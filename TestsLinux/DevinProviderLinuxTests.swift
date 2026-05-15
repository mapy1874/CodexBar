import Foundation
import Testing
@testable import CodexBarCore

struct DevinProviderLinuxTests {
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
        #expect(cycles[1].end == "2026-02-05T08:00:00Z")
    }

    @Test
    func `parses empty billing cycles`() throws {
        let json = "[]"
        let cycles = try DevinUsageFetcher._parseCyclesForTesting(Data(json.utf8))
        #expect(cycles.isEmpty)
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
        #expect(metrics.prs_merged == 25)
    }

    // MARK: - Snapshot Conversion

    @Test
    func `snapshot converts to usage snapshot`() {
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
        #expect(usage.secondary?.resetDescription?.contains("150 sessions") == true)
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
        #expect(usage.primary?.resetDescription == "50.0 ACUs used")
        #expect(usage.secondary == nil)
    }

    // MARK: - Settings Reader

    @Test
    func `settings reader resolves DEVIN_API_KEY`() {
        let env = ["DEVIN_API_KEY": "apk_user_test123"]
        #expect(DevinSettingsReader.apiKey(environment: env) == "apk_user_test123")
    }

    @Test
    func `settings reader resolves DEVIN_TOKEN`() {
        let env = ["DEVIN_TOKEN": "apk_user_fallback"]
        #expect(DevinSettingsReader.apiKey(environment: env) == "apk_user_fallback")
    }

    @Test
    func `settings reader prefers DEVIN_API_KEY over DEVIN_TOKEN`() {
        let env = ["DEVIN_API_KEY": "primary", "DEVIN_TOKEN": "fallback"]
        #expect(DevinSettingsReader.apiKey(environment: env) == "primary")
    }

    @Test
    func `settings reader returns nil for empty env`() {
        #expect(DevinSettingsReader.apiKey(environment: [:]) == nil)
    }

    @Test
    func `settings reader strips quotes`() {
        let env = ["DEVIN_API_KEY": "\"quoted_key\""]
        #expect(DevinSettingsReader.apiKey(environment: env) == "quoted_key")
    }

    // MARK: - Token Resolver

    @Test
    func `token resolver resolves Devin token`() {
        let env = ["DEVIN_API_KEY": "apk_user_resolver_test"]
        #expect(ProviderTokenResolver.devinToken(environment: env) == "apk_user_resolver_test")
    }

    @Test
    func `token resolver returns nil without Devin env`() {
        #expect(ProviderTokenResolver.devinToken(environment: [:]) == nil)
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
}
