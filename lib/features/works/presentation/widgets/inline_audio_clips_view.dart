import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart';
import 'package:john_estacio_website/features/works/presentation/widgets/audio_progress_bar.dart';
import 'package:john_estacio_website/theme.dart';

class InlineAudioClipsView extends StatefulWidget {
  final List<Object> audioClips;
  final EdgeInsetsGeometry padding;

  const InlineAudioClipsView({super.key, required this.audioClips, this.padding = const EdgeInsets.all(12)});

  @override
  State<InlineAudioClipsView> createState() => _InlineAudioClipsViewState();
}

class _InlineAudioClipsViewState extends State<InlineAudioClipsView> {
  final AudioPlayer _player = AudioPlayer();
  int? _playingIndex;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(int index, String url) async {
    if (_playingIndex == index) {
      // Pause if same item is playing
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      setState(() {});
      return;
    }

    try {
      await _player.setUrl(url);
      await _player.play();
      setState(() => _playingIndex = index);
    } catch (e) {
      debugPrint('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not play audio.')),
      );
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() => _playingIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkGray,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: widget.padding,
      child: Column(
        children: [
          for (int i = 0; i < widget.audioClips.length; i++)
            Builder(
              builder: (context) {
                final clip = widget.audioClips[i] as AudioClip;
                final isActive = _playingIndex == i;
                final isPlaying = isActive && _player.playing;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AudioRow(
                      title: clip.title,
                      isActive: isActive,
                      isPlaying: isPlaying,
                      onPlayPause: () => _togglePlay(i, clip.url),
                      onStop: isActive ? _stop : null,
                    ),
                    if (isActive) AudioProgressBar(player: _player),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AudioRow extends StatelessWidget {
  final String title;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback? onStop;

  const _AudioRow({
    required this.title,
    required this.isActive,
    required this.isPlaying,
    required this.onPlayPause,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.white,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
      ),
      trailing: isActive
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Always show Pause and Stop when active. Pause is disabled if already paused.
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline),
                  color: AppTheme.primaryOrange,
                  onPressed: isPlaying ? onPlayPause : null,
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined),
                  color: AppTheme.primaryOrange,
                  onPressed: onStop,
                ),
              ],
            )
          : IconButton(
              icon: const Icon(Icons.play_circle_outline),
              color: AppTheme.primaryOrange,
              onPressed: onPlayPause,
            ),
    );
  }
}