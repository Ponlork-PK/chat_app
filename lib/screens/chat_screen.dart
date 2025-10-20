import 'package:chat_app/controller/chat_controller.dart';
import 'package:chat_app/model/message.dart';
import 'package:chat_app/screens/widget/audio_wave_widget.dart';
import 'package:chat_app/screens/widget/message_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: must_be_immutable
class ChatScreen extends StatefulWidget {
  RxString name;
  RxString myImage;
  RxString peerImage;
  RxInt myId;
  RxInt peerId;
  ChatScreen({
    super.key,
    required this.name,
    required this.myImage,
    required this.peerImage,
    required this.myId,
    required this.peerId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ChatController chatController = Get.find<ChatController>();
  final TextEditingController _controller = TextEditingController();
  final isConnected = false.obs;

  @override
  void initState() {
    super.initState();

    final me = widget.myId.value.toString();
    final peer = widget.peerId.value.toString();

    chatController.setupSocket(myId: me);
    chatController.connectSafely();

    final socket = chatController.socketService.socket;

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
      chatController.appendMessage(me, peer, msg);
    });

    chatController.incomingMediaController.stream.listen((p){
      final me = widget.myId.value.toString();
      final peer = widget.peerId.value.toString();
      final from = (p['from'] ?? '').toString();
      final to = (p['to'] ?? '').toString();

      final inThisChat = (from == peer && to == me) || (from == me && to == peer);
      if(!inThisChat) return;
      final msg = Message.fromJson(p);
      chatController.appendMessage(me, peer, msg);
      chatController.scrollToBottom();
    });

    chatController.incomingAudioController.stream.listen((p){
      final from = (p['from'] ?? '').toString();
      final to = (p['to'] ?? '').toString();

      final inThisChat = (from == peer && to == me) || (from == me && to == peer);
      if(!inThisChat) return;
      final msg = Message.fromJson(p);
      chatController.appendMessage(me, peer, msg);
      chatController.scrollToBottom();
    });

  }

  @override
  void dispose() {
    chatController.socketService.socket.off('dm');
    super.dispose();
    if (chatController.socketService.socket.connected) chatController.socketService.socket.disconnect();
    chatController.socketService.socket.dispose();
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
          body: _buildBody,
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
                child: Image.network(widget.peerImage.value, fit: BoxFit.cover),
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

  get _buildBody => Stack(
    children: [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        bottom: 60,
        child: Column(children: [_buildMessageList])),

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
  );

  get _buildMessageList => Expanded(
    child: Obx(() {
      final me = widget.myId.value.toString();
      final peer = widget.peerId.value.toString();
      final dmStream = chatController.getThread(me, peer);

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
              myImage: widget.myImage,
              peerImage: widget.peerImage,
              type: currentMessage.type,
              url: currentMessage.url,
              mime: currentMessage.mime,
              duration: currentMessage.durationMs,
              wave: currentMessage.wave,
              bytes: currentMessage.bytes,
              items: currentMessage.items,
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
            onPressed: () async{
              await chatController.pickAndSendMultipleMedia(widget.peerId.value.toString());
            },
            icon: Icon(Icons.image, size: 30),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onLongPressStart: (_) {
              chatController.startVoiceHold();
            },
            onLongPressMoveUpdate: (d) => chatController.setCancelRecording(d.localOffsetFromOrigin.dy < -60),
            onLongPressEnd: (_) async {
              chatController.endVoiceHold(from: widget.myId.value.toString(), to: widget.peerId.value.toString());
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
              final me = widget.myId.value.toString();
              final peer = widget.peerId.value.toString();
              final text = _controller.text.trim();
              if (text.isEmpty) return;
              chatController.sendMessage(me: me, peer: peer, text: text);
              chatController.scrollToBottom();
              _controller.clear();
            },
            icon: Icon(Icons.send, size: 30),
          ),
        ],
      ),
    ),
  );
}
