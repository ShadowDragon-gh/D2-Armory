import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Disk cache for Destiny item icons.
///
/// The default [CacheManager] caps at 200 objects, so a full account (hundreds
/// of items) evicts its own icons between sessions and re-downloads them from
/// the Bungie CDN on every launch. This raises the cap well past a full
/// inventory + vault and extends the stale window, so once an icon is fetched
/// it stays on local disk — later launches load icons locally instead of over
/// HTTP.
class ItemIconCache {
  const ItemIconCache._();

  static const key = 'itemIconCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      maxNrOfCacheObjects: 4000,
      stalePeriod: const Duration(days: 90),
    ),
  );
}
