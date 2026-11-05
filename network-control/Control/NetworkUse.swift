enum LinkKind: Sendable {
    case wifi, ethernet, other
}

enum NetworkUse: Sendable, Equatable {
    case wifi, ethernet, other, offline

    // Links arrive in system preference order; a VPN on top still runs over the first real link.
    init(connected: Bool, links: [LinkKind]) {
        guard connected, !links.isEmpty else {
            self = .offline
            return
        }
        switch links.first(where: { $0 != .other }) {
        case .wifi: self = .wifi
        case .ethernet: self = .ethernet
        default: self = .other
        }
    }

    var title: String {
        switch self {
        case .wifi: "Wi-Fi"
        case .ethernet: "Ethernet"
        case .other: "Other"
        case .offline: "Offline"
        }
    }

    var symbol: String {
        switch self {
        case .wifi: "wifi"
        case .ethernet: "cable.connector"
        case .other: "network"
        case .offline: "network.slash"
        }
    }
}
