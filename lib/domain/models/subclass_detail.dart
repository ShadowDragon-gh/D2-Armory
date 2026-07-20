import '../../core/config/app_config.dart';
import 'destiny_item.dart';
import 'item_detail.dart';

/// The resolved, editable configuration of a subclass: the base [item], its
/// element, art, and its sockets grouped like the in-game screen (Abilities,
/// Super, Aspects, Fragments). Built from the live socket (305) / reusable-plug
/// (310) components plus the subclass definition's socket categories.
class SubclassDetail {
  const SubclassDetail({
    required this.item,
    required this.element,
    required this.screenshotPath,
    required this.groups,
    this.owned = true,
  });

  final DestinyItem item;

  /// The subclass's element from `talentGrid.hudDamageType` (2=Arc … 7=Strand),
  /// driving the header accent colour.
  final int element;

  final String screenshotPath;

  /// One group per socket category (Abilities, Super, Aspects, Fragments, and
  /// any Prismatic extras), in the definition's category order.
  final List<SubclassSocketGroup> groups;

  /// Whether the character owns this subclass (has a live instance). False for a
  /// definition-only subclass injected into the grid — the modal shows every
  /// option for browsing, but none is equippable, and a "not unlocked" notice
  /// is shown.
  final bool owned;

  String? get screenshotUrl => screenshotPath.isEmpty
      ? null
      : '${AppConfig.bungieBaseUrl}$screenshotPath';
}

/// One socket category of a subclass (e.g. Abilities), labelled by the
/// `DestinySocketCategoryDefinition` name.
class SubclassSocketGroup {
  const SubclassSocketGroup({required this.label, required this.sockets});

  final String label;
  final List<SubclassSocket> sockets;
}

/// How an option renders in a socket's picker.
enum SubclassOptionState {
  /// Unlocked and selectable in this socket (in its live 310, or the plug
  /// already equipped here).
  equippable,

  /// Owned but currently socketed in another slot of the same category — the
  /// game blocks the same aspect/fragment in two slots, so it is shown (not
  /// "not unlocked") but not selectable here.
  equippedElsewhere,

  /// Not unlocked by the character — viewable for its details, not equippable.
  locked,
}

/// One editable socket within a group: the equipped plug and the selectable
/// options for it. [socketIndex] pairs with a plug hash for an in-game insert.
class SubclassSocket {
  const SubclassSocket({
    required this.socketIndex,
    required this.equipped,
    required this.options,
    this.equippableHashes = const {},
    this.equippedElsewhereHashes = const {},
    this.available = true,
  });

  final int socketIndex;

  /// The plug currently in the socket (from the live 305 component), or null
  /// when the socket is empty.
  final ItemPlug? equipped;

  /// Every plug this socket can hold, from the definition's reusable plug set —
  /// including options the character has not unlocked, so they are viewable.
  /// Includes the "Empty … Socket" placeholder (inserting one removes the plug).
  final List<ItemPlug> options;

  /// The plug hashes in [options] the character has actually unlocked (present
  /// in the instance's live ItemReusablePlugs (310) component) — the only ones
  /// that can be equipped here. Options not in this set are not selectable.
  final Set<int> equippableHashes;

  /// Owned plug hashes currently equipped in *another* socket of the same group
  /// (aspects/fragments can't be duplicated across slots). Shown as owned but
  /// not selectable here — distinct from a not-unlocked option.
  final Set<int> equippedElsewhereHashes;

  /// Whether this socket can currently hold a plug. False for an empty fragment
  /// socket beyond the slot count the equipped aspects grant (their summed
  /// "Aspect Energy Capacity") — the game disables such slots, so the modal
  /// greys them out and blocks the picker.
  final bool available;

  /// How [option] renders in this socket, in precedence order:
  ///  1. the plug already equipped *here* → [SubclassOptionState.equippable]
  ///     (a re-select is never blocked);
  ///  2. a plug equipped in *another* slot of this group →
  ///     [SubclassOptionState.equippedElsewhere] — this wins over ownership
  ///     because the same aspect/fragment can't be socketed twice, even though
  ///     the account-wide plug set reports it as insertable elsewhere;
  ///  3. an unlocked, insertable plug ([equippableHashes]) →
  ///     [SubclassOptionState.equippable];
  ///  4. otherwise [SubclassOptionState.locked].
  SubclassOptionState optionState(ItemPlug option) {
    if (option.plugHash == equipped?.plugHash) {
      return SubclassOptionState.equippable;
    }
    if (equippedElsewhereHashes.contains(option.plugHash)) {
      return SubclassOptionState.equippedElsewhere;
    }
    if (available && equippableHashes.contains(option.plugHash)) {
      return SubclassOptionState.equippable;
    }
    return SubclassOptionState.locked;
  }

  /// Whether [option] can be equipped by clicking it in this socket.
  bool canEquip(ItemPlug option) =>
      optionState(option) == SubclassOptionState.equippable;
}
