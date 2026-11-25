// backdrop-wallpaper: one photo from ~/Pictures/BackdropCarousel on all displays, scaled to the largest one.
//   backdrop-wallpaper --pick | --rescale [--no-apply] [--screens WxH,...]
//   backdrop-wallpaper --watch --interval <seconds> [--no-apply] [--ignore-lock] [--screens WxH,...]
import AppKit
import ImageIO
import UniformTypeIdentifiers

setvbuf(stdout, nil, _IOLBF, 0)

let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
let photosDir = URL(fileURLWithPath: "\(home)/Pictures/BackdropCarousel")
let currentDir = URL(fileURLWithPath: "\(home)/Pictures/BackdropCarousel Current")
let stateDir = URL(fileURLWithPath: "\(home)/.local/state/backdrop-carousel")
let stateFile = stateDir.appendingPathComponent("current")
let pidFile = stateDir.appendingPathComponent("watch.pid")
let fm = FileManager.default

func usage() -> Never {
    FileHandle.standardError.write("""
    usage: backdrop-wallpaper --pick | --rescale [--no-apply] [--screens WxH,...]
           backdrop-wallpaper --watch --interval <seconds> [--no-apply] [--ignore-lock] [--screens WxH,...]

    """.data(using: .utf8)!)
    exit(2)
}

func fail(_ message: String) -> Never {
    print("ERROR: \(message)")
    exit(1)
}

// MARK: arguments

var mode = ""
var interval: Double = 0
var apply = true
var ignoreLock = false
var screenOverride: [CGSize]? = nil
var args = Array(CommandLine.arguments.dropFirst())
while !args.isEmpty {
    let arg = args.removeFirst()
    switch arg {
    case "--pick", "--rescale", "--watch":
        guard mode.isEmpty else { usage() }
        mode = arg
    case "--interval":
        guard let value = args.first.flatMap(Double.init), value > 0 else { usage() }
        interval = value; args.removeFirst()
    case "--no-apply": apply = false
    case "--ignore-lock": ignoreLock = true
    case "--screens":
        guard let list = args.first else { usage() }
        args.removeFirst()
        screenOverride = list.split(separator: ",").map { item in
            let parts = item.split(separator: "x").compactMap { Double($0) }
            guard parts.count == 2 else { usage() }
            return CGSize(width: parts[0], height: parts[1])
        }
    default: usage()
    }
}
if mode.isEmpty || (mode == "--watch" && interval == 0) || (mode != "--watch" && interval != 0) { usage() }

// MARK: photos and state

func photos() -> [String] {
    let exts: Set<String> = ["jpg", "jpeg", "png", "heic"]
    let names = (try? fm.contentsOfDirectory(atPath: photosDir.path)) ?? []
    return names.filter { exts.contains(($0 as NSString).pathExtension.lowercased()) }.sorted()
}

func currentName() -> String? {
    (try? String(contentsOf: stateFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
}

func currentURL() -> URL? {
    let names = (try? fm.contentsOfDirectory(atPath: currentDir.path)) ?? []
    return names.first { !$0.hasPrefix(".") }.map { currentDir.appendingPathComponent($0) }
}

func screenSizes() -> [CGSize] {
    if let override = screenOverride { return override }
    return NSScreen.screens.map { screen in
        CGSize(width: screen.frame.width * screen.backingScaleFactor,
               height: screen.frame.height * screen.backingScaleFactor)
    }
}

// MARK: render and apply

func render(_ name: String) -> (URL, Int, Int) {
    let src = photosDir.appendingPathComponent(name)
    guard let source = CGImageSourceCreateWithURL(src as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
          let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          var w = props[kCGImagePropertyPixelWidth] as? Double,
          var h = props[kCGImagePropertyPixelHeight] as? Double
    else { fail("Cannot read \(name)") }
    if let orientation = props[kCGImagePropertyOrientation] as? Int, orientation >= 5 { swap(&w, &h) }

    var scale = 0.0
    for screen in screenSizes() { scale = max(scale, screen.width / w, screen.height / h) }
    if scale == 0 || scale > 1 { scale = 1 }
    let longSide = Int((max(w, h) * scale - 1e-6).rounded(.up))

    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: longSide,
        kCGImageSourceShouldCache: false,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { fail("Cannot scale \(name)") }

    try? fm.createDirectory(at: currentDir, withIntermediateDirectories: true)
    let base = (name as NSString).deletingPathExtension
    let stamp = Int(Date().timeIntervalSince1970 * 1000)
    let out = currentDir.appendingPathComponent("\(base)-\(image.width)x\(image.height)-\(stamp).jpg")
    let tmp = currentDir.appendingPathComponent(".writing.jpg")
    guard let dest = CGImageDestinationCreateWithURL(tmp as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else { fail("Cannot write \(tmp.path)") }
    CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { fail("Cannot write \(tmp.path)") }
    try? fm.moveItem(at: tmp, to: out)
    for old in (try? fm.contentsOfDirectory(atPath: currentDir.path)) ?? [] where old != out.lastPathComponent {
        try? fm.removeItem(at: currentDir.appendingPathComponent(old))
    }
    try? fm.createDirectory(at: stateDir, withIntermediateDirectories: true)
    try? name.write(to: stateFile, atomically: true, encoding: .utf8)
    return (out, image.width, image.height)
}

func setOnScreens(_ url: URL, onlyIfDifferent: Bool) {
    guard apply else { return }
    let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
        .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
        .allowClipping: true,
    ]
    for screen in NSScreen.screens where !onlyIfDifferent || NSWorkspace.shared.desktopImageURL(for: screen) != url {
        do { try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: options) }
        catch { FileHandle.standardError.write("\(screen.localizedName): \(error)\n".data(using: .utf8)!) }
    }
}

/// newPhoto: a different photo than now; otherwise the current one again (rescaled).
func show(newPhoto: Bool) {
    let all = photos()
    guard !all.isEmpty else { fail("No photos to pick from") }
    let now = currentName()
    let name: String
    if !newPhoto, let now, all.contains(now) {
        name = now
    } else {
        let others = all.filter { $0 != now }
        name = (others.isEmpty ? all : others).randomElement()!
    }
    let (url, w, h) = render(name)
    setOnScreens(url, onlyIfDifferent: false)
    print("Wallpaper: \(name) (\(w)x\(h))")
}

if mode != "--watch" {
    show(newPhoto: mode == "--pick")
    exit(0)
}

// MARK: watch

func commandOf(_ pid: Int32) -> String {
    let ps = Process()
    ps.executableURL = URL(fileURLWithPath: "/bin/ps")
    ps.arguments = ["-p", String(pid), "-o", "comm="]
    let pipe = Pipe()
    ps.standardOutput = pipe
    ps.standardError = FileHandle.nullDevice
    try? ps.run()
    ps.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

let myPid = getpid()
if let text = try? String(contentsOf: pidFile, encoding: .utf8),
   let old = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), old != myPid,
   kill(old, 0) == 0, commandOf(old).contains("backdrop-wallpaper") {
    kill(old, SIGTERM)
    for _ in 0..<40 where kill(old, 0) == 0 { usleep(50_000) }
}
try? fm.createDirectory(at: stateDir, withIntermediateDirectories: true)
try? String(myPid).write(to: pidFile, atomically: true, encoding: .utf8)

func quit() -> Never {
    if let text = try? String(contentsOf: pidFile, encoding: .utf8),
       text.trimmingCharacters(in: .whitespacesAndNewlines) == String(myPid) {
        try? fm.removeItem(at: pidFile)
    }
    exit(0)
}
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT, SIGHUP] {
    signal(sig, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler { quit() }
    source.resume()
    signalSources.append(source)
}

// Each change runs in a child process: ImageIO keeps memory per render that only process exit frees.
let selfPath = Bundle.main.executablePath ?? CommandLine.arguments[0]
func runChild(_ childMode: String) {
    var childArgs = [selfPath, childMode]
    if !apply { childArgs.append("--no-apply") }
    if let override = screenOverride {
        childArgs += ["--screens", override.map { "\(Int($0.width))x\(Int($0.height))" }.joined(separator: ",")]
    }
    var cArgs = childArgs.map { strdup($0) } + [nil]
    defer { cArgs.forEach { free($0) } }
    var pid: pid_t = 0
    guard posix_spawn(&pid, selfPath, nil, nil, &cArgs, environ) == 0 else {
        FileHandle.standardError.write("Cannot start \(selfPath)\n".data(using: .utf8)!)
        return
    }
    var status: Int32 = 0
    waitpid(pid, &status, 0)
}

func screenLocked() -> Bool {
    if ignoreLock { return false }
    let session = CGSessionCopyCurrentDictionary() as? [String: Any]
    return session?["CGSSessionScreenIsLocked"] as? Bool ?? false
}

var lastChange = Date()
var missed = false
func change() {
    if screenLocked() { missed = true; return }
    missed = false
    lastChange = Date()
    runChild("--pick")
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

if let url = currentURL(), let now = currentName(), photos().contains(now) {
    setOnScreens(url, onlyIfDifferent: true)
} else {
    runChild("--pick")
}

let timer = Timer(timeInterval: interval, repeats: true) { _ in change() }
timer.tolerance = interval * 0.1
RunLoop.main.add(timer, forMode: .common)

let distributed = DistributedNotificationCenter.default()
distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in
    if missed || Date().timeIntervalSince(lastChange) >= interval { change() }
}

let workspace = NSWorkspace.shared.notificationCenter
workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
    if !screenLocked(), Date().timeIntervalSince(lastChange) >= interval { change() }
}
workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
    if let url = currentURL() { setOnScreens(url, onlyIfDifferent: true) }
}

var screenCount = NSScreen.screens.count
var screenWork: DispatchWorkItem?
NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
    guard screenOverride == nil else { return }
    screenWork?.cancel()
    let work = DispatchWorkItem {
        let count = NSScreen.screens.count
        let added = count > screenCount
        screenCount = count
        if added { change() } else { runChild("--rescale") }
    }
    screenWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
}

app.run()
