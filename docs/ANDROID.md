# OpenBR على Android (APK / AAB)

هذا الدليل يشرح بناء **العميل فقط** لـAndroid. الخادم وخدمة الـmatchmaker لا يدخلان في
الـAPK/AAB؛ يبقيان على PC/VPS (أو Docker).

> الحالة: تم بناء debug APK وrelease APK وrelease AAB محليًا باستخدام Godot 4.4.1،
> Android SDK 34، وJDK 17 كامل، وتم التحقق من التوقيع/البنية. **اللعب الفعلي على
> الهاتف** (لمس + LAN) لم يُختبر بعد بشكل كامل.

---

## 0) المخرجات الحالية

| الملف | الحجم | SHA-256 | ملاحظات |
|---|---:|---|---|
| `build/OpenBR.apk` | 27,231,037 | `00843682783F963C5E8D007D2FA685892B419C1C91406D42F96D462C8F80788A` | debug، `CN=Android Debug`، minSdk 21 |
| `build/OpenBR-release.apk` | 25,703,272 | `2FB4E6AD07CB2A39AA94631C4CE4DBA60F4E8D9353A2C9C259B741376035EB96` | release، `CN=OpenBR`، APK v1/v2/v3، minSdk 21 |
| `build/OpenBR-release.aab` | 25,639,580 | `3330EAB3C497C8EEF7782B46954059DAF0D610A091F513E67F7C24639B18AE25` | release، `CN=OpenBR`، `bundletool validate` exit 0، minSdk 21 |

كل المخرجات: `org.openbr.game`، الإصدار `0.1.0`، `targetSdk 34`، ARM64 فقط،
وصلاحية `INTERNET`. نسخة release غير debuggable.

---

## 1) المتطلبات

| الأداة | الإصدار / ملاحظة |
|---|---|
| Godot | 4.4+ (استُخدم 4.4.1) مع **Android Export Templates** |
| JDK | **17 كامل** (ليس JRE) — يجب أن يحتوي `bin/instrument.dll` لبناء AAB |
| Android SDK | `platform-tools` + `build-tools;34.0.0` + `platforms;android-34` |
| ADB | ضمن `platform-tools` |
| Gradle | يأتي مع Android build template (لا تحتاج تثبيتًا منفصلًا) |

في Godot: `Editor > Manage Export Templates > Download and Install`.

> تحذير: بعض حزم JDK المختصرة تحتوي `java.instrument` في الوحدات لكنها تفتقد
> `bin/instrument.dll`. هذا يجعل Gradle يفشل بـ:
> `Could not find agent library instrument` أو
> `NoClassDefFoundError: org/slf4j/LoggerFactory`. استخدم JDK 17 كاملًا
> (مثل Temurin/Adoptium JDK) وليس JRE.

في `Editor > Editor Settings > Export > Android` اضبط:

- `Android SDK Path` = مسار Android SDK (مثال `%LOCALAPPDATA%\Android\Sdk`).
- `Java SDK Path` = مسار JDK 17 الكامل.
- `Debug Keystore` = `%USERPROFILE%\.android\debug.keystore` (أو اتركه للافتراضي).

على جهاز البناء الحالي استُخدم:

- Android SDK: `C:\Users\AISOU\AppData\Local\Temp\opencode\openbr-tools\android-sdk`
- JDK 17 كامل: `C:\Users\AISOU\AppData\Local\Temp\opencode\openbr-tools\jdk17-full\jdk-17.0.20.1+1`

تثبيت حزم SDK (من `cmdline-tools/latest/bin`):

```powershell
sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34" "cmdline-tools;latest"
```

### مفتاح debug

إن لم يكن موجودًا:

```powershell
keytool -genkeypair -v `
  -keystore "$env:USERPROFILE\.android\debug.keystore" `
  -storepass android -alias androiddebugkey -keypass android `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -dname "CN=Android Debug,O=Android,C=US"
```

---

## 2) إعداد المشروع

- `project.godot`:
  - `renderer/rendering_method.mobile="gl_compatibility"`.
  - `display/window/handheld/orientation=4` (sensor landscape).
  - `display/window/stretch/aspect="expand"`.
  - `input_devices/pointing/emulate_mouse_from_touch=true`.
  - `rendering/textures/vram_compression/import_etc2_astc=true` (مطلوب للتصدير).
- الأيقونة: `assets/icon.svg` عبر `application/config/icon`.

### البريسيتان

`export_presets.cfg` المحلي يحتوي بريسيتين:

| Preset | الناتج | Gradle | الاستخدام |
|---|---|---|---|
| `Android` | `build/OpenBR.apk` | لا | debug/release APK |
| `Android AAB` | `build/OpenBR-release.aab` | نعم | Google Play / AAB |

`export_presets.cfg` **مستثنى من Git** لأنه يحتوي مسار keystore وكلمة السر.
عند الاستنساخ:

```powershell
Copy-Item export_presets.cfg.example export_presets.cfg
```

ثم عدّل `keystore/release` و`keystore/release_user` و`keystore/release_password`
في النسخة المحلية فقط. القيم في `export_presets.cfg.example` فارغة.

### تثبيت Android build template

مرة واحدة (ينشئ `android/build/`، وهو مستثنى من Git):

```powershell
godot --headless --path . --install-android-build-template `
  --export-debug "Android" build/OpenBR.apk
```

هذا الأمر يثبّت القالب ثم يصدّر debug APK. يمكنك لاحقًا استخدام أوامر التصدير
العادية. بناء AAB لا يعمل بدون هذا القالب.

---

## 3) مفتاح release

مفتاح release **خارج المشروع**:

- المسار المحلي: `D:\tagriba2\openbr-keys\openbr-release.keystore`
- alias: `openbr`
- كلمة السر: `D:\tagriba2\openbr-keys\keystore-password.txt`
- README: `D:\tagriba2\openbr-keys\README.txt`

إنشاء مفتاح جديد (مرة واحدة فقط؛ لا تفعل هذا بعد النشر إن أردت تحديث نفس الحزمة):

```powershell
keytool -genkeypair -v `
  -keystore "D:\tagriba2\openbr-keys\openbr-release.keystore" `
  -storetype PKCS12 -alias openbr `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -dname "CN=OpenBR, OU=OpenBR, O=OpenBR, L=Local, ST=Local, C=US"
```

ثم في `export_presets.cfg` المحلي:

```ini
keystore/release="D:/tagriba2/openbr-keys/openbr-release.keystore"
keystore/release_user="openbr"
keystore/release_password="<كلمة-السر>"
```

- **احتفظ بنسخة احتياطية آمنة**؛ فقدان المفتاح يمنع تحديث `org.openbr.game` على Play.
- لا ترفع المفتاح أو كلمة السر إلى Git، ولا تضعها في الـAPK/AAB.
- الشهادة self-signed (`CN=OpenBR`)؛ `jarsigner` قد يطبع
  `Invalid certificate chain: PKIX path building failed`. هذا متوقع وليس فشل توقيع.
- Google Play سيستخدم **Play App Signing** عند الرفع؛ المفتاح المحلي يُستخدم كـupload key.

---

## 4) بناء APK

```powershell
# debug APK (للاختبار)
godot --headless --path . --export-debug "Android" build/OpenBR.apk

# release APK (يتطلب keystore في export_presets.cfg)
godot --headless --path . --export-release "Android" build/OpenBR-release.apk
```

### التحقق

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"  # عدّل المسار
& "$sdk\build-tools\34.0.0\apksigner.bat" verify --verbose --print-certs build/OpenBR-release.apk
& "$sdk\build-tools\34.0.0\aapt.exe" dump badging build/OpenBR-release.apk
```

يجب أن يظهر:

- `Verifies`.
- `Verified using v1/v2/v3 scheme: true`.
- `Signer #1 certificate DN: CN=OpenBR` لنسخة release، أو `CN=Android Debug` للـdebug.
- `package: name='org.openbr.game'`.
- `sdkVersion:'21'` و`targetSdkVersion:'34'`.
- `native-code: 'arm64-v8a'`.
- `uses-permission: name='android.permission.INTERNET'`.

---

## 5) بناء AAB (Google Play)

يستخدم بريسيت `Android AAB` مع Gradle:

```powershell
godot --headless --path . --export-release "Android AAB" build/OpenBR-release.aab
```

ملاحظات مهمة:

- يجب تثبيت Android build template أولًا (القسم 2).
- يجب أن يكون `Java SDK Path` هو JDK 17 الكامل (فيه `bin/instrument.dll`).
- Godot قد يبدو **معلّقًا** بعد إنشاء الـAAB. تحقق من وجود الملف، ثم أوقف العملية
  إن لزم. الملف يظهر عادة في `build/OpenBR-release.aab`.
- لا تخلط بين `export_format=0` (APK) و`export_format=1` (AAB).

### التحقق من AAB

```powershell
# توقيع JAR (AAB موقّع بـv1 JAR signing من Gradle)
jarsigner -verify -verbose -certs build/OpenBR-release.aab

# التحقق من بنية bundle (نزّل bundletool-all من GitHub Releases)
java -jar bundletool-all.jar validate --bundle=build/OpenBR-release.aab
java -jar bundletool-all.jar dump manifest --bundle=build/OpenBR-release.aab
```

`bundletool` standalone: <https://github.com/google/bundletool/releases>.

النتيجة المحلية: `bundletool validate` أعاد **exit 0**، والـAAB يحتوي:

- وحدة `base`.
- `base/dex/classes.dex`.
- `base/lib/arm64-v8a/libgodot_android.so`.
- `base/manifest/AndroidManifest.xml`.
- asset pack من نوع `installTime` (سلوك قالب Godot).

### minSdk

- APK: **minSdk 21**.
- AAB: **minSdk 21** بعد ضبط `gradle_build/min_sdk="21"` و
  `gradle_build/target_sdk="34"` في بريسيت `Android AAB`.

تم التحقق من manifest الـAAB بـ`bundletool`:
`android:minSdkVersion="21"` و`android:targetSdkVersion="34"`.
يبقى اختبار التثبيت على جهاز Android 5/6 فعلي مطلوبًا قبل الاعتماد على هذا النطاق.

---

## 6) التثبيت على الهاتف والتبديل بين النسخ

```powershell
adb devices
adb install -r build/OpenBR-release.apk
adb logcat | Select-String "godot"
```

- توقيع debug يختلف عن توقيع release. قبل التبديل بينهما:

```powershell
adb uninstall org.openbr.game
```

- `adb install -r` لا ينجح إذا كانت النسخة المثبتة موقّعة بمفتاح مختلف.
- بعد التثبيت، اختر الشخصية وخصّص الألوان/الملابس في اللوبي ثم اضغط **DEPLOY**،
  وأدخل بيانات الخادم في شاشة الاتصال. المظهر يُحفظ في `user://profile.cfg`.

---

## 7) الاختبار عبر الشبكة المحلية (LAN)

1. شغّل الخادم على PC (مع بوتات اختيارية):

```powershell
godot --headless --path . res://server/main.tscn -- `
  --port=7777 --dev-auth --bots=3
```

2. اعرف عنوان PC:

```powershell
ipconfig
# خذ IPv4 مثل 192.168.1.10
```

3. افتح UDP 7777 في جدار الحماية (مرة واحدة، PowerShell كمسؤول):

```powershell
netsh advfirewall firewall add rule name="OpenBR UDP 7777" dir=in action=allow protocol=UDP localport=7777
```

4. يجب أن يكون الهاتف وPC على نفس شبكة Wi-Fi، وأن يكون **AP isolation** مغلقًا.

5. في التطبيق:

- **Server host**: `192.168.1.10`
- **Port**: `7777`
- **Join token**: `dev` (فقط مع `--dev-auth`)

> `127.0.0.1` داخل الهاتف يعني الهاتف نفسه، وليس PC.

---

## 8) التحكم باللمس

- **Joystick**: اسحب في النصف الأيسر السفلي — يظهر تحت إبهامك (dynamic).
- **Look**: اسحب في أي مكان آخر (نصف الشاشة الأيمن عادة).
- **FIRE**: زر أحمر أسفل يمين — طلقة لكل ضغطة.
- **RELOAD**: فوق FIRE — إعادة تلقيم.
- **SWAP**: يسار RELOAD — تبديل السلاح (Rifle → SMG → Shotgun).
- **JUMP**: زر أزرق أسفل اليسار من FIRE.
- **LOOT**: أعلى أزرار اليمين — التقاط العنصر القريب (يظهر prompt باسمه).
- **BAND / MED**: أزرار Bandage / Medkit — استخدام عنصر علاج.
- على PC: `godot --path . -- --touch`.

الأسلحة الحالية: Rifle (25 ضرر، 30/90)، SMG (16 ضرر، 35/105)،
Shotgun (12×6 pellets، 6/24). الذخيرة والضرر وإعادة التلقيم على الخادم.

### Loot والدرع والعلاج على الهاتف

- توجد **69 نقطة loot** ثابتة في `shared/loot.gd`، وbandage قرب كل spawn من نقاط
  Verdant Reach التسع.
- عند الاقتراب يظهر `LOOT  <ITEM>  [E]`؛ على الهاتف اضغط **LOOT**.
- **ARMOR** يظهر في أعلى اليسار (`ARMOR x / 100`) ويمتص 55% من ضرر الأسلحة؛
  ضرر العاصفة يتجاوز الدرع.
- **BANDAGE** (25 HP / 2s) و**MEDKIT** (60 HP / 4s) يظهر عددهما في الـHUD،
  واستخدامهما يستهلك العنصر فورًا. أي ضرر أو إطلاق نار يلغي العلاج.
- الـHUD يعرض `BANDAGE xN   MEDKIT xN` و`USING ... x.xs`.
- الـrespawn يعيد الدرع والـconsumables إلى الصفر، لكن العناصر المأخوذة تبقى
  مأخوذة في المباراة. كل التحقق من المسافة والكمية والضرر يتم على الخادم.

---

## 9) التوكن من الـmatchmaker

شغّل الخدمة على PC:

```powershell
cd server/matchmaker
$env:BR_SECRET = "ضع-سرًا-طويلًا-هنا"
$env:GAME_SERVERS = "192.168.1.10:7777"
go run .
```

اطلب مباراة:

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:8080/v1/match `
  -ContentType "application/json" `
  -Body '{"player_id":"phone1","region":"me"}'
```

انسخ `token` والصقه في **Join token**. التوكن صالح 5 دقائق.

> التطبيق لا يتصل بالـmatchmaker عبر HTTP حاليًا؛ الإدخال يدوي. عند إضافة جلب
> تلقائي لاحقًا استخدم **HTTPS** (Android يمنع cleartext HTTP افتراضيًا).

---

## 10) GitHub Actions

workflow جاهز في `.github/workflows/android.yml` لبناء **debug APK** فقط.

المستودع المحلي مهيّأ على فرع `main` مع commit أول
(`086f2f0 Initial OpenBR prototype...`)، لكن **لم يُضف remote ولم يُدفع** بعد
لعدم وجود مصادقة GitHub على هذا الجهاز. بعد إضافة remote:

```powershell
git remote add origin https://github.com/<USER>/<REPO>.git
git push -u origin main
```

ثم:

1. **Actions** > **Android APK** > **Run workflow**.
2. نزّل artifact `OpenBR-android-debug`.
3. `adb install -r OpenBR.apk`.

الـworkflow يثبّت JDK 17 وGodot 4.4.1 + export templates وAndroid SDK، وينسخ
`export_presets.cfg.example`، ثم يصدّر debug APK.

> الـworkflow لا يملك مفاتيح release، ولا يبني AAB. لا تضع keystore أو كلمة السر
> في Git أو في أسرار الـworkflow إلا بعد فهم مخاطرها. الـworkflow نفسه لم يُشغّل
> على GitHub بعد؛ راجع سجل Actions إذا فشل أي step.

لاختبار جهاز فعلي، راجع [`docs/TESTING.md`](TESTING.md): يحتوي سكربت
`scripts/android-device-test.ps1` وقائمة اختبار اللمس وLAN وAndroid 5/6.

---

## 11) استكشاف الأخطاء

| المشكلة | الحل |
|---|---|
| `Android SDK path not configured` | اضبط `Android SDK Path` في Editor Settings |
| `Unable to open Android 'build-tools' directory` | ثبّت `build-tools;34.0.0` أو صحّح المسار |
| `Missing export templates` | نزّل Android templates من Manage Export Templates |
| `JDK not found` | اضبط JDK 17 كاملًا، وليس JRE |
| `Could not find agent library instrument` | الـJDK ناقص `bin/instrument.dll`؛ استبدله بـJDK 17 كامل |
| `NoClassDefFoundError: org/slf4j/LoggerFactory` | غالبًا JDK ناقص/Gradle تالف؛ استخدم JDK كامل وأعد المحاولة |
| فشل Gradle في أول بناء | تحقق من الإنترنت (تنزيل Gradle/AGP)، ومن `JAVA_HOME` |
| AAB لا يخرج من الأمر | تحقق من `build/OpenBR-release.aab` ثم أوقف Godot |
| `Cannot export ... configuration errors` | تأكد من `import_etc2_astc=true` ومن صحة preset |
| `No project icon specified` | أضف `application/config/icon` (مضبوط إلى `assets/icon.svg`) |
| `Trying to call an RPC ... not connected` | حارس `is_client_connected()` في `scripts/net.gd` |
| لا يوجد اتصال من الهاتف | UDP 7777، نفس الشبكة، AP isolation مغلق، IP صحيح |
| شاشة سوداء | استخدم `adb logcat` وتأكد من `gl_compatibility` |
| زر Connect مخفي تحت الكيبورد | اضغط Enter/Done في حقل التوكن، أو أغلق الكيبورد |
| `adb install` يفشل بعد تغيير التوقيع | `adb uninstall org.openbr.game` ثم أعد التثبيت |

---

## 12) ملاحظات أمان

1. **لا تضع `BR_SECRET` داخل الـAPK/AAB** ولا في `export_presets.cfg`؛ التوكن يُوقَّع
   على الخادم.
2. لا تستخدم `--dev-auth` في الإنتاج.
3. لا ترفع `export_presets.cfg` (يحتوي بيانات release keystore).
4. احتفظ بمفتاح release وكلمة السر خارج المشروع، وخذ نسخة احتياطية.
5. APK الموقّع بـdebug key للاختبار فقط.
6. لا توجد ميزات دفع/IAP في المشروع، ولا محاولة تجاوز مدفوعات أو anti-cheat.
