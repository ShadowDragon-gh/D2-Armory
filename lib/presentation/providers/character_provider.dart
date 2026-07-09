import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../data/remote/bungie_api.dart';
import '../../data/repositories/character_repository.dart';
import '../../domain/models/destiny_character.dart';
import 'auth_provider.dart';

/// Authenticated Bungie API client. The auth repository doubles as the token
/// provider that supplies/refreshes the Bearer token.
final bungieApiProvider = Provider<BungieApi>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return BungieApi(DioClient.authenticated(auth));
});

final characterRepositoryProvider = Provider<CharacterRepository>((ref) {
  return CharacterRepository(ref.watch(bungieApiProvider));
});

/// The signed-in user's characters. Auto-refetches when re-read after invalidation.
final charactersProvider = FutureProvider<List<DestinyCharacter>>((ref) {
  return ref.watch(characterRepositoryProvider).fetchCharacters();
});
