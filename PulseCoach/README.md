# PulseCoach — First Aid Copilot

PulseCoach (Survivor MVP) is a spatial first-aid assistant with a 3-column UI: left rail, main copilot, and visual instructions including live camera preview.

## Structure

- **macos/** — macOS app (live webcam in simulator/device). Open `Survivor MVP.xcodeproj` and use the **Survivor MVP Mac** scheme.
- **visionos/** — visionOS app (Apple Vision Pro). Open `Survivor MVP.xcodeproj` and use the **Survivor MVP** scheme.

Both folders contain the same Xcode project with two targets; use the scheme that matches the folder when building.

## Requirements

- Xcode with visionOS and macOS SDKs
- macOS 14+ for the Mac app
- visionOS 26+ for the Vision Pro app

## Camera

- **macOS:** Allow camera permission when prompted; the right panel shows live webcam.
- **visionOS simulator:** Camera is typically unavailable; a placeholder is shown. On device, behavior depends on platform support.
