import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:john_estacio_website/features/works/domain/models/work_model.dart';
import 'package:john_estacio_website/features/works/presentation/widgets/audio_progress_bar.dart';
import 'package:john_estacio_website/theme.dart';

class AudioPlayerDialog extends StatefulWidget {
  final List<AudioClip> audioClips;
  final String title;

  const AudioPlayerDialog({
    required this.audioClips,
    required this.title,
    super.key,
  });

  @override
  State<AudioPlayerDialog> createState() => _AudioPlayerDialogState();
}

class _AudioPlayerDialogState extends State<AudioPlayerDialog> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final ScrollController _scrollController = ScrollController();
  int? _currentlyPlayingIndex;

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _play(int index, String url) async {
    try {
      await _audioPlayer.setUrl(url);
      _audioPlayer.play();
      setState(() {
        _currentlyPlayingIndex = index;
      });
    } catch (e) {
      // Handle error
      print("Error loading audio source: $e");
    }
  }

  void _stop() {
    _audioPlayer.stop();
    setState(() {
      _currentlyPlayingIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkGray,
      title: Text(
        widget.title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.white),
      ),
      content: SizedBox(
        width: 400,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.audioClips.length, (index) {
                final clip = widget.audioClips[index];
                final isActive = _currentlyPlayingIndex == index;
                final isPlaying = isActive && _audioPlayer.playing;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                      title: Text(
                        clip.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.white),
                      ),
                      trailing: isActive
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Always show a Pause button when active. Disable when already paused.
                                IconButton(
                                  icon: const Icon(Icons.pause_circle_outline),
                                  color: AppTheme.primaryOrange,
                                  onPressed: isPlaying
                                      ? () async {
                                          await _audioPlayer.pause();
                                          setState(() {});
                                        }
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.stop_circle_outlined),
                                  color: AppTheme.primaryOrange,
                                  onPressed: _stop,
                                ),
                              ],
                            )
                          : IconButton(
                              icon: const Icon(Icons.play_circle_outline),
                              color: AppTheme.primaryOrange,
                              onPressed: () => _play(index, clip.url),
                            ),
                    ),
                    if (isActive) AudioProgressBar(player: _audioPlayer),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}