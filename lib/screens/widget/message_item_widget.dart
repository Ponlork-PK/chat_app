import 'dart:io';
import 'dart:typed_data';

import 'package:chat_app/screens/widget/audio_wave_widget.dart';
import 'package:chat_app/screens/widget/video_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class MessageItemWidget extends StatelessWidget {
  late RxBool isMe;
  RxString message;
  RxString time;
  RxString image;
  final String type;
  final String? url;
  final String? mime;
  final int? duration;
  final List<double>? wave;
  final Uint8List? bytes;
  MessageItemWidget({
    super.key,
    required this.isMe,
    required this.message,
    required this.time,
    required this.image,
    this.type = 'text',
    this.url,
    this.mime,
    this.duration,
    this.wave,
    this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    if (type == 'text' && message.isEmpty && time.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: isMe.value ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          isMe.value
              ? SizedBox.shrink()
              : Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    image: DecorationImage(
                      image: NetworkImage(image.value),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
          Flexible(
            child: Container(
              margin: EdgeInsets.only(top: 4),
              // padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                // color: isMe.value ? Colors.blue : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(10),
                  topRight: const Radius.circular(10),
                  bottomLeft: Radius.circular(isMe.value ? 10 : 2),
                  bottomRight: Radius.circular(isMe.value ? 2 : 10),
                ),
              ),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (type) {
      case 'image':
        if (url != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(url!),
              width: 250,
              height: 250,
              fit: BoxFit.cover,
            ),
          );
        }
        return const Icon(Icons.broken_image, size: 80, color: Colors.red);

      case 'video':
        if (url != null) {
          return VideoPlayerWidget(url: url!);
        }
        return Icon(Icons.videocam_off, size: 20);

      case 'audio':
        return VoiceMessageBubble(
          bytes: bytes,
          filePath: url,
          durationMs: duration ?? 0, 
          waveform: wave ?? [],
          isOutgoing: isMe.value,
        );

      case 'text':
      default:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
                color: isMe.value ? Colors.blue : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(10),
                  topRight: const Radius.circular(10),
                  bottomLeft: Radius.circular(isMe.value ? 10 : 2),
                  bottomRight: Radius.circular(isMe.value ? 2 : 10),
                ),
              ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              Flexible(
                child: Text(
                  message.value,
                  style: TextStyle(
                    fontSize: 20,
                    color: isMe.value ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Text(
                time.value,
                style: TextStyle(
                  fontSize: 14,
                  color: isMe.value ? Colors.white : Colors.black.withAlpha(150),
                ),
              ),
            ],
          ),
        );
    }
  }
}
