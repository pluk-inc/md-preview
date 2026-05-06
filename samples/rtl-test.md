# RTL Test — ދިވެހި · العربية · עברית · English

A document for stress-testing right-to-left rendering, bidirectional runs,
and mixed-script paragraphs in the preview.

---

## 1. Pure Dhivehi paragraph

އައްސަލާމް ޢަލައިކުމް! މިއީ ކަނާތުން ވާތަށް ލިޔުމުގެ ޓެސްޓު ކުރުމަށް
ހަދާފައިވާ ލިޔުމެކެވެ. ދިވެހި ބަސް ތާނަ އަކުރުން ލިޔެވެއެވެ. މި ލިޔުމުގެ
މަޤްޞަދަކީ ތާނަ އަކުރުތައް ރަނގަޅަށް ދައްކާތޯ ބެލުމެވެ.

މިއީ ދެވަނަ ޕެރެގްރާފެކެވެ. ޖުމްލަތަކުގެ ދޭތެރޭ ހުންނަ ޖާގަ، ތިރި ތިރިއަށް
ހުންނަ ސަފުތަކުގެ ދޭތެރޭ ހުންނަ ޖާގަ، އަދި ހާސިޔާ ރަނގަޅުތޯ ޓެސްޓު
ކުރުމަށެވެ.

## 2. Pure Arabic paragraph

مرحبا بالعالم! هذا مستند لاختبار العرض من اليمين إلى اليسار. الهدف هو
التحقق من أن النص يتدفق في الاتجاه الصحيح، وأن علامات الترقيم تلتصق
بالكلمة الصحيحة، وأن علامات الاستفهام والفواصل لا تقفز إلى الجانب الخطأ.

فقرة ثانية لنرى التباعد بين الأسطر وما إذا كانت الهوامش تبدو صحيحة عند
وجود عدة أسطر متتالية.

## 3. Pure Hebrew paragraph

שלום עולם! זהו מסמך לבדיקה של תצוגה מימין לשמאל. המטרה היא לוודא שהטקסט
זורם בכיוון הנכון, שהפיסוק נצמד למילה הנכונה, ושסימני שאלה ופסיקים לא
קופצים לצד הלא נכון. האם זה עובד? כן, אני מקווה שכן.

הנה פסקה שנייה כדי לראות את המרווחים בין שורות והאם השוליים נראים נכון
כאשר יש כמה שורות זו אחר זו.

## 4. Mixed bidi within a single paragraph

This English sentence has a Dhivehi name އަޙްމަދު, an Arabic name محمد,
and a Hebrew name דָּוִד inside it, followed by a number 12345 and a
parenthetical (with English) and (ދިވެހި ތެރޭ) and (مع العربية) and
(עם עברית) — punctuation should hug the right side of each run.

މިއީ ދިވެހި ޕެރެގްރާފެކެވެ، "Swift" ބަސް އާއި 77 ނަންބަރު އަދި `inline code`
މެދުގައި ހިމެނޭ، އަދި ސުވާލަކުން ނިމޭ: ހުރިހާ ކަމެއް ރަނގަޅުތަ؟

هذه فقرة عربية تحتوي على كلمة "TypeScript" ورقم 99 وعبارة `inline code`
في المنتصف، وتنتهي بسؤال: هل كل شيء على ما يرام؟

זוהי פסקה בעברית שמכילה את המילה "JavaScript" ואת המספר 42 ואת הביטוי
`code snippet` באמצע, ונגמרת בשאלה: האם הכל תקין?

## 5. Lists

### Unordered (Dhivehi)

- ފުރަތަމަ ބައި
- ދެވަނަ ބައި **ބޯ ލިޔުން** އަދި *ރޮދި ލިޔުން*
- `inline` ކޯޑު ހިމެނޭ ބައި
- އެކުވެފައިވާ ބައި: hello ދިވެހި مرحبا עולם 123

### Ordered (Arabic)

1. العنصر الأول في القائمة
2. العنصر الثاني مع **نص غامق** و*مائل*
3. عنصر مع كود `inline` في الوسط
4. عنصر مختلط: hello ދިވެހި مرحبا עולם 123

### Unordered (Hebrew)

- פריט ראשון ברשימה
- פריט שני עם **טקסט מודגש** ו*נטוי*
- פריט עם קוד `inline` באמצע
- פריט מעורב: hello ދިވެހި مرحبا עולם 123

### Nested

- English root
  - ދިވެހި ނެސްޓެޑް
    - عنصر فرعي بالعربية
      - תת-פריט בעברית
        - back to English
- ދިވެހި މައި
  - ހެލޯ
  - مرحبا
  - שלום
  - hello

## 6. Blockquotes

> މިއީ ދިވެހި ކޯޓުކެވެ. ކޯޓުގެ ތެރި ރޮނގު ޕެރެގްރާފުގެ ކަނާތު ފަރާތުގައި
> ހުންނަން ޖެހޭނެއެވެ، ވާތު ފަރާތުގައި ނޫނެވެ.

> هذا اقتباس بالعربية. يجب أن يكون الشريط العمودي للاقتباس على الجانب
> الأيمن من الفقرة، وليس على الجانب الأيسر.

> זהו ציטוט בעברית. הפס האנכי של הציטוט אמור להיות בצד הימני של הפסקה,
> לא בצד השמאלי, אם הכיוון הוגדר נכון.

> A plain English blockquote, for comparison — bar on the left.

## 7. Tables

| ނަން    | الاسم  | שם   | Role        |
|---------|--------|------|-------------|
| އަޙްމަދު | محمد   | דוד  | Engineer    |
| ޢާއިޝާ  | سارة   | מרים | Designer    |
| ޙަސަން   | علي    | Alex | PM          |
| ފާޠިމާ  | فاطمة  | רחל  | Researcher  |
| އިބްރާހިމް | إبراهيم | יוסף | Team Lead   |

## 8. Code blocks (should stay LTR even in RTL context)

ދިވެހި ޕެރެގްރާފުގެ ތެރޭގައި Python ކޯޑުގެ މިސާލެކެވެ:

```python
greetings = {
    "dv": "ހެލޯ",
    "ar": "مرحبا",
    "he": "שלום",
    "en": "Hello",
}
for lang, word in greetings.items():
    print(f"{lang}: {word}")
```

وهذا مثال بلغة JavaScript داخل فقرة عربية:

```javascript
const names = ["ދިވެހި", "محمد", "דוד", "Alex"];
names.forEach((n) => console.log(`Hello, ${n}!`));
```

הנה דוגמה לקוד Swift בתוך פסקה עברית:

```swift
func greet(name: String) -> String {
    // English comment
    return "Hello, \(name)!"
}

// בעברית: greeting בעברית
let message = greet(name: "עולם")
print(message)
```

## 9. Inline formatting torture test

**ދިވެހި ބޯ** و**عربي غامق** ו**עברית מודגשת** and **English bold**, mixed
with *ދިވެހި ރޮދި* and *مائل* and *נטוי* and *italic*, plus ~~ހުރަސް~~
~~مشطوب~~ ~~יישור~~ ~~strikethrough~~ and `ކޯޑު` and `كود` and `קוד` and
`code`.

A line with [ދިވެހި ލިންކު](https://example.com),
[رابط بالعربية](https://example.com), [קישור בעברית](https://example.com),
and [English link](https://example.com).

## 10. Numbers, punctuation, and edge cases

- Phone number in Dhivehi sentence: 7774444 އަށް ގުޅާލާށެވެ.
- Phone number in Arabic sentence: اتصل بـ 05-9876543 من فضلك.
- Phone number in Hebrew sentence: התקשרו אל 03-1234567 בבקשה.
- Mixed quotes: one said "ހެލޯ", another replied "مرحبا", a third said
  "שלום", and they all said "hi".
- Parentheses around RTL: (ދިވެހި ބުރެކެޓުގެ ތެރޭ) and (عربية بين قوسين)
  and (עברית בסוגריים) and (English).
- Question marks: ދިވެހި؟ · العربية؟ · עברית? · English?
- Semicolons: ދިވެހި؛ العربية؛ עברית; English;
- Range: 2020–2026 inside ދިވެހި, inside العربية, and inside עברית.

## 11. Headings of every level

# H1 — ބޮޑު ސުރުޚީ — العنوان الرئيسي — כותרת ראשית
## H2 — ތަންވެ ސުރުޚީ — العنوان الفرعي — כותרת משנה
### H3 — ކުޑަ ސުރުޚީ — عنوان فرعي — תת-כותרת
#### H4 — ބައި — قسم — סעיף
##### H5 — ކުޑަ ބައި — قسم فرعي — תת-סעיף
###### H6 — ނޯޓު — ملاحظة — הערה

## 12. A paragraph with a forced LTR run

Even when surrounded by ދިވެހި and العربية and עברית, identifiers like
`MarkdownPreview.app` and URLs like https://github.com/example/repo
and version strings like `v1.2.3-rc.4` should remain left-to-right and
readable.

## 13. Long Dhivehi paragraph for word-wrap

ދިވެހި ބަސް އަކީ ރާއްޖޭގެ ޤައުމީ ބަސް ކަމުގައިވާ، ތާނަ އަކުރުން ކަނާތުން
ވާތަށް ލިޔެވޭ ބަހެކެވެ. މި ޕެރެގްރާފަކީ ވަރަށް ދިގު ޖުމްލައެއް ހިމެނޭ، ތާނަ
އަކުރުގެ ވިއްސާރަ، ފިލި، އަދި ނިޝާންތައް އެކުލެވޭ ބަހުގެ ތެރޭގައި ލައިން
ރެޕިން ކިހިނެއް މަސައްކަތް ކުރޭތޯ ބެލުމަށް ހަދާފައިވާ ޓެސްޓެކެވެ.

## 14. Long Arabic paragraph for word-wrap

في البدء خلق الله السماوات والأرض — وهذه جملة طويلة بشكل خاص تحتوي على
تشكيل كامل وعلامات اقتباس وشرطات، لاختبار كيفية تعامل آلية التفاف
الأسطر مع النص العربي الذي يحتوي على علامات خاصة يجب أن تبقى متصلة
بالحرف الذي تنتمي إليه.

## 15. Long Hebrew paragraph for word-wrap

ספר בראשית מתחיל במילים "בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת
הָאָרֶץ" — זוהי שורה ארוכה במיוחד שכוללת ניקוד מלא, גרשיים, ומקפים, כדי
לבדוק כיצד מנגנון גלישת השורות מתמודד עם טקסט עברי עם סימנים מיוחדים
שאמורים להישאר מחוברים לאות שלהם.

---

End — ނިމުނީ — النهاية — סוף
