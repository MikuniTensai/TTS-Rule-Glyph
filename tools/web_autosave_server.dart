import 'dart:convert';
import 'dart:io';

const _jsonEncoder = JsonEncoder.withIndent('  ');
const _validMapSymbols =
    '.#R><NvT456MWYZ-|QEFGDX^abc123@&%*\$ABCHK[]_LlPp(){}IOUVJS0789?!defghi';
const _validRules = {'STOP', 'PUSH', 'SWAP', 'MERGE'};
const _playerSymbols = [
  ['@'],
  ['%', '&'],
  ['*'],
  ['\$'],
];
const _playerPortals = ['I', 'O', 'U', 'V'];

Future<void> main(List<String> args) async {
  final port = args.isNotEmpty ? int.tryParse(args.first) ?? 8088 : 8088;
  final root = Directory.current;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

  print('Rule Glyph Lab Web');
  print('Folder: ${root.path}');
  print('URL: http://127.0.0.1:$port/');
  print('Autosave: enabled for rule_glyph_app/assets/levels.json');
  print('Press Ctrl+C to stop.');

  await for (final request in server) {
    try {
      if (request.method == 'POST' &&
          request.uri.path == '/__autosave_levels') {
        await _handleAutosave(request, root);
      } else if (request.method == 'GET' || request.method == 'HEAD') {
        await _serveStatic(request, root);
      } else {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
      }
    } on FormatException catch (e, stack) {
      stderr.writeln('FormatException during request: $e');
      stderr.writeln(stack);
      request.response.statusCode = HttpStatus.badRequest;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'ok': false, 'error': e.message}));
      await request.response.close();
    } catch (e, stack) {
      stderr.writeln('Request failed: $e');
      stderr.writeln(stack);
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('500 Internal Server Error');
        await request.response.close();
      } catch (_) {}
    }
  }
}

Future<void> _handleAutosave(HttpRequest request, Directory root) async {
  final raw = await utf8.decoder.bind(request).join();
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected JSON object');
  }

  _validateCampaignJson(decoded);

  final modes = decoded['levels_by_mode'] as Map<String, dynamic>;
  for (final mode in ['1', '2', '3', '4']) {
    final levels = modes[mode] as List<dynamic>;
    for (var i = 0; i < levels.length; i++) {
      levels[i]['id'] = i + 1;
    }
  }

  final soloLevels = modes['1'] as List<dynamic>;
  // Keep derived data deterministic and prevent base_levels drift.
  decoded['base_levels'] = soloLevels.take(22).toList();

  final androidAssets = Directory('${root.path}/rule_glyph_app/assets');
  if (!androidAssets.existsSync()) {
    androidAssets.createSync(recursive: true);
  }

  var removedLogoFloors = <Map<String, dynamic>>[];
  final logoFile = File('${androidAssets.path}/logo.png');
  if (logoFile.existsSync()) {
    removedLogoFloors = _removeAccidentalLogoFloors(
      decoded,
      logoFile.readAsBytesSync(),
    );
  }

  final levelsFile = File('${androidAssets.path}/levels.json');
  levelsFile.writeAsStringSync('${_jsonEncoder.convert(decoded)}\n');
  _writeSplitAssets(androidAssets, decoded);

  if (decoded.containsKey('custom_wall_image')) {
    final customWallBase64 = decoded['custom_wall_image'] as String;
    final wallFile = File('${androidAssets.path}/custom_wall.png');
    if (customWallBase64.isNotEmpty) {
      try {
        var base64Data = customWallBase64;
        if (base64Data.contains(',')) {
          base64Data = base64Data.substring(base64Data.indexOf(',') + 1);
        }
        final bytes = base64Decode(base64Data);
        wallFile.writeAsBytesSync(bytes);
        print('Autosave: wrote custom_wall.png (${bytes.length} bytes)');
      } catch (e) {
        stderr.writeln('Failed to write custom_wall.png: $e');
      }
    } else {
      try {
        final placeholderBytes = base64Decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=");
        wallFile.writeAsBytesSync(placeholderBytes);
        print('Autosave: reset custom_wall.png to placeholder');
      } catch (e) {
        stderr.writeln('Failed to reset custom_wall.png: $e');
      }
    }
  }

  final response = {
    'ok': true,
    'path': levelsFile.path,
    'soloLevels': soloLevels.length,
    'levelsByMode': {
      for (final mode in ['1', '2', '3', '4'])
        mode: (modes[mode] as List).length,
    },
    'removedLogoFloors': removedLogoFloors,
  };

  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(response));
  await request.response.close();
}

List<Map<String, dynamic>> _removeAccidentalLogoFloors(
  Map<String, dynamic> campaign,
  List<int> logoBytes,
) {
  final removed = <Map<String, dynamic>>[];
  final modes = campaign['levels_by_mode'];
  if (modes is! Map) return removed;

  for (final modeEntry in modes.entries) {
    final mode = modeEntry.key.toString();
    final levels = modeEntry.value;
    if (levels is! List) continue;
    for (var levelIndex = 0; levelIndex < levels.length; levelIndex++) {
      final level = levels[levelIndex];
      if (level is! Map) continue;
      final floorKeys = level.keys
          .whereType<String>()
          .where((key) => key == 'custom_floor' || key.startsWith('custom_floor_'))
          .toList();
      for (final key in floorKeys) {
        final value = level[key];
        if (value is! String || value.isEmpty) continue;
        try {
          final separator = value.indexOf(',');
          final encoded = separator == -1 ? value : value.substring(separator + 1);
          final textureBytes = base64Decode(encoded);
          if (_bytesEqual(textureBytes, logoBytes)) {
            level[key] = null;
            removed.add({
              'mode': mode,
              'index': levelIndex,
              'field': key,
            });
            print('Autosave: removed accidental logo texture from $key');
          }
        } on FormatException {
          // Texture validation is handled by the clients; ignore unrelated data here.
        }
      }
    }
  }
  return removed;
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

void _validateCampaignJson(Map<String, dynamic> data) {
  final modes = data['levels_by_mode'];
  if (modes is! Map<String, dynamic>) {
    throw const FormatException('levels_by_mode is required');
  }

  for (final mode in ['1', '2', '3', '4']) {
    final levels = modes[mode];
    if (levels is! List || levels.isEmpty) {
      throw FormatException('levels_by_mode.$mode must be a non-empty list');
    }

    final ids = <int>{};
    for (var index = 0; index < levels.length; index++) {
      final level = levels[index];
      if (level is! Map<String, dynamic>) {
        throw FormatException('levels_by_mode.$mode contains a non-object');
      }
      _validateLevel(level, mode, index);
      final id = level['id'] as int;
      if (!ids.add(id)) {
        throw FormatException('Duplicate level id $id in mode $mode');
      }
    }
  }
}

void _validateLevel(Map<String, dynamic> level, String mode, int index) {
  final label = 'mode $mode level ${index + 1}';
  final id = level['id'];
  final width = level['width'];
  final height = level['height'];
  final movesLimit = level['movesLimit'];
  final map = level['map'];

  if (id is! int || id <= 0) {
    throw FormatException('Invalid level schema at $label: id is $id (expected positive int)');
  }
  if (width is! int || width <= 0 || width > 64) {
    throw FormatException('Invalid level schema at $label: width is $width (expected int 1..64)');
  }
  if (height is! int || height <= 0 || height > 64) {
    throw FormatException('Invalid level schema at $label: height is $height (expected int 1..64)');
  }
  if (movesLimit is! int || movesLimit <= 0) {
    throw FormatException('Invalid level schema at $label: movesLimit is $movesLimit (expected positive int)');
  }
  if (level['name'] is! String) {
    throw FormatException('Invalid level schema at $label: name is ${level['name']} (expected String)');
  }
  if (level['description'] is! String) {
    throw FormatException('Invalid level schema at $label: description is ${level['description']} (expected String)');
  }
  if (map is! List) {
    throw FormatException('Invalid level schema at $label: map is ${map.runtimeType} (expected List)');
  }
  if (map.length != height) {
    throw FormatException('Invalid level schema at $label: map length is ${map.length} but height is $height');
  }

  final customFloorMap = level['custom_floor_map'];
  if (customFloorMap != null) {
    if (customFloorMap is! List) {
      throw FormatException('Invalid level schema at $label: custom_floor_map is ${customFloorMap.runtimeType} (expected List)');
    }
    if (customFloorMap.length != height) {
      throw FormatException('Invalid level schema at $label: custom_floor_map length is ${customFloorMap.length} but height is $height');
    }
    for (var rowIndex = 0; rowIndex < customFloorMap.length; rowIndex++) {
      final row = customFloorMap[rowIndex];
      if (row is! String || row.length != width) {
        throw FormatException('$label custom_floor_map row ${rowIndex + 1} has invalid width (expected $width, got ${row.length})');
      }
      for (final rune in row.runes) {
        final symbol = String.fromCharCode(rune);
        if (symbol != '.' && (rune < 49 || rune > 54)) {
          throw FormatException('$label custom_floor_map uses unsupported symbol "$symbol"');
        }
      }
    }
  }


  final rows = <String>[];
  for (var rowIndex = 0; rowIndex < map.length; rowIndex++) {
    final row = map[rowIndex];
    if (row is! String || row.length != width) {
      throw FormatException('$label row ${rowIndex + 1} has invalid width');
    }
    for (final rune in row.runes) {
      final symbol = String.fromCharCode(rune);
      if (!_validMapSymbols.contains(symbol)) {
        throw FormatException('$label uses unsupported symbol "$symbol"');
      }
    }
    rows.add(row);
  }

  final mapText = rows.join();
  final playerCount = int.parse(mode);
  for (
    var playerIndex = 0;
    playerIndex < _playerSymbols.length;
    playerIndex++
  ) {
    final count = _playerSymbols[playerIndex].fold<int>(
      0,
      (total, symbol) => total + symbol.allMatches(mapText).length,
    );
    final expected = playerIndex < playerCount ? 1 : 0;
    if (count != expected) {
      print('Autosave Warning: $label must contain $expected P${playerIndex + 1} start, got $count');
    }
    if (expected == 1 &&
        !mapText.contains('X') &&
        !mapText.contains(_playerPortals[playerIndex])) {
      print('Autosave Warning: $label has no goal for P${playerIndex + 1}');
    }
  }

  final initialRules = level['initialRules'];
  final allowedRules = level['allowedRules'];
  if (initialRules is! Map || allowedRules is! Map) {
    throw FormatException('$label is missing rule configuration');
  }
  for (final color in ['red', 'blue', 'green']) {
    final initial = initialRules[color];
    final allowed = allowedRules[color];
    if (initial is! String ||
        !_validRules.contains(initial) ||
        allowed is! List ||
        allowed.isEmpty ||
        allowed.any((rule) => rule is! String || !_validRules.contains(rule)) ||
        !allowed.contains(initial)) {
      throw FormatException('$label has invalid $color rule configuration');
    }
  }
}

void _writeSplitAssets(Directory androidAssets, Map<String, dynamic> data) {
  final levelsByMode = data['levels_by_mode'] as Map<String, dynamic>;
  final soloLevels = levelsByMode['1'] as List<dynamic>;

  final chaptersList = data['chapters'] as List<dynamic>?;
  final chaptersCount = chaptersList?.length ?? 9;

  for (var chap = 1; chap <= chaptersCount; chap++) {
    final start = chap == 1 ? 0 : 22 + (chap - 2) * 12;
    final length = chap == 1 ? 22 : 12;
    final end = start + length;
    final safeEnd = chap == chaptersCount ? soloLevels.length : (end > soloLevels.length ? soloLevels.length : end);
    final levels = start < soloLevels.length
        ? soloLevels.sublist(start, safeEnd)
        : [];
    _writeSoloChapter(androidAssets, chap, levels);
  }

  // Clean up obsolete chapter directories
  final soloDir = Directory('${androidAssets.path}/levels/solo');
  if (soloDir.existsSync()) {
    for (final entity in soloDir.listSync()) {
      if (entity is Directory) {
        final name = entity.path.replaceAll('\\', '/').split('/').last;
        if (name.startsWith('chap')) {
          final chapNum = int.tryParse(name.substring(4));
          if (chapNum != null && chapNum > chaptersCount) {
            // Delete all json files in the obsolete chapter
            for (final file in entity.listSync().whereType<File>()) {
              if (file.path.toLowerCase().endsWith('.json')) {
                file.deleteSync();
              }
            }
            // Only delete directory completely if it's beyond chap9 (not listed in pubspec.yaml)
            if (chapNum > 9) {
              entity.deleteSync(recursive: true);
            }
          }
        }
      }
    }
  }

  for (final mode in ['2', '3', '4']) {
    _writeCoopMode(androidAssets, mode, levelsByMode[mode] as List<dynamic>);
  }
}

void _writeSoloChapter(
  Directory androidAssets,
  int chapter,
  List<dynamic> levels,
) {
  final dir = Directory('${androidAssets.path}/levels/solo/chap$chapter');
  _replaceJsonFiles(dir, levels);
}

void _writeCoopMode(
  Directory androidAssets,
  String mode,
  List<dynamic> levels,
) {
  final dir = Directory('${androidAssets.path}/levels/coop/${mode}p');
  _replaceJsonFiles(dir, levels);
}

void _replaceJsonFiles(Directory dir, List<dynamic> levels) {
  if (levels.isEmpty) {
    if (dir.existsSync()) {
      final path = dir.path.replaceAll('\\', '/');
      final name = path.split('/').last;
      final isChap = name.startsWith('chap');
      final chapNum = isChap ? int.tryParse(name.substring(4)) : null;
      final isCoop = path.contains('/levels/coop/');
      final keepDir = (isChap && chapNum != null && chapNum <= 9) || isCoop;
      
      if (keepDir) {
        for (final file in dir.listSync().whereType<File>()) {
          if (file.path.toLowerCase().endsWith('.json')) {
            file.deleteSync();
          }
        }
      } else {
        dir.deleteSync(recursive: true);
      }
    }
    return;
  }

  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  for (final file in dir.listSync().whereType<File>()) {
    if (file.path.toLowerCase().endsWith('.json')) {
      file.deleteSync();
    }
  }

  for (var i = 0; i < levels.length; i++) {
    final file = File('${dir.path}/${i + 1}.json');
    file.writeAsStringSync('${_jsonEncoder.convert(levels[i])}\n');
  }
}

Future<void> _serveStatic(HttpRequest request, Directory root) async {
  var relativePath = Uri.decodeComponent(request.uri.path);
  if (relativePath == '/') {
    relativePath = '/index.html';
  }

  final target = File(
    '${root.path}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  );
  final resolvedRoot = root.resolveSymbolicLinksSync();

  if (!target.existsSync()) {
    request.response.statusCode = HttpStatus.notFound;
    request.response.write('404 Not Found');
    await request.response.close();
    return;
  }

  final resolvedTarget = target.resolveSymbolicLinksSync();
  final rootPrefix = resolvedRoot.endsWith(Platform.pathSeparator)
      ? resolvedRoot
      : '$resolvedRoot${Platform.pathSeparator}';
  if (resolvedTarget != resolvedRoot &&
      !resolvedTarget.startsWith(rootPrefix)) {
    request.response.statusCode = HttpStatus.forbidden;
    await request.response.close();
    return;
  }

  request.response.headers.contentType = _contentTypeFor(target.path);
  request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
  if (request.method != 'HEAD') {
    await request.response.addStream(target.openRead());
  }
  await request.response.close();
}

ContentType _contentTypeFor(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.html')) return ContentType.html;
  if (lower.endsWith('.js')) {
    return ContentType('application', 'javascript', charset: 'utf-8');
  }
  if (lower.endsWith('.css'))
    return ContentType('text', 'css', charset: 'utf-8');
  if (lower.endsWith('.json')) return ContentType.json;
  if (lower.endsWith('.png')) return ContentType('image', 'png');
  if (lower.endsWith('.ico')) return ContentType('image', 'x-icon');
  return ContentType.binary;
}
