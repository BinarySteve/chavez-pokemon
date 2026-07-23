import 'package:flutter/material.dart';

import '../application/adventure_controller.dart';
import '../domain/models/pokemon_species.dart';
import 'collection_screen.dart';
import 'home_screen.dart';
import 'gym_guide_screen.dart';
import 'pokedex_screen.dart';
import 'pokemon_detail_screen.dart';

class AdventureShell extends StatefulWidget {
  const AdventureShell({required this.controller, super.key});

  final AdventureController controller;

  @override
  State<AdventureShell> createState() => _AdventureShellState();
}

class _AdventureShellState extends State<AdventureShell> {
  int _selectedIndex = 0;

  void _openPokemon(PokemonSpecies pokemon) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PokemonDetailScreen(
          controller: widget.controller,
          pokemon: pokemon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(controller: widget.controller, onOpenPokemon: _openPokemon),
      PokedexScreen(controller: widget.controller, onOpenPokemon: _openPokemon),
      CollectionScreen(
        controller: widget.controller,
        onOpenPokemon: _openPokemon,
      ),
      GymGuideScreen(
        controller: widget.controller,
        onOpenPokemon: _openPokemon,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 840;
        final content = IndexedStack(index: _selectedIndex, children: pages);
        if (useRail) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    extended: constraints.maxWidth >= 1120,
                    leading: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Icon(
                          _avatarIcon(widget.controller.profile!.avatar),
                        ),
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.menu_book_outlined),
                        selectedIcon: Icon(Icons.menu_book_rounded),
                        label: Text('Pokédex'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.collections_bookmark_outlined),
                        selectedIcon: Icon(Icons.collections_bookmark_rounded),
                        label: Text('Collection'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.shield_outlined),
                        selectedIcon: Icon(Icons.shield_rounded),
                        label: Text('Let’s Go Gyms'),
                      ),
                    ],
                    onDestinationSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: SafeArea(bottom: false, child: content),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book_rounded),
                label: 'Pokédex',
              ),
              NavigationDestination(
                icon: Icon(Icons.collections_bookmark_outlined),
                selectedIcon: Icon(Icons.collections_bookmark_rounded),
                label: 'Collection',
              ),
              NavigationDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield_rounded),
                label: 'Let’s Go Gyms',
              ),
            ],
          ),
        );
      },
    );
  }
}

IconData _avatarIcon(String avatar) {
  return switch (avatar) {
    'leaf' => Icons.eco_rounded,
    'star' => Icons.auto_awesome_rounded,
    _ => Icons.explore_rounded,
  };
}
