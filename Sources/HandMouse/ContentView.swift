import AVFoundation
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage("handmouse.sensitivity") private var sensitivity = 1.0

    private let mint = Color(red: 0.33, green: 0.96, blue: 0.63)
    private let teal = Color(red: 0.16, green: 0.70, blue: 0.68)
    private let ink = Color(red: 0.045, green: 0.065, blue: 0.080)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ink,
                    Color(red: 0.075, green: 0.11, blue: 0.14),
                    Color(red: 0.045, green: 0.075, blue: 0.085)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                header
                cameraStage
                controls
                footer
            }
            .padding(24)
        }
        .frame(minWidth: 680, minHeight: 740)
        .onAppear {
            sensitivity = model.sensitivity
        }
        .onChange(of: sensitivity) { _, value in
            model.sensitivity = value
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [mint.opacity(0.24), teal.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(mint)
            }
            .frame(width: 48, height: 48)
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(mint.opacity(0.28), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("HandMouse")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("用摄像头把指尖变成鼠标")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.54))
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(model.active ? mint : Color.white.opacity(0.25))
                    .frame(width: 8, height: 8)
                    .shadow(color: model.active ? mint.opacity(0.9) : .clear, radius: 6)
                Text(model.active ? "接管中" : "待机")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(model.active ? mint : .white.opacity(0.55))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.055), in: Capsule())
            .overlay {
                Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private var cameraStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.42))

            CameraPreview(session: model.camera.session)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            if model.latestPose == nil {
                VStack(spacing: 10) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 38, weight: .light))
                    Text(model.cameraStatus)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.5))
            }

            HandSkeletonOverlay(pose: model.latestPose)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .allowsHitTesting(false)

            VStack {
                HStack(alignment: .top, spacing: 10) {
                    telemetry
                    Spacer()
                    gestureBadge
                }
                Spacer()
                HStack(spacing: 8) {
                    Label(model.cameraName, systemImage: "video.fill")
                    Spacer()
                    Text(String(format: "%.0f FPS", model.framesPerSecond))
                }
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.68))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial.opacity(0.72), in: Capsule())
                .padding(14)
            }
            .padding(2)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [mint.opacity(0.45), .white.opacity(0.04), teal.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .aspectRatio(16.0 / 10.5, contentMode: .fit)
    }

    private var telemetry: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(model.control.mode.title)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(mint)
            Text(String(format: "捏合比 %.2f  ·  阈值 %.2f / %.2f", model.control.pinchRatio, 0.42, 0.55))
            Text(String(format: "置信度 %.0f%%  ·  左右张掌翻页", model.control.confidence * 100))
            Text(model.control.isPressed ? "左键已按下 · 移动可拖拽" : "松开捏合完成点击")
        }
        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
        .foregroundStyle(.white.opacity(0.66))
        .padding(12)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var gestureBadge: some View {
        Image(systemName: modeSymbol)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(model.active ? ink : .white.opacity(0.5))
            .frame(width: 48, height: 48)
            .background(
                model.active ? mint : Color.white.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .animation(.easeOut(duration: 0.16), value: model.control.mode)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Button {
                    model.toggleControl()
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: model.active ? "pause.fill" : "play.fill")
                        Text(model.active ? "暂停控制" : "开始控制")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(model.active ? .white : ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        model.active ? Color.white.opacity(0.10) : mint,
                        in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    model.recalibrate()
                } label: {
                    Label("重新校准", systemImage: "scope")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(
                            Color.white.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!model.active)
                .opacity(model.active ? 1 : 0.45)

                Menu {
                    ForEach(model.cameras, id: \.id) { camera in
                        Button {
                            model.selectCamera(id: camera.id)
                        } label: {
                            HStack {
                                Text(camera.name)
                                if camera.id == model.selectedCameraID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "video.badge.ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 44, height: 44)
                        .background(
                            Color.white.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            HStack(spacing: 14) {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                Slider(value: $sensitivity, in: 0.35...2.4)
                    .tint(mint)
                Image(systemName: "hare.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(mint.opacity(0.9))
                Text(String(format: "灵敏度 %.2f×", sensitivity))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 92, alignment: .trailing)
            }

            HStack(spacing: 10) {
                Image(systemName: model.accessibilityGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .foregroundStyle(model.accessibilityGranted ? mint : Color.orange)
                Text(model.status)
                    .lineLimit(1)
                Spacer()
                if !model.accessibilityGranted {
                    Button("打开辅助功能设置") {
                        model.openPrivacySettings()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(mint)
                }
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.58))
        }
        .padding(15)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.065), lineWidth: 1)
        }
    }

    private var footer: some View {
        HStack {
            Text("食指移动  ·  拇指与食指捏合  ·  保持捏合拖动")
            Spacer()
            Label("⌃⌥⌘Esc 紧急暂停", systemImage: "escape")
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(.white.opacity(0.32))
    }

    private var modeSymbol: String {
        switch model.control.mode {
        case .none: "hand.raised"
        case .openPalm: "hand.raised.fill"
        case .point: "hand.point.up.left.fill"
        case .pinch: "hand.tap.fill"
        }
    }
}

private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.attach(session: session)
        return view
    }

    func updateNSView(_ view: CameraPreviewNSView, context: Context) {
        view.attach(session: session)
    }
}

private final class CameraPreviewNSView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private weak var attachedSession: AVCaptureSession?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.black.cgColor
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attach(session: AVCaptureSession) {
        guard attachedSession !== session else { return }
        attachedSession = session
        previewLayer.session = session
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }
}

private struct HandSkeletonOverlay: View {
    let pose: HandPoseFrame?

    private let segments: [(HandJoint, HandJoint)] = [
        (.wrist, .thumbCMC), (.thumbCMC, .thumbMP), (.thumbMP, .thumbIP), (.thumbIP, .thumbTip),
        (.wrist, .indexMCP), (.indexMCP, .indexPIP), (.indexPIP, .indexDIP), (.indexDIP, .indexTip),
        (.wrist, .middleMCP), (.middleMCP, .middlePIP), (.middlePIP, .middleDIP), (.middleDIP, .middleTip),
        (.wrist, .ringMCP), (.ringMCP, .ringPIP), (.ringPIP, .ringDIP), (.ringDIP, .ringTip),
        (.wrist, .littleMCP), (.littleMCP, .littlePIP), (.littlePIP, .littleDIP), (.littleDIP, .littleTip)
    ]

    var body: some View {
        Canvas { context, size in
            guard let pose else { return }
            var bones = Path()
            for (first, second) in segments {
                guard let a = point(pose.landmarks[first], in: size),
                      let b = point(pose.landmarks[second], in: size) else { continue }
                bones.move(to: a)
                bones.addLine(to: b)
            }
            context.stroke(
                bones,
                with: .color(Color(red: 0.42, green: 1, blue: 0.65)),
                style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
            )

            for (joint, normalized) in pose.landmarks {
                guard let point = point(normalized, in: size) else { continue }
                let diameter: CGFloat = [.indexTip, .thumbTip].contains(joint) ? 8 : 5
                let rect = CGRect(
                    x: point.x - diameter / 2,
                    y: point.y - diameter / 2,
                    width: diameter,
                    height: diameter
                )
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.96)))
                context.stroke(
                    Path(ellipseIn: rect.insetBy(dx: 1, dy: 1)),
                    with: .color(Color(red: 0.30, green: 0.88, blue: 0.53)),
                    lineWidth: 1.3
                )
            }
        }
    }

    private func point(_ normalized: CGPoint?, in size: CGSize) -> CGPoint? {
        guard let normalized else { return nil }
        return CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }
}
