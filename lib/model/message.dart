import 'dart:typed_data';

class Message {
  final String id;
  final String from;
  final String to;
  final String message;
  final String sentByMe;
  final String time;

  final String type;
  final String? url;
  final String? name;
  final String? mime;
  final int? durationMs;
  final List<double>? wave;
  final Uint8List? bytes;

  Message({
    required this.id, 
    required this.from, 
    required this.to, 
    required this.message, 
    required this.sentByMe, 
    required this.time,

    this.type = 'text',
    this.url,
    this.name,
    this.mime,
    this.durationMs,
    this.wave,
    this.bytes,
  });

  factory Message.fromJson(Map<String, dynamic> map){
    final id = (map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString());
    final to = (map['to'] ?? '').toString();
    final msg  = (map['message'] ?? map['text'] ?? '').toString();
    final from = (map['from']  ?? '').toString();
    final time = (map['time'] ?? map['ts']  ?? '').toString();
    final sentByMe = (map['sentByMe'] ?? map['sendByMe'] ?? map['from'] ?? '').toString();
    final type = (map['type'] ?? 'text').toString();
    final url = map['url']?.toString();
    final name = map['name']?.toString();
    final mime = map['mime']?.toString();

    int? durationMs;
    final dRaw = map['duration'] ?? map['durationMs'];
    if(dRaw is int){
      durationMs = dRaw;
    } else if(dRaw is String){
      durationMs = int.parse(dRaw);
    }

    List<double>? wave;
    final wRaw = map['wave'];
    if(wRaw is List){
      wave = wRaw.map((e)=> (e as num).toDouble()).toList();
    }

    Uint8List? bytes;
    final bRaw = map['bytes'] ?? map['data'];
    if(bRaw is Uint8List) {
      bytes = bRaw;
    } else if(bRaw is ByteBuffer) {
      bytes = bRaw.asUint8List();
    } else if(bRaw is List<int>) {
      bytes = Uint8List.fromList(bRaw);
    } else if(bRaw is List){
      bytes = Uint8List.fromList(bRaw.map((e)=> (e as num).toInt()).toList());
    }

    return Message(
      id: id, 
      to: to, 
      from: from, 
      message: msg, 
      sentByMe: sentByMe, 
      time: time,
      type: type,
      url: url,
      name: name,
      mime: mime,
      durationMs: durationMs,
      wave: wave,
      bytes: bytes,
    );
  }
  
}