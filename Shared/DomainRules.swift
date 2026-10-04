import Foundation

struct DomainRules {
    let domains: [String]

    init(text: String) throws {
        var result = Set<String>()
        for line in text.components(separatedBy: .newlines) {
            let value = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if value.isEmpty { continue }
            guard let domain = Self.normalize(value), domain.contains("."),
                  !domain.contains(":"), !domain.contains("/"),
                  domain.split(separator: ".", omittingEmptySubsequences: false).allSatisfy({ label in
                      !label.isEmpty && label.count <= 63 && label.first != "-" && label.last != "-" &&
                      label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
                  }), domain.count <= 253 else {
                throw NSError(domain: "NetBlock", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid domain: \(line). Enter a domain such as example.com, not a URL. Use Punycode for internationalized domains."])
            }
            result.insert(domain)
        }
        domains = result.sorted()
    }

    static func normalize(_ host: String) -> String? {
        var host = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if host.hasSuffix(".") { host.removeLast() }
        return host.isEmpty ? nil : host
    }

    func blocks(_ host: String) -> Bool {
        guard let host = Self.normalize(host) else { return false }
        return domains.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
