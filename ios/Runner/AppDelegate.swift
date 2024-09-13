import UIKit
import Flutter
import MobileCoreServices
import os // OSLog를 위해 추가

@main
@objc class AppDelegate: FlutterAppDelegate {
    // OSLog 인스턴스 생성
    let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "AppDelegate")
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        os_log("Application is launching", log: osLog, type: .info)
        
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let clipboardChannel = FlutterMethodChannel(name: "com.example.nursing_quiz_app_6/clipboard",
                                                    binaryMessenger: controller.binaryMessenger)
        
        os_log("Setting up method channel handler", log: osLog, type: .info)
        clipboardChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            guard let self = self else { return }
            
            if call.method == "getClipboardImage" {
                os_log("Received getClipboardImage method call", log: self.osLog, type: .info)
                if let image = UIPasteboard.general.image {
                    os_log("Image found in clipboard", log: self.osLog, type: .info)
                    if let data = image.pngData() {
                        os_log("Image converted to PNG data", log: self.osLog, type: .info)
                        result(FlutterStandardTypedData(bytes: data))
                    } else {
                        os_log("Failed to convert image to PNG", log: self.osLog, type: .error)
                        result(FlutterError(code: "UNAVAILABLE",
                                            message: "Image could not be converted to PNG",
                                            details: nil))
                    }
                } else {
                    // 'warning' 대신 'default' 사용
                    os_log("No image found in clipboard", log: self.osLog, type: .default)
                    result(FlutterError(code: "UNAVAILABLE",
                                        message: "No image on clipboard",
                                        details: nil))
                }
            } else {
                os_log("Received unknown method call: %{public}@", log: self.osLog, type: .error, call.method)
                result(FlutterMethodNotImplemented)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        os_log("Application launch completed", log: osLog, type: .info)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}