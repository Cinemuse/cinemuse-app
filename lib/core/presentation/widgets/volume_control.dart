import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

/// Shared volume button with expandable slider.
/// Works with any media_kit [Player] instance.
class VolumeControl extends StatefulWidget {
  final Player player;
  final double iconSize;

  const VolumeControl({
    super.key,
    required this.player,
    this.iconSize = 24,
  });

  @override
  State<VolumeControl> createState() => VolumeControlState();
}

class VolumeControlState extends State<VolumeControl> {
  bool _showSlider = false;
  double _lastVolume = 100.0;

  void toggleMute() {
    final current = widget.player.state.volume;
    if (current > 0) {
      _lastVolume = current;
      widget.player.setVolume(0);
    } else {
      widget.player.setVolume(_lastVolume > 0 ? _lastVolume : 100);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _showSlider = true),
      onExit: (_) => setState(() => _showSlider = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<double>(
            stream: widget.player.stream.volume,
            initialData: widget.player.state.volume,
            builder: (context, snapshot) {
              final volume = snapshot.data ?? widget.player.state.volume;
              IconData iconData = Icons.volume_up_rounded;
              if (volume == 0) {
                iconData = Icons.volume_off_rounded;
              } else if (volume < 50) {
                iconData = Icons.volume_down_rounded;
              }
              return IconButton(
                icon: Icon(iconData, color: Colors.white, size: widget.iconSize),
                onPressed: toggleMute,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                splashRadius: 20,
              );
            },
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: _showSlider ? 100 : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showSlider ? 1 : 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: 100,
                  child: StreamBuilder<double>(
                    stream: widget.player.stream.volume,
                    initialData: widget.player.state.volume,
                    builder: (context, snapshot) {
                      final volume = snapshot.data ?? widget.player.state.volume;
                      return SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 2,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: volume.clamp(0.0, 100.0),
                          min: 0.0,
                          max: 100.0,
                          onChanged: (v) => widget.player.setVolume(v),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
