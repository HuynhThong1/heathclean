# Handoff: HealthClean — iOS calorie tracking app

> **Cách dùng nhanh (Vietnamese quickstart)**
> 1. Copy cả thư mục `design_handoff_healthclean/` vào repo Swift của bạn (ví dụ `HeathClean/DesignHandoff/`).
> 2. Copy `DesignTokens.swift` (mục 9 dưới đây) vào target app.
> 3. Trong repo, chạy `claude` rồi nói: **“Đọc `DesignHandoff/README.md` và `SPEC.md`, rồi implement màn hình Dashboard bằng SwiftUI theo đúng spec, dùng `DesignTokens.swift`. Không đổi code Domain.”**
> 4. Làm từng màn hình một, đừng yêu cầu cả 11 màn hình trong một lần.
> Muốn xem thiết kế chạy thật: mở `design/HealthClean Screens.dc.html` trong Chrome (mọi màn hình đều bấm được).

## 1. Overview

HealthClean is a Vietnamese-first iOS calorie tracking app: the user photographs a meal, an AI recognizes the foods, a nutrition database computes calories, and **the user confirms or corrects the portion before anything is saved**. The design covers the full Phase 1–4 surface described in `plan.md`: onboarding (body info + goal), Apple Health permissions, a today dashboard, camera scan, AI review & correction, manual entry, meal detail, meal history, 7-day insights, and profile/notification settings.

The design derives its numbers from the real domain code already in `HuynhThong1/heathclean` (`CalculateCalorieGoalUseCase`, `EvaluateCalorieBudgetUseCase`, `BMI`, `ActivityLevel`) — so the UI and the Swift domain layer already agree. **Do not change the domain layer to fit the UI.**

## 2. About the design files

The files in `design/` are **design references written in HTML**, not production code. They are interactive prototypes that show intended look, copy, and behavior. Your task is to **recreate them in SwiftUI** using the existing app's architecture (Domain / Data / Presentation with `@Observable` models, as already established in the repo) — never to embed, port, or wrap the HTML.

- `design/HealthClean Screens.dc.html` — the screen board: all 14 states side by side. **Open this first.** Every phone on the board is live and clickable.
- `design/HealthClean iOS.dc.html` — the prototype itself (one file, all screens, real state).
- `design/ios-frame.jsx`, `design/support.js` — the harness that renders the phone bezel and the HTML runtime. **Ignore these for implementation**; they are not part of the design.
- `tokens/*.css` — the FPT IS design-system token files the design draws every color and font size from. `DesignTokens.swift` in section 9 is the Swift translation; prefer it over re-reading the CSS.

How to view: open `design/HealthClean Screens.dc.html` in Chrome or Safari. No server needed.

## 3. Fidelity

**High-fidelity.** Colors, type sizes, weights, radii, spacing, and all Vietnamese copy are final and should be matched closely. Where the spec below gives a number, use that number. Two things are deliberately unfinished:

- **Meal photos** are gray placeholders. Real photo thumbnails go in the same slots (see 6.7, 6.9).
- **Icons** are inline SVG line icons at 2px stroke, standing in for SF Symbols. Map each to the SF Symbol named in section 8 rather than reproducing the SVG paths.

## 4. Design language (read before writing any view)

- **One accent rule.** FPT IS blue `#0062B0` carries structure and primary action. Orange `#F37021` is reserved for exactly one thing per screen — the camera/scan action. Green `#12B24C` means growth/success only (fat macro, weight trend, checkmarks). Never all three loud on one surface.
- **Warnings are neutral, never alarming.** Over-budget state renders in gray `--neutral-400`, never red. Copy states the fact ("Bạn đã vượt mục tiêu hôm nay 214 kcal") and gives no command. This is a health app for casual users, not a scold.
- **Bilingual pairing, VI primary.** Every label is Vietnamese at full size with a smaller English sub-label beneath (11.5px, `--text-subtle`). This pattern repeats everywhere — build one small reusable `LabelPair` view.
- **AI is honest and correctable.** Every AI-derived item shows a confidence badge, and tapping it opens a gram editor. Items below 75% confidence get an orange-tinted border and the phrase "Nên kiểm tra". The AI never silently commits a number.
- **Numbers are typographically loud.** Big metrics are 38–52px, weight 800, letter-spacing −0.03em to −0.04em. Labels are small, 650 weight. Hierarchy comes from weight and scale, not color.
- **Cards, not chrome.** White cards (`--surface-card` = `#FFFFFF`) on a cool page background `#F4F7FA`, 1px `--border-subtle` border, radius 16–20px, soft shadow. Section headings sit *outside* the card as a small VI/EN pair.

## 5. Navigation model

Tab bar (4 tabs + a raised center action):

| Tab | VI label | Screen |
| --- | --- | --- |
| 1 | Hôm nay | Dashboard |
| 2 | Lịch sử | History |
| — | *(raised orange circle)* | Camera scan |
| 3 | Thống kê | Insights |
| 4 | Tôi | Profile |

Tab bar: height 86px, background `rgba(255,255,255,0.94)` with a blur (SwiftUI: `.ultraThinMaterial`), 1px top border `--border-subtle`. Icons 23px, labels 10.5px/650. Active = `#0062B0`, inactive = `--neutral-400`.

Center action: 60×60 circle, `#F37021`, 4px white ring, offset **−24px above** the bar's top edge, shadow `0 8px 20px rgba(243,112,33,0.42)`.

The tab bar is **hidden** on: Welcome, Onboarding, Apple Health, Camera, Analyzing, AI Review, Manual entry, Meal detail. It is shown only on the four tab roots.

Flows:
- First run: Welcome → Onboarding (4 steps) → Apple Health → Dashboard.
- Scan: Camera → Analyzing (~1.8 s) → AI Review → (Confirm) → Dashboard + toast.
- Dashboard meal row: has items → Meal detail; empty → Manual entry pre-set to that meal type.
- Manual save / AI confirm → Dashboard + toast "Đã lưu bữa ăn · 1.234 kcal".

## 6. Screens

Every screen is 402×874pt content (iPhone 16 Pro), 54pt status bar, 20pt horizontal page padding, scroll content bottom padding 108pt where the tab bar is present (24–34pt otherwise).

### 6.1 Welcome
Full-bleed gradient `linear-gradient(160deg, #004E8C 0%, #0062B0 55%, #0E9F43 140%)`. Content pinned top and bottom (space-between).

- Logo row: 34×34 rounded 9px chip at `rgba(255,255,255,.16)` with a 20px heart-pin glyph, then "HealthClean" 17px/700, white.
- Eyebrow "DINH DƯỠNG HẰNG NGÀY" — 11px/700, letter-spacing 0.16em, `rgba(255,255,255,.7)`.
- Headline "Chụp bữa ăn.\nBiết ngay calo." — 38px/800, line-height 1.1, tracking −0.025em, white.
- Body — 15px/1.55, `rgba(255,255,255,.82)`, max width 300pt: "AI nhận diện món ăn, cơ sở dữ liệu dinh dưỡng tính calo, và bạn là người xác nhận cuối cùng."
- Two checkmark lines, 14px: "Dữ liệu sức khỏe lưu trên thiết bị" / "Món Việt: cơm tấm, phở, bánh mì…"
- Primary button "Bắt đầu" (accent variant, full width, 52pt) → Onboarding. Text link "Tôi đã có tài khoản" → Dashboard.

### 6.2 Onboarding — 4 steps, one shell
Shell: back chip (32×32, radius 8, `--surface-sunken`) + a 4-segment progress bar (each 4pt tall, radius 2, filled `#0062B0` / unfilled `--neutral-200`) + step counter "1/4" (12.5px/600). Sticky bottom bar: white, 1px top border, one full-width 52pt primary button.

Per-step header: eyebrow 11px/700 tracking 0.14em in `#0062B0`, title 27px/800 tracking −0.02em, subtitle 14px/1.5 `--text-muted`.

| Step | Eyebrow | Title | CTA |
| --- | --- | --- | --- |
| 1 | BƯỚC 1 · VỀ BẠN | Cho chúng tôi biết về bạn | Tiếp tục |
| 2 | BƯỚC 2 · VẬN ĐỘNG | Một tuần của bạn thế nào? | Tiếp tục |
| 3 | BƯỚC 3 · MỤC TIÊU | Bạn muốn điều gì? | Xem mục tiêu |
| 4 | BƯỚC 4 · KẾT QUẢ | Mục tiêu hằng ngày của bạn | Kết nối Apple Health |

**Step 1 — body info.** One card, rows separated by 1px `--border-subtle`:
- Tuổi / Age — stepper: two 32×32 radius-8 `--blue-50` buttons (− / +, 19px/600, `#0062B0`) around a 19px/700 value. Clamp 13–120.
- Chiều cao / Height — numeric field, 66pt wide, right-aligned 16px/700, 1.5px `--border-default` border, radius 10, suffix "cm".
- Cân nặng / Weight — same, suffix "kg".
- Giới tính sinh học / "Dùng cho công thức Mifflin-St Jeor" — 3 equal segments: Nam / Nữ / Không nói. Selected = `--blue-50` bg, `#004E8C` text, 1.5px `#0062B0` border. Unselected = white bg, `--text-body`, `--border-subtle` border.
- If "Không nói" selected, a gray note appears: "Không có giới tính sinh học, mục tiêu sẽ dùng giá trị trung bình nên kém chính xác hơn."

**Step 2 — activity.** 5 radio cards, 9pt gap. Each: 20×20 radio ring (2px, `#0062B0` when selected with a 10px filled dot; `--neutral-300` empty), VI label 14.5px/650, EN sub 11.5px, and the multiplier right-aligned as "×1.375" (12px/600, `--text-subtle`). Selected card gets a 1.5px `#0062B0` border.

| Key | VI | EN | Multiplier |
| --- | --- | --- | --- |
| sedentary | Ít vận động | Almost no exercise | 1.2 |
| light | Nhẹ — 1–3 ngày/tuần | Light | 1.375 |
| moderate | Trung bình — 3–5 ngày/tuần | Moderate | 1.55 |
| active | Tích cực — 6–7 ngày/tuần | Active | 1.725 |
| veryActive | Rất tích cực — việc thể lực | Very active | 1.9 |

**Step 3 — goal.** Three equal tiles: Giảm (−500 kcal) / Duy trì (±0 kcal) / Tăng (+350 kcal). Tile: 16pt vertical padding, radius 14, label 15px/700, delta 11px `--text-subtle`; selected uses the same blue-50 treatment as the sex segments. If goal ≠ maintain, a target-weight row appears (same numeric field pattern). Gray note: "Mức thiếu hụt không bao giờ đưa bạn xuống dưới chuyển hóa cơ bản của chính bạn."

**Step 4 — result.** Hero card, radius 18, with a 4px `#0062B0` accent bar across the top:
- Eyebrow "CALO MỖI NGÀY".
- Value 46px/800 tracking −0.03em in `#0062B0`, then "kcal" 16px/600.
- Formula line, 12.5px `--text-muted`: "BMR 1.735 × vận động ×1.375 −500 kcal".
- Three macro chips (equal width, radius 12, 12pt padding): Đạm on `--blue-50` / `#004E8C`; Tinh bột on `--orange-100` / `#C2540F`; Chất béo on `--green-100` / `#0B7A34`. Value 20px/800, label 11.5px/600.

Second card — BMI as *context only*: "BMI 25.9" 15px/650 + "Thừa cân · Overweight", a Badge, an 8pt gradient scale bar (blue → green → orange → muted red across the 14–36 BMI range) with a 4×16 dark marker ringed in white at the user's position, and the note: "BMI chỉ là bối cảnh sức khỏe — mục tiêu calo được tính từ tuổi, chiều cao, cân nặng, vận động và mục tiêu của bạn."

### 6.3 Apple Health
56×56 white rounded-16 card holding a 28px heart glyph in `--danger`. Title "Kết nối Apple Health" 27px/800. Body: "HealthClean chỉ đọc những gì bạn cho phép. Ứng dụng vẫn hoạt động đầy đủ nếu bạn từ chối."

Four permission rows in one card, each: 32×32 radius-9 `--blue-50` icon chip, VI 14.5px/650 + EN 11.5px, and a Switch.

| Key | VI | EN | HealthKit type |
| --- | --- | --- | --- |
| steps | Bước chân | Step count | `stepCount` |
| energy | Năng lượng vận động | Active energy | `activeEnergyBurned` |
| sleep | Giấc ngủ | Sleep | `sleepAnalysis` |
| weight | Cân nặng & BMI | Body mass | `bodyMass`, `bodyMassIndex` |

Gray shield note: "Dữ liệu Apple Health không rời khỏi thiết bị và không dùng cho quảng cáo." Bottom: primary "Cho phép truy cập" + text button "Để sau".

**Note for implementation:** HealthKit grants permission per type through the system sheet; these switches express *intent* (which types to request). Read back the real authorization status afterwards and reflect it here.

### 6.4 Dashboard — ring variant (default)
Header: eyebrow "HÔM NAY · TODAY", date "Thứ Bảy, 9/8" 29px/800 tracking −0.025em, and a 38×38 avatar circle (`--blue-100` bg, `#004E8C` initials 14px/700) → Profile.

**Hero card** (radius 20, shadow-sm, 20pt padding, centered):
- Ring: 214×214, three stacked circles at r=95 in a 220×220 viewBox, stroke width 17, rotated −90°.
  1. Track — `--neutral-150`.
  2. Progress — `#0062B0`, round cap, dash = circumference × min(fraction, 1).
  3. Overflow — `--neutral-400`, drawn only when fraction > 1, dash = circumference × min(fraction − 1, 1). This is the neutral over-budget signal.
- Center: remaining kcal 52px/800 tracking −0.04em; "kcal còn lại" 13px/650; "remaining" 11.5px `--text-subtle`. Over budget → absolute value + "vượt mục tiêu" / "over target".
- Three stats separated by 1px dividers: Mục tiêu / Đã ăn / Vận động (value 17px/750, label 11.5px/600). "Vận động" shows "—" when Health isn't connected.
- Status note (gray pill, `--surface-sunken`, radius 12) driven by `EvaluateCalorieBudgetUseCase`:

| Fraction | Status | Copy |
| --- | --- | --- |
| < 0.70 | normal | *(no note)* |
| ≥ 0.70 | informUser | Bạn còn {n} kcal cho hôm nay. |
| ≥ 0.90 | nearTarget | Bạn đang gần mục tiêu calo hôm nay. |
| ≥ 1.00 | reached | Bạn đã đạt mục tiêu calo hôm nay. |
| > 1.00 | exceeded | Bạn đã vượt mục tiêu hôm nay {n} kcal. |

**Macros card.** Three rows (Đạm/Protein `#0062B0`, Tinh bột/Carbs `#F37021`, Chất béo/Fat `#12B24C`): label pair left, "**128** / 141 g" right (current in `--text-strong`, rest in `--text-muted`), then a 7pt track (`--neutral-150`, radius 4) with a fill capped at 100%. 14pt gap between rows.

**Meals card.** Four fixed rows in order Bữa sáng, Bữa trưa, Bữa phụ, Bữa tối. Each: 34×34 radius-10 chip (orange-100 / blue-100 / green-100 / neutral-150 respectively), VI 14.5px/650, detail line = comma-joined food names truncated to one line (or "Chưa ghi · not logged"), kcal 14px/700 right (or "—" in `--text-subtle`), chevron. Tap → meal detail if logged, else manual entry.

**Apple Health tiles.** 2×2 grid, radius 14: Bước chân 8.420 · Năng lượng 425 kcal · Giấc ngủ 7h 32m · Cân nặng 78.5 kg. Value 21px/800. If not connected, replace the grid with one dashed-border card: "Kết nối Apple Health để thấy bước chân, năng lượng và giấc ngủ." → Apple Health screen.

**BMI context row.** "BMI 25.9 · Thừa cân" + sub "Bối cảnh sức khỏe, không dùng để tính calo" + Badge with the English category.

### 6.5 Dashboard — bar variant (alternate hero)
Same card, ring replaced by a horizontal stacked bar. Left: remaining kcal 44px/800 + "còn lại · remaining". Right: "1.322 / 1.886" 15px/750 + "70% mục tiêu" 11.5px/600. Bar: 16pt tall, radius 8, `--neutral-150` track, one segment per meal type with a 2pt gap, widths = mealKcal / dailyGoal. Segment colors by meal, in blue shades: `--blue-300`, `#0062B0`, `--green-400`, `--blue-500`. Legend below: 2-column grid, 9×9 radius-3 swatch + meal name + kcal.

Ship the ring as default; keep the bar behind a flag if you want to A/B it.

### 6.6 Camera scan
Full-screen `#0B1116`, above the tab bar. Header: close chip (34×34, `rgba(255,255,255,.14)`) / "Quét bữa ăn" 15px/650 white / spacer.

Viewfinder: 1:1, radius 22, `#151E26`, 45° 12px hairline stripe pattern at 3% white, plus four 34×34 3px corner brackets at `rgba(255,255,255,.85)` inset 14pt. In the real app this is the `AVCaptureVideoPreviewLayer`; the brackets and hint stay overlaid.

Hint: "Đặt cả đĩa ăn vào khung." 13.5px `rgba(255,255,255,.72)` + "Chụp từ trên xuống giúp ước lượng khẩu phần chính xác hơn." 12px `rgba(255,255,255,.45)`.

Controls row: 52×52 library button (left) · **76×76 shutter**, `#F37021`, 5px `rgba(255,255,255,.9)` ring, shadow `0 8px 24px rgba(243,112,33,.45)` · 52×52 manual-entry button (right).

### 6.7 Analyzing
Same dark surface. 110×110 radius-28 `#151E26` tile with a camera glyph. "Đang phân tích ảnh…" 19px/700 white + "Analyzing your meal" 12.5px. A 260pt max-width 5pt progress bar in `#F37021`. Three checklist rows that light from `rgba(255,255,255,.4)` to white with a green check as progress passes 30% / 65% / 95%:

1. Nhận diện món ăn
2. Ước lượng khẩu phần
3. Tra cứu dinh dưỡng

Prototype timing is 70ms × 25 ticks ≈ 1.8s. In production drive these three states from the real pipeline (Vision/Core ML → portion estimate → nutrition lookup) and keep the same three labels. On failure, stay on this screen with a neutral message and two options: retry, or go to manual entry.

### 6.8 AI review
Header: back chip · "Kết quả AI" 18px/750 + "AI ANALYSIS · you confirm" · "Quét lại" text action (13px/650 `#0062B0`).

Blue explainer pill (`--blue-50`, radius 12, sparkle icon, text in `#004E8C`): "AI nhận diện món và ước lượng khẩu phần. Calo do cơ sở dữ liệu dinh dưỡng tính — hãy sửa khẩu phần nếu chưa đúng."

Optional 120pt photo strip placeholder above the list.

**Item cards** (radius 14, 10pt gap, tappable):
- Name 15px/700 tracking −0.01em + EN 11.5px `--text-subtle`.
- kcal 16px/750 right with a small "kcal" caption.
- Second line: a gram pill (12.5px/650 on `--surface-sunken`, radius 999, "180 g"), the confidence Badge, then macro summary "Đ 4.3 · TB 50 · B 0.4" 11.5px and a pencil icon.
- Confidence: ≥ 0.90 → green Badge "Tin cậy 92%"; ≥ 0.75 → blue Badge; < 0.75 → orange Badge "Nên kiểm tra · 61%" **and** the card border becomes 1px `--orange-300`.

Dashed "Thêm món còn thiếu" row → appends an item and opens the editor.

**Estimated-total card** (shadow-sm): "Tổng ước tính" / "ESTIMATED TOTAL", total 30px/800 in `#0062B0`, three macro chips (same palette as onboarding step 4, 15px/750), and the source line: "Nguồn: USDA FoodData Central · CSDL món Việt".

Sticky bottom bar: a 104pt meal-type button showing the current type with the caption "đổi bữa" (cycles breakfast → lunch → snack → dinner) + full-width primary "Xác nhận bữa ăn".

**English variant** — same layout with `lang = en`. Strings: "AI result" / "Estimate · you confirm the serving" / "Rescan" / "Add a missing food" / "Estimated total" / "YOU CAN STILL EDIT" / "Confidence 92%" / "Please check · 61%" / "Confirm meal" / "change" / macro shorthand "P · C · F" / "Sources: USDA FoodData Central · Vietnamese food DB". Food names swap roles: English becomes the primary line, Vietnamese the sub-line. Build this with a real localization catalog (`Localizable.xcstrings`, `vi` base + `en`), not a boolean.

### 6.9 Portion editor (bottom sheet)
Presented over AI review. Scrim `rgba(15,27,39,.42)`. Sheet: radius 24 top corners, 18/20/34pt padding, shadow `0 -12px 40px rgba(15,27,39,.18)`, slide-up 240ms `cubic-bezier(.2,0,0,1)`. SwiftUI: `.presentationDetents([.height(420)])`.

- 38×4 grab handle.
- Editable name field (16px/700) + confidence Badge.
- "AI ước lượng ban đầu: 180 g" 11.5px `--text-subtle` — always show the original estimate so the correction is visible.
- Stepper block on `--surface-page`, radius 14: 44×44 −/+ buttons (white, 1px border, `#0062B0` glyphs — note 44pt hit targets), center shows grams 34px/800 + derived kcal 12.5px/650 in `#0062B0`.
- Four preset chips: 50 g / 100 g / 150 g / 200 g.
- Footer: secondary "Xoá món" + primary "Xong".

**Scaling rule:** changing grams scales kcal, protein, carbs, and fat by the same ratio (`new / old`). Keep `originalGrams` untouched. Persist both the AI estimate and the user's correction — the "31% AI cần sửa" insight depends on it.

### 6.10 Meal detail
Header: back · meal name 18px/750 + "Lunch · 12:15" · "Thêm món" text action.

Optional 150pt photo placeholder. Hero card with a 4px top accent bar colored by meal type (sáng `#F37021`, trưa `#0062B0`, phụ `#12B24C`, tối `--blue-500`):
- "TỔNG BỮA ĂN" eyebrow, total 38px/800, "kcal".
- Right: share of daily budget 15px/750 `#0062B0` + "ngân sách ngày".
- A 10pt macro energy bar split by **kcal contribution** (protein×4, carbs×4, fat×9 over their sum) in blue / orange / green, 2pt gaps.
- Three macro chips (16px/750).

Items card: one row per food — name 14.5px/650, sub = EN name or "Nhập tay", kcal 14.5px/700 and grams 11px right-aligned.

Gray note: "Bữa này chiếm 34% ngân sách calo hôm nay. Ghi lúc 12:15." Then a full-width outlined destructive-but-quiet action "Xoá bữa ăn này" (`--text-muted` text, 1.5px `--border-default`) — confirm before deleting.

Meal times used in the design: sáng 07:20 · trưa 12:15 · phụ 15:40 · tối 19:30. In production use the real logged timestamp.

### 6.11 Meal history
Eyebrow "LỊCH SỬ · HISTORY", title "Bữa ăn đã ghi" 29px/800. Then one group per day (14pt gap):
- Row: date 14px/750 + "1.806 / 1.886" 11.5px, and day total right 13px/700.
- A 5pt progress bar vs goal — `#0062B0` under goal, `--neutral-400` over.
- A card of meal rows: 28×28 chip, VI meal name 13.5px/650, food summary 11px truncated, kcal 13px/700.

Sample data in the design (keep this shape, load real data): Thứ Sáu 8/8 · 1.806 · Phở bò 420 / Cơm gà xối mỡ 690 / Sữa chua 160 / Bún thịt nướng 536 — Thứ Năm 7/8 · 1.512 — Thứ Tư 6/8 · 2.044 — Thứ Ba 5/8 · 1.689.

Paginate by day (lazy sections). Empty state: reuse the neutral gray-note style, no illustration.

### 6.12 Insights
Eyebrow "THỐNG KÊ · INSIGHTS", title "7 ngày qua".

**Calorie card** (radius 18, shadow-sm): header "Calo mỗi ngày" + "vs mục tiêu 1.886 kcal", right shows the average 20px/800 + "trung bình". Chart: 132pt tall, 7 bars, 8pt gap, radius `6 6 3 3`, dashed 1.5px `--neutral-300` goal line across at goal/max height. Today's bar = `#0062B0` with its value printed above; other days `--blue-200`, or `--neutral-300` when over goal. Day labels T3…CN, Nay.

**Weight card**: header "Cân nặng" + "6 tuần · mục tiêu 72 kg", current value 20px/800. A 96pt polyline in `#12B24C` (2.5pt, round joins) over a `--green-100` fill, x-axis T1…Nay. Series in the design: 81.4, 80.6, 80.1, 79.4, 78.9, 78.5.

**Stat grid** (2×2, radius 14): "5/7 ngày trong mục tiêu" (blue) · "−2.9 kg trong 6 tuần" (green) · "84% bữa ăn được ghi" (dark) · "31% AI cần sửa khẩu phần" (orange). Value 22px/800, VI 11.5px/650, EN 10.5px.

Closing gray note: "Bạn thường thiếu đạm vào buổi chiều. Còn 13 g đạm cho hôm nay." — one observation, one number, no advice stack.

### 6.13 Profile
Eyebrow "TÔI · PROFILE". Identity row: 60×60 avatar circle (21px/750 initials), name 19px/750, "32 tuổi · 174 cm · 78.5 kg" 12.5px.

Three stat cards: daily kcal goal (blue), BMI + category (dark), kg to target (green).

**THIẾT LẬP** — two rows with chevrons: "Thông tin cơ thể & mục tiêu / Body info & goal" → onboarding in edit mode; "Apple Health" with sub "Đã kết nối · bước chân, năng lượng, giấc ngủ" (or "Chưa kết nối").

**THÔNG BÁO** — five Switch rows mirroring the plan's thresholds:

| Key | VI | EN | Default |
| --- | --- | --- | --- |
| p70 | Khi dùng 70% ngân sách | At 70% of budget | on |
| p90 | Khi gần mục tiêu (90%) | Near target | on |
| reached | Khi đạt mục tiêu | Target reached | on |
| remind | Nhắc ghi bữa ăn | Meal logging reminder | off |
| daily | Tóm tắt hằng ngày | Daily summary | on |

**QUYỀN RIÊNG TƯ** — three green-check lines: data stays on device; meal photos are used transiently for analysis then deleted; health data is never sold or used for ads. These are product commitments — implement them literally.

### 6.14 Toast
Position: 16pt insets, 104pt from the bottom (clears the tab bar). `--neutral-900` background, white text 13.5px/600, radius 14, green check icon, shadow `0 10px 30px rgba(15,27,39,.3)`, fade+rise in 220ms, auto-dismiss after 2.6s. Copy: "Đã lưu bữa ăn · 1.234 kcal".

## 7. Domain logic the UI depends on

Already implemented in the repo — the UI must read these, not reimplement them.

**Calorie goal** (`CalculateCalorieGoalUseCase`): Mifflin-St Jeor BMR = `10·kg + 6.25·cm − 5·age + k`, where k = +5 male, −161 female, **−78 unspecified**. Then `adjusted = BMR × activityMultiplier + goalDelta`, delta = −500 lose / 0 maintain / +350 gain. Floor: `calories = max(adjusted, max(BMR, 1200))` — never prescribe below the user's own BMR. Protein = `kg × 1.8` when losing, else `× 1.6`. Fat = `calories × 0.25 / 9`. Carbs = `max(0, calories − protein·4 − fat·9) / 4`.

**Budget status** (`EvaluateCalorieBudgetUseCase`): thresholds 0.70 / 0.90 / 1.00 as tabulated in 6.4.

**BMI**: `kg / m²`; bands < 18.5 underweight · < 25 normal · < 30 overweight · ≥ 30 obese. Display only.

Rounding: kcal and grams shown as integers (`Int(rounded())`); macros in AI review shown to 1 decimal; BMI to 1 decimal; thousands separator is a period in Vietnamese ("1.886") — use a `vi_VN` `NumberFormatter`, don't hand-roll it.

## 8. Icons → SF Symbols

| Design icon | SF Symbol |
| --- | --- |
| Tab: Hôm nay | `clock` |
| Tab: Lịch sử | `list.bullet` |
| Tab: Thống kê | `chart.bar` |
| Tab: Tôi | `person.crop.circle` |
| Shutter / scan | `camera.fill` |
| Bữa sáng | `sunrise` |
| Bữa trưa | `fork.knife` |
| Bữa phụ | `cup.and.saucer` |
| Bữa tối | `moon` |
| Steps | `figure.walk` |
| Active energy | `flame` |
| Sleep | `moon.zzz` |
| Body mass | `scalemass` |
| Confidence / AI | `sparkles` |
| Info note | `info.circle` |
| Privacy | `checkmark.shield` |
| Edit portion | `pencil` |
| Confirm / check | `checkmark` |

All at ~2pt stroke equivalent — use `.symbolRenderingMode(.monochrome)` with `.medium` or `.semibold` weight, inheriting the row's foreground color.

## 9. Design tokens — DesignTokens.swift

Drop this in the app target and reference it everywhere. Values come straight from `tokens/colors.css` and `tokens/semantic.css`.

```swift
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >>  8) & 0xFF) / 255,
                  blue:  Double( hex        & 0xFF) / 255,
                  opacity: 1)
    }
}

enum DS {
    // Brand
    static let blue   = Color(hex: 0x0062B0)   // primary
    static let orange = Color(hex: 0xF37021)   // single accent: scan
    static let green  = Color(hex: 0x12B24C)   // growth / success

    // Blue ramp
    static let blue50  = Color(hex: 0xEDF5FC)
    static let blue100 = Color(hex: 0xD3E7F8)
    static let blue200 = Color(hex: 0xA7CFF1)
    static let blue300 = Color(hex: 0x6FB0E7)
    static let blue500 = Color(hex: 0x0071CC)
    static let blue700 = Color(hex: 0x004E8C)

    // Orange / green ramps
    static let orange100 = Color(hex: 0xFDE8DA)
    static let orange300 = Color(hex: 0xF9B183)
    static let orange700 = Color(hex: 0xC2540F)
    static let green100  = Color(hex: 0xDCF5E5)
    static let green400  = Color(hex: 0x3ECB72)
    static let green600  = Color(hex: 0x0E9F43)
    static let green700  = Color(hex: 0x0B7A34)

    // Cool neutrals
    static let neutral150 = Color(hex: 0xE9EDF2)
    static let neutral200 = Color(hex: 0xDCE2EA)
    static let neutral300 = Color(hex: 0xC3CCD8)
    static let neutral400 = Color(hex: 0x9AA7B8)
    static let neutral600 = Color(hex: 0x5B6878)
    static let neutral700 = Color(hex: 0x44505F)
    static let neutral900 = Color(hex: 0x0F1B27)

    // Semantic
    static let surfacePage   = Color(hex: 0xF4F7FA)
    static let surfaceCard   = Color.white
    static let surfaceSunken = Color(hex: 0xEDF1F5)
    static let textStrong    = Color(hex: 0x0F1B27)
    static let textBody      = Color(hex: 0x2B3947)
    static let textMuted     = Color(hex: 0x5B6878)
    static let textSubtle    = Color(hex: 0x8794A6)
    static let borderSubtle  = Color(hex: 0xE9EDF2)
    static let borderDefault = Color(hex: 0xDCE2EA)
    static let danger        = Color(hex: 0xD64545)

    // Radii
    static let rControl: CGFloat = 10
    static let rCard: CGFloat = 16
    static let rHero: CGFloat = 20
    static let rSheet: CGFloat = 24

    // Spacing (8pt grid, 4pt half-steps)
    static let s1: CGFloat = 4, s2: CGFloat = 8, s3: CGFloat = 12
    static let s4: CGFloat = 16, s5: CGFloat = 20, s6: CGFloat = 24

    // Motion
    static let durFast = 0.12
    static let durBase = 0.20
    static let ease = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.20)
}
```

**Typography.** One family, weight-driven. The design ships **Be Vietnam Pro** (Google Fonts) as a substitute for the licensed FPT corporate face; it has full Vietnamese diacritics. Either bundle the real corporate font or bundle Be Vietnam Pro — do **not** fall back to system SF for headlines, since the tracking values assume the geometric humanist face.

| Role | Size | Weight | Tracking |
| --- | --- | --- | --- |
| Hero metric | 52 | 800 | −0.04em |
| Big metric | 38–46 | 800 | −0.03em |
| Screen title | 27–29 | 800 | −0.025em |
| Card metric | 20–22 | 800 | −0.02em |
| Section head | 15 | 750 | 0 |
| Row label | 14.5 | 650 | 0 |
| Body | 13.5–15 | 400–500 | 0 |
| Sub-label / EN | 11.5 | 400–600 | 0 |
| Eyebrow | 11 | 700 | +0.14–0.16em |

Line-height: 1.5 body, 1.15–1.2 display.

**Shadows.** sm = `0 1px 2px rgba(15,27,39,.06), 0 2px 8px rgba(15,27,39,.04)` · orange CTA = `0 8px 20px rgba(243,112,33,.42)` · sheet = `0 -12px 40px rgba(15,27,39,.18)` · toast = `0 10px 30px rgba(15,27,39,.3)`.

## 10. State the views need

Per-screen state, on top of the existing repo models:

- **Onboarding**: `age`, `heightCm`, `weightKg`, `biologicalSex`, `activityLevel`, `weightGoal`, `targetWeightKg`, `step (0…3)`. Derived: BMR, goal calories, macro targets, BMI + category. Recompute on every change; step 4 is pure derivation.
- **Health**: `requestedTypes: Set<HKType>`, `authorizationStatus` per type.
- **Dashboard**: today's `[Meal]`, `DailyNutritionSummary`, `DailyCalorieBudget`, `budgetStatus`, active energy from HealthKit, `isHealthConnected`.
- **Scan**: `.idle → .capturing → .analyzing(progress, stage) → .review([AIFoodItem]) → .saved` and `.failed(reason)`. `AIFoodItem` carries `name`, `nameEn`, `grams`, `originalGrams`, `kcal`, `protein`, `carbs`, `fat`, `confidence`.
- **Review**: `items`, `editingIndex`, `pendingMealType`.
- **Manual**: `[DraftFood]` (name, grams, kcal, p/c/f), `pendingMealType`; save disabled until at least one item has kcal > 0 — the prototype flashes "Nhập calo trước khi lưu".
- **Meal detail**: `mealType` / meal id.
- **History**: day-grouped meals, paginated.
- **Insights**: 7-day kcal series, 6-week weight series, derived stats.
- **Profile**: profile fields, notification prefs, health connection state.

Nothing is written until the user confirms. AI results live only in review state until "Xác nhận bữa ăn".

## 11. Interaction details worth matching

- Hover has no meaning on iOS; the prototype's hover states map to **press** states: darken the fill and nudge 1pt down over 120ms.
- All steppers and ±buttons are ≥ 44pt hit targets (the gram editor uses 44×44 exactly).
- Sheet, toast, and screen transitions all use `cubic-bezier(.2,0,0,1)` — 120ms press, 200ms toggles, 220–240ms sheet/toast. No bounce, no spring overshoot.
- Focus ring in the design is a 3px translucent blue outline; on iOS this is the field border switching to `DS.blue` at 1.5pt.
- Progress and ring fills animate their value change with `DS.ease`; do not animate the ring on first appear from zero on every navigation — only on value change.

## 12. Files in this bundle

```
design_handoff_healthclean/
├── README.md                        ← this file (self-sufficient spec)
├── design/
│   ├── HealthClean Screens.dc.html  ← open this: all 14 states, clickable
│   ├── HealthClean iOS.dc.html      ← the prototype (all screens, real state)
│   ├── ios-frame.jsx                ← phone bezel harness (ignore)
│   └── support.js                   ← HTML runtime (ignore)
└── tokens/
    ├── colors.css                   ← source of every hex in section 9
    ├── semantic.css
    ├── typography.css
    └── layout.css
```

Repo files the design was derived from — reread these before implementing, they are the source of truth for math:
`Sources/Domain/UseCases/CalculateCalorieGoalUseCase.swift`, `Sources/Domain/UseCases/EvaluateCalorieBudgetUseCase.swift`, `Sources/Domain/Entities/{BMI,ActivityLevel,WeightGoal,BiologicalSex,DailyNutritionSummary,DailyCalorieBudget}.swift`, `App/Presentation/{Dashboard,Onboarding,MealEntry,MealHistory}/`.

## 13. Suggested implementation order

1. `DesignTokens.swift` + the shared `LabelPair`, `SectionHeader`, `DSCard`, `GrayNote`, `MacroChip`, `PrimaryButton` views. Everything else composes from these six.
2. Dashboard (ring, macros, meals, status note) — it exercises most of the vocabulary and the domain layer already exists.
3. Onboarding 4 steps + result — pure derivation, no I/O.
4. Manual entry, meal detail, history — completes Phase 1 without any AI.
5. Apple Health permissions + tiles.
6. Camera → analyzing → review → portion editor.
7. Insights, profile, notifications.
8. Localization pass: extract every string into `Localizable.xcstrings` with `vi` base and the `en` strings from 6.8.

## 14. Assets

No production imagery is bundled. Meal photos are gray placeholders in the design; wire them to the real captured photo (`UIImage` thumbnail, `fill` aspect, radius 14–16). The FPT IS logotype lives in the design system at `assets/fpt-is-logo.png` — use the file, never redraw the mark. Icons: SF Symbols per section 8.
