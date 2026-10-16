import 'package:flutter/material.dart';

/// The soft dark fade at the bottom of a card's picture, so the badges and
/// the progress bar stay readable on light images.
class CardBottomVignette extends StatelessWidget {
  const CardBottomVignette({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [Color(0x73000000), Colors.transparent],
          stops: [0.0, 0.4],
        ),
      ),
    );
  }
}
