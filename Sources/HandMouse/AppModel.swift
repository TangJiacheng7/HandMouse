import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var latestPose: HandPoseFrame?
    @Published private(set) var control = ControlSnapshot()
    @Published private(set) var active = false
    @Published private(set) var status = "准备好后点击“开始控制”"
    @Published private(set) var cameraName = "正在查找摄像头"
    @Published private(set) var cameraStatus = "摄像头未启动"
    @Published private(set) var framesPerSecond: Double = 0
    @Published private(set) var accessibilityGranted = MouseInjector.isAccessibilityGranted
    @Published private(set) var selectedCameraID: String?

    let camera: CameraController
    private let engine = GestureControlEngine()
    private var cancellables: Set<AnyCancellable> = []
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?

    init(camera: CameraController = CameraController()) {
        self.camera = camera
        let savedSensitivity = UserDefaults.standard.object(forKey: "handmouse.sensitivity") as? Double ?? 1.0
        engine.sensitivity = savedSensitivity
        let availableCameras = camera.availableCameras
        let savedCameraID = UserDefaults.standard.string(forKey: "handmouse.selectedCameraID")
        let selected = availableCameras.first(where: { $0.id == savedCameraID }) ?? availableCameras.first
        selectedCameraID = selected?.id
        cameraName = selected?.name ?? "没有可用摄像头"

        engine.onUpdate = { [weak self] snapshot in
            self?.control = snapshot
        }

        camera.$latestPose
            .receive(on: RunLoop.main)
            .sink { [weak self] pose in
                guard let self else { return }
                self.latestPose = pose
                if self.active {
                    self.engine.process(frame: pose)
                }
            }
            .store(in: &cancellables)

        camera.$cameraName
            .receive(on: RunLoop.main)
            .assign(to: &$cameraName)

        camera.$status
            .receive(on: RunLoop.main)
            .assign(to: &$cameraStatus)

        camera.$framesPerSecond
            .receive(on: RunLoop.main)
            .assign(to: &$framesPerSecond)

        installEmergencyHotkey()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }
    }

    var sensitivity: Double {
        get { engine.sensitivity }
        set {
            let bounded = min(2.4, max(0.35, newValue))
            engine.sensitivity = bounded
            UserDefaults.standard.set(bounded, forKey: "handmouse.sensitivity")
        }
    }

    var cameras: [(id: String, name: String)] {
        camera.availableCameras
    }

    func toggleControl() {
        active ? stopControl(reason: "控制已暂停") : startControl()
    }

    func startControl() {
        guard !active else { return }
        _ = MouseInjector.requestAccessibility()
        refreshPermissions()
        engine.begin()
        active = true
        status = accessibilityGranted
            ? "手势控制已接管，食指移动指针"
            : "控制已启动，请在系统设置中允许“辅助功能”"
        camera.start(preferredCameraID: selectedCameraID)
    }

    func stopControl(reason: String = "控制已停止") {
        engine.end()
        active = false
        latestPose = nil
        control = ControlSnapshot()
        status = reason
        camera.stop()
    }

    func emergencyPause() {
        stopControl(reason: "已由紧急快捷键暂停")
    }

    func recalibrate() {
        engine.recalibrate()
        refreshPermissions()
        status = accessibilityGranted
            ? "已重新校准：以当前手部位置为起点"
            : "已校准，但辅助功能权限仍未开启"
    }

    func selectCamera(id: String) {
        selectedCameraID = id
        UserDefaults.standard.set(id, forKey: "handmouse.selectedCameraID")
        if let camera = cameras.first(where: { $0.id == id }) {
            cameraName = camera.name
        }
        if active {
            camera.switchCamera(id: id)
        }
    }

    func refreshPermissions() {
        accessibilityGranted = MouseInjector.isAccessibilityGranted
        if active, accessibilityGranted {
            status = "辅助功能已授权，手势控制正在运行"
        }
    }

    func openPrivacySettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        else { return }
        NSWorkspace.shared.open(url)
    }

    func shutdown() {
        removeKeyMonitors()
        if active {
            engine.end()
            camera.stop()
        }
    }

    private func installEmergencyHotkey() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard Self.isEmergencyPause(event) else { return }
            Task { @MainActor in self?.emergencyPause() }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard Self.isEmergencyPause(event) else { return event }
            Task { @MainActor in self?.emergencyPause() }
            return nil
        }
    }

    private func removeKeyMonitors() {
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
        }
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
        globalKeyMonitor = nil
        localKeyMonitor = nil
    }

    private static func isEmergencyPause(_ event: NSEvent) -> Bool {
        guard event.keyCode == 53 else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains([.control, .option, .command])
    }
}
