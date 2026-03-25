import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct RoundFlowView: View {
    @Environment(AppSettings.self) private var appSettings
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss

    private enum ReviewSection: String {
        case mission = "任務紀錄"
        case vote = "投票紀錄"
    }

    private struct BoardOverlayLayout {
        let missionCenters: [CGPoint]
        let missionIconScale: CGFloat
        let voteCenters: [CGPoint]
        let voteIconScale: CGFloat

        static let standard = BoardOverlayLayout(
            missionCenters: [
                CGPoint(x: 0.110294, y: 0.455394),
                CGPoint(x: 0.305481, y: 0.455913),
                CGPoint(x: 0.498663, y: 0.454357),
                CGPoint(x: 0.689505, y: 0.454357),
                CGPoint(x: 0.876003, y: 0.455913)
            ],
            missionIconScale: 0.26,
            voteCenters: [
                CGPoint(x: 0.111096, y: 0.660071),
                CGPoint(x: 0.268980, y: 0.660071),
                CGPoint(x: 0.426864, y: 0.660071),
                CGPoint(x: 0.584748, y: 0.660071),
                CGPoint(x: 0.742632, y: 0.660071)
            ],
            voteIconScale: 0.135
        )

        static let fivePlayers = BoardOverlayLayout(
            missionCenters: [
                CGPoint(x: 0.1108, y: 0.4590),
                CGPoint(x: 0.3047, y: 0.4590),
                CGPoint(x: 0.5019, y: 0.4590),
                CGPoint(x: 0.6914, y: 0.4590),
                CGPoint(x: 0.8808, y: 0.4590)
            ],
            missionIconScale: 0.185,

            voteCenters: [
                CGPoint(x: 0.0939, y: 0.8667),
                CGPoint(x: 0.2493, y: 0.8667),
                CGPoint(x: 0.4047, y: 0.8667),
                CGPoint(x: 0.5600, y: 0.8667),
                CGPoint(x: 0.7154, y: 0.8667)
            ],
            voteIconScale: 0.135
        )
    }

    private enum DangerAction {
        case resetGame
        case reshuffleRoles

        var title: String {
            switch self {
            case .resetGame: return "重開本局"
            case .reshuffleRoles: return "重抽身份"
            }
        }

        var confirmMessage: String {
            switch self {
            case .resetGame: return "將清除目前局數進度與記錄，並保留目前身份重新開始。"
            case .reshuffleRoles: return "將重抽所有身份並清除全部進度重新開始。"
            }
        }
    }

    private struct MissionMemeOverlay: Equatable {
        let imageName: String
        let title: String
        let soundEffect: SoundEffect
        let holdAfterSound: TimeInterval
    }

    private enum AssassinationCinematicStage: Equatable {
        case suspense
        case result(wasSuccessful: Bool)
    }

    private struct AssassinationCinematicState: Equatable {
        let targetSeat: Int
        let wasSuccessful: Bool
        let stage: AssassinationCinematicStage
    }

    private struct EvilVictoryCinematicState: Equatable {
        let imageName: String
        let title: String
        let soundEffect: SoundEffect
        let holdAfterSound: TimeInterval
    }

    @State private var showConfirmNomination = false
    @State private var showConfirmMissionChoice = false
    @State private var pendingMissionSuccess = true
    @State private var showSentAnimation = false
    @State private var selectedAssassinationTarget = 0
    @State private var showConfirmAssassination = false
    @State private var showDebugRoles = false
    @State private var showMissionSizeTable = false
    @State private var showReviewSheet = false
    @State private var selectedReviewSection: ReviewSection?
    @State private var showIdentityReviewSheet = false
    @State private var selectedIdentityReviewSeat = 0
    @State private var isBottomPanelMinimized = false
    @State private var isPhasePanelMinimized = false
    @State private var showsCalibrationOverlay = false
    @State private var missionCalibrationCenters: [CGPoint] = []
    @State private var voteCalibrationCenters: [CGPoint] = []
    @State private var selectedCalibrationMarkerID: String?

    @State private var showDangerStepOne = false
    @State private var showDangerStepTwo = false
    @State private var pendingDangerAction: DangerAction?
    @State private var activeMissionMemeOverlay: MissionMemeOverlay?
    @State private var missionMemeOverlaySequence = 0
    @State private var assassinationCinematic: AssassinationCinematicState?
    @State private var assassinationCinematicSequence = 0
    @State private var beastJumpOffset: CGFloat = 0
    @State private var beastShakeOffset: CGFloat = 0
    @State private var evilVictoryCinematic: EvilVictoryCinematicState?
    @State private var evilVictoryCinematicSequence = 0
    @State private var evilVictoryRotation: Double = 0
    @State private var evilVictoryScale: CGFloat = 0.7

    var body: some View {
        GeometryReader { geo in
            let boardFrame = boardFrame(in: geo)

            ZStack {
                Color(.systemBackground)

                Image(boardImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: boardFrame.width, height: boardFrame.height)
                    .clipped()
                    .position(x: boardFrame.midX, y: boardFrame.midY)

                missionOutcomeOverlay(boardFrame: boardFrame)
                voteShieldOverlay(boardFrame: boardFrame)
#if DEBUG
                if showsCalibrationOverlay {
                    calibrationOverlay(boardFrame: boardFrame)
                }
#endif

                overlayHUD(geo: geo)

                if let activeMissionMemeOverlay {
                    missionMemeOverlay(activeMissionMemeOverlay)
                        .transition(.opacity)
                        .zIndex(10)
                }

                if let assassinationCinematic {
                    assassinationCinematicOverlay(for: assassinationCinematic)
                        .transition(.opacity)
                        .zIndex(11)
                }

                if let evilVictoryCinematic {
                    evilVictoryCinematicOverlay(for: evilVictoryCinematic)
                        .transition(.opacity)
                        .zIndex(12)
                }

                if isBottomPanelMinimized {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    isBottomPanelMinimized = false
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.headline.bold())
                                    .frame(width: 42, height: 42)
                                    .background(.thinMaterial, in: Circle())
                            }
                            .padding(.trailing, 18)
                            .padding(.bottom, 18)
                        }
                    }
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            SoundEffectPlayer.shared.stop(.setupOpen)
            setLandscape(true)
            resetCalibrationCenters()
        }
        .onDisappear {
            setLandscape(false)
            dismissMissionMemeOverlay()
            dismissAssassinationCinematic(commitResult: false)
            dismissEvilVictoryCinematic(commitResult: false)
        }
        .onChange(of: session.playerCount) { _, _ in
            resetCalibrationCenters()
        }
        .alert("目前身份（除錯）", isPresented: $showDebugRoles) {
            Button("關閉", role: .cancel) {}
        } message: {
            Text(debugRoleSummary)
        }
        .alert("任務人數表", isPresented: $showMissionSizeTable) {
            Button("關閉", role: .cancel) {}
        } message: {
            Text((5...10).map { players in
                "\(players) 人：\(GameSetup.missionTeamSizes(for: players).map(String.init).joined(separator: " / "))"
            }.joined(separator: "\n"))
        }
        .sheet(isPresented: $showReviewSheet) {
            NavigationStack {
                reviewSheetContent
                    .padding()
                    .toolbar {
                        if selectedReviewSection != nil {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("返回") {
                                    selectedReviewSection = nil
                                }
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("關閉") {
                                showReviewSheet = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showIdentityReviewSheet) {
            NavigationStack {
                identityReviewSheetContent
                    .padding()
                    .navigationTitle("重看身份")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("關閉") {
                                showIdentityReviewSheet = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .alert("高風險操作", isPresented: $showDangerStepOne, presenting: pendingDangerAction) { action in
            Button("確定執行", role: .destructive) {
                performDangerAction(action)
                pendingDangerAction = nil
            }
            Button("不執行", role: .cancel) {
                pendingDangerAction = nil
            }
        } message: { action in
            Text(action.confirmMessage)
        }
        .onChange(of: phaseMinimizeResetKey) { _, _ in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                isPhasePanelMinimized = false
            }
            presentMissionMemeIfNeeded()
        }
    }

    // MARK: - Overlay HUD

    @ViewBuilder
    private func missionOutcomeOverlay(boardFrame: CGRect) -> some View {
        let points = overlayPoints(from: overlayLayout.missionCenters, in: boardFrame)
        let iconSize = boardFrame.width * overlayLayout.missionIconScale

        ZStack {
            ForEach(Array(session.missionTrack.enumerated()), id: \.offset) { index, result in
                if let result, index < points.count {
                    missionCircle(isSuccess: result, at: points[index], size: iconSize)
                }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func voteShieldOverlay(boardFrame: CGRect) -> some View {
        let points = overlayPoints(from: overlayLayout.voteCenters, in: boardFrame)
        let iconSize = boardFrame.width * overlayLayout.voteIconScale

        ZStack {
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                if index < session.vetoCount {
                    Image("shield")
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        .position(point)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func boardFrame(in geo: GeometryProxy) -> CGRect {
        let canvasWidth = geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing
        let canvasHeight = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
        let maxWidth = canvasWidth * 0.94
        let maxHeight = canvasHeight * 0.84
        let aspectRatio = boardImageAspectRatio
        let width = min(maxWidth, maxHeight * aspectRatio)
        let height = width / aspectRatio
        return CGRect(
            x: ((canvasWidth - width) / 2) - geo.safeAreaInsets.leading,
            y: ((canvasHeight - height) / 2) - geo.safeAreaInsets.top,
            width: width,
            height: height
        )
    }

    private func missionCircle(isSuccess: Bool, at point: CGPoint, size: CGFloat) -> some View {
        Image(isSuccess ? "success" : "fail")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
            .position(point)
    }

    private func normalizedPoint(in rect: CGRect, normalizedX: CGFloat, normalizedY: CGFloat) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * normalizedX,
            y: rect.minY + rect.height * normalizedY
        )    }

    private func overlayPoints(from normalizedCenters: [CGPoint], in rect: CGRect) -> [CGPoint] {
        normalizedCenters.map { normalizedPoint(in: rect, normalizedX: $0.x, normalizedY: $0.y) }
    }

#if DEBUG
    @ViewBuilder
    private func calibrationOverlay(boardFrame: CGRect) -> some View {
        let missionSize = boardFrame.width * overlayLayout.missionIconScale
        let voteSize = boardFrame.width * overlayLayout.voteIconScale

        ZStack {
            ForEach(nonSelectedMissionMarkers, id: \.offset) { index, center in
                CalibrationMarker(
                    title: "M\(index + 1)",
                    normalizedCenter: center,
                    size: missionSize,
                    color: .red,
                    boardFrame: boardFrame,
                    isSelected: selectedCalibrationMarkerID == missionMarkerID(for: index),
                    onSelect: {
                        selectedCalibrationMarkerID = missionMarkerID(for: index)
                    }
                ) { point in
                    updateMissionCalibrationCenter(at: index, to: point)
                }
            }

            ForEach(nonSelectedVoteMarkers, id: \.offset) { index, center in
                CalibrationMarker(
                    title: "V\(index + 1)",
                    normalizedCenter: center,
                    size: voteSize,
                    color: .orange,
                    boardFrame: boardFrame,
                    isSelected: selectedCalibrationMarkerID == voteMarkerID(for: index),
                    onSelect: {
                        selectedCalibrationMarkerID = voteMarkerID(for: index)
                    }
                ) { point in
                    updateVoteCalibrationCenter(at: index, to: point)
                }
            }

            if let selectedMissionMarker {
                CalibrationMarker(
                    title: "M\(selectedMissionMarker.index + 1)",
                    normalizedCenter: selectedMissionMarker.center,
                    size: missionSize,
                    color: .red,
                    boardFrame: boardFrame,
                    isSelected: true,
                    onSelect: {
                        selectedCalibrationMarkerID = missionMarkerID(for: selectedMissionMarker.index)
                    }
                ) { point in
                    updateMissionCalibrationCenter(at: selectedMissionMarker.index, to: point)
                }
                .zIndex(1)
            }

            if let selectedVoteMarker {
                CalibrationMarker(
                    title: "V\(selectedVoteMarker.index + 1)",
                    normalizedCenter: selectedVoteMarker.center,
                    size: voteSize,
                    color: .orange,
                    boardFrame: boardFrame,
                    isSelected: true,
                    onSelect: {
                        selectedCalibrationMarkerID = voteMarkerID(for: selectedVoteMarker.index)
                    }
                ) { point in
                    updateVoteCalibrationCenter(at: selectedVoteMarker.index, to: point)
                }
                .zIndex(1)
            }
        }
    }
#endif

    @ViewBuilder
    private func overlayHUD(geo: GeometryProxy) -> some View {
        VStack(spacing: 12) {
            topStatusRow
            missionTrackRow

            Spacer(minLength: 4)

            if !isPhasePanelMinimized {
                phasePanelContainer
                    .frame(maxWidth: min(geo.size.width * 0.62, 760))
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
            }

            Spacer(minLength: 4)

            if !isBottomPanelMinimized {
                bottomTeamPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, geo.safeAreaInsets.top + 8)
        .padding(.bottom, 10)
        .overlay {
            if showSentAnimation {
                SentOverlay().transition(.opacity)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if isPhasePanelMinimized {
                minimizedPhasePanelButton
                    .padding(.trailing, 10)
                    .padding(.bottom, minimizedPhaseButtonBottomPadding(in: geo))
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: isPhasePanelMinimized)
        .animation(.easeInOut(duration: 0.2), value: showSentAnimation)
    }

    private func missionMemeOverlay(_ overlay: MissionMemeOverlay) -> some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(overlay.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 340, maxHeight: 340)
                    .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)

                Text(overlay.title)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)

                Text("點一下可跳過")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(28)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissMissionMemeOverlay()
        }
    }

    private func assassinationCinematicOverlay(for state: AssassinationCinematicState) -> some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 20) {
                    assassinationImage(for: state)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 360, maxHeight: 360)
                        .offset(x: state.stage == .result(wasSuccessful: true) ? beastShakeOffset : 0,
                                y: state.stage == .result(wasSuccessful: true) ? beastJumpOffset : 0)
                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 12)

                    Text(assassinationTitle(for: state))
                        .font(.system(size: 30, weight: .heavy))
                        .foregroundStyle(.white)

                    Text(assassinationSubtitle(for: state))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }
                .id(assassinationStageID(for: state))
                .transition(.opacity)
            }
            .padding(28)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleAssassinationCinematicTap()
        }
        .animation(.easeInOut(duration: 0.35), value: assassinationStageID(for: state))
    }

    private func evilVictoryCinematicOverlay(for state: EvilVictoryCinematicState) -> some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(state.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 340, maxHeight: 340)
                    .rotationEffect(.degrees(evilVictoryRotation))
                    .scaleEffect(evilVictoryScale)
                    .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 12)

                Text(state.title)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)

                Text("點一下進入真正的結果公布")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(28)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissEvilVictoryCinematic(commitResult: true)
        }
    }

    private var topStatusRow: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    StatusPill(systemName: "flag.fill", text: "第 \(session.roundIndex + 1) 局")
                    StatusPill(systemName: "person.fill", text: "隊長：\(session.leaderIndex + 1) 號")
                    StatusPill(systemName: "arrow.right.circle.fill", text: "下一位：\(session.nextLeaderIndex() + 1) 號")
                    StatusPill(systemName: "person.3.fill", text: "本局需 \(session.currentTeamSize) 人")
                    if session.currentRoundNeedsTwoFails {
                        StatusPill(systemName: "2.circle.fill", text: "本局需 2 失敗")
                    }
                    StatusPill(systemName: "xmark.circle.fill", text: "否決 \(session.vetoCount)/5")
                    StatusPill(systemName: "chart.bar.fill", text: "好 \(session.goodWins) : 壞 \(session.evilWins)")
                }
                .padding(.horizontal, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("任務表") {
                        showMissionSizeTable = true
                    }
                    .buttonStyle(.bordered)

                    Button("回顧") {
                        selectedReviewSection = nil
                        showReviewSheet = true
                    }
                    .buttonStyle(.bordered)

                    Button("重看身份") {
                        selectedIdentityReviewSeat = 0
                        showIdentityReviewSheet = true
                    }
                    .buttonStyle(.bordered)

                    Button("重開本局") {
                        requestDangerAction(.resetGame)
                    }
                    .buttonStyle(.bordered)

                    Button("重抽身份") {
                        requestDangerAction(.reshuffleRoles)
                    }
                    .buttonStyle(.bordered)

                    Button("回到首頁") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

#if DEBUG
                    Button("查看身份") {
                        showDebugRoles = true
                    }
                    .buttonStyle(.bordered)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 1.5).onEnded { _ in
                            showsCalibrationOverlay.toggle()
                            if showsCalibrationOverlay {
                                resetCalibrationCenters()
                            }
                        }
                    )

                    if showsCalibrationOverlay {
                        Button("重設校正") {
                            resetCalibrationCenters()
                        }
                        .buttonStyle(.bordered)
                    }
#endif
                }
                .padding(.horizontal, 2)
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var missionTrackRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(session.missionTrack.enumerated()), id: \.offset) { idx, result in
                VStack(spacing: 4) {
                    Circle()
                        .fill(nodeColor(for: idx, result: result))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Image(systemName: nodeIcon(for: result))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                        )
                        .overlay(
                            Circle().stroke(idx == session.roundIndex ? Color.yellow : .clear, lineWidth: 3)
                        )
                    Text("R\(idx + 1)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var phasePanel: some View {
        switch session.phase {
        case .nomination:
            nominationPanel
        case .voting(let current, let votes):
            votingPanel(current: current, votes: votes)
        case .votingResult(let votes, let passed):
            votingResultPanel(votes: votes, passed: passed)
        case .mission(let current, let submissions):
            missionPanel(current: current, submissions: submissions)
        case .reveal(let success, let fails):
            revealPanel(success: success, fails: fails)
        case .assassination:
            assassinationPanel
        case .gameOver(let winner, let reason):
            gameOverPanel(winner: winner, reason: reason)
        }
    }

    private var phasePanelContainer: some View {
        phasePanel
            .overlay(alignment: .topTrailing) {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        isPhasePanelMinimized = true
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.bold())
                        .frame(width: 24, height: 24)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(10)
            }
    }

    private var minimizedPhasePanelButton: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                isPhasePanelMinimized = false
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "rectangle.expand.vertical")
                    .font(.headline.bold())
                Text(phasePanelTitle)
                    .font(.caption2.bold())
            }
            .foregroundStyle(.primary)
            .frame(width: 62, height: 62)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var bottomTeamPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("本局隊伍：\(session.currentTeamSorted.map { "\($0 + 1)" }.joined(separator: "、"))")
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                        isBottomPanelMinimized = true
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.bold())
                        .frame(width: 24, height: 24)
                        .background(.ultraThinMaterial, in: Circle())
                }
                Spacer()
                Text("\(session.selectedTeam.count)/\(session.currentTeamSize)")
                    .font(.subheadline.bold())
            }
            .font(.subheadline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(0..<session.playerCount, id: \.self) { seat in
                    SeatChip(
                        number: seat + 1,
                        selected: session.selectedTeam.contains(seat),
                        enabled: isSeatSelectableInCurrentPhase(seat)
                    ) {
                        session.toggleSeatInTeam(seat)
                    }
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Phase Panels

    private var nominationPanel: some View {
        VStack(spacing: 10) {
            Text("提名階段").font(.title3.bold())
            Text("隊長是 \(session.leaderIndex + 1) 號\n請選擇 \(session.currentTeamSize) 位成員（\(session.selectedTeam.count)/\(session.currentTeamSize)）")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Button("清除重選") {
                    playRoundClick()
                    session.clearTeamSelection()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("確認送出隊伍") {
                    playRoundClick()
                    confirmNominationIfNeeded()
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.selectedTeam.count != session.currentTeamSize)
                .confirmationDialog("送出隊伍？", isPresented: nominationConfirmationBinding) {
                    Button("確認送出") { session.confirmNomination() }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("隊伍：\(session.currentTeamSorted.map { "\($0 + 1) 號" }.joined(separator: "、"))")
                }
            }
        }
        .panelStyle()
    }

    private func votingPanel(current: Int, votes: [Int: Bool]) -> some View {
        VStack(spacing: 12) {
            Text("投票階段").font(.title3.bold())
            Text("請把手機交給：玩家 \(current + 1) 號投票")
                .font(.headline)
            Text("已投：\(votes.count)/\(session.playerCount)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("同意") {
                    playRoundClick()
                    session.recordCurrentVote(agree: true)
                }
                .buttonStyle(.borderedProminent)

                Button("反對") {
                    playRoundClick()
                    session.recordCurrentVote(agree: false)
                }
                .buttonStyle(.bordered)
            }
        }
        .panelStyle()
    }

    private func votingResultPanel(votes: [Int: Bool], passed: Bool) -> some View {
        VStack(spacing: 10) {
            Text("投票結果").font(.title3.bold())

            if session.shouldRevealVotesImmediately {
                voteDetailRow(votes: votes)
            } else if session.setup.voteReveal == .reviewLater {
                Text("當下隱藏個人投票，結束後回顧可查看")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("本局僅顯示是否通過")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(passed ? "提名通過，進入任務" : "提名被否決")
                .font(.headline)
                .foregroundStyle(passed ? .green : .red)

            Button(passed ? "開始任務出牌" : "下一輪提名") {
                playRoundClick()
                session.finishVotingResult()
            }
            .buttonStyle(.borderedProminent)
        }
        .panelStyle()
    }

    private func voteDetailRow(votes: [Int: Bool]) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<session.playerCount, id: \.self) { seat in
                let agree = votes[seat] ?? false
                VStack(spacing: 3) {
                    Text("\(seat + 1)")
                        .font(.caption.bold())
                    Text(agree ? "同" : "反")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(agree ? .green : .red, in: Capsule())
                }
            }
        }
    }

    private func missionPanel(current: Int, submissions: [Int: Bool]) -> some View {
        let role = session.role(for: current)
        let isEvil = role.faction == .evil

        return VStack(spacing: 12) {
            Text("任務出牌").font(.title3.bold())
            Text("請把手機交給：玩家 \(current + 1) 號")
                .font(.headline)
            Text("已收到 \(submissions.count)/\(session.currentTeamSize) 張任務牌")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("成功") {
                    playRoundClick()
                    handleMissionChoice(success: true)
                }
                .buttonStyle(.borderedProminent)

                Button("失敗") {
                    playRoundClick()
                    handleMissionChoice(success: false)
                }
                .buttonStyle(.bordered)
                .disabled(!isEvil)
                .opacity(isEvil ? 1.0 : 0.45)
            }
            .confirmationDialog("確認本次出牌？", isPresented: $showConfirmMissionChoice) {
                Button(pendingMissionSuccess ? "確認成功" : "確認失敗") {
                    playRoundClick()
                    session.submitMissionCard(success: pendingMissionSuccess)
                    triggerSentAnimation()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("你將送出：\(pendingMissionSuccess ? "成功" : "失敗")")
            }
        }
        .panelStyle()
    }

    private func revealPanel(success: Bool, fails: Int) -> some View {
        let latestRecord = session.missionRecords.last

        return VStack(spacing: 10) {
            Text("任務公布").font(.title3.bold())
            Text(success ? "任務成功" : "任務失敗")
                .font(.headline)
                .foregroundStyle(success ? .green : .red)
            Text("失敗張數：\(fails)")
                .font(.subheadline)

            if latestRecord?.causedByRejectTrack == true {
                Text("本局因累積 5 次否決，直接判定任務失敗")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if session.currentRoundNeedsTwoFails {
                Text("本局套用「第 4 局需 2 失敗」規則")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if session.goodWins >= 3 {
                Text("好人達成 3 次成功，進入刺殺階段")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(revealAdvanceButtonTitle) {
                playRoundClick()
                handleRevealAdvance()
            }
            .buttonStyle(.borderedProminent)
        }
        .panelStyle()
    }

    private var assassinationPanel: some View {
        VStack(spacing: 12) {
            Text("刺殺階段").font(.title3.bold())

            if session.setup.includeAssassin {
                Text("請交給刺客選擇刺殺目標")
                    .font(.headline)
            } else {
                Text("未包含刺客，請由全體壞人共同決定目標")
                    .font(.headline)
            }

            Picker("目標座位", selection: $selectedAssassinationTarget) {
                ForEach(0..<session.playerCount, id: \.self) { seat in
                    Text("玩家 \(seat + 1) 號").tag(seat)
                }
            }
            .pickerStyle(.menu)

            Button("確認刺殺") {
                playRoundClick()
                confirmAssassinationIfNeeded()
            }
            .buttonStyle(.borderedProminent)
            .alert("確認刺殺目標？", isPresented: $showConfirmAssassination) {
                Button("刺殺玩家 \(selectedAssassinationTarget + 1) 號") {
                    playRoundClick()
                    startAssassinationCinematic()
                }
                Button("取消", role: .cancel) {}
            }
        }
        .panelStyle()
    }

    private func gameOverPanel(winner: Faction, reason: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("遊戲結束：\(winner == .good ? "好人勝利" : "壞人勝利")")
                .font(.title3.bold())
                .foregroundStyle(winner == .good ? .blue : .red)
            Text(reason).font(.subheadline)

            Divider()
            gameOverReviewPanel
                .frame(maxHeight: 190)

            Divider()
            Text("身份揭示").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(0..<session.playerCount, id: \.self) { seat in
                    VStack(spacing: 2) {
                        Text("\(seat + 1) 號").font(.caption2.bold())
                        Text(session.role(for: seat).displayName)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack {
                Button("再來一局\n（重洗身份）") {
                    playRoundClick()
                    session.restartWithReshuffle()
                }
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 68)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)

                Button("回到首頁") {
                    playRoundClick()
                    dismiss()
                }
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 68)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .font(.headline)
            .foregroundStyle(.primary)
        }
        .panelStyle()
    }

    @ViewBuilder
    private var reviewSheetContent: some View {
        if let selectedReviewSection {
            Group {
                switch selectedReviewSection {
                case .mission:
                    missionReviewPanel
                case .vote:
                    voteReviewPanel
                }
            }
            .navigationTitle(selectedReviewSection.rawValue)
        } else {
            VStack(spacing: 16) {
                Text("回顧")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    selectedReviewSection = .vote
                } label: {
                    reviewEntryCard(
                        title: "投票紀錄",
                        subtitle: session.voteRecords.isEmpty ? "目前尚無投票紀錄" : "查看每輪是否通過、否決累積與個人投票"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    selectedReviewSection = .mission
                } label: {
                    reviewEntryCard(
                        title: "任務紀錄",
                        subtitle: session.missionRecords.isEmpty ? "目前尚無任務紀錄" : "查看每局隊伍、成功失敗與失敗張數"
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .navigationTitle("回顧")
        }
    }

    private var missionReviewPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if session.missionRecords.isEmpty {
                    Text("目前尚無任務紀錄")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.missionRecords) { record in
                        let ruleSuffix = record.requiresTwoFails ? "（2 失敗規則）" : ""
                        let reasonSuffix = record.causedByRejectTrack ? "（5 次否決判定）" : ""
                        Text("第 \(record.round + 1) 局｜隊伍：\(record.team.map { "\($0 + 1)" }.joined(separator: "、"))｜\(record.success ? "成功" : "失敗")（失敗 \(record.failCount)）\(ruleSuffix)\(reasonSuffix)")
                            .font(.caption)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var gameOverReviewPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("任務紀錄")
                    .font(.headline)

                if session.missionRecords.isEmpty {
                    Text("目前尚無任務紀錄")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.missionRecords) { record in
                        let ruleSuffix = record.requiresTwoFails ? "（2 失敗規則）" : ""
                        let reasonSuffix = record.causedByRejectTrack ? "（5 次否決判定）" : ""
                        Text("第 \(record.round + 1) 局｜隊伍：\(record.team.map { "\($0 + 1)" }.joined(separator: "、"))｜\(record.success ? "成功" : "失敗")（失敗 \(record.failCount)）\(ruleSuffix)\(reasonSuffix)")
                            .font(.caption)
                    }
                }

                Divider()

                Text("投票紀錄")
                    .font(.headline)

                if session.voteRecords.isEmpty {
                    Text("目前尚無投票紀錄")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.voteRecords) { record in
                        if session.shouldShowVotesInReview {
                            Text("第 \(record.round + 1) 局｜隊長 \(record.leader + 1) 號｜\(formatVotes(record.votes))｜\(record.passed ? "通過" : "否決")｜否決累積 \(record.vetoCountAfter)/5")
                                .font(.caption)
                        } else {
                            Text("第 \(record.round + 1) 局｜隊長 \(record.leader + 1) 號｜\(record.passed ? "通過" : "否決")｜否決累積 \(record.vetoCountAfter)/5")
                                .font(.caption)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var voteReviewPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if session.voteRecords.isEmpty {
                    Text("目前尚無投票紀錄")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.voteRecords) { record in
                        if session.shouldShowVotesInReview {
                            Text("第 \(record.round + 1) 局｜隊長 \(record.leader + 1) 號｜\(formatVotes(record.votes))｜\(record.passed ? "通過" : "否決")｜否決累積 \(record.vetoCountAfter)/5")
                                .font(.caption)
                        } else {
                            Text("第 \(record.round + 1) 局｜隊長 \(record.leader + 1) 號｜\(record.passed ? "通過" : "否決")｜否決累積 \(record.vetoCountAfter)/5")
                                .font(.caption)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func reviewEntryCard(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var identityReviewSheetContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(0..<session.playerCount, id: \.self) { seat in
                    Button("玩家 \(seat + 1) 號") {
                        selectedIdentityReviewSeat = seat
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(seat == selectedIdentityReviewSeat ? Color.accentColor : Color(.secondarySystemBackground))
                    )
                    .foregroundStyle(seat == selectedIdentityReviewSeat ? .white : .primary)
                }
            }

            IdentityReviewCard(
                role: session.role(for: selectedIdentityReviewSeat),
                seatNumber: selectedIdentityReviewSeat + 1,
                detailText: identityInfoText(for: selectedIdentityReviewSeat, role: session.role(for: selectedIdentityReviewSeat))
            )

            Text("長按身份卡可查看，放手後會再次遮蔽。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func minimizedPhaseButtonBottomPadding(in geo: GeometryProxy) -> CGFloat {
        if isBottomPanelMinimized {
            return 76
        }
        return min(max(geo.size.height * 0.2, 130), 190)
    }

    // MARK: - Actions

    private var currentMissionSeat: Int? {
        if case let .mission(current, _) = session.phase {
            return current
        }
        return nil
    }

    private var isGameOver: Bool {
        if case .gameOver = session.phase { return true }
        return false
    }

    private func isSeatSelectableInCurrentPhase(_ seat: Int) -> Bool {
        if case .nomination = session.phase {
            return true
        }
        return session.selectedTeam.contains(seat)
    }

    private func nodeColor(for index: Int, result: Bool?) -> Color {
        if let result {
            return result ? .green : .red
        }
        return index == session.roundIndex ? .orange : .gray.opacity(0.45)
    }

    private func nodeIcon(for result: Bool?) -> String {
        guard let result else { return "questionmark" }
        return result ? "checkmark" : "xmark"
    }

    private var phasePanelTitle: String {
        switch session.phase {
        case .nomination:
            return "提名"
        case .voting:
            return "投票"
        case .votingResult:
            return "結果"
        case .mission:
            return "任務"
        case .reveal:
            return "公布"
        case .assassination:
            return "刺殺"
        case .gameOver:
            return "結算"
        }
    }

    private var phaseMinimizeResetKey: String {
        switch session.phase {
        case .nomination:
            return "nomination-\(session.roundIndex)-\(session.leaderIndex)"
        case .voting(let current, _):
            return "voting-\(session.roundIndex)-\(current)"
        case .votingResult(_, let passed):
            return "votingResult-\(session.roundIndex)-\(passed)"
        case .mission(let current, let submissions):
            return "mission-\(session.roundIndex)-\(current)-\(submissions.count)"
        case .reveal(let success, let fails):
            return "reveal-\(session.roundIndex)-\(success)-\(fails)"
        case .assassination:
            return "assassination"
        case .gameOver(let winner, let reason):
            return "gameOver-\(winner)-\(reason)"
        }
    }

    private var debugRoleSummary: String {
        (0..<session.playerCount)
            .map { "玩家 \($0 + 1) 號：\(session.role(for: $0).displayName)" }
            .joined(separator: "\n")
    }

    private var boardImageName: String {
        String(session.playerCount)
    }

    private var boardImageAspectRatio: CGFloat {
#if canImport(UIKit)
        if let size = UIImage(named: boardImageName)?.size, size.height > 0 {
            return size.width / size.height
        }
#endif
        return 1496.0 / 964.0
    }

    private var overlayLayout: BoardOverlayLayout {
        .fivePlayers
    }

    private func formatVotes(_ votes: [Int: Bool]) -> String {
        (0..<session.playerCount)
            .map { seat in
                let vote = (votes[seat] ?? false) ? "同" : "反"
                return "\(seat + 1):\(vote)"
            }
            .joined(separator: " ")
    }

    private func playRoundClick() {
        SoundEffectPlayer.shared.play(.clickSecondary, isEnabled: appSettings.soundEnabled)
    }

    private var revealAdvanceButtonTitle: String {
        if session.goodWins >= 3 {
            return "進入刺殺"
        }

        if session.evilWins >= 3 || session.roundIndex + 1 >= session.missionSizes.count {
            return "查看結果"
        }

        return "進入下一局"
    }

    private func handleRevealAdvance() {
        if session.evilWins >= 3 {
            startEvilVictoryCinematic()
            return
        }

        session.finishReveal()
    }

    private func presentMissionMemeIfNeeded() {
        guard case .reveal(let success, _) = session.phase else { return }
        guard appSettings.soundEnabled || appSettings.effectsEnabled else { return }

        let overlay = missionMemeOverlayConfig(success: success)
        missionMemeOverlaySequence += 1
        let currentSequence = missionMemeOverlaySequence

        if appSettings.soundEnabled {
            SoundEffectPlayer.shared.play(overlay.soundEffect, isEnabled: true)
            if overlay.soundEffect == .missionSuccessMeme {
                let fadeDuration = 1.2
                let fadeStartDelay = max(SoundEffectPlayer.shared.duration(for: overlay.soundEffect) - fadeDuration, 0.2)
                DispatchQueue.main.asyncAfter(deadline: .now() + fadeStartDelay) {
                    if activeMissionMemeOverlay == overlay {
                        SoundEffectPlayer.shared.fadeOut(.missionSuccessMeme, duration: fadeDuration)
                    }
                }
            }
        }

        guard appSettings.effectsEnabled else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            activeMissionMemeOverlay = overlay
        }

        let overlayDuration = max(SoundEffectPlayer.shared.duration(for: overlay.soundEffect) + overlay.holdAfterSound, 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + overlayDuration) {
            guard currentSequence == missionMemeOverlaySequence else { return }
            dismissMissionMemeOverlay()
        }
    }

    private func missionMemeOverlayConfig(success: Bool) -> MissionMemeOverlay {
        if success {
            if Bool.random() {
                return MissionMemeOverlay(
                    imageName: "nice",
                    title: "NICE",
                    soundEffect: .missionSuccessNice,
                    holdAfterSound: 0.5
                )
            }

            return MissionMemeOverlay(
                imageName: "successkid",
                title: "我們做到了",
                soundEffect: .missionSuccessMeme,
                holdAfterSound: 0
            )
        }

        return MissionMemeOverlay(
            imageName: "heyheyboy",
            title: "壞人得逞",
            soundEffect: .missionFailureMeme,
            holdAfterSound: 0
        )
    }

    private func dismissMissionMemeOverlay() {
        missionMemeOverlaySequence += 1
        if let activeMissionMemeOverlay {
            SoundEffectPlayer.shared.stop(activeMissionMemeOverlay.soundEffect)
        }

        guard activeMissionMemeOverlay != nil else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            activeMissionMemeOverlay = nil
        }
    }

    private func startEvilVictoryCinematic() {
        let overlay = EvilVictoryCinematicState(
            imageName: "章魚哥贏家",
            title: "邪惡陣營獲勝",
            soundEffect: .evilVictoryCarelessWhisper,
            holdAfterSound: 0.5
        )

        evilVictoryCinematicSequence += 1
        let currentSequence = evilVictoryCinematicSequence
        evilVictoryRotation = -120
        evilVictoryScale = 0.45

        if appSettings.soundEnabled {
            SoundEffectPlayer.shared.play(overlay.soundEffect, isEnabled: true)
        }

        if appSettings.effectsEnabled {
            evilVictoryCinematic = overlay
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) {
                evilVictoryScale = 1
            }
            withAnimation(.easeOut(duration: 0.65)) {
                evilVictoryRotation = 0
            }
        }

        let totalDuration = max(SoundEffectPlayer.shared.duration(for: overlay.soundEffect) + overlay.holdAfterSound, 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            guard currentSequence == evilVictoryCinematicSequence else { return }
            dismissEvilVictoryCinematic(commitResult: true)
        }
    }

    private func dismissEvilVictoryCinematic(commitResult: Bool) {
        evilVictoryCinematicSequence += 1
        SoundEffectPlayer.shared.stop(.evilVictoryCarelessWhisper)
        evilVictoryRotation = 0
        evilVictoryScale = 1

        let wasPresented = evilVictoryCinematic != nil
        evilVictoryCinematic = nil

        guard commitResult, wasPresented else { return }
        session.finishReveal()
    }

    private func startAssassinationCinematic() {
        let wasSuccessful = session.role(for: selectedAssassinationTarget) == .merlin
        assassinationCinematicSequence += 1
        let currentSequence = assassinationCinematicSequence

        beastJumpOffset = 0
        beastShakeOffset = 0

        if appSettings.soundEnabled {
            SoundEffectPlayer.shared.stop(.assassinationSuspense)
            SoundEffectPlayer.shared.play(.assassinationSuspense, isEnabled: true)
        }

        if appSettings.effectsEnabled {
            withAnimation(.easeInOut(duration: 0.18)) {
                assassinationCinematic = AssassinationCinematicState(
                    targetSeat: selectedAssassinationTarget,
                    wasSuccessful: wasSuccessful,
                    stage: .suspense
                )
            }
        }

        let suspenseDuration = max(SoundEffectPlayer.shared.duration(for: .assassinationSuspense), 0.6) + 2
        DispatchQueue.main.asyncAfter(deadline: .now() + suspenseDuration) {
            guard currentSequence == assassinationCinematicSequence else { return }
            transitionToAssassinationResult(wasSuccessful: wasSuccessful)
        }
    }

    private func transitionToAssassinationResult(wasSuccessful: Bool) {
        assassinationCinematicSequence += 1

        if !appSettings.effectsEnabled {
            commitAssassinationResult(wasSuccessful: wasSuccessful)
            return
        }

        beastJumpOffset = 0
        beastShakeOffset = 0
        withAnimation(.easeInOut(duration: 0.35)) {
            assassinationCinematic = AssassinationCinematicState(
                targetSeat: selectedAssassinationTarget,
                wasSuccessful: wasSuccessful,
                stage: .result(wasSuccessful: wasSuccessful)
            )
        }

        if !wasSuccessful {
            if appSettings.soundEnabled {
                SoundEffectPlayer.shared.play(.assassinationFailEpic, isEnabled: true)
                let totalDuration = SoundEffectPlayer.shared.duration(for: .assassinationFailEpic)
                let fadeDuration = max(totalDuration - 3, 0.5)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if case .result(wasSuccessful: false)? = assassinationCinematic?.stage {
                        SoundEffectPlayer.shared.fadeTo(.assassinationFailEpic, targetVolume: 0.5, duration: fadeDuration)
                    }
                }
            }
            return
        }

        if appSettings.soundEnabled {
            SoundEffectPlayer.shared.play(.beastRoar, isEnabled: true)
            let totalDuration = SoundEffectPlayer.shared.duration(for: .beastRoar)
            let fadeDuration = max(totalDuration - 3, 0.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if case .result(wasSuccessful: true)? = assassinationCinematic?.stage {
                    SoundEffectPlayer.shared.fadeTo(.beastRoar, targetVolume: 0.5, duration: fadeDuration)
                }
            }
        }

        playBeastAnimation(sequence: assassinationCinematicSequence)
    }

    private func playBeastAnimation(sequence: Int) {
        let jumpHeight: CGFloat = 24
        let jumpDuration = 0.18
        let totalJumpTime = 2.0
        let jumpCount = Int(totalJumpTime / (jumpDuration * 2))

        for jumpIndex in 0..<jumpCount {
            let delay = Double(jumpIndex) * (jumpDuration * 2)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard sequence == assassinationCinematicSequence else { return }
                withAnimation(.easeOut(duration: jumpDuration)) {
                    beastJumpOffset = -jumpHeight
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay + jumpDuration) {
                guard sequence == assassinationCinematicSequence else { return }
                withAnimation(.easeIn(duration: jumpDuration)) {
                    beastJumpOffset = 0
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + totalJumpTime) {
            guard sequence == assassinationCinematicSequence else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                beastJumpOffset = 0
            }
            withAnimation(.easeInOut(duration: 0.08).repeatForever(autoreverses: true)) {
                beastShakeOffset = 22
            }
        }
    }

    private func handleAssassinationCinematicTap() {
        guard let assassinationCinematic else { return }

        switch assassinationCinematic.stage {
        case .suspense:
            transitionToAssassinationResult(wasSuccessful: assassinationCinematic.wasSuccessful)
        case .result:
            dismissAssassinationCinematic(commitResult: true)
        }
    }

    private func dismissAssassinationCinematic(commitResult: Bool) {
        assassinationCinematicSequence += 1
        SoundEffectPlayer.shared.stop(.assassinationSuspense)
        SoundEffectPlayer.shared.stop(.beastRoar)
        SoundEffectPlayer.shared.stop(.assassinationFailEpic)
        beastJumpOffset = 0
        beastShakeOffset = 0

        let pendingResult = assassinationCinematic?.wasSuccessful
        assassinationCinematic = nil

        guard commitResult, let pendingResult else { return }
        commitAssassinationResult(wasSuccessful: pendingResult)
    }

    private func commitAssassinationResult(wasSuccessful: Bool) {
        session.assassinate(target: selectedAssassinationTarget)
    }

    private func assassinationImage(for state: AssassinationCinematicState) -> Image {
        switch state.stage {
        case .suspense:
            return Image("慌張")
        case .result(let wasSuccessful):
            return Image(wasSuccessful ? "野獸" : "ishowSpeed")
        }
    }

    private func assassinationTitle(for state: AssassinationCinematicState) -> String {
        switch state.stage {
        case .suspense:
            return "刺殺進行中"
        case .result(let wasSuccessful):
            return wasSuccessful ? "梅林死啦！！！！！！" : "梅林逃過一劫"
        }
    }

    private func assassinationSubtitle(for state: AssassinationCinematicState) -> String {
        switch state.stage {
        case .suspense:
            return "玩家 \(state.targetSeat + 1) 號即將揭曉命運"
        case .result(let wasSuccessful):
            return wasSuccessful ? "點一下進入真正的結果公布" : "點一下進入真正的結果公布"
        }
    }

    private func assassinationStageID(for state: AssassinationCinematicState) -> String {
        switch state.stage {
        case .suspense:
            return "suspense"
        case .result(let wasSuccessful):
            return "result-\(wasSuccessful)"
        }
    }

    private func identityInfoText(for seat: Int, role: Role) -> String {
        let evilSeats = session.assignments.filter { $0.value.faction == .evil }.map(\.key).sorted()
        let mordredSeats = session.assignments.filter { $0.value == .mordred }.map(\.key)
        let oberonSeats = session.assignments.filter { $0.value == .oberon }.map(\.key)

        func format(_ seats: [Int]) -> String {
            if seats.isEmpty { return "（無）" }
            return seats.map { "玩家 \($0 + 1) 號" }.joined(separator: "、")
        }

        switch role {
        case .merlin:
            let visible = evilSeats.filter { !mordredSeats.contains($0) }
            return "你能看到以下壞人（不含莫德雷德）：\(format(visible))"
        case .percival:
            let candidates = session.assignments.filter { $0.value == .merlin || $0.value == .morgana }.map(\.key).sorted()
            return "你看到以下兩位其中一位是梅林：\(format(candidates))"
        case .oberon:
            return "你是壞人，但不與其他壞人互認；其他壞人也看不到你。"
        case .assassin, .morgana, .mordred, .minion:
            let visible = evilSeats.filter { $0 != seat && !oberonSeats.contains($0) }
            return "你的壞人同夥：\(format(visible))"
        case .loyalServant:
            return "你是好人（忠臣）。你沒有額外資訊。"
        }
    }

    private func triggerSentAnimation() {
        showSentAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            showSentAnimation = false
        }
    }

    private func requestDangerAction(_ action: DangerAction) {
        pendingDangerAction = action
        showDangerStepOne = true
    }

    private func handleMissionChoice(success: Bool) {
        if session.isDebugFastMode {
            session.submitMissionCard(success: success)
            triggerSentAnimation()
            return
        }

        pendingMissionSuccess = success
        showConfirmMissionChoice = true
    }

    private func confirmNominationIfNeeded() {
        if session.isDebugFastMode {
            session.confirmNomination()
            return
        }
        showConfirmNomination = true
    }

    private func confirmAssassinationIfNeeded() {
        if session.isDebugFastMode {
            startAssassinationCinematic()
            return
        }
        showConfirmAssassination = true
    }

    private var nominationConfirmationBinding: Binding<Bool> {
        Binding(
            get: { !session.isDebugFastMode && showConfirmNomination },
            set: { showConfirmNomination = $0 }
        )
    }

    private func performDangerAction(_ action: DangerAction) {
        switch action {
        case .resetGame:
            session.restartKeepingRoles()
        case .reshuffleRoles:
            session.restartWithReshuffle()
        }
    }

    private func resetCalibrationCenters() {
        missionCalibrationCenters = Array(overlayLayout.missionCenters.prefix(5))
        voteCalibrationCenters = Array(overlayLayout.voteCenters.prefix(2))
        selectedCalibrationMarkerID = nil
    }

    private func updateMissionCalibrationCenter(at index: Int, to point: CGPoint) {
        guard missionCalibrationCenters.indices.contains(index) else { return }
        selectedCalibrationMarkerID = missionMarkerID(for: index)
        missionCalibrationCenters[index] = point
    }

    private func updateVoteCalibrationCenter(at index: Int, to point: CGPoint) {
        guard voteCalibrationCenters.indices.contains(index) else { return }
        selectedCalibrationMarkerID = voteMarkerID(for: index)
        voteCalibrationCenters[index] = point
    }

    private func missionMarkerID(for index: Int) -> String {
        "mission-\(index)"
    }

    private func voteMarkerID(for index: Int) -> String {
        "vote-\(index)"
    }

    private var nonSelectedMissionMarkers: [(offset: Int, center: CGPoint)] {
        Array(missionCalibrationCenters.enumerated())
            .filter { missionMarkerID(for: $0.offset) != selectedCalibrationMarkerID }
            .map { (offset: $0.offset, center: $0.element) }
    }

    private var nonSelectedVoteMarkers: [(offset: Int, center: CGPoint)] {
        Array(voteCalibrationCenters.enumerated())
            .filter { voteMarkerID(for: $0.offset) != selectedCalibrationMarkerID }
            .map { (offset: $0.offset, center: $0.element) }
    }

    private var selectedMissionMarker: (index: Int, center: CGPoint)? {
        guard let selectedCalibrationMarkerID else { return nil }
        return Array(missionCalibrationCenters.enumerated()).first { missionMarkerID(for: $0.offset) == selectedCalibrationMarkerID }
            .map { ($0.offset, $0.element) }
    }

    private var selectedVoteMarker: (index: Int, center: CGPoint)? {
        guard let selectedCalibrationMarkerID else { return nil }
        return Array(voteCalibrationCenters.enumerated()).first { voteMarkerID(for: $0.offset) == selectedCalibrationMarkerID }
            .map { ($0.offset, $0.element) }
    }
}

private struct StatusPill: View {
    let systemName: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemName)
            Text(text)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
    }
}

#if DEBUG
private struct CalibrationMarker: View {
    let title: String
    let normalizedCenter: CGPoint
    let size: CGFloat
    let color: Color
    let boardFrame: CGRect
    let isSelected: Bool
    let onSelect: () -> Void
    let onMove: (CGPoint) -> Void

    var body: some View {
        let actualCenter = CGPoint(
            x: boardFrame.minX + boardFrame.width * normalizedCenter.x,
            y: boardFrame.minY + boardFrame.height * normalizedCenter.y
        )

        ZStack(alignment: .top) {
            Circle()
                .stroke(color, lineWidth: isSelected ? 4 : 3)
                .background(Circle().fill(color.opacity(0.12)))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .foregroundStyle(color)
                )

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(String(format: "(%.4f, %.4f)", normalizedCenter.x, normalizedCenter.y))
                    .font(.caption2.monospacedDigit())
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .offset(y: -max(size * 0.72, 42))
        }
        .position(actualCenter)
        .onTapGesture {
            onSelect()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onSelect()
                    let normalizedX = ((value.location.x - boardFrame.minX) / boardFrame.width).clamped(to: 0...1)
                    let normalizedY = ((value.location.y - boardFrame.minY) / boardFrame.height).clamped(to: 0...1)
                    onMove(CGPoint(x: normalizedX, y: normalizedY))
                }
        )
    }
}
#endif

private struct SeatChip: View {
    let number: Int
    let selected: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(selected ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selected ? Color.accentColor : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.55)
    }
}

private struct IdentityReviewCard: View {
    let role: Role
    let seatNumber: Int
    let detailText: String

    @State private var isRevealed = false
    @State private var blackout = true

    var body: some View {
        VStack(spacing: 12) {
            Text("玩家 \(seatNumber) 號").font(.headline)
            ZStack {
                VStack(spacing: 10) {
                    Text(role.displayName)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(factionColor)
                    Text(role.faction == .good ? "好人陣營" : "壞人陣營")
                        .font(.headline)
                        .foregroundStyle(factionColor)
                    Text(detailText)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .blur(radius: (isRevealed && !blackout) ? 0 : 20)

                if blackout {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.85))
                        .overlay(Text("長按以查看身份").foregroundStyle(.white))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.6)
                    .onChanged { _ in
                        blackout = false
                        isRevealed = true
                    }
                    .onEnded { _ in
                        isRevealed = false
                        blackout = true
                    }
            )
            .onAppear {
                resetRevealState()
            }
            .onChange(of: seatNumber) { _, _ in
                resetRevealState()
            }
        }
    }

    private var factionColor: Color {
        role.faction == .good ? .blue : .red
    }

    private func resetRevealState() {
        blackout = true
        isRevealed = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if !isRevealed {
                blackout = true
            }
        }
    }
}

private struct SentOverlay: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 46))
                .foregroundStyle(.green)
            Text("已送出")
                .font(.title3.bold())
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .padding(.top, 24)
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 4)
    }
}

#if os(iOS)
private func setLandscape(_ enable: Bool) {
    let orientation = enable ? UIInterfaceOrientation.landscapeRight : .portrait
    UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
}
#else
private func setLandscape(_ enable: Bool) { }
#endif
private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
