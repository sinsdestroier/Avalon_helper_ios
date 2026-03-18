import Foundation
import Combine

final class GameSession: ObservableObject, Identifiable {
    let id = UUID()

    struct MissionRecord: Identifiable, Sendable {
        let id = UUID()
        let round: Int
        let team: [Int]
        let success: Bool
        let failCount: Int
        let requiresTwoFails: Bool
        let causedByRejectTrack: Bool
    }

    struct VoteRecord: Identifiable, Sendable {
        let id = UUID()
        let round: Int
        let leader: Int
        let team: [Int]
        let votes: [Int: Bool]
        let passed: Bool
        let vetoCountAfter: Int
    }

    enum Phase: Equatable {
        case nomination
        case voting(current: Int, votes: [Int: Bool])
        case votingResult(votes: [Int: Bool], passed: Bool)
        case mission(current: Int, submissions: [Int: Bool])
        case reveal(result: Bool, fails: Int)
        case assassination
        case gameOver(winner: Faction, reason: String)
    }

    let setup: GameSetup
    let playerCount: Int

    @Published var assignments: [Int: Role] = [:]
    @Published var roundIndex: Int = 0
    @Published var leaderIndex: Int = 0
    @Published var vetoCount: Int = 0
    @Published var goodWins: Int = 0
    @Published var evilWins: Int = 0
    @Published var selectedTeam: Set<Int> = []
    @Published var phase: Phase = .nomination
    @Published var missionRecords: [MissionRecord] = []
    @Published var voteRecords: [VoteRecord] = []
    @Published var isDebugFastMode = false

    init?(setup: GameSetup, playerCount: Int) {
        guard (5...10).contains(playerCount) else { return nil }
        self.setup = setup
        self.playerCount = playerCount
        self.assignments = Self.assignRoles(setup: setup, playerCount: playerCount)
        guard self.assignments.count == playerCount else { return nil }
        self.leaderIndex = Int.random(in: 0..<playerCount)
        self.phase = .nomination
    }

    var missionSizes: [Int] {
        GameSetup.missionTeamSizes(for: playerCount)
    }

    var currentTeamSize: Int { missionSizes[roundIndex] }

    var currentTeamSorted: [Int] { selectedTeam.sorted() }

    var currentRoundNeedsTwoFails: Bool {
        GameSetup.needsTwoFailsOnFourthRound(
            playerCount: playerCount,
            roundIndex: roundIndex,
            ruleEnabled: setup.requireTwoFailsOnFourthAtSevenPlus
        )
    }

    var missionTrack: [Bool?] {
        var track = Array<Bool?>(repeating: nil, count: missionSizes.count)
        for record in missionRecords where record.round < track.count {
            track[record.round] = record.success
        }
        return track
    }

    var currentVoteTrack: [Bool] {
        Array(repeating: true, count: vetoCount)
    }

    var shouldRevealVotesImmediately: Bool {
        setup.voteReveal == .showNow
    }

    var shouldShowVotesInReview: Bool {
        setup.voteReveal == .showNow || setup.voteReveal == .reviewLater
    }

    func nextLeaderIndex() -> Int {
        setup.clockwiseLeaderRotation
            ? (leaderIndex + 1) % playerCount
            : (leaderIndex - 1 + playerCount) % playerCount
    }

    func role(for seat: Int) -> Role {
        assignments[seat] ?? .loyalServant
    }

    func isSeatOnCurrentMission(_ seat: Int) -> Bool {
        selectedTeam.contains(seat)
    }

    // MARK: - Nomination

    func toggleSeatInTeam(_ seat: Int) {
        guard case .nomination = phase else { return }

        if selectedTeam.contains(seat) {
            selectedTeam.remove(seat)
            return
        }

        if selectedTeam.count < currentTeamSize {
            selectedTeam.insert(seat)
        }
    }

    func clearTeamSelection() {
        selectedTeam.removeAll()
    }

    func confirmNomination() {
        guard case .nomination = phase else { return }
        guard selectedTeam.count == currentTeamSize else { return }
        phase = .voting(current: 0, votes: [:])
    }

    func startDebugVotingPhase() {
        isDebugFastMode = true
        let team = Array(0..<min(currentTeamSize, playerCount))
        selectedTeam = Set(team)
        phase = .voting(current: 0, votes: [:])
    }

    func enableDebugFastMode() {
        isDebugFastMode = true
    }

    func loadDebugBoardPreview() {
        isDebugFastMode = true
        roundIndex = 4
        leaderIndex = 0
        vetoCount = 4
        goodWins = 2
        evilWins = 2
        selectedTeam = []
        voteRecords = [
            VoteRecord(round: 0, leader: 0, team: [0, 1], votes: [0: true, 1: true, 2: false, 3: true, 4: true], passed: true, vetoCountAfter: 0),
            VoteRecord(round: 1, leader: 1, team: [0, 2, 3], votes: [0: false, 1: true, 2: false, 3: true, 4: false], passed: false, vetoCountAfter: 1),
            VoteRecord(round: 1, leader: 2, team: [1, 2, 4], votes: [0: true, 1: true, 2: true, 3: false, 4: true], passed: true, vetoCountAfter: 0),
            VoteRecord(round: 2, leader: 3, team: [0, 1], votes: [0: false, 1: false, 2: true, 3: false, 4: true], passed: false, vetoCountAfter: 1),
            VoteRecord(round: 3, leader: 4, team: [1, 2, 3], votes: [0: true, 1: true, 2: false, 3: true, 4: false], passed: true, vetoCountAfter: 0),
            VoteRecord(round: 4, leader: 0, team: [0, 1, 2], votes: [0: false, 1: false, 2: true, 3: false, 4: true], passed: false, vetoCountAfter: 4)
        ]
        missionRecords = [
            MissionRecord(round: 0, team: [0, 1], success: true, failCount: 0, requiresTwoFails: false, causedByRejectTrack: false),
            MissionRecord(round: 1, team: [0, 2, 3], success: false, failCount: 1, requiresTwoFails: false, causedByRejectTrack: false),
            MissionRecord(round: 2, team: [0, 1], success: false, failCount: 1, requiresTwoFails: false, causedByRejectTrack: false),
            MissionRecord(round: 3, team: [1, 2, 3], success: true, failCount: 0, requiresTwoFails: false, causedByRejectTrack: false)
        ]
        phase = .nomination
    }

    // MARK: - Voting

    func recordCurrentVote(agree: Bool) {
        guard case let .voting(current, votes) = phase else { return }

        var newVotes = votes
        newVotes[current] = agree

        if current + 1 < playerCount {
            phase = .voting(current: current + 1, votes: newVotes)
        } else {
            tallyVotes(newVotes)
        }
    }

    func finishVotingResult() {
        guard case let .votingResult(_, passed) = phase else { return }

        if passed {
            let team = currentTeamSorted
            guard let firstSeat = team.first else { return }
            phase = .mission(current: firstSeat, submissions: [:])
            return
        }

        if setup.fiveRejectsEvilWins && vetoCount >= 5 {
            applyAutoMissionFailureFromRejects()
            return
        }

        leaderIndex = nextLeaderIndex()
        clearTeamSelection()
        phase = .nomination
    }

    // MARK: - Mission

    func submitMissionCard(success: Bool) {
        guard case let .mission(current, submissions) = phase else { return }
        guard selectedTeam.contains(current) else { return }

        var newSubmissions = submissions
        let currentRole = role(for: current)
        let isFail = currentRole.faction == .evil ? !success : false
        newSubmissions[current] = isFail

        let team = currentTeamSorted
        if newSubmissions.count < team.count,
           let currentIndex = team.firstIndex(of: current),
           currentIndex + 1 < team.count {
            phase = .mission(current: team[currentIndex + 1], submissions: newSubmissions)
            return
        }

        tallyMission(newSubmissions)
    }

    func finishReveal() {
        guard case .reveal = phase else { return }

        if goodWins >= 3 {
            phase = .assassination
            return
        }

        if evilWins >= 3 {
            phase = .gameOver(winner: .evil, reason: "壞人先達成 3 次任務失敗")
            return
        }

        if roundIndex + 1 >= missionSizes.count {
            let winner: Faction = goodWins > evilWins ? .good : .evil
            let reason = winner == .good ? "五局結束，好人分數較高" : "五局結束，壞人分數較高"
            phase = .gameOver(winner: winner, reason: reason)
            return
        }

        roundIndex += 1
        leaderIndex = nextLeaderIndex()
        clearTeamSelection()
        phase = .nomination
    }

    // MARK: - Assassination / Reset

    func assassinate(target seat: Int) {
        if role(for: seat) == .merlin {
            phase = .gameOver(winner: .evil, reason: "刺殺梅林成功")
        } else {
            phase = .gameOver(winner: .good, reason: "刺殺失敗，好人守住勝利")
        }
    }

    func restartKeepingRoles() {
        roundIndex = 0
        vetoCount = 0
        goodWins = 0
        evilWins = 0
        selectedTeam.removeAll()
        missionRecords = []
        voteRecords = []
        leaderIndex = Int.random(in: 0..<playerCount)
        phase = .nomination
    }

    func restartWithReshuffle() {
        assignments = Self.assignRoles(setup: setup, playerCount: playerCount)
        restartKeepingRoles()
    }

    func resetToNominationStage() {
        guard case .gameOver = phase else {
            selectedTeam.removeAll()
            phase = .nomination
            return
        }
    }

    // MARK: - Internals

    private func tallyVotes(_ votes: [Int: Bool]) {
        let agrees = votes.values.filter { $0 }.count
        let passed = agrees > playerCount / 2
        vetoCount = passed ? 0 : (vetoCount + 1)

        voteRecords.append(
            VoteRecord(
                round: roundIndex,
                leader: leaderIndex,
                team: currentTeamSorted,
                votes: votes,
                passed: passed,
                vetoCountAfter: vetoCount
            )
        )

        phase = .votingResult(votes: votes, passed: passed)
    }

    private func tallyMission(_ submissions: [Int: Bool]) {
        let fails = submissions.values.filter { $0 }.count
        let requiresTwoFails = currentRoundNeedsTwoFails
        let success = requiresTwoFails ? fails < 2 : fails == 0

        if success {
            goodWins += 1
        } else {
            evilWins += 1
        }

        missionRecords.append(
            MissionRecord(
                round: roundIndex,
                team: currentTeamSorted,
                success: success,
                failCount: fails,
                requiresTwoFails: requiresTwoFails,
                causedByRejectTrack: false
            )
        )

        phase = .reveal(result: success, fails: fails)
    }

    private func applyAutoMissionFailureFromRejects() {
        missionRecords.append(
            MissionRecord(
                round: roundIndex,
                team: [],
                success: false,
                failCount: 1,
                requiresTwoFails: currentRoundNeedsTwoFails,
                causedByRejectTrack: true
            )
        )

        evilWins += 1
        vetoCount = 0
        phase = .reveal(result: false, fails: 1)
    }

    private static func assignRoles(setup: GameSetup, playerCount: Int) -> [Int: Role] {
        var roles: [Role] = []

        var evilSpecials: [Role] = []
        if setup.includeAssassin { evilSpecials.append(.assassin) }
        if setup.includeMorgana { evilSpecials.append(.morgana) }
        if setup.includeMordred { evilSpecials.append(.mordred) }
        if setup.includeOberon { evilSpecials.append(.oberon) }
        let evilSlots = max(0, setup.evilCount - evilSpecials.count)
        roles.append(contentsOf: evilSpecials)
        roles.append(contentsOf: Array(repeating: .minion, count: evilSlots))

        var goodSpecials: [Role] = []
        if setup.includeMerlin { goodSpecials.append(.merlin) }
        if setup.includePercival { goodSpecials.append(.percival) }
        let goodSlots = max(0, setup.goodCount - goodSpecials.count)
        roles.append(contentsOf: goodSpecials)
        roles.append(contentsOf: Array(repeating: .loyalServant, count: goodSlots))

        if roles.count < playerCount {
            roles.append(contentsOf: Array(repeating: .loyalServant, count: playerCount - roles.count))
        } else if roles.count > playerCount {
            roles = Array(roles.prefix(playerCount))
        }

        roles.shuffle()
        var result: [Int: Role] = [:]
        for index in 0..<playerCount {
            result[index] = roles[index]
        }
        return result
    }
}
