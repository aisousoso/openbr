# OpenBR

نموذج **Battle Royale مفتوح المصدر** مبني على Godot 4.4، بخادم سلطوي (server-authoritative)
وشبكة ENet، مع خدمة matchmaking بلغة Go. الرخصة MIT، والأصول المقترحة CC0.
الخريطة الأصلية الحالية هي **Verdant Reach**: 120×120 متر و9 مناطق بيئية مختلفة.

> هذا مشروع أصلي. لا تستخدم أصول Free Fire أو أسماءها أو خرائطها — النوع (Battle Royale)
> غير محمي، لكن الأصول المحددة محمية بحقوق النشر.
>
> لا يحتوي المشروع على أي تخطٍّ للمدفوعات (IAP bypass)، أو فتح سكنات مدفوعة، أو evasion
> لأنظمة anti-cheat، أو تعديل APK تجاري. لا توجد ميزات دفع في هذا النموذج.

---

## المتطلبات

| الأداة | الإصدار |
|---|---|
| Godot | 4.4+ (ويفضّل 4.4.1) |
| Go | 1.22+ (للـmatchmaker) |
| Docker | اختياري |
| Git | أي إصدار |

لبناء APK/AAB إضافيًا تحتاج **JDK 17 كاملًا** (ليس JRE) و**Android SDK** — التفاصيل في
[`docs/ANDROID.md`](docs/ANDROID.md). بناء AAB يحتاج أيضًا **Android build template** وGradle.

---

## التشغيل السريع

### 1) الخادم (Headless)

```bash
godot --headless --path . res://server/main.tscn -- --port=7777 --dev-auth
```

`--dev-auth` يقبل التوكن `dev` فقط للتطوير المحلي. **لا تستخدمه في الإنتاج.**

لإضافة بوتات اختبار على الخادم (0–16 بوتًا، كلها server-only):

```bash
godot --headless --path . res://server/main.tscn -- --port=7777 --dev-auth --bots=3
```

الخادم يبدأ في طور **WAITING** ولا تبدأ الجولة حتى يضغط لاعب حقيقي **READY**
(أو حتى يتحقق `--auto-start`). معاملات دورة المباراة:

| المعامل | الافتراضي | الوظيفة |
|---|---:|---|
| `--min-players=N` | `2` | عدد اللاعبين (بشر + بوتات) المطلوب لبدء الجولة |
| `--countdown=N` | `8` | ثواني العد التنازلي قبل `LIVE` |
| `--end-delay=N` | `10` | ثواني عرض النتيجة قبل العودة إلى اللوبي |
| `--auto-start` | معطّل | تجاهل READY (للاختبارات؛ يظل يحتاج لاعبًا حقيقيًا واحدًا) |
| `--dev-respawn` | معطّل | إعادة respawn بعد 3s (وضع اختبار قديم فقط) |

مثال جولة اختبار سريعة بدون انتظار:

```bash
godot --headless --path . res://server/main.tscn -- `
  --port=7777 --dev-auth --bots=3 --auto-start --countdown=0 --min-players=2
```

> إذا لم يكن `godot` مضافًا إلى `PATH` على Windows، استخدم المسار الكامل لملف
> `Godot_v4.4.1-stable_win64_console.exe` بدلًا من `godot`.

### 2) العميل

```bash
godot --path . -- --host=127.0.0.1 --port=7777 --token=dev
```

أو شغّل بدون أي معاملات لتظهر **شاشة اللوبي واختيار الشخصية** أولًا، ثم زر **DEPLOY**
يفتح شاشة الاتصال (Host / Port / Token)، وهي الطريقة المستخدمة على Android:

```bash
godot --path .
```

> من شاشة الاتصال يمكنك الرجوع إلى اللوبي بزر **Change operator** لتغيير الشخصية أو
> الألوان قبل المحاولة مرة أخرى.

لاختبار القتال: افتح Terminal آخر ونفّذ نفس الأمر (عميل ثانٍ). كلاهما سيرى الآخر.

### 3) التحكم

| المفتاح | الوظيفة |
|---|---|
| WASD | الحركة |
| Space | قفز |
| زر الفأرة الأيسر | إطلاق النار |
| Mouse | النظر |
| 1 / 2 / 3 | اختيار Rifle / SMG / Shotgun |
| R | إعادة التلقيم (reload) |
| E | التقاط الـloot القريب |
| 4 / 5 | استخدام Bandage / Medkit |
| Esc | تحرير/إمساك المؤشر |
| Joystick (لمس) | الحركة — اسحب في النصف الأيسر السفلي |
| Drag (لمس) | النظر |
| FIRE / JUMP | إطلاق النار / القفز |
| RELOAD / SWAP | إعادة التلقيم / تبديل السلاح (لمس) |
| LOOT / BAND / MED | التقاط الـloot / Bandage / Medkit (لمس) |

على الهاتف تظهر أزرار **FIRE** أسفل اليمين، و**RELOAD** فوقه، و**SWAP** يسار
RELOAD، و**JUMP** أسفل اليسار من FIRE، وأزرار **LOOT / BAND / MED** أعلى
الأزرار اليمنى. يظهر prompt `LOOT  <ITEM>  [E]` عندما تكون قريبًا من عنصر.

على PC يمكنك تجربة واجهة اللمس بـ`--touch`:

```bash
godot --path . -- --touch
```

### 4) دورة المباراة (Match Lifecycle)

الخادم يدير الحالات التالية، والعميل يعرضها فقط:

```
WAITING ──READY / auto-start──> COUNTDOWN ──> LIVE ──> ENDED ──> WAITING
```

- **WAITING:** اللوبي. الحركة والقتال والـloot والـstorm متوقفة. زر **READY**
  في لوحة المباراة، وعدد الجاهزين/اللاعبين ظاهر. البوتات جاهزة تلقائيًا، لكن
  يجب أن يكون لاعب بشري واحد على الأقل جاهزًا.
- **COUNTDOWN:** تجميد كامل وعد تنازلي. أي نقص في عدد اللاعبين يلغي العد
  ويعيد الخادم إلى `WAITING`.
- **LIVE:** جولة واحدة، **حياة واحدة**. لا respawn. العاصفة تبدأ فقط الآن.
  آخر لاعب/بوت حي يفوز، ويُسجَّل ترتيب كل مُقصى (`placement`).
- **ENDED:** إعلان `VICTORY` أو `ELIMINATED #N` مع اسم الفائز، ثم العودة
  التلقائية إلى اللوبي بعد `--end-delay`.
- **الانضمام المتأخر:** يُرفض أي مصادقة جديدة أثناء `COUNTDOWN` أو `LIVE`
  أو `ENDED` برسالة `match in progress`.
- **المُقصى:** يدخل **spectator mode** بكاميرا خلف لاعب حي، مع زر **NEXT**
  لتبديل الهدف وزر **LEAVE** للخروج، ويبقى kill feed يعمل.
- **إعادة المباراة:** بعد `ENDED` يعيد الخادم الجميع إلى اللوبي ويصفّر
  HP/armor/inventory/ammo/kills/loot/storm، ثم ينتظر READY من جديد.

### 5) قواعد القتال الحالية

- اللاعب يبدأ بـ**100 HP**؛ كل سلاح له ضرر ومعدل إطلاق ومدى وذخيرة مستقلة.
- في `LIVE` لا يوجد respawn؛ الموت = إقصاء نهائي. `--dev-respawn` يعيد سلوك
  3 ثوانٍ القديم للاختبار فقط.
- HUD يعرض اسم الخريطة، HP، عدد الإقصاءات، حالة العاصفة، والسلاح الحالي مع
  `mag / reserve` و`RELOADING...` أثناء إعادة التلقيم.
- أثر الرصاصة (tracer) يظهر لكل اللاعبين بلون مختلف لكل سلاح.
- **العاصفة (storm):** تبدأ بعد 25 ثانية، ثم تتقلص على 3 مراحل. من يبقى خارج
  الدائرة يتلقى ضررًا متزايدًا (2 / 4 / 6 / 8 HP/s)، والموت بسبب العاصفة يظهر
  في الـHUD باسم `the storm`. الخادم هو من يحسب الموقع والضرر، والعميل يرسم
  الجدار البنفسجي وحلقة الأرض فقط.

#### الأسلحة

| السلاح | الضرر | الفاصل بين الطلقات | المدى | المخزن / الاحتياط | إعادة التلقيم |
|---|---:|---:|---:|---:|---:|
| Rifle | 25 | 0.15s | 40m | 30 / 90 | 1.8s |
| SMG | 16 | 0.08s | 28m | 35 / 105 | 1.5s |
| Shotgun | 12 × 6 pellets | 0.8s | 20m | 6 / 24 | 2.2s |

- الطلقة تستهلك رصاصة من المخزن، ويُعاد التلقيم تلقائيًا عند فراغ المخزن، أو
  يدويًا بزر **R** / **RELOAD**.
- تبديل السلاح يستغرق `0.25s` على الخادم، ولا يمكن الإطلاق أثناء التبديل أو
  إعادة التلقيم.
- Shotgun يطلق 6 pellets؛ الضرر الأقصى 72 إذا أصابت كلها، والضرر يُحسب لكل
  pellet على حدة.
- الذخيرة والضرر ومعدل الإطلاق كلها **server-authoritative**؛ العميل يعرض فقط
  القيم القادمة في الـsnapshot.

### Loot + Inventory + Armor + Healing

- **Loot ثابت ومشترك:** `shared/loot.gd` يحتوي تعريفات العناصر و**69 نقطة spawn**
  ثابتة (ID من `0` إلى `68`)، موزعة على مناطق Verdant Reach. الخادم والعميل يقرآن
  نفس الملف، لذلك لا حاجة لإرسال مواقع الـloot كل tick. توجد bandage قريبة من كل
  نقطة spawn (9 نقاط) لبداية سريعة، وبعض العناصر داخل المباني أو على الأرصفة.
- **الالتقاط سلطوي:** العميل يرسل `request_loot(loot_id)` فقط. الخادم يتحقق من:
  اللاعب حي، العنصر غير مأخوذ، والمسافة ضمن `PICKUP_RADIUS = 2.6m` (مع tolerance
  صغير). ثم يطبّق العنصر ويبث `loot_taken` لكل اللاعبين. اللاعبون الذين يدخلون
  لاحقًا يستقبلون قائمة العناصر المأخوذة عبر `loot_state`.
- **العناصر الحالية:**

| العنصر | الكمية عند الالتقاط | الحد الأقصى | التأثير |
|---|---:|---:|---|
| Armor | +50 | 100 | يمتص **55%** من ضرر الأسلحة حتى ينفد |
| Bandage | +2 | 5 | يعالج **25 HP** خلال **2s** |
| Medkit | +1 | 3 | يعالج **60 HP** خلال **4s** |
| Ammo | +30 للسلاح الحالي و+15 لكل سلاح آخر | — | يضيف إلى `reserve` |

- **Armor:** ضرر العاصفة يتجاوز الدرع (`ignore_armor`)، وضرر الأسلحة فقط هو الذي
  يستهلك الدرع. يظهر `ARMOR x / 100` في الـHUD، ويتحول وميض الضرر إلى أزرق عندما
  يمتص الدرع الإصابة بالكامل.
- **Healing:** استخدام Bandage/Medkit يستهلك العنصر فورًا ويبدأ مؤقتًا على الخادم.
  عند اكتمال المؤقت يُضاف العلاج إلى HP. **أي ضرر أو إطلاق نار يلغي العلاج**،
  والعنصر يبقى مستهلكًا. الـHUD يعرض `USING BANDAGE/MEDKIT  x.xs`.
- **Inventory:** العدّادات موجودة في snapshot والـHUD (`BANDAGE xN   MEDKIT xN`).
  الالتقاط يفشل إذا كان العنصر ممتلئًا أو الدرع ممتلئًا، ويظهر سبب الرفض في رسالة
  قصيرة. بداية كل جولة (وبعد `ENDED`) تعيد الدرع والـconsumables والذخيرة إلى
  الصفر، وتعيد كل عناصر الـloot إلى الخريطة.
- **الأمان:** العميل لا يرسل HP أو armor أو عدد العناصر أو الضرر. كل هذه القيم
  تُحسب وتُخزَّن على الخادم، والـsnapshot يحمل الحقول الإضافية:
  `armor, bandage, medkit, heal_remaining, heal_type` بعد حقول المظهر.

اختبار dev-only للـloot والعلاج (خادم + عميل headless):

```powershell
# terminal 1
godot --headless --path . res://server/main.tscn -- `
  --port=7777 --dev-auth --bots=0 --test-loot --auto-start `
  --countdown=0 --min-players=1 --run-seconds=12

# terminal 2
godot --headless --path . -- `
  --host=127.0.0.1 --port=7777 --token=dev --test-loot --run-seconds=9
```

`--test-loot` على الخادم يخفض HP البداية إلى 60 فقط لاختبار العلاج، وعلى العميل
يلتقط bandage القريبة ثم يستخدمها ويطبع قيم الـHUD. لا يؤثر على اللعب العادي.

---

## اللوبي واختيار الشخصية (Lobby + Character Select)

التطبيق يبدأ الآن بـ**لوبي أصلي** قبل شاشة الاتصال:

```
Lobby / Character Select  ──DEPLOY──>  Connect (Host/Port/Token)  ──>  Match
        ^                                      │
        └────────── Change operator ───────────┘
```

- **12 شخصية أصلية** (Aster, Bram, Cyra, Dax, Eira, Fenn, Gale, Iris, Jax, Kira,
  Lumen, Mako) — أسماء وتصاميم وسِيَر من إنشاء المشروع، وليست من Free Fire.
- لكل شخصية **لوحة ألوان افتراضية** و**نمط ملابس** و**غطاء رأس** يميّز شكلها.
- التخصيص متاح للجميع دون دفع أو فتح سكنات:
  - **Primary / Secondary / Accent** عبر `ColorPickerButton`.
  - **Outfit**: Tactical / Hoodie / Armored / Runner — يغيّر شكل الجسم والملابس.
  - **Palette preset** جاهزة (Ember / Frost / Forest / Neon / Signal) + Reset + Randomize.
- **معاينة 3D** داخل `SubViewport` باستخدام نفس النموذج الإجرائي (low-poly) المستخدم
  داخل المباراة، مع إضاءة ومنصة دوّارة.
- الملف الشخصي يُحفظ محليًا في `user://profile.cfg`، ويُرسل مع المصادقة:
  `authenticate(token, appearance)`.
- الخادم ينظّف المظهر (`shared/characters.gd`) ويخزّنه ويضمّنه في snapshots، لذلك
  يرى اللاعبون الآخرون نفس الألوان/الملابس. المظهر **cosmetic فقط** ولا يغيّر
  الحركة أو hitbox أو الضرر.
- البوتات تحصل على ألوان وأنماط محددة تلقائيًا حتى لا تبدو نسخًا متطابقة.
- التشغيل المباشر بالمعاملات (`--host=...`) يتخطى اللوبي ويستخدم الملف المحفوظ.

> جميع الشخصيات والألوان والملابس أصلية. لا توجد أصول أو أسماء أو واجهات
> مستنسخة من أي لعبة تجارية.

---

## الخريطة والتصادم

الخريطة الوحيدة الآن: **Verdant Reach** في `maps/verdant_reach.tscn`.

- **120×120 متر** مع جدران محيطة وسطح تصادم واحد.
- **9 مناطق أصلية**، لكل منطقة بيئة وlandmarks ومواد وألوان مختلفة:
  - **Meridian Relay** — برج اتصالات مركزي ومنصة مرتفعة وramps وألواح شمسية.
  - **Aurora Yards** — ساحة صناعية بمستودع وcontainers وسايلوهات وcatwalk.
  - **Cinder Terrace** — بيوت terraced حجرية/طينية وسوق صغير وwater tower.
  - **Tideglass Shore** — أرصفة خشبية وماء ضحل وwarehouse ورافعة.
  - **Dune Chapel** — كنيسة رملية مهجورة وأقواس وصخور وبرج مكسور.
  - **Frostline Depot** — مستودع ثلجي وسايلوهات وصناديق وفences.
  - **Saltwind Docks** — أرصفة وماء وcontainers ورافعة على الحافة الشرقية.
  - **Hollow Grove** — غابة كثيفة وأشجار وأكوام خشب وكوخ حارس.
  - **Sunken Gardens** — wetlands وboardwalks وgreenhouse وplanters.
- **9 نقاط spawn** (`Marker3D`) موزعة على المناطق، يقرأها الخادم مباشرة.
- الأرض والطرق والمناطق والـprops تُبنى من `shared/map_data.gd` و
  `maps/verdant_reach.gd`، وتُحمَّل نفسها على العميل والخادم، لذلك التصادم متطابق:
  - العميل: `client/main.gd` يضيف `verdant_reach.tscn` تحت `World`.
  - الخادم: `server/main.gd` يضيف نفس المشهد، وينشئ `CharacterBody3D` لكل لاعب.
- كل `StaticBody3D` على طبقة التصادم `1`، والـloot موضوع في أماكن مفتوحة أو داخل
  مبانٍ يمكن دخولها.

أي تعديل على الخريطة يجب أن يبقى في `maps/verdant_reach.tscn` و
`maps/verdant_reach.gd` فقط (مصدر حقيقة واحد). لا تُضف تصادمًا للعميل فقط، وإلا
حدث desync. عند تغيير نقاط spawn، حدّث `shared/map_data.gd` و`SpawnPoints` معًا.

---

## إطلاق النار (Server-Authoritative)

```
Client  ──request_fire(aim_dir)──>  Server
Server: origin  = player_pos + (0, 1.65, 0)   # العميل لا يرسل موقعه
        weapon  = shared/weapons.gd[current]
        wall    = raycast(origin, pellet_dir, weapon.range, mask=1)
        hit     = nearest player sphere (r=0.6, center=pos+0.9)
        damage  = weapon.damage لكل pellet → death → placement + ENDED
Server ──send_shot(..., weapon) / apply_death / match_state / kill_feed──> Clients
```

- معدل الإطلاق والمدى والضرر وعدد pellets تُقرأ من `shared/weapons.gd` على الخادم.
- الجدران تحجب الرصاص فعليًا (الـraycast على طبقة العالم `1`).
- أجسام اللاعبين على طبقة `2`، ولا تتصادم مع بعضها (mask=1) لتفادي فرق العميل/الخادم.
- العميل يرسل اتجاه التصويب فقط؛ الخادم يحدد نقطة الانطلاق والإصابة.
- الخادم يخصم الرصاص ويبدأ إعادة التلقيم؛ لا يثق العميل بأي قيمة ذخيرة أو ضرر.

---

## الدائرة المتقلصة (Storm)

العاصفة **server-authoritative**: الخادم يحدّد المركز ونصف القطر والمرحلة والضرر،
ويُرسل الحالة مع كل snapshot. العميل لا يرسل أي قيمة تتعلق بالعاصفة.

| المرحلة | الانتظار | التقلص | نصف القطر | الضرر خارج الدائرة |
|---|---:|---:|---:|---:|
| 0 (بداية) | 25s | 22s | 54m → 38m | 2 HP/s |
| 1 | 12s | 16s | 38m → 22m | 4 HP/s |
| 2 | 10s | 12s | 22m → 10m | 6 HP/s |
| نهائي | — | — | 10m | 8 HP/s |

- المركز الحالي: `(0, 0)`، ونصف القطر الابتدائي `54m` (الخريطة 120×120).
- أثناء أول 25 ثانية لا يوجد ضرر؛ بعدها يُطبَّق الضرر كل ثانية تقريبًا.
- الموت بسبب العاصفة يستخدم `killer_id = 0`، ولا يزيد قتلات أي لاعب.
- العاصفة **لا تتحرك ولا تؤذي** إلا في طور `LIVE`؛ في `WAITING`/`COUNTDOWN`
  يرسل الخادم حالة فارغة ويخفي العميل الجدار.
- في `--dev-respawn` فقط يختار الـrespawn نقطة داخل الدائرة الحالية؛ في الجولة
  العادية لا يوجد respawn أصلًا.
- العميل يرسم جدارًا أسطوانيًا شفافًا + حلقة أرضية (`client/storm.tscn`)،
  ويُظهر حالة العاصفة في أعلى اليسار، مع تحذير أحمر عند الخروج من الدائرة.

للاختبار السريع محليًا (يُسرّع مؤقتات العاصفة 10× ويغلق الخادم بعد 25 ثانية):

```powershell
godot --headless --path . res://server/main.tscn -- `
  --port=7777 --dev-auth --storm-fast --dev-respawn --auto-start `
  --countdown=0 --min-players=1 --run-seconds=25
```

---

## البوتات (Bots للاختبار)

البوتات **server-only** ولا تدخل في الـAPK. تُشغَّل مع الخادم:

```bash
godot --headless --path . res://server/main.tscn -- `
  --port=7777 --dev-auth --bots=3
```

- العدد الأقصى `16` بوتًا (`--bots=N`).
- لكل بوت ID سالب (`-1`, `-2`, ...) ولا يملك اتصال ENet ولا يستقبل أي RPC.
- البوت يختار أقرب لاعب حقيقي، وإذا لم يوجد يختار أقرب بوت آخر.
- يتحرك نحو الهدف أو يبتعد/يتحرك جانبيًا حسب المسافة، ويتحقق من خط الرؤية
  بـraycast على طبقة العالم قبل الإطلاق.
- يستخدم نفس نظام الأسلحة والذخيرة والضرر وإعادة التلقيم، ويُمنح reserve كبيرًا
  (`999`) حتى لا تنتهي اختبارات طويلة ببوتات بلا ذخيرة.
- العملاء يرون البوتات كـremote players، ويستقبلون tracers وأحداث القتل.
  عند قتلك بوتًا تظهر `Eliminated a bot`، وعند قتل بوت لك تظهر `a bot`.
- البوتات تُقصى مثل اللاعبين في الجولة العادية (لا respawn)، وتعود في اللوبي
  بعد `ENDED`. مع `--dev-respawn` فقط تستمر في القتال بعد الموت.
- البوتات تُحتسب في `--min-players` وتكون جاهزة تلقائيًا، لكنها لا تبدأ جولة
  بدون لاعب بشري واحد على الأقل.

اختبار آلي سريع للأسلحة من طرف العميل (dev-only، يحتاج خادمًا في `LIVE`):

```bash
godot --headless --path . -- `
  --host=127.0.0.1 --port=7777 --token=dev --test-combat
```

هذا الخيار يبدّل الأسلحة ويطلق ويعيد التلقيم، ثم يطبع HUD وعدد اللاعبين
البعيدين. لا يؤثر على اللعب العادي لأنه يعمل فقط عند تمرير `--test-combat`.

---

## Interest Management (بالخلايا)

- حجم الخلية: `CELL_SIZE = 20m`.
- نصف قطر الاهتمام: `INTEREST_RADIUS = 45m`.
- الخادم يحتفظ بـ`cells: Vector2i -> [player_ids]` ويحدّثها عند تحرك اللاعب.
- كل snapshot يُبنى لكل لاعب حقيقي على حدة: نفسه + اللاعبون/البوتات داخل نصف القطر
  (فلترة مسافة دقيقة). البوتات لا تستقبل snapshots.
- أحداث الطلقات والقتل تُرسل أيضًا حسب الاهتمام: من هم داخل `45m` من مصدر الطلقة/الضحية،
  بالإضافة إلى مطلق النار والضحية. البوتات مستبعدة من قائمة المستلمين.
- العميل يحذف اللاعب البعيد إذا لم يظهر في أي snapshot لمدة `2s`.

هذا يقلل عدد اللاعبين والأحداث المرسلة لكل عميل، لكن بناء الـsnapshot ما يزال O(n²) عند 64 لاعبًا.
الخطوة التالية: قنوات أولوية (movement unreliable / events reliable) وتحديث الخلايا عند تغيّر الخلية فقط (منفّذ).

---

## Matchmaking (اختياري)

### تشغيل الخدمة

```bash
cd server/matchmaker
go run .
# أو
docker compose up --build matchmaker
```

### طلب مباراة

PowerShell:

```powershell
Invoke-RestMethod -Method Post -Uri http://localhost:8080/v1/match `
  -ContentType "application/json" `
  -Body '{"player_id":"p1","region":"me"}'
```

bash:

```bash
curl -s -X POST http://localhost:8080/v1/match \
  -H "Content-Type: application/json" \
  -d '{"player_id":"p1","region":"me"}'
```

الرد:

```json
{
  "server": "127.0.0.1:7777",
  "token": "7b7b...2e31",
  "exp": 1760000000
}
```

ثم:

```bash
godot --path . -- --host=127.0.0.1 --port=7777 --token=<TOKEN>
```

### سر مشترك

الـmatchmaker يوقّع التوكن بـ`HMAC-SHA256`، والخادم يتحقق منه:

```bash
# bash
export BR_SECRET="ضع-سرًا-طويلًا-هنا"

# PowerShell
$env:BR_SECRET = "ضع-سرًا-طويلًا-هنا"
```

يجب أن يكون `BR_SECRET` **نفسه** في خدمة الـmatchmaker وخادم اللعبة.

---

## Android (APK / AAB)

العميل يدعم التصدير إلى Android مع شاشة اتصال وتحكم لمس كامل. **الخادم والـmatchmaker
لا يدخلان في الـAPK/AAB**؛ شغّلهما على PC/VPS.

- شاشة اللوبي: 12 شخصية أصلية + معاينة 3D + ألوان/ملابس، ثم **DEPLOY** لفتح شاشة الاتصال.
- شاشة الاتصال: Host / Port / Join token، وتُحفظ في `user://client.cfg`.
- الملف الشخصي للمظهر يُحفظ في `user://profile.cfg`.
- التحكم: dynamic joystick + سحب للنظر + FIRE + JUMP + RELOAD + SWAP + LOOT/BAND/MED.
- الإعدادات جاهزة في `project.godot` و`export_presets.cfg.example`.
- دليل كامل (JDK/SDK، keystore، بناء APK/AAB، adb، جدار الحماية، LAN):
  [`docs/ANDROID.md`](docs/ANDROID.md).

### البريسيتات

| Preset | الناتج | Gradle | الاستخدام |
|---|---|---|---|
| `Android` | `build/OpenBR.apk` | لا | debug/release APK مباشر |
| `Android AAB` | `build/OpenBR-release.aab` | نعم | Google Play / AAB |

`export_presets.cfg` المحلي يحتوي مسار keystore وكلمة السر الحقيقية، لذلك هو
**مستثنى من Git**. `export_presets.cfg.example` يحتوي قيمًا فارغة.

```powershell
Copy-Item export_presets.cfg.example export_presets.cfg
# عدّل keystore/release و user/password في النسخة المحلية عند بناء release

# تثبيت Android build template مرة واحدة (يجب أن يكون JDK 17 كاملًا)
godot --headless --path . --install-android-build-template `
  --export-debug "Android" build/OpenBR.apk

# debug APK
godot --headless --path . --export-debug "Android" build/OpenBR.apk

# release APK
godot --headless --path . --export-release "Android" build/OpenBR-release.apk

# release AAB (Gradle)
godot --headless --path . --export-release "Android AAB" build/OpenBR-release.aab

adb install -r build/OpenBR-release.apk
```

- بناء AAB ينشئ `android/build/` (القالب المولّد) وهو مستثنى من Git.
- Godot قد يبدو معلّقًا بعد إنشاء AAB؛ تحقق من وجود الملف وأوقف العملية عند الحاجة.
- AAB يستخدم Gradle/AGP، ويحتاج JDK 17 كاملًا يحتوي `bin/instrument.dll`. الـJRE أو
  JDK ناقص يعطي أخطاء مثل `NoClassDefFoundError: org/slf4j/LoggerFactory` أو
  `Could not find agent library instrument`.

### المخرجات التي تم التحقق منها محليًا

| الملف | الحجم | SHA-256 | التوقيع / ملاحظات |
|---|---:|---|---|
| `build/OpenBR.apk` | 27,830,269 | `3DF3A0A91ED034C058F2A146A2E0DFBB09D1FFA25FBBFC62CA76CC152AAD58AF` | debug، `CN=Android Debug`، ARM64، minSdk 21 |
| `build/OpenBR-release.apk` | 29,768,507 | `66D2EC0E12C33A9366FDE8A31D3B0A84B7F10CCE254A05CAFA0A16CCD65CF34C` | release، `CN=OpenBR`، APK v1/v2/v3، minSdk 21 |
| `build/OpenBR-release.aab` | 29,687,378 | `FA10F77F326B7879D0FC20004FF4D7350FCFC707CC7BAF9796806DD5371A412D` | release، `CN=OpenBR`، `bundletool validate` exit 0، minSdk 21 |

كل المخرجات: `org.openbr.game`، الإصدار `0.2.0`، `targetSdk 34`، ARM64 فقط،
وصلاحية `INTERNET`. الـAPK غير debuggable في نسخة release.

> **minSdk موحّد:** APK وAAB كلاهما الآن على **minSdk 21** بعد ضبط
> `gradle_build/min_sdk="21"` في بريسيت `Android AAB`. تم التحقق من manifest الـAAB
> بـ`bundletool`. هذا يغطي Android 5.0+ نظريًا، لكن يبقى اختبار جهاز فعلي مطلوبًا.
>
> AAB يحتوي وحدة `base` وasset pack من نوع `installTime` (سلوك قالب Godot)،
> وتم التحقق منه بـ`bundletool`. التوقيع self-signed (`CN=OpenBR`)؛ هذا متوقع
> وليس خطأ، وGoogle Play سيستخدم Play App Signing عند الرفع.

### مفتاح release

- المفتاح محليًا خارج المشروع:
  `D:\tagriba2\openbr-keys\openbr-release.keystore` (alias `openbr`).
- كلمة السر في `D:\tagriba2\openbr-keys\keystore-password.txt`، وREADME في نفس المجلد.
- **احتفظ بنسخة احتياطية آمنة**؛ فقدان المفتاح يمنع تحديث نفس الحزمة على Play.
- لا ترفع المفتاح أو كلمة السر إلى Git، ولا تضعها في الـAPK.
- `export_presets.cfg` المحلي يحتوي `keystore/release` و`keystore/release_user`
  و`keystore/release_password`، وهو gitignored. لا تشاركه.

على الهاتف أدخل IP الخاص بـPC (مثل `192.168.1.10`)، المنفذ `7777`، والتوكن `dev`
عند تشغيل الخادم بـ`--dev-auth`. تأكد من فتح **UDP 7777** في جدار الحماية.

> لا تضع `BR_SECRET` في الـAPK/AAB. التوكن يُصدره الـmatchmaker ويُوقَّع على الخادم.
>
> توقيع debug يختلف عن توقيع release؛ قبل التبديل بين النسختين:
> `adb uninstall org.openbr.game`.
>
> تم التحقق من البناء والتوقيع وبنية الحزمة، لكن **اللعب الفعلي على الهاتف**
> (لمس + شبكة LAN) لم يُختبر بعد لعدم وجود جهاز متصل. القائمة الكاملة
> وخطوات الاختبار في [`docs/TESTING.md`](docs/TESTING.md).

### بناء APK تلقائيًا عبر GitHub Actions

أضفت workflow جاهزًا في `.github/workflows/android.yml` لبناء **debug APK** على GitHub
دون تثبيت Godot أو Android SDK على جهازك.

المستودع المحلي مهيّأ على `main` مع commit أول، لكنه **بلا remote وبلا push**
حتى الآن لعدم وجود مصادقة GitHub. بعد إضافة remote:

```powershell
git remote add origin https://github.com/<USER>/<REPO>.git
git push -u origin main
```

ثم:

1. من المستودع: **Actions** > **Android APK** > **Run workflow**.
2. بعد انتهاء البناء، نزّل الـartifact باسم `OpenBR-android-debug` من صفحة الـrun.
3. ثبّت الـAPK: `adb install -r OpenBR.apk`.

للتحقق على هاتف حقيقي، راجع [`docs/TESTING.md`](docs/TESTING.md) وسكربت
`scripts/android-device-test.ps1`.

ماذا يفعل الـworkflow؟

- يثبّت JDK 17 وGodot 4.4.1 + export templates.
- يثبّت Android SDK: `build-tools;34.0.0` و`platforms;android-34`.
- يضبط `editor_settings` لمسار SDK/JDK ومفتاح debug.
- ينسخ `export_presets.cfg.example` إلى `export_presets.cfg` (لأن الأخير مستثنى من Git).
- يصدّر `build/OpenBR.apk` ويرفعه كـartifact.

> الـworkflow يستخدم **debug keystore** فقط؛ الـAPK الناتج للاختبار وليس للنشر على Google Play.
> تم التحقق من خطوات البناء نفسها محليًا (Godot 4.4.1 + Android SDK 34)، لكن الـworkflow نفسه
> لم يُشغّل على GitHub بعد؛ راجع سجل الـActions إذا فشل أي step.
>
> مفتاح debug المحلي يختلف عن مفتاح CI؛ قبل التبديل بين الـAPKين:
> `adb uninstall org.openbr.game`.

---

## البنية

```
openbr/
├─ client/          # مشهد اللاعب والعميل و HUD والعاصفة (storm.tscn) + loot_field
│  └─ ui/           # اللوبي + شاشة الاتصال + تحكم اللمس
├─ server/          # الخادم السلطوي
│  └─ matchmaker/   # خدمة Go للتوزيع والتوكن
├─ shared/          # movement.gd + weapons.gd + characters.gd + character_model.gd
│                   # map_data.gd + loot.gd + inventory.gd (map/loot/armor/healing rules)
├─ scripts/         # Autoloads: Net, GameInput
├─ maps/            # verdant_reach.tscn + builder (تُحمَّل على الطرفين)
├─ android/build/   # Android build template (مولّد، مستثنى من Git)
├─ docs/            # ANDROID.md
├─ .github/         # workflow بناء debug APK تلقائيًا
├─ build/           # APK/AAB — مستثنى من Git
├─ export_presets.cfg.example
└─ assets/          # أصول CC0
```

مفتاح release وملف كلمة السر خارج المشروع في `D:\tagriba2\openbr-keys` (وليس داخل
`openbr/`)، حتى لا يدخلا Git بالخطأ.

### تدفّق اللعبة

```
1. Client ──POST /v1/match──> Matchmaker
2. Matchmaker ──> {server, HMAC token}
3. Client ──ENet connect──> Game Server
4. Client ──authenticate(token, appearance)──> Game Server
5. Server ──spawn_player(id, pos)──> Client
6. Client ──send_input(dir,yaw,jump) @30Hz──> Server
7. Client ──request_fire(aim_dir) / select_weapon / request_reload──> Server
8. Client ──request_loot(id) / request_use_item(type)──> Server
9. Server: movement + weapon state + hitscan + armor + healing + loot @30Hz
10. Server ──apply_snapshot(snap + weapon/ammo + appearance + armor/inventory, storm) @20Hz──> كل عميل
11. Server ──apply_shot / apply_death / match_state / kill_feed / loot_state / loot_taken──> Clients
```

- **الخادم سلطوي**: لا يثق بموقع العميل ولا بسرعة حركته ولا بجهة إصابته،
  ولا بالذخيرة أو الضرر. المظهر cosmetic فقط ويُنظَّف على الخادم قبل توزيعه.
- **العملاء لا يرسلون ضررًا**؛ الضرر يُحسب على الخادم فقط.
- **Snapshots** غير موثوقة (unreliable) لأن الأحدث يكفي.
- **Input** غير موثوق/مرتّب (unreliable_ordered) لتفادي تراكم التأخير.
- **Fire / weapon switch / reload** موثوقة (reliable) لأن كل حدث مهم، مع rate limit
  وتحقق على الخادم.
- **البوتات** تعمل داخل الخادم فقط ولا تستقبل/ترسل RPC.

---

## ما هو منفّذ الآن

- [x] هيكل Godot + Autoloads
- [x] خادم ENet سلطوي + مصادقة HMAC (تم التحقق: توكن صالح/معدّل/سر خاطئ)
- [x] اختبار LAN محلي (خادم + عميل headless)
- [x] حركة مشتركة وتصادم حقيقي على الخادم (`verdant_reach.tscn`)
- [x] Snapshots + interpolation + reconciliation
- [x] إطلاق نار hitscan + جدران تحجب + ضرر + موت + إقصاء
- [x] دورة مباراة BR: WAITING → COUNTDOWN → LIVE → ENDED → RESET
- [x] READY + auto-start + min-players + عد تنازلي قابل للضبط
- [x] حياة واحدة + فوز آخر لاعب + placement + spectator + kill feed
- [x] رفض الانضمام المتأخر أثناء COUNTDOWN/LIVE/ENDED
- [x] HUD (HP / armor / kills / ALIVE / storm / weapon+ammo / inventory / heal / kill feed / hit marker / damage flash) + tracers
- [x] Interest management بالخلايا (20m / 45m)
- [x] Matchmaker Go + Dockerfile + Compose
- [x] شاشة اتصال (Host/Port/Token) مع حفظ الإعدادات
- [x] تحكم لمس كامل (joystick + look + FIRE + JUMP + RELOAD + SWAP + LOOT/BAND/MED)
- [x] إعداد تصدير Android (APK/AAB, ARM64, mobile renderer)
- [x] بناء debug APK محليًا والتحقق من التوقيع (`build/OpenBR.apk`)
- [x] بناء release APK موقّع (`build/OpenBR-release.apk`)
- [x] بناء release AAB موقّع + `bundletool validate` (`build/OpenBR-release.aab`)
- [ ] تشغيل GitHub Actions فعليًا بعد إضافة remote والدفع (الـworkflow جاهز)
- [ ] اختبار اللمس واللعب LAN على هاتف Android حقيقي (بانتظار جهاز متصل)
- [x] الدائرة المتقلصة (storm) — خادم سلطوي + رسم على العميل + HUD، تعمل في LIVE فقط
- [x] أسلحة متعددة (Rifle/SMG/Shotgun) + ذخيرة + إعادة تلقيم + تبديل
- [x] بوتات اختبار server-only (`--bots=N`, حتى 16)
- [x] لوبي أصلي + اختيار شخصية (12 شخصية) + تخصيص ألوان/ملابس + معاينة 3D
- [x] حفظ المظهر في `user://profile.cfg` ومزامنته مع الخادم واللاعبين الآخرين
- [x] Loot + Inventory + Armor + Healing — server-authoritative + HUD + أزرار لمس
- [x] 69 نقطة loot ثابتة مشتركة + bandage قرب كل spawn + مزامنة العناصر المأخوذة
- [x] خريطة BR أصلية Verdant Reach ب9 مناطق بيئية و9 نقاط spawn
- [x] اختبار headless للـloot/العلاج + اختبار منطق armor/ammo/healing
- [ ] اختبار لعب فعلي على الهاتف (لمس + LAN)
- [ ] اختبار حمل/أداء مع عدد كبير من البوتات
- [ ] خرائط متعددة ووضع الفريق
- [ ] مراقبة/تليمتري للخادم

---

## ملاحظات أمان

1. `--dev-auth` للتطوير فقط؛ في الإنتاج استخدم توكن الـmatchmaker.
2. لا تضع `BR_SECRET` في Git أو في الـAPK/AAB؛ استخدم متغيرات البيئة أو مدير أسرار.
3. التوكن صالح 5 دقائق فقط؛ يمكن تقصيره.
4. الخادم يقيّد معدل إطلاق النار والتبديل وإعادة التلقيم، ويرفض أي مدخلات من لاعب
   غير مصادَق أو ميت.
5. الخادم لا يثق بأي قيمة عددية من العميل (الاتجاه يُقصّ إلى طول 1، وأصل الطلقة
   والذخيرة والضرر من الخادم).
6. مفتاح release وكلمة السر خارج Git (في `D:\tagriba2\openbr-keys`)، و
   `export_presets.cfg` مستثنى. لا تشارك المفتاح أو ترفعه.
7. ما زال هناك حاجة لـrate limiting عام على مستوى الاتصال (حزم/ثانية) قبل النشر العام.
8. الـloot والـinventory والـarmor والـhealing كلها server-authoritative؛ العميل يرسل
   `loot_id` أو نوع العنصر فقط، والخادم يتحقق من المسافة والكمية والوقت والضرر.

---

## الرخصة

- الكود: MIT (انظر `LICENSE`).
- الأصول المضافة لاحقًا: يجب أن تكون CC0/CC-BY مع ذكر المصدر في `assets/README.md`.
