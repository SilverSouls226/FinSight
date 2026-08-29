import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/add_entry/add_entry_sheet.dart';
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

class _MainNavigation extends ConsumerStatefulWidget {
  const _MainNavigation();

  @override
  ConsumerState<_MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<_MainNavigation> with WidgetsBindingObserver {
  static const _screens = [
    HomeScreen(),
    DigitalTwinScreen(),
    SimulationScreen(),
    InterventionFeedScreen(),
    GoalsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Real bank SMS detected while backgrounded is handled by a separate
    // isolate with no access to this app's Riverpod state (see
    // background_sms_handler.dart) -- it updates the real backend balance
    // directly but can't refresh this UI. Refetch whenever the user
    // returns to the app so a balance change from a backgrounded SMS
    // (the common case: sending money means being in the UPI app, not
    // here) shows up without needing a manual restart.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(financialSnapshotProvider);
      ref.invalidate(interventionsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(rootTabIndexProvider);

    return Scaffold(
      body: IndexedStack(index: index, children: _screens),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          gradient: AppColors.accentGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton(
          key: const Key('rootAddFab'),
          onPressed: () => showAddEntrySheet(context),
          tooltip: 'Add',
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
          child: const Icon(Icons.add_rounded),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(rootTabIndexProvider.notifier).state = i,
        backgroundColor: AppColors.surface,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate_rounded), label: 'Simulate'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications_rounded), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
