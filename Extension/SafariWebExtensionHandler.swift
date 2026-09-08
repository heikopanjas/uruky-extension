import SafariServices
import os.log

/// Principal class for the Safari web extension appex.
///
/// This extension does all of its work in JavaScript (declarativeNetRequest
/// rules and a webNavigation fallback), so there is no native logic to run.
/// The class still has to exist and be named in Info.plist under
/// `NSExtensionPrincipalClass`, otherwise Safari will not load the extension.
///
/// If you later add native messaging — say, to read a Startpage `prfe` token
/// out of the container app's shared container — this is where the message
/// handling goes.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private static let log = Logger(
        subsystem: "com.panjas.StartpageForSafari.Extension",
        category: "messaging"
    )

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message = request?.userInfo?[SFExtensionMessageKey]

        Self.log.debug("Received message from web extension: \(String(describing: message), privacy: .public)")

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["status": "ok"]]
        context.completeRequest(returningItems: [response])
    }
}
