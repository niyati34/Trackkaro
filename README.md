# TrackKaro – Admin App

Introducing our innovative fleet management system designed for real-time tracking of school buses, ensuring safety and efficiency for students and institutions.

With advanced GPS technology, you can monitor bus locations live, enhancing route planning and security.

Our facial recognition boarding system provides secure student access, while the punch in/punch out feature automatically logs attendance as students board and exit the bus.

Developed with Flutter, our user-friendly app offers a seamless experience across devices.

Enjoy benefits like enhanced safety, operational efficiency through automation, and peace of mind for parents with real-time notifications about their child's bus status. Transform the way you manage your fleet and ensure a safer journey for every student.

## Repository layout

- dmin-app/ – Flutter Admin application source (this is the app you run/build)
- TrackKaro_Desktop_App/ – Prebuilt Windows desktop bundle (binary artifact)

## Run the Admin app locally

Requirements:
- Flutter SDK (3.x)
- Dart SDK (bundled with Flutter)
- Platform tooling as needed (Chrome for web, Visual Studio for Windows desktop)

From the dmin-app directory:

`powershell
# Install dependencies
flutter pub get

# Run on your preferred device
flutter devices
flutter run -d chrome          # Web
# flutter run -d windows       # Windows desktop
# flutter run -d <device_id>   # Android/iOS if configured
`

Run tests:

`powershell
flutter test
`

## Build

`powershell
# Web
flutter build web

# Windows desktop (requires Visual Studio with Desktop development with C++)
flutter build windows
`

## Notes on binaries and large files

This repository currently contains prebuilt binaries and a ZIP in the root. For a cleaner Git history and faster clones, consider moving large artifacts to Git LFS or releases. If you want, we can migrate these and update history accordingly.

## Helpful links

- Flutter docs: https://docs.flutter.dev/
- Packages: https://pub.dev/
