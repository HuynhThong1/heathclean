# HISTORY_SPEC.md — màn "Lịch sử" (History tab)

> Chốt phương án: **Logged-day cards (1b)** — danh sách chỉ chứa NGÀY ĐÃ GHI, mỗi ngày là một thẻ, kèm thanh lệch mục tiêu và hàng chip món.
> Tham chiếu hình ảnh: `design/HealthClean History.dc.html` (mở trong Chrome). Option `1b` là bản phải dựng; `1a`/`1c` chỉ để tham khảo, **không implement**.
> File `.dc.html` là tài liệu tham chiếu, KHÔNG phải code để port. Recreate bằng SwiftUI.

---

## 0. Nguyên tắc không được vi phạm

1. **Không có lưới lịch tháng.** Không bao giờ render ô cho ngày không có dữ liệu. Ngày trống không tồn tại trong UI.
2. **Đa số bữa KHÔNG có ảnh** — chip món không ảnh và chip món có ảnh phải **cùng kích thước**. Không thiết kế phụ thuộc ảnh.
3. **Vượt mục tiêu = xám trung tính** (`DS.Color.overBudget`). Không đỏ, không cam, không icon cảnh báo, không câu mệnh lệnh.
4. Không streak, không huy hiệu, không gamification, không emoji.
5. Người dùng **không** ghi lùi ngày → không có nút "thêm bữa cho ngày này" trong History.

---

## 1. Kiến trúc màn hình

```
HistoryView
├── HistoryHeader (pinned, không cuộn)
│   ├── LabelPair("Lịch sử", "History")
│   ├── SearchField
│   └── FilterChipRow (ScrollView .horizontal, showsIndicators: false)
└── ScrollView
    ├── [MonthSection]              // tháng có dữ liệu
    │   ├── MonthHeader             // "Tháng 8, 2026" + "5 ngày ghi · TB 1.780 kcal"
    │   └── [DayCard]               // giảm dần theo ngày
    ├── EmptyMonthDivider           // "Tháng 7, 2026 — chưa ghi ngày nào"
    └── LoadMoreFooter              // nút / đang tải / hết dữ liệu
```

Khi `searchText` không rỗng hoặc có chip lọc bật → thân màn đổi sang **MealResultList** (danh sách theo BỮA, không theo ngày). Xem mục 5.

State machine của màn: `.loading` → `.empty` | `.error(retry)` | `.loaded(months)` ; cộng thêm `.searching(results)` | `.searchEmpty`.

---

## 2. Đo đạc (points)

| Thành phần | Giá trị |
| --- | --- |
| Page padding ngang | 16 |
| Header padding | 16 ngang, top an toàn + 8, bottom 12 |
| Tiêu đề màn | 26pt / 700, letter-spacing −0.01em; phụ đề EN 11.5pt / 400 |
| Search field | height 44, corner 12, border 1, padding ngang 12, icon 15, gap 9 |
| Filter chip | height 34, corner 17, padding ngang 12, gap 8, border 1 |
| Khoảng cách header → nội dung | 12 |
| Month header | 15pt / 700; padding 12 / 4 / 10; meta phải 11.5pt / 400 muted |
| DayCard | padding 13, corner 16, border 1, gap giữa card 10 |
| Cột ngày trong card | width 42, canh giữa; số 20pt / 700 monospacedDigit; thứ 10.5pt / 600 muted |
| kcal ngày | 17pt / 700 + " kcal · mục tiêu 1.900" 12pt / 500 muted |
| Thanh lệch | height 8, corner 4, track `DS.Color.trackBg`; vạch mục tiêu width 1.5 màu `DS.Color.axis` |
| Dòng delta | 11.5pt / 500 muted, cách thanh 6 |
| Chip món | height 38, corner 10, padding (5, 10, 5, 5), gap 8; ô ảnh/chữ 26×26 corner 7 |
| Empty-month divider | height 28; chữ 11.5pt / 400 `#94A3B2`, hai bên là đường 1pt |
| Tab bar | height 84 (giữ nguyên như các tab khác) |
| Day panel (sheet) | corner trên 20, grabber 36×4, `.presentationDetents([.fraction(0.78), .large])` |

**Scale thanh lệch:** `maxValue = max(kcal, goal) * 1.12`; `fill = kcal / maxValue`; `goalMark = goal / maxValue`. Nhờ hệ số 1.12 nên ngày đúng mục tiêu vẫn còn khoảng trống bên phải, vạch mục tiêu không dính mép.

---

## 3. Màu (chỉ dùng `DS.*`, không hardcode hex trong View)

| Token | Light | Dùng ở đâu |
| --- | --- | --- |
| `DS.Color.brandBlue` | #0062B0 | thanh calo ≤ mục tiêu, số ngày hôm nay, chip đang bật, tab đang chọn |
| `DS.Color.overBudget` | #B4C0CB | phần thanh của ngày vượt mục tiêu |
| `DS.Color.axis` | #C0CAD4 | vạch mục tiêu |
| `DS.Color.trackBg` | #E9EEF2 | nền thanh |
| `DS.Color.cardBg` | #FFFFFF | thẻ ngày |
| `DS.Color.pageBg` | #F4F7FA | nền màn |
| `DS.Color.border` | #E9EDF2 | viền thẻ |
| `DS.Color.textStrong` | #0F1B27 | số kcal, tên tháng |
| `DS.Color.textBody` | #35485A | chip chưa bật, giá trị phụ |
| `DS.Color.textMuted` | #6E7F90 | nhãn EN, meta, delta |
| `DS.Color.chipOnBg` | #E7EFF6 | nền chip đang bật, ô chữ cái của món không ảnh |
| `DS.Color.brandOrange` | #F37021 | **chỉ** nút "Quét bữa ăn" ở trạng thái rỗng |

Dark mode: `pageBg #0F1B27`, `cardBg #1A2733`, `border #2A3947`, `textStrong #F2F5F8`, `textBody #C0CAD4`, `trackBg #223040`, `overBudget #566878`. brandBlue giữ nguyên.

---

## 4. DayCard — chi tiết

- Toàn bộ thẻ là **một** `Button` (min 44×44). Chip món **không** phải nút riêng (tránh chạm nhầm) → mở panel ngày rồi mới vào bữa.
- Hàng chip: tối đa hiện 3 chip, còn lại gộp thành chip `"+2 món"`. Chip không ảnh dùng ô 26×26 nền `chipOnBg` với chữ cái đầu tên món, màu `brandBlue`. Chip có ảnh dùng đúng ô đó nhưng là thumbnail (`.scaledToFill().clipped()`).
- Ngày hôm nay: số ngày màu `brandBlue`, thêm nhãn "Hôm nay" cạnh thứ.
- Copy delta: `Còn 219 kcal · 3 bữa` / `Vượt 180 kcal · 2 bữa` / `Đạt mục tiêu · 2 bữa` (sai lệch ≤ 2%).
- **Dynamic Type:** dùng `ViewThatFits`. Từ `.accessibility1` trở lên: cột ngày chuyển lên trên thành hàng ("13 · Th 5"), khối kcal xuống dưới, hàng chip đổi `HStack` → `VStack`. Không dùng lưới cột cố định, không `.fixedSize` trên text.

---

## 5. Tìm kiếm & bộ lọc

- Ô tìm kiếm nằm trong header cố định (không phải sheet). Placeholder: `Tìm món ăn, ví dụ: phở`. Nút xoá 18pt hiện khi có chữ.
- **Khớp không phân biệt dấu và hoa/thường**: so sánh với `.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi_VN"))`. "pho" = "phở" = "PHO".
- Debounce 250 ms; < 2 ký tự không lọc. Không spinner — giữ danh sách cũ ở opacity 0.5 trong lúc lọc.
- Phạm vi: tên món + tên bữa, **chỉ trong các tháng đã tải**. Luôn hiện dòng `Tìm trong các tháng đã tải. Kéo xuống để tải thêm.`
- **Đổi đơn vị hiển thị:** không tìm kiếm → theo NGÀY; có từ khoá → theo BỮA (ô ảnh 34, tên món 13.5pt/600, meta "Bữa sáng · 480 kcal", ngày 11.5pt/600 canh phải). Header kết quả: `4 bữa có "phở" · 3 tháng gần nhất`.
- Chip: `Tất cả · Có ảnh · Vượt mục tiêu · Bữa sáng · Bữa trưa · Bữa tối · Bữa phụ`. "Tất cả" loại trừ các chip khác; nhóm bữa là OR trong nhóm, AND với các nhóm khác. Chip "Vượt mục tiêu" **vẫn màu brandBlue** như mọi chip — không xám, không đỏ.
- Từ khoá và chip **không lưu** giữa hai lần mở tab: mở History luôn là danh sách đầy đủ.

---

## 6. Trạng thái (bắt buộc dựng đủ)

| Trạng thái | Nội dung |
| --- | --- |
| **Loading** | 3 thẻ skeleton (khối #E3E9EF, opacity 0.45→0.95, 1.4s easeInOut lặp). Không spinner, không hiện "không có dữ liệu" trước khi tải xong. |
| **Empty (người mới)** | "Chưa có bữa nào được ghi" / "No meals logged yet" / "Ghi bữa đầu tiên để bắt đầu lịch sử của bạn. Lịch sử chỉ hiện những ngày bạn đã ghi." · nút cam "Quét bữa ăn" (48pt) + nút viền xanh "Nhập tay". |
| **Error** | "Không đọc được dữ liệu" / "Couldn't load your history" / "Dữ liệu vẫn nằm an toàn trên máy bạn. Thử lại sau vài giây." · nút xanh "Thử lại". Không đỏ, không icon cảnh báo. |
| **Pagination** | Nút "Tải các tháng trước"; đang tải: chữ "Đang tải tháng 3, 2026…"; hết: "Đã hiển thị toàn bộ lịch sử." Tháng trống ở giữa co thành divider một dòng. |
| **Search results** | Xem mục 5. |
| **Search empty** | "Không tìm thấy bữa nào" / "Không có bữa nào tên "…" trong các tháng đã tải. Thử bỏ bớt bộ lọc." · nút "Xoá bộ lọc". |
| **Day panel** | Sheet: "Thứ Năm, 13/8/2026" (+ "Hôm nay · Today"), 1.681 kcal 30pt/700 + "/ mục tiêu 1.900", thanh 10pt, "Còn 219 kcal · 3 bữa", 3 macro (Đạm / Tinh bột / Béo — nhãn 11pt, số 14pt/700, thanh 4pt), rồi danh sách bữa theo thời gian (giờ 40pt rộng, ô ảnh 34, tên + số món, kcal canh phải). Chạm một bữa → MealDetailView đã có. |

---

## 7. Accessibility

- Mỗi DayCard là **một** phần tử: `.accessibilityElement(children: .combine)`, trait `.isButton`.
  Nhãn: `"Thứ Năm 13 tháng 8. 1.681 ki-lô ca-lo trên mục tiêu 1.900. Còn 219. 3 bữa: Phở bò, Cơm gà, Sữa chua. Có 1 ảnh."`
  Hint: `"Chạm hai lần để xem các bữa trong ngày."`
- Ngày vượt: `"…2.080 trên mục tiêu 1.900. Vượt 180."` — tuyệt đối không dùng từ phán xét.
- Thanh lệch và ô ảnh trong chip: `.accessibilityHidden(true)` (thông tin đã nằm trong nhãn gộp).
- Thứ tự đọc: header tháng → ngày mới → ngày cũ → divider tháng trống (đọc là văn bản, **không** phải nút) → nút tải thêm.
- Skeleton: container `.accessibilityLabel("Đang tải lịch sử")`, các ô giả ẩn.
- Chip: `.isButton` + `.isSelected`; nhãn "Có ảnh, đang bật". Khi số kết quả đổi, thông báo `"4 kết quả"`.
- Panel ngày: tiêu đề `.isHeader`; mỗi bữa một phần tử: `"06:50, Bữa sáng, Phở bò, 480 ki-lô ca-lo. Có ảnh."`; macro đọc `"Đạm 96 gam, 78 phần trăm mục tiêu."`
- Tương phản: `textMuted #6E7F90` chỉ đặt trên nền trắng (4.6:1). Không đặt lên `pageBg` ở cỡ < 11.5pt.

---

## 8. Số liệu & định dạng

- Mọi số dùng `NumberFormatter` locale `vi_VN` (`groupingSeparator = "."`) → `1.681`. Không tự nối chuỗi, không dấu phẩy.
- Ngày: `dd/M` trong danh sách, `EEEE, d/M/yyyy` trong panel, locale `vi_VN` (Thứ Hai … Chủ Nhật).
- Trung bình tháng chỉ tính trên **ngày đã ghi**, không chia cho số ngày trong tháng.
- Mục tiêu kcal lấy theo **mục tiêu của chính ngày đó** (đã lưu trong bản ghi), không lấy mục tiêu hiện tại.

---

## 9. Thứ tự làm việc cho Claude Code

1. `HistoryDeviationBar` (thanh 8pt + vạch mục tiêu) và `MealChip` — hai view nhỏ, có preview riêng.
2. `DayCard` + Dynamic Type variant, preview đủ 5 biến thể: có 1 ảnh / nhiều ảnh / không ảnh / hôm nay / vượt mục tiêu.
3. `MonthSection` + `EmptyMonthDivider` + `MonthHeader`.
4. `HistoryView` với state machine `.loading/.empty/.error/.loaded` + pagination.
5. `SearchField` + `FilterChipRow` + `MealResultList` + trạng thái tìm không ra.
6. `DayPanelSheet` (macro + danh sách bữa) → nối vào `MealDetailView` sẵn có.
7. Rà accessibility bằng VoiceOver và Dynamic Type `.accessibility3`.
