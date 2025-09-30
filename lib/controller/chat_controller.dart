import 'package:chat_app/model/message.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:get/get.dart';

class ChatController extends GetxController {
  final chatMessage = <String, RxList<Message>>{}.obs;

  String _dmKey(String sender, String receiver) =>
    (sender.compareTo(receiver) <= 0) ? '$sender-$receiver' : '$receiver-$sender';
  
  RxList<Message> thread(String sender, String receiver) {
    final key = _dmKey(sender, receiver);
    return chatMessage.putIfAbsent(key, () => <Message>[].obs);
  }

  void addDm(String senderId, String receiverId, Message message) {
    thread(senderId, receiverId).add(message);
  }

  void clearRoom(String senderId, String receiverId) {
    thread(senderId, receiverId).clear();
  }

  // socket connection global
  late final IO.Socket socket;
  final isConnected = false.obs;
  bool _inited = false;

  void initSocket({required String myId}){
    if(!_inited) {
      _inited = true;

      socket = IO.io(
        'http://localhost:3000',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'username': myId})
            .disableAutoConnect()
            .build(),
      );

      socket.onConnect((_) {
        isConnected.value = true;
      });
      socket.onDisconnect((_) {
        isConnected.value = false;
      });

      socket.connect();

      return;
    }

  }
}