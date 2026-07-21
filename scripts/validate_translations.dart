/// One-shot validator that loads every `assets/translations/*.json` and
/// reports (a) keys that exist in `en.json` (the master) but are missing or
/// empty in any other language, and (b) keys that exist in a non-en file but
/// not in `en.json` (outliers). Run from the project root:
///
///   dart run scripts/validate_translations.dart
///
/// Exit code: 0 when every non-en file has every en.json key with a non-empty
/// value, 2 otherwise. Writes a machine-readable `translation_report.json` to
/// `build/` so CI can consume it.
import 'dart:convert';
import 'dart:io';

const _translationsDir = 'assets/translations';
const _masterLang = 'en';
const _reportPath = 'build/translation_report.json';

Future<void> main() async {
  final dir = Directory(_translationsDir);
  if (!await dir.exists()) {
    stderr.writeln('❌ Translations directory not found: $_translationsDir');
    exit(2);
  }

  // Load every *.json in the translations folder, keyed by language code
  // (the file stem, e.g. `en.json` → `en`).
  final Map<String, Map<String, dynamic>> byLang = {};
  final Map<String, String> langDisplayName = {};
  final errors = <String>[];

  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final name = entity.path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    if (!name.endsWith('.json') || dot <= 0) continue;
    final code = name.substring(0, dot);
    late final Map<String, dynamic> decoded;
    try {
      decoded = json.decode(await entity.readAsString()) as Map<String, dynamic>;
    } on FormatException catch (e) {
      errors.add('⚠️  $name is not valid JSON: $e');
      continue;
    } on Object catch (e) {
      errors.add('⚠️  Could not read $name: $e');
      continue;
    }
    byLang[code] = decoded;
    // Best-effort display name from the file itself; fall back to code.
    langDisplayName[code] = decoded['_language_name']?.toString() ?? code;
  }

  if (!byLang.containsKey(_masterLang)) {
    stderr.writeln(
      '❌ Master language "$_masterLang" not found in $_translationsDir. '
      'Cannot validate without a reference.',
    );
    exit(2);
  }

  final masterKeys = byLang[_masterLang]!.keys.toSet();
  final report = <String, dynamic>{
    'generated_at': DateTime.now().toIso8601String(),
    'master_language': _masterLang,
    'master_key_count': masterKeys.length,
    'languages': <String, dynamic>{},
    'ok': true,
    'errors': errors,
  };

  var anyFailure = errors.isNotEmpty;

  for (final entry in byLang.entries) {
    final code = entry.key;
    final map = entry.value;
    final langReport = <String, dynamic>{
      'display_name': langDisplayName[code] ?? code,
      'total_keys': map.length,
      'master_key_count': masterKeys.length,
      'missing_keys': <String>[],
      'empty_keys': <String>[],
      'outlier_keys': <String>[],
    };

    if (code == _masterLang) {
      report['languages'][code] = langReport;
      continue;
    }

    // 1. Keys in master but missing or empty in this language.
    for (final key in masterKeys) {
      if (!map.containsKey(key)) {
        langReport['missing_keys'].add(key);
      } else if (map[key] == null || map[key].toString().trim().isEmpty) {
        langReport['empty_keys'].add(key);
      }
    }

    // 2. Keys in this language but NOT in master (outliers — usually stale).
    for (final key in map.keys) {
      if (!masterKeys.contains(key) && !key.startsWith('_')) {
        langReport['outlier_keys'].add(key);
      }
    }

    final missing = (langReport['missing_keys'] as List).length;
    final empty = (langReport['empty_keys'] as List).length;
    final outliers = (langReport['outlier_keys'] as List).length;

    if (missing > 0 || empty > 0 || outliers > 0) {
      anyFailure = true;
    }

    stdout.writeln(
      '── $code (${langReport['display_name']}) '
      'total=${langReport['total_keys']} '
      'missing=$missing empty=$empty outliers=$outliers',
    );
    if (missing > 0) {
      for (final k in langReport['missing_keys'] as List<String>) {
        stdout.writeln('  MISSING  $k');
      }
    }
    if (empty > 0) {
      for (final k in langReport['empty_keys'] as List<String>) {
        stdout.writeln('  EMPTY    $k');
      }
    }
    if (outliers > 0) {
      for (final k in langReport['outlier_keys'] as List<String>) {
        stdout.writeln('  OUTLIER  $k');
      }
    }

    report['languages'][code] = langReport;
  }

  if (errors.isNotEmpty) {
    for (final e in errors) stderr.writeln(e);
  }

  report['ok'] = !anyFailure;

  // Write machine-readable report for CI / IDE consumers.
  final reportDir = Directory(_reportPath).parent;
  if (!await reportDir.exists()) {
    await reportDir.create(recursive: true);
  }
  await File(_reportPath).writeAsString(
    const JsonEncoder.withIndent('  ').convert(report),
  );
  stdout.writeln('\n📄 Machine-readable report → $_reportPath');

  if (anyFailure) {
    stderr.writeln('\n❌ FAIL — translation gaps detected (see above).');
    exit(2);
  }
  stdout.writeln('\n✅ PASS — all languages have every key, no empty values.');
}
