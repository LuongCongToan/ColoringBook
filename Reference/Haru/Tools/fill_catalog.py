"""Dien chuoi giao dien con thieu vao String Catalog.

  python -E -P Tools/fill_catalog.py            # dien cho trong
  python -E -P Tools/fill_catalog.py --check    # chi bao cao, khong ghi

Nguon la Tools/ui_strings.json. Script chi DIEN CHO TRONG - ban dich nao da co
trong catalog thi giu nguyen, ke ca khi khac voi ban trong ui_strings.json. Vi
vay chay lai bao nhieu lan cung an toan, va chay duoc ca khi co nguoi khac dang
sua catalog bang Xcode.

Hai catalog:
  Shared/Resources/Localizable.xcstrings   app iPhone va app Watch
  Widgets/Localizable.xcstrings            hai widget extension - chung khong
                                           bien dich Shared/ nen can catalog rieng
"""
import json, os, re, sys

sys.stdout.reconfigure(encoding='utf-8')
CHECK = '--check' in sys.argv
SOURCE = 'Tools/ui_strings.json'
CATALOGS = {
    'main': 'Shared/Resources/Localizable.xcstrings',
    'widgets': 'Widgets/Localizable.xcstrings',
}
# Ma ngon ngu trong catalog. Tieng Trung la zh-Hans, khop voi project.xcproj.
LANGUAGES = ['vi', 'zh-Hans', 'ja', 'th', 'id', 'ru', 'mn', 'es', 'fr', 'ar']
SPEC = re.compile(r'%(?:\d+\$)?(lld|@|d|ld)')
fails = []


def specifiers(text):
    """Cac cho chen, khong ke thu tu: ban dich duoc doi cho %1$lld va %2$lld."""
    return sorted(SPEC.findall(text))


def load(path):
    if os.path.exists(path):
        return json.load(open(path, encoding='utf-8'))
    return {'sourceLanguage': 'en', 'strings': {}, 'version': '1.0'}


def save(path, catalog):
    catalog['strings'] = dict(sorted(catalog['strings'].items(), key=lambda kv: kv[0].lower()))
    # Dung kieu Xcode ghi: thut 2, " : " giua khoa va gia tri, khong xuong dong cuoi.
    text = json.dumps(catalog, ensure_ascii=False, indent=2, separators=(',', ' : '))
    # Xcode viet doi tuong rong thanh ba dong. Giu dung nhu vay de lan Xcode
    # ghi lai file khong sinh ra diff thua.
    text = re.sub(r'(?m)^( *)(.*) : \{\}(,?)$', r'\1\2 : {\n\n\1}\3', text)
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)


strings = json.load(open(SOURCE, encoding='utf-8'))
for name, path in CATALOGS.items():
    catalog = load(path)
    added = 0
    for key, translations in strings.get(name, {}).items():
        entry = catalog['strings'].setdefault(key, {})
        localizations = entry.setdefault('localizations', {})
        for language, value in translations.items():
            if specifiers(value) != specifiers(key):
                fails.append('%s [%s]: cho chen khac ban goc' % (key[:40], language))
                continue
            if language in localizations:
                continue
            localizations[language] = {'stringUnit': {'state': 'translated', 'value': value}}
            added += 1

    # Bao cao do phu: khoa nao can dich ma con thieu ngon ngu nao.
    missing = {}
    for key, entry in catalog['strings'].items():
        if entry.get('shouldTranslate') is False:
            continue
        have = entry.get('localizations', {})
        lacking = [code for code in LANGUAGES if code not in have]
        if lacking and have:
            missing[key] = lacking
        for language, unit in have.items():
            value = unit.get('stringUnit', {}).get('value')
            if value is not None and specifiers(value) != specifiers(key):
                fails.append('%s [%s]: cho chen khac ban goc' % (key[:40], language))
    untranslated = [k for k, e in catalog['strings'].items()
                    if e.get('shouldTranslate') is not False and not e.get('localizations')]

    print('%s' % path)
    print('   khoa            : %d' % len(catalog['strings']))
    print('   them moi        : %d ban dich' % added)
    print('   thieu ngon ngu  : %d khoa' % len(missing))
    for key, lacking in list(missing.items())[:8]:
        print('      %-44s %s' % (key[:44], ' '.join(lacking)))
    if untranslated:
        print('   chua dich gi    : %s' % ', '.join(repr(k[:30]) for k in untranslated))
    if added and not CHECK:
        save(path, catalog)
        print('   da ghi')
    print()

if fails:
    print('LOI: ' + '; '.join(fails))
sys.exit(1 if fails else 0)
