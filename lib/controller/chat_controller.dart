import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:chat_app/model/message.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:path/path.dart' as p;
import 'package:get/get.dart';

class ChatController extends GetxController {

  final ScrollController scrollController = ScrollController();

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
  late String myId;

  // audio part
  final record = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;

  final isRecording = false.obs;
  final second = 0.obs;
  final samples = <double>[].obs;
  final _cancelled = false.obs;
  static const liveMaxBars = 26;
  DateTime? _start;
  String? _filePath;

  final inComing = StreamController<Map<String, dynamic>>.broadcast();

  void initSocket({required String myId}){
    if(!_inited) {
      _inited = true;

      this.myId = myId;

      socket = IO.io(
        'http://10.10.77.191:3000',   // http://localhost:300010.10.77.237
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
        final id = (data['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString();
        final from = data['from']?.toString() ?? '';
        final to = data['to']?.toString() ?? '';
        final type = data['type']?.toString() ?? 'image';
        final name = data['name']?.toString() ?? '';
        final mime = data['mime']?.toString() ?? '';
        final time = data['time']?.toString() ?? '';
        final b64 = data['data'] as String?;

        String? _localPath;

        if(b64 != null) {
          final bytes = base64Decode(b64);
          if(type == 'file' || type == 'video' || type == 'voice'){
            final ext = _extensionForMime(mime, fallback: p.extension(name));
            final tmp = await _writeTempMedia(bytes, ext: ext.isEmpty ? '.bin' : ext);
            _localPath = tmp.path;
          } else {
            
            final tmp = await _writeTempMedia(bytes, ext: _extensionForMime(mime, fallback: p.extension(name)));
            _localPath = tmp.path;
          }
        }

        addDm(from, to, Message(
          id: id, 
          from: from, 
          to: to, 
          message: '', 
          sentByMe: from, 
          time: time,

          type: type,
          url: _localPath,
          name: name,
          mime: mime,
        ));
      });

      socket.on('audio', (payload) async {
        if(payload is! Map) return;

        // none duplicate
        if(payload['from']?.toString() == myId) return;

        // final bytes = _toBytes(payload['data']);
        final wave = _toDoubleList(payload['wave']);
        final id = payload['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
        final from = payload['from'];
        final to = payload['to'];
        final type = payload['type'] ?? 'audio';
        final name = payload['name'] ?? 'voice.m4a';
        final mime = payload['mime'] ?? 'audio/mp4';
        final time = payload['time'] ?? '';
        final duration = payload['duration'] ?? 0;

        final data = payload['data'];
        final Uint8List bytes = (data is String) ? base64Decode(data) : _toBytes(data);
        final file = await _writeTempMedia(bytes, ext: '.m4a');

        inComing.add({
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
        });
      });
      return;
    }

  }

  void connectSafely(){
    if(_inited && !socket.connected){
      try{ socket.connect(); } catch (_){}
    }
  }

  // ====================== Image and Video ======================
  Future<File?> _pickImageFromGallary() async {
    final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 75,
          maxWidth: 1280,
          maxHeight: 1280,
    );

    return image != null ? File(image.path) : null;
  }

  Future<File?> _pickImageFromCamera() async {
    final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 1920,
          maxHeight: 1920,
    );

    return image != null ? File(image.path) : null;
  }

  Future<File?> _pickVideoFromGallary() async {
    final XFile? video = await ImagePicker().pickVideo(
          source: ImageSource.gallery,
          maxDuration: Duration(minutes: 5),
    );
    return video != null ? File(video.path) : null;
  }

  Future<File?> _pickVideoFromCamera() async {
    final XFile? video = await ImagePicker().pickVideo(
          source: ImageSource.camera,
          maxDuration: Duration(minutes: 5),
    );
    return video != null ? File(video.path) : null;
  }

  Future<void> sendImageTo(String toId, {bool isFromCamera = false}) async {
    final file = isFromCamera ? await _pickImageFromCamera() : await _pickImageFromGallary();
    if(file == null) return;

    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(file.path) ?? 'image/jpeg';
    final name = p.basename(file.path);

    final payload = {
      "from": myId,
      "to": toId,
      "type": "image",
      "url": file.path,
      "name": name,
      "mime": mime,
      "data": base64Encode(bytes),
      "time": DateTime.now().toIso8601String(),
    };

    socket.emitWithAck('media', payload, ack: (res){
      print('Media ack: $res');
    });
    scrollToBottom();

  }

  Future<void> sendVideoTo(String toId, {bool isFromCamera = false }) async {
    final file = isFromCamera ? await _pickVideoFromCamera() : await _pickVideoFromGallary();
    if(file == null) return;

    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(file.path) ?? 'video/mp4';
    final name = p.basename(file.path);

    final payload = {
      "from": myId,
      "to": toId,
      "type": 'video',
      "url": file.path,
      "name": name,
      "mime": mime,
      "data": base64Encode(bytes),
      "time": DateTime.now().microsecondsSinceEpoch.toString(),
    };

    socket.emitWithAck('media', payload, ack: (res){
      print('Media ack: $res');
    });
    scrollToBottom();
  }

  String _extensionForMime(String? mime, {String fallback = ''}) {
    if (mime == null || mime.isEmpty) {
      return fallback.isNotEmpty ? fallback : '.bin';
    }

    // Normalize
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
      'video/quicktime': '.mov',      // IMPORTANT: iOS camera/gallery
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

    // Generic families
    if (m.startsWith('image/')) {
      final e = m.split('/').last;
      return e == 'jpeg' ? '.jpg' : '.$e';
    }
    if (m.startsWith('video/')) {
      final e = m.split('/').last;
      return '.$e';
    }
    if (m.startsWith('audio/')) {
      final e = m.split('/').last;
      return '.$e';
    }

    return fallback.isNotEmpty ? fallback : '.bin';
  }

  Future<File> _writeTempMedia(List<int> bytes, {String ext = '.mp4'}) async {
    final dir = await Directory.systemTemp.createTemp('chat_media_');
    final file = File(p.join(dir.path, 'm_${DateTime.now().microsecondsSinceEpoch}$ext'));

    return file.writeAsBytes(bytes, flush: true);
  }

  void scrollToBottom(){
    if(!scrollController.hasClients) return;
    Future.delayed(Duration(milliseconds: 500), (){
      scrollController.animateTo(
        scrollController.position.maxScrollExtent, 
        duration: Duration(milliseconds: 800), 
        curve: Curves.easeIn
      );
    });
  }

  // ====================== Audio ======================
  Future<void> startHold() async {
    if(!await record.hasPermission()) return;

    samples.clear();
    second.value = 0;
    _cancelled.value = false;
    _start = DateTime.now();

    _filePath = await _tempM4a();

    await record.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ), 
      path: _filePath.toString(),
    );

    _ampSub = record.onAmplitudeChanged(const Duration(milliseconds: 60)).listen((a){
      final v = _mapDbToUnit(a.current);
      samples.add(v);
      if(samples.length > liveMaxBars) samples.removeAt(0);
      final s = DateTime.now().difference(_start!).inSeconds;
      if(s != second.value) second.value = s;
    });
    
    isRecording.value = true;

  }

  // when user slide up to cancel
  void markCancel(bool cancel) => _cancelled.value = cancel;

  Future<void> endHold({required String from, required String to}) async {
    if(!isRecording.value) return;
    isRecording.value = false;

    await _ampSub?.cancel();
    final stopPath = await record.stop();
    final used = stopPath ?? _filePath;
    if(_cancelled.value || used == null) return;

    final durationMs = DateTime.now().difference(_start!).inMilliseconds;
    final file = File(used.toString());
    if(!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final nowIso = DateTime.now().toIso8601String();
    final name = 'vm_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final tmpPath = await _tempM4a();
    await File(tmpPath).writeAsBytes(bytes, flush: true);

    inComing.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'from': from,
      'to': to,
      'name': name,
      'mime': 'audio/mp4',
      'time': nowIso,
      'duration': durationMs,
      'wave': List<double>.from(samples),
      'bytes': bytes,
      'type': 'audio',
      'url': tmpPath,
    });

    socket.emit('audio', {
      'from': from,
      'to': to,
      'name': name,
      'mime': 'audio/mp4',
      'time': nowIso,
      'duration': durationMs,
      'wave': samples,
      'data': base64Encode(bytes),
      'type': 'audio',
    });
  }

  Future<String> _tempM4a() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/vm_${DateTime.now().microsecondsSinceEpoch}.m4a';
  }

  double _mapDbToUnit(double db){
    final clamped = db.clamp(-60, 0.0);
    return math.pow(10, clamped / 20).toDouble();
  }

  Uint8List _toBytes(dynamic d){
    if(d is Uint8List) return d;
    if(d is List) return Uint8List.fromList(d.cast<int>());
    if(d is ByteBuffer) return d.asUint8List();
    throw 'Unsupported audio file type: ${d.runtimeType}';
  }

  List _toDoubleList(dynamic d){
    if(d is List) return d.map((e) => (e as num).toDouble()).toList();
    return const [];
  }

}

