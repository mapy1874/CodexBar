import AppKit
import CodexBarCore

enum ProviderBrandIcon {
    private static let size = NSSize(width: 16, height: 16)

    /// Lazy-loaded resource bundle for provider icons.
    private static let resourceBundle = providerIconResourceBundle()

    static func image(for provider: UsageProvider) -> NSImage? {
        let baseName = ProviderDescriptorRegistry.descriptor(for: provider).branding.iconResourceName
        guard let url = self.resourceBundle.url(forResource: baseName, withExtension: "svg"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        image.size = self.size
        image.isTemplate = true
        return image
    }
}

func providerIconResourceBundle(
    mainBundle: Bundle = .main,
    bundleName: String = "CodexBar_CodexBar") -> Bundle
{
    guard mainBundle.bundleURL.pathExtension == "app" else {
        return Bundle.module
    }

    if let bundleURL = mainBundle.url(forResource: bundleName, withExtension: "bundle"),
       let bundle = Bundle(url: bundleURL)
    {
        return bundle
    }

    if let resourceURL = mainBundle.resourceURL?.absoluteURL,
       let bundle = Bundle(url: resourceURL.appendingPathComponent("\(bundleName).bundle"))
    {
        return bundle
    }

    return mainBundle
}
