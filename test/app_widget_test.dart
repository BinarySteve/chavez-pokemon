import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_adventure/app.dart';
import 'package:pokemon_adventure/application/adventure_controller.dart';
import 'package:pokemon_adventure/domain/models/collection_state.dart';
import 'package:pokemon_adventure/domain/models/encounter_guide.dart';
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

  testWidgets('trainer can change partner from Home', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final userRepository = _UserFake(
      profile: const TrainerProfile(
        name: 'Nova',
        avatar: 'star',
        partnerSpeciesId: 25,
      ),
    );
    final controller = AdventureController(
      referenceRepository: _ReferenceFake(),
      userRepository: userRepository,
      updateService: _UpdateFake(),
    );

    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change partner'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a new partner'), findsOneWidget);
    expect(find.text('Current partner'), findsOneWidget);
    await tester.tap(find.text('Sprigatito'));
    await tester.pumpAndSettle();

    expect(controller.partner?.id, 906);
    expect(userRepository.profile?.partnerSpeciesId, 906);
    expect(find.text('Sprigatito'), findsWidgets);
  });

  testWidgets('new app release gets a kid-friendly grown-up update prompt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final updateService = _AppUpdateFake();
    final controller = AdventureController(
      referenceRepository: _ReferenceFake(),
      userRepository: _UserFake(
        profile: const TrainerProfile(
          name: 'Nova',
          avatar: 'star',
          partnerSpeciesId: 25,
        ),
      ),
      updateService: updateService,
    );

    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('More Pokémon fun'), findsOneWidget);
    expect(
      find.text('A new version is ready to join the team!'),
      findsOneWidget,
    );
    expect(find.text('Update with a grown-up'), findsOneWidget);
    await tester.tap(find.text('Update with a grown-up'));
    await tester.pumpAndSettle();

    expect(
      controller.appUpdateActionState,
      AppUpdateActionState.openingInstaller,
    );
    expect(updateService.installRequests, 1);
    expect(find.text('A new adventure is ready!'), findsOneWidget);
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
      referenceRepository: _GymReferenceFake(),
      userRepository: _UserFake(
        profile: const TrainerProfile(
          name: 'Nova',
          avatar: 'star',
          partnerSpeciesId: 25,
        ),
        collection: const {
          74: CollectionState(speciesId: 74, isCaught: true),
          906: CollectionState(speciesId: 906, isCaught: true),
        },
      ),
      updateService: _UpdateFake(),
      encounterGuideRepository: const _EncounterGuideFake(_brockGuide),
    );

    await tester.pumpWidget(AdventureApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let’s Go Gyms'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Brock'));
    await tester.pumpAndSettle();

    expect(find.text('Sprigatito'), findsNothing);
    expect(find.text('Against Onix: Ground 2×'), findsOneWidget);
    expect(find.text('Your caught helpers'), findsWidgets);
    expect(find.text('You can catch these before Brock'), findsWidgets);
    expect(find.text('Oddish'), findsWidgets);
    expect(
      find.text('Route 1 · Wild · Lv. 3–6 · Pikachu version'),
      findsWidgets,
    );
    expect(find.text('Bellsprout'), findsWidgets);
    expect(find.text('Route 1 · Wild · Lv. 3–6 · Eevee version'), findsWidgets);
    expect(find.text('Bulbasaur'), findsWidgets);
    expect(
      find.text('Viridian Forest · Rare spawn · Lv. 3–6 · Both games'),
      findsWidgets,
    );
    expect(find.text('Lickitung'), findsNothing);
    expect(find.text('Kangaskhan'), findsNothing);
    expect(find.text('Mew'), findsNothing);
    expect(tester.takeException(), isNull);

    await controller.updateCollection(const CollectionState(speciesId: 74));
    await tester.pumpAndSettle();
    expect(find.text('Against Onix: Ground 2×'), findsNothing);
    expect(find.text('No matching caught helper yet.'), findsWidgets);
  });

  testWidgets('opening details does not automatically mark Pokemon as seen', (
    tester,
  ) async {
    final user = _UserFake();
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
    await tester.pumpAndSettle();

    expect(controller.collectionFor(25).isSeen, isFalse);
    expect(user.collection.containsKey(25), isFalse);
    expect(find.text('Seen'), findsOneWidget);
  });

  testWidgets('manual collection save failure keeps state and offers retry', (
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seen'));
    await tester.pumpAndSettle();

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

class _GymReferenceFake implements ReferenceRepository {
  @override
  Future<void> close() async {}

  @override
  Future<Map<String, String>> loadMetadata() async => {
    'dataset_version': '4',
    'display_name': 'Gym Fixture',
  };

  @override
  Future<List<PokemonSpecies>> loadSpecies() async => [
    ...await _ReferenceFake().loadSpecies(),
    _gymPokemon(1, 'Bulbasaur', 'Grass'),
    _gymPokemon(43, 'Oddish', 'Grass'),
    _gymPokemon(69, 'Bellsprout', 'Grass'),
    _gymPokemon(108, 'Lickitung', 'Water'),
    _gymPokemon(115, 'Kangaskhan', 'Water'),
    _gymPokemon(151, 'Mew', 'Water'),
  ];
}

PokemonSpecies _gymPokemon(int id, String name, String moveType) {
  return PokemonSpecies(
    id: id,
    dexNumber: id,
    name: name,
    classification: 'Fixture Pokémon',
    description: 'Fixture',
    heightMeters: 1,
    weightKilograms: 1,
    generation: 1,
    types: const ['Normal'],
    abilities: const [],
    forms: const [],
    evolutionEdges: const [],
    moves: [
      PokemonMove(
        name: '$moveType move',
        type: moveType,
        learnMethod: 'level-up',
        levelLearned: 1,
      ),
    ],
  );
}

const _brockGuide = EncounterGuide(
  guideSchemaVersion: 1,
  guideVersion: 1,
  logicalSha256:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  areas: {
    1: LetsGoEncounterArea(id: 1, displayName: 'Route 1', requiredBadges: 0),
    2: LetsGoEncounterArea(
      id: 2,
      displayName: 'Viridian Forest',
      requiredBadges: 0,
    ),
    3: LetsGoEncounterArea(id: 3, displayName: 'Route 3', requiredBadges: 1),
  },
  encounters: [
    LetsGoEncounter(
      speciesId: 43,
      areaId: 1,
      versions: [LetsGoVersion.pikachu],
      method: 'overworld',
      minLevel: 3,
      maxLevel: 6,
      slotRarity: 20,
      conditions: [],
    ),
    LetsGoEncounter(
      speciesId: 69,
      areaId: 1,
      versions: [LetsGoVersion.eevee],
      method: 'overworld',
      minLevel: 3,
      maxLevel: 6,
      slotRarity: 20,
      conditions: [],
    ),
    LetsGoEncounter(
      speciesId: 1,
      areaId: 2,
      versions: [LetsGoVersion.pikachu, LetsGoVersion.eevee],
      method: 'overworld-special',
      minLevel: 3,
      maxLevel: 6,
      slotRarity: 1,
      conditions: [],
    ),
    LetsGoEncounter(
      speciesId: 108,
      areaId: 3,
      versions: [LetsGoVersion.pikachu, LetsGoVersion.eevee],
      method: 'overworld',
      minLevel: 10,
      maxLevel: 12,
      slotRarity: 10,
      conditions: [],
    ),
  ],
);

class _EncounterGuideFake implements EncounterGuideRepository {
  const _EncounterGuideFake(this.guide);

  final EncounterGuide guide;

  @override
  Future<EncounterGuide> load() async => guide;
}

class _UserFake implements UserRepository {
  _UserFake({
    this.profile,
    this.saveError,
    Map<int, CollectionState> collection = const {},
  }) : collection = Map.of(collection);

  TrainerProfile? profile;
  Object? saveError;
  final Map<int, CollectionState> collection;

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

class _AppUpdateFake implements AppUpdateService {
  static final release = AppUpdateRelease(
    versionCode: 2,
    versionName: '1.1.0',
    apkUri: Uri.parse('https://home.example/pokemon-adventure.apk'),
    sha256: '0' * 64,
    sizeBytes: 1024,
    title: 'More Pokémon fun',
    notes: const ['New discoveries', 'A friendlier update screen'],
  );

  int installRequests = 0;

  @override
  Future<UpdateCheckResult> check({required int currentDatasetVersion}) async {
    return UpdateCheckResult(
      state: UpdateCheckState.updateAvailable,
      message: 'A new adventure is ready!',
      release: release,
    );
  }

  @override
  Future<String> download(
    AppUpdateRelease release, {
    required void Function(double progress) onProgress,
  }) async {
    onProgress(0.5);
    onProgress(1);
    return 'verified-update.apk';
  }

  @override
  Future<UpdateInstallRequest> requestInstall(String apkPath) async {
    installRequests += 1;
    return UpdateInstallRequest.launched;
  }
}
