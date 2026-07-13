import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:d2_armory/presentation/theme/branding_svg.dart';

void main() {
  // The brand marks render from inline string constants (no asset-bundle read,
  // which intermittently failed at startup). These pump each mark and settle to
  // prove the embedded SVG markup parses and rasterizes without throwing.
  testWidgets('the icon SVG renders from its string constant', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SvgPicture.string(kArmoryIconSvg, width: 40, height: 40),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the wordmark SVG renders from its string constant',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SvgPicture.string(kArmoryWordmarkSvg, height: 48),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
