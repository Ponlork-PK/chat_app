import 'package:chat_app/model/message.dart';
import 'package:get/get.dart';

class ChatController extends GetxController {
  final chatMessage = <String, RxList<Message>>{}.obs;
  
  RxList<Message> room(String roomId) {
    return chatMessage.putIfAbsent(roomId, () => <Message>[].obs);
  }

  void add(String roomId, Message m) {
    room(roomId).add(m);
  }

  void clearRoom(String roomId) {
    room(roomId).clear();
  }
}