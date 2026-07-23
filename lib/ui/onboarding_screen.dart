import 'package:flutter/material.dart';

import '../application/adventure_controller.dart';
import '../domain/models/pokemon_species.dart';
import 'widgets/pokemon_emblem.dart';
import 'widgets/type_badge.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({required this.controller, super.key});

  final AdventureController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _avatar = 'explorer';
  int? _partnerId;
  bool _saving = false;

  static const _partnerIds = [1, 4, 25, 133];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partners = widget.controller.species
        .where((pokemon) => _partnerIds.contains(pokemon.id))
        .toList(growable: false);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.explore_rounded,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Your adventure starts here',
                      style: Theme.of(context).textTheme.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create a local trainer. No account, email, or internet needed.',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.done,
                      maxLength: 24,
                      decoration: const InputDecoration(
                        labelText: 'Trainer name',
                        hintText: 'What should your partner call you?',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Choose a trainer name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Choose an explorer badge',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          avatar: const Icon(Icons.explore_outlined),
                          label: const Text('Explorer'),
                          selected: _avatar == 'explorer',
                          onSelected: (_) =>
                              setState(() => _avatar = 'explorer'),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.eco_outlined),
                          label: const Text('Nature'),
                          selected: _avatar == 'leaf',
                          onSelected: (_) => setState(() => _avatar = 'leaf'),
                        ),
                        ChoiceChip(
                          avatar: const Icon(Icons.auto_awesome_outlined),
                          label: const Text('Star'),
                          selected: _avatar == 'star',
                          onSelected: (_) => setState(() => _avatar = 'star'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Choose your first partner',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can explore every Pokémon later.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    _PartnerGrid(
                      partners: partners,
                      selectedId: _partnerId,
                      onSelected: (id) => setState(() => _partnerId = id),
                    ),
                    if (_partnerId == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Pick a partner to continue.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _saving ? null : _complete,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.flag_rounded),
                      label: const Text('Begin adventure'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Everything stays on this device. Artwork is included only for private family use.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _complete() async {
    if (!_formKey.currentState!.validate() || _partnerId == null) {
      setState(() {});
      return;
    }
    setState(() => _saving = true);
    await widget.controller.completeOnboarding(
      trainerName: _nameController.text,
      avatar: _avatar,
      partnerSpeciesId: _partnerId!,
    );
    if (mounted) {
      setState(() => _saving = false);
    }
  }
}

class _PartnerGrid extends StatelessWidget {
  const _PartnerGrid({
    required this.partners,
    required this.selectedId,
    required this.onSelected,
  });

  final List<PokemonSpecies> partners;
  final int? selectedId;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        final cardWidth =
            (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final pokemon in partners)
              SizedBox(
                width: cardWidth,
                child: Semantics(
                  button: true,
                  selected: pokemon.id == selectedId,
                  label: 'Choose ${pokemon.name} as partner',
                  child: InkWell(
                    onTap: () => onSelected(pokemon.id),
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: pokemon.id == selectedId
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: pokemon.id == selectedId
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: pokemon.id == selectedId ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PokemonEmblem(pokemon: pokemon, size: 64),
                          const SizedBox(height: 10),
                          Text(
                            pokemon.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final type in pokemon.types)
                                TypeBadge(type: type, compact: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
