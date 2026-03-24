import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:john_estacio_website/theme.dart';

class AudioProgressBar extends StatefulWidget {
  final AudioPlayer player;
  final EdgeInsetsGeometry padding;

  const AudioProgressBar({super.key, required this.player, this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8)});

  @override
  State<AudioProgressBar> createState() => _AudioProgressBarState();
}

class _AudioProgressBarState extends State<AudioProgressBar> {
  double? _dragValue; // in milliseconds

  String _formatDuration(Duration? d) {
    final duration = d ?? Duration.zero;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;

    return Padding(
      padding: widget.padding,
      child: StreamBuilder<Duration?>(
        stream: player.durationStream,
        builder: (context, durationSnap) {
          final total = durationSnap.data ?? Duration.zero;

          return StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, positionSnap) {
              final position = positionSnap.data ?? Duration.zero;

              return StreamBuilder<Duration>(
                stream: player.bufferedPositionStream,
                builder: (context, bufferedSnap) {
                  final buffered = bufferedSnap.data ?? Duration.zero;

                  final totalMs = total.inMilliseconds.toDouble().clamp(0.0, double.infinity);
                  final positionMs = (_dragValue ?? position.inMilliseconds.toDouble()).clamp(0.0, totalMs == 0.0 ? 1.0 : totalMs);
                  final bufferedMs = buffered.inMilliseconds.toDouble().clamp(0.0, totalMs == 0.0 ? 1.0 : totalMs);

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 28,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              // Base track (light gray)
                              Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGray,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              // Buffered track (white)
                              FractionallySizedBox(
                                widthFactor: totalMs > 0 ? (bufferedMs / totalMs).clamp(0.0, 1.0) : 0.0,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppTheme.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              // Progress track (primary orange)
                              FractionallySizedBox(
                                widthFactor: totalMs > 0 ? (positionMs / totalMs).clamp(0.0, 1.0) : 0.0,
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryOrange,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              // Slider thumb (with transparent track)
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  // Make the thumb travel the full width with no side padding.
                                  trackShape: const _FullWidthSliderTrackShape(),
                                  trackHeight: 0, // we paint our own tracks above
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                  // Remove extra overlay padding so extremes align perfectly.
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                                  overlayColor: Colors.transparent,
                                  activeTrackColor: Colors.transparent,
                                  inactiveTrackColor: Colors.transparent,
                                  thumbColor: AppTheme.primaryOrange,
                                ),
                                child: Slider(
                                  min: 0.0,
                                  max: totalMs <= 0 ? 1.0 : totalMs,
                                  value: positionMs.isNaN ? 0.0 : positionMs.clamp(0.0, totalMs <= 0 ? 1.0 : totalMs),
                                  onChanged: totalMs <= 0
                                      ? null
                                      : (v) {
                                          setState(() => _dragValue = v);
                                        },
                                  onChangeEnd: totalMs <= 0
                                      ? null
                                      : (v) {
                                          player.seek(Duration(milliseconds: v.round()));
                                          setState(() => _dragValue = null);
                                        },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _formatDuration(total),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.white),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// Ensures Slider's track rect spans the full available width so the thumb can
// align flush with both ends of the custom-painted track.
class _FullWidthSliderTrackShape extends RoundedRectSliderTrackShape {
  const _FullWidthSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 2;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
