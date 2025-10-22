import 'dart:convert';
import 'dart:typed_data';

class Message {
  final String id, from, to, message, sentByMe, time, type;
  final String? url, name, mime, kind;
  final int? durationMs;
  final List<double>? wave;
  final Uint8List? bytes;
  final List<MediaItem>? items;

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
    this.kind,
    this.durationMs,
    this.wave,
    this.bytes,
    this.items,
  });

  // bool get isPacket => items != null && items!.isNotEmpty;

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
    final data = map['bytes'] ?? map['data'];
    if(data is String) {
      bytes = base64Decode(data);
    } else if(data is List) {
      bytes = Uint8List.fromList(data.cast<int>());
    }

    final items = (map['items'] is List) 
          ? (map['items'] as List)
                .whereType<Map>()
                .map((e)=> MediaItem.fromJson(e.cast<String, dynamic>())).toList()
          : null;

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
      items: items,
    );
  }
  
}

class MediaItem {
  final String type;
  final String? url, name, mime;
  final Uint8List? bytes;

  MediaItem({required this.type, this.url, this.name, this.mime, this.bytes});

  factory MediaItem.fromJson(Map<String, dynamic> map){
    Uint8List? bytes;
    final data = (map['data'] ?? map['bytes']);

    if(data is String) {
      bytes = base64Decode(data);
    } else if(data is List) {
      bytes = Uint8List.fromList(data.cast<int>());
    }

    return MediaItem(
      type: (map['type'] ?? 'image').toString(),
      url: map['url']?.toString(),
      name: map['name']?.toString(),
      mime: map['mime']?.toString(),
      bytes: bytes,
    );
  }
}