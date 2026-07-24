import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/app.dart';
import 'package:pokemon_adventure/application/adventure_controller.dart';
import 'package:pokemon_adventure/domain/models/collection_state.dart';
import 'package:pokemon_adventure/domain/models/pokemon_species.dart';
import 'package:pokemon_adventure/domain/models/trainer_profile.dart';
import 'package:pokemon_adventure/domain/repositories.dart';
import 'package:pokemon_adventure/ui/pokemon_detail_screen.dart';

void main() {
  for (final size in [const Size(430, 932), const Size(1024, 768)]) {
    testWidgets('onboarding fits at 200% on ${size.width.toInt()}px', (
      tester,
    ) async {
      _configureView(tester, size);
      final controller = _controller();

      await tester.pumpWidget(AdventureApp(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Your adventure starts here'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('main destinations fit at 200% on ${size.width.toInt()}px', (
      tester,
    ) async {
      _configureView(tester, size);
      final controller = _controller(
        profile: const TrainerProfile(
          name: 'Nova',
          avatar: 'star',
          partnerSpeciesId: 25,
        ),
        collection: const {
          25: CollectionState(speciesId: 25, isSeen: true, isFavorite: true),
        },
      );

      await tester.pumpWidget(AdventureApp(controller: controller));
      await tester.pumpAndSettle();

      _selectDestination(tester, 1);
      await tester.pumpAndSettle();
      expect(find.textContaining('Pokémon shown'), findsOneWidget);
      expect(tester.takeException(), isNull);

      _selectDestination(tester, 2);
      await tester.pumpAndSettle();
      expect(find.text('My collection'), findsOneWidget);
      expect(tester.takeException(), isNull);

      _selectDestination(tester, 3);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Brock'),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('gym-guide-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.textContaining('Brock'));
      await tester.pumpAndSettle();
      expect(find.text('Against Onix · Level 12'), findsOneWidget);
      expect(find.text('No matching caught helper yet.'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'detail and form sheet fit at 200% on ${size.width.toInt()}px',
      (tester) async {
        _configureView(tester, size);
        final controller = _controller();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: PokemonDetailScreen(
              controller: controller,
              pokemon: _ReferenceFake.pikachu,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('Captain Pikachu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Captain Pikachu'));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Costume Form'), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('Quick facts'), findsOneWidget);
      },
    );
  }

  testWidgets('Android back returns from detail route', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PokemonDetailScreen(
                    controller: controller,
                    pokemon: _ReferenceFake.pikachu,
                  ),
                ),
              ),
              child: const Text('Open Pikachu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Pikachu'));
    await tester.pumpAndSettle();
    expect(find.text('How do I battle Pikachu?'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open Pikachu'), findsOneWidget);
  });

  testWidgets('phone detail keeps evolution directions and moves readable', (
    tester,
  ) async {
    _configureView(tester, const Size(430, 932));
    final controller = _controller();
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: PokemonDetailScreen(
          controller: controller,
          pokemon: controller.speciesById(133)!,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Evolution paths'), 350);
    await tester.pumpAndSettle();
    expect(find.text('Tap a Pokémon to open its details.'), findsOneWidget);
    expect(find.text('Ways to evolve'), findsOneWidget);
    expect(find.text('Level up at a special mossy place'), findsOneWidget);
    expect(find.text('Use Leaf Stone'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Moves'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moves'));
    await tester.pumpAndSettle();
    expect(find.text('Normal'), findsWidgets);
    expect(find.text('Lv. 10'), findsOneWidget);
    expect(find.text('TM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _selectDestination(WidgetTester tester, int index) {
  final navigationBar = find.byType(NavigationBar);
  if (navigationBar.evaluate().isNotEmpty) {
    tester
        .widget<NavigationBar>(navigationBar)
        .onDestinationSelected
        ?.call(index);
    return;
  }
  tester
      .widget<NavigationRail>(find.byType(NavigationRail))
      .onDestinationSelected
      ?.call(index);
}

void _configureView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

AdventureController _controller({
  TrainerProfile? profile,
  Map<int, CollectionState> collection = const {},
}) {
  return AdventureController(
    referenceRepository: _ReferenceFake(),
    userRepository: _UserFake(profile: profile, collection: collection),
    updateService: _UpdateFake(),
  );
}

class _ReferenceFake implements ReferenceRepository {
  static const pikachu = PokemonSpecies(
    id: 25,
    dexNumber: 25,
    name: 'Pikachu',
    classification: 'Mouse Pokémon',
    description: 'A friendly local fixture.',
    heightMeters: 0.4,
    weightKilograms: 6,
    generation: 1,
    types: ['Electric'],
    abilities: ['Static'],
    forms: [
      PokemonForm(
        id: 'pikachu-captain',
        name: 'Captain Pikachu',
        category: 'Costume Form',
        types: ['Electric'],
        note: 'A cheerful costume used for layout testing.',
        isBattleOnly: false,
        artworkAsset: 'assets/artwork/25.png',
      ),
    ],
    evolutionEdges: [],
  );

  @override
  Future<void> close() async {}

  @override
  Future<Map<String, String>> loadMetadata() async => {
    'dataset_version': '4',
    'display_name': 'Layout fixture',
  };

  @override
  Future<List<PokemonSpecies>> loadSpecies() async => const [
    PokemonSpecies(
      id: 1,
      dexNumber: 1,
      name: 'Bulbasaur',
      classification: 'Seed Pokémon',
      description: 'Fixture',
      heightMeters: 0.7,
      weightKilograms: 6.9,
      generation: 1,
      types: ['Grass', 'Poison'],
      abilities: [],
      forms: [],
      evolutionEdges: [],
      moves: [
        PokemonMove(
          name: 'Vine Whip',
          type: 'Grass',
          learnMethod: 'level-up',
          levelLearned: 3,
        ),
      ],
    ),
    PokemonSpecies(
      id: 4,
      dexNumber: 4,
      name: 'Charmander',
      classification: 'Lizard Pokémon',
      description: 'Fixture',
      heightMeters: 0.6,
      weightKilograms: 8.5,
      generation: 1,
      types: ['Fire'],
      abilities: [],
      forms: [],
      evolutionEdges: [],
    ),
    pikachu,
    PokemonSpecies(
      id: 74,
      dexNumber: 74,
      name: 'Geodude',
      classification: 'Rock Pokémon',
      description: 'Fixture',
      heightMeters: 0.4,
      weightKilograms: 20,
      generation: 1,
      types: ['Rock', 'Ground'],
      abilities: [],
      forms: [],
      evolutionEdges: [],
    ),
    PokemonSpecies(
      id: 95,
      dexNumber: 95,
      name: 'Onix',
      classification: 'Rock Snake Pokémon',
      description: 'Fixture',
      heightMeters: 8.8,
      weightKilograms: 210,
      generation: 1,
      types: ['Rock', 'Ground'],
      abilities: [],
      forms: [],
      evolutionEdges: [],
    ),
    PokemonSpecies(
      id: 133,
      dexNumber: 133,
      name: 'Eevee',
      classification: 'Evolution Pokémon',
      description: 'Fixture',
      heightMeters: 0.3,
      weightKilograms: 6.5,
      generation: 1,
      types: ['Normal'],
      abilities: [],
      forms: [],
      evolutionEdges: [
        EvolutionEdge(
          fromSpeciesId: 133,
          toSpeciesId: 134,
          condition: 'Level up at at a special mossy place or Use Leaf Stone',
          sortOrder: 1,
        ),
      ],
      moves: [
        PokemonMove(
          name: 'Double Kick',
          type: 'Normal',
          learnMethod: 'level-up',
          levelLearned: 10,
        ),
        PokemonMove(
          name: 'Protect',
          type: 'Normal',
          learnMethod: 'machine',
          levelLearned: 0,
        ),
      ],
    ),
    PokemonSpecies(
      id: 134,
      dexNumber: 134,
      name: 'Vaporeon',
      classification: 'Bubble Jet Pokémon',
      description: 'Fixture',
      heightMeters: 1,
      weightKilograms: 29,
      generation: 1,
      types: ['Water'],
      abilities: [],
      forms: [],
      evolutionEdges: [
        EvolutionEdge(
          fromSpeciesId: 133,
          toSpeciesId: 134,
          condition: 'Level up at at a special mossy place or Use Leaf Stone',
          sortOrder: 1,
        ),
      ],
    ),
    PokemonSpecies(
      id: 906,
      dexNumber: 906,
      name: 'Sprigatito',
      classification: 'Grass Cat Pokémon',
      description: 'Fixture',
      heightMeters: 0.4,
      weightKilograms: 4.1,
      generation: 9,
      types: ['Grass'],
      abilities: [],
      forms: [],
      evolutionEdges: [],
      moves: [
        PokemonMove(
          name: 'Leafage',
          type: 'Grass',
          learnMethod: 'level-up',
          levelLearned: 1,
        ),
      ],
    ),
  ];
}

class _UserFake implements UserRepository {
  _UserFake({this.profile, required Map<int, CollectionState> collection})
    : collection = Map.of(collection);

  TrainerProfile? profile;
  final Map<int, CollectionState> collection;

  @override
  Future<void> close() async {}

  @override
  Future<Map<int, CollectionState>> loadCollection() async => collection;

  @override
  Future<TrainerProfile?> loadProfile() async => profile;

  @override
  Future<void> saveCollectionState(CollectionState state) async {
    collection[state.speciesId] = state;
  }

  @override
  Future<void> saveProfile(TrainerProfile profile) async {
    this.profile = profile;
  }
}

class _UpdateFake implements UpdateService {
  @override
  Future<UpdateCheckResult> check({required int currentDatasetVersion}) async {
    return const UpdateCheckResult(
      state: UpdateCheckState.current,
      message: 'Current',
    );
  }
}
