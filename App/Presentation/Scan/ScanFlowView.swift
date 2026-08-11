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
    /// Manual entry is presented from inside the scan flow rather than by
    /// dismissing it first: closing a full-screen cover and opening a sheet in
    /// the same update races, and this keeps one owner for the saved-meal
    /// callback either way the user logs the meal.
    @State private var manualEntry: MealType?
    /// A captured photo waiting to be confirmed. Not in the handoff, and worth
    /// the extra step: analysing is one request against a small daily free-tier
    /// quota — exhausted once already — so sending a blurry frame costs a call
    /// and returns a wrong dish. Confirming is cheap; re-earning the quota is not.
    @State private var pendingImage: Data?

    let type: MealType
    let onSaved: (Double) -> Void

    var body: some View {
        Group {
            if let model {
                switch model.state {
                case .idle where pendingImage != nil:
                    CapturedPhotoView(
                        imageData: pendingImage ?? Data(),
                        onUse: { data in
                            pendingImage = nil
                            Task { await model.analyze(image: data) }
                        },
                        onRetake: { pendingImage = nil }
                    )
                case .idle:
                    // §6.6 is the camera screen. Where there is no capture
                    // device — the simulator, an iPad without one — the picker
                    // chooser stands in, since it is the only path that works.
                    if CameraCaptureView.isAvailable {
                        CameraCaptureView(
                            onImage: { data in pendingImage = data },
                            // §6.6's third control is manual entry, not an exit.
                            // It used to call `dismiss()`, so the button simply
                            // closed the scan and did nothing — a control that
                            // looks like it goes somewhere and does not.
                            onManualEntry: { manualEntry = type },
                            onClose: { dismiss() }
                        )
                    } else {
                        chooser(model: model)
                    }
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
        .sheet(item: $manualEntry) { type in
            MealEntryView(type: type) { calories in
                onSaved(calories)
                dismiss()
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else {
                    return
                }
                // Through the same confirmation step as a capture: a photo picked
                // from the library can be just as wrong for the job, and one code
                // path means one place where the quota is spent.
                pendingImage = data
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

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, DS.s3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// §6.7: a failure stays on the analysing screen — so on its dark surface —
    /// with a neutral message and the two ways out.
    private func failure(message: String, model: ScanModel) -> some View {
        VStack(spacing: DS.s4) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
            Text(message)
                .hfStyle(HFType.body)
                .foregroundStyle(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("scan.error")
            Spacer()

            Button("Thử lại") { model.reset() }
                .buttonStyle(.ds(.primary, size: .large, fullWidth: true))
            // The ghost style is drawn for a light surface, so the text action
            // is styled here rather than reused.
            Button("Nhập tay") { dismiss() }
                .buttonStyle(.plain)
                .font(.custom(DSFontName.semibold, size: 15))
                .foregroundStyle(.white.opacity(0.72))
                .frame(height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.scanSurface.ignoresSafeArea())
    }
}

/// §6.7 — the analysing state, on §6.6's dark surface so the camera does not
/// flash white on its way here.
private struct AnalyzingView: View {
    /// §6.7's prototype timing: 70ms × 25 ticks ≈ 1.8s.
    private static let tick = Duration.milliseconds(70)
    private static let tickCount = 25
    /// The bar stops just short of full and waits. The real work is one network
    /// request whose length is unknown, so filling the bar would be a claim the
    /// app cannot make — what ends this screen is the response arriving.
    private static let ceiling = 0.95

    @State private var progress = 0.0

    private let steps = [
        (vi: "Nhận diện món ăn", threshold: 0.30),
        (vi: "Ước lượng khẩu phần", threshold: 0.65),
        (vi: "Tra cứu dinh dưỡng", threshold: 0.95),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(DS.scanViewfinder)
                .frame(width: 110, height: 110)
                .overlay {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.white.opacity(0.72))
                }

            Text("Đang phân tích ảnh…")
                .font(.custom(DSFontName.bold, size: 19))
                .foregroundStyle(.white)
                .padding(.top, DS.s5)
                .accessibilityIdentifier("scan.analyzing")
            Text("Analyzing your meal")
                .font(.custom(DSFontName.regular, size: 12.5))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 2)

            progressBar
                .padding(.top, DS.s5)

            VStack(alignment: .leading, spacing: DS.s3) {
                ForEach(steps, id: \.vi) { step in
                    checklistRow(step.vi, isDone: progress >= step.threshold)
                }
            }
            .padding(.top, DS.s6)

            Spacer()

            Text("Ảnh chỉ dùng để phân tích rồi xoá.")
                .font(.custom(DSFontName.regular, size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.scanSurface.ignoresSafeArea())
        .task {
            for step in 1...Self.tickCount {
                try? await Task.sleep(for: Self.tick)
                withAnimation(.linear(duration: 0.07)) {
                    progress = Double(step) / Double(Self.tickCount) * Self.ceiling
                }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.14))
                Capsule()
                    .fill(DS.orange)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(maxWidth: 260)
        .frame(height: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Đang phân tích")
    }

    private func checklistRow(_ label: String, isDone: Bool) -> some View {
        HStack(spacing: DS.s2) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isDone ? DS.green : .white.opacity(0.4))
            Text(label)
                .font(.custom(DSFontName.medium, size: 13.5))
                .foregroundStyle(isDone ? .white : .white.opacity(0.4))
        }
        .animation(DS.ease, value: isDone)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isStaticText)
    }
}

extension DS {
    /// White on the orange scan action.
    static let textOnBrandScan = Color.white
}
