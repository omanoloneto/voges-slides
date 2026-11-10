# Voges Slides

Simple presentations for the desktop: write slides with titles, text, shapes and pictures, present them full screen, and open and save `.pptx`. Part of the Voges suite, next to [Voges Word](https://github.com/omanoloneto/voges-word), [Voges Pencil](https://github.com/omanoloneto/voges-pencil) and [Voges Tables](https://github.com/omanoloneto/voges-tables). Built with Flutter for macOS, Windows and Linux.

Installers are not published yet; for now, build it from the source (see [Build](#build)).

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
- Warns before closing or opening another file with unsaved changes, and opens files from the system's "Open with" and from the command line.
- Interface in English, Portuguese and Spanish. It follows the system language, and you can pick another one in the File menu.

## Build

Requires [Flutter](https://docs.flutter.dev/get-started/install) 3.41 or newer.

```sh
flutter pub get
flutter run -d macos     # or windows, linux
flutter test
```
