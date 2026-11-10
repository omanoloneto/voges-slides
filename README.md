# Voges Slides

Simple presentations for the desktop: write slides with titles, text, shapes and pictures, present them full screen, and open and save `.pptx`. Part of the Voges suite, next to [Voges Word](https://github.com/omanoloneto/voges-word), [Voges Pencil](https://github.com/omanoloneto/voges-pencil) and [Voges Tables](https://github.com/omanoloneto/voges-tables). Built with Flutter for macOS, Windows and Linux.

## Install

The installers are in the [latest release](https://github.com/omanoloneto/voges-slides/releases/latest) and on the [omanoloneto.pro/voges/slides](https://omanoloneto.pro/voges/slides/) page.

- **macOS** 10.15 or newer, Apple Silicon and Intel: [`VogesSlides-macos.dmg`](https://github.com/omanoloneto/voges-slides/releases/latest/download/VogesSlides-macos.dmg). Open it and drag Voges Slides to Applications. The app is not notarized by Apple; the first time, allow it in System Settings → Privacy & Security → Open Anyway.
- **Windows** 10 or 11, 64-bit: [`VogesSlides-windows-setup.exe`](https://github.com/omanoloneto/voges-slides/releases/latest/download/VogesSlides-windows-setup.exe). It installs without administrator rights and shows up in "Open with" for `.pptx`, `.ppsx` and `.potx`, without becoming the default program. If SmartScreen warns you, click "More info" and then "Run anyway".
- **Linux** (Ubuntu 22.04, Debian 12 or newer and derivatives, 64-bit): [`voges-slides-linux-amd64.deb`](https://github.com/omanoloneto/voges-slides/releases/latest/download/voges-slides-linux-amd64.deb), then `sudo apt install ./voges-slides-linux-amd64.deb`.

`SHA256SUMS.txt` in each release lists the SHA-256 of every installer, and `SHA256SUMS.txt.sig` is its signature.

### Updates

Voges Slides checks for a new version every time it opens and says in the status bar whether it is up to date. When there is an update, clicking it asks about unsaved changes, closes the app and opens **Voges Updater**, which lists every installed app of the Voges suite that has an update; update all of them or only some. When it finishes, Voges Slides opens again.

- The check reads the number of the latest release from github.com; nothing about you or your presentations is sent.
- Every update is verified before it is installed: its files must match the `SHA256SUMS.txt` of the release, and that file must carry the Ed25519 signature of the project's key, which is built into the app. A download that doesn't match is never installed.
- **macOS:** the updater replaces the app in its folder; if your account can't write to it, it puts the verified `.dmg` in Downloads for you to install. Voges Slides stays sandboxed: the updater is a separate app inside it (`Contents/Helpers/Voges Updater.app`).
- **Windows:** the installer runs silently; installs for all users ask for administrator permission.
- **Linux:** the update is installed with `apt`, after the system asks for your password (polkit). Without a password window, the updater shows the command to run in a terminal.

## What it does

- **Slides:** add slides from four layouts (title slide, title and content, title only, blank), duplicate, delete and reorder them in the panel on the left, and give each one, or all of them, a background color.
- **Text:** click a placeholder or a text box and type. Font, size, bold, italic, underline, strikethrough and color; align left, center, right or justified; bullets and numbering with levels (Tab and Shift+Tab); text at the top, middle or bottom of its shape. Shift+Enter breaks the line inside the paragraph.
- **Shapes:** rectangle, rounded rectangle, ellipse, triangles, diamond, pentagon, hexagon, star, block arrows, lines and arrows, each with fill color, outline color and outline width, and with text inside.
- **Pictures:** insert PNG, JPEG, GIF, BMP and WebP files.
- **Arranging:** drag to move, pull the handles to resize (Shift keeps the proportions) and rotate (Shift snaps to 15°), nudge with the arrows, select several with Shift or by dragging a box around them, bring forward and send backward, duplicate, and copy, cut and paste between slides.
- **Slideshow:** F5 presents from the first slide and Shift+F5 from the current one, full screen. Arrows, Space, Enter and clicks move through the slides; Esc leaves.
- **Editing:** undo and redo for every change; typing is undone a word at a time.
- **Files:** opens `.pptx`, `.ppsx` and `.potx`, with the look the slides inherit from their theme, master and layout, and saves `.pptx`. What is not supported yet (tables, charts, speaker notes, animations and transitions) is left out when a file is opened; the app says so and saves to a new file, so the original stays as it is.
- The status bar shows which slide is open and the zoom (25% to 400%; Ctrl or ⌘ with the mouse wheel).
- Warns before closing or opening another file with unsaved changes, and opens files from the system's "Open with" (on macOS and, through the installers, Windows and Linux, without becoming the default app) and from the command line.
- Updates itself on macOS, Windows and Linux: the status bar shows when a new version exists (see [Updates](#updates)).
- Interface in English, Portuguese and Spanish. It follows the system language, and you can pick another one in the File menu.

## Build

Requires [Flutter](https://docs.flutter.dev/get-started/install) 3.41 or newer.

```sh
flutter pub get --enforce-lockfile
flutter run -d macos     # or windows, linux
flutter test
```

Updates come from the `voges_updater` package of [Voges Word](https://github.com/omanoloneto/voges-word/tree/main/packages/voges_updater), a git dependency pinned to a commit in `pubspec.yaml` and `pubspec.lock`; `--enforce-lockfile` gets the locked commit.

## Releases

1. Set the new `version` in `pubspec.yaml` and write `packaging/release-notes.md`.
2. Push a `vX.Y.Z` tag with the same version. `.github/workflows/release.yml` builds the three installers (the macOS one with Voges Updater embedded) and creates a draft release with them and `SHA256SUMS.txt`.
3. Sign and publish the draft on the owner's Mac, from a Voges Word checkout:

   ```sh
   cd packages/voges_updater
   dart run tool/release_signing.dart publish omanoloneto/voges-slides vX.Y.Z --clone <path to the voges-slides clone>
   ```

Release builds pass `--dart-define=VOGES_VERSION=<version>`; without it, as in `flutter run`, the update indicator stays hidden.
