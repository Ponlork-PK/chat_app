import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import 'package:chat_app/controller/chat_controller.dart';


class LiveRecordBar extends StatelessWidget {
  final String? me;
  final String? peer;
  LiveRecordBar({super.key, this.me, this.peer});

  final ChatController chatController = Get.find<ChatController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!chatController.isRecording.value) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () async {
                chatController.setCancelRecording(true);
                await chatController.endVoiceHold(
                  from: me.toString(),
                  to: peer.toString(),
                );
              }, 
              icon: Icon(Icons.delete, color: Colors.red, size: 30,),
            ),
            Expanded(
              child: Container(
                height: 60,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 6),
                    const Icon(Icons.mic, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Obx(() => TinyWaveform(
                              samples: chatController.waveformSamples.toList(growable: false),
                              height: 28,
                              barWidth: 3,
                              barGap: 2,
                              isRecording: true,
                              isOutgoing: true,
                            )),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Obx(() => Text(
                          _formatElapsed(chatController.elapsedSeconds.value),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        )),
                  ],
                ),
              ),
            ),
            IconButton(
              onPressed: (){
                chatController.endVoiceHold(from: me.toString(), to: peer.toString());
              }, 
              icon: Icon(Icons.send, color: Colors.blue, size: 30,),
            )
          ],
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

  StreamSubscription? _stateSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _positionSub;

  @override
  void initState() {
    super.initState();

    _stateSub = audioPlayer.onPlayerStateChanged.listen(
      (state) => setState(() => isPlaying = (state == PlayerState.playing)),
    );
    _durationSub = audioPlayer.onDurationChanged.listen(
      (d) => setState(() => totalDuration = d),
    );
    _positionSub = audioPlayer.onPositionChanged.listen(
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
    _stateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
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

