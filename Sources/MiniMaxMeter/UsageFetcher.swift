import Foundation

enum FetchError: LocalizedError {
    case noCookie
    case badStatus(Int)
    case unauthorized
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .noCookie:        return "未配置 Cookie"
        case .badStatus(let c): return "HTTP \(c)"
        case .unauthorized:    return "Cookie 过期，请重新登录"
        case .decode(let s):   return "解码失败: \(s)"
        }
    }
}

actor UsageFetcher {
    /// 真实 endpoint（用户在 DevTools Headers tab 抓的）
    private let endpoint = URL(string: "https://www.minimaxi.com/v1/api/openplatform/coding_plan/remains")!

    private let cookie: String

    init(cookie: String) {
        self.cookie = cookie
    }

    func fetch() async throws -> UsageSnapshot {
        let maxRetries = 3
        var lastError: Error = FetchError.badStatus(-1)

        for attempt in 0..<maxRetries {
            do {
                return try await fetchOnce()
            } catch FetchError.unauthorized {
                // 401/403 不重试
                throw FetchError.unauthorized
            } catch {
                lastError = error
                if attempt < maxRetries - 1 {
                    // 指数退避：1s / 3s / 9s
                    let delaySec = pow(3.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delaySec * 1_000_000_000))
                }
            }
        }
        throw lastError
    }

    private func fetchOnce() async throws -> UsageSnapshot {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "GET"
        req.setValue(cookie, forHTTPHeaderField: "Cookie")
        req.setValue("https://platform.minimaxi.com", forHTTPHeaderField: "Origin")
        req.setValue("https://platform.minimaxi.com/", forHTTPHeaderField: "Referer")
        req.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        req.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36",
                     forHTTPHeaderField: "User-Agent")
        if let groupId = Self.extractGroupId(from: cookie) {
            req.setValue(groupId, forHTTPHeaderField: "X-Group-Id")
        }
        req.timeoutInterval = 10

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
            let decoded = try JSONDecoder().decode(UsageResponse.self, from: data)
            guard let r = decoded.modelRemains.first(where: { $0.modelName == "general" }),
                  let pair = Quota.from(r) else {
                throw FetchError.decode("找不到 general 模型")
            }
            return UsageSnapshot(fiveHour: pair.fiveHour, weekly: pair.weekly, fetchedAt: Date())
        } catch let e as FetchError {
            throw e
        } catch {
            throw FetchError.decode(error.localizedDescription)
        }
    }

    /// 从 cookie 字符串里抓 `minimax_group_id_v2=2027774615954137290`
    static func extractGroupId(from cookie: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"minimax_group_id_v2=(\d+)"#) else { return nil }
        let range = NSRange(cookie.startIndex..., in: cookie)
        guard let match = regex.firstMatch(in: cookie, range: range),
              let r = Range(match.range(at: 1), in: cookie) else { return nil }
        return String(cookie[r])
    }
}
