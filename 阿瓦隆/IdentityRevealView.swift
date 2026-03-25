import SwiftUI

struct IdentityRevealView: View {
    @Environment(AppSettings.self) private var appSettings
    @ObservedObject var session: GameSession
    var onFinished: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var stage: Stage = .handoff
    @State private var hasViewedCurrentCard = false
    @State private var showNeedViewAlert = false

    enum Stage { case handoff, card }

    var body: some View {
        VStack(spacing: 24) {
            switch stage {
            case .handoff:
                Text("請把手機交給：玩家 \(index + 1) 號")
                    .font(.title2.bold())
                Button("我準備好了") {
                    SoundEffectPlayer.shared.play(.clickPrimary, isEnabled: appSettings.soundEnabled)
                    hasViewedCurrentCard = false
                    stage = .card
                }
                .buttonStyle(.borderedProminent)

            case .card:
                let role = session.role(for: index)
                IdentityCard(
                    role: role,
                    seatNumber: index + 1,
                    detailText: buildInfoText(for: index, role: role),
                    onFirstReveal: {
                        hasViewedCurrentCard = true
                    }
                )

                if hasViewedCurrentCard {
                    Button("我看完了") {
                        SoundEffectPlayer.shared.play(.clickPrimary, isEnabled: appSettings.soundEnabled)
                        advanceToNextPlayerOrFinish()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("請先長按查看身份後再繼續")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .presentationBackground(.thinMaterial)
        .onAppear {
            SoundEffectPlayer.shared.playLoopingIfNeeded(.setupOpen, isEnabled: appSettings.soundEnabled, volume: 0.16)
        }
        .onDisappear {
            SoundEffectPlayer.shared.fadeOutLooping(.setupOpen, duration: 0.6)
        }
        .onChange(of: appSettings.soundEnabled) { _, newValue in
            if newValue {
                SoundEffectPlayer.shared.playLoopingIfNeeded(.setupOpen, isEnabled: true, volume: 0.16)
            } else {
                SoundEffectPlayer.shared.stopAll()
            }
        }
        .alert("尚未查看身份", isPresented: $showNeedViewAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("請先長按身份卡確認內容，再點選「我看完了」。")
        }
    }

    private func advanceToNextPlayerOrFinish() {
        guard hasViewedCurrentCard else {
            showNeedViewAlert = true
            return
        }

        if index + 1 < session.playerCount {
            index += 1
            stage = .handoff
            hasViewedCurrentCard = false
        } else {
            onFinished?()
            dismiss()
        }
    }

    private func buildInfoText(for seat: Int, role: Role) -> String {
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
}

private struct IdentityCard: View {
    let role: Role
    let seatNumber: Int
    let detailText: String
    let onFirstReveal: () -> Void

    @State private var isRevealed = false
    @State private var blackout = true
    @State private var didNotifyReveal = false

    var body: some View {
        VStack(spacing: 12) {
            Text("玩家 \(seatNumber) 號").font(.headline)
            ZStack {
                VStack(spacing: 10) {
                    Text(displayName)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(factionColor)
                    Text(factionText)
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
                        if !didNotifyReveal {
                            didNotifyReveal = true
                            onFirstReveal()
                        }
                    }
                    .onEnded { _ in
                        isRevealed = false
                        blackout = true
                    }
            )
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    if !isRevealed {
                        blackout = true
                    }
                }
            }
        }
    }

    private var factionColor: Color { role.faction == .good ? .blue : .red }
    private var displayName: String { role.displayName }
    private var factionText: String { role.faction == .good ? "好人陣營" : "壞人陣營" }
}
