import Foundation
import Testing
@testable import CodexBarCore

struct DevinProviderLinuxTests {
    // MARK: - v2 Billing Cycles Parsing

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
    func `parses single billing cycle`() throws {
        let json = """
        [
          {"start": "2026-05-01T08:00:00Z", "end": "2026-06-01T08:00:00Z"}
        ]
        """
        let cycles = try DevinUsageFetcher._parseCyclesForTesting(Data(json.utf8))
        #expect(cycles.count == 1)
        #expect(cycles[0].start == "2026-05-01T08:00:00Z")
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

    @Test
    func `malformed cycles JSON throws`() {
        let json = "not json at all"
        #expect(throws: (any Error).self) {
            _ = try DevinUsageFetcher._parseCyclesForTesting(Data(json.utf8))
        }
    }

    // MARK: - v2 Consumption Parsing

    @Test
    func `parses consumption response with all fields`() throws {
        let json = """
        {
          "total_acus": 142.5,
          "consumption_by_date": {
            "2026-01-06": 10.5,
            "2026-01-07": 20.0,
            "2026-01-08": 112.0
          },
          "consumption_by_org_id": {
            "org_abc": 100.0,
            "org_def": 42.5
          }
        }
        """
        let consumption = try DevinUsageFetcher._parseConsumptionForTesting(Data(json.utf8))
        #expect(consumption.total_acus == 142.5)
        #expect(consumption.consumption_by_date?.count == 3)
        #expect(consumption.consumption_by_date?["2026-01-06"] == 10.5)
        #expect(consumption.consumption_by_date?["2026-01-07"] == 20.0)
        #expect(consumption.consumption_by_date?["2026-01-08"] == 112.0)
        #expect(consumption.consumption_by_org_id?.count == 2)
        #expect(consumption.consumption_by_org_id?["org_abc"] == 100.0)
        #expect(consumption.consumption_by_org_id?["org_def"] == 42.5)
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
        #expect(consumption.consumption_by_date?.isEmpty == true)
        #expect(consumption.consumption_by_org_id?.isEmpty == true)
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

    @Test
    func `parses consumption with fractional ACUs`() throws {
        let json = """
        {
          "total_acus": 0.001
        }
        """
        let consumption = try DevinUsageFetcher._parseConsumptionForTesting(Data(json.utf8))
        #expect(consumption.total_acus == 0.001)
    }

    @Test
    func `parses consumption with large ACU values`() throws {
        let json = """
        {
          "total_acus": 99999.99
        }
        """
        let consumption = try DevinUsageFetcher._parseConsumptionForTesting(Data(json.utf8))
        #expect(consumption.total_acus == 99999.99)
    }

    @Test
    func `invalid consumption JSON throws`() {
        let json = "[1, 2, 3]"
        #expect(throws: (any Error).self) {
            _ = try DevinUsageFetcher._parseConsumptionForTesting(Data(json.utf8))
        }
    }

    // MARK: - v2 Usage Metrics Parsing

    @Test
    func `parses usage metrics with all fields`() throws {
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
        #expect(metrics.searches_count == 0)
        #expect(metrics.prs_opened == 0)
        #expect(metrics.prs_closed == 0)
        #expect(metrics.prs_merged == 0)
    }

    @Test
    func `parses usage metrics with large values`() throws {
        let json = """
        {
          "sessions_count": 10000,
          "searches_count": 50000,
          "prs_opened": 1500,
          "prs_closed": 200,
          "prs_merged": 1300
        }
        """
        let metrics = try DevinUsageFetcher._parseMetricsForTesting(Data(json.utf8))
        #expect(metrics.sessions_count == 10000)
        #expect(metrics.prs_merged == 1300)
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

    @Test
    func `missing required metrics field throws`() {
        let json = """
        {
          "sessions_count": 10,
          "searches_count": 5
        }
        """
        #expect(throws: (any Error).self) {
            _ = try DevinUsageFetcher._parseMetricsForTesting(Data(json.utf8))
        }
    }

    // MARK: - Snapshot Conversion (full fields)

    @Test
    func `snapshot converts to usage snapshot with all fields`() throws {
        let cycleEnd = Date(timeIntervalSince1970: 1_738_368_000)
        let snapshot = DevinUsageSnapshot(
            totalACUs: 142.5,
            cycleStart: Date(timeIntervalSince1970: 1_735_689_600),
            cycleEnd: cycleEnd,
            sessionsCount: 150,
            prsOpened: 30,
            prsMerged: 25,
            updatedAt: Date())
        let usage = snapshot.toUsageSnapshot()

        let primary = try #require(usage.primary)
        #expect(primary.resetDescription == "142.5 ACUs used")
        #expect(primary.resetsAt == cycleEnd)
        #expect(primary.usedPercent == 0)
        #expect(primary.windowMinutes == nil)

        let secondary = try #require(usage.secondary)
        #expect(secondary.resetDescription?.contains("150 sessions") == true)
        #expect(secondary.resetDescription?.contains("25 PRs merged") == true)
        #expect(secondary.resetsAt == nil)
        #expect(secondary.usedPercent == 0)

        let identity = try #require(usage.identity)
        #expect(identity.providerID == .devin)
        #expect(identity.accountEmail == nil)
        #expect(identity.accountOrganization == nil)
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
        #expect(usage.primary?.resetsAt == nil)
        #expect(usage.secondary == nil)
        #expect(usage.tertiary == nil)
    }

    @Test
    func `snapshot with sessions but zero PRs omits PR text`() throws {
        let snapshot = DevinUsageSnapshot(
            totalACUs: 10.0,
            cycleStart: nil,
            cycleEnd: nil,
            sessionsCount: 5,
            prsOpened: 0,
            prsMerged: 0,
            updatedAt: Date())
        let usage = snapshot.toUsageSnapshot()
        let secondary = try #require(usage.secondary)
        #expect(secondary.resetDescription == "5 sessions")
        #expect(secondary.resetDescription?.contains("PRs") == false)
    }

    @Test
    func `snapshot with sessions and no PRs merged omits PR text`() throws {
        let snapshot = DevinUsageSnapshot(
            totalACUs: 10.0,
            cycleStart: nil,
            cycleEnd: nil,
            sessionsCount: 5,
            prsOpened: 3,
            prsMerged: nil,
            updatedAt: Date())
        let usage = snapshot.toUsageSnapshot()
        let secondary = try #require(usage.secondary)
        #expect(secondary.resetDescription == "5 sessions")
    }

    @Test
    func `snapshot with zero ACUs formats correctly`() {
        let snapshot = DevinUsageSnapshot(
            totalACUs: 0.0,
            cycleStart: nil,
            cycleEnd: nil,
            sessionsCount: 0,
            prsOpened: 0,
            prsMerged: 0,
            updatedAt: Date())
        let usage = snapshot.toUsageSnapshot()
        #expect(usage.primary?.resetDescription == "0.0 ACUs used")
    }

    @Test
    func `snapshot with fractional ACUs formats one decimal`() {
        let snapshot = DevinUsageSnapshot(
            totalACUs: 3.14159,
            cycleStart: nil,
            cycleEnd: nil,
            sessionsCount: nil,
            prsOpened: nil,
            prsMerged: nil,
            updatedAt: Date())
        let usage = snapshot.toUsageSnapshot()
        #expect(usage.primary?.resetDescription == "3.1 ACUs used")
    }

    @Test
    func `snapshot with large ACU value formats correctly`() {
        let snapshot = DevinUsageSnapshot(
            totalACUs: 12345.6789,
            cycleStart: nil,
            cycleEnd: nil,
            sessionsCount: nil,
            prsOpened: nil,
            prsMerged: nil,
            updatedAt: Date())
        let usage = snapshot.toUsageSnapshot()
        #expect(usage.primary?.resetDescription == "12345.7 ACUs used")
    }

    @Test
    func `snapshot with single session and single PR merged`() throws {
        let snapshot = DevinUsageSnapshot(
            totalACUs: 1.0,
            cycleStart: nil,
            cycleEnd: nil,
            sessionsCount: 1,
            prsOpened: 1,
            prsMerged: 1,
            updatedAt: Date())
        let usage = snapshot.toUsageSnapshot()
        let secondary = try #require(usage.secondary)
        #expect(secondary.resetDescription == "1 sessions, 1 PRs merged")
    }

    @Test
    func `snapshot preserves updatedAt timestamp`() {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = DevinUsageSnapshot(
            totalACUs: 0.0,
            cycleStart: nil,
            cycleEnd: nil,
            sessionsCount: nil,
            prsOpened: nil,
            prsMerged: nil,
            updatedAt: fixedDate)
        let usage = snapshot.toUsageSnapshot()
        #expect(usage.updatedAt == fixedDate)
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
    func `settings reader strips double quotes`() {
        let env = ["DEVIN_API_KEY": "\"quoted_key\""]
        #expect(DevinSettingsReader.apiKey(environment: env) == "quoted_key")
    }

    @Test
    func `settings reader strips single quotes`() {
        let env = ["DEVIN_API_KEY": "'single_quoted'"]
        #expect(DevinSettingsReader.apiKey(environment: env) == "single_quoted")
    }

    @Test
    func `settings reader ignores whitespace-only values`() {
        let env = ["DEVIN_API_KEY": "   "]
        #expect(DevinSettingsReader.apiKey(environment: env) == nil)
    }

    @Test
    func `settings reader trims leading and trailing whitespace`() {
        let env = ["DEVIN_API_KEY": "  apk_user_spaced  "]
        #expect(DevinSettingsReader.apiKey(environment: env) == "apk_user_spaced")
    }

    @Test
    func `settings reader ignores empty string value`() {
        let env = ["DEVIN_API_KEY": ""]
        #expect(DevinSettingsReader.apiKey(environment: env) == nil)
    }

    @Test
    func `settings reader falls through empty first key to second`() {
        let env = ["DEVIN_API_KEY": "", "DEVIN_TOKEN": "cog_fallback"]
        #expect(DevinSettingsReader.apiKey(environment: env) == "cog_fallback")
    }

    @Test
    func `settings reader resolves cog service user key`() {
        let env = ["DEVIN_API_KEY": "cog_abcdef123456"]
        #expect(DevinSettingsReader.apiKey(environment: env) == "cog_abcdef123456")
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

    @Test
    func `token resolver resolves cog key`() {
        let env = ["DEVIN_API_KEY": "cog_resolver_cog_test"]
        #expect(ProviderTokenResolver.devinToken(environment: env) == "cog_resolver_cog_test")
    }

    @Test
    func `token resolution returns resolution struct`() {
        let env = ["DEVIN_API_KEY": "apk_user_resolution"]
        let resolution = ProviderTokenResolver.devinResolution(environment: env)
        #expect(resolution != nil)
        #expect(resolution?.token == "apk_user_resolution")
    }

    @Test
    func `token resolution returns nil for empty env`() {
        let resolution = ProviderTokenResolver.devinResolution(environment: [:])
        #expect(resolution == nil)
    }

    // MARK: - v3 Self Parsing

    @Test
    func `parses v3 self response with org_id`() throws {
        let json = """
        {
          "principal_type": "service_user",
          "service_user_id": "service-user-abc123",
          "service_user_name": "Test Bot",
          "org_id": "org_XYZ"
        }
        """
        let selfInfo = try DevinUsageFetcher._parseSelfForTesting(Data(json.utf8))
        #expect(selfInfo.principal_type == "service_user")
        #expect(selfInfo.service_user_id == "service-user-abc123")
        #expect(selfInfo.org_id == "org_XYZ")
        #expect(selfInfo.service_user_name == "Test Bot")
    }

    @Test
    func `parses v3 self response without org_id`() throws {
        let json = """
        {
          "principal_type": "service_user",
          "service_user_id": "service-user-abc123",
          "service_user_name": "Enterprise Bot",
          "org_id": null
        }
        """
        let selfInfo = try DevinUsageFetcher._parseSelfForTesting(Data(json.utf8))
        #expect(selfInfo.org_id == nil)
        #expect(selfInfo.principal_type == "service_user")
    }

    @Test
    func `parses v3 self response with null optional fields`() throws {
        let json = """
        {
          "principal_type": "service_user",
          "service_user_id": null,
          "service_user_name": null,
          "org_id": null
        }
        """
        let selfInfo = try DevinUsageFetcher._parseSelfForTesting(Data(json.utf8))
        #expect(selfInfo.service_user_id == nil)
        #expect(selfInfo.service_user_name == nil)
        #expect(selfInfo.org_id == nil)
    }

    @Test
    func `invalid v3 self JSON throws`() {
        let json = "[]"
        #expect(throws: (any Error).self) {
            _ = try DevinUsageFetcher._parseSelfForTesting(Data(json.utf8))
        }
    }

    // MARK: - v3 Sessions Parsing

    @Test
    func `parses v3 sessions response with multiple items`() throws {
        let json = """
        {
          "items": [
            {
              "session_id": "abc123",
              "status": "finished",
              "acus_consumed": 5.5,
              "pull_requests": [
                {"pr_url": "https://github.com/org/repo/pull/1", "pr_state": "merged"},
                {"pr_url": "https://github.com/org/repo/pull/2", "pr_state": "open"}
              ],
              "org_id": "org_XYZ"
            },
            {
              "session_id": "def456",
              "status": "running",
              "acus_consumed": 2.0,
              "pull_requests": [],
              "org_id": "org_XYZ"
            }
          ],
          "total": 10,
          "has_next_page": true,
          "end_cursor": "cursor123"
        }
        """
        let response = try DevinUsageFetcher._parseSessionsForTesting(Data(json.utf8))
        #expect(response.items.count == 2)
        #expect(response.total == 10)
        #expect(response.has_next_page == true)
        #expect(response.end_cursor == "cursor123")

        #expect(response.items[0].session_id == "abc123")
        #expect(response.items[0].status == "finished")
        #expect(response.items[0].acus_consumed == 5.5)
        #expect(response.items[0].pull_requests?.count == 2)
        #expect(response.items[0].pull_requests?[0].pr_state == "merged")
        #expect(response.items[0].pull_requests?[1].pr_state == "open")

        #expect(response.items[1].session_id == "def456")
        #expect(response.items[1].status == "running")
        #expect(response.items[1].acus_consumed == 2.0)
        #expect(response.items[1].pull_requests?.isEmpty == true)
    }

    @Test
    func `parses v3 sessions with empty items`() throws {
        let json = """
        {
          "items": [],
          "total": 0,
          "has_next_page": false,
          "end_cursor": null
        }
        """
        let response = try DevinUsageFetcher._parseSessionsForTesting(Data(json.utf8))
        #expect(response.items.isEmpty)
        #expect(response.total == 0)
        #expect(response.has_next_page == false)
        #expect(response.end_cursor == nil)
    }

    @Test
    func `parses v3 sessions without pull_requests field`() throws {
        let json = """
        {
          "items": [
            {
              "session_id": "no-prs",
              "status": "suspended",
              "acus_consumed": 0.0,
              "pull_requests": null,
              "org_id": "org_XYZ"
            }
          ],
          "total": 1,
          "has_next_page": false,
          "end_cursor": null
        }
        """
        let response = try DevinUsageFetcher._parseSessionsForTesting(Data(json.utf8))
        #expect(response.items.count == 1)
        #expect(response.items[0].pull_requests == nil)
        #expect(response.items[0].acus_consumed == 0.0)
    }

    @Test
    func `parses v3 session with various PR states`() throws {
        let json = """
        {
          "items": [
            {
              "session_id": "pr-states",
              "status": "finished",
              "acus_consumed": 3.0,
              "pull_requests": [
                {"pr_url": "https://github.com/a/b/pull/1", "pr_state": "merged"},
                {"pr_url": "https://github.com/a/b/pull/2", "pr_state": "open"},
                {"pr_url": "https://github.com/a/b/pull/3", "pr_state": "closed"},
                {"pr_url": "https://github.com/a/b/pull/4", "pr_state": null}
              ],
              "org_id": "org_XYZ"
            }
          ],
          "total": 1,
          "has_next_page": false,
          "end_cursor": null
        }
        """
        let response = try DevinUsageFetcher._parseSessionsForTesting(Data(json.utf8))
        let prs = response.items[0].pull_requests!
        #expect(prs.count == 4)
        #expect(prs[0].pr_state == "merged")
        #expect(prs[1].pr_state == "open")
        #expect(prs[2].pr_state == "closed")
        #expect(prs[3].pr_state == nil)
    }

    @Test
    func `invalid v3 sessions JSON throws`() {
        let json = "{}"
        #expect(throws: (any Error).self) {
            _ = try DevinUsageFetcher._parseSessionsForTesting(Data(json.utf8))
        }
    }

    // MARK: - v3 Aggregation Logic

    @Test
    func `v3 session aggregation computes total ACUs`() {
        let sessions: [DevinV3Session] = [
            DevinV3Session(session_id: "a", status: "finished", acus_consumed: 5.5,
                           pull_requests: nil, org_id: "org"),
            DevinV3Session(session_id: "b", status: "finished", acus_consumed: 3.0,
                           pull_requests: nil, org_id: "org"),
            DevinV3Session(session_id: "c", status: "running", acus_consumed: 1.5,
                           pull_requests: nil, org_id: "org"),
        ]
        let totalACUs = sessions.reduce(0.0) { $0 + $1.acus_consumed }
        #expect(totalACUs == 10.0)
    }

    @Test
    func `v3 session aggregation counts merged PRs`() {
        let sessions: [DevinV3Session] = [
            DevinV3Session(session_id: "a", status: "finished", acus_consumed: 1.0,
                           pull_requests: [
                               DevinV3PullRequest(pr_url: "url1", pr_state: "merged"),
                               DevinV3PullRequest(pr_url: "url2", pr_state: "open"),
                           ], org_id: "org"),
            DevinV3Session(session_id: "b", status: "finished", acus_consumed: 2.0,
                           pull_requests: [
                               DevinV3PullRequest(pr_url: "url3", pr_state: "merged"),
                               DevinV3PullRequest(pr_url: "url4", pr_state: "closed"),
                               DevinV3PullRequest(pr_url: "url5", pr_state: "merged"),
                           ], org_id: "org"),
            DevinV3Session(session_id: "c", status: "running", acus_consumed: 0.0,
                           pull_requests: nil, org_id: "org"),
        ]
        let allPRs = sessions.flatMap { $0.pull_requests ?? [] }
        let mergedCount = allPRs.filter { $0.pr_state == "merged" }.count
        #expect(allPRs.count == 5)
        #expect(mergedCount == 3)
    }

    @Test
    func `v3 session aggregation with no sessions`() {
        let sessions: [DevinV3Session] = []
        let totalACUs = sessions.reduce(0.0) { $0 + $1.acus_consumed }
        let allPRs = sessions.flatMap { $0.pull_requests ?? [] }
        #expect(totalACUs == 0.0)
        #expect(allPRs.isEmpty)
    }

    @Test
    func `v3 session aggregation with zero-ACU sessions`() {
        let sessions: [DevinV3Session] = [
            DevinV3Session(session_id: "a", status: "suspended", acus_consumed: 0.0,
                           pull_requests: [], org_id: "org"),
            DevinV3Session(session_id: "b", status: "suspended", acus_consumed: 0.0,
                           pull_requests: nil, org_id: "org"),
        ]
        let totalACUs = sessions.reduce(0.0) { $0 + $1.acus_consumed }
        #expect(totalACUs == 0.0)
        #expect(sessions.count == 2)
    }

    // MARK: - Error Messages

    @Test
    func `error missingCredentials has descriptive message`() {
        let error = DevinUsageError.missingCredentials
        #expect(error.errorDescription?.contains("DEVIN_API_KEY") == true)
        #expect(error.errorDescription?.contains("DEVIN_TOKEN") == true)
    }

    @Test
    func `error networkError includes message`() {
        let error = DevinUsageError.networkError("Connection refused")
        #expect(error.errorDescription?.contains("Connection refused") == true)
    }

    @Test
    func `error apiError includes code and body`() {
        let error = DevinUsageError.apiError(403, "Unauthorized")
        #expect(error.errorDescription?.contains("403") == true)
        #expect(error.errorDescription?.contains("Unauthorized") == true)
    }

    @Test
    func `error parseFailed includes detail`() {
        let error = DevinUsageError.parseFailed("cycles: missing key")
        #expect(error.errorDescription?.contains("cycles: missing key") == true)
    }

    @Test
    func `error noBillingCycle has descriptive message`() {
        let error = DevinUsageError.noBillingCycle
        #expect(error.errorDescription?.contains("billing cycle") == true)
    }

    // MARK: - API Key Format Detection

    @Test
    func `cog prefix routes to v3`() {
        #expect("cog_abcdef".hasPrefix("cog_") == true)
    }

    @Test
    func `apk_user prefix does not route to v3`() {
        #expect("apk_user_abcdef".hasPrefix("cog_") == false)
    }

    @Test
    func `empty key does not route to v3`() {
        #expect("".hasPrefix("cog_") == false)
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

    @Test
    func `descriptor branding has correct color`() {
        let descriptor = ProviderDescriptorRegistry.descriptor(for: .devin)
        let color = descriptor.branding.color
        #expect(abs(color.red - 99.0 / 255.0) < 0.01)
        #expect(abs(color.green - 102.0 / 255.0) < 0.01)
        #expect(abs(color.blue - 241.0 / 255.0) < 0.01)
    }

    @Test
    func `descriptor metadata fields`() {
        let descriptor = ProviderDescriptorRegistry.descriptor(for: .devin)
        #expect(descriptor.metadata.sessionLabel == "ACUs")
        #expect(descriptor.metadata.weeklyLabel == "Sessions")
        #expect(descriptor.metadata.toggleTitle == "Show Devin usage")
        #expect(descriptor.metadata.defaultEnabled == false)
        #expect(descriptor.metadata.isPrimaryProvider == false)
        #expect(descriptor.metadata.dashboardURL == "https://app.devin.ai")
    }

    @Test
    func `descriptor cli config`() {
        let descriptor = ProviderDescriptorRegistry.descriptor(for: .devin)
        #expect(descriptor.cli.name == "devin")
        #expect(descriptor.cli.aliases == ["devin-cli"])
    }
}
