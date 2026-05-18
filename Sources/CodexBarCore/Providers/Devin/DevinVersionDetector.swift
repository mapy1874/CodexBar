import Foundation

public enum DevinVersionDetector {
    public static func detectVersion() -> String? {
        guard let path = TTYCommandRunner.which("devin") else { return nil }
        let candidates = [
            ["--version"],
            ["-v"],
        ]
        for args in candidates {
            if let version = ProviderVersionDetector.run(path: path, args: args) {
                return version
            }
        }
        return nil
    }
}
