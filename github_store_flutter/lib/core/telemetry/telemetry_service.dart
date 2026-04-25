import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Anonymous usage analytics event types tracked by the application.
enum TelemetryEventType {
  searchPerformed('search_performed'),
  searchResultClicked('search_result_clicked'),
  repoViewed('repo_viewed'),
  releaseDownloaded('release_downloaded'),
  installStarted('install_started'),
  installSucceeded('install_succeeded'),
  installFailed('install_failed'),
  appOpened('app_opened'),
  uninstalled('uninstalled'),
  favorited('favorited'),
  unfavorited('unfavorited');

  const TelemetryEventType(this.value);
  final String value;
}

/// A single telemetry event to be sent to the analytics backend.
class TelemetryEvent {
  TelemetryEvent({
    required this.type,
    this.payload = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toUtc();

  final TelemetryEventType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'event_type': type.value,
        'timestamp': timestamp.toIso8601String(),
        'payload': payload,
      };
}

/// Persistent event queue entry stored in memory buffer.
class _QueuedEvent {
  _QueuedEvent({required this.json, required this.queuedAt});

  final Map<String, dynamic> json;
  final DateTime queuedAt;
}

/// Anonymous usage analytics service with batched uploads.
///
/// Events are queued in an in-memory buffer (max 500) and flushed to the
/// backend every 30 seconds (max 50 events per batch). The device ID is
/// a random UUID generated once and persisted via [SharedPreferences].
///
/// When analytics is disabled, the buffer is cleared and no events are sent.
class TelemetryService {
  TelemetryService({
    Dio? httpClient,
    SharedPreferences? prefs,
  })  : _dio = httpClient ??
            Dio(BaseOptions(
              baseUrl: 'https://api.github-store.org',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'Content-Type': 'application/json',
                'User-Agent': 'GitHubStore-Desktop/1.0',
              },
            )),
        _prefs = prefs;

  final Dio _dio;
  final SharedPreferences? _prefs;

  // ── Constants ───────────────────────────────────────────────────────────

  /// Maximum number of events to keep in the buffer.
  static const int _maxBufferSize = 500;

  /// Maximum number of events per batch upload.
  static const int _maxBatchSize = 50;

  /// Interval between automatic flush attempts.
  static const Duration _flushInterval = Duration(seconds: 30);

  /// SharedPreferences key for the persisted device ID.
  static const String _deviceIdKey = 'telemetry_device_id';

  /// SharedPreferences key for the analytics enabled flag.
  static const String _analyticsEnabledKey = 'telemetry_enabled';

  /// SharedPreferences key for the persisted event buffer.
  static const String _eventBufferKey = 'telemetry_event_buffer';

  /// SharedPreferences key for last flush timestamp.
  static const String _lastFlushKey = 'telemetry_last_flush';

  // ── State ───────────────────────────────────────────────────────────────

  final List<_QueuedEvent> _buffer = [];
  Timer? _flushTimer;
  String? _deviceId;
  bool _enabled = true;
  bool _isFlushing = false;

  // ── Initialization ──────────────────────────────────────────────────────

  /// Initialize the telemetry service.
  ///
  /// Loads the persisted device ID and event buffer from storage.
  /// Starts the periodic flush timer if analytics is enabled.
  Future<void> initialize() async {
    // Load persisted device ID or generate a new one
    _deviceId = _prefs?.getString(_deviceIdKey);
    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = _generateUUID();
      await _prefs?.setString(_deviceIdKey, _deviceId!);
    }

    // Load analytics enabled flag
    final stored = _prefs?.getBool(_analyticsEnabledKey);
    _enabled = stored ?? true;

    // Load persisted events from previous session
    await _loadPersistedBuffer();

    // Start periodic flush if enabled
    if (_enabled) {
      _startFlushTimer();
    }

    debugPrint('[Telemetry] Initialized. Device ID: $_deviceId, Enabled: $_enabled, '
        'Buffer: ${_buffer.length}');
  }

  /// Dispose the telemetry service and flush remaining events.
  Future<void> dispose() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await flush();
  }

  // ── Public API ──────────────────────────────────────────────────────────

  /// Track an analytics event.
  ///
  /// If analytics is disabled, the event is silently dropped.
  /// If the buffer exceeds [_maxBufferSize], the oldest events are dropped.
  void trackEvent(
    TelemetryEventType type, {
    Map<String, dynamic> payload = const {},
  }) {
    if (!_enabled) return;
    if (kDebugMode) {
      debugPrint('[Telemetry] Event: ${type.value}, payload: $payload');
    }

    final event = TelemetryEvent(type: type, payload: payload);
    final queued = _QueuedEvent(json: event.toJson(), queuedAt: DateTime.now());

    _buffer.add(queued);

    // Drop oldest events if buffer exceeds max size
    while (_buffer.length > _maxBufferSize) {
      _buffer.removeAt(0);
    }

    // Persist buffer periodically (debounced)
    _persistBufferDebounced();
  }

  /// Immediately flush all queued events to the backend.
  ///
  /// Events are sent in batches of up to [_maxBatchSize].
  /// Failed events remain in the buffer for retry.
  Future<void> flush() async {
    if (_buffer.isEmpty || _isFlushing || !_enabled) return;
    _isFlushing = true;

    try {
      // Take up to maxBatchSize events
      final batch = _buffer.take(_maxBatchSize).toList();
      final eventsJson = batch.map((e) => e.json).toList();

      final payload = {
        'device_id': _deviceId,
        'app_version': _getAppVersion(),
        'platform': _getPlatformName(),
        'events': eventsJson,
      };

      final response = await _dio.post<dynamic>(
        '/v1/events',
        data: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Remove successfully sent events from buffer
        _buffer.removeRange(0, batch.length);
        await _prefs?.setString(_lastFlushKey, DateTime.now().toUtc().toIso8601String());

        if (kDebugMode) {
          debugPrint('[Telemetry] Flushed ${batch.length} events. '
              'Remaining: ${_buffer.length}');
        }

        // If there are more events, flush again
        if (_buffer.isNotEmpty) {
          await flush();
        }
      } else {
        debugPrint('[Telemetry] Flush failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[Telemetry] Flush error: $e');
      // Events remain in buffer for next flush attempt
    } finally {
      _isFlushing = false;
      await _persistBuffer();
    }
  }

  /// Enable analytics and start the periodic flush timer.
  Future<void> enable() async {
    _enabled = true;
    await _prefs?.setBool(_analyticsEnabledKey, true);
    _startFlushTimer();
    debugPrint('[Telemetry] Analytics enabled');
  }

  /// Disable analytics, clear the event buffer, and stop the flush timer.
  Future<void> disable() async {
    _enabled = false;
    await _prefs?.setBool(_analyticsEnabledKey, false);
    _flushTimer?.cancel();
    _flushTimer = null;
    _buffer.clear();
    await _prefs?.remove(_eventBufferKey);
    debugPrint('[Telemetry] Analytics disabled, buffer cleared');
  }

  /// Whether analytics is currently enabled.
  bool get isEnabled => _enabled;

  /// Get the persisted device ID.
  ///
  /// Returns `null` if [initialize] has not been called yet.
  String? getDeviceId() => _deviceId;

  /// Get the number of events currently in the buffer.
  int get bufferSize => _buffer.length;

  // ── Private Helpers ─────────────────────────────────────────────────────

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      flush();
    });
  }

  String _generateUUID() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // Set version 4
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    // Set variant 10xx
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  String _getAppVersion() {
    // This will be populated by the build system
    const version = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0+1');
    return version;
  }

  String _getPlatformName() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  Timer? _persistDebounceTimer;

  void _persistBufferDebounced() {
    _persistDebounceTimer?.cancel();
    _persistDebounceTimer = Timer(const Duration(seconds: 5), () {
      _persistBuffer();
    });
  }

  Future<void> _persistBuffer() async {
    if (_prefs == null || _buffer.isEmpty) return;
    try {
      final jsonList = _buffer.map((e) => e.json).toList();
      await _prefs!.setString(_eventBufferKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[Telemetry] Failed to persist buffer: $e');
    }
  }

  Future<void> _loadPersistedBuffer() async {
    if (_prefs == null) return;
    try {
      final stored = _prefs!.getString(_eventBufferKey);
      if (stored == null || stored.isEmpty) return;

      final list = jsonDecode(stored) as List<dynamic>;
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          _buffer.add(_QueuedEvent(
            json: item,
            queuedAt: DateTime.now(),
          ));
        }
      }

      // Trim to max buffer size
      while (_buffer.length > _maxBufferSize) {
        _buffer.removeAt(0);
      }

      if (_buffer.isNotEmpty) {
        debugPrint('[Telemetry] Loaded ${_buffer.length} persisted events');
      }
    } catch (e) {
      debugPrint('[Telemetry] Failed to load persisted buffer: $e');
    }
  }
}
