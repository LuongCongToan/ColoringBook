"""Doi chieu Worker voi app, va quet bi mat.

  python -E -P Tools/check_worker.py

Worker va app la hai codebase khac ngon ngu cung giu mot hop dong: bundle id,
product id, danh sach ngon ngu, danh sach loai loi, gioi han do dai. Lech nhau
thi khong co loi bien dich o ben nao ca - app chi am tham nhan 403 hoac giai ma
that bai. Nen phai kiem bang may.

Phan quet bi mat la test cua SCOPE 5B.4: key Anthropic khong bao gio duoc nam
trong repo.
"""
import os, re, sys, subprocess

sys.stdout.reconfigure(encoding='utf-8')
fails = []


def want(ok, label, detail=''):
    print(('  ok   ' if ok else '  FAIL ') + label + (('  — ' + detail) if detail else ''))
    if not ok:
        fails.append(label)


def read(path):
    return open(path, encoding='utf-8').read() if os.path.exists(path) else ''


config = read('Worker/src/config.ts')
checker = read('Worker/src/checker.ts')
access = read('Shared/Store/ProAccess.swift')
client = read('Shared/AI/SentenceCheckClient.swift')
langs = read('Shared/Deck/ContentLanguage.swift')
toml = read('Worker/wrangler.toml')

# --- 1. Dinh danh -----------------------------------------------------------
print('Dinh danh — Worker phai khop app, neu khong moi request deu 403')
w_bundle = re.search(r'BUNDLE_ID = "([^"]+)"', config)
want(w_bundle is not None and w_bundle.group(1) == 'pt.team.haru',
     'BUNDLE_ID cua Worker la pt.team.haru', w_bundle.group(1) if w_bundle else 'khong thay')

w_products = set(re.findall(r'"(pt\.team\.haru\.[a-z.]+)"', config))
a_products = set(re.findall(r'static let \w+ = "(pt\.team\.haru\.[a-z.]+)"', access))
want(bool(a_products) and w_products == a_products, 'product id o Worker == ProductID trong app',
     'Worker %s / app %s' % (sorted(w_products), sorted(a_products)))

w_daily = re.search(r'DAILY_CHECKS = (\d+)', config)
a_daily = re.search(r'dailyChecks = (\d+)', access)
want(w_daily and a_daily and w_daily.group(1) == a_daily.group(1),
     'han muc ngay o Worker == ProAccess.dailyChecks',
     '%s / %s' % (w_daily.group(1) if w_daily else '?', a_daily.group(1) if a_daily else '?'))

# --- 2. Hop dong request / response ----------------------------------------
print()
print('Hop dong — app gui gi, Worker tra gi')
w_langs = set(re.findall(r'^\s{2}([a-z]{2}): "', config, re.M))
a_langs = set(re.findall(r'case \w+ = "([a-z]{2})"', langs))
want(len(a_langs) == 11 and w_langs == a_langs, '11 ma ngon ngu khop ContentLanguage',
     'chi o Worker: %s, chi o app: %s' % (sorted(w_langs - a_langs), sorted(a_langs - w_langs)))

w_issues = set(re.findall(r'^\s{2}"(\w+)",$', checker[checker.find('const ISSUES'):checker.find('] as const')], re.M))
block = client[client.find('enum Issue'):]
a_issues = set(re.findall(r'case (\w+)', block[:block.find('}')]))
want(bool(a_issues) and w_issues == a_issues, 'loai loi khop SentenceFeedback.Issue',
     'chi o Worker: %s, chi o app: %s' % (sorted(w_issues - a_issues), sorted(a_issues - w_issues)))

w_max = re.search(r'MAX_SENTENCE = (\d+)', config)
a_max = re.search(r'maxSentenceLength = (\d+)', client)
want(w_max and a_max and w_max.group(1) == a_max.group(1), 'gioi han do dai cau giong nhau',
     '%s / %s' % (w_max.group(1) if w_max else '?', a_max.group(1) if a_max else '?'))

for field in ('jws', 'word', 'sentence', 'lang'):
    want(re.search(r'let %s: String' % field, client) is not None
         and ('body.%s' % field) in read('Worker/src/handler.ts'),
         'truong request "%s" co o ca hai ben' % field)
for field in ('corrected', 'notes', 'remaining'):
    want(re.search(r'let %s:' % field, client) is not None, 'app giai ma truong "%s"' % field)

statuses = {'401, 403': 'notEntitled', '422': 'rejected', '429': 'quotaExhausted'}
for code, failure in statuses.items():
    want(re.search(r'case %s: throw Failure\.%s' % (code, failure), client) is not None,
         'app anh xa %s -> .%s' % (code, failure))

# --- 3. Bat bien bao mat nhin thay duoc trong ma nguon ----------------------
print()
print('Bat bien — SCOPE 5B.0 va 5B.4')
want(re.search(r'MODEL = "claude-haiku-5-5"', config) is not None, 'model co dinh la claude-haiku-5-5')
handler = read('Worker/src/handler.ts')
want('access-control-allow' not in (handler + read('Worker/src/index.ts')).lower()
     .replace('// no cors', ''), 'khong dat header CORS nao')
want(handler.find('verifyTransaction(') < handler.find('checkSentence(') and
     handler.find('quota.reserve(') < handler.find('checkSentence('),
     'xac minh va han muc dung truoc lenh goi model')
want('env.ENVIRONMENT === "test"' in handler, 'root thay the chi doc khi ENVIRONMENT la test')
want(re.search(r'^ENVIRONMENT = "production"', toml, re.M) is not None,
     'wrangler.toml mac dinh ENVIRONMENT = production')
want('TEST_TRUST_ROOT' not in toml, 'wrangler.toml khong dat TEST_TRUST_ROOT')
want(re.search(r'console\.(log|info|warn|error)\((?!JSON\.stringify\(\{ event)', handler + read('Worker/src/checker.ts')
               + read('Worker/src/jws.ts') + read('Worker/src/guard.ts') + read('Worker/src/quota.ts')) is None,
     'moi dong log deu di qua mot mau co dinh', 'log tu do la cho cau nguoi hoc lot ra')

# --- 4. Bi mat --------------------------------------------------------------
print()
print('Bi mat — key Anthropic khong bao gio nam trong repo')
want(re.search(r'ANTHROPIC_API_KEY\s*=', toml) is None, 'wrangler.toml khong gan ANTHROPIC_API_KEY')
ignore = read('.gitignore')
want('.dev.vars' in ignore and '.env' in ignore, '.gitignore chan .dev.vars va .env')

try:
    tracked = subprocess.run(['git', 'ls-files', '-co', '--exclude-standard'],
                             capture_output=True, text=True, encoding='utf-8').stdout.split('\n')
except OSError:
    tracked = []
KEY = re.compile(r'sk-ant-[A-Za-z0-9_-]{20,}')
leaks = []
for path in tracked:
    if not path or not os.path.isfile(path) or os.path.getsize(path) > 2_000_000:
        continue
    try:
        if KEY.search(open(path, encoding='utf-8', errors='ignore').read()):
            leaks.append(path)
    except OSError:
        pass
want(bool(tracked), 'quet duoc danh sach file cua git')
want(not leaks, 'khong file nao chua chuoi dang sk-ant-…', ', '.join(leaks))
want(not any(os.path.basename(p) in ('.dev.vars', '.env') for p in tracked),
     'khong co .dev.vars hay .env trong danh sach file')

print()
print('KET QUA: %s' % ('tat ca qua' if not fails else 'THAT BAI: ' + '; '.join(fails)))
sys.exit(1 if fails else 0)
