import SwiftUI
@main
struct NetBlockApp: App {
    @StateObject private var controller = FilterController()
    var body: some Scene {
        MenuBarExtra {
            Text(controller.enabled ? "Filter configuration: On" : "Filter configuration: Off")
            Button(controller.enabled ? "Turn Blocking Off" : "Turn Blocking On") { Task { await controller.toggle() } }
                .disabled(controller.busy || controller.needsProxyRecovery)
            OpenSettingsButton()
            if !controller.message.isEmpty { Text(controller.message) }
            Divider()
            Button("Quit (Keep Filter Configuration)") { NSApplication.shared.terminate(nil) }.disabled(controller.busy)
        } label: {
            Image(nsImage: WireMenuIcon.image(blocking: controller.enabled))
                .accessibilityLabel(controller.enabled ? "NetBlock: blocking on" : "NetBlock: blocking off")
        }
        Settings {
            ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("NetBlock — Content Filter").font(.title2.bold())
                Text("Enter one domain per line. Subdomains are included.")
                TextEditor(text: $controller.domainText).font(.system(.body, design: .monospaced)).frame(height: 180).border(.secondary)
                HStack {
                    Button("Install / Update Extension") { controller.installExtension() }
                    Button("Save & Apply Domains") { Task { await controller.saveRules() } }
                }.disabled(controller.busy || controller.needsProxyRecovery)
                if controller.needsProxyRecovery { Button("Restore Previous Proxy Settings") { controller.recoverProxy() } }
                Button("Remove Filter & Extension") { Task { await controller.uninstall() } }.disabled(controller.busy)
                GroupBox("Content Filter Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(controller.diagnostics)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack {
                            Button("Refresh Status") { Task { await controller.refreshStatus() } }
                                .disabled(controller.busy || controller.refreshingStatus)
                            Button("Copy Status") { controller.copyStatus() }
                        }
                    }
                }
                Text(controller.message).textSelection(.enabled)
                Text("Blocking applies to new connections with an available hostname. If a site remains unavailable after turning blocking off, fully quit and reopen your browser.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(20).frame(width: 620)
            }.frame(height: 720)
                .background(SettingsWindowActivation())
        }
    }
}

private struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        Button("Domains & Settings…") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openSettings()
        }
    }
}

// Activate after SwiftUI has attached the settings view to its window.
private struct SettingsWindowActivation: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { ActivationView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ActivationView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async { [weak window] in
                NSApplication.shared.activate(ignoringOtherApps: true)
                window?.makeKeyAndOrderFront(nil)
            }
        }
    }
}

// A template image follows the menu bar's light/dark appearance automatically.
private enum WireMenuIcon {
    static func image(blocking: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            // Keep exactly the same curve in both states; only hide the cut section.
            let wire = NSBezierPath()
            wire.lineWidth = 1.7
            wire.lineCapStyle = .round
            wire.move(to: NSPoint(x: 1, y: 9))
            wire.curve(to: NSPoint(x: 17, y: 9),
                       controlPoint1: NSPoint(x: 6, y: 16),
                       controlPoint2: NSPoint(x: 12, y: 2))
            NSGraphicsContext.saveGraphicsState()
            if blocking {
                let visibleWire = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 5.8, height: 18))
                visibleWire.appendRect(NSRect(x: 12.2, y: 0, width: 5.8, height: 18))
                visibleWire.addClip()
            }
            wire.stroke()
            NSGraphicsContext.restoreGraphicsState()
            if blocking {
                let blades = NSBezierPath()
                blades.lineWidth = 1.8
                blades.lineCapStyle = .round
                blades.move(to: NSPoint(x: 7.1, y: 5.1))
                blades.line(to: NSPoint(x: 12, y: 15.5))
                blades.move(to: NSPoint(x: 10.9, y: 5.1))
                blades.line(to: NSPoint(x: 6, y: 15.5))
                blades.stroke()
                for x in [CGFloat(4.5), CGFloat(9.7)] {
                    let ring = NSBezierPath(ovalIn: NSRect(x: x, y: 1.5, width: 3.8, height: 3.8))
                    ring.lineWidth = 1.3
                    ring.stroke()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
