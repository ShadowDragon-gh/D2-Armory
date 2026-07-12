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

  /// POST /Destiny2/Actions/Items/TransferItem/ — move an instanced item
  /// between a character and the vault. [transferToVault] chooses direction;
  /// [characterId] is always the character side of the move (source when
  /// transferring to the vault, destination when transferring from it).
  /// Requires the `MoveEquipDestinyItems` OAuth scope.
  Future<void> transferItem({
    required int itemReferenceHash,
    required String itemId,
    required bool transferToVault,
    required String characterId,
    required int membershipType,
    int stackSize = 1,
  }) =>
      _postResponse('/Destiny2/Actions/Items/TransferItem/', {
        'itemReferenceHash': itemReferenceHash,
        'stackSize': stackSize,
        'transferToVault': transferToVault,
        'itemId': itemId,
        'characterId': characterId,
        'membershipType': membershipType,
      });

  /// POST /Destiny2/Actions/Items/EquipItem/ — equip an instanced item that is
  /// already on [characterId]. Requires the `MoveEquipDestinyItems` OAuth scope.
  Future<void> equipItem({
    required String itemId,
    required String characterId,
    required int membershipType,
  }) =>
      _postResponse('/Destiny2/Actions/Items/EquipItem/', {
        'itemId': itemId,
        'characterId': characterId,
        'membershipType': membershipType,
      });

  /// POST /Destiny2/Actions/Items/InsertSocketPlugFree/ — insert [plugItemHash]
  /// into the [socketIndex] socket of the instanced item [itemId] on
  /// [characterId]. Used to select a weapon perk or mod. This is the "free and
  /// reversible" socket action: it needs only the `MoveEquipDestinyItems` scope
  /// (not `AdvancedWriteActions`, which the material-consuming `InsertSocketPlug`
  /// requires). Bungie only allows randomized/reusable plugs with no insertion
  /// material cost, and will not overwrite a non-free plug with a free one.
  Future<void> insertSocketPlugFree({
    required String itemId,
    required String characterId,
    required int membershipType,
    required int socketIndex,
    required int plugItemHash,
  }) =>
      _postResponse('/Destiny2/Actions/Items/InsertSocketPlugFree/', {
        'itemId': itemId,
        'characterId': characterId,
        'membershipType': membershipType,
        'socketIndex': socketIndex,
        'plug': {
          'socketIndex': socketIndex,
          'plugItemHash': plugItemHash,
          'plugObjectiveValues': const <String, dynamic>{},
        },
      });

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

  /// POSTs [body] as JSON and checks Bungie's platform envelope for success.
  /// Action endpoints (transfer/equip) signal the outcome via `ErrorCode`
  /// (1 = Success) and return a trivial `Response` (usually the int 0), so —
  /// unlike [_getResponse] — the payload itself is not unwrapped or returned.
  Future<void> _postResponse(String path, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(path, data: body);
      final data = res.data;
      if (data == null) {
        throw const ApiFailure('Empty response from Bungie.');
      }
      final errorCode = (data['ErrorCode'] as num?)?.toInt();
      if (errorCode != null && errorCode != 1) {
        throw ApiFailure(
          (data['Message'] as String?) ?? 'Bungie returned error $errorCode.',
          statusCode: res.statusCode,
          errorCode: errorCode,
        );
      }
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
