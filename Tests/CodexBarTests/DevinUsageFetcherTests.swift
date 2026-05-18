import Foundation
import Testing
@testable import CodexBarCore

struct DevinUsageFetcherTests {
    // MARK: - Billing Cycles Parsing

    @Test
    func `parses billing cycles`() throws {
        let json = """
        [
          {"start": "2025-12-05T08:00:00Z", "end": "2026-01-05T08:00:00Z"},
          {"start": "2026-01-05T08:00:00Z", "end": "2026-02-05T08:00:00Z"}
        ]
        """
        let cycles = try DevinUsageFetcher._parseCyclesForTesting(Data(json.utf8))
        #expect(cycles.count == 2)
        #expect(cycles[0].start == "2025-12-05T08:00:00Z")
        #expect(cycles[0].end == "2026-01-05T08:00:00Z")
        #expect(cycles[1].start == "2026-01-05T08:00:00Z")
        #expect(cycles[1].end == "2026-02-05T08:00:00Z")
    }

    @Test
    func `parses empty billing cycles`() throws {
        let json = "[]"
        let cycles = try DevinUsageFetcher._parseCyclesForTesting(Data(json.utf8))
        #expect(cycles.isEmpty)
    }

    @Test
    func `invalid cycles JSON throws`() {
        let json = """
        {"not": "an array"}
        """
        #expect(throws: (any Error).self) {
            _ = try DevinUsageFetcher._parseCyclesForTesting(Data(json.utf8))
        }
    }

    // MARK: - Consumption Parsing

    @Test
    func `parses consumption response`() throws {
        let json = """
        {
          "total_acus": 142.5,
          "consumption_by_date": {
            "2026-01-06": 10.5,
            "2026-01-07": 20.0
          },
          "consumption_by_org_id": {
            "org_abc": 100.0,
            "org_def": 42.5
          }
        }
        """
        let consumption = try DevinUsageFetcher._parseConsumptionForTesting(Data(json.utf8))
        #expect(consumption.total_acus == 142.5)
        #expect(consumption.consumption_by_date?.count == 2)
        #expect(consumption.consumption_by_date?["2026-01-06"] == 10.5)
        #expect(consumption.consumption_by_org_id?["org_abc"] == 100.0)
    }

    @Test
    func `parses consumption with zero ACUs`() throws {
        let json = """
        {
          "total_acus": 0,
          "consumption_by_date": {},
          "consumption_by_org_id": {}
        }
        """
        let consumption = try DevinUsageFetcher._parseConsumptionForTesting(Data(json.utf8))
        #expect(consumption.total_acus == 0)
    }

    @Test
    func `parses consumption without optional fields`() throws {
        let json = """
        {
          "total_acus": 50.0
        }
        """
        let consumption = try DevinUsageFetcher._parseConsumptionForTesting(Data(json.utf8))
        #expect(consumption.total_acus == 50.0)
        #expect(consumption.consumption_by_date == nil)
        #expect(consumption.consumption_by_org_id == nil)
    }

    // MARK: - Usage Metrics Parsing

    @Test
    func `parses usage metrics`() throws {
        let json = """
        {
          "sessions_count": 150,
          "searches_count": 42,
          "prs_opened": 30,
          "prs_closed": 5,
          "prs_merged": 25
        }
        """
        let metrics = try DevinUsageFetcher._parseMetricsForTesting(Data(json.utf8))
        #expect(metrics.sessions_count == 150)
        #expect(metrics.searches_count == 42)
        #expect(metrics.prs_opened == 30)
        #expect(metrics.prs_closed == 5)
        #expect(metrics.prs_merged == 25)
    }

    @Test
    func `parses usage metrics with zero values`() throws {
        let json = """
        {
          "sessions_count": 0,
          "searches_count": 0,
          "prs_opened": 0,
          "prs_closed": 0,
          "prs_merged": 0
        }
        """
        let metrics = try DevinUsageFetcher._parseMetricsForTesting(Data(json.utf8))
        #expect(metrics.sessions_count == 0)
        #expect(metrics.prs_merged == 0)
    }

    @Test
    func `invalid metrics JSON throws`() {
        let json = """
        {"sessions_count": "not a number"}
        """
        #expect(throws: (any Error).self) {
            _ = try DevinUsageFetcher._parseMetricsForTesting(Data(json.utf8))
        }
    }

    // MARK: - Snapshot Conversion

    @Test
    func `snapshot converts to usage snapshot with sessions`() {
        let snapshot = DevinUsageSnapshot(
            totalACUs: 142.5,
            cycleStart: Date(timeIntervalSince1970: 1_735_689_600),
            cycleEnd: Date(timeIntervalSince1970: 1_738_368_000),
            sessionsCount: 150,
            prsOpened: 30,
            prsMerged: 25,
            updatedAt: Date())
        let usage = snapshot.toUsageSnapshot()
        #expect(usage.primary != nil)
        #expect(usage.primary?.resetDescription == "142.5 ACUs used")
        #expect(usage.primary?.resetsAt != nil)
        #expect(usage.secondary != nil)
        #expect(usage.secondary?.resetDescription?.contains("150 sessions") == true)
        #expect(usage.secondary?.resetDescription?.contains("25 PRs merged") == true)
        #expect(usage.identity?.providerID == .devin)
    }

    @Test
    func `snapshot converts without optional metrics`() {
        let snapshot = DevinUsageSnapshot(
            totalACUs: 50.0,
            cycleStart: nil,
            cycleEnd: nil,
            sessionsCount: nil,
            prsOpened: nil,
            prsMerged: nil,
            updatedAt: Date())
        let usage = snapshot.toUsageSnapshot()
        #expect(usage.primary != nil)
        #expect(usage.primary?.resetDescription == "50.0 ACUs used")
        #expect(usage.primary?.resetsAt == nil)
        #expect(usage.secondary == nil)
    }

    @Test
    func `snapshot with sessions but no PRs omits PR text`() {
        let snapshot = DevinUsageSnapshot(
            totalACUs: 10.0,
            cycleStart: nil,
            cycleEnd: nil,
            sessionsCount: 5,
            prsOpened: 0,
            prsMerged: 0,
            updatedAt: Date())
        let usage = snapshot.toUsageSnapshot()
        #expect(usage.secondary != nil)
        #expect(usage.secondary?.resetDescription == "5 sessions")
    }

    // MARK: - Settings Reader

    @Test
    func `settings reader resolves DEVIN_API_KEY`() {
        let env = ["DEVIN_API_KEY": "apk_user_test123"]
        let token = DevinSettingsReader.apiKey(environment: env)
        #expect(token == "apk_user_test123")
    }

    @Test
    func `settings reader resolves DEVIN_TOKEN`() {
        let env = ["DEVIN_TOKEN": "apk_user_fallback"]
        let token = DevinSettingsReader.apiKey(environment: env)
        #expect(token == "apk_user_fallback")
    }

    @Test
    func `settings reader prefers DEVIN_API_KEY over DEVIN_TOKEN`() {
        let env = [
            "DEVIN_API_KEY": "primary",
            "DEVIN_TOKEN": "fallback",
        ]
        let token = DevinSettingsReader.apiKey(environment: env)
        #expect(token == "primary")
    }

    @Test
    func `settings reader returns nil for empty environment`() {
        let env: [String: String] = [:]
        let token = DevinSettingsReader.apiKey(environment: env)
        #expect(token == nil)
    }

    @Test
    func `settings reader strips quotes`() {
        let env = ["DEVIN_API_KEY": "\"quoted_key\""]
        let token = DevinSettingsReader.apiKey(environment: env)
        #expect(token == "quoted_key")
    }

    @Test
    func `settings reader ignores whitespace-only values`() {
        let env = ["DEVIN_API_KEY": "   "]
        let token = DevinSettingsReader.apiKey(environment: env)
        #expect(token == nil)
    }

    // MARK: - Token Resolver

    @Test
    func `token resolver resolves Devin token`() {
        let env = ["DEVIN_API_KEY": "apk_user_resolver_test"]
        let token = ProviderTokenResolver.devinToken(environment: env)
        #expect(token == "apk_user_resolver_test")
    }

    @Test
    func `token resolver returns nil without Devin env`() {
        let env: [String: String] = [:]
        let token = ProviderTokenResolver.devinToken(environment: env)
        #expect(token == nil)
    }

    @Test
    func `token account catalog supports Devin API keys`() {
        let support = TokenAccountSupportCatalog.support(for: .devin)
        #expect(support?.title == "API keys")
        #expect(support?.requiresManualCookieSource == false)
        #expect(support?.cookieName == nil)

        if case let .environment(key) = support?.injection {
            #expect(key == DevinSettingsReader.apiKeyEnvironmentKey)
        } else {
            Issue.record("Expected Devin token accounts to inject an environment variable")
        }

        let override = TokenAccountSupportCatalog.envOverride(for: .devin, token: "cog_test")
        #expect(override?[DevinSettingsReader.apiKeyEnvironmentKey] == "cog_test")
    }

    // MARK: - Provider Descriptor

    @Test
    func `descriptor is registered`() {
        let descriptor = ProviderDescriptorRegistry.descriptor(for: .devin)
        #expect(descriptor.id == .devin)
        #expect(descriptor.metadata.displayName == "Devin")
        #expect(descriptor.metadata.cliName == "devin")
        #expect(descriptor.branding.iconStyle == .devin)
    }

    @Test
    func `descriptor source modes include api`() {
        let descriptor = ProviderDescriptorRegistry.descriptor(for: .devin)
        #expect(descriptor.fetchPlan.sourceModes.contains(.api))
    }
}
