# Run the redesigned emergency UI (4-panel layout)

To see the **new UI** (camera + left Guidance panel + right Chat / Menu / Actions panels):

1. **In Xcode:** Choose **Product → Scheme → Survivor MVP Mac** (not "Survivor MVP").
2. **Run:** Press **⌘R** or click the Run button.
3. The window title will be **"Survivor MVP Mac"** and you should see:
   - **Top-left:** "LIVE FEED" badge and "Aura Emergency"
   - **Left:** Panel labeled **"1. GUIDANCE"** (step-by-step instructions + diagram)
   - **Right:** **"2. CHAT"**, **"3. MENU"**, **"4. ACTIONS"** panels stacked

If you run **"Survivor MVP"** (visionOS) instead, you get a different target and the window/simulator will not show this Mac layout.

## From terminal (build + launch Mac app)

```bash
cd /Users/yuvraaj/dev/H4H-2026
xcodebuild -scheme "Survivor MVP Mac" -destination "generic/platform=macOS" build
open ~/Library/Developer/Xcode/DerivedData/Survivor_MVP-*/Build/Products/Debug/Survivor\ MVP\ Mac.app
```

**Easiest:** In Xcode, set scheme to **Survivor MVP Mac** and press **⌘R**.
