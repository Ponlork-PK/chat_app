import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'package:chat_app/controller/chat_controller.dart';


class LiveRecordBar extends StatelessWidget {
  LiveRecordBar({super.key});

  final ChatController chatController = Get.find<ChatController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!chatController.isRecording.value) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        margin: const EdgeInsets.only(bottom: 10, left: 12, right: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.82),
          borderRadius: BorderRadius.circular(14),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Obx(() => Text(
                    _formatElapsed(chatController.second.value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  )),
              const SizedBox(width: 12),
              Obx(() => TinyWaveform(
                    samples: chatController.samples.toList(growable: false),
                    height: 28,
                    barWidth: 3,
                    barGap: 2,
                    isRecording: true,
                    isOutgoing: true,
                  )),
              const SizedBox(width: 12),
              const Text(
                'Slide up to cancel',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    });
  }

  String _formatElapsed(int seconds) {
    final minutes = seconds ~/ 60;
    final remain = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remain.toString().padLeft(2, '0')}';
  }
}


class VoiceMessageBubble extends StatefulWidget {
  final Uint8List? bytes;
  final String? filePath;
  final int durationMs;
  final List<double> waveform;
  final bool isOutgoing;

  const VoiceMessageBubble({
    super.key,
    required this.durationMs,
    required this.waveform,
    this.bytes,
    this.filePath,
    this.isOutgoing = false,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  // Visual constants
  static const int _fixedBarCount = 20;
  static const double _fixedBarWidth = 3;
  static const double _fixedBarGap = 2;

  // Player state
  final AudioPlayer audioPlayer = AudioPlayer();
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;
  Duration? totalDuration;
  String? _tempM4aPath;

  @override
  void initState() {
    super.initState();

    audioPlayer.onPlayerStateChanged.listen(
      (state) => setState(() => isPlaying = (state == PlayerState.playing)),
    );
    audioPlayer.onDurationChanged.listen(
      (d) => setState(() => totalDuration = d),
    );
    audioPlayer.onPositionChanged.listen(
      (d) => setState(() => currentPosition = d),
    );
  }

  Duration get _safeTotal => totalDuration ?? Duration(milliseconds: widget.durationMs);
  Duration get _remaining {
    final rem = _safeTotal - currentPosition;
    return rem.isNegative ? Duration.zero : rem;
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  List<double> _normalizeSamplesToBars(List<double> values, int targetCount) {
    if (values.isEmpty) return List<double>.filled(targetCount, 0.0);
    if (values.length == targetCount) return values;

    final out = List<double>.filled(targetCount, 0.0);
    for (int i = 0; i < targetCount; i++) {
      final start = (i * values.length / targetCount).floor();
      final end = (((i + 1) * values.length) / targetCount).ceil().clamp(start + 1, values.length);
      double sum = 0;
      int count = 0;
      for (int j = start; j < end; j++) {
        sum += values[j];
        count++;
      }
      out[i] = count == 0 ? values[start] : sum / count;
    }
    return out;
  }

  Future<void> _playOrPause() async {
    if (isPlaying) {
      await audioPlayer.pause();
      return;
    }

    try {
      // play directly from memory bytes
      if (widget.bytes != null) {
        await audioPlayer.play(BytesSource(widget.bytes!, mimeType: 'audio/mp4'));
        return;
      }

      // play from a file path
      if (widget.filePath != null) {
        var path = widget.filePath!;
        if (!path.toLowerCase().endsWith('.m4a')) {
          final tempDir = await getTemporaryDirectory();
          final fixed = '${tempDir.path}/vm_${DateTime.now().microsecondsSinceEpoch}.m4a';
          await File(path).copy(fixed);
          path = fixed;
        }
        await audioPlayer.play(DeviceFileSource(path, mimeType: 'audio/mp4'));
        return;
      }
    } catch (e) {
      print('Error: $e');
      // if we have bytes, write them to a .m4a temp and play
      if (widget.bytes != null) {
        _tempM4aPath ??= await _writeBytesToTemporaryM4a(widget.bytes!);
        await audioPlayer.play(DeviceFileSource(_tempM4aPath!, mimeType: 'audio/mp4'));
      } else {
        rethrow;
      }
    }
  }

  Future<String> _writeBytesToTemporaryM4a(Uint8List data) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/vm_${DateTime.now().microsecondsSinceEpoch}.m4a');
    await file.writeAsBytes(data, flush: true);
    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    final Duration safeDuration = totalDuration ?? Duration(milliseconds: widget.durationMs);
    final double progress =
        safeDuration.inMilliseconds == 0 ? 0.0 : (currentPosition.inMilliseconds / safeDuration.inMilliseconds).clamp(0.0, 1.0);

    final Color bubbleColor = widget.isOutgoing ? Colors.blue : (Colors.grey[300]!);

    final List<double> rawWave = widget.waveform.isEmpty
        ? List<double>.filled(_fixedBarCount, 0.2)
        : widget.waveform;
    final List<double> bars = _normalizeSamplesToBars(rawWave, _fixedBarCount);
    final double fixedWidth = _fixedBarCount * (_fixedBarWidth + _fixedBarGap) - _fixedBarGap;

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: widget.isOutgoing ? Colors.white : Colors.blue,
            ),
            onPressed: _playOrPause,
          ),
          SizedBox(
            width: fixedWidth,
            child: TinyWaveform(
              samples: bars,
              height: 12,
              barWidth: _fixedBarWidth,
              barGap: _fixedBarGap,
              progress: progress,
              isOutgoing: widget.isOutgoing,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(isPlaying ? _remaining : safeDuration),
            style: TextStyle(
              color: widget.isOutgoing ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final seconds = d.inSeconds;
    final minutes = seconds ~/ 60;
    final remain = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remain.toString().padLeft(2, '0')}';
  }
}


class TinyWaveform extends StatelessWidget {
  final List<double> samples;
  final double height;
  final double barWidth;
  final double barGap;
  final double? progress;
  final bool isRecording;
  final bool? isOutgoing;

  const TinyWaveform({
    super.key,
    required this.samples,
    required this.height,
    this.barWidth = 3,
    this.barGap = 2,
    this.progress,
    this.isRecording = false,
    this.isOutgoing,
  });

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) return const SizedBox(width: 60, height: 24);

    final int totalBars = samples.length;
    final double cutoffIndex = (progress == null) ? -1.0 : (progress!.clamp(0.0, 1.0) * totalBars);

    final Color playedBase = (isOutgoing ?? false) ? Colors.black : Colors.blue;
    final Color restBase = Theme.of(context).disabledColor;
    final Color recordingAccent = Theme.of(context).colorScheme.onPrimary;

    final double totalWidth = totalBars * (barWidth + barGap) - barGap;

    return SizedBox(
      height: height,
      width: totalWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(totalBars, (i) {
          final double clamped = samples[i].clamp(0.05, 1.0);
          final double barHeight = (height * clamped).clamp(2, height);
          final bool isPlayed = i <= cutoffIndex;

          final Color outgoingColor = isRecording ? recordingAccent : (isPlayed ? Colors.white : playedBase);
          final Color incomingColor = isRecording ? recordingAccent : (isPlayed ? playedBase : restBase);
          final Color barColor = (isOutgoing ?? false) ? outgoingColor : incomingColor;

          return Padding(
            padding: EdgeInsets.only(right: i == totalBars - 1 ? 0 : barGap),
            child: Container(
              width: barWidth,
              height: barHeight.toDouble(),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

