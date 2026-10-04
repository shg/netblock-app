import NetworkExtension
import OSLog

final class FilterDataProvider: NEFilterDataProvider {
    private let logger = Logger(subsystem: "org.kakera.netblock.app", category: "FilterLifecycle")
    private var rules = try! DomainRules(text: "")
    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        do {
            let domains = filterConfiguration.vendorConfiguration?["domains"] as? [String] ?? []
            rules = try DomainRules(text: domains.joined(separator: "\n"))
            logger.notice("Filter started with \(self.rules.domains.count) domain rules")
            completionHandler(nil)
        } catch { completionHandler(error) }
    }
    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        rules = try! DomainRules(text: "")
        logger.notice("Filter stopped, reason: \(reason.rawValue)")
        completionHandler()
    }
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        let host = flow.url?.host ?? (flow as? NEFilterSocketFlow)?.remoteHostname
        if let host, rules.blocks(host) { return .drop() }
        return .allow()
    }
}
