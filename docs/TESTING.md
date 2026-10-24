# اختبار OpenBR على Android

هذا الملف يفصل بين **ما تم التحقق منه فعليًا** و**ما ينتظر جهازًا حقيقيًا**.
لا تعتبر أي بند مكتملًا قبل تسجيل النتيجة في الجدول أسفل الصفحة.

## 1) الحالة الحالية

آخر تحديث: 2026-10-24.

| البند | الحالة | الدليل |
|---|---|---|
| بناء debug APK | ✅ تم | `build/OpenBR.apk`، توقيع `CN=Android Debug` |
| بناء release APK | ✅ تم | `build/OpenBR-release.apk`، توقيع `CN=OpenBR`، APK v1/v2/v3 |
| بناء release AAB | ✅ تم | `build/OpenBR-release.aab`، `bundletool validate` exit 0 |
| `org.openbr.game` + `targetSdk 34` + ARM64 + `INTERNET` | ✅ تم | `aapt dump badging` |
| minSdk للـAPK | ✅ 21 | `aapt dump badging` |
| minSdk للـAAB | ✅ 21 | `bundletool dump manifest` |
| خلو APK/AAB من `server/` و`matchmaker/` | ✅ تم | فحص محتويات الحزمة |
| تحميل خريطة Verdant Reach headless | ✅ تم | `map: VERDANT REACH built (9 spawn markers)` |
| تصادم spawn/loot | ✅ 0 | فحص `PhysicsDirectSpaceState3D` |
| loot + healing | ✅ تم | `BANDAGE +2`، `HP 60 → 85` |
| storm | ✅ تم | `54 → 38 → 22 → 10m` |
| combat | ✅ تم | `Rifle 26 / 90 RELOADING...` |
| **لمس فعلي على هاتف** | ⛔ لم يُختبر | لا يوجد جهاز متصل؛ `adb devices -l` فارغ |
| **لعب LAN من الهاتف** | ⛔ لم يُختبر | يحتاج هاتفًا على نفس شبكة الـPC |
| **تثبيت AAB على Android 5/6** | ⛔ لم يُختبر | يحتاج جهاز/محاكي API 21–23 |

> الخريطة واللعب واللمس تم اختبارها على سطح المكتب فقط. لا تدّعِ دعم Android 5/6
> عمليًا حتى تُسجّل نتيجة جهاز حقيقي أو محاكي API 21.

### محاولة المحاكي على جهاز التطوير

تم تنزيل Android Emulator 37.2.12 ومحاولة تشغيل صور API 21:

- `arm64-v8a`: رفض المحاكي (`QEMU2 emulator does not support arm64 CPU architecture`).
- `armeabi-v7a`: رفض المحاكي (`CPU Architecture 'arm' is not supported`).
- `x86_64` يحتاج `Android Emulator hypervisor driver` أو WHPX، وليسا مثبتين،
  وتثبيتهما يحتاج صلاحيات مدير وإعادة تشغيل.

لذلك لا يوجد بديل عن هاتف حقيقي (أو جهاز تطوير مع WHPX مفعّل) لإتمام هذا البند.
تم أيضًا تشغيل العميل على Windows بـ`--touch` والتقاط صورة تؤكد ظهور الـjoystick
وأزرار `FIRE/JUMP/RELOAD/SWAP/LOOT/BAND/MED` والـHUD، لكن هذا يتحقق من الـlayout
والمدخلات على سطح المكتب فقط، وليس من سلوك Android الفعلي.

## 2) تجهيز الهاتف

1. افتح **Settings > About phone** واضغط **Build number** سبع مرات.
2. من **Developer options** فعّل **USB debugging**.
3. وصّل الهاتف بكابل USB واقبل بصمة RSA.
4. تأكد من الظهور:

```powershell
adb devices -l
```

يجب أن يظهر جهاز بحالة `device` وليس `unauthorized` أو `offline`.
إن ظهر `unauthorized`، افتح الهاتف واقبل الرسالة.

## 3) تشغيل سكربت الاختبار

من جذر المشروع:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/android-device-test.ps1
```

السكربت:

- يبحث عن `adb` عبر `ANDROID_HOME` أو المسار المحلي المعروف.
- يلغي تثبيت `org.openbr.game` أولًا لتجنّب تعارض توقيع debug/release.
- يثبّت `build/OpenBR.apk` ويشغّل `com.godot.game.GodotApp`.
- يجمع طراز الجهاز، إصدار Android، ABI، ودقة الشاشة.
- يأخذ screenshot وlogcat في `build/device-test-<timestamp>/`.

لاختبار نسخة release:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/android-device-test.ps1 -ApkPath build/OpenBR-release.apk
```

للتحقق من التثبيت فقط دون إعادة تثبيت:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/android-device-test.ps1 -SkipInstall
```

## 4) قائمة الاختبار اليدوي

### أ. الإقلاع والاتجاه

- [ ] التطبيق يفتح دون crash.
- [ ] الشاشة **landscape** ومليئة دون شريط نظام دائم.
- [ ] لوبي/شاشة الاتصال تعمل باللمس، ولوحة المفاتيح تظهر عند إدخال IP.
- [ ] زر الرجوع في Android لا يغلق اللعبة فجأة أثناء match.

### ب. التحكم باللمس

منطقة التحكم تغطي الشاشة:

- النصف الأيسر السفلي: **joystick ديناميكي** للحركة.
- السحب في أي مكان آخر: **تدوير الكاميرا**.
- الأزرار اليمنى: `FIRE`، `JUMP`، `RELOAD`، `SWAP`، `LOOT`، `BAND`، `MED`.

- [ ] سحب الإصبع من اليسار للأسفل/الأعلى يحرّك اللاعب في الاتجاه الصحيح.
- [ ] رفع الإصبع يوقف الحركة فورًا.
- [ ] السحب بإصبع ثانٍ يدوّر الكاميرا أثناء الحركة.
- [ ] `FIRE` يطلق ويستهلك الذخيرة ويظهر tracer.
- [ ] `JUMP` يعمل مرة واحدة لكل ضغطة.
- [ ] `RELOAD` يعيد التذخير ويظهر `RELOADING...`.
- [ ] `SWAP` يبدّل السلاح.
- [ ] `LOOT` يلتقط العنصر القريب.
- [ ] `BAND` و`MED` يبدآن العلاج ويظهر `USING ...`.
- [ ] الضرر أو الإطلاق يلغي العلاج.
- [ ] بعد تغيير الاتجاه أو العودة من الخلفية لا تبقى الحركة عالقة.

### ج. اللعب والـHUD

- [ ] HP، armor، kills، storm، weapon/ammo، inventory تظهر وتتحدث.
- [ ] loot prompt يظهر عند الاقتراب: `LOOT  BANDAGE   [E]` (أو زر LOOT).
- [ ] العلاج يرفع HP بالقيم الصحيحة: bandage ‎+25‎، medkit ‎+60‎.
- [ ] armor يمتص 55% من ضرر السلاح، والعاصفة تتجاوز armor.
- [ ] storm يبدأ عند 54m ويتقلص حسب المراحل.
- [ ] الموت والإقصاء وrespawn يعملان.
- [ ] HUD يظهر `VERDANT REACH`.

### د. الشبكة LAN

على الـPC:

```powershell
godot --headless --path . res://server/main.tscn -- --dev-auth --bots=0
```

- [ ] الخادم يطبع `OpenBR server listening on udp/7777`.
- [ ] افتح UDP 7777 في Windows Firewall (أو استخدم `scripts/open-firewall.bat`).
- [ ] الهاتف والـPC على نفس شبكة Wi-Fi (تجنّب Guest/AP isolation).
- [ ] أدخل IP الـPC (مثل `192.168.1.10`)، port `7777`، token `dev`.
- [ ] يظهر اللاعب في الخريطة ويتحرك دون rubber-banding شديد.
- [ ] لاعب ثانٍ (bot أو PC) يظهر ويتحرك بسلاسة.
- [ ] إطلاق النار والضرر والإقصاء تظهر على الطرفين.
- [ ] فصل Wi-Fi ثم إعادته يعطي رسالة واضحة دون تعليق اللعبة.

### هـ. الاستقرار

- [ ] 15 دقيقة لعب متواصل دون crash أو تسريب ذاكرة واضح.
- [ ] العودة من الخلفية (Home ثم فتح التطبيق) تعمل.
- [ ] إغلاق الشاشة وفتحها لا يكسر اللمس.
- [ ] الحرارة/الأداء مقبولان على جهاز mid-range.

## 5) اختبار AAB على Android 5/6

الـAAB ليس ملف تثبيت مباشر. لاختبار minSdk 21:

```powershell
java -jar bundletool-all.jar build-apks `
  --bundle=build/OpenBR-release.aab `
  --output=build/OpenBR-release.apks `
  --mode=universal `
  --ks=D:\tagriba2\openbr-keys\openbr-release.keystore `
  --ks-key-alias=openbr `
  --ks-pass=pass:<PASSWORD>

java -jar bundletool-all.jar install-apks --apks=build/OpenBR-release.apks
```

ثم:

```powershell
adb shell getprop ro.build.version.sdk
adb shell dumpsys package org.openbr.game | Select-String "minSdk|targetSdk|versionName"
```

- [ ] التثبيت نجح على API 21–23.
- [ ] التطبيق يفتح ويصل إلى اللوبي.
- [ ] لعبة سريعة تعمل دون crash.

> لا تضع كلمة سر keystore في Git أو في سجل CI. استخدم متغير بيئة محليًا.

## 6) سجل النتائج

املأ صفًا لكل جهاز/محاكي:

| التاريخ | الجهاز | Android / API | ABI | APK/AAB | الاتجاه | اللمس | LAN | الملاحظات |
|---|---|---|---|---|---:|---|---|---|
| — | — | — | — | — | — | — | — | لم يُختبر بعد |

عند وجود فشل، أرفق:

- `build/device-test-<timestamp>/device-info.txt`
- `screen.png`
- `logcat-godot.txt`
- خطوات إعادة الإنتاج
