import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:voges_updater/core.dart';

// Voges Updater finds and replaces Voges Slides by the names in its catalog,
// so the build files must use exactly those names.
String _read(String path) => File(
  p.joinAll([Directory.current.path, ...p.posix.split(path)]),
).readAsStringSync();

String? _first(String pattern, String text) =>
    RegExp(pattern, multiLine: true).firstMatch(text)?[1];

void main() {
  const app = vogesSlides;
  final installers = {app.macos.asset, app.windows.asset, app.linux.asset};
  final workflow = _read('.github/workflows/release.yml');

  test('the release workflow checksums exactly the catalog assets', () {
    final command = RegExp(r'sha256sum\s([^>]*)>\s*(\S+)').firstMatch(workflow);
    expect(command, isNotNull);
    final listed = command![1]!
        .split(RegExp(r'[\s\\]+'))
        .where((name) => name.isNotEmpty);
    expect(listed.toSet(), installers);
    expect(listed, hasLength(installers.length));
    expect(command[2], checksumsAsset);

    final uploaded = RegExp(
      r'^\s*path:\s*(\S+)\s*$',
      multiLine: true,
    ).allMatches(workflow).map((match) => p.posix.basename(match[1]!));
    expect(uploaded, containsAll(installers));
  });

  test('the draft release carries the installers and the checksums', () {
    final create = RegExp(
      r'gh release create ((?:[^\n]*\\\n)*[^\n]*)',
    ).firstMatch(workflow);
    expect(create, isNotNull);
    final files = RegExp(
      r'dist/(\S+)',
    ).allMatches(create![1]!).map((match) => match[1]!);
    expect(files.toSet(), {...installers, checksumsAsset});
    expect(files, hasLength(installers.length + 1));
  });

  test('every build installs the locked voges_updater commit', () {
    final gets = RegExp(r'flutter pub get[^\n]*').allMatches(workflow);
    expect(gets, isNotEmpty);
    for (final get in gets) {
      expect(get[0], contains('--enforce-lockfile'));
    }
  });

  test('the Windows installer has the catalog AppId and executable', () {
    final setup = _read('packaging/windows/voges_slides.iss');
    // Inno Setup writes the opening brace of the AppId as {{
    expect(_first(r'^AppId=\{(\{[0-9A-F-]+\})\r?$', setup), app.windows.appId);
    expect(_first(r'^#define AppExe "([^"]+)"', setup), app.windows.executable);
    expect(
      '${_first(r'^OutputBaseFilename=(\S+?)\r?$', setup)}.exe',
      app.windows.asset,
    );
    expect(
      '${_first(r'^set\(BINARY_NAME "([^"]+)"\)', _read('windows/CMakeLists.txt'))}.exe',
      app.windows.executable,
    );
  });

  test('the Debian package has the catalog package, binary and launcher', () {
    final script = _read('packaging/linux/build_deb.sh');
    expect(_first(r'^Package: (\S+)$', script), app.linux.package);
    expect(_first(r'^Architecture: (\S+)$', script), 'amd64');
    expect(app.linux.asset, endsWith('-amd64.deb'));

    final link = RegExp(r'ln -s (\S+) "\$root(/\S+)"').firstMatch(script);
    expect(link, isNotNull);
    expect(link![2], app.linux.launcher);
    expect(
      p.posix.normalize(p.posix.join(p.posix.dirname(link[2]!), link[1]!)),
      app.linux.binary,
    );
    expect(
      script,
      contains(
        'cp -r "\$bundle/." "\$root${p.posix.dirname(app.linux.binary)}/"',
      ),
    );
    expect(
      _first(r'^set\(BINARY_NAME "([^"]+)"\)', _read('linux/CMakeLists.txt')),
      p.posix.basename(app.linux.binary),
    );
  });

  test('the macOS app and .dmg have the catalog bundle id and names', () {
    final info = _read('macos/Runner/Configs/AppInfo.xcconfig');
    expect(
      _first(r'^PRODUCT_BUNDLE_IDENTIFIER = (\S+)$', info),
      app.macos.bundleId,
    );
    expect(
      '${_first(r'^PRODUCT_NAME = (.+)$', info)}.app',
      app.macos.bundleName,
    );

    final dmg = RegExp(r'build_dmg\.sh "\$app" (\S+)').firstMatch(workflow);
    expect(dmg?[1], app.macos.asset);
    expect(
      _first(r'^\s*app="build/macos/Build/Products/Release/([^"]+)"', workflow),
      app.macos.bundleName,
    );
  });
}
