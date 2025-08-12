import UIKit
import Flutter
import Contacts

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Flutter 메서드 채널 설정
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let contactsChannel = FlutterMethodChannel(name: "contacts_permission_channel", binaryMessenger: controller.binaryMessenger)
    
    contactsChannel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "checkContactsPermission":
        self?.checkContactsPermission(result: result)
      case "requestContactsPermission":
        self?.requestContactsPermission(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // 주소록 권한 상태 확인
  private func checkContactsPermission(result: @escaping FlutterResult) {
    let status = CNContactStore.authorizationStatus(for: .contacts)
    
    switch status {
    case .authorized:
      result("granted")
    case .denied:
      result("denied")
    case .restricted:
      result("restricted")
    case .notDetermined:
      result("notDetermined")
    @unknown default:
      result("unknown")
    }
  }
  
  // 주소록 권한 요청
  private func requestContactsPermission(result: @escaping FlutterResult) {
    let contactStore = CNContactStore()
    contactStore.requestAccess(for: .contacts) { granted, error in
      DispatchQueue.main.async {
        if granted {
          result("granted")
        } else {
          result("denied")
        }
      }
    }
  }
}
