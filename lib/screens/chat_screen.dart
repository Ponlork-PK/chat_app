import 'package:chat_app/controller/chat_controller.dart';
import 'package:chat_app/controller/voice_controller.dart';
import 'package:chat_app/model/message.dart';
import 'package:chat_app/screens/widget/audio_wave_widget.dart';
import 'package:chat_app/screens/widget/message_item_widget.dart';
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
  final ChatController chatController = Get.find<ChatController>();
  VoiceController voiceController = Get.put(VoiceController());
  final TextEditingController _controller = TextEditingController();
  final isConnected = false.obs;

  @override
  void initState() {
    super.initState();

    final me = widget.myId.value.toString();
    final peer = widget.peerId.value.toString();

    chatController.initSocket(myId: me);
    chatController.connectSafely();

    final socket = chatController.socket;

    socket.off('dm');
    socket.on('dm', (data) {
      final map = data is Map<String, dynamic>
          ? Map<String, dynamic>.from(data)
          : Map<String, dynamic>.from(data as Map);

      final from = map['from']?.toString() ?? '';
      final to = map['to']?.toString() ?? '';

      if (from == me) return;

      final involeThisChat =
          (from == peer && to == me) || (from == me && to == peer);

      if (!involeThisChat) return;

      final msg = Message.fromJson(map);
      chatController.addDm(me, peer, msg);
    });

    chatController.inComing.stream.listen((p){
      final from = (p['from'] ?? '').toString();
      final to = (p['to'] ?? '').toString();

      final inThisChat = (from == peer && to == me) || (from == me && to == peer);
      if(!inThisChat) return;
      final msg = Message.fromJson(p);
      chatController.addDm(me, peer, msg);
      chatController.scrollToBottom();
    });

  }

  @override
  void dispose() {
    chatController.socket.off('dm');
    super.dispose();
    if (chatController.socket.connected) chatController.socket.disconnect();
    chatController.socket.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: SafeArea(
        child: Scaffold(
          appBar: _buildAppBar,
          body: Stack(
            children: [
              Column(children: [_buildMessageList]),

              Positioned(
                left: 0,
                right: 0,
                bottom: 62,
                child: LiveRecordBar()
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildInputAndSend
              )
            ]
          ),
        ),
      ),
    );
  }

  get _buildAppBar => AppBar(
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
                child: Image.network(widget.image.value, fit: BoxFit.cover),
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
  );

  get _buildMessageList => Expanded(
    child: Obx(() {
      final me = widget.myId.value.toString();
      final peer = widget.peerId.value.toString();
      final dmStream = chatController.thread(me, peer);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: ListView.builder(
          controller: chatController.scrollController,
          itemCount: dmStream.length,
          itemBuilder: (context, index) {
            final currentMessage = dmStream[index];
            return MessageItemWidget(
              isMe: (currentMessage.sentByMe == me).obs,
              message: currentMessage.message.obs,
              time: currentMessage.time.obs,
              image: widget.image,
              type: currentMessage.type,
              url: currentMessage.url,
              mime: currentMessage.mime,
              duration: currentMessage.durationMs,
              wave: currentMessage.wave,
              bytes: currentMessage.bytes,

            );
          },
        ),
      );
    }),
  );

  get _buildInputAndSend => Container(
    width: double.infinity,
    height: 60,
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              chatController.sendVideoTo(widget.peerId.value.toString());
            },
            icon: Icon(Icons.video_camera_back_outlined, size: 30),
          ),
          IconButton(
            onPressed: () {
              chatController.sendImageTo(widget.peerId.value.toString());
            },
            icon: Icon(Icons.image, size: 30),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onLongPressStart: (_) {
              chatController.startHold();
            },
            onLongPressMoveUpdate: (d) => chatController.markCancel(d.localOffsetFromOrigin.dy < -60),
            onLongPressEnd: (_) async {
              chatController.endHold(from: widget.myId.value.toString(), to: widget.peerId.value.toString());
            },
            child: Icon(Icons.mic_none, size: 30,),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              maxLines: 3,
              minLines: 1,
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                constraints: BoxConstraints(minHeight: 50, maxHeight: 50),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isEmpty) return;
              sendMessage(text);
              chatController.scrollToBottom();
              _controller.clear();
            },
            icon: Icon(Icons.send, size: 30),
          ),
        ],
      ),
    ),
  );

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
