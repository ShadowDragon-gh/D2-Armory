import 'package:dio/dio.dart';

import '../../core/errors/failures.dart';

/// Thin wrapper over the Bungie Destiny2 endpoints used by the app. Takes an
/// authenticated [Dio] (API key + Bearer token via interceptors) and returns
/// the decoded `Response` payload from the platform envelope.
class BungieApi {
  BungieApi(this._dio);

  final Dio _dio;

  /// GET /Destiny2/Manifest/ — manifest version + per-language content paths.
  /// Public endpoint (only the API key is required).
  Future<Map<String, dynamic>> getManifest() =>
      _getResponse('/Destiny2/Manifest/');

  /// GET /User/GetMembershipsForCurrentUser/ — the signed-in user's platform
  /// memberships and cross-save primary.
  Future<Map<String, dynamic>> getMembershipsForCurrentUser() =>
      _getResponse('/User/GetMembershipsForCurrentUser/');

  /// GET /Destiny2/{type}/Profile/{id}/?components=... — profile data.
  Future<Map<String, dynamic>> getProfile({
    required int membershipType,
    required String membershipId,
    required List<int> components,
  }) =>
      _getResponse(
        '/Destiny2/$membershipType/Profile/$membershipId/',
        query: {'components': components.join(',')},
      );

  /// Performs the GET and unwraps Bungie's platform envelope, which nests the
  /// payload under `Response` and signals errors via `ErrorCode` (1 = Success).
  Future<Map<String, dynamic>> _getResponse(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(path,
          queryParameters: query);
      final body = res.data;
      if (body == null) {
        throw const ApiFailure('Empty response from Bungie.');
      }
      final errorCode = (body['ErrorCode'] as num?)?.toInt();
      if (errorCode != null && errorCode != 1) {
        throw ApiFailure(
          (body['Message'] as String?) ?? 'Bungie returned error $errorCode.',
          statusCode: res.statusCode,
          errorCode: errorCode,
        );
      }
      final response = body['Response'];
      if (response is! Map<String, dynamic>) {
        throw const ApiFailure('Bungie response envelope had no Response.');
      }
      return response;
    } on DioException catch (e) {
      throw _mapDioError(e, path);
    }
  }

  Failure _mapDioError(DioException e, String path) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return NetworkFailure('Network error reaching $path.', cause: e);
    }
    final data = e.response?.data;
    final errorCode = data is Map ? (data['ErrorCode'] as num?)?.toInt() : null;
    return ApiFailure(
      'Bungie request to $path failed.',
      statusCode: e.response?.statusCode,
      errorCode: errorCode,
      cause: e,
    );
  }
}
