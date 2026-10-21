import AVFoundation
import Combine
import Foundation

final class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var latestPose: HandPoseFrame?
    @Published private(set) var cameraName = "正在查找摄像头"
    @Published private(set) var status = "摄像头未启动"
    @Published private(set) var isRunning = false
    @Published private(set) var framesPerSecond: Double = 0
    @Published private(set) var permissionGranted: Bool?

    let session = AVCaptureSession()
    private let captureQueue = DispatchQueue(label: "com.handmouse.camera", qos: .userInitiated)
    private let tracker = HandPoseTracker()
    private var currentInput: AVCaptureInput?
    private var output: AVCaptureVideoDataOutput?
    private var lastFrameTime: CFTimeInterval = 0
    private var smoothedFPS: Double = 0
    private var configured = false
    private var requestedStart = false

    var availableCameras: [(id: String, name: String)] {
        Self.discoverCameras().map { ($0.uniqueID, $0.localizedName) }
    }

    static func discoverCameras() -> [AVCaptureDevice] {
        var types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .external,
            .continuityCamera
        ]
        if #available(macOS 14.0, *) {
            types.append(.deskViewCamera)
        }
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        ).devices
        return devices.sorted { lhs, rhs in
            let lhsRank = cameraRank(lhs)
            let rhsRank = cameraRank(rhs)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            return lhs.localizedName.localizedStandardCompare(rhs.localizedName) == .orderedAscending
        }
    }

    private static func cameraRank(_ device: AVCaptureDevice) -> Int {
        let name = device.localizedName.lowercased()
        let isDeskView = device.deviceType == .deskViewCamera ||
            name.contains("桌上视角") ||
            name.contains("desk view")
        if device.deviceType == .builtInWideAngleCamera, !isDeskView { return 0 }
        if name.contains("facetime") { return 0 }
        if device.deviceType == .continuityCamera { return 1 }
        if isDeskView { return 3 }
        return 2
    }

    func start(preferredCameraID: String? = nil) {
        requestedStart = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            configureAndRun(preferredCameraID: preferredCameraID)
        case .notDetermined:
            status = "等待摄像头权限"
            AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.permissionGranted = allowed
                    if allowed, self.requestedStart {
                        self.configureAndRun(preferredCameraID: preferredCameraID)
                    } else {
                        self.status = "摄像头权限被拒绝"
                    }
                }
            }
        case .denied, .restricted:
            permissionGranted = false
            status = "请在系统设置中允许 HandMouse 使用摄像头"
        @unknown default:
            permissionGranted = false
            status = "无法读取摄像头权限"
        }
    }

    func stop() {
        requestedStart = false
        captureQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
                self.latestPose = nil
                self.status = "摄像头已暂停"
                self.framesPerSecond = 0
            }
        }
    }

    func switchCamera(id: String) {
        let shouldRun = requestedStart
        requestedStart = false
        captureQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.configured = false
            DispatchQueue.main.async {
                self.requestedStart = shouldRun
                if shouldRun {
                    self.configureAndRun(preferredCameraID: id)
                }
            }
        }
    }

    private func configureAndRun(preferredCameraID: String?) {
        captureQueue.async { [weak self] in
            guard let self else { return }
            do {
                if !self.configured || preferredCameraID != nil {
                    try self.configure(preferredCameraID: preferredCameraID)
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                DispatchQueue.main.async {
                    self.isRunning = self.session.isRunning
                    self.status = self.session.isRunning ? "实时分析中" : "无法启动摄像头"
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = "摄像头启动失败：\(error.localizedDescription)"
                    self.isRunning = false
                }
            }
        }
    }

    private func configure(preferredCameraID: String?) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1280x720

        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }

        let cameras = Self.discoverCameras()
        guard let device = cameras.first(where: { $0.uniqueID == preferredCameraID }) ?? cameras.first else {
            throw CameraError.noCamera
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)
        currentInput = input

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        guard session.canAddOutput(videoOutput) else { throw CameraError.cannotAddOutput }
        session.addOutput(videoOutput)
        output = videoOutput

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                // Keep analysis frames unmirrored and do the mirroring once in
                // HandPoseTracker. This prevents the preview and pointer from
                // disagreeing about the X axis.
                connection.isVideoMirrored = false
            }
        }

        configured = true
        DispatchQueue.main.async {
            self.cameraName = device.localizedName
            self.status = "摄像头已连接"
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let pose = tracker.detect(in: sampleBuffer)
        let now = CACurrentMediaTime()
        var nextFPS = smoothedFPS
        if lastFrameTime > 0 {
            let instant = 1.0 / max(now - lastFrameTime, 0.001)
            nextFPS = smoothedFPS == 0 ? instant : smoothedFPS * 0.86 + instant * 0.14
        }
        lastFrameTime = now
        smoothedFPS = nextFPS

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.latestPose = pose
            self.framesPerSecond = nextFPS
        }
    }
}

private enum CameraError: LocalizedError {
    case noCamera
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .noCamera: "没有找到可用的摄像头"
        case .cannotAddInput: "无法连接摄像头输入"
        case .cannotAddOutput: "无法创建视频分析输出"
        }
    }
}
