import AVFoundation
import PhotosUI
import SwiftUI

/// §6.6's camera screen: a 1:1 viewfinder over the dark scan surface, with the
/// library and manual-entry escapes either side of the shutter.
///
/// **Unverified on this machine.** AVFoundation has no camera in the simulator,
/// so everything below the layout — authorization, the preview layer, and the
/// capture itself — has only been compiled, never run. `ScanFlowView` shows this
/// screen only where a camera is reported, and falls back to the picker
/// otherwise, so the simulator never reaches it.
struct CameraCaptureView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var model = CameraModel()
    @State private var pickerItem: PhotosPickerItem?

    let onImage: (Data) -> Void
    let onManualEntry: () -> Void
    let onClose: () -> Void

    /// Whether a capture session can be built at all.
    ///
    /// This asks AVFoundation for the very device the session needs, rather
    /// than `UIImagePickerController.isSourceTypeAvailable(.camera)`, which
    /// answers a different question — it is about the legacy UIKit picker — and
    /// reports a camera on a simulator that has no capture device.
    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: DS.s4)
            viewfinder
            hint
            Spacer(minLength: DS.s4)
            controls
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.scanSurface.ignoresSafeArea())
        .task { await model.start() }
        .onDisappear { model.stop() }
        // iOS stops the session when the app leaves the foreground, and
        // `.task` does not run again on return — without this the viewfinder
        // comes back black after a phone call or a lock. `.inactive` is
        // transient (Control Centre, the app switcher) so it is left alone.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: Task { await model.start() }
            case .background: model.stop()
            default: break
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    onImage(data)
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: DS.s3) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("camera.close")
            .accessibilityLabel("Đóng")

            Text("Quét bữa ăn")
                .font(.custom(DSFontName.semibold, size: 15))
                .foregroundStyle(.white)

            Spacer(minLength: 0)
        }
        .padding(.top, DS.s2)
    }

    // MARK: Viewfinder

    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(DS.scanViewfinder)
                .overlay(HairlineStripes().opacity(0.03))

            if model.isRunning {
                CameraPreview(session: model.session)
            } else if model.access == .denied {
                deniedNote
            }

            CornerBrackets()
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var deniedNote: some View {
        VStack(spacing: DS.s3) {
            Text("Chưa có quyền dùng máy ảnh.")
                .font(.custom(DSFontName.semibold, size: 14))
                .foregroundStyle(.white.opacity(0.82))
            Text("Bạn vẫn có thể chọn ảnh từ thư viện.")
                .font(.custom(DSFontName.regular, size: 12.5))
                .foregroundStyle(.white.opacity(0.45))
            if let settings = URL(string: UIApplication.openSettingsURLString) {
                Link("Mở Cài đặt", destination: settings)
                    .font(.custom(DSFontName.semibold, size: 13))
                    .foregroundStyle(DS.orange)
            }
        }
        .multilineTextAlignment(.center)
        .padding(DS.s5)
        .accessibilityIdentifier("camera.denied")
    }

    private var hint: some View {
        VStack(spacing: 2) {
            Text("Đặt cả đĩa ăn vào khung.")
                .font(.custom(DSFontName.regular, size: 13.5))
                .foregroundStyle(.white.opacity(0.72))
            Text("Chụp từ trên xuống giúp ước lượng khẩu phần chính xác hơn.")
                .font(.custom(DSFontName.regular, size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .padding(.top, DS.s4)
    }

    // MARK: Controls

    private var controls: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                SideButton(symbol: "photo.on.rectangle")
            }
            .accessibilityIdentifier("camera.library")
            .accessibilityLabel("Chọn ảnh từ thư viện")

            Spacer(minLength: 0)
            shutter
            Spacer(minLength: 0)

            Button(action: onManualEntry) {
                SideButton(symbol: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("camera.manual")
            .accessibilityLabel("Nhập tay")
        }
    }

    private var shutter: some View {
        Button {
            Task {
                if let data = await model.capturePhoto() { onImage(data) }
            }
        } label: {
            Circle()
                .fill(DS.orange)
                .frame(width: 76, height: 76)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 5))
                .shadow(color: DS.orange.opacity(0.45), radius: 12, y: 8)
        }
        .buttonStyle(.plain)
        // A shutter with no session behind it would photograph nothing.
        .disabled(!model.isRunning)
        .opacity(model.isRunning ? 1 : 0.4)
        .accessibilityIdentifier("camera.shutter")
        .accessibilityLabel("Chụp ảnh bữa ăn")
    }

}

/// §6.6's two 52×52 escapes either side of the shutter. A separate view rather
/// than a method because `PhotosPicker`'s label is built outside the main actor.
private struct SideButton: View {
    let symbol: String

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(Color.white.opacity(0.14), in: Circle())
    }
}

// MARK: - Session

/// Holds the AVFoundation objects and the UI state around them.
///
/// The session itself lives in `CaptureSession`, off this actor, because
/// AVFoundation requires configuration and `startRunning()` to happen on a
/// dedicated serial queue rather than the main thread.
@MainActor
@Observable
final class CameraModel {
    enum Access { case undetermined, granted, denied }

    private(set) var access: Access = .undetermined
    private(set) var isRunning = false

    private let capture = CaptureSession()

    var session: AVCaptureSession { capture.session }

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            access = .granted
        case .notDetermined:
            access = await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        default:
            access = .denied
        }

        guard access == .granted else { return }
        isRunning = await capture.start()
    }

    func stop() {
        capture.stop()
        isRunning = false
    }

    func capturePhoto() async -> Data? {
        await capture.photo()
    }
}

/// `@unchecked Sendable` because every touch of the session happens on `queue`.
/// The one exception is handing `session` to the preview layer, which is the
/// use AVFoundation documents for it.
private final class CaptureSession: @unchecked Sendable {
    let session = AVCaptureSession()

    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.heathfirst.camera.session")
    /// The delegate has to outlive `capturePhoto`, which does not retain it.
    private var delegate: PhotoDelegate?

    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                if session.inputs.isEmpty {
                    guard configure() else {
                        continuation.resume(returning: false)
                        return
                    }
                }
                if !session.isRunning { session.startRunning() }
                continuation.resume(returning: session.isRunning)
            }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func photo() async -> Data? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(returning: nil)
                    return
                }
                let delegate = PhotoDelegate { data in
                    continuation.resume(returning: data)
                }
                self.delegate = delegate
                output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
            }
        }
    }

    /// Called on `queue` only.
    private func configure() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo
        guard
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back
            ),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input),
            session.canAddOutput(output)
        else { return false }

        session.addInput(input)
        session.addOutput(output)
        return true
    }
}

/// `capturePhoto` reports through a delegate rather than a completion handler,
/// so the continuation is resumed from here.
private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (Data?) -> Void

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        completion(error == nil ? photo.fileDataRepresentation() : nil)
    }
}

// MARK: - Preview layer

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // Guaranteed by `layerClass` above.
        layer as! AVCaptureVideoPreviewLayer
    }
}

// MARK: - Viewfinder decoration

/// §6.6's 45° hairline stripes, 12pt apart.
private struct HairlineStripes: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 12
            let reach = size.width + size.height
            var offset: CGFloat = -size.height
            var path = Path()
            while offset < reach {
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + size.height, y: size.height))
                offset += step
            }
            context.stroke(path, with: .color(.white), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

/// Four 34×34 brackets inset 14pt, 3pt stroke (§6.6).
private struct CornerBrackets: View {
    private let arm: CGFloat = 34
    private let inset: CGFloat = 14
    private let lineWidth: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            Path { path in
                // Top-left
                path.move(to: CGPoint(x: inset, y: inset + arm))
                path.addLine(to: CGPoint(x: inset, y: inset))
                path.addLine(to: CGPoint(x: inset + arm, y: inset))
                // Top-right
                path.move(to: CGPoint(x: size.width - inset - arm, y: inset))
                path.addLine(to: CGPoint(x: size.width - inset, y: inset))
                path.addLine(to: CGPoint(x: size.width - inset, y: inset + arm))
                // Bottom-right
                path.move(to: CGPoint(x: size.width - inset, y: size.height - inset - arm))
                path.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
                path.addLine(to: CGPoint(x: size.width - inset - arm, y: size.height - inset))
                // Bottom-left
                path.move(to: CGPoint(x: inset + arm, y: size.height - inset))
                path.addLine(to: CGPoint(x: inset, y: size.height - inset))
                path.addLine(to: CGPoint(x: inset, y: size.height - inset - arm))
            }
            .stroke(
                Color.white.opacity(0.85),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .allowsHitTesting(false)
    }
}

extension DS {
    /// §6.6's dark scan surface. Not part of the light `DS` palette — the camera
    /// screen is the one place the app goes dark, so these live with it.
    static let scanSurface = Color(hex: 0x0B1116)
    static let scanViewfinder = Color(hex: 0x151E26)
}
