import 'dart:io';
import 'dart:typed_data';

import 'package:chat_app/model/message.dart';
import 'package:chat_app/screens/widget/audio_wave_widget.dart';
import 'package:chat_app/screens/widget/video_player_widget.dart';
import 'package:flutter/material.dart';
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
              margin: EdgeInsets.only(top: 6),
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
        
        if (files.isEmpty && (url != null || (bytes?.isNotEmpty ?? false))){
          files.add(MediaItem(type: 'media', url: url, mime: mime, bytes: bytes));
        }

        if(files.isEmpty) return const Icon(Icons.broken_image, size: 80, color: Colors.red);

        return isMe.value
        ? Row(
            spacing: 10,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(time.value.toString()),
              Container(
                width: 230,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: files.length > 4 ? 4 : files.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: files.length == 1 ? 1 : 2,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 5,
                  ),
                  itemBuilder: (context, index) {
                    final item = files[index];
                    final url = (item.url ?? '');
                    final mime = (item.mime ?? '').toLowerCase();
                    final isVideo = mime.startsWith('video/') ||
                                  url.toLowerCase().endsWith('.mp4') ||
                                  url.toLowerCase().endsWith('.mov') ||
                                  url.toLowerCase().endsWith('.mkv');
              
                    // if items larger then 4
                    final hasExtra = files.length > 4;
                    if(hasExtra && index == 3){
                      final extra = files.length - 3;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                          ),
                          child: Text('$extra+', style: TextStyle(fontSize: 18),),
                        ),
                      );
                    }
              
                    if (isVideo) {
                      if (url.isNotEmpty) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: VideoPlayerWidget(url: url),
                        );
                      }
                      return const Icon(Icons.broken_image, color: Colors.red);
                    } else {
                      // from network
                      if (url.startsWith('http')) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(url, fit: BoxFit.cover),
                        );
                      } else if (url.isNotEmpty && File(url).existsSync()) {
                        // from url file anywhere
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(url), fit: BoxFit.cover),
                        );
                      }
                      return const Icon(Icons.broken_image, color: Colors.red);
                    }
                  },
                ),
              ),
            ],
          )
        : Row(
            spacing: 10,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 230,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: files.length > 4 ? 4 : files.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: files.length == 1 ? 1 : 2,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 5,
                  ),
                  itemBuilder: (context, index) {
                    final item = files[index];
                    final url = (item.url ?? '');
                    final mime = (item.mime ?? '').toLowerCase();
                    final isVideo = mime.startsWith('video/') ||
                                  url.toLowerCase().endsWith('.mp4') ||
                                  url.toLowerCase().endsWith('.mov') ||
                                  url.toLowerCase().endsWith('.mkv');
              
                    // if items larger then 4
                    final hasExtra = files.length > 4;
                    if(hasExtra && index == 3){
                      final extra = files.length - 3;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                          ),
                          child: Text('$extra+', style: TextStyle(fontSize: 18),),
                        ),
                      );
                    }
              
                    if (isVideo) {
                      if (url.isNotEmpty) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: VideoPlayerWidget(url: url),
                        );
                      }
                      return const Icon(Icons.broken_image, color: Colors.red);
                    } else {
                      // from network
                      if (url.startsWith('http')) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(url, fit: BoxFit.cover),
                        );
                      } else if (url.isNotEmpty && File(url).existsSync()) {
                        // from url file from gallery
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(url), fit: BoxFit.cover),
                        );
                      }
                      return const Icon(Icons.broken_image, color: Colors.red);
                    }
                  },
                ),
              ),
              Text(time.value.toString()),
            ],
          );

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
