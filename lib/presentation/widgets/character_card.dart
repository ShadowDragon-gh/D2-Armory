import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/models/destiny_character.dart';

/// A single character rendered on its emblem banner, with class and light.
class CharacterCard extends StatelessWidget {
  const CharacterCard({super.key, required this.character});

  final DestinyCharacter character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final banner = character.emblemBackgroundUrl;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 96,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (banner != null)
              CachedNetworkImage(
                imageUrl: banner,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            // Scrim so text stays legible over any emblem art.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    character.className,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.bolt, color: Colors.amber, size: 20),
                      Text(
                        '${character.light}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
