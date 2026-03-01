//
//  AVPlayerView.swift
//  Survivor MVP
//
//  visionOS/iOS: UIViewControllerRepresentable; macOS: stub (no immersive video).
//

import SwiftUI

#if os(iOS) || os(visionOS)
import UIKit

struct AVPlayerView: UIViewControllerRepresentable {
    let viewModel: AVPlayerViewModel

    func makeUIViewController(context: Context) -> some UIViewController {
        return viewModel.makePlayerViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {}
}
#else
struct AVPlayerView: View {
    let viewModel: AVPlayerViewModel

    var body: some View {
        EmptyView()
    }
}
#endif
