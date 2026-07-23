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
  testWidgets('new local trainer sees onboarding', (tester) async {
    final controller = AdventureController(
      referenceRepository: _ReferenceFake(),
      userRepository: _UserFake(),
      updateService: _UpdateFake(),
    );

    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Your adventure starts here'), findsOneWidget);
    expect(
      find.text(
        'Create a local trainer. No account, email, or internet needed.',
      ),
      findsOneWidget,
    );
    expect(find.text('Begin adventure'), findsOneWidget);
  });

  testWidgets('returning trainer sees phone navigation and partner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AdventureController(
      referenceRepository: _ReferenceFake(),
      userRepository: _UserFake(
        profile: const TrainerProfile(
          name: 'Nova',
          avatar: 'star',
          partnerSpeciesId: 25,
        ),
      ),
      updateService: _UpdateFake(),
    );

    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Nova'), findsOneWidget);
    expect(find.text('Your partner'), findsOneWidget);
    expect(find.text('Pikachu'), findsWidgets);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Let’s Go Gyms'), findsOneWidget);
  });

  testWidgets('returning trainer gets navigation rail on tablet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = AdventureController(
      referenceRepository: _ReferenceFake(),
      userRepository: _UserFake(
        profile: const TrainerProfile(
          name: 'Nova',
          avatar: 'explorer',
          partnerSpeciesId: 25,
        ),
      ),
      updateService: _UpdateFake(),
    );

    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Let’s Go Gyms'), findsOneWidget);
  });

  testWidgets('Pokédex switches between every species and Let’s Go', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AdventureController(
      referenceRepository: _ReferenceFake(),
      userRepository: _UserFake(
        profile: const TrainerProfile(
          name: 'Nova',
          avatar: 'star',
          partnerSpeciesId: 25,
        ),
      ),
      updateService: _UpdateFake(),
    );

    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokédex').last);
    await tester.pumpAndSettle();

    expect(find.text('All Pokémon'), findsOneWidget);
    expect(find.text('4 Pokémon shown'), findsOneWidget);
    await tester.tap(find.text('Let’s Go'));
    await tester.pumpAndSettle();
    expect(find.text('3 Pokémon shown'), findsOneWidget);
  });

  testWidgets('tapping outside search dismisses keyboard focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AdventureController(
      referenceRepository: _ReferenceFake(),
      userRepository: _UserFake(
        profile: const TrainerProfile(
          name: 'Nova',
          avatar: 'star',
          partnerSpeciesId: 25,
        ),
      ),
      updateService: _UpdateFake(),
    );

    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokédex').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SearchBar));
    await tester.pump();
    var editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Pokédex').first);
    await tester.pump();
    editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isFalse);
  });

  testWidgets('Gym helper recommendations render without exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AdventureController(
      referenceRepository: _ReferenceFake(),
      userRepository: _UserFake(
        profile: const TrainerProfile(
          name: 'Nova',
          avatar: 'star',
          partnerSpeciesId: 25,
        ),
      ),
      updateService: _UpdateFake(),
    );

    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let’s Go Gyms'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Brock'));
    await tester.pumpAndSettle();

    expect(find.text('Sprigatito'), findsNothing);
    expect(find.text('Against Onix: Ground 2×'), findsOneWidget);
    expect(find.text('Let’s Go helpers with matching moves'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collection save failure keeps saved state and offers retry', (
    tester,
  ) async {
    final user = _UserFake(saveError: StateError('disk full'));
    final controller = AdventureController(
      referenceRepository: _ReferenceFake(),
      userRepository: user,
      updateService: _UpdateFake(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: PokemonDetailScreen(
          controller: controller,
          pokemon: _ReferenceFake.pikachu,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('We couldn’t save that change. Your collection is still safe.'),
      findsOneWidget,
    );
    expect(controller.collectionFor(25).isSeen, isFalse);
    user.saveError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(controller.collectionFor(25).isSeen, isTrue);
  });

  testWidgets('battle helper explains matchups in kid-friendly groups', (
    tester,
  ) async {
    final controller = AdventureController(
      referenceRepository: _ReferenceFake(),
      userRepository: _UserFake(),
      updateService: _UpdateFake(),
    );
    addTearDown(controller.dispose);
    const onix = PokemonSpecies(
      id: 95,
      dexNumber: 95,
      name: 'Onix',
      classification: 'Rock Snake Pokémon',
      description: 'A friendly local fixture.',
      heightMeters: 8.8,
      weightKilograms: 210,
      generation: 1,
      types: ['Rock', 'Ground'],
      abilities: [],
      forms: [],
      evolutionEdges: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PokemonDetailScreen(controller: controller, pokemon: onix),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How do I battle Onix?'), findsOneWidget);
    expect(find.text('Best choices'), findsOneWidget);
    expect(find.text('Amazing! 4×'), findsWidgets);
    expect(find.text('Not very helpful'), findsOneWidget);
    expect(find.text('Won’t work'), findsOneWidget);
    expect(
      find.textContaining('Check the move’s type—not only your Pokémon’s type'),
      findsOneWidget,
    );
  });

  testWidgets('phone home remains usable at 200 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final controller = AdventureController(
      referenceRepository: _ReferenceFake(),
      userRepository: _UserFake(
        profile: const TrainerProfile(
          name: 'Nova',
          avatar: 'star',
          partnerSpeciesId: 25,
        ),
      ),
      updateService: _UpdateFake(),
    );

    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Nova'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
    forms: [],
    evolutionEdges: [],
  );

  @override
  Future<void> close() async {}

  @override
  Future<Map<String, String>> loadMetadata() async => {
    'dataset_version': '1',
    'display_name': 'Widget Fixture',
  };

  @override
  Future<List<PokemonSpecies>> loadSpecies() async => const [
    pikachu,
    PokemonSpecies(
      id: 906,
      dexNumber: 906,
      name: 'Sprigatito',
      classification: 'Grass Cat Pokémon',
      description: 'A friendly local fixture.',
      heightMeters: 0.4,
      weightKilograms: 4.1,
      generation: 9,
      types: ['Grass'],
      abilities: ['Overgrow'],
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
    PokemonSpecies(
      id: 74,
      dexNumber: 74,
      name: 'Geodude',
      classification: 'Rock Pokémon',
      description: 'A friendly local fixture.',
      heightMeters: 0.4,
      weightKilograms: 20,
      generation: 1,
      types: ['Rock', 'Ground'],
      abilities: [],
      forms: [],
      evolutionEdges: [],
      moves: [
        PokemonMove(
          name: 'Dig',
          type: 'Ground',
          learnMethod: 'machine',
          levelLearned: 0,
        ),
      ],
    ),
    PokemonSpecies(
      id: 95,
      dexNumber: 95,
      name: 'Onix',
      classification: 'Rock Snake Pokémon',
      description: 'A friendly local fixture.',
      heightMeters: 8.8,
      weightKilograms: 210,
      generation: 1,
      types: ['Rock', 'Ground'],
      abilities: [],
      forms: [],
      evolutionEdges: [],
    ),
  ];
}

class _UserFake implements UserRepository {
  _UserFake({this.profile, this.saveError});

  TrainerProfile? profile;
  Object? saveError;
  final Map<int, CollectionState> collection = {};

  @override
  Future<void> close() async {}

  @override
  Future<Map<int, CollectionState>> loadCollection() async => collection;

  @override
  Future<TrainerProfile?> loadProfile() async => profile;

  @override
  Future<void> saveCollectionState(CollectionState state) async {
    if (saveError case final error?) {
      throw error;
    }
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
      message: 'Demo content is current.',
    );
  }
}
