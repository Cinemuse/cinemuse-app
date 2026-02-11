import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/home/presentation/home_screen.dart';
import 'package:cinemuse_app/features/search/presentation/search_screen.dart';
import 'package:cinemuse_app/core/presentation/widgets/navbar.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(), // Explore/Search tab
    const Center(child: Text("Live TV (Todo)")),
    const Center(child: Text("Profile (Todo)")),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Match "bg-primary"
      body: Stack(
        children: [
          // Main Content
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
          
          // Top Navbar (Floating)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppNavbar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
