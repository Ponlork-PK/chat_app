import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

// ignore: must_be_immutable
class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

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

    const double maxWidth = 250;
    final aspect = controller.value.aspectRatio;
    final width = maxWidth;
    final height = width / aspect;
    return GestureDetector(
      onTap: () {
        controller.value.isPlaying ? controller.pause() : controller.play();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: width, 
            height: height, 
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: VideoPlayer(controller),
            )
          ),
          if(!controller.value.isPlaying)
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey,
              ),
              child: Icon(Icons.play_arrow),
            )
          else 
            SizedBox.shrink()
        ]
      ),
    );
  }
}
