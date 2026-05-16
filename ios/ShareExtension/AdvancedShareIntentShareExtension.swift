import Foundation
import MobileCoreServices
import Photos
import Social
import UIKit

@objc(open) class AdvancedShareIntentShareExtension: UIViewController {
  @objc open var appGroupIdentifier: String { "" }
  @objc open var containingAppScheme: String { "" }
  @objc open var sharedDirectoryName: String { "AdvancedShareIntent" }

  private var activityIndicator: UIActivityIndicatorView?
  private var cancelButton: UIButton?

  open override func viewDidLoad() {
    super.viewDidLoad()
    setupLoadingView()
    processSharedItems()
  }

  @objc private func cancel() {
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  private func setupLoadingView() {
    view.subviews.forEach { $0.removeFromSuperview() }
    view.backgroundColor = .systemBackground

    let indicator = UIActivityIndicatorView(style: .large)
    indicator.translatesAutoresizingMaskIntoConstraints = false
    indicator.startAnimating()
    view.addSubview(indicator)
    activityIndicator = indicator

    let button = UIButton(type: .system)
    button.setTitle("Cancel", for: .normal)
    button.setTitleColor(.systemRed, for: .normal)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.addTarget(self, action: #selector(cancel), for: .touchUpInside)
    view.addSubview(button)
    cancelButton = button

    NSLayoutConstraint.activate([
      indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      button.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 40),
      button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      button.heightAnchor.constraint(equalToConstant: 44)
    ])
  }

  private func processSharedItems() {
    Task {
      let payload = await ShareExtensionPayloadBuilder(
        context: extensionContext,
        appGroupIdentifier: appGroupIdentifier,
        sharedDirectoryName: sharedDirectoryName
      ).build()

      save(payload: payload)
      openContainingApp()
    }
  }

  private func save(payload: [String: Any]) {
    guard !appGroupIdentifier.isEmpty,
          let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
      return
    }

    defaults.set(payload, forKey: "AdvancedShareIntentPayload")
    defaults.synchronize()
  }

  private func openContainingApp() {
    guard !containingAppScheme.isEmpty,
          let url = URL(string: "\(containingAppScheme)://share-intent?source=share_extension&timestamp=\(Int(Date().timeIntervalSince1970))") else {
      extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
      return
    }

    extensionContext?.open(url) { [weak self] _ in
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
      }
    }
  }
}

private final class ShareExtensionPayloadBuilder {
  private let context: NSExtensionContext?
  private let appGroupIdentifier: String
  private let sharedDirectoryName: String
  private let lock = NSLock()
  private var indexedFiles: [Int: [String: Any]] = [:]
  private var indexedText: [Int: String] = [:]

  init(context: NSExtensionContext?, appGroupIdentifier: String, sharedDirectoryName: String) {
    self.context = context
    self.appGroupIdentifier = appGroupIdentifier
    self.sharedDirectoryName = sharedDirectoryName
  }

  func build() async -> [String: Any] {
    let providers = (context?.inputItems as? [NSExtensionItem])?
      .flatMap { $0.attachments ?? [] } ?? []

    for (index, provider) in providers.enumerated() {
      await process(provider: provider, index: index)
    }

    let files = orderedFiles()
    let text = orderedText().joined(separator: "\n")
    let firstMimeType = files.first?["mimeType"] as? String

    var payload: [String: Any] = [
      "files": files,
      "isInitial": true,
      "receivedAt": Date().timeIntervalSince1970 * 1000
    ]

    if !text.isEmpty {
      payload["text"] = text
      payload["webUrl"] = text.firstWebURL
    }
    if let firstMimeType {
      payload["mimeType"] = firstMimeType
    }

    return payload
  }

  private func process(provider: NSItemProvider, index: Int) async {
    if let text = await loadText(provider: provider) {
      store(text: text, index: index)
      return
    }

    if let assetFile = await loadPhotosAsset(provider: provider, index: index) {
      store(file: assetFile, index: index)
      return
    }

    if let file = await loadFile(provider: provider, index: index) {
      store(file: file, index: index)
    }
  }

  private func loadText(provider: NSItemProvider) async -> String? {
    let identifiers = [kUTTypeURL as String, kUTTypePlainText as String, kUTTypeText as String]
    guard let identifier = identifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
      return nil
    }

    return await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
        if let url = item as? URL {
          continuation.resume(returning: url.absoluteString)
        } else if let string = item as? String {
          continuation.resume(returning: string)
        } else if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
          continuation.resume(returning: string)
        } else {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  private func loadPhotosAsset(provider: NSItemProvider, index: Int) async -> [String: Any]? {
    let identifiers = [
      "com.apple.photos.asset",
      "com.apple.photos.asset-id",
      "com.apple.photos.asset-url",
      "com.apple.private.auto-fill-photos-asset",
      "com.apple.private.photos-cloud-sharing",
      "com.apple.photos.library-asset",
      "com.apple.photos.asset-identifier"
    ]

    for identifier in identifiers where provider.hasItemConformingToTypeIdentifier(identifier) {
      if let assetId = await loadAssetIdentifier(provider: provider, identifier: identifier) {
        return photosAssetPayload(assetId: assetId)
      }
    }

    return nil
  }

  private func loadAssetIdentifier(provider: NSItemProvider, identifier: String) async -> String? {
    await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
        if let assetId = item as? String {
          continuation.resume(returning: assetId)
        } else if let url = item as? URL, url.scheme == "ph" {
          continuation.resume(returning: url.absoluteString.replacingOccurrences(of: "ph://", with: ""))
        } else if let data = item as? Data,
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                  let assetId = plist["assetID"] as? String {
          continuation.resume(returning: assetId)
        } else {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  private func photosAssetPayload(assetId: String) -> [String: Any] {
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    let asset = assets.firstObject
    let mediaType = asset?.mediaType == .video ? "video" : "image"
    let mimeType = mediaType == "video" ? "photos/video-asset" : "photos/image-asset"
    let dateTaken = asset?.creationDate?.timeIntervalSince1970 ?? 0

    return [
      "uri": "ph://\(assetId)",
      "fileName": "Photo Asset",
      "name": "Photo Asset",
      "mimeType": mimeType,
      "type": mediaType,
      "dateTaken": dateTaken * 1000,
      "localIdentifier": assetId,
      "originalUri": "ph://\(assetId)"
    ]
  }

  private func loadFile(provider: NSItemProvider, index: Int) async -> [String: Any]? {
    guard let identifier = preferredFileIdentifier(provider: provider) else {
      return nil
    }

    return await withCheckedContinuation { continuation in
      provider.loadFileRepresentation(forTypeIdentifier: identifier) { [weak self] url, _ in
        guard let self, let url else {
          continuation.resume(returning: nil)
          return
        }

        let destination = self.sharedContainerDirectory()
          .appendingPathComponent(UUID().uuidString)
          .appendingPathExtension(url.pathExtension)

        do {
          if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
          }
          try FileManager.default.copyItem(at: url, to: destination)
          continuation.resume(returning: self.filePayload(for: destination, provider: provider))
        } catch {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  private func preferredFileIdentifier(provider: NSItemProvider) -> String? {
    let preferred = [
      kUTTypeImage as String,
      kUTTypeMovie as String,
      kUTTypePDF as String,
      kUTTypeData as String
    ]

    return preferred.first(where: { provider.hasItemConformingToTypeIdentifier($0) })
      ?? provider.registeredTypeIdentifiers.first
  }

  private func filePayload(for url: URL, provider: NSItemProvider) -> [String: Any] {
    let mimeType = provider.registeredTypeIdentifiers.first ?? "application/octet-stream"
    let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    let createdDate = (attributes?[.creationDate] as? Date)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970

    var payload: [String: Any] = [
      "uri": url.absoluteString,
      "fileName": url.lastPathComponent,
      "name": url.lastPathComponent,
      "mimeType": mimeType,
      "type": classify(mimeType: mimeType),
      "dateTaken": createdDate * 1000,
      "originalUri": url.absoluteString
    ]

    if let size = attributes?[.size] as? NSNumber {
      payload["size"] = size
    }

    return payload
  }

  private func orderedFiles() -> [[String: Any]] {
    lock.lock()
    let files = indexedFiles.keys.sorted().compactMap { indexedFiles[$0] }
    lock.unlock()

    let hasImages = files.contains { ($0["type"] as? String) == "image" }
    let hasVideos = files.contains { ($0["type"] as? String) == "video" }
    guard hasImages && hasVideos else {
      return files
    }

    let images = files.filter { ($0["type"] as? String) == "image" }
    guard let first = images.first?["dateTaken"] as? Double,
          let last = images.last?["dateTaken"] as? Double else {
      return files
    }

    let ascending = first < last
    return files.sorted {
      let left = $0["dateTaken"] as? Double ?? 0
      let right = $1["dateTaken"] as? Double ?? 0
      return ascending ? left < right : left > right
    }
  }

  private func orderedText() -> [String] {
    lock.lock()
    let text = indexedText.keys.sorted().compactMap { indexedText[$0] }
    lock.unlock()
    return text
  }

  private func store(file: [String: Any], index: Int) {
    lock.lock()
    indexedFiles[index] = file
    lock.unlock()
  }

  private func store(text: String, index: Int) {
    lock.lock()
    indexedText[index] = text
    lock.unlock()
  }

  private func sharedContainerDirectory() -> URL {
    if !appGroupIdentifier.isEmpty,
       let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
      let directory = container.appendingPathComponent(sharedDirectoryName, isDirectory: true)
      try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      return directory
    }

    return FileManager.default.temporaryDirectory
  }

  private func classify(mimeType: String) -> String {
    if mimeType.hasPrefix("public.image") || mimeType.hasPrefix("image/") {
      return "image"
    }
    if mimeType.hasPrefix("public.movie") || mimeType.hasPrefix("video/") {
      return "video"
    }
    if mimeType.hasPrefix("public.text") || mimeType.hasPrefix("text/") {
      return "text"
    }
    return "document"
  }
}

private extension String {
  var firstWebURL: String? {
    range(of: #"https?://\S+"#, options: .regularExpression).map { String(self[$0]) }
  }
}
