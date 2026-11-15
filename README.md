# Elderly Care App

Elderly Care App is a Flutter-based mobile application designed to support seniors, their families, and volunteers in a connected care ecosystem. The app helps older adults manage daily needs, communicate with family members, receive support from volunteers, and access emergency assistance when needed.

## Overview

This project brings together three main user groups:

- Seniors who need support with daily routines, appointments, and health-related tasks
- Family members who want to stay involved and monitor the wellbeing of their loved ones
- Volunteers who can respond to requests and assist with day-to-day support

The app combines communication, scheduling, emergency features, location-aware services, and a simple user experience tailored for elderly users.

## Key Features

- Role-based access for seniors, family members, and volunteers
- Secure login and registration flow
- Daily needs tracking for seniors
- Appointment management
- Family connection and monitoring features
- Volunteer matching and availability tracking
- Emergency assistance and emergency contact support
- Notification support for reminders and alerts
- Firebase-powered authentication and data storage
- Location and map support for emergency and family coordination
- Profile management for each user type

## Tech Stack

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Messaging
- OneSignal
- Google Maps
- Geolocator
- Sensors Plus
- Provider for state management

## Project Structure

```text
elderly_care_app/
├── android/
├── ios/
├── lib/
│   ├── models/
│   ├── screens/
│   ├── services/
│   ├── utils/
│   ├── widgets/
│   ├── firebase_options.dart
│   └── main.dart
├── assets/
├── test/
├── analysis_options.yaml
├── firebase.json
├── pubspec.yaml
├── .firebaserc
├── .gitignore
└── README.md
```

## Getting Started

### Prerequisites

Before running the app, make sure you have the following installed:

- Flutter SDK
- Dart SDK
- Android Studio or VS Code with Flutter tools
- A Firebase project configured for Android and iOS

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run
```

## Firebase Setup

This app uses Firebase for user authentication, storage, messaging, and backend data services. If you are setting up the project from scratch, connect this app to your own Firebase project and regenerate the Firebase configuration files if needed.

## App Flow

The application is organized around a simple care workflow:

1. Users create an account and choose their role.
2. Seniors set up their daily needs and preferences.
3. Family members connect with seniors and stay informed.
4. Volunteers receive assigned tasks and manage availability.
5. Emergency services and contact features are available when needed.

## Notes

This project is built as a practical care support application and is intended to improve communication and assistance between elderly users, family members, and volunteers.

## Contributing

Contributions are welcome. If you want to improve the app, fix a bug, or add a new feature, feel free to open an issue or submit a pull request.

## Contact

For questions or collaboration, please reach out through the repository owner or project maintainer.
