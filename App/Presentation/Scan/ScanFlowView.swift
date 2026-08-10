import Domain
import PhotosUI
import SwiftUI

/// The scan flow: pick or capture a photo → analysing → review (§6.6–6.8).
///
/// The camera is unavailable in the simulator, so the picker is the path that
/// can actually be exercised here; capture is offered only on a device that
/// reports a camera.
struct ScanFlowView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var model: ScanModel?
    @State private var pickerItem: PhotosPickerItem?

    let type: MealType
    let onSaved: (Double) -> Void

    var body: some View {
        Group {
            if let model {
                switch model.state {
                case .idle:
                    chooser(model: model)
                case .analyzing:
                    AnalyzingView()
                case .review:
                    ScanReviewView(
                        model: model,
                        onRescan: { model.reset() },
                        onConfirmed: { calories in
                            onSaved(calories)
                            dismiss()
                        },
                        onCancel: { dismiss() }
                    )
                case let .failed(message):
                    failure(message: message, model: model)
                }
            } else {
                ProgressView()
            }
        }
        .background(DS.surfacePage)
        .onAppear {
            if model == nil { model = container.makeScanModel(type: type) }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item, let model else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    return
                }
                await model.analyze(image: data)
            }
        }
    }

    // MARK: Idle

    private func chooser(model: ScanModel) -> some View {
        VStack(alignment: .leading, spacing: DS.s5) {
            HStack(alignment: .top, spacing: DS.s3) {
                HFBackChip { dismiss() }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Quét bữa ăn")
                        .font(.custom(DSFontName.bold, size: 18))
                        .foregroundStyle(DS.textStrong)
                    Text("\(model.type.vi) · \(model.type.en)")
                        .hfStyle(HFType.subLabel)
                        .foregroundStyle(DS.textSubtle)
                }
                Spacer(minLength: 0)
            }

            GrayNote(
                text: "AI nhận diện món ăn, cơ sở dữ liệu tính calo, và bạn xác nhận trước khi lưu."
            )

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Chọn ảnh bữa ăn", systemImage: "photo.on.rectangle")
                    .font(.custom(DSFontName.semibold, size: 17))
                    .foregroundStyle(DS.textOnBrandScan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(DS.orange, in: RoundedRectangle(cornerRadius: DS.rControl, style: .continuous))
            }
            .accessibilityIdentifier("scan.pickPhoto")

            // §6.6 draws a camera shutter. AVFoundation has no camera in the
            // simulator, so this is offered only where one exists rather than
            // shipping a button that cannot work.
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Text("Chụp ảnh trực tiếp sẽ được bổ sung sau.")
                    .hfStyle(HFType.subLabel)
                    .foregroundStyle(DS.textSubtle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, DS.s3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func failure(message: String, model: ScanModel) -> some View {
        VStack(spacing: DS.s4) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(DS.neutral400)
            Text(message)
                .hfStyle(HFType.body)
                .foregroundStyle(DS.textBody)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("scan.error")
            Spacer()
            Button("Thử lại") { model.reset() }
                .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
            Button("Nhập tay") { dismiss() }
                .buttonStyle(.ds(.ghost, size: .medium))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
    }
}

/// §6.7 — the analysing state. The three labels are the real pipeline stages.
private struct AnalyzingView: View {
    @State private var stage = 0

    private let stages = [
        "Đang nhận diện món ăn…",
        "Đang ước lượng khẩu phần…",
        "Đang tra cứu dinh dưỡng…"
    ]

    var body: some View {
        VStack(spacing: DS.s4) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(DS.blue)
            Text(stages[min(stage, stages.count - 1)])
                .hfStyle(HFType.body)
                .foregroundStyle(DS.textBody)
                .accessibilityIdentifier("scan.analyzing")
            Text("Ảnh chỉ dùng để phân tích rồi xoá.")
                .hfStyle(HFType.subLabel)
                .foregroundStyle(DS.textSubtle)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .task {
            // Purely presentational pacing; the real work is one request.
            for index in stages.indices.dropFirst() {
                try? await Task.sleep(for: .milliseconds(600))
                stage = index
            }
        }
    }
}

extension DS {
    /// White on the orange scan action.
    static let textOnBrandScan = Color.white
}
