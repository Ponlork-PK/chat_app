import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class MessageItem extends StatelessWidget {
  late RxBool isMe;
  RxString message;
  RxString time;
  MessageItem({super.key, required this.isMe, required this.message, required this.time});

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty && time.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: isMe.value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: 4),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: Radius.circular(isMe.value ? 10 : 2),
            bottomRight: Radius.circular(isMe.value ? 2 : 10),
          ),
        ),
        child: Row(
          spacing: 8,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message.value, style: TextStyle(fontSize: 20),),
            Text(time.value, style: TextStyle(fontSize: 14, color: Colors.black.withAlpha(150)),)
          ],
        )
      ),
    );
  }
}