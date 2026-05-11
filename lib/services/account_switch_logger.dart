import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Logger specifically for account switching process
/// Writes timestamped logs to a file instead of console
class AccountSwitchLogger {
  static File? _logFile;
  static bool _isEnabled = true;
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss.SSS');
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Initialize the logger and create log file
  static Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/account_switch_logs');
      print("Log directory: ${logDir.path}");

      // Create directory if it doesn't exist
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Create log file with current date
      final fileName =
          'account_switch_${_dateFormat.format(DateTime.now())}.log';
      _logFile = File('${logDir.path}/$fileName');

      // Write header
      await _writeToFile('='.repeat(80));
      await _writeToFile('Account Switch Log - ${DateTime.now()}');
      await _writeToFile('='.repeat(80));
      await _writeToFile('');
    } catch (e) {
      print('Failed to initialize AccountSwitchLogger: $e');
      _isEnabled = false;
    }
  }

  /// Log a message with timestamp
  static Future<void> log(String message) async {
    if (!_isEnabled || _logFile == null) return;

    try {
      final timestamp = _timeFormat.format(DateTime.now());
      await _writeToFile('[$timestamp] $message');
    } catch (e) {
      print('Failed to write log: $e');
    }
  }

  /// Log the start of account switch
  static Future<void> logSwitchStart(
    String? oldAccount,
    String newAccount,
  ) async {
    await log('');
    await log('${'='.repeat(80)}');
    await log('ACCOUNT SWITCH START');
    await log('${'='.repeat(80)}');
    await log('Previous account: ${oldAccount ?? 'null'}');
    await log('New account: $newAccount');
    await log('');
  }

  /// Log the completion of account switch
  static Future<void> logSwitchComplete() async {
    await log('');
    await log('${'='.repeat(80)}');
    await log('ACCOUNT SWITCH COMPLETE');
    await log('${'='.repeat(80)}');
    await log('');
  }

  /// Log a step in the process
  static Future<void> logStep(int stepNumber, String description) async {
    await log('');
    await log('🔄 Step $stepNumber: $description');
  }

  /// Log a breakpoint
  static Future<void> logBreakpoint(
    int number,
    String description,
    Map<String, dynamic> state,
  ) async {
    await log('');
    await log('🔴 BREAKPOINT $number: $description');
    for (var entry in state.entries) {
      await log('   ${entry.key}: ${entry.value}');
    }
  }

  /// Log a request being sent
  static Future<void> logRequest(
    String channel,
    Map<String, dynamic> payload,
  ) async {
    await log('📤 REQUEST - $channel');
    for (var entry in payload.entries) {
      // Truncate authID for security
      if (entry.key == 'authID' &&
          entry.value is String &&
          (entry.value as String).length > 20) {
        await log(
          '   ${entry.key}: ${(entry.value as String).substring(0, 20)}...',
        );
      } else {
        await log('   ${entry.key}: ${entry.value}');
      }
    }
  }

  /// Log a response received
  static Future<void> logResponse(
    String type,
    Map<String, dynamic>? data,
  ) async {
    await log('📥 RESPONSE: $type');
    if (data != null) {
      for (var entry in data.entries) {
        await log('   ${entry.key}: ${entry.value}');
      }
    }
  }

  /// Log an error
  static Future<void> logError(String error) async {
    await log('❌ ERROR: $error');
  }

  /// Log a warning
  static Future<void> logWarning(String warning) async {
    await log('⚠️ WARNING: $warning');
  }

  /// Log a success message
  static Future<void> logSuccess(String message) async {
    await log('✅ SUCCESS: $message');
  }

  /// Write directly to file
  static Future<void> _writeToFile(String line) async {
    if (_logFile == null) return;

    try {
      await _logFile!.writeAsString(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      print('Failed to write to log file: $e');
    }
  }

  /// Get the current log file path
  static String? getLogFilePath() {
    return _logFile?.path;
  }

  /// Clear old log files (keep last 7 days)
  static Future<void> cleanupOldLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();

      print("Directory path: ${directory.path}");
      final logDir = Directory('${directory.path}/account_switch_logs');

      if (!await logDir.exists()) return;

      final now = DateTime.now();
      final files = await logDir.list().toList();

      for (var file in files) {
        if (file is File) {
          final stat = await file.stat();
          final age = now.difference(stat.modified).inDays;

          // Delete files older than 7 days
          if (age > 7) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Failed to cleanup old logs: $e');
    }
  }
}

// Extension to repeat strings
extension StringRepeat on String {
  String repeat(int count) => List.filled(count, this).join();
}
