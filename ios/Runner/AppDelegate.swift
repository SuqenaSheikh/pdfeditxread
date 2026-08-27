import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)

    if let registrar = self.registrar(forPlugin: "FolioSaveImages") {
      let channel = FlutterMethodChannel(
        name: "folio/save_images",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        if call.method == "saveImages" {
          let paths = (call.arguments as? [String: Any])?["paths"] as? [String] ?? []
          self.saveImagesToPhotos(paths: paths, result: result)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return ok
  }

  /// Adds images to Photos using add-only access. No full library permission.
  private func saveImagesToPhotos(paths: [String], result: @escaping FlutterResult) {
    func addAssets() {
      var saved = 0
      let group = DispatchGroup()
      for path in paths {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else { continue }
        group.enter()
        PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
        }, completionHandler: { success, _ in
          if success { saved += 1 }
          group.leave()
        })
      }
      group.notify(queue: .main) {
        result(saved)
      }
    }

    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        if status == .authorized || status == .limited {
          addAssets()
        } else {
          DispatchQueue.main.async { result(0) }
        }
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        if status == .authorized {
          addAssets()
        } else {
          DispatchQueue.main.async { result(0) }
        }
      }
    }
  }
}
