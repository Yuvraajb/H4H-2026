//
//  AVPlayerViewModel.swift
//  Survivor MVP
//
//  visionOS/iOS: AVPlayerViewController; macOS: stub (isPlaying always false).
//

import AVFoundation
#if os(iOS) || os(visionOS)
import AVKit
import UIKit

@MainActor
@Observable
class AVPlayerViewModel: NSObject {
    var isPlaying: Bool = false
    private var avPlayerViewController: AVPlayerViewController?
    private var avPlayer = AVPlayer()
    private let videoURL: URL? = nil

    func makePlayerViewController() -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = avPlayer
        vc.delegate = self
        self.avPlayerViewController = vc
        return vc
    }

    func play() {
        guard !isPlaying, let videoURL else { return }
        isPlaying = true
        let item = AVPlayerItem(url: videoURL)
        avPlayer.replaceCurrentItem(with: item)
        avPlayer.play()
    }

    func reset() {
        guard isPlaying else { return }
        isPlaying = false
        avPlayer.replaceCurrentItem(with: nil)
        avPlayerViewController?.delegate = nil
    }
}

extension AVPlayerViewModel: AVPlayerViewControllerDelegate {
    nonisolated func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        Task { @MainActor in
            reset()
        }
    }
}
#else
import SwiftUI

@MainActor
@Observable
class AVPlayerViewModel {
    var isPlaying: Bool = false

    func makePlayerViewController() -> Any { 0 }
    func play() {}
    func reset() {}
}
#endif
