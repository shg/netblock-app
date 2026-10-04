import Foundation
import SystemConfiguration
import Security

struct ProxySnapshot: Codable {
    let serviceID: String
    let original: Data
    let installed: Data
}
final class ProxySettings {
    static let port = 18473
    private static let recoveryURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NetBlock/proxy-recovery.json")
    static func error(_ message: String) -> NSError { NSError(domain: "NetBlock", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    static func data(_ dict: [String: Any]) throws -> Data { try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) }
    static func dictionary(_ data: Data) throws -> [String: Any] { try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] ?? [:] }
    static func read(_ id: String) throws -> [String: Any] {
        guard let prefs = SCPreferencesCreate(nil, "NetBlock" as CFString, nil), let service = SCNetworkServiceCopy(prefs, id as CFString),
              let proto = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeProxies) else { throw error("Could not read the network service.") }
        return SCNetworkProtocolGetConfiguration(proto) as? [String: Any] ?? [:]
    }
    static func same(_ a: [String: Any], _ b: [String: Any]) -> Bool { NSDictionary(dictionary: a).isEqual(to: b) }
    static func recovery() throws -> ProxySnapshot? {
        guard FileManager.default.fileExists(atPath: recoveryURL.path) else { return nil }
        return try JSONDecoder().decode(ProxySnapshot.self, from: Data(contentsOf: recoveryURL))
    }
    static func saveRecovery(_ snapshot: ProxySnapshot) throws {
        try FileManager.default.createDirectory(at: recoveryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: recoveryURL.deletingLastPathComponent().path)
        try JSONEncoder().encode(snapshot).write(to: recoveryURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: recoveryURL.path)
    }
    static func clearRecovery() throws { try FileManager.default.removeItem(at: recoveryURL) }
    static func write(_ snapshot: ProxySnapshot, restoring: Bool) throws {
        var authorization: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [.interactionAllowed, .extendRights, .preAuthorize], &authorization) == errAuthorizationSuccess,
              let authorization else { throw error("Could not obtain authorization to change settings.") }
        defer { AuthorizationFree(authorization, []) }
        guard let prefs = SCPreferencesCreateWithAuthorization(nil, "NetBlock" as CFString, nil, authorization), SCPreferencesLock(prefs, true) else { throw error("Could not lock network settings.") }
        defer { SCPreferencesUnlock(prefs) }
        guard let service = SCNetworkServiceCopy(prefs, snapshot.serviceID as CFString),
              let proto = SCNetworkServiceCopyProtocol(service, kSCNetworkProtocolTypeProxies) else { throw error("The network service could not be found.") }
        let current = SCNetworkProtocolGetConfiguration(proto) as? [String: Any] ?? [:]
        let original = try dictionary(snapshot.original), installed = try dictionary(snapshot.installed)
        if restoring && same(current, original) {
            guard SCPreferencesApplyChanges(prefs) else { throw error("Could not apply restored settings. Recovery data has been retained.") }
            return
        }
        guard same(current, restoring ? installed : original) else { throw error("Another app changed the proxy settings. No settings were overwritten. Recovery data has been retained.") }
        guard SCNetworkProtocolSetConfiguration(proto, (restoring ? original : installed) as CFDictionary),
              SCPreferencesCommitChanges(prefs), SCPreferencesApplyChanges(prefs) else { throw error("Could not apply settings (\(SCError())). Recovery data has been retained.") }
    }
}
