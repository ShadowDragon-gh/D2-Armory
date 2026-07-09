import 'package:dio/dio.dart';

/// Supplies access tokens to [AuthInterceptor], abstracting away the auth
/// repository so the network layer does not depend on it directly.
abstract class TokenProvider {
  /// A currently-valid access token, refreshing proactively if needed.
  /// Returns null when the user is not signed in.
  Future<String?> validAccessToken();

  /// Force a token refresh after a rejected request. Returns the new access
  /// token, or null if refresh failed (caller should surface re-auth).
  Future<String?> forceRefresh();
}

/// Attaches `Authorization: Bearer <token>` to requests and, on a 401,
/// refreshes once and retries the original request.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokens, this._dio);

  final TokenProvider _tokens;
  final Dio _dio;

  static const _retriedFlag = 'auth_retried';

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _tokens.validAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final alreadyRetried = err.requestOptions.extra[_retriedFlag] == true;

    if (response?.statusCode != 401 || alreadyRetried) {
      return handler.next(err);
    }

    final newToken = await _tokens.forceRefresh();
    if (newToken == null) {
      // Refresh failed — let the original 401 propagate so the app can
      // surface re-authentication rather than silently swallowing it.
      return handler.next(err);
    }

    final retryOptions = err.requestOptions
      ..headers['Authorization'] = 'Bearer $newToken'
      ..extra[_retriedFlag] = true;

    try {
      final retried = await _dio.fetch<dynamic>(retryOptions);
      handler.resolve(retried);
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
