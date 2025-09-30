import 'package:chat_app/controller/chat_controller.dart';
import 'package:chat_app/model/message.dart';
import 'package:chat_app/screens/widget/message_item.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class ChatScreen extends StatefulWidget {
  RxString name;
  RxString image;
  RxInt myId;
  RxInt peerId;
  ChatScreen({
    super.key,
    required this.name,
    required this.image,
    required this.myId,
    required this.peerId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  ChatController chatController = Get.put(ChatController());
  final TextEditingController _controller = TextEditingController();
  final isConnected = false.obs;

  @override
  void initState() {
    super.initState();

    final me = widget.myId.value.toString();
    final peer = widget.peerId.value.toString();

    chatController.initSocket(myId: me);

    final socket = chatController.socket;

    socket.off('dm');
    socket.on('dm', (data) {
      final map = data is Map<String, dynamic>
          ? Map<String, dynamic>.from(data)
          : Map<String, dynamic>.from(data as Map);

      final from = map['from']?.toString() ?? '';
      final to = map['to']?.toString() ?? '';

      if(from == me) return;

      final involeThisChat =
          (from == peer && to == me) || (from == me && to == peer);

      if (!involeThisChat) return;

      final msg = Message.fromJson(map);
      chatController.addDm(me, peer, msg);
    });
    socket.connect();
  }

  @override
  void dispose() {
    chatController.socket.off('dm');
    super.dispose();
    if(chatController.socket.connected) chatController.socket.disconnect();
    chatController.socket.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.myId.value.toString();
    final peer = widget.peerId.value.toString();

    final dmStream = chatController.thread(me, peer);
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
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
                child: Obx(() {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: ListView.builder(
                      itemCount: dmStream.length,
                      itemBuilder: (context, index) {
                        final currentMessage = dmStream[index];
                        return MessageItem(
                          isMe: (currentMessage.sentByMe == me).obs,
                          message: currentMessage.message.obs,
                          time: currentMessage.time.obs,
                          image: widget.image,
                        );
                      },
                    ),
                  );
                }),
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
                        if (text.isEmpty) return;
                        sendMessage(text);
                        _controller.clear();
                      },
                      icon: Icon(Icons.send, size: 30),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void sendMessage(String text) {
    DateTime now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    String peroid = hour >= 12 ? "PM" : "AM";

    String time = '$hour:${minute.toString().padLeft(2, '0')} $peroid';

    final me = widget.myId.value.toString();
    final peer = widget.peerId.value.toString();

    final offMsg = {
      "message": text,
      "text": text,
      "time": time,
      "sendByMe": me,
      "from": me,
    };
    
    chatController.addDm(me, peer, Message.fromJson(offMsg));

    if (chatController.isConnected.value && chatController.socket.connected) {
      var messageJson = {
        "from": me,
        "to": peer,
        "message": text,
        "text": text,
        "time": time,
        "sendByMe": me,
      };
      chatController.socket.emit('dm', messageJson);
      return;
    }

  }
}
