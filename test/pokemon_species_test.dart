import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/domain/models/pokemon_species.dart';

void main() {
  const pokemon = PokemonSpecies(
    id: 25,
    dexNumber: 25,
    name: 'Pikachu',
    classification: 'Mouse Pokémon',
    description: 'Demo',
    heightMeters: 0.4,
    weightKilograms: 6,
    generation: 1,
    types: ['Electric'],
    abilities: ['Static'],
    forms: [
      PokemonForm(
        id: 'pikachu-demo',
        name: 'Pikachu Demo Form',
        category: 'Demo',
        types: ['Electric'],
        note: 'Demo',
        isBattleOnly: false,
      ),
    ],
    evolutionEdges: [],
  );

  test('search handles number, punctuation, spacing, and minor typo', () {
    expect(pokemon.matches('25'), isTrue);
    expect(pokemon.matches('#0025'), isTrue);
    expect(pokemon.matches('Pika chu'), isTrue);
    expect(pokemon.matches('Pikchu'), isTrue);
  });

  test('search includes form names', () {
    expect(pokemon.matches('demo form'), isTrue);
  });

  test('unrelated search does not match', () {
    expect(pokemon.matches('Bulbasaur'), isFalse);
  });
}
