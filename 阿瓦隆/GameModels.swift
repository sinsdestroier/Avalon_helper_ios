import Foundation

// 基本陣營
enum Faction: String, Codable, CaseIterable, Sendable {
    case good
    case evil
}

// 支援的角色（可再擴充）
enum Role: String, Codable, CaseIterable, Sendable, Identifiable {
    case merlin, assassin, percival, morgana, mordred, oberon
    case loyalServant // 忠臣（泛用好人）
    case minion       // 爪牙（泛用壞人）

    var id: String { rawValue }

    var faction: Faction {
        switch self {
        case .merlin, .percival, .loyalServant:
            return .good
        case .assassin, .morgana, .mordred, .oberon, .minion:
            return .evil
        }
    }

    var displayName: String {
        switch self {
        case .merlin: return "梅林"
        case .assassin: return "刺客"
        case .percival: return "派西維爾"
        case .morgana: return "莫甘娜"
        case .mordred: return "莫德雷德"
        case .oberon: return "奧伯倫"
        case .loyalServant: return "忠臣"
        case .minion: return "爪牙"
        }
    }

    var summary: String {
        switch self {
        case .merlin:
            return "好人核心情報位。知道多數壞人，但看不到莫德雷德。"
        case .assassin:
            return "壞人刺殺位。好人三成後可刺殺梅林翻盤。"
        case .percival:
            return "好人情報位。看見梅林與莫甘娜兩人但無法分辨。"
        case .morgana:
            return "壞人干擾位。偽裝成梅林干擾派西維爾。"
        case .mordred:
            return "壞人隱匿位。梅林看不到你。"
        case .oberon:
            return "壞人孤立位。你看不到其他壞人，其他壞人也看不到你。"
        case .loyalServant:
            return "一般好人。任務中只能出成功。"
        case .minion:
            return "一般壞人。任務中可出成功或失敗。"
        }
    }
}

// 玩家
struct Player: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String
    var role: Role? = nil
}

// 投票顯示策略
enum VoteRevealStrategy: String, Codable, CaseIterable, Identifiable, Sendable {
    case resultOnly      // 只顯示是否通過
    case reviewLater     // 當下不顯示，回顧可看
    case showNow         // 當下即顯示每人投票

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .resultOnly: return "僅顯示是否通過"
        case .reviewLater: return "結束後回顧"
        case .showNow: return "即時顯示個別投票"
        }
    }
}

// 遊戲設定
struct GameSetup: Codable, Sendable {
    var playerCount: Int = 5
    var customEvilCount: Int? = nil // 若設定則覆蓋標準壞人數

    // 角色開關
    var includeMerlin = true
    var includeAssassin = true
    var includePercival = false
    var includeMorgana = false
    var includeMordred = false
    var includeOberon = false
    var includeGenericMinions = true

    // 規則開關
    var requireTwoFailsOnFourthAtSevenPlus = false // 7+ 人第 4 局需 2 張失敗
    var fiveRejectsEvilWins = false               // 5 次否決壞人勝利
    var clockwiseLeaderRotation = true           // 隊長輪替方向 true=順時針

    // 投票顯示策略
    var voteReveal: VoteRevealStrategy = .showNow

    // 標準壞人數
    static func standardEvilCount(for players: Int) -> Int {
        switch players {
        case 5, 6: return 2
        case 7, 8, 9: return 3
        case 10: return 4
        default: return max(2, Int((Double(players) * 0.4).rounded()))
        }
    }

    static func missionTeamSizes(for players: Int) -> [Int] {
        switch players {
        case 5: return [2, 3, 2, 3, 3]
        case 6: return [2, 3, 4, 3, 4]
        case 7: return [2, 3, 3, 4, 4]
        case 8, 9, 10: return [3, 4, 4, 5, 5]
        default: return [2, 3, 2, 3, 3]
        }
    }

    static func needsTwoFailsOnFourthRound(playerCount: Int, roundIndex: Int, ruleEnabled: Bool) -> Bool {
        ruleEnabled && playerCount >= 7 && roundIndex == 3
    }

    var evilCount: Int { customEvilCount ?? Self.standardEvilCount(for: playerCount) }
    var goodCount: Int { max(0, playerCount - evilCount) }

    var evilSpecialSelectedCount: Int {
        [includeAssassin, includeMorgana, includeMordred, includeOberon].filter { $0 }.count
    }

    var goodSpecialSelectedCount: Int {
        [includeMerlin, includePercival].filter { $0 }.count
    }

    var minionCount: Int {
        includeGenericMinions ? max(0, evilCount - evilSpecialSelectedCount) : 0
    }

    var loyalServantCount: Int {
        max(0, goodCount - goodSpecialSelectedCount)
    }

    // If Assassin is not included, assassination will be decided collectively by all evil
    var assassinationByCollective: Bool { !includeAssassin }

    // 基本檢查提醒
    func validationWarnings() -> [String] {
        var warnings: [String] = []

        if let custom = customEvilCount, custom != Self.standardEvilCount(for: playerCount) {
            warnings.append("壞人數量偏離標準配置：標準為 \(Self.standardEvilCount(for: playerCount)) 人")
        }
        if includeMerlin && !includeAssassin {
            warnings.append("使用梅林時，通常需要包含刺客以決定最終勝負")
        }
        if includeOberon {
            warnings.append("使用奧伯倫時，壞人互相資訊揭示需依奧伯倫規則處理")
        }
        if includeMorgana && !includePercival {
            warnings.append("使用莫甘娜時，建議加入派西維爾以平衡資訊")
        }
        if includeMordred && includeMerlin {
            warnings.append("使用莫德雷德時，梅林看不到莫德雷德")
        }
        if evilCount < 2 || evilCount >= playerCount {
            warnings.append("壞人數量不合理，請重新設定")
        }
        if !includeGenericMinions && evilSpecialSelectedCount < evilCount {
            warnings.append("目前壞人數不足，請增加壞人特殊或開啟爪牙補足")
        }
        if !includeAssassin {
            warnings.append("未包含刺客：刺殺階段將由全體壞人共同決定目標")
        }

        return warnings
    }
}
