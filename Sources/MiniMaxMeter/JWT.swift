import Foundation

/// JWT 工具：解码 `_token` 里的 `exp` 字段
enum JWT {
    /// 从 JWT 字符串解码 payload，提取 `exp` 字段
    /// - Parameter token: JWT 字符串（"header.payload.signature"）
    /// - Returns: 过期时间（Date），解析失败返回 nil
    static func expirationDate(from token: String) -> Date? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        let payloadSegment = String(segments[1])

        // base64url → base64
        var base64 = payloadSegment
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // 补 padding
        while base64.count % 4 != 0 {
            base64.append("=")
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? Double else { return nil }

        return Date(timeIntervalSince1970: exp)
    }

    /// 从 cookie 字符串里找 `_token=...` 并解析 exp
    /// minimaxi cookie 里的 _token 是 JWT，含 exp 字段
    static func cookieExpiration(_ cookie: String) -> Date? {
        // 用 ; 分隔，找 _token=xxx
        for part in cookie.split(separator: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("_token=") {
                let token = String(trimmed.dropFirst("_token=".count))
                return expirationDate(from: token)
            }
        }
        return nil
    }

    /// 距离过期还有几天（负数=已过期）
    static func daysUntilExpiration(_ date: Date, from now: Date = Date()) -> Int {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        let startOfExpiry = cal.startOfDay(for: date)
        let comps = cal.dateComponents([.day], from: startOfToday, to: startOfExpiry)
        return comps.day ?? 0
    }
}
