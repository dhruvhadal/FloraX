import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Centralized Persistent Activity Logger for KisanSetu.
/// Captures structured telemetry events across all Flutter repositories,
/// edge ML vision inference pipelines, and Firestore data channels.
class AppActivityLogger {
  AppActivityLogger._();
  static final AppActivityLogger instance = AppActivityLogger._();
  factory AppActivityLogger() => instance;

  Future<void> init() async {
    await _getLogFile();
  }

  static const String logFileName = 'kisansetu_activity.log';
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB rotation limit

  final List<Map<String, dynamic>> _inMemoryLogs = [];
  File? _cachedLogFile;

  /// In-memory buffer of captured activity logs (used by test suites & audit exporters)
  List<Map<String, dynamic>> get capturedLogs => List.unmodifiable(_inMemoryLogs);

  /// Clears in-memory log buffer
  void clear() {
    _inMemoryLogs.clear();
  }

  /// Appends a structured activity event to both the in-memory buffer and rotating log file
  Future<void> log({
    required String screen,
    required String action,
    required String backendTarget,
    required String status,
    Map<String, dynamic>? details,
  }) async {
    final entry = {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'screen': screen,
      'action': action,
      'backendTarget': backendTarget,
      'status': status,
      'details': details ?? <String, dynamic>{},
    };

    // 1. Append to in-memory buffer
    _inMemoryLogs.add(entry);

    // 2. Output to debug console for live dev tracking
    if (kDebugMode) {
      debugPrint('[KisanSetu Log] [$status] $screen -> $action ($backendTarget)');
    }

    // 3. Persist to on-device rotating file (synchronous to guarantee zero pending ports in test runners)
    try {
      final file = await _getLogFile();
      if (file != null) {
        final line = '${jsonEncode(entry)}\n';
        file.writeAsStringSync(line, mode: FileMode.append, flush: true);

        // Simple size rotation
        final length = file.lengthSync();
        if (length > maxFileSizeBytes) {
          final backup = File('${file.path}.bak');
          if (backup.existsSync()) backup.deleteSync();
          file.renameSync(backup.path);
        }
      }
    } catch (e) {
      // Graceful fallback: never crash the app due to logging I/O
    }
  }

  /// Resolves the local persistent log file path with robust test environment fallback
  Future<File?> _getLogFile() async {
    if (_cachedLogFile != null) return _cachedLogFile;

    // Direct filesystem logging for Desktop, CI, and test runners (never hangs on unmocked channels)
    if (!Platform.isAndroid && !Platform.isIOS) {
      final fallbackDir = Directory('logs');
      if (!fallbackDir.existsSync()) fallbackDir.createSync(recursive: true);
      _cachedLogFile = File('logs/$logFileName');
      return _cachedLogFile;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      _cachedLogFile = File('${dir.path}/$logFileName');
      return _cachedLogFile;
    } catch (_) {
      final fallbackDir = Directory('logs');
      if (!fallbackDir.existsSync()) fallbackDir.createSync(recursive: true);
      _cachedLogFile = File('logs/$logFileName');
      return _cachedLogFile;
    }
  }

  /// Exports captured activity logs to a specified file path (e.g. `logs/frontend_activity_audit.log`)
  Future<void> exportLogs(String targetPath) async {
    try {
      final targetFile = File(targetPath);
      final parent = targetFile.parent;
      if (!parent.existsSync()) parent.createSync(recursive: true);

      final buffer = StringBuffer();
      for (final log in _inMemoryLogs) {
        buffer.writeln(jsonEncode(log));
      }

      await targetFile.writeAsString(buffer.toString(), flush: true);
    } catch (e) {
      debugPrint('[AppActivityLogger] Export logs error: $e');
    }
  }
}
