import 'package:chat_app/controller/chat_controller.dart';
import 'package:chat_app/model/message.dart';
import 'package:chat_app/screens/widget/message_item.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class ChatScreen extends StatefulWidget {
  RxString name;
  RxString image;
  RxInt myId;
  RxInt peerId;
  ChatScreen({super.key, required this.name, required this.image, required this.myId, required this.peerId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  ChatController chatController = Get.put(ChatController());
  final TextEditingController _controller =
      TextEditingController(); // text controller
  late IO.Socket socket;
  final isConnected = false.obs;

  late final String roomId;
  String _makeRoomId(int a, int b) {
    final x = a < b ? a : b;
    final y = a < b ? b : a;
    return '$x-$y';
  }

  @override
  void initState(){
    super.initState();

    roomId = _makeRoomId(widget.myId.value, widget.peerId.value);

    socket = IO.io('http://localhost:3000', 
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build()
    );
    socket.onConnect((_){
      isConnected.value = true;
      socket.emit('join', {'room': roomId});
      print("Join room: $roomId");
    });
    socket.onDisconnect((_){
      isConnected.value = false;
    });

    socket.off('dm');
    socket.on('dm', (data){
      final msg = Message.fromJson(data is Map<String, dynamic> ? data : <String, dynamic>{});
      if(msg.roomId == roomId) {
        chatController.add(roomId, msg);
      }

      if (msg.roomId != roomId) return;
      if (msg.sentByMe == widget.myId.value.toString()) return;
    });
    socket.connect();
  }

  @override
  void dispose() {
    socket.off('dm');
    socket.off('connect');
    socket.off('disconnect');

    if (socket.connected) socket.disconnect();
    socket.dispose();

    _controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final roomStream = chatController.room(roomId);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              Get.back();
            },
            icon: Icon(Icons.arrow_back_ios),
          ),
          title: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        widget.image.value,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(widget.name.value, style: TextStyle(fontSize: 20)),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(onPressed: () {}, icon: Icon(Icons.call)),
            IconButton(onPressed: () {}, icon: Icon(Icons.video_call)),
            IconButton(onPressed: () {}, icon: Icon(Icons.info_outline)),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Obx((){
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: ListView.builder(
                    itemCount: roomStream.length,
                    itemBuilder: (context, index) {
                      final currentMessage = roomStream[index];
                      return MessageItem(
                        isMe: (currentMessage.sentByMe == widget.myId.value.toString()).obs,
                        message: currentMessage.message.obs,
                        time: currentMessage.time.obs,
                      );
                    },
                  ),
                );
              })
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      maxLines: 3,
                      minLines: 1,
                      controller: _controller,
                      decoration: InputDecoration(
                        hint: Text('message'),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (!isConnected.value || text.isEmpty) return;
                      sendMessage(text);
                      _controller.clear();
                    },
                    // onPressed: _sendMessage,
                    icon: Icon(Icons.send, size: 30),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void sendMessage(String text){
    DateTime now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    String peroid = hour >= 12 ? "PM" : "AM";

    String time = '$hour:${minute.toString().padLeft(2, '0')} $peroid';

    final me = widget.myId.value.toString();
    var messageJson = {
      "room": roomId,
      "from": me,
      "to": widget.peerId.value.toString(),
      "message": text,
      "time": time,
      "sendByMe": me,
      "roomId": roomId,
    };
    socket.emit('dm', messageJson);
  }

  // void setUpSocketListener(){
  //   socket.on('dm', (data) {
  //     final map = data is Map<String, dynamic>
  //         ? data
  //         : Map<String, dynamic>.from(data as Map);
  //     final msg = Message.fromJson(map);
  //     if (msg.roomId == roomId) {
  //       chatController.add(roomId, msg);
  //     }
  //     print('data-receive: $data');
  //   });
  // }
}
