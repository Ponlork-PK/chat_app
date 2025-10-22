import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// ignore: must_be_immutable
class VideoPlayerWidget extends StatefulWidget {
  final String url;
  final String mime;
  final int? checkScreen;
  const VideoPlayerWidget({
    super.key, 
    required this.url, 
    required this.mime, 
    this.checkScreen = 0
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController controller;

  // ignore: unused_field
  bool _ready = false;

  @override
  void initState() {
    controller = VideoPlayerController.file(File(widget.url))
          ..initialize().then((_){
            setState(() {
              _ready = true;
            });
          });

    controller.addListener((){
      if(mounted){
        setState(() {});
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if(!_ready || !controller.value.isInitialized){
      return const SizedBox(
        width: 150,
        height: 150,
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        widget.checkScreen == 0 
          ? Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            )
          : AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
        if(!controller.value.isPlaying)
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey,
            ),
            child: IconButton(
              onPressed: () {
                controller.value.isPlaying ? null : controller.play();
              },
              icon: Icon(Icons.play_arrow, size: 34,)
            ),
          )
        else
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: IconButton(
              onPressed: () {
                controller.value.isPlaying ? controller.pause() : null;
              },
              icon: Icon(Icons.pause, size: 34, color: Colors.grey,)
            ),
          )
      ]
    );
  }
}
