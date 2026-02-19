import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';

class NextEpisodeOverlay extends StatefulWidget {
  final CinemaPlayerState playerState;
  final VoidCallback onNextEpisode;

  const NextEpisodeOverlay({
    super.key,
    required this.playerState,
    required this.onNextEpisode,
  });

  @override
  State<NextEpisodeOverlay> createState() => _NextEpisodeOverlayState();
}

class _NextEpisodeOverlayState extends State<NextEpisodeOverlay> {
  bool _isNextButtonHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.playerState.nextEpisode == null) return const SizedBox.shrink();

    final player = widget.playerState.controller.player;

    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (context, snapshot) {
        final pos = snapshot.data?.inSeconds ?? player.state.position.inSeconds;
        final dur = player.state.duration.inSeconds;
        if (dur <= 0) return const SizedBox.shrink();
        final isFinished = (dur - pos < 180) || (pos / dur > 0.95);

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuart,
          bottom: isFinished ? 100 : -100,
          right: 32,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isNextButtonHovered = true),
            onExit: (_) => setState(() => _isNextButtonHovered = false),
            child: GestureDetector(
              onTap: widget.onNextEpisode,
              child: AnimatedScale(
                scale: _isNextButtonHovered ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _isNextButtonHovered ? 16 : 12,
                      sigmaY: _isNextButtonHovered ? 16 : 12,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(_isNextButtonHovered ? 0.95 : 0.85),
                            Colors.white.withOpacity(_isNextButtonHovered ? 0.85 : 0.65),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(_isNextButtonHovered ? 0.4 : 0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(_isNextButtonHovered ? 0.4 : 0.3),
                            blurRadius: _isNextButtonHovered ? 30 : 25,
                            offset: Offset(0, _isNextButtonHovered ? 12 : 10),
                            spreadRadius: -5,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Next Episode'.toUpperCase(),
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.85),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.black.withOpacity(0.85),
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
