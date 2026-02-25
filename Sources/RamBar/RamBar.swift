import AppKit
import Combine
import Darwin
import SwiftUI

@MainActor
final class RamMonitor: ObservableObject {
    @Published private(set) var usedPercent: Int = 0
    @Published private(set) var ramUsageText: String = "--/--G"
    @Published private(set) var wattsText: String = "--W"
    @Published private(set) var refreshInterval: Int = 5

    private var timer: Timer?
    private let refreshKey = "RamBarRefreshIntervalSeconds"

    init() {
        let saved = UserDefaults.standard.integer(forKey: refreshKey)
        refreshInterval = [1, 3, 5, 10, 30, 60].contains(saved) ? saved : 10
        refresh()
        rescheduleTimer()
    }

    func setRefreshInterval(seconds: Int) {
        let clamped = [1, 3, 5, 10, 30, 60].contains(seconds) ? seconds : 10
        guard clamped != refreshInterval else { return }
        refreshInterval = clamped
        UserDefaults.standard.set(clamped, forKey: refreshKey)
        rescheduleTimer()
        refresh()
    }

    private func rescheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(refreshInterval), target: self, selector: #selector(onTimer), userInfo: nil, repeats: true)
    }

    @objc private func onTimer() {
        refresh()
    }

    func refresh() {
        guard let snapshot = Self.currentMemorySnapshot() else { return }

        let percent = Int((snapshot.usedBytes / snapshot.totalBytes) * 100.0)
        usedPercent = max(0, min(100, percent))

        let usedGiB = snapshot.usedBytes / 1_073_741_824.0
        let totalGiB = snapshot.totalBytes / 1_073_741_824.0
        ramUsageText = String(format: "%.1f/%.1fG", usedGiB, totalGiB)

        wattsText = Self.currentSystemWattsText() ?? "--W"
    }

    private struct MemorySnapshot {
        let usedBytes: Double
        let totalBytes: Double
    }

    private static func currentMemorySnapshot() -> MemorySnapshot? {
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { integerPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, integerPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            return nil
        }

        let usedPages = Double(vmStats.active_count + vmStats.wire_count + vmStats.compressor_page_count)
        let usedBytes = usedPages * Double(pageSize)

        return MemorySnapshot(usedBytes: usedBytes, totalBytes: totalBytes)
    }

    private static func currentSystemWattsText() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["macmon", "pipe", "-s", "1", "-i", "200"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard
            let text = String(data: data, encoding: .utf8),
            let line = text.split(separator: "\n").first,
            let jsonData = line.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            let watts = object["all_power"] as? Double
        else {
            return nil
        }

        return "\(Int(watts.rounded()))W"
    }
}

final class LaunchAtStartupManager {
    private let label = "com.daffibot.rambar"

    private var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentURL.path)
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            try? installAgent()
        } else {
            try? FileManager.default.removeItem(at: launchAgentURL)
        }
    }

    private func installAgent() throws {
        guard let executablePath = Bundle.main.executablePath else { return }

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": true
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let parentDirectory = launchAgentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        try data.write(to: launchAgentURL, options: .atomic)
    }
}

struct RamStatusView: View {
    @ObservedObject var monitor: RamMonitor

    var body: some View {
        HStack(spacing: 7) {
            Text(monitor.wattsText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(width: 40, alignment: .trailing)

            GeometryReader { geometry in
                let barWidth = max(0, min(geometry.size.width, geometry.size.width * CGFloat(monitor.usedPercent) / 100.0))

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.35))

                    Capsule()
                        .fill(Color.primary)
                        .frame(width: barWidth)
                }
            }
            .frame(width: 104, height: 10)

            Text("\(monitor.usedPercent)%")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(width: 198, height: 18)
        .padding(.horizontal, 4)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = RamMonitor()
    private var statusItem: NSStatusItem?
    private let macMonCommand = "macmon"
    private let launchManager = LaunchAtStartupManager()
    private var startupMenuItem: NSMenuItem?
    private var ramUsageMenuItem: NSMenuItem?
    private var refreshItems: [Int: NSMenuItem] = [:]
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: 214)
        statusItem = item

        guard let button = item.button else { return }
        button.imagePosition = .imageOnly

        let hosting = NSHostingView(rootView: RamStatusView(monitor: monitor))
        hosting.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(hosting)

        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: button.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])

        let menu = NSMenu()

        let forceRefresh = NSMenuItem(title: "Force Refresh", action: #selector(forceRefresh), keyEquivalent: "")
        forceRefresh.target = self
        menu.addItem(forceRefresh)

        let openMacMon = NSMenuItem(title: "Open mac mon in Terminal", action: #selector(openMacMonInTerminal), keyEquivalent: "")
        openMacMon.target = self
        menu.addItem(openMacMon)

        let startupItem = NSMenuItem(title: "Start on Startup", action: #selector(toggleLaunchAtStartup), keyEquivalent: "")
        startupItem.target = self
        startupItem.state = launchManager.isEnabled() ? .on : .off
        menu.addItem(startupItem)
        startupMenuItem = startupItem

        let ramItem = NSMenuItem(title: "RAM: \(monitor.ramUsageText)", action: nil, keyEquivalent: "")
        ramItem.isEnabled = false
        menu.addItem(ramItem)
        ramUsageMenuItem = ramItem

        menu.addItem(.separator())

        let settingsHeader = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        settingsHeader.isEnabled = false
        menu.addItem(settingsHeader)

        for seconds in [1, 3, 5, 10, 30, 60] {
            let title = seconds == 1 ? "1 second refresh" : "\(seconds) second refresh"
            let intervalItem = NSMenuItem(title: title, action: #selector(selectRefreshInterval(_:)), keyEquivalent: "")
            intervalItem.target = self
            intervalItem.tag = seconds
            menu.addItem(intervalItem)
            refreshItems[seconds] = intervalItem
        }
        updateRefreshChecks(selected: monitor.refreshInterval)

        menu.addItem(.separator())

        let closeItem = NSMenuItem(title: "Close RamBar", action: #selector(quitApp), keyEquivalent: "")
        closeItem.target = self
        menu.addItem(closeItem)

        item.menu = menu

        monitor.$ramUsageText
            .receive(on: RunLoop.main)
            .sink { [weak self] usageText in
                self?.ramUsageMenuItem?.title = "RAM: \(usageText)"
            }
            .store(in: &cancellables)
    }

    private func updateRefreshChecks(selected: Int) {
        for (seconds, item) in refreshItems {
            item.state = seconds == selected ? .on : .off
        }
    }

    @objc private func forceRefresh() {
        monitor.refresh()
    }

    @objc private func openMacMonInTerminal() {
        let appleScript = """
        tell application "Terminal"
            activate
            do script "\(macMonCommand)"
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript]
        try? process.run()
    }

    @objc private func toggleLaunchAtStartup() {
        let newEnabled = !(startupMenuItem?.state == .on)
        launchManager.setEnabled(newEnabled)
        startupMenuItem?.state = newEnabled ? .on : .off
    }

    @objc private func selectRefreshInterval(_ sender: NSMenuItem) {
        monitor.setRefreshInterval(seconds: sender.tag)
        updateRefreshChecks(selected: sender.tag)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

@MainActor
@main
struct RamBarApp {
    private static let appDelegate = AppDelegate()

    static func main() {
        signal(SIGHUP, SIG_IGN)
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.run()
    }
}
