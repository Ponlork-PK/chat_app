import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:path/path.dart' as path;
import 'package:socket_io_client/socket_io_client.dart' as IO;
class SocketService {

  late final IO.Socket socket;
  bool _initialized = false;
  late String _selfId;
  final isConnected = false.obs;

  final incomingAudioController = StreamController<Map<String, dynamic>>.broadcast();
  final incomingMediaController = StreamController<Map<String, dynamic>>.broadcast();
  
  void initSocket({required String myId}) {
    if (_initialized) return;
    _initialized = true;
    _selfId = myId;

    socket = IO.io(
      'http://10.115.206.196:3000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'username': myId})
          .setReconnectionAttempts(0)
          .setTimeout(1500)
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      print('connected');
      isConnected.value = true;
    });

    socket.onDisconnect((_) {
      print('disconnected');
      isConnected.value = false;
    });

    socket.on('media', (data) async {
      if(data is Map && data['items'] is List){
        final base = {
          'id': (data['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
          'from': data['from'],
          'to': data['to'],
          'time': data['time'],
          'type': data['media'],
        };
        
        for( final it in (data['items'] as List)){
          if( it is Map ){
            final res = await _handleIncomingMedia({...base, ...it});
            if(res != null) incomingMediaController.add(res);
          }
        }
      } else {
        final result = await _handleIncomingMedia(data);
        if(result != null) incomingMediaController.add(result);
      }
    });

    socket.on('audio', (payload) async {
      final result = await _handleIncomingAudio(payload);
      if(result != null) incomingAudioController.add(result);
    });
  }

  void connectIfNeeded() {
    if (_initialized && !socket.connected) {
      try {
        socket.connect();
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>?> _handleIncomingMedia(dynamic data) async {
    if (data is! Map) return null;

    final id = (data['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString();
    final from = data['from']?.toString() ?? '';
    final to = data['to']?.toString() ?? '';
    final type = data['type']?.toString() ?? 'media';
    final name = data['name']?.toString() ?? '';
    final mime = data['mime']?.toString() ?? '';
    final time = data['time']?.toString() ?? '';
    final b64 = data['data'] as String?;

    String? localPath;
    if (b64 != null) {
      final bytes = base64Decode(b64);
      final ext = _extensionFromMime(mime, fallback: path.extension(name));
      final file = await _writeTempFileWithExt(
        bytes,
        ext: (type == 'file' || type == 'media' || type == 'voice')
            ? (ext.isEmpty ? '.bin' : ext)
            : ext,
      );
      localPath = file.path;
    }

    return {
      "id": id,
      "from": from,
      "to": to,
      "type": type,
      "name": name,
      "mime": mime,
      "time": time,
      "url": localPath,
    };
  }

  Future<Map<String, dynamic>?> _handleIncomingAudio(dynamic payload) async {
    if (payload is! Map) return null;

    // prevent local echo
    if (payload['from']?.toString() == _selfId) return null;

    final id = payload['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
    final from = payload['from'];
    final to = payload['to'];
    final type = payload['type'] ?? 'audio';
    final name = payload['name'] ?? 'voice.m4a';
    final mime = payload['mime'] ?? 'audio/mp4';
    final time = payload['time'] ?? '';
    final duration = payload['duration'] ?? 0;
    final wave = _toDoubleList(payload['wave']);

    final data = payload['data'];
    final Uint8List bytes = (data is String) ? base64Decode(data) : _toBytes(data);
    final file = await _writeTempFileWithExt(bytes, ext: '.m4a');

    return {
      'id': id,
      'from': from,
      'to': to,
      'name': name,
      'mime': mime,
      'time': time,
      'duration': duration,
      'bytes': bytes,
      'wave': wave,
      'type': type,
      'url': file.path,
    };
  }

  // Helpers
  String _extensionFromMime(String? mime, {String fallback = ''}) {
    if (mime == null || mime.isEmpty) {
      return fallback.isNotEmpty ? fallback : '.bin';
    }

    final m = mime.toLowerCase();
    const map = {
      // Images
      'image/jpeg': '.jpg',
      'image/jpg': '.jpg',
      'image/png': '.png',
      'image/gif': '.gif',
      'image/webp': '.webp',
      'image/heic': '.heic',

      // Videos (common)
      'video/mp4': '.mp4',
      'video/quicktime': '.mov',
      'video/x-matroska': '.mkv',
      'video/webm': '.webm',
      'video/3gpp': '.3gp',
      'video/3gpp2': '.3g2',
      'video/avi': '.avi',
      'video/x-msvideo': '.avi',

      // Audio
      'audio/aac': '.aac',
      'audio/mpeg': '.mp3',
      'audio/mp4': '.m4a',
      'audio/wav': '.wav',
      'audio/3gpp': '.3gp',
      'audio/ogg': '.ogg',
      'audio/webm': '.weba',
    };

    if (map.containsKey(m)) return map[m]!;

    if (m.startsWith('image/') || m.startsWith('video/') || m.startsWith('audio/')) {
      final e = m.split('/').last;
      return e == 'jpeg' ? '.jpg' : '.$e';
    }
    return fallback.isNotEmpty ? fallback : '.bin';
  }

  Future<File> _writeTempFileWithExt(List<int> bytes, {String ext = '.mp4'}) async {
    final dir = await Directory.systemTemp.createTemp('chat_media_');
    final file = File(path.join(dir.path, 'm_${DateTime.now().microsecondsSinceEpoch}$ext'));
    return file.writeAsBytes(bytes, flush: true);
  }

  Uint8List _toBytes(dynamic d) {
    if (d is Uint8List) return d;
    if (d is List) return Uint8List.fromList(d.cast<int>());
    if (d is ByteBuffer) return d.asUint8List();
    throw 'Unsupported audio file type: ${d.runtimeType}';
  }

  List<double> _toDoubleList(dynamic d) {
    if (d is List) return d.map((e) => (e as num).toDouble()).toList();
    return const [];
  }

  Future<Map<String, dynamic>> _materializeItem(Map item) async {
    final mime = item['mime']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    String? url = item['url']?.toString();
    final b64 = item['data'] as String?;

    if((url == null || url.isEmpty) && b64 != null && b64.isNotEmpty){
      final bytes = base64Decode(b64);
      final ext = _extensionFromMime(mime, fallback: path.extension(name));
      final file = await _writeTempFileWithExt(bytes, ext: ext.isEmpty ? '.bin' : ext);
      url = file.path;
    }
    return {
      'type': (item['type'] ?? 'media').toString(),
      'name': name,
      'mime': mime,
      'url': url,
    };
  }
}