import 'package:flutter/material.dart';

import '../../core/theme/type_colors.dart';
import '../../domain/models/pokemon_species.dart';

class PokemonEmblem extends StatelessWidget {
  const PokemonEmblem({
    required this.pokemon,
    this.size = 96,
    this.heroTag,
    super.key,
  });

  final PokemonSpecies pokemon;
  final double size;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final fallback = Text(
      pokemon.name.characters.first,
      style: TextStyle(
        fontSize: size * 0.46,
        height: 1,
        fontWeight: FontWeight.w900,
        color: typeColor(pokemon.types.first),
      ),
    );
    final emblem = Semantics(
      image: true,
      label: 'Artwork of ${pokemon.name}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: typeColor(pokemon.types.first).withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border: Border.all(
            color: typeColor(pokemon.types.first).withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.all(size * .08),
          child: Image.asset(
            'assets/artwork/${pokemon.dexNumber}.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => fallback,
          ),
        ),
      ),
    );
    if (heroTag == null) {
      return emblem;
    }
    return Hero(tag: heroTag!, child: emblem);
  }
}
