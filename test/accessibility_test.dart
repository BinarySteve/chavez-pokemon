import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/core/theme/app_theme.dart';
import 'package:pokemon_adventure/core/theme/type_colors.dart';
import 'package:pokemon_adventure/domain/battle/type_matchups.dart';
import 'package:pokemon_adventure/domain/models/pokemon_species.dart';
import 'package:pokemon_adventure/ui/widgets/pokemon_emblem.dart';
import 'package:pokemon_adventure/ui/widgets/type_badge.dart';

void main() {
  test('primary controls and every type badge meet 4.5 contrast', () {
    final scheme = AppTheme.light.colorScheme;
    expect(
      contrastRatio(scheme.primary, scheme.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(scheme.secondary, scheme.onSecondary),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(scheme.tertiary, scheme.onTertiary),
      greaterThanOrEqualTo(4.5),
    );
    for (final type in pokemonTypes) {
      expect(
        contrastRatio(typeColor(type), typeForegroundColor(type)),
        greaterThanOrEqualTo(4.5),
        reason: '$type badge contrast',
      );
    }
  });

  testWidgets('type badges expose one complete spoken label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TypeBadge(type: 'Grass')),
      ),
    );

    final node = tester.getSemantics(find.byType(TypeBadge));
    expect(node.label, 'Grass type');
    semantics.dispose();
  });

  testWidgets('Pokémon artwork exposes one complete image label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PokemonEmblem(
            pokemon: PokemonSpecies(
              id: 25,
              dexNumber: 25,
              name: 'Pikachu',
              classification: 'Mouse Pokémon',
              description: 'Fixture',
              heightMeters: 0.4,
              weightKilograms: 6,
              generation: 1,
              types: ['Electric'],
              abilities: [],
              forms: [],
              evolutionEdges: [],
            ),
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(PokemonEmblem));
    expect(node.label, 'Artwork of Pikachu');
    semantics.dispose();
  });
}
