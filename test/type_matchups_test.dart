import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/domain/battle/type_matchups.dart';

void main() {
  test('dual types combine into four-times weakness', () {
    expect(attackMultiplier('Water', ['Rock', 'Ground']), 4);
  });

  test('immunity wins over other multipliers', () {
    expect(attackMultiplier('Ground', ['Flying', 'Fire']), 0);
  });

  test('best attack types include known super-effective matchups', () {
    expect(bestAttackTypes(['Water']), containsAll(['Electric', 'Grass']));
  });
}
