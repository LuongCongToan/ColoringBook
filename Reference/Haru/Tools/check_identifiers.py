"""Doi chieu moi dinh danh giua project Xcode, entitlements va code Swift.

  python -E -P Tools/check_identifiers.py

Lech mot ky tu o day thi khong co loi bien dich va khong co loi luc chay:
App Group chi im lang tra ve kho rong, nen phai kiem bang may.
"""
import json, re, sys, os

sys.stdout.reconfigure(encoding='utf-8')
fails = []


def want(ok, label, detail=''):
    print(('  ok   ' if ok else '  FAIL ') + label + (('  ' + detail) if detail else ''))
    if not ok:
        fails.append(label)


def read(path):
    return open(path, encoding='utf-8').read()


proj = json.loads(re.sub(r',(\s*[}\]])', r'\1', read('TopikVocab.xcodeproj/project.xcproj')))
target = {t['name']: t for t in proj['targets']}['Haru']
bs = target['build-settings']

bundle = bs.get('PRODUCT_BUNDLE_IDENTIFIER', '')
print('Bundle identifier')
want(bundle == bundle.lower(), 'toan chu thuong', bundle)
want(bundle == 'pt.team.haru', 'khop quy uoc pt.team.<app>', bundle)

print()
print('App Group — phai giong het nhau o ca ba noi')
ent_path = bs.get('CODE_SIGN_ENTITLEMENTS', '')
want(bool(ent_path), 'CODE_SIGN_ENTITLEMENTS da dat', ent_path or '(trong)')
want(os.path.exists(ent_path), 'file entitlements ton tai', ent_path)
ent_group = re.search(r'<string>(group\.[^<]+)</string>', read(ent_path)).group(1) if os.path.exists(ent_path) else ''
code_group = re.search(r'appGroupID\s*=\s*"([^"]+)"', read('Core/SharedStorage.swift')).group(1)
want(ent_group == code_group, 'entitlements == SharedStorage.appGroupID',
     '%s vs %s' % (ent_group, code_group))
want(ent_group == 'group.' + bundle, 'App Group == group.<bundle id>',
     '%s vs group.%s' % (ent_group, bundle))

print()
print('Product ID StoreKit')
products = re.findall(r'static let \w+ = "([^"]+)"', read('Shared/Store/ProAccess.swift'))
products = [p for p in products if p.startswith('pt.')]
for p in products:
    want(p.startswith(bundle + '.'), 'bat dau bang bundle id', p)

# Products.storekit la ban sao cua App Store Connect de test mua o local. Lech ID
# thi Simulator bao 'Could not reach the App Store' ma khong noi vi sao.
storekit = json.loads(read('Products.storekit')) if os.path.exists('Products.storekit') else {}
want(bool(storekit), 'co Products.storekit')
kit_ids = sorted(s['productID'] for g in storekit.get('subscriptionGroups', [])
                 for s in g['subscriptions']) + sorted(p['productID'] for p in storekit.get('products', []))
want(sorted(kit_ids) == sorted(products), 'Products.storekit == ProductID trong ProAccess.swift',
     '%s vs %s' % (kit_ids, products))
for name in ('Haru', 'Haru Watch App'):
    scheme = read('TopikVocab.xcodeproj/xcshareddata/xcschemes/%s.xcscheme' % name)
    want('identifier = "../../Products.storekit"' in scheme, 'scheme %s tro toi Products.storekit' % name)

print()
print('Info.plist')
plist_path = bs.get('INFOPLIST_FILE', '')
want(bool(plist_path), 'INFOPLIST_FILE da dat', plist_path or '(trong) -> trung lenh build')
want(os.path.exists(plist_path), 'file ton tai', plist_path)
for path in (plist_path, ent_path):
    if path:
        inside = path.split('/')[0] in ('iOS', 'Shared', 'Watch', 'Widgets')
        want(not inside, 'nam ngoai thu muc synchronized', path)

print()
print('Cau hinh build')
want(bs.get('IPHONEOS_DEPLOYMENT_TARGET') == '17.6', 'deployment target target-level',
     bs.get('IPHONEOS_DEPLOYMENT_TARGET', ''))
want(proj['build-settings'].get('IPHONEOS_DEPLOYMENT_TARGET') == '17.6',
     'deployment target project-level',
     proj['build-settings'].get('IPHONEOS_DEPLOYMENT_TARGET', ''))
want(bs.get('SWIFT_DEFAULT_ACTOR_ISOLATION') == 'nonisolated',
     'actor isolation mac dinh = nonisolated', bs.get('SWIFT_DEFAULT_ACTOR_ISOLATION', ''))
want(bs.get('TARGETED_DEVICE_FAMILY') == '1,2', 'iPhone + iPad',
     bs.get('TARGETED_DEVICE_FAMILY', ''))

print()
print('Thu muc synchronized')
for f in proj['files']:
    if 'path' in f and f.get('kind') == 'folder':
        want(True, 'synchronized: %s -> %s' % (f['path'], f.get('target-membership')))

print()
print('Bon target — moi cai phai dung ten, dung nhom, dung cho')
EXPECTED = {
    'Haru': 'pt.team.haru',
    'Haru Watch App': 'pt.team.haru.watchkitapp',
    'HaruWidgetExtension': 'pt.team.haru.widget',
    'HaruWatchWidgetExtension': 'pt.team.haru.watchkitapp.widget',
}
by_name = {t['name']: t for t in proj['targets']}
want(set(by_name) == set(EXPECTED), 'co du bon target', ', '.join(sorted(by_name)))
for name, expected in EXPECTED.items():
    t = by_name.get(name)
    if not t:
        continue
    tbs = t['build-settings']
    want(tbs.get('PRODUCT_BUNDLE_IDENTIFIER') == expected, '%s: bundle id' % name,
         tbs.get('PRODUCT_BUNDLE_IDENTIFIER', ''))
    # App #1 de ten "Notched" o ca bon target. Copy khuon sang ma quen doi la
    # app moi hien ten app cu tren man hinh chinh.
    want(tbs.get('INFOPLIST_KEY_CFBundleDisplayName') == 'Haru', '%s: ten hien thi la Haru' % name,
         tbs.get('INFOPLIST_KEY_CFBundleDisplayName', ''))
    for key in ('INFOPLIST_FILE', 'CODE_SIGN_ENTITLEMENTS'):
        path = tbs.get(key, '')
        want(os.path.exists(path), '%s: %s ton tai' % (name, key), path or '(trong)')
        want(path.startswith('Config/'), '%s: %s nam trong Config/' % (name, key), path)
    ent = tbs.get('CODE_SIGN_ENTITLEMENTS', '')
    if os.path.exists(ent):
        found = re.search(r'<string>(group\.[^<]+)</string>', read(ent))
        want(found is not None and found.group(1) == code_group,
             '%s: App Group == SharedStorage.appGroupID' % name,
             found.group(1) if found else 'khong co')
    want(tbs.get('SWIFT_DEFAULT_ACTOR_ISOLATION') == 'nonisolated',
         '%s: actor isolation = nonisolated' % name)

watch_bs = by_name.get('Haru Watch App', {}).get('build-settings', {})
want(watch_bs.get('INFOPLIST_KEY_WKCompanionAppBundleIdentifier') == bundle,
     'Watch tro dung app iPhone', watch_bs.get('INFOPLIST_KEY_WKCompanionAppBundleIdentifier', ''))
want('WKCompanionAppBundleIdentifier' in read('Config/HaruWatch-Info.plist')
     and '<string>%s</string>' % bundle in read('Config/HaruWatch-Info.plist'),
     'HaruWatch-Info.plist tro dung app iPhone')

print()
print('Target nao bien dich thu muc nao')
members = {f['path']: f for f in proj['files'] if f.get('kind') == 'folder'}
WIDGETS = ['HaruWidgetExtension', 'HaruWatchWidgetExtension']
# So theo tap hop: Xcode tu sap lai thu tu target khi ghi file project.
def targets(folder):
    return sorted(members.get(folder, {}).get('target-membership', []))


want(targets('Core') == sorted(['Haru', 'Haru Watch App'] + WIDGETS),
     'Core thuoc ca bon target')
want(targets('Shared') == ['Haru', 'Haru Watch App'],
     'Shared chi thuoc hai app, khong thuoc widget',
     'widget ma bien dich Shared la keo ca deck 2 MB vao moi extension')
want(targets('Widgets') == sorted(WIDGETS), 'Widgets thuoc hai extension')
want(members.get('Watch', {}).get('target-membership') == ['Haru Watch App'], 'Watch chi thuoc app Watch')
want(members.get('iOS', {}).get('target-membership') == ['Haru'], 'iOS chi thuoc app iPhone')
excluded = [x for e in members.get('Shared', {}).get('membership-exceptions', [])
            if e.get('target') == 'Haru Watch App' for x in e.get('exclusions', [])]
want('Resources/krdict_glosses.json' in excluded, 'Watch khong dong goi tu dien 13 MB')
for path in excluded:
    want(os.path.exists(os.path.join('Shared', path)), 'file bi loai tru con ton tai', path)

# Widget chi bien dich Core + Widgets, nen moi kieu no dung phai nam o hai noi do.
core_types = set()
for folder in ('Core', 'Widgets'):
    for dirpath, _, names in os.walk(folder):
        for n in names:
            if n.endswith('.swift'):
                core_types |= set(re.findall(r'\b(?:struct|enum|class|actor)\s+(\w+)', read(os.path.join(dirpath, n))))
shared_types = set()
for dirpath, _, names in os.walk('Shared'):
    for n in names:
        if n.endswith('.swift'):
            shared_types |= set(re.findall(r'^\s*(?:@\w+\s+)*(?:final\s+)?(?:struct|enum|class|actor)\s+(\w+)',
                                           read(os.path.join(dirpath, n)), re.M))
leaks = set()
for folder in ('Core', 'Widgets'):
    for dirpath, _, names in os.walk(folder):
        for n in names:
            if n.endswith('.swift'):
                # Bo chu thich va chuoi: "Word of the day" khong phai la kieu Word.
                code = re.sub(r'//.*', '', read(os.path.join(dirpath, n)))
                code = re.sub(r'"(?:[^"\\]|\\.)*"', '""', code)
                leaks |= {t for t in shared_types - core_types if re.search(r'\b%s\b' % t, code)}
want(not leaks, 'Core va Widgets khong dung kieu nao cua Shared',
     ', '.join(sorted(leaks)) or 'widget extension se khong bien dich duoc')

print()
print('KET QUA: %s' % ('tat ca deu khop' if not fails else '%d loi' % len(fails)))
sys.exit(1 if fails else 0)
