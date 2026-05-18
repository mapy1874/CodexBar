import CodexBarMacroSupport
import Foundation

@ProviderDescriptorRegistration
@ProviderDescriptorDefinition
public enum DevinProviderDescriptor {
    static func makeDescriptor() -> ProviderDescriptor {
        ProviderDescriptor(
            id: .devin,
            metadata: ProviderMetadata(
                id: .devin,
                displayName: "Devin",
                sessionLabel: "ACUs",
                weeklyLabel: "Sessions",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Devin usage",
                cliName: "devin",
                defaultEnabled: false,
                isPrimaryProvider: false,
                usesAccountFallback: false,
                dashboardURL: "https://app.devin.ai",
                statusPageURL: nil,
                statusLinkURL: "https://status.devin.ai"),
            branding: ProviderBranding(
                iconStyle: .devin,
                iconResourceName: "ProviderIcon-devin",
                color: ProviderColor(red: 99 / 255, green: 102 / 255, blue: 241 / 255)),
            tokenCost: ProviderTokenCostConfig(
                supportsTokenCost: false,
                noDataMessage: { "Devin cost summary is not available." }),
            fetchPlan: ProviderFetchPlan(
                sourceModes: [.auto, .api],
                pipeline: ProviderFetchPipeline(resolveStrategies: { _ in [DevinAPIFetchStrategy()] })),
            cli: ProviderCLIConfig(
                name: "devin",
                aliases: ["devin-cli"],
                versionDetector: { _ in DevinVersionDetector.detectVersion() }))
    }
}

struct DevinAPIFetchStrategy: ProviderFetchStrategy {
    let id: String = "devin.api"
    let kind: ProviderFetchKind = .apiToken

    func isAvailable(_ context: ProviderFetchContext) async -> Bool {
        Self.resolveToken(environment: context.env) != nil
    }

    func fetch(_ context: ProviderFetchContext) async throws -> ProviderFetchResult {
        guard let apiKey = Self.resolveToken(environment: context.env) else {
            throw DevinUsageError.missingCredentials
        }
        let usage = try await DevinUsageFetcher.fetchUsage(apiKey: apiKey)
        return self.makeResult(
            usage: usage.toUsageSnapshot(),
            sourceLabel: "api")
    }

    func shouldFallback(on _: Error, context _: ProviderFetchContext) -> Bool {
        false
    }

    private static func resolveToken(environment: [String: String]) -> String? {
        ProviderTokenResolver.devinToken(environment: environment)
    }
}
