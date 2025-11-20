# Fix: Code Signing Error

## ✅ Quick Fix (Recommended for Simulator)

### Option 1: Automatic Signing (Easiest)

1. Open Xcode
2. In the **Project Navigator** (left panel), click on **OperaApp** (the blue project icon at the top)
3. In the main editor, select the **OperaApp** target (under TARGETS)
4. Click the **Signing & Capabilities** tab at the top
5. Under "Signing":
   - Check the box: ✅ **"Automatically manage signing"**
   - In **Team** dropdown: Select your Apple ID or "(none)" for simulator only
   
6. Press **⌘R** to build and run!

### Option 2: Manual Signing (If Option 1 Doesn't Work)

1. Follow steps 1-4 above
2. **Uncheck** "Automatically manage signing"
3. Set **Signing Certificate** to: "Sign to Run Locally"
4. Press **⌘R** to build and run!

## 🎯 Visual Guide

```
Xcode Window:
┌─────────────────────────────────────────────────┐
│ OperaApp (project) ← Click this blue icon      │
│   ├─ OperaApp (target) ← Then click this       │
│   └─ Products                                    │
│                                                  │
│ Tabs: General | Signing & Capabilities | ...    │
│       ─────────────────────────────────         │
│                                                  │
│ ☐ Automatically manage signing                  │
│                                                  │
│ Team: [Your Apple ID ▼] or (none)              │
│                                                  │
│ Bundle Identifier: com.operaapp.OperaApp        │
└─────────────────────────────────────────────────┘
```

## 📱 For Simulator Testing (No Developer Account Needed)

You **don't need** a paid Apple Developer account to run on simulator!

Just select:
- Team: **(none)** or your free Apple ID
- Target device: **Any iOS Simulator** (iPhone 15 Pro, etc.)

## 🔧 If You Have an Apple Developer Account

If you're a paid developer:
1. Team: Select your team from dropdown
2. This allows running on real devices

## 🚀 After Fixing

Once you select a team (or none):
- The error will disappear ✅
- Press **⌘R** to run
- Your app will launch in the simulator! 🎭

---

**Still having issues?** Make sure you're targeting a **Simulator** (not "Any iOS Device" or a real device) in the device dropdown at the top of Xcode.

