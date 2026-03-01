//
//  CameraFeedModel.swift
//  Survivor MVP
//
//  Camera authorization and AVCaptureSession for live preview in Visual guide.
//  Start/stop session on background queue. Works on visionOS, macOS, and iOS.
//  Simulator for visionOS may show unavailable; macOS target will show live webcam.
//

import AVFoundation
import SwiftUI

@MainActor
@Observable
final class CameraFeedModel {
    enum Status: Equatable {
        case idle
        case requestingPermission
        case unauthorized
        case unavailable
        case running
        case failed(String)
    }

    private let sessionQueue = DispatchQueue(label: "com.pulsecoach.camera.session")

    var status: Status = .idle
    var session: AVCaptureSession?

    func start() {
        status = .requestingPermission

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted {
                        self.configureAndStartSession()
                    } else {
                        self.status = .unauthorized
                    }
                }
            }
        case .denied, .restricted:
            status = .unauthorized
        @unknown default:
            status = .unauthorized
        }
    }

    func stop() {
        let sessionToStop = session
        session = nil
        status = .idle
        sessionQueue.async {
            sessionToStop?.stopRunning()
        }
    }

    private func configureAndStartSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video) else {
            status = .unavailable
            return
        }

        let newSession = AVCaptureSession()
        newSession.beginConfiguration()

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if newSession.canAddInput(input) {
                newSession.addInput(input)
            }
            #if !os(visionOS)
            newSession.sessionPreset = .high
            #endif
        } catch {
            newSession.commitConfiguration()
            status = .failed(error.localizedDescription)
            return
        }

        newSession.commitConfiguration()
        self.session = newSession

        sessionQueue.async { [weak self] in
            self?.session?.startRunning()
            Task { @MainActor in
                self?.status = .running
            }
        }
    }
}
