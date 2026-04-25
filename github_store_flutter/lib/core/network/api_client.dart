import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/api_constants.dart';

part 'api_client.g.dart';

/// Enum for supported API versions.
enum ApiVersion {
  v3('v3'),
  graphql('graphql');

  const ApiVersion(this.value);
  final String value;
}

/// Custom exception class for API errors.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.path,
  });

  final String message;
  final int? statusCode;
  final String? errorCode;
  final String? path;

  @override
  String toString() =>
      'ApiException: $message (status: $statusCode, code: $errorCode, path: $path)';

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isRateLimited => statusCode == 429;
  bool get isServerError => statusCode != null && statusCode! >= 500;
}

/// Type alias for the Dio HTTP client.
typedef HttpClient = Dio;

/// Provider for the API client singleton.
@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  return ApiClient();
}

/// Core HTTP client wrapping Dio with interceptors, retry logic, and auth support.
class ApiClient {
  ApiClient() {
    _initDio();
  }

  late final Dio _dio;
  String? _authToken;
  int _remainingRequests = 5000;
  int _rateLimitReset = 0;

  // ── Initialization ─────────────────────────────────────────────────────

  void _initDio() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.githubApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 15),
        maxRedirects: 5,
        headers: Map<String, dynamic>.from(ApiConstants.defaultHeaders),
        validateStatus: (status) => status != null && status < 600,
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(() => _authToken),
      _RateLimitInterceptor(
        onRateLimited: _handleRateLimit,
        onRemainingUpdate: (remaining, reset) {
          _remainingRequests = remaining;
          _rateLimitReset = reset;
        },
      ),
      _LoggingInterceptor(),
      _RetryInterceptor(_dio),
      _ErrorInterceptor(),
    ]);

    _dio.transformer = BackgroundTransformer();
  }

  // ── Auth ───────────────────────────────────────────────────────────────

  void setAuthToken(String? token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  bool get isAuthenticated => _authToken != null;
  int get remainingRequests => _remainingRequests;

  // ── Rate Limit Handling ────────────────────────────────────────────────

  Future<void> _handleRateLimit(int resetTime) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final waitSeconds = resetTime > now ? resetTime - now : 60;
    await Future.delayed(Duration(seconds: waitSeconds));
  }

  // ── REST Methods ───────────────────────────────────────────────────────

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ApiVersion version = ApiVersion.v3,
    String? customBaseUrl,
  }) async {
    final opts = _applyVersionHeaders(options, version);
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: _applyBaseUrl(opts, customBaseUrl),
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ApiVersion version = ApiVersion.v3,
    String? customBaseUrl,
  }) async {
    final opts = _applyVersionHeaders(options, version);
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _applyBaseUrl(opts, customBaseUrl),
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ApiVersion version = ApiVersion.v3,
    String? customBaseUrl,
  }) async {
    final opts = _applyVersionHeaders(options, version);
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _applyBaseUrl(opts, customBaseUrl),
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ApiVersion version = ApiVersion.v3,
    String? customBaseUrl,
  }) async {
    final opts = _applyVersionHeaders(options, version);
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _applyBaseUrl(opts, customBaseUrl),
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ApiVersion version = ApiVersion.v3,
    String? customBaseUrl,
  }) async {
    final opts = _applyVersionHeaders(options, version);
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _applyBaseUrl(opts, customBaseUrl),
      cancelToken: cancelToken,
    );
  }

  // ── GraphQL ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> graphQl(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    final response = await post<Map<String, dynamic>>(
      ApiConstants.githubGraphQlUrl,
      data: {
        'query': query,
        if (variables != null) 'variables': variables,
      },
      customBaseUrl: ApiConstants.githubApiBaseUrl,
    );

    final data = response.data;
    if (data == null) {
      throw const ApiException(message: 'Empty response from GraphQL');
    }

    if (data.containsKey('errors')) {
      final errors = data['errors'] as List;
      final message = errors
          .map((e) => (e as Map)['message'] as String? ?? 'Unknown error')
          .join('; ');
      throw ApiException(message: message);
    }

    return data;
  }

  // ── Streaming / Paginated ──────────────────────────────────────────────

  Future<List<T>> fetchAllPages<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    int perPage = 100,
    required T Function(Map<String, dynamic> json) fromJson,
    CancelToken? cancelToken,
  }) async {
    final allItems = <T>[];
    int page = 1;

    while (true) {
      final queryParams = <String, dynamic>{
        'per_page': perPage,
        'page': page,
        ...?queryParameters,
      };

      final response = await get<List<dynamic>>(
        path,
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data == null || data.isEmpty) break;

      for (final item in data) {
        if (item is Map<String, dynamic>) {
          allItems.add(fromJson(item));
        }
      }

      // Check if we should continue paginating
      final linkHeader = response.headers.value('link');
      if (linkHeader == null || !linkHeader.contains('rel="next"')) break;

      page++;
    }

    return allItems;
  }

  // ── Download ───────────────────────────────────────────────────────────

  Future<Response> downloadFile(
    String urlPath, {
    required String savePath,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.download(
      urlPath,
      savePath,
      onReceiveProgress: onReceiveProgress,
      cancelToken: cancelToken,
      queryParameters: queryParameters,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Options _applyVersionHeaders(Options? options, ApiVersion version) {
    if (version == ApiVersion.graphql) {
      return (options ?? Options()).copyWith(
        headers: {
          'Content-Type': 'application/json',
          ...?options?.headers,
        },
      );
    }
    return options ?? Options();
  }

  Options _applyBaseUrl(Options? options, String? customBaseUrl) {
    if (customBaseUrl == null) return options ?? Options();
    return (options ?? Options()).copyWith(
      extra: {'custom_base_url': customBaseUrl},
    );
  }

  /// Paged fetch helper with cursor-based pagination for GraphQL.
  Stream<Map<String, dynamic>> graphQlPaginatedStream(
    String query, {
    required String initialCursor,
    required Map<String, dynamic> Function(Map<String, dynamic>) pageInfoExtractor,
    required Map<String, dynamic> Function(Map<String, dynamic>) nodesExtractor,
    int pageSize = 30,
  }) async* {
    String? cursor = initialCursor.isEmpty ? null : initialCursor;

    while (true) {
      final variables = <String, dynamic>{
        'first': pageSize,
        if (cursor != null) 'after': cursor,
      };

      final result = await graphQl(query, variables: variables);
      final pageInfo = pageInfoExtractor(result);
      final hasNext = pageInfo['hasNextPage'] as bool? ?? false;

      yield result;

      if (!hasNext) break;
      cursor = pageInfo['endCursor'] as String?;
    }
  }
}

// ── Interceptors ──────────────────────────────────────────────────────────

/// Interceptor that adds the Authorization header when a token is available.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokenProvider);

  final String? Function() _tokenProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token might be expired; caller should handle re-authentication
    }
    handler.next(err);
  }
}

/// Interceptor that tracks rate limiting headers and pauses when limited.
class _RateLimitInterceptor extends Interceptor {
  _RateLimitInterceptor({
    required this.onRateLimited,
    required this.onRemainingUpdate,
  });

  final Future<void> Function(int resetTime) onRateLimited;
  final void Function(int remaining, int reset) onRemainingUpdate;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final remaining = response.headers.value('x-ratelimit-remaining');
    final reset = response.headers.value('x-ratelimit-reset');

    if (remaining != null) {
      onRemainingUpdate(int.parse(remaining), int.tryParse(reset ?? '0') ?? 0);
    }

    // Check for rate limit hit
    if (response.statusCode == 429) {
      final resetTime = int.tryParse(reset ?? '0') ?? 0;
      throw ApiException(
        message: 'Rate limit exceeded. Reset at $reset.',
        statusCode: 429,
        errorCode: 'RATE_LIMITED',
      );
    }

    handler.next(response);
  }
}

/// Interceptor that logs request/response details in debug mode.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint(
      '[API] ${options.method} ${options.baseUrl}${options.path} '
      '${options.queryParameters.isNotEmpty ? '?${options.queryParameters}' : ''}',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[API] ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.path}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '[API] ERROR ${err.response?.statusCode ?? 'NO_RESPONSE'} '
      '${err.requestOptions.method} ${err.requestOptions.path}: '
      '${err.message}',
    );
    handler.next(err);
  }
}

/// Interceptor that retries failed requests with exponential backoff.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  final Dio _dio;
  static const _maxRetries = 3;
  static const _retryDelay = Duration(milliseconds: 1000);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;

    final shouldRetry = _shouldRetry(err) && retryCount < _maxRetries;

    if (shouldRetry) {
      final delay = _retryDelay * (1 << retryCount); // Exponential backoff
      debugPrint('[API] Retrying (${retryCount + 1}/$_maxRetries) after ${delay.inMilliseconds}ms');

      await Future.delayed(delay);

      final newOptions = err.requestOptions.copyWith(
        extra: {'retryCount': retryCount + 1},
      );

      try {
        final response = await _dio.fetch(newOptions);
        handler.resolve(response);
        return;
      } on DioException catch (e) {
        handler.next(e);
        return;
      }
    }

    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return true;
    }
    final status = err.response?.statusCode;
    return status == 429 || status == 500 || status == 502 || status == 503;
  }
}

/// Interceptor that converts Dio errors to typed ApiException.
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiException = _convertError(err);
    handler.next(DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: apiException,
    ));
    handler.next(err);
  }

  ApiException _convertError(DioException err) {
    String message;
    int? statusCode = err.response?.statusCode;
    String? errorCode;
    String? path = err.requestOptions.path;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        errorCode = 'CONNECTION_TIMEOUT';
      case DioExceptionType.sendTimeout:
        message = 'Request send timeout. The server is taking too long.';
        errorCode = 'SEND_TIMEOUT';
      case DioExceptionType.receiveTimeout:
        message = 'Response timeout. The server took too long to respond.';
        errorCode = 'RECEIVE_TIMEOUT';
      case DioExceptionType.badResponse:
        message = _parseErrorMessage(err.response);
        errorCode = _parseErrorCode(err.response);
      case DioExceptionType.cancel:
        message = 'Request was cancelled.';
        errorCode = 'CANCELLED';
      case DioExceptionType.connectionError:
        message = 'No internet connection. Please check your network.';
        errorCode = 'NO_CONNECTION';
      case DioExceptionType.badCertificate:
        message = 'SSL certificate error. This could be a security issue.';
        errorCode = 'BAD_CERTIFICATE';
      case DioExceptionType.unknown:
        message = 'An unexpected error occurred: ${err.message}';
        errorCode = 'UNKNOWN';
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      errorCode: errorCode,
      path: path,
    );
  }

  String _parseErrorMessage(Response? response) {
    if (response?.data == null) return 'Server returned an error.';

    try {
      final data = response!.data;
      if (data is Map<String, dynamic>) {
        // GitHub API format
        if (data.containsKey('message')) return data['message'] as String;
        // GraphQL errors
        if (data.containsKey('errors')) {
          final errors = data['errors'] as List;
          return errors
              .map((e) => (e as Map)['message'] ?? 'Unknown error')
              .join('; ');
        }
      }
      if (data is String) {
        try {
          final parsed = jsonDecode(data) as Map<String, dynamic>;
          return parsed['message'] as String? ?? 'Server error';
        } catch (_) {
          return data;
        }
      }
    } catch (_) {}

    return 'Server error (${response?.statusCode})';
  }

  String? _parseErrorCode(Response? response) {
    if (response?.data is Map<String, dynamic>) {
      return (response!.data as Map<String, dynamic>)['error_code'] as String?;
    }
    return null;
  }
}
