import 'dart:io';

import 'package:chat_app/model/message.dart';
import 'package:chat_app/screens/widget/video_player_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PreviewContent extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;
  const PreviewContent({super.key, required this.items, this.initialIndex = 0});

  @override
  State<PreviewContent> createState() => _PreviewContentState();
}

class _PreviewContentState extends State<PreviewContent> {
  late PageController _pageController;

  @override
  void initState() {
    _pageController = PageController(initialPage: widget.initialIndex);
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[300],
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final message = items[index];
                final url = (message.url.toString());
                final mime = message.mime.toString().toLowerCase();
                final isVideo = mime.startsWith('video/') ||
                      url.toLowerCase().endsWith('.mp4') ||
                      url.toLowerCase().endsWith('mkv') ||
                      url.toLowerCase().endsWith('mov');
                return Center(
                  child: Hero(
                    tag: url.isNotEmpty ? url : 'media_$index',
                    child: isVideo 
                      ? VideoPlayerWidget(url: url, mime: mime, checkScreen: 1,)
                      : Image.file(File(url), fit: BoxFit.contain,)
                  ),
                );
              }
            ),
            Positioned(
              top: 10,
              left: 10,
              child: IconButton(
                onPressed: (){
                  print('Tapped');
                  Get.back();
                }, 
                icon: Icon(Icons.close, size: 30,)
              )
            ),
          ],
        ),
      ),
    );
  }
}