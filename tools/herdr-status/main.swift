// herdr のエージェント状態を Cornix ドングルへ Raw HID で送る常駐プログラム。
// パケット仕様は zmk-dongle-screen の src/widgets/agent_status.c を参照。
//
//   swiftc -O -swift-version 5 -o herdr-status main.swift
//   ./herdr-status            # 常駐して 1 秒ごとに送信
//   ./herdr-status --print    # 送信せず、送る内容を 1 回だけ表示

import Foundation
import IOKit.hid

let vendorID = 0x1D50
let productID = 0x615E
let usagePage = 0xFF60
let usage = 0x61
let reportSize = 32

let rowCount = 4
let stateLength = 6
let nameLength = 23
let interval: TimeInterval = 1

enum Status: UInt8 {
    case none = 0, idle, working, blocked, done, unknown

    init(herdr: String) {
        switch herdr {
        case "idle": self = .idle
        case "working": self = .working
        case "blocked": self = .blocked
        case "done": self = .done
        default: self = .unknown
        }
    }

    var priority: Int {
        switch self {
        case .blocked: return 0
        case .done: return 1
        case .working: return 2
        case .idle: return 3
        default: return 4
        }
    }
}

struct Agent {
    let pane: String
    let status: Status
    let name: String
    var since = Date()
}

struct Row: Equatable {
    var status = Status.none
    var state = ""
    var name = ""
}

func herdrPath() -> String {
    if let path = ProcessInfo.processInfo.environment["HERDR_BIN"] {
        return path
    }
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let candidates = ["\(home)/.local/bin/herdr", "/opt/homebrew/bin/herdr", "/usr/local/bin/herdr"]
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "herdr"
}

// 取得に失敗したときは nil(0 件の [] と区別する)
func fetchAgents() -> [Agent]? {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [herdrPath(), "agent", "list"]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    guard (try? process.run()) != nil else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let result = json["result"] as? [String: Any],
        let agents = result["agents"] as? [[String: Any]]
    else { return nil }

    return agents.compactMap { agent in
        guard let pane = agent["pane_id"] as? String else { return nil }
        let cwd = agent["cwd"] as? String ?? ""
        let repo = URL(fileURLWithPath: cwd).lastPathComponent
        let branch = (agent["tokens"] as? [String: Any])?["branch"] as? String ?? ""
        let showBranch = !branch.isEmpty && branch != "main" && branch != "master"
        return Agent(
            pane: pane,
            status: Status(herdr: agent["agent_status"] as? String ?? ""),
            name: showBranch ? "\(repo.prefix(10)) \(branch)" : repo)
    }
}

func stateText(_ agent: Agent, now: Date) -> String {
    switch agent.status {
    case .blocked: return "BLOCK"
    case .done: return "done"
    case .idle: return "idle"
    case .working:
        let seconds = Int(now.timeIntervalSince(agent.since))
        let minutes = seconds / 60
        if minutes >= 60 { return String(format: "%dh%02d", minutes / 60, minutes % 60) }
        return minutes > 0 ? String(format: "%dm%02ds", minutes, seconds % 60) : "\(seconds)s"
    default: return "?"
    }
}

func packet(_ bytes: [UInt8]) -> [UInt8] {
    Array((bytes + [UInt8](repeating: 0, count: reportSize)).prefix(reportSize))
}

func rowPacket(index: Int, row: Row) -> [UInt8] {
    func field(_ text: String, _ length: Int) -> [UInt8] {
        let ascii = text.unicodeScalars.map { $0.isASCII ? UInt8($0.value) : UInt8(ascii: "?") }
        return Array((ascii + [UInt8](repeating: 0, count: length)).prefix(length))
    }
    return packet([0x01, UInt8(index), row.status.rawValue] + field(row.state, stateLength) + field(row.name, nameLength))
}

func metaPacket(count: Int, hidden: Int, wake: Bool) -> [UInt8] {
    packet([0x02, UInt8(min(count, 255)), UInt8(min(hidden, 255)), wake ? 1 : 0])
}

var tracked: [String: Agent] = [:]
var firstPoll = true

// 状態が変わっていない間は since を引き継ぎ、経過時間を出せるようにする
func poll() -> (rows: [Row], count: Int, hidden: Int, wake: Bool)? {
    let now = Date()
    var wake = false
    var next: [String: Agent] = [:]

    // 一時的な失敗で経過時間を失わないよう tracked は触らない
    guard let agents = fetchAgents() else { return nil }
    for var agent in agents {
        if let previous = tracked[agent.pane], previous.status == agent.status {
            agent.since = previous.since
        } else if agent.status == .blocked || agent.status == .done {
            wake = !firstPoll
        }
        next[agent.pane] = agent
    }
    tracked = next
    firstPoll = false

    let sorted = next.values.sorted {
        ($0.status.priority, $0.since, $0.pane) < ($1.status.priority, $1.since, $1.pane)
    }
    var rows = sorted.prefix(rowCount).map {
        Row(status: $0.status, state: stateText($0, now: now), name: $0.name)
    }
    rows += [Row](repeating: Row(), count: rowCount - rows.count)

    return (rows, sorted.count, max(0, sorted.count - rowCount), wake)
}

if CommandLine.arguments.contains("--print") {
    guard let result = poll() else {
        FileHandle.standardError.write("herdr agent list failed\n".data(using: .utf8)!)
        exit(1)
    }
    for row in result.rows where row.status != .none {
        print("\(row.status)".padding(toLength: 8, withPad: " ", startingAt: 0),
              row.name.padding(toLength: nameLength, withPad: " ", startingAt: 0), row.state)
    }
    print("count=\(result.count) hidden=\(result.hidden)")
    exit(0)
}

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(manager, [
    kIOHIDVendorIDKey: vendorID,
    kIOHIDProductIDKey: productID,
    kIOHIDDeviceUsagePageKey: usagePage,
    kIOHIDDeviceUsageKey: usage,
] as CFDictionary)
IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

let opened = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
if opened != kIOReturnSuccess {
    FileHandle.standardError.write("IOHIDManagerOpen failed: \(String(opened, radix: 16))\n".data(using: .utf8)!)
}

func send(_ packets: [[UInt8]]) {
    guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return }
    for device in devices {
        for bytes in packets {
            let status = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, bytes, bytes.count)
            if status != kIOReturnSuccess {
                FileHandle.standardError.write("send failed: \(String(status, radix: 16))\n".data(using: .utf8)!)
                break
            }
        }
    }
}

func tick() {
    // 送らなければドングル側が途絶を検知して offline 表示にする
    guard let result = poll() else { return }
    // META が行より先に届くと空の一覧が一瞬出るため、行を先に送る
    send(result.rows.enumerated().map { rowPacket(index: $0.offset, row: $0.element) }
        + [metaPacket(count: result.count, hidden: result.hidden, wake: result.wake)])
}

tick()
Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in tick() }
RunLoop.main.run()
