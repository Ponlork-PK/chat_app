import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class ChatScreen extends StatelessWidget {
  RxString name;
  RxString image;
  ChatScreen({super.key, required this.name, required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: (){
            Get.back();
          },
          icon: Icon(Icons.arrow_back_ios)
        ),
        title: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  image.value,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10,),
            Text(name.value, style: TextStyle(fontSize: 20),),
          ]
        ),
        actions: [
          IconButton(onPressed: (){}, icon: Icon(Icons.call)),
          IconButton(onPressed: (){}, icon: Icon(Icons.video_call)),
          IconButton(onPressed: (){}, icon: Icon(Icons.info_outline)),
        ],
      ),
    );
  }
}
