//
//  ContentView.swift
//  阿瓦隆
//
//  Created by 114-2Student07 on 2026/3/3.
//

import AVKit
import SwiftUI

struct ContentView: View {
    @Environment(AppSettings.self) private var appSettings
    @State private var introFinished = false

    var body: some View {
        ZStack {
            SetupView()
                .opacity(introFinished ? 1 : 0)

            if !introFinished {
                LaunchIntroView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        introFinished = true
                    }
                }
                .transition(.opacity)
            }
        }
        .background(Color.black)
        .animation(.easeInOut(duration: 0.5), value: introFinished)
        .onAppear {
            SoundEffectPlayer.shared.playLoopingIfNeeded(.setupOpen, isEnabled: appSettings.soundEnabled, volume: 0.18)
        }
    }
}

private struct LaunchIntroView: View {
    let onFinished: () -> Void

    @State private var player: AVPlayer?
    @State private var hasFinished = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .disabled(true)
            }
        }
        .task {
            guard !hasFinished else { return }
            guard let url = introVideoURL() else {
                finishIfNeeded()
                return
            }

            let player = AVPlayer(url: url)
            self.player = player
            player.isMuted = true
            player.play()

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                finishIfNeeded()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func finishIfNeeded() {
        guard !hasFinished else { return }
        hasFinished = true
        player?.pause()
        onFinished()
    }

    private func introVideoURL() -> URL? {
        Bundle.main.url(forResource: "阿瓦隆開始動畫", withExtension: "mp4")
        ?? Bundle.main.url(forResource: "阿瓦隆開始動畫 ", withExtension: "mp4")
    }
}

#Preview {
    ContentView()
}
