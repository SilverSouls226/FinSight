import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../goals/goals_screen.dart';
import '../home/home_screen.dart';
import '../interventions/intervention_feed_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../simulation/simulation_screen.dart';
import '../twin/digital_twin_screen.dart';

/// Top-level shell: shows Onboarding until a local [UserProfile] exists,
/// then the main bottom-navigation app.
class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    if (profile == null) {
      return const OnboardingScreen();
    }
    return const _MainNavigation();
  }
}

class _MainNavigation extends ConsumerWidget {
  const _MainNavigation();

  static const _screens = [
    HomeScreen(),
    DigitalTwinScreen(),
    InterventionFeedScreen(),
    SimulationScreen(),
    GoalsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(rootTabIndexProvider);

    return Scaffold(
      body: IndexedStack(index: index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(rootTabIndexProvider.notifier).state = i,
        backgroundColor: AppColors.surface,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wb_cloudy_outlined), selectedIcon: Icon(Icons.wb_cloudy), label: 'Weather'),
          NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: 'Twin'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'Simulate'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Goals'),
        ],
      ),
    );
  }
}
