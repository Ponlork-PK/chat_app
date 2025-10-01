class Message {
  final String id;
  final String from;
  final String to;
  final String message;
  final String sentByMe;
  final String time;

  Message({required this.id, required this.from, required this.to, required this.message, required this.sentByMe, required this.time});

  factory Message.fromJson(Map<String, dynamic> map){
    final id = (map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString());
    final to = (map['to'] ?? '').toString();
    final msg  = (map['message'] ?? map['text'] ?? '').toString();
    final from = (map['from']  ?? '').toString();
    final time = (map['time'] ?? map['ts']  ?? '').toString();
    final sentByMe = (map['sentByMe'] ?? map['sendByMe'] ?? map['from'] ?? '').toString();
    return Message(
      id: id, 
      to: to, 
      from: from, 
      message: msg, 
      sentByMe: sentByMe, 
      time: time,
    );
  }
  
}