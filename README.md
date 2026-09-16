# CoreHives

Internal finance and employee-management platform with a Flutter mobile client, Firebase-backed services, and supporting web/cloud components.

## Overview

CoreHives is built for internal operational use, bringing employee, payroll, transaction, notification, and finance workflows into a single system. The repository contains the Flutter mobile application together with Firebase/cloud-function and web support code.

## Mobile stack

- Flutter / Dart
- Riverpod for state management
- GoRouter for navigation
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Functions
- Firebase Cloud Messaging
- Firebase Crashlytics
- Freezed / JSON serialization

## Main mobile modules

- Authentication and session handling
- Employee management
- Payroll workflows
- Transaction management
- Notifications
- User profile
- Application configuration
- Internal home/dashboard experience

## Repository structure

```text
corehives/
├── mobile/       Flutter mobile application
├── web/          Web application/supporting frontend
├── functions/    Firebase Cloud Functions
├── firebase/     Firebase-related configuration/resources
├── scripts/      Project tooling and scripts
└── update.json   Internal application update metadata
```

## Run the Flutter application

```bash
cd mobile
flutter pub get
flutter run
```

For a release APK:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

## Internal distribution

CoreHives includes an internal update flow for distributing Android builds outside the Play Store. See [`UPDATE_SYSTEM.md`](UPDATE_SYSTEM.md) for the repository's update-system notes.

## Security

Do not commit private Firebase service-account credentials, production secrets, signing keys, or environment-specific credentials. Configure sensitive values outside source control.

## License

This repository is publicly visible for portfolio and demonstration purposes. **All Rights Reserved.** The source code may not be copied, modified, redistributed, sold, sublicensed, or incorporated into another project without prior written permission from the copyright owner. See [`LICENSE`](LICENSE).
