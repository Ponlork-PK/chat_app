import 'dart:io';
import 'dart:typed_data';

import 'package:chat_app/model/message.dart';
import 'package:chat_app/screens/widget/audio_wave_widget.dart';
import 'package:chat_app/screens/widget/video_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:get/get.dart';

// ignore: must_be_immutable
class MessageItemWidget extends StatelessWidget {
  late RxBool isMe;
  RxString message;
  RxString time;
  RxString myImage;
  RxString peerImage;
  final String type;
  final String? url;
  final String? mime;
  final int? duration;
  final List<double>? wave;
  final Uint8List? bytes;
  final List<MediaItem>? items;
  MessageItemWidget({
    super.key,
    required this.isMe,
    required this.message,
    required this.time,
    required this.myImage,
    required this.peerImage,
    this.type = 'text',
    this.url,
    this.mime,
    this.duration,
    this.wave,
    this.bytes,
    this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (type == 'text' && message.isEmpty && time.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: isMe.value ? Alignment.centerRight : Alignment.centerLeft,
      child: isMe.value 
        ? Row(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Container(
              margin: EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(10),
                  topRight: const Radius.circular(10),
                  bottomLeft: Radius.circular(isMe.value ? 10 : 2),
                  bottomRight: Radius.circular(isMe.value ? 2 : 10),
                ),
              ),
              child: isMe.value ? _buildContent() : SizedBox.shrink(),
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.transparent,
              image: DecorationImage(
                image: NetworkImage(myImage.value),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(17),
            ),
          ),
        ],
      )
      : Row(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.transparent,
              image: DecorationImage(
                image: NetworkImage(peerImage.value),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          Flexible(
            child: Container(
              margin: EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(10),
                  topRight: const Radius.circular(10),
                  bottomLeft: Radius.circular(isMe.value ? 10 : 2),
                  bottomRight: Radius.circular(isMe.value ? 2 : 10),
                ),
              ),
              child: isMe.value ? SizedBox.shrink() : _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (type) {
      case 'media':
        final files = items ?? <MediaItem>[];
        final ext = (mime ?? path.extension(url ?? '').toLowerCase());
        final isVideo = mime?.startsWith('video/') == true 
                        || ext.endsWith('.mp4')
                        || ext.endsWith('.mkv')
                        || ext.endsWith('.mov');
        if(files.isEmpty && (url != null || (bytes != null || bytes!.isNotEmpty))){
          files.add(MediaItem(type: 'media', url: url, mime: mime, bytes: bytes));
        }

        if(files.isEmpty) return const Icon(Icons.broken_image, size: 80, color: Colors.red);

        final count = files.length;
        final cols = count == 1 ? 1 : 2;

        if(url != null && File(url!).existsSync()){
          
          return Container(
            width: 230,
            
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(15)
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: count,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
              ), 
              itemBuilder: (context, index){
                return Container(
                  child: isVideo
                    ? VideoPlayerWidget(url: url!)
                    : ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(url!),
                        width: 250,
                        height: 250,
                        fit: BoxFit.cover,
                      ),
                    ),
                );
              }
            ),
          );
        }
        
        return const Icon(Icons.broken_image, size: 80, color: Colors.red);

      case 'audio':
        return isMe.value
        ? Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 10,
          children: [
            Text(
              time.value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withAlpha(150),
              ),
            ),
            VoiceMessageBubble(
              bytes: bytes,
              filePath: url,
              durationMs: duration ?? 0, 
              waveform: wave ?? [],
              isOutgoing: isMe.value,
            ),
          ],
        )
        : Row(
          spacing: 10,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            VoiceMessageBubble(
              bytes: bytes,
              filePath: url,
              durationMs: duration ?? 0, 
              waveform: wave ?? [],
              isOutgoing: isMe.value,
            ),
            Text(
              time.value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withAlpha(150),
              ),
            ),
          ],
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
            crossAxisAlignment: CrossAxisAlignment.end,
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
