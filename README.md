# NSCGSchedule

A student timetable and scheduling app for NSCG. This Flutter application helps students view timetables, exam schedules, notifications, and manage friends' schedules.

Key features
- View personal timetable and exam timetables.
- Notifications and schedule updates.
- Friends list, gaps, QR sharing, and profile views.
- Local encrypted storage with Hive.

Prerequisites
- Flutter SDK (stable channel) installed and configured.
- A connected device or emulator.

Quick start
1. Install dependencies:

	`flutter pub get`
2. Run on connected device or emulator:

	`flutter run`
3. Build release APK:

	`flutter build apk --release``

Project layout
- `lib/` — app source code (screens, services, models).
- `assets/` — images and icons.

Development notes
- Uses Hive for local persistence (see generated `hive_registrar.g.dart`).
- Routes and navigation defined in `lib/router.dart`.
- Background services and notifications in `lib/watch_service.dart` and `lib/notifications.dart`.

Contributing
- Open an issue to discuss changes.
- Fork, create a branch, and submit a pull request.

License
- See the `LICENSE` file for license details.

Contact
- If you're with the college, you can use C243879; please also open a GitHub issue so I'm aware to actually respond. For everyone else, opening a GitHub issue is the best way to get my attention — I check issues and will respond as soon as I can.
