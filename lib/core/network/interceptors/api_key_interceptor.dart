import 'package:dio/dio.dart';

import '../../config/app_config.dart';

/// Attaches the Bungie `X-API-Key` header to every request.
class ApiKeyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-API-Key'] = AppConfig.bungieApiKey;
    handler.next(options);
  }
}
