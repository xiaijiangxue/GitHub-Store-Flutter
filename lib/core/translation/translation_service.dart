import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/settings_model.dart' show TranslationProvider;

/// Supported translation providers.
enum TranslationProviderType {
  google('Google Translate'),
  youdao('Youdao');

  const TranslationProviderType(this.displayName);
  final String displayName;
}

/// Language detection result.
class DetectedLanguage {
  DetectedLanguage({
    required this.languageCode,
    required this.confidence,
    required this.provider,
  });

  /// ISO 639-1 language code (e.g. "en", "zh", "ja").
  final String languageCode;

  /// Confidence score between 0.0 and 1.0.
  final double confidence;

  /// Which provider detected the language.
  final TranslationProviderType provider;

  @override
  String toString() => 'DetectedLanguage($languageCode, confidence: ${confidence.toStringAsFixed(2)}, provider: ${provider.displayName})';
}

/// Translation service that supports multiple providers for translating
/// README files and release notes.
///
/// Supports:
/// - **Google Translate** (free, no credentials required)
/// - **Youdao Translate** (requires appKey and appSecret)
///
/// Features:
/// - Markdown-aware translation that preserves code blocks, links, and formatting.
/// - Text chunking for long texts (splits at paragraph/code block boundaries).
/// - Language detection for READMEs.
/// - Tries localized README variants before translating (e.g. README.zh-CN.md).
class TranslationService {
  TranslationService({
    Dio? httpClient,
    String? youdaoAppKey,
    String? youdaoAppSecret,
    TranslationProvider defaultProvider = TranslationProvider.google,
  })  : _dio = httpClient ?? Dio(BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 30),
          )),
        _youdaoAppKey = youdaoAppKey,
        _youdaoAppSecret = youdaoAppSecret,
        _defaultProvider = defaultProvider;

  final Dio _dio;
  String? _youdaoAppKey;
  String? _youdaoAppSecret;
  TranslationProvider _defaultProvider;

  /// Maximum characters per chunk for translation API calls.
  static const int _maxChunkSize = 4500;

  /// Google Translate API endpoint (unofficial, free).
  static const String _googleTranslateUrl =
      'https://translate.googleapis.com/translate_a/single';

  /// Youdao Translate API endpoint.
  static const String _youdaoTranslateUrl = 'https://openapi.youdao.com/api';

  /// Youdao Language Detection API endpoint.
  static const String _youdaoDetectUrl = 'https://openapi.youdao.com/detect';

  // ── Configuration ───────────────────────────────────────────────────────

  /// Update the Youdao API credentials.
  void setYoudaoCredentials(String? appKey, String? appSecret) {
    _youdaoAppKey = appKey;
    _youdaoAppSecret = appSecret;
  }

  /// Update the default translation provider.
  void setDefaultProvider(TranslationProvider provider) {
    _defaultProvider = provider;
  }

  // ── Translation Methods ─────────────────────────────────────────────────

  /// Translate a plain text string.
  ///
  /// [text] - The text to translate.
  /// [targetLanguage] - Target language code (e.g. "zh", "en", "ja").
  ///   Defaults to the language from settings or "en".
  /// [provider] - Override the default translation provider.
  ///
  /// Returns the translated text.
  Future<String> translateText(
    String text, {
    String? targetLanguage,
    TranslationProvider? provider,
  }) async {
    if (text.trim().isEmpty) return text;

    targetLanguage ??= 'en';
    final providerType = _mapProvider(provider ?? _defaultProvider);

    // If text is short enough, translate directly
    if (text.length <= _maxChunkSize) {
      return _translateChunk(text, targetLanguage, providerType);
    }

    // Split into chunks and translate each
    final chunks = _splitTextIntoChunks(text);
    final translatedChunks = <String>[];

    for (final chunk in chunks) {
      if (chunk.trim().isEmpty) {
        translatedChunks.add(chunk);
        continue;
      }
      final translated = await _translateChunk(chunk, targetLanguage, providerType);
      translatedChunks.add(translated);
    }

    return translatedChunks.join('\n\n');
  }

  /// Detect the language of the given text.
  ///
  /// Uses the Youdao detection API or falls back to simple heuristic detection.
  Future<String> detectLanguage(String text) async {
    if (text.trim().isEmpty) return 'unknown';

    // Try Youdao detection first if credentials are available
    if (_youdaoAppKey != null && _youdaoAppSecret != null) {
      try {
        final result = await _detectLanguageYoudao(text);
        if (result != null && result.languageCode != 'unknown') {
          return result.languageCode;
        }
      } catch (e) {
        debugPrint('[Translation] Youdao detection failed: $e');
      }
    }

    // Fallback to heuristic detection
    return _detectLanguageHeuristic(text);
  }

  /// Translate a README markdown file, preserving code blocks and formatting.
  ///
  /// Code blocks (```...```) are left untranslated. Inline code (`...`) is
  /// preserved. Links and image URLs are left intact.
  ///
  /// [markdown] - The README markdown content.
  /// [targetLanguage] - Target language code.
  /// [provider] - Override the default translation provider.
  ///
  /// Returns the translated markdown with preserved formatting.
  Future<String> translateReadme(
    String markdown, {
    String? targetLanguage,
    TranslationProvider? provider,
  }) async {
    return _translateMarkdown(markdown, targetLanguage: targetLanguage, provider: provider);
  }

  /// Translate release notes markdown, preserving code blocks and formatting.
  ///
  /// Same behavior as [translateReadme] but specifically for release notes.
  Future<String> translateReleaseNotes(
    String markdown, {
    String? targetLanguage,
    TranslationProvider? provider,
  }) async {
    return _translateMarkdown(markdown, targetLanguage: targetLanguage, provider: provider);
  }

  /// Suggest a localized README variant for the given URL and target language.
  ///
  /// For example, for `README.md` with target `zh`, tries:
  /// - `README.zh-CN.md`
  /// - `README.zh.md`
  /// - `README.zh_Hans.md`
  ///
  /// Returns the suggested filename, or `null` if no variant is available.
  String? suggestLocalizedReadme(String originalFilename, String targetLanguage) {
    if (!originalFilename.toLowerCase().contains('readme')) return null;

    final baseName = originalFilename.contains('.')
        ? originalFilename.substring(0, originalFilename.lastIndexOf('.'))
        : originalFilename;
    final extension = originalFilename.contains('.')
        ? originalFilename.substring(originalFilename.lastIndexOf('.'))
        : '.md';

    // Language code mappings for common README variants
    final variants = _getReadmeLanguageVariants(targetLanguage);

    for (final variant in variants) {
      final localizedFile = '${baseName}.${variant}$extension';
      // Return the first suggested variant - the caller will need to
      // check if this file actually exists on GitHub
      return localizedFile;
    }

    return null;
  }

  // ── Private: Markdown Translation ───────────────────────────────────────

  /// Translate markdown while preserving code blocks and inline code.
  Future<String> _translateMarkdown(
    String markdown, {
    String? targetLanguage,
    TranslationProvider? provider,
  }) async {
    if (markdown.trim().isEmpty) return markdown;

    // Extract code blocks and replace with placeholders
    final codeBlocks = <String>[];
    String processed = markdown;

    // Extract fenced code blocks (```)
    final fencedBlockRegex = RegExp(r'```[\s\S]*?```', multiLine: true);
    processed = processed.replaceAllMapped(fencedBlockRegex, (match) {
      final index = codeBlocks.length;
      codeBlocks.add(match.group(0)!);
      return '\x00CODE_BLOCK_$index\x00';
    });

    // Extract inline code (`)
    final inlineCodeRegex = RegExp(r'`[^`]+`');
    processed = processed.replaceAllMapped(inlineCodeRegex, (match) {
      final index = codeBlocks.length;
      codeBlocks.add(match.group(0)!);
      return '\x00CODE_BLOCK_$index\x00';
    });

    // Extract image/URL markdown ![alt](url) and [text](url)
    final linkRegex = RegExp(r'!?\[[^\]]*\]\([^)]*\)');
    processed = processed.replaceAllMapped(linkRegex, (match) {
      final index = codeBlocks.length;
      codeBlocks.add(match.group(0)!);
      return '\x00CODE_BLOCK_$index\x00';
    });

    // Extract HTML tags
    final htmlRegex = RegExp(r'<[^>]+>');
    processed = processed.replaceAllMapped(htmlRegex, (match) {
      final index = codeBlocks.length;
      codeBlocks.add(match.group(0)!);
      return '\x00CODE_BLOCK_$index\x00';
    });

    // Translate the remaining text
    final translated = await translateText(
      processed,
      targetLanguage: targetLanguage,
      provider: provider,
    );

    // Restore code blocks
    String result = translated;
    for (var i = codeBlocks.length - 1; i >= 0; i--) {
      result = result.replaceAll('\x00CODE_BLOCK_$i\x00', codeBlocks[i]);
    }

    return result;
  }

  // ── Private: Google Translate ───────────────────────────────────────────

  Future<String> _translateGoogle(String text, String targetLanguage) async {
    try {
      final response = await _dio.get<dynamic>(
        _googleTranslateUrl,
        queryParameters: {
          'client': 'gtx',
          'sl': 'auto',
          'tl': targetLanguage,
          'dt': 't',
          'q': text,
        },
      );

      final data = response.data;
      if (data == null) throw Exception('Empty response from Google Translate');

      // Google returns a nested array structure:
      // [[["translated text","original text",null,null,10]], ...,"en"]
      if (data is List && data.isNotEmpty) {
        final translatedParts = <String>[];
        for (final item in data) {
          if (item is List && item.isNotEmpty) {
            final inner = item[0];
            if (inner is List && inner.isNotEmpty && inner[0] is String) {
              translatedParts.add(inner[0] as String);
            }
          }
        }
        if (translatedParts.isNotEmpty) {
          return translatedParts.join('');
        }
      }

      // Fallback: try to extract from string response
      if (data is String) {
        final parsed = jsonDecode(data) as List;
        final parts = <String>[];
        for (final item in parsed) {
          if (item is List && item.isNotEmpty && item[0] is List) {
            final inner = item[0] as List;
            if (inner.isNotEmpty && inner[0] is String) {
              parts.add(inner[0] as String);
            }
          }
        }
        if (parts.isNotEmpty) return parts.join('');
      }

      throw Exception('Could not parse Google Translate response');
    } on DioException catch (e) {
      throw _TranslationException(
        'Google Translate API error: ${e.message}',
        provider: TranslationProviderType.google,
      );
    }
  }

  // ── Private: Youdao Translate ──────────────────────────────────────────

  Future<String> _translateYoudao(
      String text, String targetLanguage) async {
    if (_youdaoAppKey == null || _youdaoAppSecret == null) {
      throw const _TranslationException(
        'Youdao API credentials not configured',
        provider: TranslationProviderType.youdao,
      );
    }

    final salt = Random().nextInt(100000).toString();
    final input = text.length <= 20 ? text : '${text.substring(0, 10)}${text.length}${text.substring(text.length - 10)}';
    final signStr = '$_youdaoAppKey$input$salt$_youdaoAppSecret';
    final sign = _md5Hash(signStr);

    final youdaoLang = _mapToYoudaoLangCode(targetLanguage);

    try {
      final response = await _dio.post<dynamic>(
        _youdaoTranslateUrl,
        data: {
          'q': text,
          'from': 'auto',
          'to': youdaoLang,
          'appKey': _youdaoAppKey,
          'salt': salt,
          'sign': sign,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final data = response.data;
      if (data == null) {
        throw Exception('Empty response from Youdao');
      }

      final Map<String, dynamic> result;
      if (data is Map<String, dynamic>) {
        result = data;
      } else if (data is String) {
        result = jsonDecode(data) as Map<String, dynamic>;
      } else {
        throw Exception('Invalid response format from Youdao');
      }

      if (result.containsKey('errorCode') && result['errorCode'] != '0') {
        throw _TranslationException(
          'Youdao API error: ${result['errorCode']} - ${result['errorMsg'] ?? ''}',
          provider: TranslationProviderType.youdao,
        );
      }

      final translation = result['translation'];
      if (translation is List && translation.isNotEmpty) {
        return (translation as List).cast<String>().join('\n');
      }
      if (translation is String) return translation;

      throw Exception('No translation in Youdao response');
    } on DioException catch (e) {
      throw _TranslationException(
        'Youdao API error: ${e.message}',
        provider: TranslationProviderType.youdao,
      );
    }
  }

  /// Detect language using Youdao API.
  Future<DetectedLanguage?> _detectLanguageYoudao(String text) async {
    if (_youdaoAppKey == null || _youdaoAppSecret == null) return null;

    final salt = Random().nextInt(100000).toString();
    final signStr = '$_youdaoAppKey$text$salt$_youdaoAppSecret';
    final sign = _md5Hash(signStr);

    try {
      final response = await _dio.post<dynamic>(
        _youdaoDetectUrl,
        data: {
          'q': text,
          'appKey': _youdaoAppKey,
          'salt': salt,
          'sign': sign,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final data = response.data;
      if (data == null) return null;

      final Map<String, dynamic> result;
      if (data is Map<String, dynamic>) {
        result = data;
      } else if (data is String) {
        result = jsonDecode(data) as Map<String, dynamic>;
      } else {
        return null;
      }

      final langCode = result['language'] as String?;
      if (langCode != null && langCode.isNotEmpty) {
        return DetectedLanguage(
          languageCode: _normalizeLanguageCode(langCode),
          confidence: 0.9,
          provider: TranslationProviderType.youdao,
        );
      }
    } catch (e) {
      debugPrint('[Translation] Youdao detection error: $e');
    }
    return null;
  }

  // ── Private: Heuristic Detection ────────────────────────────────────────

  String _detectLanguageHeuristic(String text) {
    // Count CJK characters
    int cjkCount = 0;
    int latinCount = 0;
    int cyrillicCount = 0;
    int japaneseKanaCount = 0;

    for (final rune in text.runes) {
      if ((rune >= 0x4E00 && rune <= 0x9FFF) || // CJK Unified Ideographs
          (rune >= 0x3400 && rune <= 0x4DBF)) {
        cjkCount++;
      } else if (rune >= 0x3040 && rune <= 0x30FF) {
        // Hiragana + Katakana
        japaneseKanaCount++;
      } else if ((rune >= 0x0400 && rune <= 0x04FF)) {
        cyrillicCount++;
      } else if ((rune >= 0x0041 && rune <= 0x007A)) {
        latinCount++;
      }
    }

    final total = text.length;
    if (total == 0) return 'unknown';

    if (japaneseKanaCount > total * 0.05) return 'ja';
    if (cjkCount > total * 0.1) {
      // Could be Chinese, Korean, or Japanese with Kanji only.
      // Default to Chinese as it's most common in READMEs.
      return 'zh';
    }
    if (cyrillicCount > total * 0.1) return 'ru';
    if (latinCount > total * 0.5) return 'en';

    return 'unknown';
  }

  // ── Private: Chunking ──────────────────────────────────────────────────

  /// Split text into chunks at paragraph and code block boundaries.
  List<String> _splitTextIntoChunks(String text) {
    final chunks = <String>[];
    final lines = text.split('\n');
    StringBuffer currentChunk = StringBuffer();

    for (final line in lines) {
      final newLength = currentChunk.length + line.length + 1;
      if (newLength > _maxChunkSize && currentChunk.isNotEmpty) {
        chunks.add(currentChunk.toString().trimRight());
        currentChunk = StringBuffer();
      }
      if (currentChunk.isNotEmpty) {
        currentChunk.write('\n');
      }
      currentChunk.write(line);
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString().trimRight());
    }

    return chunks;
  }

  /// Translate a single chunk using the specified provider.
  Future<String> _translateChunk(
    String text,
    String targetLanguage,
    TranslationProviderType provider,
  ) async {
    switch (provider) {
      case TranslationProviderType.google:
        return _translateGoogle(text, targetLanguage);
      case TranslationProviderType.youdao:
        return _translateYoudao(text, targetLanguage);
    }
  }

  // ── Private: Utilities ──────────────────────────────────────────────────

  TranslationProviderType _mapProvider(TranslationProvider provider) {
    return switch (provider) {
      TranslationProvider.google => TranslationProviderType.google,
      TranslationProvider.youdao => TranslationProviderType.youdao,
    };
  }

  String _mapToYoudaoLangCode(String langCode) {
    final map = {
      'zh': 'zh-CHS',
      'zh-CN': 'zh-CHS',
      'zh-TW': 'zh-CHT',
      'en': 'en',
      'ja': 'ja',
      'ko': 'ko',
      'fr': 'fr',
      'de': 'de',
      'es': 'es',
      'pt': 'pt',
      'ru': 'ru',
      'ar': 'ar',
      'it': 'it',
    };
    return map[langCode] ?? langCode;
  }

  String _normalizeLanguageCode(String code) {
    final map = {
      'zh-CHS': 'zh',
      'zh-CHT': 'zh-TW',
      'jap': 'ja',
      'kor': 'ko',
    };
    return map[code.toLowerCase()] ?? code.split('-').first.toLowerCase();
  }

  List<String> _getReadmeLanguageVariants(String languageCode) {
    final map = <String, List<String>>{
      'zh': ['zh-CN', 'zh', 'zh_Hans'],
      'ja': ['ja', 'jp'],
      'ko': ['ko', 'kr'],
      'es': ['es-ES', 'es'],
      'pt': ['pt-BR', 'pt-PT', 'pt'],
      'fr': ['fr-FR', 'fr'],
      'de': ['de-DE', 'de'],
      'ru': ['ru-RU', 'ru'],
      'ar': ['ar-SA', 'ar'],
      'it': ['it-IT', 'it'],
    };
    return map[languageCode] ?? [languageCode];
  }

  /// MD5 hash for Youdao sign generation.
  String _md5Hash(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }
}

/// Exception thrown when translation fails.
class _TranslationException implements Exception {
  const _TranslationException(this.message, {required this.provider});

  final String message;
  final TranslationProviderType provider;

  @override
  String toString() => 'TranslationException($provider): $message';
}
