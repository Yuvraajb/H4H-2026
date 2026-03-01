//
//  BackendLauncher.swift
//  Survivor MVP
//
//  Launches the Python backend automatically on app start.
//  Checks if port 8000 is already live before spawning a new process.
//

import Foundation

@MainActor
final class BackendLauncher {

    static let shared = BackendLauncher()

    private var process: Process?

    /// Call once at app launch. No-ops if backend is already up.
    func startIfNeeded() {
        Task.detached { [weak self] in
            guard let self else { return }
            if await self.isHealthy() { return }   // already running
            await self.launch()
        }
    }

    func stop() {
        process?.terminate()
        process = nil
    }

    // MARK: - Private

    private func launch() async {
        // Locate python3
        let python = await resolvedPython()

        // Backend lives next to the app bundle in development; fall back to /tmp path
        let backendDir = resolvedBackendDir()
        guard let backendDir else { return }

        let runScript = backendDir.appendingPathComponent("run.py")
        guard FileManager.default.fileExists(atPath: runScript.path) else { return }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: python)
        proc.arguments = [runScript.path]
        proc.currentDirectoryURL = backendDir

        // Inherit environment so virtual-env / system packages are visible
        var env = ProcessInfo.processInfo.environment
        // Ensure .env variables are injected from the backend directory
        if let envVars = parseDotEnv(at: backendDir.appendingPathComponent(".env")) {
            for (k, v) in envVars { env[k] = v }
        }
        proc.environment = env

        // Suppress backend stdout/stderr in the app console (it goes to system log)
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError  = FileHandle.nullDevice

        do {
            try proc.run()
            process = proc
        } catch {
            return  // python not found or script missing — fail silently
        }

        // Wait up to 8 s for the server to become healthy
        for _ in 0..<16 {
            try? await Task.sleep(for: .milliseconds(500))
            if await isHealthy() { return }
        }
    }

    private func isHealthy() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:8000/health") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2
        return (try? await URLSession.shared.data(for: req)) != nil
    }

    private func resolvedPython() async -> String {
        for candidate in ["/usr/bin/python3", "/usr/local/bin/python3", "/opt/homebrew/bin/python3"] {
            if FileManager.default.fileExists(atPath: candidate) { return candidate }
        }
        return "python3"  // rely on PATH
    }

    private func resolvedBackendDir() -> URL? {
        // 1. Sibling of the .app bundle (dev layout: /tmp/H4H-2026/backend)
        let bundleParent = Bundle.main.bundleURL.deletingLastPathComponent()
        let sibling = bundleParent.appendingPathComponent("backend")
        if FileManager.default.fileExists(atPath: sibling.appendingPathComponent("run.py").path) {
            return sibling
        }
        // 2. Hardcoded dev path as fallback
        let dev = URL(fileURLWithPath: "/tmp/H4H-2026/backend")
        if FileManager.default.fileExists(atPath: dev.appendingPathComponent("run.py").path) {
            return dev
        }
        return nil
    }

    /// Minimal .env parser: returns key=value pairs, ignoring comments and blanks.
    private func parseDotEnv(at url: URL) -> [String: String]? {
        guard let content = try? String(contentsOf: url) else { return nil }
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), trimmed.contains("=") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            if parts.count == 2 { result[parts[0]] = parts[1] }
        }
        return result
    }
}
