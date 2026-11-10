#!/usr/bin/env bash
set -euo pipefail

version="${1:?version, such as 1.0.0}"
bundle="${2:?build/linux/x64/release/bundle folder}"
output="${3:?output .deb file}"

here="$(cd "$(dirname "$0")" && pwd)"
app_id=com.omanoloneto.voges_slides
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT
chmod 755 "$root"

mkdir -p "$root/DEBIAN" "$root/usr/lib/voges-slides" "$root/usr/bin" \
  "$root/usr/share/applications" "$root/usr/share/icons/hicolor/256x256/apps"
cp -r "$bundle/." "$root/usr/lib/voges-slides/"
ln -s ../lib/voges-slides/voges_slides "$root/usr/bin/voges-slides"
install -m 644 "$here/$app_id.desktop" "$root/usr/share/applications/"
convert "$here/../../assets/icon/icon_rounded.png" -resize 256x256 \
  "$root/usr/share/icons/hicolor/256x256/apps/$app_id.png"

# zenity (or kdialog) provides the open and save dialogs for file_picker
cat > "$root/DEBIAN/control" <<CONTROL
Package: voges-slides
Version: $version
Section: office
Priority: optional
Architecture: amd64
Depends: libgtk-3-0t64 | libgtk-3-0, zenity | kdialog
Maintainer: omanoloneto <mano.afonso93@gmail.com>
Homepage: https://omanoloneto.pro/voges/slides/
Description: simple presentations
 Voges Slides makes presentations with titles, text, shapes and
 pictures, presents them full screen, opens PPTX, PPSX and POTX files
 and saves PPTX.
CONTROL

dpkg-deb --build --root-owner-group "$root" "$output"
