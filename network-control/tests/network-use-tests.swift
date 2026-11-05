import Foundation

var fails = 0
func check(_ name: String, _ ok: Bool) {
    print("\(ok ? "PASS" : "FAIL")  \(name)")
    if !ok { fails += 1 }
}

check("Wi-Fi alone", NetworkUse(connected: true, links: [.wifi]) == .wifi)
check("Ethernet alone", NetworkUse(connected: true, links: [.ethernet]) == .ethernet)
check("Wi-Fi first wins over Ethernet", NetworkUse(connected: true, links: [.wifi, .ethernet]) == .wifi)
check("Ethernet first wins over Wi-Fi", NetworkUse(connected: true, links: [.ethernet, .wifi]) == .ethernet)
check("VPN on top is skipped", NetworkUse(connected: true, links: [.other, .ethernet, .wifi]) == .ethernet)
check("only a VPN or other link counts as other", NetworkUse(connected: true, links: [.other]) == .other)
check("not connected wins over any link", NetworkUse(connected: false, links: [.ethernet]) == .offline)
check("no links is offline", NetworkUse(connected: true, links: []) == .offline)

check("title Wi-Fi", NetworkUse.wifi.title == "Wi-Fi")
check("title Ethernet", NetworkUse.ethernet.title == "Ethernet")
check("title other", NetworkUse.other.title == "Other")
check("title offline", NetworkUse.offline.title == "Offline")

check("icon Wi-Fi", NetworkUse.wifi.symbol == "wifi")
check("icon Ethernet", NetworkUse.ethernet.symbol == "cable.connector")
check("icon other", NetworkUse.other.symbol == "network")
check("icon offline", NetworkUse.offline.symbol == "network.slash")

print("")
if fails == 0 { print("all passed") } else { print("\(fails) failed"); exit(1) }
