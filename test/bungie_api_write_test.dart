import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/core/errors/failures.dart';
import 'package:d2_armory/data/remote/bungie_api.dart';

class _MockDio extends Mock implements Dio {}

/// A platform-envelope response with the given [errorCode] (1 = success).
Response<Map<String, dynamic>> _envelope(int errorCode, {String? message}) =>
    Response(
      requestOptions: RequestOptions(path: '/'),
      statusCode: errorCode == 1 ? 200 : 500,
      data: {
        'Response': 0,
        'ErrorCode': errorCode,
        'Message': ?message,
      },
    );

void main() {
  late _MockDio dio;
  late BungieApi api;

  setUp(() {
    dio = _MockDio();
    api = BungieApi(dio);
  });

  /// Captures the path + JSON body of the single `dio.post` call. Each
  /// `verify` consumes the recorded interaction, so this must be called once
  /// per test and both values read from its result.
  ({String path, Map<String, dynamic> body}) capturePost() {
    final captured = verify(() => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        )).captured;
    return (
      path: captured[0] as String,
      body: captured[1] as Map<String, dynamic>,
    );
  }

  group('transferItem', () {
    test('posts to TransferItem with the correct body (to vault)', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data')))
          .thenAnswer((_) async => _envelope(1));

      await api.transferItem(
        itemReferenceHash: 1234,
        itemId: '6789',
        transferToVault: true,
        characterId: 'charA',
        membershipType: 3,
      );

      final post = capturePost();
      expect(post.path, '/Destiny2/Actions/Items/TransferItem/');
      expect(post.body, {
        'itemReferenceHash': 1234,
        'stackSize': 1,
        'transferToVault': true,
        'itemId': '6789',
        'characterId': 'charA',
        'membershipType': 3,
      });
    });

    test('posts transferToVault:false when pulling from the vault', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data')))
          .thenAnswer((_) async => _envelope(1));

      await api.transferItem(
        itemReferenceHash: 1,
        itemId: '2',
        transferToVault: false,
        characterId: 'charB',
        membershipType: 3,
      );

      final post = capturePost();
      expect(post.body['transferToVault'], isFalse);
      expect(post.body['characterId'], 'charB');
    });

    test('maps a non-success ErrorCode to ApiFailure carrying code + message',
        () async {
      // 1642 = DestinyItemActionForbidden-ish "destination full" style error.
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data')))
          .thenAnswer((_) async =>
              _envelope(1642, message: 'That destination is full.'));

      await expectLater(
        api.transferItem(
          itemReferenceHash: 1,
          itemId: '2',
          transferToVault: false,
          characterId: 'c',
          membershipType: 3,
        ),
        throwsA(isA<ApiFailure>()
            .having((f) => f.errorCode, 'errorCode', 1642)
            .having((f) => f.message, 'message', 'That destination is full.')),
      );
    });

    test('maps a dio connection error to NetworkFailure', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      ));

      await expectLater(
        api.transferItem(
          itemReferenceHash: 1,
          itemId: '2',
          transferToVault: true,
          characterId: 'c',
          membershipType: 3,
        ),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('equipItem', () {
    test('posts to EquipItem with the correct body', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data')))
          .thenAnswer((_) async => _envelope(1));

      await api.equipItem(itemId: '55', characterId: 'charA', membershipType: 3);

      final post = capturePost();
      expect(post.path, '/Destiny2/Actions/Items/EquipItem/');
      expect(post.body, {
        'itemId': '55',
        'characterId': 'charA',
        'membershipType': 3,
      });
    });

    test('surfaces an equip error code as ApiFailure', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data')))
          .thenAnswer((_) async =>
              _envelope(1623, message: 'Item is not on that character.'));

      await expectLater(
        api.equipItem(itemId: '55', characterId: 'c', membershipType: 3),
        throwsA(isA<ApiFailure>().having((f) => f.errorCode, 'errorCode', 1623)),
      );
    });
  });
}
