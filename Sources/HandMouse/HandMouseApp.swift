import AVFoundation
import Foundation
import SwiftUI
import Vision

@main
enum HandMouseMain {
    static func main() {
        if CommandLine.arguments.contains("--smoke") {
            runSmokeCheck()
            return
        }
        HandMouseDesktopApp.main()
    }
}

struct HandMouseDesktopApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onAppear {
                    appDelegate.model = model
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?

    func applicationWillTerminate(_ notification: Notification) {
        model?.shutdown()
    }
}

private func runSmokeCheck() {
    let request = VNDetectHumanHandPoseRequest()
    request.maximumHandCount = 1
    let hasCamera = AVCaptureDevice.default(for: .video) != nil
    let classifier = GestureClassifier()
    let sample = HandPoseFrame.syntheticPinch()
    let reading = classifier.classify(sample)

    print("handmouse-smoke=ok")
    print("vision-request=ok")
    print("camera-present=\(hasCamera ? "yes" : "no")")
    print("pinch-test=\(String(format: "%.3f", reading.pinchRatio))")
}
