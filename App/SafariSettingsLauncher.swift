#if os(macOS)
import SafariServices

/// Opens Safari's extension settings pane directly at our extension.
///
/// There is no iOS equivalent — on iOS the user has to walk through
/// Settings.app manually, which is what `SetupInstructions` describes.
enum SafariSettingsLauncher {
    /// Must match `PRODUCT_BUNDLE_IDENTIFIER` of the Extension target.
    static let extensionBundleIdentifier = "com.panjas.StartpageForSafari.Extension"

    static func open() {
        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: extensionBundleIdentifier
        ) { error in
            if let error {
                assertionFailure("Could not open Safari settings: \(error)")
            }
        }
    }
}
#endif
