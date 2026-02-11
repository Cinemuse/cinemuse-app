import 'dart:ui';
import 'package:flutter/material.dart';

class AppNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a1a).withOpacity(0.8), // Surface color
            border: const Border(bottom: BorderSide(color: Colors.white10)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              const Text(
                "CINEMUSE", // Placeholder for wordmark logo
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 1.5,
                ),
              ),

              // Nav Items (Centered)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavItem(
                    label: "Home",
                    isSelected: currentIndex == 0,
                    onTap: () => onTap(0),
                  ),
                  const SizedBox(width: 20),
                  _NavItem(
                    label: "Explore",
                    isSelected: currentIndex == 1,
                    onTap: () => onTap(1),
                  ),
                  const SizedBox(width: 20),
                  _NavItem(
                    label: "Live TV",
                    isSelected: currentIndex == 2,
                    onTap: () => onTap(2),
                  ),
                  const SizedBox(width: 20),
                  _NavItem(
                    label: "Profile",
                    isSelected: currentIndex == 3,
                    onTap: () => onTap(3),
                  ),
                ],
              ),

              // Actions (Right)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white70),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 10),
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, size: 16, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
