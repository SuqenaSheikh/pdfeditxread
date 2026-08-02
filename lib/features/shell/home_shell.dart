import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../library/library_screen.dart';
import '../recent/recent_screen.dart';
import '../settings/settings_screen.dart';
import '../tools/tools_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _pages = const [
    LibraryScreen(),
    RecentScreen(),
    ToolsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outline)),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 64,
            backgroundColor: colors.surface,
            indicatorColor: colors.primary.withValues(alpha: 0.12),
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(PhosphorIconsRegular.books),
                selectedIcon: Icon(PhosphorIconsFill.books),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(PhosphorIconsRegular.clockCounterClockwise),
                selectedIcon: Icon(PhosphorIconsFill.clockCounterClockwise),
                label: 'Recent',
              ),
              NavigationDestination(
                icon: Icon(PhosphorIconsRegular.wrench),
                selectedIcon: Icon(PhosphorIconsFill.wrench),
                label: 'Tools',
              ),
              NavigationDestination(
                icon: Icon(PhosphorIconsRegular.gearSix),
                selectedIcon: Icon(PhosphorIconsFill.gearSix),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
