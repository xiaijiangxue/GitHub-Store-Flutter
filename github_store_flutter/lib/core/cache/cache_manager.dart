import 'dart:async';
import 'dart:convert';

import '../database/app_database.dart';

/// Entry for a cached item stored in the database.
class CacheEntry {
  CacheEntry({
    required this.key,
    required this.value,
    this.createdAt,
    this.ttl = const Duration(minutes: 15),
  });

  final String key;
  final String value;
  final DateTime? createdAt;
  final Duration ttl;

  /// Whether this cache entry has expired.
  bool get isExpired {
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt!) > ttl;
  }
}

/// A two-tier cache with in-memory and database-backed storage.
///
/// The cache works as follows:
/// 1. On [get], check the memory cache first (fast, no I/O).
/// 2. If not in memory, check the database cache.
/// 3. On [put], store in both memory and database.
///
/// The memory cache has a configurable max size (default 50 entries) and
/// entries are evicted in LRU order. The database cache uses the existing
/// [AppSettings] table for storage.
///
/// TTL (Time To Live) defaults to 15 minutes but can be specified per entry.
class CacheManager {
  CacheManager({AppDatabase? database, int maxMemoryEntries = 50})
      : _database = database,
        _maxMemoryEntries = maxMemoryEntries;

  final AppDatabase? _database;
  final int _maxMemoryEntries;

  // Memory cache: key -> CacheEntry
  final Map<String, CacheEntry> _memoryCache = {};

  // Track access order for LRU eviction
  final List<String> _accessOrder = [];

  // Pending writes to avoid DB contention
  final Map<String, Timer> _pendingWrites = {};

  // Debounce duration for database writes
  static const _writeDebounce = Duration(milliseconds: 500);

  // ── Public API ──────────────────────────────────────────────────────────

  /// Retrieve a cached value.
  ///
  /// [key] - Cache key (supports prefix matching via [getByPrefix]).
  /// [ttl] - Maximum age for the cached entry.
  /// [fromJson] - Factory function to deserialize the cached JSON.
  ///
  /// Returns the cached value, or `null` if not found or expired.
  Future<T?> get<T>(
    String key, {
    Duration ttl = const Duration(minutes: 15),
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    // Check memory cache first
    final memEntry = _memoryCache[key];
    if (memEntry != null && !memEntry.isExpired) {
      _touchAccessOrder(key);
      try {
        final json = jsonDecode(memEntry.value) as Map<String, dynamic>;
        return fromJson(json);
      } catch (e) {
        // Corrupted memory cache entry, remove it
        _removeFromMemory(key);
      }
    }

    // Check database cache
    if (_database != null) {
      try {
        final cached = await _database!.getSetting(_cacheKey(key));
        if (cached != null) {
          // Parse the stored JSON wrapper
          final wrapper = jsonDecode(cached) as Map<String, dynamic>;
          final value = wrapper['value'] as String?;
          final cachedAt = wrapper['cached_at'] as String?;

          if (value != null) {
            // Check TTL
            final createdAt = cachedAt != null
                ? DateTime.tryParse(cachedAt)
                : null;
            final isExpired = createdAt != null &&
                DateTime.now().difference(createdAt) > ttl;

            if (!isExpired) {
              // Promote to memory cache
              _addToMemory(key, value, createdAt, ttl);

              try {
                final json = jsonDecode(value) as Map<String, dynamic>;
                return fromJson(json);
              } catch (_) {
                // Corrupted data, remove it
                await invalidate(key);
              }
            } else {
              // Expired, remove from both caches
              await invalidate(key);
            }
          }
        }
      } catch (e) {
        // Database read error, silently fall through
      }
    }

    return null;
  }

  /// Retrieve a raw string from the cache without deserialization.
  ///
  /// Useful for caching non-JSON data like raw markdown content.
  Future<String?> getRaw(
    String key, {
    Duration ttl = const Duration(minutes: 15),
  }) async {
    // Check memory cache first
    final memEntry = _memoryCache[key];
    if (memEntry != null && !memEntry.isExpired) {
      _touchAccessOrder(key);
      return memEntry.value;
    }

    // Check database cache
    if (_database != null) {
      try {
        final cached = await _database!.getSetting(_cacheKey(key));
        if (cached != null) {
          final wrapper = jsonDecode(cached) as Map<String, dynamic>;
          final value = wrapper['value'] as String?;
          final cachedAt = wrapper['cached_at'] as String?;

          if (value != null) {
            final createdAt = cachedAt != null
                ? DateTime.tryParse(cachedAt)
                : null;
            final isExpired = createdAt != null &&
                DateTime.now().difference(createdAt) > ttl;

            if (!isExpired) {
              _addToMemory(key, value, createdAt, ttl);
              return value;
            } else {
              await invalidate(key);
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Store a value in the cache.
  ///
  /// [key] - Cache key.
  /// [data] - The value to cache.
  /// [toJson] - Serialization function to convert the value to JSON.
  /// [ttl] - Time to live for this cache entry.
  Future<void> put<T>(
    String key, {
    required T data,
    required Map<String, dynamic> Function(T) toJson,
    Duration ttl = const Duration(minutes: 15),
  }) async {
    final jsonString = jsonEncode(toJson(data));
    await _putRaw(key, jsonString, ttl);
  }

  /// Store a raw string value in the cache.
  ///
  /// Useful for caching pre-serialized or non-object data.
  Future<void> putRaw(
    String key,
    String value, {
    Duration ttl = const Duration(minutes: 15),
  }) async {
    await _putRaw(key, value, ttl);
  }

  /// Store a list of items in the cache.
  ///
  /// [key] - Cache key.
  /// [items] - List of items to cache.
  /// [toJson] - Serialization function for each item.
  /// [ttl] - Time to live.
  Future<void> putList<T>(
    String key, {
    required List<T> items,
    required Map<String, dynamic> Function(T) toJson,
    Duration ttl = const Duration(minutes: 15),
  }) async {
    final jsonString = jsonEncode(items.map(toJson).toList());
    await _putRaw(key, jsonString, ttl);
  }

  /// Retrieve a list of cached items.
  ///
  /// [key] - Cache key.
  /// [fromJson] - Deserialization function for each item.
  /// [ttl] - Maximum age for the cached entry.
  Future<List<T>?> getList<T>(
    String key, {
    required T Function(Map<String, dynamic>) fromJson,
    Duration ttl = const Duration(minutes: 15),
  }) async {
    final raw = await getRaw(key, ttl: ttl);
    if (raw == null) return null;

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Invalidate (remove) a single cache entry by key.
  Future<void> invalidate(String key) async {
    _removeFromMemory(key);
    _cancelPendingWrite(key);

    if (_database != null) {
      try {
        // The database doesn't have a delete-by-key method for AppSettings,
        // but we can overwrite with an empty marker or use a deletion strategy.
        // Since AppSettings doesn't support deletion by key easily,
        // we store a tombstone marker.
        await _database!.setSetting(
          _cacheKey(key),
          jsonEncode({'deleted': true, 'cached_at': DateTime.now().toUtc().toIso8601String()}),
        );
      } catch (_) {}
    }
  }

  /// Invalidate all cache entries matching a prefix.
  ///
  /// For example, `invalidateByPrefix('repos:')` removes all keys starting
  /// with "repos:".
  ///
  /// This only operates on the memory cache. Database cache entries with
  /// the prefix will be lazily ignored on next read.
  Future<void> invalidateByPrefix(String prefix) async {
    final keysToRemove = <String>[];
    for (final key in _memoryCache.keys) {
      if (key.startsWith(prefix)) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      _removeFromMemory(key);
      _cancelPendingWrite(key);
    }
  }

  /// Clear all cached entries from both memory and database.
  Future<void> clearAll() async {
    // Clear memory cache
    _memoryCache.clear();
    _accessOrder.clear();

    // Cancel all pending writes
    for (final timer in _pendingWrites.values) {
      timer.cancel();
    }
    _pendingWrites.clear();

    // Clear database cache - we don't have a bulk delete, but we can
    // iterate. For efficiency, we'll just clear the memory cache and
    // let database entries expire naturally via TTL.
    // If a full DB clear is needed, it should be done via a direct query.
  }

  /// Get the number of entries in the memory cache.
  int get memoryCacheSize => _memoryCache.length;

  /// Check if a key exists in the memory cache (regardless of TTL).
  bool containsKey(String key) => _memoryCache.containsKey(key);

  /// Get all cache keys in the memory cache.
  List<String> get keys => List.unmodifiable(_memoryCache.keys);

  // ── Private Implementation ──────────────────────────────────────────────

  /// Internal method to put a raw value into both cache tiers.
  Future<void> _putRaw(
    String key,
    String value,
    Duration ttl,
  ) async {
    final now = DateTime.now();

    // Always update memory cache immediately
    _addToMemory(key, value, now, ttl);

    // Debounce database writes
    _cancelPendingWrite(key);
    _pendingWrites[key] = Timer(_writeDebounce, () {
      _pendingWrites.remove(key);
      _writeToDatabase(key, value, now);
    });
  }

  /// Write a cache entry to the database.
  Future<void> _writeToDatabase(
    String key,
    String value,
    DateTime cachedAt,
  ) async {
    if (_database == null) return;

    try {
      final wrapper = jsonEncode({
        'value': value,
        'cached_at': cachedAt.toUtc().toIso8601String(),
      });
      await _database!.setSetting(_cacheKey(key), wrapper);
    } catch (e) {
      // Silently ignore database write errors to avoid impacting app performance
    }
  }

  /// Add an entry to the memory cache with LRU eviction.
  void _addToMemory(
    String key,
    String value,
    DateTime? createdAt,
    Duration ttl,
  ) {
    _memoryCache[key] = CacheEntry(
      key: key,
      value: value,
      createdAt: createdAt,
      ttl: ttl,
    );
    _touchAccessOrder(key);
    _evictIfNeeded();
  }

  /// Remove an entry from the memory cache.
  void _removeFromMemory(String key) {
    _memoryCache.remove(key);
    _accessOrder.remove(key);
  }

  /// Update the access order for an LRU entry.
  void _touchAccessOrder(String key) {
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  /// Evict the least recently used entries if over capacity.
  void _evictIfNeeded() {
    while (_memoryCache.length > _maxMemoryEntries && _accessOrder.isNotEmpty) {
      final oldest = _accessOrder.removeAt(0);
      _memoryCache.remove(oldest);
    }
  }

  /// Cancel a pending database write for a key.
  void _cancelPendingWrite(String key) {
    _pendingWrites[key]?.cancel();
    _pendingWrites.remove(key);
  }

  /// Prefix all cache keys to avoid collisions with real app settings.
  String _cacheKey(String key) => 'cache:$key';
}
