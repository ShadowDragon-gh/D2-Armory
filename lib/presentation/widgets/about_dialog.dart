import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/armory_palette.dart';

/// The About dialog: app version and the data-source attributions required by
/// Clarity's partnership terms (community insights) and DIM d2-additional-info's
/// MIT license (acquisition-source text). Centralising the credits here
/// satisfies "credit near the tooltips" for every insight surface at once.
Future<void> showAppAboutDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _AboutDialog(),
  );
}

class _AboutDialog extends StatelessWidget {
  const _AboutDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('About D2 Armory'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final v = snapshot.data;
                return Text(
                  v == null ? 'Version …' : 'Version ${v.version}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              },
            ),
            const SizedBox(height: 16),
            Text('Data sources',
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            _Attribution(
              lead: 'Community Insights courtesy of ',
              links: [
                _Link('Clarity', 'https://d2clarity.com'),
                _Link('Discord', 'https://d2clarity.com/discord'),
              ],
              trailing:
                  ' — an external community database. Report inaccuracies via '
                  'their Discord.',
            ),
            const SizedBox(height: 10),
            _Attribution(
              lead: 'Acquisition source data from Bungie\'s manifest and DIM\'s ',
              links: [
                _Link('d2-additional-info',
                    'https://github.com/DestinyItemManager/d2-additional-info'),
              ],
              trailing: ' (MIT).',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _Link {
  const _Link(this.text, this.url);
  final String text;
  final String url;
}

/// A short attribution paragraph: lead text, one or more inline links (comma
/// separated), then trailing text.
class _Attribution extends StatelessWidget {
  const _Attribution(
      {required this.lead, required this.links, required this.trailing});

  final String lead;
  final List<_Link> links;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4);
    final linkStyle = baseStyle?.copyWith(
      color: ArmoryPalette.info,
      decoration: TextDecoration.underline,
      decorationColor: ArmoryPalette.info,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: lead),
          for (var i = 0; i < links.length; i++) ...[
            if (i > 0) const TextSpan(text: ', '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => launchUrl(Uri.parse(links[i].url)),
                  child: Text(links[i].text, style: linkStyle),
                ),
              ),
            ),
          ],
          TextSpan(text: trailing),
        ],
      ),
      style: baseStyle,
    );
  }
}
