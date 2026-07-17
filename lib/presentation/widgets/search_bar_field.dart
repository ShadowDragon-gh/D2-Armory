import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../../core/network/item_icon_cache.dart';
import '../../core/search/search_suggestions.dart';
import '../theme/armory_palette.dart';
import '../theme/armory_theme_extension.dart';
import 'search_help_modal.dart';

/// The shared search field with filter autocomplete, used by both the Inventory
/// and Database tabs. It owns the text controller, the suggestion overlay, and
/// the Escape-to-clear behaviour; the caller supplies the query text, a setter,
/// the autocomplete [names], the [unsupported] terms to flag, and whether
/// live-data filters should be suggested ([instanceData]). State (which query
/// each tab holds) stays with the caller — this widget is provider-agnostic.
class SearchBarField extends StatefulWidget {
  const SearchBarField({
    super.key,
    required this.text,
    required this.onChanged,
    required this.unsupported,
    this.names = const [],
    this.perks = const [],
    this.frames = const [],
    this.setEffects = const [],
    this.warming = false,
    this.instanceData = true,
    this.hintText = 'Filter items — e.g. is:solar is:handcannon power:>540',
    this.height = 40,
    this.fontSize = 14,
  });

  /// The query text. Seeds the field, and is re-applied when it changes to a
  /// value the field did not itself produce (an external set — e.g. a chip that
  /// injects a query). The field still owns the controller while the user types.
  final String text;

  /// Called with the full query text on every edit or suggestion pick.
  final ValueChanged<String> onChanged;

  /// Terms recognized but not evaluable on this tab, surfaced via a tooltip.
  final List<String> unsupported;

  /// Item names offered as `name:"..."` autocomplete suggestions.
  final List<String> names;

  /// The perk catalog (name + icon) offered as `perk:` value autocomplete.
  final List<PerkOption> perks;

  /// The archetype-frame catalog (name + icon) offered as `frame:` value
  /// autocomplete.
  final List<PerkOption> frames;

  /// The set-effect catalog (name + icon) offered as `set:`/`set2:`/`set4:`
  /// value autocomplete.
  final List<PerkOption> setEffects;

  /// Whether background facet warming is still running, so the definition-backed
  /// filters (`perk:`/`stat:`/`source:`/…) and the perk autocomplete are not yet
  /// fully populated. Surfaced as a spinner in the field so the user knows the
  /// search is still coming online.
  final bool warming;

  /// Whether to suggest filters that need live account data (power/count/…).
  final bool instanceData;

  final String hintText;
  final double height;
  final double fontSize;

  @override
  State<SearchBarField> createState() => _SearchBarFieldState();
}

class _SearchBarFieldState extends State<SearchBarField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _overlayController = OverlayPortalController();
  final _link = LayerLink();

  List<Suggestion> _suggestions = const [];

  /// The highlighted suggestion the arrow keys move and Tab/Enter applies.
  /// Kept in range of [_suggestions]; reset to 0 whenever they recompute.
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.text;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SearchBarField old) {
    super.didUpdateWidget(old);
    // Reflect an externally-set query (e.g. a chip that injects `frame:"…"`).
    // Self-originated edits already updated the controller before onChanged
    // fired, so this only fires for genuine external changes — guarded by the
    // controller-text check so we never clobber what the user is typing.
    if (widget.text != old.text && widget.text != _controller.text) {
      _controller.text = widget.text;
      _controller.selection =
          TextSelection.collapsed(offset: widget.text.length);
    }
    // The perk/frame catalogs warm in the background and can arrive after the
    // user has already typed `perk:`/`frame:` (which showed nothing while empty).
    // When one lands, recompute so an open, focused field surfaces the values
    // without another keystroke. Deferred to a post-frame callback so we do not
    // mutate the overlay during this build.
    final catalogGrew = widget.perks.length != old.perks.length ||
        widget.frames.length != old.frames.length ||
        widget.setEffects.length != old.setEffects.length;
    if (catalogGrew && _focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) _recomputeSuggestions();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay so a tap on a suggestion is registered before the overlay hides.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) _overlayController.hide();
      });
    }
  }

  void _onChanged(String value) {
    widget.onChanged(value);
    _recomputeSuggestions();
  }

  void _recomputeSuggestions() {
    final tok =
        currentToken(_controller.text, _controller.selection.baseOffset);
    final next = suggestionsFor(tok.token, widget.names,
        instanceData: widget.instanceData,
        perks: widget.perks,
        frames: widget.frames,
        setEffects: widget.setEffects);
    setState(() {
      _suggestions = next;
      _selectedIndex = 0; // best match highlighted first
    });
    if (next.isEmpty) {
      _overlayController.hide();
    } else if (!_overlayController.isShowing) {
      _overlayController.show();
    }
  }

  /// Replace the token under the cursor with [suggestion], preserving the rest
  /// of the query. A completed term (e.g. `is:solar`) gets a trailing space so
  /// the next term can be typed; a filter *key* that still needs a value (ends
  /// with `:`, e.g. `breaker:`) does not — the space would make the tokenizer
  /// read it as a finished empty-value term and break the search.
  void _pick(Suggestion suggestion) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset < 0
        ? text.length
        : _controller.selection.baseOffset;
    final tok = currentToken(text, cursor);
    final before = text.substring(0, tok.start);
    final after = text.substring(tok.end);
    final needsValue = suggestion.insert.endsWith(':');
    final inserted = needsValue ? suggestion.insert : '${suggestion.insert} ';
    final newText = '$before$inserted$after';
    final newCursor = before.length + inserted.length;

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    widget.onChanged(newText);
    _overlayController.hide();
    _focusNode.requestFocus();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    _overlayController.hide();
  }

  /// Whether the suggestion overlay is currently open with options — the state
  /// in which the arrow / Tab / Enter keys operate on it.
  bool get _overlayActive =>
      _overlayController.isShowing && _suggestions.isNotEmpty;

  /// Move the highlight by [delta] with wraparound.
  void _moveSelection(int delta) {
    final n = _suggestions.length;
    setState(() => _selectedIndex = (_selectedIndex + delta) % n);
  }

  /// Apply the currently highlighted suggestion, if any.
  void _pickSelected() {
    if (_selectedIndex >= 0 && _selectedIndex < _suggestions.length) {
      _pick(_suggestions[_selectedIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      overlayChildBuilder: (context) {
        return CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Align(
            alignment: Alignment.topLeft,
            child: _SuggestionsOverlay(
              options: _suggestions,
              selectedIndex: _selectedIndex,
              onPick: _pick,
            ),
          ),
        );
      },
      child: CompositedTransformTarget(
        link: _link,
        child: SizedBox(
          height: widget.height,
          // The field (a descendant) bubbles key events up to this ancestor
          // Focus: arrow keys move the suggestion highlight, Tab/Enter apply it,
          // Escape clears the filter. Repeats (KeyRepeatEvent) count too so a
          // held arrow keeps moving.
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyUpEvent) return KeyEventResult.ignored;
              final key = event.logicalKey;

              if (_overlayActive) {
                if (key == LogicalKeyboardKey.arrowDown) {
                  _moveSelection(1);
                  return KeyEventResult.handled;
                }
                if (key == LogicalKeyboardKey.arrowUp) {
                  _moveSelection(-1);
                  return KeyEventResult.handled;
                }
                // Tab and Enter apply the highlighted suggestion.
                if (key == LogicalKeyboardKey.tab ||
                    key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.numpadEnter) {
                  _pickSelected();
                  return KeyEventResult.handled;
                }
              }

              if (key == LogicalKeyboardKey.escape) {
                if (_overlayController.isShowing) {
                  _overlayController.hide();
                  return KeyEventResult.handled;
                }
                if (_controller.text.isNotEmpty) {
                  _clear();
                  return KeyEventResult.handled;
                }
              }
              return KeyEventResult.ignored;
            },
            child: _Field(
              controller: _controller,
              focusNode: _focusNode,
              unsupported: widget.unsupported,
              warming: widget.warming,
              hintText: widget.hintText,
              fontSize: widget.fontSize,
              onChanged: _onChanged,
              onTap: _recomputeSuggestions,
              onClear: _clear,
            ),
          ),
        ),
      ),
    );
  }
}

/// The styled text field, extracted so the field and overlay share it.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.unsupported,
    required this.warming,
    required this.hintText,
    required this.fontSize,
    required this.onChanged,
    required this.onClear,
    this.onTap,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> unsupported;
  final bool warming;
  final String hintText;
  final double fontSize;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onTap: onTap,
          style: TextStyle(fontSize: fontSize),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            hintText: hintText,
            hintStyle: TextStyle(
                fontSize: fontSize - 1, color: context.armory.textMuted),
            prefixIcon: const Icon(Icons.search, size: 18),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (warming)
                  Tooltip(
                    message: 'Preparing search…\n'
                        'perk:, stat:, source: and perk autocomplete '
                        'are still loading.',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ),
                if (unsupported.isNotEmpty)
                  Tooltip(
                    message:
                        'Incomplete or unsupported filter (ignored):\n${unsupported.join('\n')}',
                    child: Icon(Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.tertiary),
                  ),
                IconButton(
                  icon: const Icon(Icons.help_outline, size: 18),
                  tooltip: 'Search & filter help',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showSearchHelpModal(context),
                ),
                if (hasText)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: onClear,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The dropdown list of suggestions. [selectedIndex] is the keyboard-highlighted
/// row (moved by the arrow keys, applied by Tab/Enter), tinted so it stands out.
class _SuggestionsOverlay extends StatelessWidget {
  const _SuggestionsOverlay({
    required this.options,
    required this.selectedIndex,
    required this.onPick,
  });

  final List<Suggestion> options;
  final int selectedIndex;
  final void Function(Suggestion) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: ArmoryRadius.md,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: ArmoryShadows.md,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 320),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: options.length,
            itemBuilder: (context, i) {
              final option = options[i];
              final selected = i == selectedIndex;
              return InkWell(
                onTap: () => onPick(option),
                child: Container(
                  color: selected
                      ? theme.colorScheme.primary.withValues(alpha: 0.14)
                      : Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      _LeadingGlyph(
                          iconPath: option.iconPath,
                          selected: selected,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(option.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            )),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The leading glyph for a suggestion row: the perk's Bungie icon when the
/// suggestion carries an [iconPath], otherwise the default search glyph (tinted
/// when the row is keyboard-[selected]).
class _LeadingGlyph extends StatelessWidget {
  const _LeadingGlyph({
    required this.iconPath,
    required this.selected,
    required this.color,
  });

  final String? iconPath;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final path = iconPath;
    if (path == null || path.isEmpty) {
      return Icon(Icons.search, size: 16, color: selected ? color : null);
    }
    return SizedBox(
      width: 18,
      height: 18,
      child: CachedNetworkImage(
        imageUrl: '${AppConfig.bungieBaseUrl}$path',
        cacheManager: ItemIconCache.instance,
        fit: BoxFit.cover,
        fadeInDuration: Duration.zero,
        errorWidget: (_, _, _) =>
            Icon(Icons.search, size: 16, color: selected ? color : null),
      ),
    );
  }
}
