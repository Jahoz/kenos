import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_fonts.dart';
import '../../../echo/domain/echo_media.dart';

/// The attached fragment, made visible before launch: a thumbnail for
/// images, a duration line and a private listen for recordings. The
/// author sees what they give (the reader will have to hold for it).
class MediaDraftPreview extends StatefulWidget {
  const MediaDraftPreview({
    super.key,
    required this.media,
    required this.onRemoved,
  });

  final EchoMediaDraft media;
  final VoidCallback onRemoved;

  @override
  State<MediaDraftPreview> createState() => _MediaDraftPreviewState();
}

class _MediaDraftPreviewState extends State<MediaDraftPreview> {
  AudioPlayer? _player;
  bool _listening = false;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  /// The author may rehear their own fragment before sealing it.
  Future<void> _toggleListen() async {
    if (_listening) {
      await _player?.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      _player ??= AudioPlayer();
      await _player!.setAudioSource(
        AudioSource.uri(
          Uri.dataFromBytes(
            widget.media.bytes,
            mimeType: playbackAudioMime(widget.media.bytes),
          ),
        ),
      );
      unawaited(_player!.play().then((_) {
        if (mounted) setState(() => _listening = false);
      }));
      setState(() => _listening = true);
    } catch (_) {
      // Silence is also an answer: the preview never blocks the send.
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final isImage = media.kind == EchoMediaKind.image;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.hairlineStrong),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 72,
                height: 72,
                child: Image.memory(
                  Uint8List.fromList(media.bytes),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _BrokenFragment(),
                ),
              ),
            )
          else
            SizedBox(
              width: 72,
              height: 72,
              child: _WaveformSeed(
                listening: _listening,
                color: AppColors.teal,
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isImage ? 'FRAGMENT VISUEL' : 'FRAGMENT SONORE',
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 9,
                    letterSpacing: 3,
                    color: AppColors.fade(AppColors.pureLight, 0.75),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${media.name} · ${media.sizeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.mono,
                    fontSize: 8,
                    letterSpacing: 1,
                    color: AppColors.fade(AppColors.pureLight, 0.45),
                  ),
                ),
                if (!isImage) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _toggleListen,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _listening ? Icons.stop : Icons.play_arrow,
                          size: 16,
                          color: AppColors.teal,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _listening ? 'ARRÊTER' : 'ÉCOUTER',
                          style: TextStyle(
                            fontFamily: AppFonts.mono,
                            fontSize: 8,
                            letterSpacing: 2,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retirer le fragment',
            onPressed: widget.onRemoved,
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.fade(AppColors.pureLight, 0.6),
          ),
        ],
      ),
    );
  }
}

class _BrokenFragment extends StatelessWidget {
  const _BrokenFragment();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.voidBlackDeep,
      child: Icon(
        Icons.broken_image_outlined,
        size: 22,
        color: AppColors.fade(AppColors.pureLight, 0.3),
      ),
    );
  }
}

/// A quiet waveform seed — not a real waveform (we never decode the
/// audio), but a visual that says "sound lives here". It breathes
/// while listening.
class _WaveformSeed extends StatelessWidget {
  const _WaveformSeed({required this.listening, required this.color});

  final bool listening;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bars = [0.35, 0.7, 0.45, 0.9, 0.55, 1.0, 0.4, 0.75, 0.5];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.voidBlackDeep,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final h in bars)
            Container(
              width: 3,
              height: 40 * h * (listening ? 1.0 : 0.7),
              decoration: BoxDecoration(
                color: AppColors.fade(color, 0.35 + 0.45 * h),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
