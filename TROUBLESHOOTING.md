# Troubleshooting Build Errors

## 🔍 First: Get the Exact Error Message

In Xcode:
1. Press **⌘5** to open the Issue Navigator (left sidebar)
2. Look for red error icons 🔴
3. Click on each error to see details
4. **Share these error messages** so I can fix them!

## Common Build Errors & Fixes

### 1. "No such module 'SwiftUI'" or similar

**Fix:**
- Xcode → Preferences → Locations
- Make sure "Command Line Tools" is set
- Restart Xcode

### 2. "Signing for 'OperaApp' requires a development team"

**Fix:**
1. Click on **OperaApp** project (blue icon) in Project Navigator
2. Select **OperaApp** target
3. Go to **Signing & Capabilities** tab
4. Choose your Team (or set to None for simulator only)
5. Or: Uncheck "Automatically manage signing" and back on

### 3. "Cannot find type X in scope" errors

This means files aren't being compiled. **Fix:**
1. In Project Navigator, select **OperaApp** project
2. Select **OperaApp** target
3. Go to **Build Phases** tab
4. Expand **Compile Sources**
5. Check that ALL .swift files are listed (should be 23 files)
6. If any are missing, click **+** and add them

### 4. "Duplicate symbol" or "Redefinition" errors

**Fix:**
- Make sure no files are added twice in Build Phases
- Clean Build Folder: **⇧⌘K**
- Build again: **⌘B**

### 5. Deployment Target Mismatch

**Fix:**
1. Select OperaApp project
2. Select OperaApp target
3. General tab → Minimum Deployments → iOS **16.0**

### 6. "Info.plist file not found"

**Fix:**
1. Select OperaApp target
2. Build Settings tab
3. Search for "Info.plist"
4. Set to: `OperaApp/Info.plist`

## 🧹 Nuclear Option: Clean Everything

If nothing works:

```bash
# 1. Close Xcode completely

# 2. Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/OperaApp-*

# 3. Reopen project
open /Users/ivantolmachev/Documents/Workshop/threee/OperaApp.xcodeproj

# 4. In Xcode: Product → Clean Build Folder (⇧⌘K)

# 5. Build: ⌘B
```

## 📝 Share Error Details

If none of these work, share:

1. **Exact error message(s)** from Issue Navigator
2. **Screenshot** of the error
3. **Xcode version**: Xcode → About Xcode
4. **macOS version**: System Preferences → About This Mac

I'll provide a specific fix!

## ✅ Expected Files in Build Phases

Your "Compile Sources" should have 23 files:
- OperaAppApp.swift
- ContentView.swift
- AppState.swift
- User.swift
- Opera.swift
- UserList.swift
- Recommendation.swift
- AuthenticationService.swift
- APIService.swift
- OnboardingView.swift
- TasteOnboardingView.swift
- MainTabView.swift
- HomeView.swift
- SearchView.swift
- OperaDetailView.swift
- ProductionDetailView.swift
- LogFlowView.swift
- ListsView.swift
- RecommendationsView.swift
- ProfileView.swift
- SettingsView.swift
- AddToListView.swift

## 🚀 Quick Test

Try this simple test:
1. **⌘B** to build (don't run yet)
2. Does it succeed? ✅ Great! Now **⌘R** to run
3. Does it fail? ❌ Share the error message

---

**Still stuck?** Copy/paste the error message here and I'll fix it immediately!

