import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var channel: FlutterMethodChannel?
  private var pendingPaths: [String] = []
  private var dartReady = false

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    let paths = urls.filter { $0.isFileURL }.map { $0.path }
    if dartReady, let channel = channel {
      channel.invokeMethod("open", arguments: paths.map { ["path": $0] })
    } else {
      pendingPaths.append(contentsOf: paths)
    }
  }

  func attach(to controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "voges_slides/open",
      binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pending", let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.dartReady = true
      result(self.pendingPaths.map { ["path": $0] })
      self.pendingPaths.removeAll()
    }
    self.channel = channel

    let fonts = FlutterMethodChannel(
      name: "voges_slides/fonts",
      binaryMessenger: controller.engine.binaryMessenger)
    fonts.setMethodCallHandler { call, result in
      guard call.method == "families" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(NSFontManager.shared.availableFontFamilies.filter { !$0.hasPrefix(".") })
    }

    // The app is sandboxed and a child process would inherit the sandbox, so
    // the embedded updater is opened through LaunchServices. Arguments are
    // not passed: macOS drops them for sandboxed callers.
    let updater = FlutterMethodChannel(
      name: "voges/updater",
      binaryMessenger: controller.engine.binaryMessenger)
    updater.setMethodCallHandler { call, result in
      guard call.method == "launch" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let helper = Bundle.main.bundleURL.appendingPathComponent(
        "Contents/Helpers/Voges Updater.app", isDirectory: true)
      guard Bundle(url: helper)?.bundleIdentifier == "com.omanoloneto.vogesUpdater" else {
        result("missing")
        return
      }
      var replied = false
      let reply: (String) -> Void = { value in
        if !replied {
          replied = true
          result(value)
        }
      }
      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = true
      NSWorkspace.shared.openApplication(at: helper, configuration: configuration) { _, error in
        DispatchQueue.main.async { reply(error == nil ? "started" : "failed") }
      }
      // a Gatekeeper prompt holds the completion for about 30 seconds
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) { reply("started") }
    }
  }
}
