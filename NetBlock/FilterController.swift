import SwiftUI
import NetworkExtension
import SystemExtensions
import OSLog

@MainActor
final class FilterController: NSObject, ObservableObject, @preconcurrency OSSystemExtensionRequestDelegate {
    static weak var current: FilterController?
    var extensionID: String { (Bundle.main.bundleIdentifier ?? "dev.netblock.app") + ".filter" }
    @Published var enabled = false
    @Published var busy = false
    @Published var message = ""
    @Published var domainText = UserDefaults.standard.string(forKey: "domains") ?? UserDefaults(suiteName: "dev.netblock.app")?.string(forKey: "domains") ?? ""
    @Published var needsProxyRecovery = false
    @Published var configurationStatus = "Not checked yet"
    @Published var extensionStatus = "Not checked yet"
    @Published var statusUpdatedAt = "Never"
    @Published var refreshingStatus = false
    private var propertiesRequest: OSSystemExtensionRequest?
    private var propertiesDelegate: ExtensionStatusDelegate?
    var diagnostics: String {
        "NetBlock Content Filter Status\nApp build: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")\nChecked: \(statusUpdatedAt)\n\n\(configurationStatus)\n\nSystem extension:\n\(extensionStatus)\n\nExtension approval is separate from filter enablement. Provider runtime health is not available from these settings."
    }
    func copyStatus() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
    }
    func refreshStatus() async {
        guard !busy, !refreshingStatus else { return }
        await refresh()
        queryExtensionStatus()
    }
    private func queryExtensionStatus() {
        guard propertiesRequest == nil else { return }
        let request = OSSystemExtensionRequest.propertiesRequest(forExtensionWithIdentifier: extensionID, queue: .main)
        let delegate = ExtensionStatusDelegate { [weak self] result in
            guard let self else { return }
            self.extensionStatus = result
            self.propertiesRequest = nil
            self.propertiesDelegate = nil
        }
        propertiesRequest = request
        propertiesDelegate = delegate
        request.delegate = delegate
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    private let logger = Logger(subsystem: "org.kakera.netblock.app", category: "FilterConfiguration")
    private let manager = NEFilterManager.shared()
    private var extensionRequest: OSSystemExtensionRequest?
    private var monitor: Timer?

    override init() {
        super.init()
        Self.current = self
        do { needsProxyRecovery = try ProxySettings.recovery() != nil }
        catch { needsProxyRecovery = true; message = error.localizedDescription }
        if needsProxyRecovery { message = "Restore the previous local proxy settings first." }
        Task { await refreshStatus() }
        monitor = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in guard let self, !self.busy else { return }; await self.refreshStatus() }
        }
    }
    private func refresh() async {
        guard !refreshingStatus else { return }
        refreshingStatus = true
        defer { refreshingStatus = false }
        do {
            try await manager.loadFromPreferences()
            enabled = manager.isEnabled
            let config = manager.providerConfiguration
            let domains = config?.vendorConfiguration?["domains"] as? [String] ?? []
            configurationStatus = "Saved filter: \(manager.isEnabled ? "Enabled" : "Disabled")\nConfiguration present: \(config == nil ? "No" : "Yes")\nProvider: \(config?.filterDataProviderBundleIdentifier ?? "None")\nSocket filtering: \(config?.filterSockets == true ? "Yes" : "No")\nBrowser filtering: \(config?.filterBrowsers == true ? "Yes" : "No")\nSaved domains: \(domains.isEmpty ? "None" : domains.joined(separator: ", "))"
            statusUpdatedAt = Date().formatted(date: .abbreviated, time: .standard)
        } catch {
            configurationStatus = "Unable to read current settings: \(error.localizedDescription)\nPrevious state is not current."
            statusUpdatedAt = Date().formatted(date: .abbreviated, time: .standard)
        }
    }
    func recoverProxy() {
        guard !busy, !refreshingStatus else { return }
        do {
            if let snapshot = try ProxySettings.recovery() {
                try ProxySettings.write(snapshot, restoring: true)
                try ProxySettings.clearRecovery()
            }
            needsProxyRecovery = false
            message = "Previous proxy settings restored."
        } catch { showError(error) }
    }
    func installExtension() {
        guard !busy, !refreshingStatus, !needsProxyRecovery else { return }
        busy = true
        let request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionID, queue: .main)
        request.delegate = self; extensionRequest = request
        message = "Requesting system extension activation from macOS."
        OSSystemExtensionManager.shared.submitRequest(request)
    }
    func uninstall() async {
        guard !busy, !refreshingStatus else { return }
        busy = true
        do {
            try await manager.loadFromPreferences()
            if manager.providerConfiguration != nil { try await manager.removeFromPreferences() }
            enabled = false
            let request = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: extensionID, queue: .main)
            request.delegate = self; extensionRequest = request
            OSSystemExtensionManager.shared.submitRequest(request)
        } catch { busy = false; showError(error) }
    }
    func toggle() async {
        await apply(wantEnabled: !enabled, updateRules: !enabled)
    }
    func saveRules() async { await apply(wantEnabled: enabled, updateRules: true) }
    private func apply(wantEnabled: Bool, updateRules: Bool) async {
        guard !busy, !refreshingStatus, !needsProxyRecovery else { return }
        busy = true; defer { busy = false }
        do {
            let rules = updateRules ? try DomainRules(text: domainText) : nil
            if wantEnabled && rules?.domains.isEmpty == true { throw ProxySettings.error("Enter at least one domain.") }
            try await manager.loadFromPreferences()
            if updateRules {
                if manager.isEnabled {
                    manager.isEnabled = false; try await manager.saveToPreferences()
                    enabled = false; try await manager.loadFromPreferences()
                }
                let config = NEFilterProviderConfiguration()
                config.filterSockets = true
                config.filterDataProviderBundleIdentifier = extensionID
                config.vendorConfiguration = ["domains": rules!.domains]
                manager.providerConfiguration = config
                manager.localizedDescription = "NetBlock"
            }
            if manager.providerConfiguration != nil {
                manager.isEnabled = wantEnabled
                try await manager.saveToPreferences()
                try await manager.loadFromPreferences()
            }
            enabled = manager.isEnabled
            logger.notice("Saved filter configuration: enabled=\(self.enabled)")
            if let rules {
                domainText = rules.domains.joined(separator: "\n")
                UserDefaults.standard.set(domainText, forKey: "domains")
            }
            message = enabled ? "Blocking enabled for new connections." : "Blocking disabled. If a site still fails, fully quit and reopen your browser."
            await refresh()
        } catch { await refresh(); showError(error) }
    }
    private func showError(_ error: Error) {
        message = error.localizedDescription
        NSApplication.shared.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = "NetBlock could not complete the operation"
        alert.informativeText = message; alert.runModal()
    }
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) { message = "Allow the NetBlock system extension in System Settings." }
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction { .replace }
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        busy = false; extensionRequest = nil
        message = result == .willCompleteAfterReboot ? "Restart your Mac to complete the change." : "System extension change completed."
    }
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) { busy = false; extensionRequest = nil; showError(error) }
}

@MainActor
private final class ExtensionStatusDelegate: NSObject, @preconcurrency OSSystemExtensionRequestDelegate {
    private let completion: (String) -> Void
    init(completion: @escaping (String) -> Void) { self.completion = completion }
    func request(_ request: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]) {
        completion(properties.isEmpty ? "Not installed" : properties.map {
            "Build: \($0.bundleVersion)\nApproved/enabled: \($0.isEnabled ? "Yes" : "No")\nAwaiting approval: \($0.isAwaitingUserApproval ? "Yes" : "No")\nUninstalling: \($0.isUninstalling ? "Yes" : "No")"
        }.joined(separator: "\n\n"))
    }
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) { completion("Unable to query extension: \(error.localizedDescription)") }
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {}
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) { completion("Awaiting user approval") }
    func request(_ request: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties, withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction { .cancel }
}
