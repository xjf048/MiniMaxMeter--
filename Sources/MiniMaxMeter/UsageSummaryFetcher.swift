import Foundation

// MARK: - API Response

struct UsageSummaryResponse: Codable {
    let totalDays: Int
    let totalTokenConsumed: String
    let usageRankingPercent: Double
    let activeDays: Int
    let currentConsecutiveDays: Int
    let dailyTokenUsage: [Int]              // 索引 0 = 最早日期
    let dateModelUsage: [DateModelEntry]    // 提供起始日期
    let lastUpdateTime: String

    enum CodingKeys: String, CodingKey {
        case totalDays              = "total_days"
        case totalTokenConsumed     = "total_token_consumed"
        case usageRankingPercent    = "usage_ranking_percent"
        case activeDays             = "active_days"
        case currentConsecutiveDays = "current_consecutive_days"
        case dailyTokenUsage        = "daily_token_usage"
        case dateModelUsage         = "date_model_usage"
        case lastUpdateTime         = "last_update_time"
    }
}

struct DateModelEntry: Codable {
    let date: String  // "2026-01-07"
}

// MARK: - Domain Model

struct DailyUsage: Identifiable, Equatable, Hashable {
    let date: Date
    let tokens: Int
    var id: Date { date }
}

// MARK: - Fetcher

actor UsageSummaryFetcher {
    /// 真实 endpoint（用户在 DevTools Headers tab 抓的）
    private let endpoint = URL(string: "https://www.minimaxi.com/backend/account/token_plan/usage_summary")!

    private let cookie: String

    init(cookie: String) {
        self.cookie = cookie
    }

    func fetch() async throws -> [DailyUsage] {
        let maxRetries = 3
        var lastError: Error = FetchError.badStatus(-1)

        for attempt in 0..<maxRetries {
            do {
                return try await fetchOnce()
            } catch FetchError.unauthorized {
                throw FetchError.unauthorized
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    let delaySec = pow(3.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delaySec * 1_000_000_000))
                }
            }
        }
        throw lastError
    }

    private func fetchOnce() async throws -> [DailyUsage] {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "GET"
        req.setValue(cookie, forHTTPHeaderField: "Cookie")
        req.setValue("https://platform.minimaxi.com", forHTTPHeaderField: "Origin")
        req.setValue("https://platform.minimaxi.com/", forHTTPHeaderField: "Referer")
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        req.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36",
                     forHTTPHeaderField: "User-Agent")
        if let groupId = UsageFetcher.extractGroupId(from: cookie) {
            req.setValue(groupId, forHTTPHeaderField: "X-Group-Id")
        }
        req.timeoutInterval = 15

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw FetchError.badStatus(-1)
        }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw FetchError.unauthorized
        default: throw FetchError.badStatus(http.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(UsageSummaryResponse.self, from: data)
            return Self.toDailyUsage(decoded)
        } catch let e as FetchError {
            throw e
        } catch {
            throw FetchError.decode(error.localizedDescription)
        }
    }

    /// 把 dailyTokenUsage 数组（索引 0 = 最早）转成 DailyUsage 日期数组
    static func toDailyUsage(_ r: UsageSummaryResponse) -> [DailyUsage] {
        guard let firstDateStr = r.dateModelUsage.first?.date else { return [] }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        guard let startDate = formatter.date(from: firstDateStr) else { return [] }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        var result: [DailyUsage] = []
        for (offset, tokens) in r.dailyTokenUsage.enumerated() {
            let date = cal.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            result.append(DailyUsage(date: date, tokens: tokens))
        }
        return result
    }
}
