# Maps

- `verdant_reach.tscn` — خريطة **Verdant Reach** الحالية، ويجب أن تُحمَّل بنفس المسار
  على العميل والخادم.
- `verdant_reach.gd` — builder إجرائي للأرض والطرق والمناطق والـprops. يعمل على
  الطرفين من نفس البيانات، لذلك التصادم متطابق.
- `../shared/map_data.gd` — أسماء المناطق التسع، مراكزها، ألوانها، ونقاط spawn.

## المحتوى

- أرض **120×120** مع تصادم، و4 جدران محيطة + أعمدة زوايا.
- 9 مناطق بيئية:
  **Meridian Relay / Aurora Yards / Cinder Terrace / Tideglass Shore /
  Dune Chapel / Frostline Depot / Saltwind Docks / Hollow Grove / Sunken Gardens**.
- مبانٍ قابلة للدخول، containers، سايلوهات، ramps، catwalks، أرصفة، ماء ضحل،
  صخور، أشجار، greenhouse، وأبراج.
- `SpawnPoints` بـ9 علامات `Marker3D` يقرأها الخادم عبر `global_position`.
- إضاءة وبيئة (sky + fog) على العميل؛ تُهمَل بصريًا على الخادم.

## قواعد التعديل

1. عدّل `verdant_reach.tscn` و`verdant_reach.gd` فقط، ولا تكرر هندسة الخريطة داخل
   `client/main.tscn`.
2. أي `StaticBody3D` يجب أن يبقى على طبقة التصادم الافتراضية `1` حتى تحجبه رصاصات الخادم.
3. أجسام اللاعبين على الطبقة `2` مع `mask=1`، أي لا تصادم بين اللاعبين.
4. حافظ على نقاط `SpawnPoints` بعيدة عن الـprops الصلبة، وحدّث `shared/map_data.gd`
   عند تغييرها.
5. إذا أضفت خريطة جديدة، أضف مسارها إلى `client/main.gd` و`server/main.gd`.
6. لا تضع loot داخل جدار أو صندوق صلب؛ الـloot الموجود على الأرصفة يستخدم `y=0.65`.

> عدم تطابق الخريطة بين الطرفين = desync في الحركة والتصادم.
