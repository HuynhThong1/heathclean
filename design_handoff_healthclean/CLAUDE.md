# CLAUDE.md — HealthClean iOS

## Design source of truth
Mọi UI phải theo `DesignHandoff/README.md` (spec đầy đủ: màn hình, màu, type, spacing, copy tiếng Việt).
Màn **Lịch sử (History)**: theo `DesignHandoff/HISTORY_SPEC.md` (phương án đã chốt: logged-day cards, có search + filter). Spec này ghi đè phần History trong README.
Prototype tương tác: mở `DesignHandoff/design/HealthClean Screens.dc.html`; riêng History mở `DesignHandoff/design/HealthClean History.dc.html` (dựng đúng option **1b**, bỏ qua 1a/1c).
Các file `.dc.html` là **tham chiếu thiết kế**, không phải code để port — recreate bằng SwiftUI.

## Rules
- Dùng `DesignTokens.swift` (DS.*) cho mọi màu / radius / spacing / motion. Không hardcode hex trong View.
- Không sửa Domain layer để khớp UI. UI đọc `CalculateCalorieGoalUseCase`, `EvaluateCalorieBudgetUseCase`.
- Blue #0062B0 dẫn dắt. Orange #F37021 chỉ dùng cho nút quét. Green #12B24C chỉ cho tăng trưởng/thành công.
- Trạng thái vượt calo: **xám trung tính, không đỏ, không mệnh lệnh**.
- Mọi nhãn song ngữ: tiếng Việt chính (14.5px/650) + tiếng Anh phụ (11.5px, textSubtle).
- Kết quả AI luôn hiện độ tin cậy và luôn sửa được. Không tự lưu khi chưa xác nhận.
- Hit target ≥ 44pt. Font: Be Vietnam Pro (hoặc font FPT chính thức), không fallback SF cho headline.
- Số: `NumberFormatter` locale `vi_VN` (1.886), không tự nối chuỗi.

## History (đã chốt)
- Không lưới lịch tháng. Chỉ render ngày ĐÃ ghi; tháng trống co thành một dòng divider.
- Đa số bữa không có ảnh → chip món có ảnh và không ảnh phải cùng kích thước.
- Vượt mục tiêu dùng `DS.Color.overBudget` (xám), không đỏ.
- Có từ khoá tìm kiếm → danh sách đổi từ theo-ngày sang theo-bữa. Khớp không phân biệt dấu.

## Order of work
Theo mục 13 của `DesignHandoff/README.md`: tokens + 6 shared view → Dashboard → Onboarding → Manual/Detail/History → HealthKit → Scan/Review → Insights/Profile → localization.
