import AppIntents
import Network
import SwiftUI
import WidgetKit

private let controlKind = "ch.holy-grail.network-control.use"

func readNetworkUse() async -> NetworkUse {
    await withCheckedContinuation { continuation in
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            monitor.pathUpdateHandler = nil
            monitor.cancel()
            let links = path.availableInterfaces.map { interface -> LinkKind in
                switch interface.type {
                case .wifi: .wifi
                case .wiredEthernet: .ethernet
                default: .other
                }
            }
            continuation.resume(returning: NetworkUse(connected: path.status == .satisfied, links: links))
        }
        monitor.start(queue: DispatchQueue(label: "network-use"))
    }
}

struct NetworkUseProvider: ControlValueProvider {
    var previewValue: NetworkUse { .wifi }

    func currentValue() async throws -> NetworkUse {
        await readNetworkUse()
    }
}

struct RefreshNetworkUse: AppIntent {
    static let title: LocalizedStringResource = "Refresh network in use"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        ControlCenter.shared.reloadControls(ofKind: controlKind)
        return .result()
    }
}

struct NetworkUseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: controlKind, provider: NetworkUseProvider()) { use in
            ControlWidgetButton(action: RefreshNetworkUse()) {
                Label(use.title, systemImage: use.symbol)
            }
        }
        .displayName("Network in use")
        .description("Shows whether Wi-Fi or Ethernet is carrying your traffic. Click to refresh.")
    }
}

@main
struct NetworkControlBundle: WidgetBundle {
    var body: some Widget {
        NetworkUseControl()
    }
}
