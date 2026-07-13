import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:d2_armory/data/repositories/update_repository.dart';
import 'package:d2_armory/domain/models/app_version.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _response(int status, dynamic data) => Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      statusCode: status,
      data: data,
    );

Map<String, dynamic> _release(String tag) => {
      'tag_name': tag,
      'body': null,
      'assets': [
        {
          'name': 'D2Armory-$tag.zip',
          'size': 100,
          'browser_download_url': 'https://example.com/$tag.zip',
        },
      ],
    };

void main() {
  late _MockDio dio;
  late UpdateRepository repo;
  const current = AppVersion(1, 0, 0);

  setUp(() {
    dio = _MockDio();
    repo = UpdateRepository(dio);
  });

  void stubGet(Response<dynamic> response) {
    when(() => dio.get<dynamic>(any(), options: any(named: 'options')))
        .thenAnswer((_) async => response);
  }

  test('returns the release when GitHub reports a newer version', () async {
    stubGet(_response(200, _release('v1.1.0')));
    final release = await repo.checkForUpdate(current);
    expect(release, isNotNull);
    expect(release!.version, const AppVersion(1, 1, 0));
  });

  test('returns null when the latest version equals the current one', () async {
    stubGet(_response(200, _release('v1.0.0')));
    expect(await repo.checkForUpdate(current), isNull);
  });

  test('returns null when the latest version is older', () async {
    stubGet(_response(200, _release('v0.9.0')));
    expect(await repo.checkForUpdate(current), isNull);
  });

  test('treats a 404 (private repo / no release) as no update, not an error',
      () async {
    stubGet(_response(404, {'message': 'Not Found'}));
    expect(await repo.checkForUpdate(current), isNull);
  });

  test('treats a network error as inconclusive (null), not a crash', () async {
    when(() => dio.get<dynamic>(any(), options: any(named: 'options')))
        .thenThrow(DioException(requestOptions: RequestOptions(path: '')));
    expect(await repo.checkForUpdate(current), isNull);
  });
}
