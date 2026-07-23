const pokemonTypes = <String>[
  'Normal',
  'Fire',
  'Water',
  'Electric',
  'Grass',
  'Ice',
  'Fighting',
  'Poison',
  'Ground',
  'Flying',
  'Psychic',
  'Bug',
  'Rock',
  'Ghost',
  'Dragon',
  'Dark',
  'Steel',
  'Fairy',
];

const _strong = <String, Set<String>>{
  'Fire': {'Grass', 'Ice', 'Bug', 'Steel'},
  'Water': {'Fire', 'Ground', 'Rock'},
  'Electric': {'Water', 'Flying'},
  'Grass': {'Water', 'Ground', 'Rock'},
  'Ice': {'Grass', 'Ground', 'Flying', 'Dragon'},
  'Fighting': {'Normal', 'Ice', 'Rock', 'Dark', 'Steel'},
  'Poison': {'Grass', 'Fairy'},
  'Ground': {'Fire', 'Electric', 'Poison', 'Rock', 'Steel'},
  'Flying': {'Grass', 'Fighting', 'Bug'},
  'Psychic': {'Fighting', 'Poison'},
  'Bug': {'Grass', 'Psychic', 'Dark'},
  'Rock': {'Fire', 'Ice', 'Flying', 'Bug'},
  'Ghost': {'Psychic', 'Ghost'},
  'Dragon': {'Dragon'},
  'Dark': {'Psychic', 'Ghost'},
  'Steel': {'Ice', 'Rock', 'Fairy'},
  'Fairy': {'Fighting', 'Dragon', 'Dark'},
};

const _weak = <String, Set<String>>{
  'Normal': {'Rock', 'Steel'},
  'Fire': {'Fire', 'Water', 'Rock', 'Dragon'},
  'Water': {'Water', 'Grass', 'Dragon'},
  'Electric': {'Electric', 'Grass', 'Dragon'},
  'Grass': {'Fire', 'Grass', 'Poison', 'Flying', 'Bug', 'Dragon', 'Steel'},
  'Ice': {'Fire', 'Water', 'Ice', 'Steel'},
  'Fighting': {'Poison', 'Flying', 'Psychic', 'Bug', 'Fairy'},
  'Poison': {'Poison', 'Ground', 'Rock', 'Ghost'},
  'Ground': {'Grass', 'Bug'},
  'Flying': {'Electric', 'Rock', 'Steel'},
  'Psychic': {'Psychic', 'Steel'},
  'Bug': {'Fire', 'Fighting', 'Poison', 'Flying', 'Ghost', 'Steel', 'Fairy'},
  'Rock': {'Fighting', 'Ground', 'Steel'},
  'Ghost': {'Dark'},
  'Dragon': {'Steel'},
  'Dark': {'Fighting', 'Dark', 'Fairy'},
  'Steel': {'Fire', 'Water', 'Electric', 'Steel'},
  'Fairy': {'Fire', 'Poison', 'Steel'},
};

const _immune = <String, Set<String>>{
  'Normal': {'Ghost'},
  'Electric': {'Ground'},
  'Fighting': {'Ghost'},
  'Poison': {'Steel'},
  'Ground': {'Flying'},
  'Psychic': {'Dark'},
  'Ghost': {'Normal'},
  'Dragon': {'Fairy'},
};

double attackMultiplier(String attack, List<String> defenders) {
  var result = 1.0;
  for (final defender in defenders) {
    if (_immune[attack]?.contains(defender) ?? false) return 0;
    if (_strong[attack]?.contains(defender) ?? false) result *= 2;
    if (_weak[attack]?.contains(defender) ?? false) result *= .5;
  }
  return result;
}

Map<String, double> defensiveMatchups(List<String> types) => {
  for (final attack in pokemonTypes) attack: attackMultiplier(attack, types),
};

List<String> bestAttackTypes(List<String> defenders) {
  final entries =
      defensiveMatchups(
          defenders,
        ).entries.where((entry) => entry.value > 1).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  return entries.map((entry) => entry.key).toList();
}
