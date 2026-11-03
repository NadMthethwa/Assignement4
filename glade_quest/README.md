# Glade Quest (Flutter)

A small retro top-down adventure built mobile-first for Android phones.
Collect every gem and defeat every beetle to save the glade.

## Controls
- **Move:** touch anywhere on the left/joystick side and drag. The stick appears under your thumb and is analog, so a small drag walks slowly.
- **Strike:** tap the big ⚔ button. Each tap is one sword sweep in the direction you face.
- **Pause:** the pause button in the top bar. The game also pauses by itself when you leave the app.
- Works in portrait (controls below the map) and landscape (controls on either side). Your phone vibrates when you get hit, land a hit, or pick something up.
- A keyboard also works (WASD/arrows, Space to strike, P to pause), which helps when testing on an emulator.

## Rules
- 5 hearts. Touching a beetle costs 1 heart, knocks you back, and makes you invincible for 1 second (you blink).
- Beetles wander, and chase you when you get close. They take 3 hits each and can drop a heart.
- Trees, the cottage, the keep and the pond are solid.

## Getting the APK
Every push that changes this folder runs `.github/workflows/build-apk.yml` on GitHub Actions. It tests the game, builds a release APK and attaches it to the **`apk-latest`** release on the repo's Releases page. Open that page on your phone, download `glade-quest.apk`, and allow your browser to install unknown apps.

## Building locally
Needs the Flutter SDK (3.47+) and the Android SDK.

```bash
flutter pub get
flutter test
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

## Code layout
- `lib/game.dart`: game rules (movement, collisions, combat, pickups, win/lose). No Flutter widgets.
- `lib/painter.dart`: draws the world.
- `lib/main.dart`: app shell, responsive layout, touch joystick, attack button, HUD, overlays.
- `test/widget_test.dart`: tests for game mechanics and layout.
