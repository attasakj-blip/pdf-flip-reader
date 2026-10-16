import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let files = NativeFiles()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PagelumeFiles") {
      files.attach(registrar.messenger())
    }
  }
}

/// iOS side of lib/native_files.dart (Android: MainActivity.kt).
///
/// Files picked in the Files app are only lent to the app, so each one is
/// remembered as a bookmark inside its uri ("bookmark:?folder=…&b=…&sub=…"):
/// the app can then write a signed copy over the original, or into a folder
/// the user chose, long after the picker closed.
final class NativeFiles: NSObject, UIDocumentPickerDelegate {
  private var pending: FlutterResult?
  private var onPick: ((URL) throws -> Any?)?

  func attach(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "pdf_flip_reader/files", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let fm = FileManager.default
    do {
      switch call.method {
      case "openPdf":
        let dir = URL(fileURLWithPath: args["dir"] as? String ?? NSTemporaryDirectory())
        pick(UIDocumentPickerViewController(forOpeningContentTypes: [.pdf]), result) { url in
          let name = url.lastPathComponent
          let dest = dir.appendingPathComponent("\(Int(Date().timeIntervalSince1970 * 1000))_\(name)")
          try Self.coordinatedCopy(from: url, to: dest)
          return ["uri": try Self.ref(url), "name": name, "path": dest.path]
        }
      case "createPdf":
        // The export picker moves a file to where the user wants it; an
        // empty one goes now and the PDF is written over it right after.
        let name = args["name"] as? String ?? "document.pdf"
        let tmpDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let tmp = tmpDir.appendingPathComponent(name)
        fm.createFile(atPath: tmp.path, contents: Data())
        pick(UIDocumentPickerViewController(forExporting: [tmp], asCopy: false), result) { url in
          ["uri": try Self.ref(url), "name": url.lastPathComponent]
        }
      case "createInNewFolder":
        let folder = args["folder"] as? String ?? "Pagelume"
        let name = args["name"] as? String ?? "document.pdf"
        pick(UIDocumentPickerViewController(forOpeningContentTypes: [.folder]), result) { url in
          let dir = url.appendingPathComponent(folder, isDirectory: true)
          try fm.createDirectory(at: dir, withIntermediateDirectories: true)
          fm.createFile(atPath: dir.appendingPathComponent(name).path, contents: Data())
          return ["uri": try Self.ref(url, sub: "\(folder)/\(name)", folder: folder), "name": name]
        }
      case "canWrite":
        let uri = args["uri"] as? String ?? ""
        result((try? Self.access(uri) { fm.isWritableFile(atPath: $0.path) }) ?? false)
      case "write":
        let uri = args["uri"] as? String ?? ""
        let src = URL(fileURLWithPath: args["path"] as? String ?? "")
        background(result) {
          try Self.access(uri) { dest in try Self.coordinatedCopy(from: src, to: dest) }
          return nil
        }
      case "copyImage":
        guard let image = UIImage(contentsOfFile: args["path"] as? String ?? "") else {
          throw NSError(domain: "files", code: 1, userInfo: [NSLocalizedDescriptionKey: "no image"])
        }
        UIPasteboard.general.image = image
        result(nil)
      case "edgeSwipes":
        result(nil)  // iOS has no back swipe from the right edge to keep clear.
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(code: "files", message: error.localizedDescription, details: nil))
    }
  }

  // MARK: picker

  private func pick(
    _ picker: UIDocumentPickerViewController, _ result: @escaping FlutterResult,
    then work: @escaping (URL) throws -> Any?
  ) {
    pending?(nil)  // an older picker that never answered
    pending = result
    onPick = work
    picker.delegate = self
    picker.allowsMultipleSelection = false
    guard let top = Self.topController() else {
      finish(nil)
      return
    }
    top.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let url = urls.first, let result = pending, let work = onPick else {
      finish(nil)
      return
    }
    pending = nil
    onPick = nil
    background(result) {
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      return try work(url)
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(nil)
  }

  private func finish(_ value: Any?) {
    let result = pending
    pending = nil
    onPick = nil
    result?(value)
  }

  private func background(_ result: @escaping FlutterResult, _ work: @escaping () throws -> Any?) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let value = try work()
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "files", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private static func topController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  // MARK: bookmarks

  /// The uri the Dart side keeps for [url] (or for [sub] inside it).
  private static func ref(_ url: URL, sub: String? = nil, folder: String? = nil) throws -> String {
    let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    var c = URLComponents()
    c.scheme = "bookmark"
    c.queryItems = [
      URLQueryItem(name: "folder", value: folder ?? label(url.deletingLastPathComponent())),
      URLQueryItem(name: "b", value: data.base64EncodedString()),
    ] + (sub.map { [URLQueryItem(name: "sub", value: $0)] } ?? [])
    // "+" survives URLComponents but reads as a space on the Dart side.
    c.percentEncodedQuery = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
    return c.string ?? ""
  }

  /// Runs [body] with the file [uri] points at, while the app may use it.
  private static func access<T>(_ uri: String, _ body: (URL) throws -> T) throws -> T {
    let items = URLComponents(string: uri)?.queryItems ?? []
    guard let b = items.first(where: { $0.name == "b" })?.value, let data = Data(base64Encoded: b) else {
      throw NSError(domain: "files", code: 2, userInfo: [NSLocalizedDescriptionKey: "unknown file"])
    }
    var stale = false
    let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let target = items.first(where: { $0.name == "sub" })?.value.map { url.appendingPathComponent($0) } ?? url
    return try body(target)
  }

  private static func coordinatedCopy(from src: URL, to dest: URL) throws {
    var coordError: NSError?
    var copyError: Error?
    NSFileCoordinator().coordinate(readingItemAt: src, options: [], writingItemAt: dest, options: .forReplacing, error: &coordError) { from, to in
      do {
        try Data(contentsOf: from).write(to: to)
      } catch {
        copyError = error
      }
    }
    if let e = coordError ?? copyError { throw e }
  }

  /// A short name for a folder, as the Files app shows it.
  private static func label(_ dir: URL) -> String {
    let name = dir.lastPathComponent
    switch name {
    case "com~apple~CloudDocs": return "iCloud Drive"
    case "File Provider Storage", "Documents": return "On My iPhone"
    default: return name
    }
  }
}
