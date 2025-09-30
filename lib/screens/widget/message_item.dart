import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class MessageItem extends StatelessWidget {
  late RxBool isMe;
  RxString message;
  RxString time;
  RxString image;
  MessageItem({super.key, required this.isMe, required this.message, required this.time, required this.image});

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty && time.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: isMe.value ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        spacing: 10,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          isMe.value ? SizedBox.shrink() : Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.transparent,
              image: DecorationImage(image: NetworkImage(image.value), fit: BoxFit.cover),
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          Flexible(
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
                  Flexible(child: Text(message.value, style: TextStyle(fontSize: 20),)),
                  Text(time.value, style: TextStyle(fontSize: 14, color: Colors.black.withAlpha(150)),),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}