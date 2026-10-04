# NetBlock — Content Filter

NetBlock is a menu bar app for macOS 14 and later. It uses `NEFilterDataProvider` in a System Extension to block new connections to specified domains and their subdomains. The previous local proxy and PAC forwarding implementation has been removed. Recovery of previous proxy settings is available only when recovery data from that version exists.

## Signing setup

1. Open `NetBlock.xcodeproj` in Xcode.
2. For both the NetBlock and NetBlockFilter targets, select your paid Apple Developer Team under Signing & Capabilities. Automatically manage signing is enabled. The public project leaves the Team field blank; select your own Team to sign the app.
3. The app bundle ID is `org.kakera.netblock.app`, and the extension bundle ID is `org.kakera.netblock.app.filter`. If you cannot register these IDs, replace them with unique IDs. The extension ID must be the app ID followed by `.filter`. Update the extension's Product Name and the corresponding identifiers in its Info.plist as well.
4. Apple Development signing uses `content-filter-provider`. The `*.DeveloperID.entitlements` files use `content-filter-provider-systemextension` for Developer ID signing. The app also has `com.apple.developer.system-extension.install`, and the extension has App Sandbox enabled. Enable the corresponding capabilities in your Apple App IDs and provisioning profiles.
5. Create the required Apple Development or Developer ID Application certificate in Xcode Settings → Accounts → your Team → Manage Certificates. The default signing configuration uses Apple Development, including Release builds. Developer ID distribution requires the corresponding provisioning profiles and entitlements, plus notarization.

Both targets use the App Group `$(TeamIdentifierPrefix)org.kakera.netblock.app`. The extension's `NEMachServiceName` is this group name followed by `.filter`. Preserve this relationship when changing bundle IDs.

An unsigned build only verifies compilation; it cannot activate the Content Filter. Follow Apple's requirements for System Extension installation and development signing. Install the signed app at `/Applications/NetBlock.app`. Activation from `~/Applications` was rejected during testing.

## Usage

1. If the previous local proxy version is running, turn blocking off in that version and quit it.
2. Launch the signed Content Filter version. If previous proxy recovery data exists, select **Restore Previous Proxy Settings**. Conflicting settings are not overwritten automatically.
3. Select **Install / Update Extension** in Settings and complete the macOS System Extension approval process.
4. Enter one domain per line, save the domains, and turn blocking on. Approve the network filter permission dialog.
5. Turn blocking off to allow new connections. Quitting the app preserves the saved filter configuration. To remove it, use **Remove Filter & Extension**.

For example, `yahoo.co.jp` also matches `www.yahoo.co.jp`. Enter domain names without URLs or wildcards. Use Punycode for internationalized domain names.

## Uninstalling

1. Select **Remove Filter & Extension** in NetBlock Settings. This removes the filter configuration and requests deactivation and removal of the System Extension.
2. Approve any macOS authentication prompt. If **Restart your Mac to complete the change.** appears, restart your Mac to finish removal. If an error appears, removal has not completed; check the error before proceeding.
3. To remove the app itself, wait until extension removal is complete, quit NetBlock, and move `/Applications/NetBlock.app` to the Trash.

Turning blocking off or quitting the app does not uninstall the extension. Remove the extension before deleting the app.

## Limitations and verification status

- The On indicator reflects the configuration saved through `NEFilterManager`. It does not confirm provider health or successful blocking of every target domain.
- Filter settings changed outside the app are reloaded periodically.
- Domain matching uses `flow.url.host` or `NEFilterSocketFlow.remoteHostname`. Connections without an available hostname are allowed. IP addresses are not used to infer domains, avoiding incorrect blocking on shared IP addresses.
- Connections established before blocking is enabled are not blocked. Test with new connections, for example after restarting the browser.
- Updating domains while blocking is on briefly disables and then re-enables the filter. Blocking is inactive during this interval. An error is shown if re-enabling fails.
- This implementation does not depend on proxy settings. NordVPN coexistence and hostname availability in Safari, Firefox, Chrome, and curl require testing with a signed app on the target system.
- The Content Filter version leaves existing PAC and proxy settings unchanged, except when restoring settings from the previous proxy implementation.

## Compilation and domain matching tests

```sh
xcodebuild -project NetBlock.xcodeproj -scheme NetBlock -configuration Release -derivedDataPath /tmp/NetBlock-content-build CODE_SIGNING_ALLOWED=NO build
swiftc -module-cache-path /tmp/netblock-swift-cache Shared/DomainRules.swift Tests/main.swift -o /tmp/netblock-domain-tests
/tmp/netblock-domain-tests
```

Regenerate the project with `python3 Scripts/generate-project.py`. The Team is blank by default. To supply your local Team, run `NETBLOCK_TEAM_ID=YOUR_TEAM_ID python3 Scripts/generate-project.py`. Regeneration overwrites project settings edited in Xcode. Check that the Team, bundle IDs, and App Groups remain consistent.

## Official documentation

- [Network Extension provider deployment](https://developer.apple.com/documentation/technotes/tn3134-network-extension-provider-deployment)
- [Network Extension entitlements](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension)
- [Debugging and testing System Extensions](https://developer.apple.com/documentation/driverkit/debugging-and-testing-system-extensions)
- [Hostname availability with remoteHostname](https://developer.apple.com/documentation/networkextension/nefiltersocketflow/remotehostname)

## Recovering access after turning blocking off

Turning blocking off saves `NEFilterManager.isEnabled = false` to stop the provider. Previously rejected connections are not revived. Test with a new connection if access does not recover.

During testing, DNS resolution for x.com timed out once, while a subsequent new curl connection returned HTTP 200. In Safari, ordinary Reload did not restore access, but **Option + Command + R** (Reload Page From Origin) restored it without restarting the browser. Try this first if a page remains unavailable after turning blocking off. Fully quitting and reopening Safari also restored access. Cached or other retained browser state may be involved, but the exact internal state has not been established. Turning NetBlock off does not guarantee recovery through ordinary Reload. NetBlock does not automatically change DNS or VPN settings or clear browser data.

Filter start, stop, and configuration changes are recorded in the system log under the subsystem `org.kakera.netblock.app`. URLs and browsing destinations are not logged.

## Icons

The application icon source is `NetBlock/Assets/NetBlock-icon.png`, and the macOS icon file is `NetBlock/Assets/NetBlock.icns`. The adopted design is `Design/IconCandidates/e-tilde-scissors.png`. `WireMenuIcon` draws a monochrome menu bar template image: a continuous tilde-shaped wire when blocking is off, and a wire cut by scissors when blocking is on.

## Content Filter status

The **Content Filter Status** section in Settings shows information read from macOS every three seconds. Use **Refresh Status** to update it manually and **Copy Status** to copy diagnostics. It shows the saved filter enablement state, configuration presence, provider ID, socket and browser filtering settings, saved domains, and the extension's build, approval, and removal state. Saved domains are distinct from unsaved edits in the domain editor.

**Approved/enabled** describes System Extension registration and approval. Use **Saved filter** to determine whether blocking is configured as on or off. These APIs do not directly confirm provider runtime health or successful blocking. Query failures are displayed as errors.

## Public source

This repository contains source code and icons. It does not include signed apps, certificates, private keys, provisioning profiles, actual domain settings, or proxy recovery data. The icons were generated with the built-in imagegen tool. Repository history starts from the snapshot prepared for public release.

## License

The code and included icons are provided under the [MIT License](LICENSE).
