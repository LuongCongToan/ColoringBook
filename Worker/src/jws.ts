// tsyringe, inside @peculiar/x509, refuses to load without this polyfill.
import "reflect-metadata";
import * as x509 from "@peculiar/x509";

/// 401: we cannot tell who this is. 403: we can, and they may not.
export class EntitlementError extends Error {
  constructor(
    readonly status: 401 | 403,
    readonly reason: string,
  ) {
    super(reason);
  }
}

/// The fields of a StoreKit 2 JWSTransaction this Worker reads.
export interface Transaction {
  /// This purchase. A consumable's counter is keyed on it.
  transactionId: string;
  /// The subscription across renewals and reinstalls. Each Family Sharing
  /// member gets their own.
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  /// "Auto-Renewable Subscription", "Consumable", ...
  type: string;
  environment: string;
  expiresDate?: number;
  revocationDate?: number;
  signedDate?: number;
  /// 1 = introductory offer, i.e. the free trial.
  offerType?: number;
  /// "PURCHASED" or "FAMILY_SHARED".
  inAppOwnershipType: string;
}

/// Marker extensions Apple puts on the certificates that sign App Store
/// receipts. Checking them means a certificate Apple issued for some other
/// purpose cannot stand in for one of these.
export const OID_APPLE_WWDR_INTERMEDIATE = "1.2.840.113635.100.6.2.1";
export const OID_APPLE_RECEIPT_SIGNING = "1.2.840.113635.100.6.11.1";

const unauthorized = (reason: string) => new EntitlementError(401, reason);

export function base64ToBytes(text: string): Uint8Array<ArrayBuffer> {
  const binary = atob(text);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function base64UrlToBytes(text: string): Uint8Array<ArrayBuffer> {
  if (!/^[A-Za-z0-9_-]+$/.test(text)) throw unauthorized("malformed");
  const padded = text.replace(/-/g, "+").replace(/_/g, "/");
  return base64ToBytes(padded + "=".repeat((4 - (padded.length % 4)) % 4));
}

function parseJson(bytes: Uint8Array): Record<string, unknown> {
  const value: unknown = JSON.parse(new TextDecoder("utf-8", { fatal: true, ignoreBOM: false }).decode(bytes));
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw unauthorized("malformed");
  }
  return value as Record<string, unknown>;
}

function sameBytes(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i]! ^ b[i]!;
  return diff === 0;
}

function validAt(cert: x509.X509Certificate, date: Date): boolean {
  return cert.notBefore.getTime() <= date.getTime() && date.getTime() <= cert.notAfter.getTime();
}

/// Verifies a StoreKit 2 signed transaction and returns its payload.
///
/// Every failure here is a 401 and none of them tells the caller why: the
/// reason is for the log line, and a precise error is a map for whoever is
/// probing (SCOPE.md 5B.1).
///
/// The one thing that makes this safe is the anchor. "The chain is internally
/// valid" proves nothing - anyone can mint a root, an intermediate and a leaf
/// that verify against each other, and sign any payload they like with them.
/// The chain has to end at `trustedRoot`, which is Apple's real root compiled
/// into this Worker, and the root the client sent is used for nothing except
/// being compared to it.
export async function verifyTransaction(
  jws: string,
  trustedRoot: Uint8Array<ArrayBuffer>,
  now: Date,
): Promise<Transaction> {
  try {
    return await verify(jws, trustedRoot, now);
  } catch (error) {
    if (error instanceof EntitlementError) throw error;
    // Anything a parser or WebCrypto threw on hostile input. Still a 401,
    // never a 500 - a 500 says the input reached somewhere it should not.
    throw unauthorized("malformed");
  }
}

async function verify(
  jws: string,
  trustedRoot: Uint8Array<ArrayBuffer>,
  now: Date,
): Promise<Transaction> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw unauthorized("malformed");
  const [headerPart, payloadPart, signaturePart] = parts as [string, string, string];

  const header = parseJson(base64UrlToBytes(headerPart));
  // An allow-list of one. `alg: none`, HS256 with the public key as the
  // secret, and every other classic all die on this line.
  if (header.alg !== "ES256") throw unauthorized("algorithm");

  const x5c = header.x5c;
  if (!Array.isArray(x5c) || x5c.length !== 3 || !x5c.every((c) => typeof c === "string")) {
    throw unauthorized("chain");
  }
  const [leafDer, intermediateDer, rootDer] = (x5c as string[]).map(base64ToBytes) as [
    Uint8Array<ArrayBuffer>,
    Uint8Array<ArrayBuffer>,
    Uint8Array<ArrayBuffer>,
  ];
  if (!sameBytes(rootDer, trustedRoot)) throw unauthorized("anchor");

  // From here on the pinned bytes are the root, not the ones that arrived.
  const root = new x509.X509Certificate(trustedRoot);
  const intermediate = new x509.X509Certificate(intermediateDer);
  const leaf = new x509.X509Certificate(leafDer);

  if (!(await intermediate.verify({ publicKey: root, signatureOnly: true }))) {
    throw unauthorized("chain");
  }
  if (!(await leaf.verify({ publicKey: intermediate, signatureOnly: true }))) {
    throw unauthorized("chain");
  }

  const constraints = intermediate.getExtension(x509.BasicConstraintsExtension);
  if (!constraints?.ca) throw unauthorized("chain");
  if (!intermediate.getExtension(OID_APPLE_WWDR_INTERMEDIATE)) throw unauthorized("chain");
  if (!leaf.getExtension(OID_APPLE_RECEIPT_SIGNING)) throw unauthorized("chain");

  // ES256 is P-256 by definition; a leaf carrying any other key fails to
  // import here and is refused.
  const key = await crypto.subtle.importKey(
    "spki",
    leaf.publicKey.rawData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["verify"],
  );
  const signature = base64UrlToBytes(signaturePart);
  if (signature.length !== 64) throw unauthorized("signature");
  const signed = new TextEncoder().encode(`${headerPart}.${payloadPart}`);
  if (!(await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, key, signature, signed))) {
    throw unauthorized("signature");
  }

  const payload = parseJson(base64UrlToBytes(payloadPart));

  // Validity is judged at the moment Apple signed, as Apple's own server
  // library does: a transaction stays presentable after the leaf that signed
  // it rotates out. `signedDate` is inside the signed payload, so the sender
  // cannot choose it - but it may not be in the future either.
  const signedDate = typeof payload.signedDate === "number" ? payload.signedDate : undefined;
  if (signedDate !== undefined && signedDate > now.getTime() + 5 * 60_000) {
    throw unauthorized("signedDate");
  }
  const effective = signedDate !== undefined ? new Date(signedDate) : now;
  if (!validAt(root, effective) || !validAt(intermediate, effective) || !validAt(leaf, effective)) {
    throw unauthorized("expired-chain");
  }

  const text = (name: string) =>
    typeof payload[name] === "string" ? (payload[name] as string) : "";
  const number = (name: string) =>
    typeof payload[name] === "number" ? (payload[name] as number) : undefined;

  const transaction: Transaction = {
    transactionId: text("transactionId"),
    originalTransactionId: text("originalTransactionId"),
    bundleId: text("bundleId"),
    productId: text("productId"),
    type: text("type"),
    environment: text("environment"),
    expiresDate: number("expiresDate"),
    revocationDate: number("revocationDate"),
    signedDate,
    offerType: number("offerType"),
    inAppOwnershipType: text("inAppOwnershipType"),
  };
  const id = /^[0-9A-Za-z-]{1,64}$/;
  if (!id.test(transaction.originalTransactionId) || !id.test(transaction.transactionId)) {
    throw unauthorized("malformed");
  }
  return transaction;
}

export interface EntitlementPolicy {
  bundleId: string;
  /// Auto-renewable subscriptions: must not be expired.
  subscriptions: ReadonlySet<string>;
  /// Consumables: no expiry; the page counter decides what is left.
  consumables: ReadonlySet<string>;
  /// Whether an Apple-signed sandbox transaction is entertained at all.
  allowSandbox: boolean;
}

/// Decides whether a verified transaction buys a coloring page right now.
///
/// Separate from `verifyTransaction` on purpose: that one answers "did Apple
/// sign this", this one answers "is it for us, and is it still good". A real
/// Apple signature on someone else's 99-cent purchase passes the first and
/// must fail here.
///
/// `now` is the server's clock. Nothing the client sends is consulted.
export function authorize(tx: Transaction, policy: EntitlementPolicy, now: Date): void {
  const forbidden = (reason: string) => new EntitlementError(403, reason);
  if (tx.bundleId !== policy.bundleId) throw forbidden("bundle");
  const subscription = policy.subscriptions.has(tx.productId);
  const consumable = policy.consumables.has(tx.productId);
  if (!subscription && !consumable) throw forbidden("product");
  // The type is signed too: a subscription id on a consumable record, or the
  // reverse, is not a purchase this Worker knows how to count.
  if (subscription && tx.type !== "Auto-Renewable Subscription") throw forbidden("type");
  if (consumable && tx.type !== "Consumable") throw forbidden("type");
  // Refunded or revoked. Without this line a refund keeps the AI for life.
  if (tx.revocationDate !== undefined) throw forbidden("revoked");
  if (subscription && (tx.expiresDate === undefined || tx.expiresDate <= now.getTime())) {
    throw forbidden("expired");
  }
  if (tx.environment === "Production") return;
  if (tx.environment === "Sandbox" && policy.allowSandbox) return;
  throw forbidden("environment");
}
