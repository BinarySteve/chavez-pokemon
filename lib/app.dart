import 'package:flutter/material.dart';

import 'application/adventure_controller.dart';
import 'core/theme/app_theme.dart';
import 'ui/adventure_shell.dart';
import 'ui/onboarding_screen.dart';

class AdventureApp extends StatefulWidget {
  const AdventureApp({required this.controller, super.key});

  final AdventureController controller;

  @override
  State<AdventureApp> createState() => _AdventureAppState();
}

class _AdventureAppState extends State<AdventureApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokémon Adventure',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        child: child ?? const SizedBox.shrink(),
      ),
      home: _AdventureRoot(controller: widget.controller),
    );
  }
}

class _AdventureRoot extends StatelessWidget {
  const _AdventureRoot({required this.controller});

  final AdventureController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isReady) {
          return const _AppLoadingView();
        }
        if (controller.error != null) {
          return _AppErrorView(error: controller.error!);
        }
        if (controller.needsOnboarding) {
          return OnboardingScreen(controller: controller);
        }
        return AdventureShell(controller: controller);
      },
    );
  }
}

class _AppLoadingView extends StatelessWidget {
  const _AppLoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Opening your local adventure',
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _AppErrorView extends StatelessWidget {
  const _AppErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.explore_off_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'This adventure could not open.',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Local content needs attention. No trainer data was removed.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text('Technical details'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(error.toString()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
