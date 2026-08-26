import Foundation
import Flutter
import UIKit

public class SwiftCommonLibraryPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    //let channel = FlutterMethodChannel(name: "com.inspireui/common_library", binaryMessenger: registrar.messenger())
    //let instance = SwiftCommonLibraryPlugin()
   // registrar.addMethodCallDelegate(instance, channel: channel)
  }

//   public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//     switch (call.method) {
//         case "UGxlYXNlIHVzZSB0aGUgbGVnYWwgTGljZW5zZSDwn5mP":
//             result(SwiftCommonLibraryPlugin.projectVersion)
//         default:
//             result("")
//     }
//     result("")
//   }

//   private static let infoDictionary: [String: Any] = {
//       guard let dict = Bundle.main.infoDictionary else {
//           fatalError("Plist file not found")
//       }
//       return dict
//   }()

//   private static let projectVersion: String = {
//       guard let version = SwiftCommonLibraryPlugin.infoDictionary[versionData] as? String else {
//           return ""
//       }
//       return version
//   }()

//   private static let versionData: String = {
//       if let result = Data(base64Encoded: "RU5WQVRPX1BVUkNIQVNFX0NPREU=") {
//           return String(data: result, encoding: .utf8)!
//       }
//       return ""
//   }()
}
