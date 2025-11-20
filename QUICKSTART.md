# Quick Start Guide - Opera iOS App

## What You've Got

A fully-featured iOS app for opera enthusiasts with **10 complete screens** matching your Figma spec, built with SwiftUI and ready to run.

## 🚀 Running the App

### Option 1: Xcode (Recommended)

1. Open the project:
```bash
open OperaApp.xcodeproj
```

2. Select a simulator (iPhone 15 Pro recommended) or connect your device

3. Hit **⌘R** to build and run

### Option 2: Command Line

```bash
xcodebuild -project OperaApp.xcodeproj -scheme OperaApp -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

## 📱 App Flow

### First Launch
1. **Onboarding** - Create account (email or Sign in with Apple)
2. **Taste Profile** - Select favorite composers, eras, and opera houses
3. Automatically redirects to main app

### Main Experience
- **Home Tab** - Personalized dashboard with quick actions
- **Search Tab** - Find operas, productions, venues
- **Lists Tab** - Manage "Wanna Experience" and "Have Experienced" lists
- **Profile Tab** - View stats and manage account

### Key Actions
- **Log Attendance** - Tap ticket icon on Home (includes OCR scanning UI)
- **Add to List** - From any opera detail view
- **Search** - Real-time search with filters

## 🎨 Features Implemented

### ✅ All 10 Screens Complete

1. **01_Onboarding** - Auth with email/password or Apple
2. **02_Home** - Dashboard with season stats and recommendations
3. **03_Search** - Typeahead search with filters
4. **04_Work** - Opera detail with synopsis, recordings, productions
5. **05_Production** - Production detail with cast, performances, venue info
6. **06_LogFlow** - Multi-step attendance logging with OCR scanning
7. **07_Lists** - Custom lists and wishlist management
8. **08_Recommendations** - Personalized suggestions with feedback
9. **09_Profile** - User stats and privacy controls
10. **10_Settings** - Privacy, notifications, account management

### ✅ Core Functionality

- **Authentication** - Sign in/up with local storage persistence
- **Navigation** - Tab-based with deep linking support
- **State Management** - MVVM pattern with ObservableObject
- **Network Layer** - APIService with mock data (ready for backend)
- **Data Models** - Complete models for Opera, Production, User, Lists, Logs
- **Privacy** - Camera, location, calendar permission handling

## 🔧 Current State

### Working (Mock Data)
- All UI screens render correctly
- Navigation flows work end-to-end
- Forms and interactions are functional
- Search has debouncing
- Lists can be created and managed (in-memory)

### Needs Backend Integration
- Replace mock data in `APIService.swift`
- Connect to your backend API
- Implement real OCR for ticket scanning
- Add real Sign in with Apple credentials

## 📝 Next Steps

### 1. Run It First
Just open and run to see the complete app in action!

### 2. Backend Integration
```swift
// In APIService.swift, update:
private let baseURL = "https://your-api.com/v1"

// Then implement real network calls instead of mock data
```

### 3. Add Real Data
- Import opera catalog to your backend
- Set up user authentication system
- Configure production database

### 4. OCR Implementation
```swift
// In LogFlowView, implement real OCR:
// Use Vision framework or third-party service
import VisionKit
```

### 5. Sign in with Apple
- Add capability in Xcode
- Configure Apple Developer account
- Implement authentication flow

## 🎭 Design Details

### Color Scheme
- **Background**: Black (#000000)
- **Primary**: White (#FFFFFF)
- **Accents**: Blue, Green, Red (contextual)
- **Opacity**: 0.05-0.8 for layers

### Typography
- **Titles**: Serif fonts (elegant opera aesthetic)
- **Body**: SF Pro (iOS system font)
- **Sizes**: 12pt (captions) to 56pt (hero titles)

### UI Patterns
- **Cards**: Rounded corners (12pt radius)
- **Buttons**: Primary (white), Secondary (outlined)
- **Gradients**: Subtle color overlays for image placeholders
- **Spacing**: Consistent 16pt/24pt rhythm

## 📦 Project Structure

```
OperaApp/
├── Core/               # App state and navigation
├── Models/             # Data models
├── Services/           # Auth, API, networking
├── Views/
│   ├── Onboarding/    # Auth and taste setup
│   ├── Main/          # Tab navigation
│   ├── Home/          # Dashboard
│   ├── Search/        # Search and filters
│   ├── Opera/         # Work details
│   ├── Production/    # Production details
│   ├── Log/           # Attendance logging
│   ├── Lists/         # List management
│   ├── Recommendations/
│   ├── Profile/       # User profile
│   ├── Settings/      # App settings
│   └── Shared/        # Reusable components
└── Assets.xcassets/   # Images and colors
```

## 🐛 Known Issues / TODO

- OCR is simulated (needs Vision framework integration)
- Images are placeholders (need asset pipeline)
- Backend is mocked (needs API integration)
- No persistence layer (add Core Data or Realm)
- Search is client-side (should be server-side)

## 💡 Tips

1. **Mock Data**: All data in `APIService.swift` is hardcoded. Perfect for UI testing!
2. **Dark Mode**: App is dark-first. Light mode not implemented.
3. **Permissions**: Camera/Location prompts work but don't affect functionality yet.
4. **State**: Closing app loses data (no persistence implemented).

## 🎯 Production Checklist

Before submitting to App Store:

- [ ] Add real backend API
- [ ] Implement data persistence (Core Data/Realm)
- [ ] Add actual opera catalog
- [ ] Implement real OCR
- [ ] Add analytics (optional)
- [ ] Test on physical devices
- [ ] Add crash reporting
- [ ] Implement proper error handling
- [ ] Add loading states everywhere
- [ ] Optimize images and assets
- [ ] Add app icon (1024x1024)
- [ ] Create screenshots for App Store
- [ ] Write privacy policy
- [ ] Set up TestFlight beta

## 🤝 Questions?

Check the main README.md for:
- Full feature list
- Architecture details
- API endpoint specs
- Contributing guidelines

---

**Ready to build something amazing!** 🎭✨

Open Xcode and hit ⌘R to see your opera app in action.

