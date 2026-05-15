import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - API Response Models

public struct DevinBillingCycle: Codable, Sendable, Equatable {
    public let start: String
    public let end: String
}

public struct DevinConsumptionResponse: Codable, Sendable, Equatable {
    public let total_acus: Double
    public let consumption_by_date: [String: Double]?
    public let consumption_by_org_id: [String: Double]?

    enum CodingKeys: String, CodingKey {
        case total_acus
        case consumption_by_date
        case consumption_by_org_id
    }
}

public struct DevinUsageMetrics: Codable, Sendable, Equatable {
    public let sessions_count: Int
    public let searches_count: Int
    public let prs_opened: Int
    public let prs_closed: Int
    public let prs_merged: Int

    enum CodingKeys: String, CodingKey {
        case sessions_count
        case searches_count
        case prs_opened
        case prs_closed
        case prs_merged
    }
}

// MARK: - Usage Snapshot

public struct DevinUsageSnapshot: Sendable {
    public let totalACUs: Double
    public let cycleStart: Date?
    public let cycleEnd: Date?
    public let sessionsCount: Int?
    public let prsOpened: Int?
    public let prsMerged: Int?
    public let updatedAt: Date

    public init(
        totalACUs: Double,
        cycleStart: Date?,
        cycleEnd: Date?,
        sessionsCount: Int?,
        prsOpened: Int?,
        prsMerged: Int?,
        updatedAt: Date)
    {
        self.totalACUs = totalACUs
        self.cycleStart = cycleStart
        self.cycleEnd = cycleEnd
        self.sessionsCount = sessionsCount
        self.prsOpened = prsOpened
        self.prsMerged = prsMerged
        self.updatedAt = updatedAt
    }

    public func toUsageSnapshot() -> UsageSnapshot {
        let resetDescription = String(format: "%.1f ACUs used", self.totalACUs)

        let primary = RateWindow(
            usedPercent: 0,
            windowMinutes: nil,
            resetsAt: self.cycleEnd,
            resetDescription: resetDescription)

        var secondaryDescription: String?
        if let sessions = self.sessionsCount {
            var parts: [String] = ["\(sessions) sessions"]
            if let prs = self.prsMerged, prs > 0 {
                parts.append("\(prs) PRs merged")
            }
            secondaryDescription = parts.joined(separator: ", ")
        }

        let secondary: RateWindow? = secondaryDescription.map { desc in
            RateWindow(
                usedPercent: 0,
                windowMinutes: nil,
                resetsAt: nil,
                resetDescription: desc)
        }

        let identity = ProviderIdentitySnapshot(
            providerID: .devin,
            accountEmail: nil,
            accountOrganization: nil,
            loginMethod: nil)

        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            updatedAt: self.updatedAt,
            identity: identity)
    }
}

// MARK: - Errors

public enum DevinUsageError: LocalizedError, Sendable {
    case missingCredentials
    case networkError(String)
    case apiError(Int, String)
    case parseFailed(String)
    case noBillingCycle

    public var errorDescription: String? {
        switch self {
        case .missingCredentials:
            "Missing Devin API key. Set DEVIN_API_KEY or DEVIN_TOKEN, or add a token account in Settings → Providers → Devin."
        case let .networkError(message):
            "Devin network error: \(message)"
        case let .apiError(code, message):
            "Devin API error (\(code)): \(message)"
        case let .parseFailed(message):
            "Failed to parse Devin response: \(message)"
        case .noBillingCycle:
            "No billing cycle found for your Devin enterprise."
        }
    }
}

// MARK: - Fetcher

public struct DevinUsageFetcher: Sendable {
    private static let log = CodexBarLog.logger(LogCategories.devinUsage)
    private static let baseURL = "https://api.devin.ai"
    private static let cyclesURL = URL(string: "\(baseURL)/v2/enterprise/consumption/cycles")!
    private static let dailyURL = URL(string: "\(baseURL)/v2/enterprise/consumption/daily")!
    private static let metricsURL = URL(string: "\(baseURL)/v2/enterprise/metrics/usage")!

    public static func fetchUsage(
        apiKey: String,
        timeout: TimeInterval = 15,
        session: URLSession = .shared) async throws -> DevinUsageSnapshot
    {
        let cycles = try await self.fetchCycles(apiKey: apiKey, timeout: timeout, session: session)
        guard let currentCycle = cycles.last else {
            throw DevinUsageError.noBillingCycle
        }

        let cycleStartDate = Self.parseDate(currentCycle.start)
        let cycleEndDate = Self.parseDate(currentCycle.end)

        let consumption = try await self.fetchDailyConsumption(
            apiKey: apiKey,
            startDate: currentCycle.start,
            endDate: currentCycle.end,
            timeout: timeout,
            session: session)

        let metrics: DevinUsageMetrics?
        do {
            metrics = try await self.fetchMetrics(
                apiKey: apiKey,
                startDate: currentCycle.start,
                endDate: currentCycle.end,
                timeout: timeout,
                session: session)
        } catch {
            self.log.info("Metrics fetch failed (non-fatal): \(error.localizedDescription)")
            metrics = nil
        }

        return DevinUsageSnapshot(
            totalACUs: consumption.total_acus,
            cycleStart: cycleStartDate,
            cycleEnd: cycleEndDate,
            sessionsCount: metrics?.sessions_count,
            prsOpened: metrics?.prs_opened,
            prsMerged: metrics?.prs_merged,
            updatedAt: Date())
    }

    // MARK: - API Calls

    static func fetchCycles(
        apiKey: String,
        timeout: TimeInterval = 15,
        session: URLSession = .shared) async throws -> [DevinBillingCycle]
    {
        var request = URLRequest(url: self.cyclesURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout

        let (data, response) = try await self.performRequest(request, session: session)
        try Self.validateResponse(response, data: data)

        do {
            return try JSONDecoder().decode([DevinBillingCycle].self, from: data)
        } catch {
            throw DevinUsageError.parseFailed("cycles: \(error.localizedDescription)")
        }
    }

    static func fetchDailyConsumption(
        apiKey: String,
        startDate: String,
        endDate: String,
        timeout: TimeInterval = 15,
        session: URLSession = .shared) async throws -> DevinConsumptionResponse
    {
        var components = URLComponents(url: self.dailyURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate),
        ]
        guard let url = components.url else {
            throw DevinUsageError.parseFailed("Invalid consumption URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout

        let (data, response) = try await self.performRequest(request, session: session)
        try Self.validateResponse(response, data: data)

        do {
            return try JSONDecoder().decode(DevinConsumptionResponse.self, from: data)
        } catch {
            throw DevinUsageError.parseFailed("consumption: \(error.localizedDescription)")
        }
    }

    static func fetchMetrics(
        apiKey: String,
        startDate: String,
        endDate: String,
        timeout: TimeInterval = 15,
        session: URLSession = .shared) async throws -> DevinUsageMetrics
    {
        var components = URLComponents(url: self.metricsURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate),
        ]
        guard let url = components.url else {
            throw DevinUsageError.parseFailed("Invalid metrics URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = timeout

        let (data, response) = try await self.performRequest(request, session: session)
        try Self.validateResponse(response, data: data)

        do {
            return try JSONDecoder().decode(DevinUsageMetrics.self, from: data)
        } catch {
            throw DevinUsageError.parseFailed("metrics: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private static func performRequest(
        _ request: URLRequest,
        session: URLSession) async throws -> (Data, URLResponse)
    {
        do {
            return try await session.data(for: request)
        } catch {
            throw DevinUsageError.networkError(error.localizedDescription)
        }
    }

    private static func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DevinUsageError.networkError("Non-HTTP response")
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "(non-UTF-8)"
            throw DevinUsageError.apiError(httpResponse.statusCode, body)
        }
    }

    private static func parseDate(_ dateString: String) -> Date? {
        let formatters: [ISO8601DateFormatter] = {
            let full = ISO8601DateFormatter()
            full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let standard = ISO8601DateFormatter()
            standard.formatOptions = [.withInternetDateTime]
            return [full, standard]
        }()
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }

    // MARK: - Test Support

    public static func _parseCyclesForTesting(_ data: Data) throws -> [DevinBillingCycle] {
        try JSONDecoder().decode([DevinBillingCycle].self, from: data)
    }

    public static func _parseConsumptionForTesting(_ data: Data) throws -> DevinConsumptionResponse {
        try JSONDecoder().decode(DevinConsumptionResponse.self, from: data)
    }

    public static func _parseMetricsForTesting(_ data: Data) throws -> DevinUsageMetrics {
        try JSONDecoder().decode(DevinUsageMetrics.self, from: data)
    }
}
