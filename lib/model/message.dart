class Message {
  final String message;
  final String sentByMe;
  final String time;
  final String roomId;

  Message({required this.message, required this.sentByMe, required this.time, required this.roomId});

  factory Message.fromJson(Map<String, dynamic> map){
    final msg  = (map['message'] ?? map['text'] ?? '').toString();
    final from = (map['sendByMe'] ?? map['from']  ?? '').toString();
    final time = (map['time'] ?? map['ts']  ?? '').toString();
    final room = (map['room'] ?? map['roomId'] ?? '').toString();
    return Message(message: msg, sentByMe: from, time: time, roomId: room);
  }
}