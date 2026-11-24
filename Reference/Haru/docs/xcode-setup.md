# Dựng project trong Xcode — hướng dẫn add tay

Tài liệu này mô tả toàn bộ cấu trúc project để add tay trong Xcode trên máy Mac.
Dựng theo đúng khuôn app #1 (`TinnitusRelief`) như SCOPE.md mục 4.1 đã chốt.

Ký hiệu trong tài liệu:

| | |
|---|---|
| 📋 | **copy nguyên xi** từ `TinnitusRelief/` — không sửa, xem lý do ở SCOPE 4.1 |
| ✏️ | copy rồi đổi nội dung |
| 🆕 | viết mới |

> **Bảng tái dùng ở SCOPE 4.1 lạc quan hơn thực tế.** Khi mở từng file ra đọc thì
> hoá ra chỉ phần *khung* tái dùng được, không phải nội dung:
>
> - `SubscriptionStore.swift` — plumbing StoreKit đúng là dùng lại gần nguyên vẹn,
>   nhưng phải bỏ cơ chế trial tự đếm bằng ngày. App #1 tự ghi ngày mở lần đầu rồi
>   cho 7 ngày; app này dùng **trial của chính StoreKit**, vì Worker phải xác minh
>   quyền từ JWS có chữ ký Apple, mà một cái ngày trong UserDefaults thì không
>   chứng minh được gì với server (SCOPE 2 và 5B.8).
> - `ProAccess.swift`, `WidgetBridge.swift` — gần như toàn bộ là nội dung riêng của
>   app #1 (SoundMix, preset, play/stop/timer). Giữ hình dạng, viết lại ruột.
> - `SharedStorage.swift` — đổi App Group và toàn bộ key.
> - `ConnectivitySync.swift` — lớp WCSession dùng lại được, nhưng mọi payload đều là
>   domain app #1 (mixes, tần số ù tai).
>
> Thứ **thật sự** copy nguyên xi chỉ còn `PrivacyInfo.xcprivacy` và
> `Tools/make_app_icon.py`.

---

## 0. Trạng thái hiện tại — bốn target đã có trong project

Cả bốn target đã nằm trong `project.xcproj`, kèm đủ file nguồn và file cấu hình.
**Không phải tạo target nào bằng tay nữa.**

| Target | File nguồn | Đã build thử trên Mac? |
|---|---|---|
| `Haru` (iOS) | `iOS/` + `Shared/` + `Core/` | ✅ đã chạy trên máy thật |
| `Haru Watch App` | `Watch/` + `Shared/` + `Core/` | ⬜ **chưa** |
| `HaruWidgetExtension` | `Widgets/` + `Core/` | ⬜ **chưa** |
| `HaruWatchWidgetExtension` | `Widgets/` + `Core/` | ⬜ **chưa** |

> **Ba target mới chưa từng được biên dịch.** Chúng được viết và ghi vào project trên
> Windows, nơi không có Xcode. Khuôn của chúng lấy từ app #1 (đã build và nộp App Store
> được), và `Tools/check_identifiers.py` kiểm được bundle ID, App Group, thư mục nào
> thuộc target nào — nhưng **không gì thay được lần build đầu**. Lỗi biên dịch ở lần đó
> là chuyện bình thường; gửi nguyên văn lỗi là sửa được.

### Lần đầu mở trên Mac

1. `git pull`, mở `TopikVocab.xcodeproj`.
   Nếu Xcode **không mở được project**, hoàn tác riêng file project rồi báo lại:
   `git checkout HEAD~1 -- TopikVocab.xcodeproj/project.xcproj`
2. Kiểm ba thư mục mới hiện màu xanh trong navigator: `Core`, `Watch`, `Widgets`.
3. Chọn từng target → tab **Signing & Capabilities**. Xcode sẽ tự đăng ký ba bundle ID
   mới và App Group cho chúng. Bấm **Try Again** nếu nó báo lỗi provisioning lần đầu.
4. Build theo thứ tự: `HaruWidgetExtension` → `HaruWatchWidgetExtension` →
   `Haru Watch App` → `Haru`. Target đứng trước hỏng thì target sau hỏng theo, nên
   thứ tự này cho lỗi gọn nhất.
5. Thả một ảnh 1024×1024 vào `Watch/Assets.xcassets/AppIcon` — hiện chưa có icon Watch.

### Ghi lại project bằng script

`Tools/add_targets.py` là thứ đã ghi ba target vào project. Chạy lại bao nhiêu lần
cũng được (giữ nguyên ID), dùng khi cần đổi build setting của cả ba cùng lúc:

```bash
python -E -P Tools/add_targets.py
```

### Vì sao `Config/` nằm ngoài mọi thư mục nguồn

Đây là nguyên nhân của lỗi `Multiple commands produce .../Haru.app/Info.plist`.

Thư mục synchronized **copy mọi thứ bên trong nó vào bundle như tài nguyên**. Để
`Info.plist` trong đó thì có hai lệnh cùng sinh ra `Haru.app/Info.plist`: một lệnh
*sinh* nó từ các `INFOPLIST_KEY_*`, một lệnh *copy* file kia vào.

`INFOPLIST_FILE` và `CODE_SIGN_ENTITLEMENTS` là build setting theo **đường dẫn** — file
không cần nằm trong project. Tám file `.plist` / `.entitlements` của bốn target vì vậy
đều ở `Config/`.

Quy tắc chung: thứ gì build setting trỏ tới bằng đường dẫn thì **đừng** để trong thư
mục synchronized.

### Hai thứ còn thiếu để app đầy đủ

- `iOS/Resources/deck_content.json` — câu ví dụ, mẹo nhớ. Mới có 2500 từ đầu, viết tay
  trong `Tools/content/` (skill `/test:generate-exam-stentence`) rồi `generate_content.py
  build`. Từ chưa có câu thì màn chi tiết từ chỉ không có mục "Examples", không hỏng gì.
- `Core/PrivacyInfo.xcprivacy` — đã có (2026-11-17), chưa build thử. `Core/` thuộc cả bốn
  target nên file tự vào gốc của cả bốn bundle. Khác app #1 ở chỗ có khai dữ liệu thu thập
  (câu gửi đi chấm).

---

> **Tên app chưa chốt.** Tài liệu dùng tạm `Haru` và `pt.team.haru` (SCOPE mục 8).
> Nếu đổi tên thì phải đổi ở: tên 4 target, 4 bundle ID, App Group, tám file trong
> `Config/`, `INFOPLIST_KEY_WKCompanionAppBundleIdentifier`, và `BUNDLE_ID` +
> `PRODUCT_IDS` trong `Worker/src/config.ts`. Sửa các hằng số ở đầu `Tools/add_targets.py`
> rồi chạy lại nó là đổi được phần project; `Tools/check_all.sh` sẽ báo chỗ nào còn sót.

---

## 1. Bốn target

Cùng hình dạng app #1: app iOS kéo theo Watch app, mỗi bên một widget extension.

| Target | Product type | SDK | Deployment | Bundle ID |
|---|---|---|---|---|
| `Haru` | application | iOS | **17.6** | `pt.team.haru` |
| `Haru Watch App` | application | watchOS | **10.0** | `pt.team.haru.watchkitapp` |
| `HaruWidgetExtension` | app-extension | iOS | 17.6 | `pt.team.haru.widget` |
| `HaruWatchWidgetExtension` | app-extension | watchOS | 10.0 | `pt.team.haru.watchkitapp.widget` |

**Dependencies** (đúng như app #1):

- `Haru` → phụ thuộc `Haru Watch App` + `HaruWidgetExtension`
- `Haru Watch App` → phụ thuộc `HaruWatchWidgetExtension`

**Build phase bổ sung của `Haru`** (ngoài compile-sources / frameworks / resources):

- Copy *"Embed Watch Content"* → `$(CONTENTS_FOLDER_PATH)/Watch`, base `build-products-directory`
- Copy *"Embed Foundation Extensions"* → base `plugins-directory`

`Haru Watch App` cũng cần phase *"Embed Foundation Extensions"* (base `plugins-directory`).

---

## 2. Cây thư mục

```
Core/            ← cả BỐN target biên dịch. Giữ nó nhỏ.
  SharedStorage.swift     App Group, defaults, file trong container
  WidgetState.swift       bản ghi 7 ngày mà widget đọc
  Theme.swift             màu, font — không được nhắc tới kiểu nào của Shared/

Shared/          ← app iPhone + app Watch
  App/          AppEnvironment.swift
  Model/        Word · GrammarItem · ReviewState
  Deck/         DeckStore · DeckLoader · ContentLanguage · GlossStore
                WatchGlossTable        (nghĩa một ngôn ngữ, iPhone gửi sang Watch)
  SRS/          SM2Scheduler · ReviewQueue
  Store/        SubscriptionStore · ProAccess · SettingsStore
                ProgressStore · WidgetBridge
  Sync/         ConnectivitySync
  Notify/       ReminderSettings
  Speech/       Pronouncer
  AI/           SentenceCheckClient
  UI/           GlyphWarmer · Theme+Study
  Resources/    vocab.json · Localizable.xcstrings
                grammar.json · krdict_glosses.json   (loại khỏi target Watch)

iOS/             ← chỉ app iPhone
  HaruApp.swift
  Notify/       ReminderScheduler.swift
  Deck/         ContentStore.swift
  Views/        Root · Today · Review · WordDetail · WriteCheck
                Library · Stats · Settings · Paywall · Onboarding
  Resources/    deck_content.json      (2500 từ đầu — xem mục 0)

Watch/           ← chỉ app Watch
  HaruWatchApp.swift
  Views/        WatchRoot · WatchReview · WatchWord · WatchPaywall
  Assets.xcassets

Widgets/         ← cả hai widget extension, cùng một bộ nguồn
  HaruWidgets.swift
  Localizable.xcstrings
  Assets.xcassets

Haru/            Assets.xcassets của app iPhone
Config/          8 file .plist / .entitlements — ngoài mọi thư mục nguồn (mục 0)

Worker/   Tools/   data/   docs/        (ngoài project Xcode)
```

`Worker/`, `Tools/`, `data/`, `docs/` **không add vào Xcode** — chúng không build.

---

## 3. Target membership

> **Membership đặt theo thư mục, không theo từng file.** Mọi thư mục nguồn là
> synchronized folder (thư mục xanh): file mới chỉ cần `git pull` là vào build, và
> `project.xcproj` gần như không đổi. Thứ gì nằm trong thư mục là vào build — đừng để
> file rác trong đó.

| Thư mục | Haru | Watch App | Widget | Watch Widget |
|---|:--:|:--:|:--:|:--:|
| `Core/` | ✓ | ✓ | ✓ | ✓ |
| `Shared/` | ✓ | ✓ ¹ | — | — |
| `iOS/` | ✓ | — | — | — |
| `Watch/` | — | ✓ | — | — |
| `Widgets/` | — | — | ✓ | ✓ |
| `Haru/` | ✓ | — | — | — |

¹ trừ `Resources/krdict_glosses.json` và `Resources/grammar.json` — ngoại lệ duy nhất
trong cả project, đặt bằng `membership-exceptions`.

`Tools/check_identifiers.py` kiểm đúng bảng này, và kiểm thêm rằng `Core/` và
`Widgets/` không dùng kiểu nào khai báo trong `Shared/`.

Bốn quyết định trong bảng có lý do, đừng sửa nếu chưa đọc:

**Widget không biên dịch `Shared/`.** Widget chỉ cần đúng một từ của hôm nay. Nó đọc
bản ghi `WidgetState` từ App Group, do app ghi sẵn. Cho widget biên dịch `Shared/` là
kéo deck 2 MB và cả StoreKit vào mỗi extension. Cái giá: thứ gì widget cần phải nằm
trong `Core/`, và `Core/` không được nhắc tới kiểu nào của `Shared/` — vì vậy
`Theme.color(for: Grade)` nằm ở `Shared/UI/Theme+Study.swift` chứ không ở `Core/Theme.swift`.

**Hai widget extension dùng chung một bộ nguồn.** Bản iOS và bản watchOS chỉ khác nhau
ở danh sách family, nên khác biệt đó là một `#if os(watchOS)` trong `HaruWidgets.swift`,
không phải hai file phải giữ cho khớp nhau.

**Watch không đóng gói từ điển.** `krdict_glosses.json` nặng 13 MB cho 11 ngôn ngữ.
Watch chỉ cần một, nên iPhone cắt ra đúng ngôn ngữ đang dùng và gửi sang
(`WatchGlossTable`, qua `WCSession.transferFile`). Watch tự xin khi chưa có hoặc khi
người học đổi ngôn ngữ. Trong lúc chờ, từ hiện 길잡이말 thay cho nghĩa.

**`ReminderScheduler` nằm ở `iOS/`, không phải `Shared/`.** Thông báo lên lịch ở iPhone
rồi **tự mirror sang cổ tay** — lên lịch ở cả hai nơi là người dùng nhận hai lần.
Ngược lại `ReminderSettings` phải ở `Shared/`: `SettingsStore` chạy ở cả hai app.

---

## 4. Build settings

### Mức project

Copy nguyên khối `build-settings` mức project từ app #1 — toàn bộ là cờ cảnh báo
clang/gcc tiêu chuẩn Xcode sinh ra, không có gì riêng của app #1.

Đáng chú ý, giữ nguyên: `ENABLE_USER_SCRIPT_SANDBOXING = YES`,
`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`,
`SWIFT_VERSION = 5.0`.

### Mức target — những key phải đặt đúng

Chung cho cả bốn target:

```
DEVELOPMENT_TEAM                            = S29VYJ2LR9
CODE_SIGN_STYLE                             = Automatic
CURRENT_PROJECT_VERSION                     = 1
MARKETING_VERSION                           = 1.0
GENERATE_INFOPLIST_FILE                     = YES
PRODUCT_NAME                                = $(TARGET_NAME)
STRING_CATALOG_GENERATE_SYMBOLS             = YES
SWIFT_EMIT_LOC_STRINGS                      = YES
SWIFT_APPROACHABLE_CONCURRENCY              = YES
SWIFT_DEFAULT_ACTOR_ISOLATION               = nonisolated
SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES
INFOPLIST_KEY_CFBundleDisplayName           = Haru
```

> `INFOPLIST_KEY_CFBundleDisplayName` là **tên hiện trên màn hình chính**, và nó
> được tiêm vào Info.plist vì `GENERATE_INFOPLIST_FILE = YES`. App #1 đặt key này
> là `Notched` ở cả bốn target — đó là tên app #1, đúng. Khi copy sang đây **phải đổi**,
> nếu không app mới sẽ hiện tên app cũ.

Riêng `Haru`:

```
INFOPLIST_FILE                   = Config/Haru-Info.plist
CODE_SIGN_ENTITLEMENTS           = Config/Haru.entitlements
IPHONEOS_DEPLOYMENT_TARGET       = 17.6
TARGETED_DEVICE_FAMILY           = 1,2
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon
ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor
ENABLE_PREVIEWS                  = YES
INFOPLIST_KEY_UIApplicationSceneManifest_Generation      = YES
INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents   = YES
INFOPLIST_KEY_UILaunchScreen_Generation                  = YES
LD_RUNPATH_SEARCH_PATHS          = $(inherited) @executable_path/Frameworks
```

Riêng `Haru Watch App`:

```
INFOPLIST_FILE                   = Config/HaruWatch-Info.plist
CODE_SIGN_ENTITLEMENTS           = Config/HaruWatch.entitlements
SDKROOT                          = watchos
WATCHOS_DEPLOYMENT_TARGET        = 10.0
TARGETED_DEVICE_FAMILY           = 4
SKIP_INSTALL                     = YES
INFOPLIST_KEY_WKCompanionAppBundleIdentifier = pt.team.haru
INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown
```

Riêng `HaruWidgetExtension`:

```
INFOPLIST_FILE                   = Config/HaruWidget-Info.plist
CODE_SIGN_ENTITLEMENTS           = Config/HaruWidget.entitlements
IPHONEOS_DEPLOYMENT_TARGET       = 17.6
TARGETED_DEVICE_FAMILY           = 1,2
SKIP_INSTALL                     = YES
ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME = WidgetBackground
LD_RUNPATH_SEARCH_PATHS = $(inherited) @executable_path/Frameworks @executable_path/../../Frameworks
```

Riêng `HaruWatchWidgetExtension`: như trên nhưng `SDKROOT = watchos`,
`WATCHOS_DEPLOYMENT_TARGET = 10.0`, `TARGETED_DEVICE_FAMILY = 4`,
`INFOPLIST_FILE = Config/HaruWatchWidget-Info.plist`,
`CODE_SIGN_ENTITLEMENTS = Config/HaruWatchWidget.entitlements`, và thêm một
mức `@executable_path/../../../../Frameworks` vào `LD_RUNPATH_SEARCH_PATHS`.

> Mọi `.plist` và `.entitlements` đều nằm trong `Config/`, không nằm trong thư mục
> synchronized nào — nếu không thì mỗi target lại dính đúng lỗi
> `Multiple commands produce ... Info.plist` (xem mục 0).

---

## 5. Tài nguyên dữ liệu

`Tools/build_vocab.py` ghi **thẳng vào `Shared/Resources/`**: `vocab.json` (2,0 MB) và
`grammar.json` (45 KB). Không có bước copy tay, và không có hai bản lệch nhau trong repo.

```bash
python -E -P Tools/build_vocab.py data/raw Shared/Resources
```

**Watch dùng chung `vocab.json` với iPhone.** Bản rút gọn `vocab-watch.json` từng được
dự tính đã bỏ: 2 MB không phải vấn đề với Watch. Thứ nặng là nghĩa của từ trong 11 ngôn
ngữ, và thứ đó đã được giải quyết bằng cách chỉ gửi sang Watch một ngôn ngữ (mục 3).

---

## 6. Hai file dữ liệu phải để riêng

`krdict_glosses.json` mang giấy phép **CC BY-SA 2.0 KR**, khác với phần còn lại (KOGL-1).
Nó phải là **một file riêng, nội dung nguyên vẹn không sửa**, kèm ghi nguồn và ghi license
ngay trong file. Không được trộn nội dung KRDict vào `vocab.json` hay `deck_content.json`.

Lý do đầy đủ ở SCOPE.md mục 3.1 và `data/ATTRIBUTION.md`. Tóm tắt: ShareAlike chỉ áp cho
tác phẩm phái sinh, và bản 2.0 KR nói rõ tác phẩm hợp thành một 편집저작물 không tính là
phái sinh — nên cấu trúc hợp tuyển giữ phần của bạn ngoài tầm SA. Sửa nội dung KRDict là
phá cấu trúc đó.

---

## 7. Capabilities

Bật trong tab *Signing & Capabilities*:

| Capability | Haru | Watch App | Widget | Watch Widget |
|---|:--:|:--:|:--:|:--:|
| App Groups — `group.pt.team.haru` | ✓ | ✓ | ✓ | ✓ |
| In-App Purchase | ✓ | ✓ | — | — |

App Group phải **giống hệt nhau ở cả bốn**, nếu lệch một ký tự thì widget và Watch
đọc không thấy tiến độ, mà không báo lỗi gì cả.

`Products.storekit` ở gốc repo, cùng khuôn với app #1, đã gán sẵn vào scheme `Haru` và
`Haru Watch App` (*Edit Scheme → Run → Options → StoreKit Configuration*): chạy Simulator là
mua thử được. Thông số từng gói và cách test ở [app-store-products.md](app-store-products.md).

---

## 8. Trình tự bấm trong Xcode

Không còn cần nữa: bốn target đã được ghi vào `project.xcproj`. Việc phải làm trên Mac
chỉ còn các bước ở **mục 0, "Lần đầu mở trên Mac"**.

---

## 9. Checklist xác minh sau khi dựng xong

- [ ] Bốn target build sạch, không warning về thiếu file
- [ ] `INFOPLIST_KEY_CFBundleDisplayName` là `Haru` ở **cả bốn** target, không còn `Notched`
- [ ] App Group giống hệt nhau ở cả bốn target
- [ ] `vocab.json` có trong bundle iOS, **không** có trong bundle widget
  (kiểm bằng *Build Phases → Copy Bundle Resources* của từng target)
- [ ] `vocab.json` có trong bundle Watch, `krdict_glosses.json` thì **không**
- [ ] `PrivacyInfo.xcprivacy` có ở gốc bundle của cả bốn target (file nằm ở `Core/` — mục 0)
- [ ] Chạy Watch app trên simulator, ép `AVSpeechSynthesizer` giọng `ko-KR` —
      **đây là rủi ro số 5 của SCOPE, phải kiểm ở tuần 1**, không để tới lúc dựng UI Watch
- [ ] Mở `Products.storekit` trong scheme, mua thử, kiểm `ProAccess` nhận đúng entitlement

---

## 10. Ghi chú về định dạng project

App #1 dùng định dạng project **JSON mới của Xcode 26** — bên trong
`TinnitusRelief.xcodeproj/` là `project.xcproj` (JSON), không phải `project.pbxproj`
(OpenStep) kiểu cũ. Định dạng này đọc và sửa tay được, nên nếu sau này muốn thì có thể
sinh thẳng file project thay vì add tay.

Repo app #1 còn một file `project.yml` của XcodeGen nhưng **nó không được dùng** —
đừng tham chiếu nó, nó không phản ánh cấu hình thật.

Schema tóm tắt, phòng khi cần sửa tay:

```jsonc
{
  "default-configuration": "Release",
  "configurations": ["Debug", "Release"],
  "localizations": { "development": "en", "supported": ["Base"] },
  "files": [ { "kind": "group", "path": "...", "children": [
      { "path": "Foo.swift", "target-membership": ["Haru/compile-sources"] } ] } ],
  "targets": [ { "name": "Haru", "id": "<24 hex>", "product": "Products/Haru.app",
                 "product-type": "application", "build-phases": [...],
                 "build-settings": {...}, "dependencies": [...] } ],
  "build-settings": { }
}
```

`localizations.supported` hiện là `["Base"]`. Khi thêm 11 ngôn ngữ (SCOPE 4.2) thì
danh sách này phải liệt kê đủ mã ngôn ngữ, và `Localizable.xcstrings` phải có đủ cột.
