import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'interceptors/api_key_interceptor.dart';
import 'interceptors/auth_interceptor.dart';

/// Builds the Dio instances used to talk to Bungie.
class DioClient {
  const DioClient._();

  static BaseOptions get _baseOptions => BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      );

  /// Dio carrying only the API key. Used for OAuth token exchange, where no
  /// Bearer token exists yet.
  static Dio unauthenticated() => Dio(_baseOptions)
    ..interceptors.add(ApiKeyInterceptor());

  /// Dio carrying the API key and a Bearer token, with 401 refresh-and-retry.
  static Dio authenticated(TokenProvider tokens) {
    final dio = Dio(_baseOptions)..interceptors.add(ApiKeyInterceptor());
    dio.interceptors.add(AuthInterceptor(tokens, dio));
    return dio;
  }
}
