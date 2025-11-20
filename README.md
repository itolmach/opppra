# Opera - Your Personal Opera Journal

An elegant iOS app for opera enthusiasts to track performances, discover new works, and manage their opera journey. Think IMDB meets personal journal, built specifically for opera lovers.

## Features

### 🎭 Core Functionality

- **Search & Discover**: Browse a comprehensive catalog of opera works, productions, venues, and artists
- **Personal Lists**: Organize operas into "Wanna Experience" and "Have Experienced" lists, plus custom collections
- **Attendance Logging**: Document your opera experiences with:
  - OCR ticket/playbill scanning for automatic data extraction
  - Detailed ratings (overall, music, singers, production)
  - Personal notes and tags
  - Photo attachments
  
- **Smart Recommendations**: AI-powered suggestions based on your taste profile
- **Production Information**: 
  - Upcoming performances with venue details
  - Cast and creative team information
  - Ticket purchasing links
  - Venue information with location data

### 🌟 Key Screens

1. **Onboarding** - Privacy-first account creation with taste profile setup
2. **Home** - Personalized dashboard with upcoming recommendations and season stats
3. **Search** - Real-time search with filters and typeahead
4. **Opera Detail** - Comprehensive information about each work
5. **Production Detail** - Specific production information with performance schedules
6. **Log Flow** - Attendance logging with OCR scanning
7. **Lists** - Manage your collections and wishlists
8. **Recommendations** - Discover new operas tailored to your taste
9. **Profile** - View your stats and share your opera journey
10. **Settings** - Privacy controls, notifications, and account management

## Architecture

### Tech Stack

- **Framework**: SwiftUI
- **Minimum iOS**: 16.0
- **Language**: Swift 5.0
- **Architecture**: MVVM (Model-View-ViewModel)

### Project Structure

```
OperaApp/
├── OperaAppApp.swift          # App entry point
├── ContentView.swift          # Root view with auth flow
├── Core/
│   └── AppState.swift         # Global app state
├── Models/
│   ├── User.swift            # User and profile models
│   ├── Opera.swift           # Opera, Production, Venue models
│   ├── UserList.swift        # Lists and attendance logs
│   └── Recommendation.swift  # Recommendation models
├── Services/
│   ├── AuthenticationService.swift  # Auth and session management
│   └── APIService.swift             # Network layer
├── Views/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── TasteOnboardingView.swift
│   ├── Main/
│   │   └── MainTabView.swift
│   ├── Home/
│   │   └── HomeView.swift
│   ├── Search/
│   │   └── SearchView.swift
│   ├── Opera/
│   │   └── OperaDetailView.swift
│   ├── Production/
│   │   └── ProductionDetailView.swift
│   ├── Log/
│   │   └── LogFlowView.swift
│   ├── Lists/
│   │   └── ListsView.swift
│   ├── Recommendations/
│   │   └── RecommendationsView.swift
│   ├── Profile/
│   │   └── ProfileView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Shared/
│       └── AddToListView.swift
└── Assets.xcassets/
```

## Getting Started

### Prerequisites

- Xcode 15.0 or later
- macOS 13.0 (Ventura) or later
- iOS 16.0+ device or simulator

### Installation

1. Clone the repository:
```bash
cd /Users/ivantolmachev/Documents/Workshop/threee
```

2. Open the project in Xcode:
```bash
open OperaApp.xcodeproj
```

3. Select your target device/simulator

4. Build and run (⌘R)

### Configuration

#### API Endpoint

The app currently uses mock data. To connect to a real backend:

1. Open `OperaApp/Services/APIService.swift`
2. Update the `baseURL` constant with your API endpoint:
```swift
private let baseURL = "https://your-api-endpoint.com/v1"
```

#### Authentication

The app includes basic authentication scaffolding. To implement Sign in with Apple:

1. Enable Sign in with Apple in your Apple Developer account
2. Add the capability in Xcode: Target → Signing & Capabilities → + Sign in with Apple
3. Implement the Apple authentication in `AuthenticationService.swift`

## Features Roadmap

### Current (MVP)

- ✅ User authentication
- ✅ Opera search and discovery
- ✅ Personal lists management
- ✅ Attendance logging
- ✅ Basic recommendations
- ✅ Profile management

### Next Steps

- [ ] Real backend API integration
- [ ] OCR implementation for ticket scanning
- [ ] Social features (follow users, share logs)
- [ ] Advanced filtering and sorting
- [ ] Offline mode with local caching
- [ ] Calendar integration
- [ ] Location-based venue discovery
- [ ] Push notifications for upcoming performances
- [ ] In-app ticket purchasing
- [ ] Audio/video previews of operas
- [ ] Advanced analytics (your opera journey over time)

## Design Principles

### Privacy-First
- User data stays private by default
- Granular privacy controls
- Easy data export
- Clear data deletion process

### Beautiful & Modern UI
- Dark theme optimized for theater-going
- Serif fonts for elegance
- Smooth animations and transitions
- Consistent design language

### User Experience
- Quick actions prioritized (Search, Log)
- Minimal taps to accomplish tasks
- Smart defaults and autocomplete
- Offline-capable core features

## API Integration Guide

### Expected Backend Endpoints

```
Authentication:
POST   /auth/signup
POST   /auth/signin
POST   /auth/signout
GET    /auth/profile

Operas:
GET    /operas
GET    /operas/:id
GET    /operas/:id/productions
GET    /operas/search?q=

Productions:
GET    /productions
GET    /productions/:id
GET    /productions/upcoming

Lists:
GET    /lists
POST   /lists
PUT    /lists/:id
DELETE /lists/:id
POST   /lists/:id/items
DELETE /lists/:id/items/:itemId

Logs:
GET    /logs
POST   /logs
PUT    /logs/:id
DELETE /logs/:id

Recommendations:
GET    /recommendations
POST   /recommendations/:id/feedback

OCR:
POST   /ocr/ticket (multipart/form-data)
```

## Contributing

This is a personal project, but suggestions and feedback are welcome!

## License

MIT License - See LICENSE file for details

## Contact

For questions or feedback, please open an issue in the repository.

---

**Note**: This app is currently in development. Mock data is used throughout. A production backend API is required for full functionality.

