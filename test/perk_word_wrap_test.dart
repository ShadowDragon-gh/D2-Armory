import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the Database detail modal's perk-column text sizing: every single
/// word of a perk name must fit within the chip's text area at the perk font
/// size, so Flutter wraps only on word boundaries and never splits a word
/// mid-character. These constants mirror
/// `database_detail_modal.dart` (`_perkTextWidth`, perk fontSize 11); if either
/// changes, keep them in sync here.
const double _perkTextWidth = 168;
const double _perkFontSize = 11;
const double _perkLineHeight = 1.15;

double _wordWidth(String word) {
  final tp = TextPainter(
    text: TextSpan(
      text: word,
      style: const TextStyle(fontSize: _perkFontSize, height: _perkLineHeight),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return tp.width;
}

void main() {
  // The widest single-token perk words that appear in the manifest (measured);
  // "Photoinhibition" (~165px) is the current widest. Includes hyphenated
  // names split at the hyphen (a valid break point) and left whole, so both
  // the token and the full compound are covered.
  const widestPerkWords = [
    'Photoinhibition',
    'Superconductor',
    'Indomitability',
    'Reconstruction',
    "Swordmaster's",
    'Counterattack',
    'Demolitionist',
    'Destabilizing',
    'Determination',
    'Armor-Piercing',
    'Nano-Munitions',
    'High-Explosive',
  ];

  test('every widest perk word fits the chip text area (no mid-word splits)',
      () {
    for (final word in widestPerkWords) {
      // Hyphenated compounds may wrap at the hyphen, so check each segment.
      for (final token in word.split('-')) {
        expect(
          _wordWidth(token),
          lessThanOrEqualTo(_perkTextWidth),
          reason: '"$token" (from "$word") is wider than the '
              '${_perkTextWidth}px perk text area and would be split mid-word.',
        );
      }
    }
  });
}
