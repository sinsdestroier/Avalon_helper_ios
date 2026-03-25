import SwiftUI

struct SetupView: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var setup = GameSetup()
    @State private var players: [Player] = (1...5).map { Player(name: "玩家\($0)") }
    @State private var showWarnings = false
    @State private var revealSession: GameSession?
    @State private var roundFlowSession: GameSession?
    @State private var pendingRoundFlowSession: GameSession?
    @State private var showMissionSizeTable = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PeopleSection(setup: $setup, players: $players)
                    RolePacksSection(setup: $setup)
                    RulesSection(setup: $setup)
                    MissionSizeQuickSection(setup: setup, isPresented: $showMissionSizeTable)
                    PlayerNamesSection(players: $players, targetCount: setup.playerCount)
                    if showWarnings && !setup.validationWarnings().isEmpty {
                        WarningsSection(warnings: setup.validationWarnings())
                    }
                    ActionButtons(showWarnings: $showWarnings, players: $players, setup: setup) {
                        startIdentityRevealFlow()
                    }
                }
                .padding(16)
            }
            .navigationTitle("建立房間")
            .background(Color(.systemGroupedBackground))
            .onChange(of: setup.playerCount) { _, newValue in
                adjustPlayersCount(to: newValue)
                syncRuleDefaults(for: newValue)
            }
            .onChange(of: setup.evilCount) { _, _ in
                enforceCaps()
            }
            .onChange(of: setup.goodCount) { _, _ in
                enforceCaps()
            }
            .onAppear {
                syncRuleDefaults(for: setup.playerCount)
                SoundEffectPlayer.shared.playLoopingIfNeeded(.setupOpen, isEnabled: appSettings.soundEnabled, volume: 0.18)
            }
            .onDisappear {
                SoundEffectPlayer.shared.fadeOutLooping(.setupOpen, duration: 0.6)
            }
            .onChange(of: appSettings.soundEnabled) { _, newValue in
                if newValue {
                    SoundEffectPlayer.shared.playLoopingIfNeeded(.setupOpen, isEnabled: true, volume: 0.18)
                } else {
                    SoundEffectPlayer.shared.stopAll()
                }
            }
            .fullScreenCover(item: $revealSession, onDismiss: {
                if let session = pendingRoundFlowSession {
                    roundFlowSession = session
                    pendingRoundFlowSession = nil
                }
            }) { session in
                IdentityRevealView(session: session) {
                    pendingRoundFlowSession = session
                    revealSession = nil
                }
            }
            .fullScreenCover(item: $roundFlowSession) { session in
                RoundFlowView(session: session)
            }
#if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    settingsMenu
                }
            }
#else
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    settingsMenu
                }
            }
#endif
        }
    }

    private var settingsMenu: some View {
        Menu {
            Toggle(isOn: soundBinding) {
                Label("開啟音效", systemImage: appSettings.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }

            Toggle(isOn: effectsBinding) {
                Label("開啟特效", systemImage: appSettings.effectsEnabled ? "sparkles" : "sparkles.slash")
            }
#if DEBUG
            Divider()
            Menu("DEBUG模式") {
                Button("快速發身份（沿用目前設定）") {
                    let session = GameSession(setup: setup, playerCount: players.count)
                    session?.enableDebugFastMode()
                    revealSession = session
                }
                Button("直接進入回合（沿用目前設定）") {
                    let session = GameSession(setup: setup, playerCount: players.count)
                    session?.enableDebugFastMode()
                    roundFlowSession = session
                }
                Button("直接進投票（沿用目前設定）") {
                    let session = GameSession(setup: setup, playerCount: players.count)
                    session?.startDebugVotingPhase()
                    roundFlowSession = session
                }
                Divider()
                Button("快速發身份（5 人預設）") {
                    applyDefaultFivePlayerPreset()
                    let session = GameSession(setup: setup, playerCount: players.count)
                    session?.enableDebugFastMode()
                    revealSession = session
                }
                Button("直接進入回合（5 人預設）") {
                    applyDefaultFivePlayerPreset()
                    let session = GameSession(setup: setup, playerCount: players.count)
                    session?.enableDebugFastMode()
                    roundFlowSession = session
                }
                Button("直接進投票（5 人預設）") {
                    applyDefaultFivePlayerPreset()
                    let session = GameSession(setup: setup, playerCount: players.count)
                    session?.startDebugVotingPhase()
                    roundFlowSession = session
                }
                Button("圖示排版預覽（5 人 2勝2敗/4否決）") {
                    applyDefaultFivePlayerPreset()
                    let session = GameSession(setup: setup, playerCount: players.count)
                    session?.loadDebugBoardPreview()
                    roundFlowSession = session
                }
            }
#endif
        } label: {
            Image(systemName: "gearshape.fill")
        }
    }

    private var soundBinding: Binding<Bool> {
        Binding(
            get: { appSettings.soundEnabled },
            set: { newValue in
                appSettings.soundEnabled = newValue
                if newValue {
                    SoundEffectPlayer.shared.play(.clickPrimary, isEnabled: true)
                }
            }
        )
    }

    private var effectsBinding: Binding<Bool> {
        Binding(
            get: { appSettings.effectsEnabled },
            set: { appSettings.effectsEnabled = $0 }
        )
    }

    private func startIdentityRevealFlow() {
        revealSession = GameSession(setup: setup, playerCount: players.count)
    }

    private func applyDefaultFivePlayerPreset() {
        setup.playerCount = 5
        setup.customEvilCount = nil
        setup.includeMerlin = true
        setup.includeAssassin = true
        setup.includePercival = false
        setup.includeMorgana = false
        setup.includeMordred = false
        setup.includeOberon = false
        setup.includeGenericMinions = true
        setup.requireTwoFailsOnFourthAtSevenPlus = false
        setup.fiveRejectsEvilWins = false
        setup.clockwiseLeaderRotation = true
        setup.voteReveal = .showNow
        adjustPlayersCount(to: 5)
        enforceCaps()
    }

    private func syncRuleDefaults(for playerCount: Int) {
        setup.requireTwoFailsOnFourthAtSevenPlus = playerCount >= 7
    }

    private func adjustPlayersCount(to newValue: Int) {
        if players.count < newValue {
            let start = players.count + 1
            for i in start...newValue {
                players.append(Player(name: "玩家\(i)"))
            }
        } else if players.count > newValue {
            players.removeLast(players.count - newValue)
        }
    }

    private func evilSpecialCount(_ s: GameSetup) -> Int {
        [s.includeAssassin, s.includeMorgana, s.includeMordred, s.includeOberon].filter { $0 }.count
    }

    private func goodSpecialCount(_ s: GameSetup) -> Int {
        [s.includeMerlin, s.includePercival].filter { $0 }.count
    }

    private func evilTotalCount(_ s: GameSetup) -> Int {
        evilSpecialCount(s) + (s.includeGenericMinions ? 1 : 0)
    }

    private func enforceCaps() {
        while evilTotalCount(setup) > setup.evilCount {
            if setup.includeGenericMinions { setup.includeGenericMinions = false; continue }
            if setup.includeOberon { setup.includeOberon = false; continue }
            if setup.includeMordred { setup.includeMordred = false; continue }
            if setup.includeMorgana { setup.includeMorgana = false; continue }
            if setup.includeAssassin { setup.includeAssassin = false; continue }
            break
        }

        while goodSpecialCount(setup) > setup.goodCount {
            if setup.includePercival { setup.includePercival = false; continue }
            if setup.includeMerlin { setup.includeMerlin = false; continue }
            break
        }
    }
}

private struct PeopleSection: View {
    @Binding var setup: GameSetup
    @Binding var players: [Player]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("玩家人數").font(.headline)
            HStack(spacing: 12) {
                Stepper("人數：\(setup.playerCount)", value: $setup.playerCount, in: 5...10)
                Spacer()
                Text("標準壞人：\(GameSetup.standardEvilCount(for: setup.playerCount))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Toggle("自訂壞人數", isOn: Binding(
                get: { setup.customEvilCount != nil },
                set: { isOn in setup.customEvilCount = isOn ? setup.evilCount : nil }
            ))

            if setup.customEvilCount != nil {
                Stepper(value: Binding(
                    get: { setup.customEvilCount ?? GameSetup.standardEvilCount(for: setup.playerCount) },
                    set: { setup.customEvilCount = $0 }
                ), in: 1...setup.playerCount - 1) {
                    Text("壞人數：\(setup.customEvilCount ?? 0)")
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct RolePacksSection: View {
    @Binding var setup: GameSetup
    @State private var roleHelpText = ""
    @State private var showRoleHelp = false

    private var selectedEvilTotal: Int {
        evilSpecialCount + (setup.includeGenericMinions ? 1 : 0)
    }

    private var evilSpecialCount: Int {
        [setup.includeAssassin, setup.includeMorgana, setup.includeMordred, setup.includeOberon].filter { $0 }.count
    }

    private var goodSpecialCount: Int {
        [setup.includeMerlin, setup.includePercival].filter { $0 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("角色與陣營（長按看說明）").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                Text("正義聯盟（好人）共 \(setup.goodCount) 人")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    RoleToggle(title: "梅林", isOn: limitedGoodBinding(\GameSetup.includeMerlin), tint: .blue, helpText: Role.merlin.summary, onLongPress: presentRoleHelp)
                    RoleToggle(title: "派西維爾", isOn: pairedPercivalBinding(), tint: .blue, helpText: Role.percival.summary, onLongPress: presentRoleHelp)
                    RoleToggle(title: "忠臣", isOn: .constant(true), tint: .blue, helpText: Role.loyalServant.summary, onLongPress: presentRoleHelp)
                }

                Divider().padding(.vertical, 6)

                Text("邪惡聯盟（壞人）共 \(setup.evilCount) 人")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    RoleToggle(title: "刺客", isOn: limitedEvilBinding(\GameSetup.includeAssassin), tint: .red, helpText: Role.assassin.summary, onLongPress: presentRoleHelp)
                    RoleToggle(title: "莫甘娜", isOn: pairedMorganaBinding(), tint: .red, helpText: Role.morgana.summary, onLongPress: presentRoleHelp)
                    RoleToggle(title: "莫德雷德", isOn: limitedEvilBinding(\GameSetup.includeMordred), tint: .red, helpText: Role.mordred.summary, onLongPress: presentRoleHelp)
                    RoleToggle(title: "奧伯倫", isOn: limitedEvilBinding(\GameSetup.includeOberon), tint: .red, helpText: Role.oberon.summary, onLongPress: presentRoleHelp)
                    RoleToggle(title: "爪牙", isOn: limitedMinionBinding(), tint: .red, helpText: Role.minion.summary, onLongPress: presentRoleHelp)
                }

                if setup.assassinationByCollective {
                    Text("未包含刺客：刺殺將由全體壞人共同決定")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .alert("角色說明", isPresented: $showRoleHelp) {
            Button("關閉", role: .cancel) {}
        } message: {
            Text(roleHelpText)
        }
    }

    private func limitedEvilBinding(_ keyPath: WritableKeyPath<GameSetup, Bool>) -> Binding<Bool> {
        Binding(
            get: { setup[keyPath: keyPath] },
            set: { newValue in
                if newValue {
                    if selectedEvilTotal < setup.evilCount {
                        setup[keyPath: keyPath] = true
                    }
                } else {
                    setup[keyPath: keyPath] = false
                }
            }
        )
    }

    private func limitedGoodBinding(_ keyPath: WritableKeyPath<GameSetup, Bool>) -> Binding<Bool> {
        Binding(
            get: { setup[keyPath: keyPath] },
            set: { newValue in
                if newValue {
                    if goodSpecialCount < setup.goodCount {
                        setup[keyPath: keyPath] = true
                    }
                } else {
                    setup[keyPath: keyPath] = false
                }
            }
        )
    }

    private func limitedMinionBinding() -> Binding<Bool> {
        Binding(
            get: { setup.includeGenericMinions },
            set: { newValue in
                if newValue {
                    if selectedEvilTotal < setup.evilCount {
                        setup.includeGenericMinions = true
                    }
                } else {
                    setup.includeGenericMinions = false
                }
            }
        )
    }

    private func pairedPercivalBinding() -> Binding<Bool> {
        Binding(
            get: { setup.includePercival },
            set: { newValue in
                if newValue {
                    guard canEnablePairedRoles() else { return }
                    setup.includePercival = true
                    setup.includeMorgana = true
                } else {
                    setup.includePercival = false
                    setup.includeMorgana = false
                }
            }
        )
    }

    private func pairedMorganaBinding() -> Binding<Bool> {
        Binding(
            get: { setup.includeMorgana },
            set: { newValue in
                if newValue {
                    guard canEnablePairedRoles() else { return }
                    setup.includeMorgana = true
                    setup.includePercival = true
                } else {
                    setup.includeMorgana = false
                    setup.includePercival = false
                }
            }
        )
    }

    private func canEnablePairedRoles() -> Bool {
        let needsPercival = !setup.includePercival
        let needsMorgana = !setup.includeMorgana

        if needsPercival && goodSpecialCount >= setup.goodCount {
            return false
        }

        var projectedEvilTotal = selectedEvilTotal + (needsMorgana ? 1 : 0)
        if projectedEvilTotal > setup.evilCount && setup.includeGenericMinions {
            setup.includeGenericMinions = false
            projectedEvilTotal -= 1
        }

        return projectedEvilTotal <= setup.evilCount
    }

    private func presentRoleHelp(_ text: String) {
        roleHelpText = text
        showRoleHelp = true
    }
}

private struct RulesSection: View {
    @Binding var setup: GameSetup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("規則與投票顯示").font(.headline)
            Toggle("7+ 人第 4 局需要 2 張失敗", isOn: $setup.requireTwoFailsOnFourthAtSevenPlus)
            Toggle("5 次否決壞人直接勝利", isOn: $setup.fiveRejectsEvilWins)

            Picker("投票顯示策略", selection: $setup.voteReveal) {
                ForEach(VoteRevealStrategy.allCases) { strategy in
                    Text(strategy.displayName).tag(strategy)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct MissionSizeQuickSection: View {
    let setup: GameSetup
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("任務人數表").font(.headline)
            Text("目前 \(setup.playerCount) 人局：\(GameSetup.missionTeamSizes(for: setup.playerCount).map(String.init).joined(separator: " / "))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("快速查看 5-10 人任務表") {
                isPresented = true
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .alert("任務人數表", isPresented: $isPresented) {
            Button("關閉", role: .cancel) {}
        } message: {
            Text((5...10).map { players in
                "\(players) 人：\(GameSetup.missionTeamSizes(for: players).map(String.init).joined(separator: " / "))"
            }.joined(separator: "\n"))
        }
    }
}

private struct PlayerNamesSection: View {
    @Binding var players: [Player]
    let targetCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("玩家名稱（\(players.count)/\(targetCount)）").font(.headline)
            VStack(spacing: 8) {
                ForEach(players.indices, id: \.self) { idx in
                    HStack {
                        Text("P\(idx + 1)").font(.subheadline.bold()).frame(width: 28)
                        TextField("暱稱", text: Binding(
                            get: { players[idx].name },
                            set: { players[idx].name = $0 }
                        ))
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .textFieldStyle(.roundedBorder)
                    }
                }
                if players.count != targetCount {
                    Text("人數尚未與設定一致，請調整玩家或人數")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct WarningsSection: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("提醒").font(.headline)
            ForEach(warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(warning)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ActionButtons: View {
    @Environment(AppSettings.self) private var appSettings
    @Binding var showWarnings: Bool
    @Binding var players: [Player]
    let setup: GameSetup
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                showWarnings = true
            } label: {
                Label("檢查配置", systemImage: "exclamationmark.triangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(action: onStart) {
                Text("開始遊戲")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    SoundEffectPlayer.shared.play(.clickPrimary, isEnabled: appSettings.soundEnabled)
                }
            )
            .buttonStyle(.borderedProminent)
            .disabled(players.count != setup.playerCount)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct RoleToggle: View {
    let title: String
    @Binding var isOn: Bool
    var tint: Color
    let helpText: String
    let onLongPress: (String) -> Void

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.seal.fill" : "seal").font(.title2)
                Text(title).font(.footnote).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(isOn ? .white : .primary)
            .background(RoundedRectangle(cornerRadius: 12).fill(isOn ? tint : Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .onLongPressGesture {
            onLongPress(helpText)
        }
    }
}

#Preview {
    SetupView()
}
