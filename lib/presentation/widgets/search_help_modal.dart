import 'package:flutter/material.dart';

import '../theme/armory_palette.dart';
import '../theme/armory_theme_extension.dart';

/// A single documented filter: the [syntax] a user types and what it [does].
class _Filter {
  const _Filter(this.syntax, this.does);
  final String syntax;
  final String does;
}

/// A titled group of related filters, with an optional [note] shown under the
/// title (e.g. "Inventory tab only").
class _Section {
  const _Section(this.title, this.filters, {this.note});
  final String title;
  final List<_Filter> filters;
  final String? note;
}

/// The full search grammar, grouped for the reference modal. Mirrors the terms
/// [compileQuery] understands (see core/search/item_filter.dart); keep the two
/// in step when filters are added or removed.
const List<_Section> _sections = [
  _Section('Item name', [
    _Filter('fatebringer', 'Bare text matches any item whose name contains it.'),
    _Filter('name:"the messenger"', 'Quote a value that has spaces.'),
    _Filter('exactname:"gjallarhorn"', 'Match the full name exactly.'),
  ]),
  _Section('Type, element & rarity — is:', [
    _Filter('is:weapon  is:armor', 'Broad item class.'),
    _Filter('is:handcannon  is:sniperrifle  is:smg',
        'Weapon type (any weapon subtype).'),
    _Filter('is:solar  is:void  is:arc  is:stasis  is:strand',
        'Damage element. is:kinetic is the kinetic element.'),
    _Filter('is:light  is:dark', 'Element family.'),
    _Filter('is:exotic  is:legendary  is:rare', 'Rarity.'),
    _Filter('is:titan  is:hunter  is:warlock', 'Armor class affinity.'),
    _Filter('is:helmet  is:gauntlets  is:chest  is:legs  is:classitem',
        'Armor slot.'),
    _Filter('is:kineticslot  is:energy  is:power', 'Weapon slot.'),
    _Filter('ammo:primary  ammo:special  ammo:heavy', 'Ammunition type.'),
  ]),
  _Section('Perks & frames', [
    _Filter('perk:rampage', 'Weapon can roll a trait perk matching the text.'),
    _Filter('perk1:outlaw  perk2:"kill clip"',
        'Restrict to the first or second trait column.'),
    _Filter('frame:adaptive  frame:"rapid-fire"', 'Intrinsic frame / archetype.'),
    _Filter('breaker:overload  breaker:barrier  breaker:unstoppable',
        'Champion breaker the weapon counters.'),
  ]),
  _Section('Stats', [
    _Filter('stat:range:>70', 'A stat compared: >, <, >=, <=, or = a value.'),
    _Filter('stat:stability:>=60  stat:handling:<40', 'Any stat name works.'),
    _Filter('stat:mobility', 'No comparison → the item simply has that stat.'),
  ]),
  _Section('Source & text', [
    _Filter('source:seraph  source:raid', "Where the item comes from."),
    _Filter('description:"kills with this"', 'Match the flavor / description text.'),
    _Filter('keyword:volatile',
        'Broad match across name, description, and perks.'),
  ]),
  _Section('Live account data', [
    _Filter('power:>1800  light:<=1600', 'Instance power level.'),
    _Filter('is:equipped  is:masterwork  is:locked', 'Instance state.'),
    _Filter('count:>1', 'How many copies you own (duplicates).'),
    _Filter('catalyst:complete  catalyst:incomplete  catalyst:missing',
        'Exotic catalyst progress. Bare catalyst: matches any that has one.'),
  ], note: 'Inventory tab only — these need your live profile. On the Database '
      'tab they are flagged and ignored.'),
  _Section('Combining & excluding', [
    _Filter('is:solar is:handcannon perk:rampage',
        'Multiple terms are AND — an item must match all of them.'),
    _Filter('-is:exotic', 'A leading - excludes matches.'),
    _Filter('not:masterwork', 'not: is an alternative way to exclude.'),
  ]),
];

/// Show the search & filter reference modal. Self-contained — it takes no
/// providers, so both tabs open the same guide.
Future<void> showSearchHelpModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _SearchHelpModal(),
  );
}

class _SearchHelpModal extends StatelessWidget {
  const _SearchHelpModal();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.all(32),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type filters into the search bar to narrow the list. '
                      'The bar autocompletes filter keys and perk names as you '
                      'type — press Tab or Enter to accept a suggestion.',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    for (final section in _sections) ...[
                      _SectionView(section: section),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
      child: Row(
        children: [
          Icon(Icons.search, size: 20, color: context.armory.accent200),
          const SizedBox(width: 10),
          Text(
            'Search & Filters',
            style: const TextStyle(
              fontFamily: ArmoryFonts.display,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final _Section section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title.toUpperCase(),
          style: TextStyle(
            fontFamily: ArmoryFonts.display,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: context.armory.accent200,
          ),
        ),
        if (section.note != null) ...[
          const SizedBox(height: 4),
          Text(
            section.note!,
            style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 10),
        for (final filter in section.filters) _FilterRow(filter: filter),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.filter});

  final _Filter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The syntax, in a subtle mono chip so it reads as "type this".
          SizedBox(
            width: 260,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: ArmoryRadius.sm,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                filter.syntax,
                style: const TextStyle(
                    fontFamily: ArmoryFonts.mono, fontSize: 12, height: 1.3),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                filter.does,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
