import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:chat_app/model/message.dart';
import 'package:chat_app/service/socket_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ChatController extends GetxController {

  final SocketService socketService = SocketService();
  final ScrollController scrollController = ScrollController();

  final threads = <String, RxList<Message>>{}.obs;

  final audioRecorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;

  final isRecording = false.obs;
  final elapsedSeconds = 0.obs;
  final waveformSamples = <double>[].obs;

  final _isCancelled = false.obs;
  static const int maxLiveBars = 26;

  DateTime? _recordStartAt;
  String? _recordFilePath;

  /// Stream of incoming audio payloads for UI to consume & render.
  final incomingAudioController = StreamController<Map<String, dynamic>>.broadcast();
  final incomingMediaController = StreamController<Map<String, dynamic>>.broadcast();

  late String myId;

  @override
  void onInit(){
    super.onInit();
    socketService.incomingMediaController.stream.listen(_onMediaReceived);
    socketService.incomingAudioController.stream.listen(_onAudioReceived);
  }

  String _threadKey(String a, String b) => (a.compareTo(b) <= 0) ? '$a-$b' : '$b-$a';

  RxList<Message> getThread(String senderId, String receiverId) {
    final key = _threadKey(senderId, receiverId);
    return threads.putIfAbsent(key, () => <Message>[].obs);
  }

  void appendMessage(String senderId, String receiverId, Message message) {
    getThread(senderId, receiverId).add(message);
  }

  void clearThread(String senderId, String receiverId) {
    getThread(senderId, receiverId).clear();
  }

  void setupSocket({required String myId}){
    this.myId = myId;
    socketService.initSocket(myId: myId);
  }

  void connectSafely(){
    socketService.connectIfNeeded();
  }

  void _onMediaReceived(Map<String, dynamic> data) {
    appendMessage(
      data['from'], 
      data['to'],
      Message(
        id: data['id'], 
        from: data['from'], 
        to: data['to'], 
        message: '', 
        sentByMe: data['from'], 
        time: data['time'],
        type: data['type'],
        url: data['url'],
        name: data['name'],
        mime: data['mime'],
      )
    );
  }

  void _onAudioReceived(Map<String, dynamic> data){
    incomingAudioController.add(data);
  }

  Future<void> pickAndSendMultipleMedia(String receiverId) async {
    final picks = await ImagePicker().pickMultipleMedia(
      imageQuality: 75,
      maxWidth: 1280,
      maxHeight: 1280,
    );

    if(picks.isEmpty) return;

    final items = <Map<String, dynamic>>[];

    DateTime now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    String peroid = hour >= 12 ? "PM" : "AM";

    String time = '$hour:${minute.toString().padLeft(2, '0')} $peroid';
    for(final x in picks){
      final file = File(x.path);
      if(!await file.exists()) continue;

      final mime = lookupMimeType(file.path) ?? _guessMimeByExt(file.path);
      final bytes = await file.readAsBytes();

      items.add({
        "type": "media",
        "url": file.path,
        "name": p.basename(file.path),
        "mime": mime,
        "data": base64Encode(bytes),
      });
    }

    if(items.isEmpty) return;

    final payload = {
      "from": myId,
      "to": receiverId,
      "time": time,
      "items": items,
    };

    socketService.socket.emitWithAck('media', payload, ack: (res){
      print('media ack: $res');
    });

    scrollToBottom();

  }

  String _guessMimeByExt(String path){
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.m4v':
        return 'video/x-m4v';
      case '.avi':
        return 'video/x-msvideo';
      case '.mkv':
        return 'video/x-matroska';
      case '.webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }

  void sendMessage({required String me, required String peer, required String text}) {
    DateTime now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    String peroid = hour >= 12 ? "PM" : "AM";

    String time = '$hour:${minute.toString().padLeft(2, '0')} $peroid';

    final offMsg = {
      "message": text,
      "text": text,
      "time": time,
      "sendByMe": me,
      "from": me,
    };

    appendMessage(me, peer, Message.fromJson(offMsg));

    if (socketService.isConnected.value && socketService.socket.connected) {
      var messageJson = {
        "from": me,
        "to": peer,
        "message": text,
        "text": text,
        "time": time,
        "sendByMe": me,
      };
      socketService.socket.emit('dm', messageJson);
      return;
    }
  }

  void scrollToBottom() {
    if (!scrollController.hasClients) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeIn,
      );
    });
  }

  // Voice message (hold to record)
  Future<void> startVoiceHold() async {
    if (!await audioRecorder.hasPermission()) return;

    waveformSamples.clear();
    elapsedSeconds.value = 0;
    _isCancelled.value = false;
    _recordStartAt = DateTime.now();

    _recordFilePath = await _tempM4aPath();

    await audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: _recordFilePath.toString(),
    );

    _ampSub = audioRecorder
        .onAmplitudeChanged(const Duration(milliseconds: 60))
        .listen((amp) {
      final v = _dbToUnit(amp.current);
      waveformSamples.add(v);
      if (waveformSamples.length > maxLiveBars) waveformSamples.removeAt(0);

      final s = DateTime.now().difference(_recordStartAt!).inSeconds;
      if (s != elapsedSeconds.value) elapsedSeconds.value = s;
    });

    isRecording.value = true;
  }

  void setCancelRecording(bool cancel) => _isCancelled.value = cancel;

  Future<void> endVoiceHold({required String from, required String to}) async {
    if (!isRecording.value) return;
    isRecording.value = false;

    await _ampSub?.cancel();
    final stopPath = await audioRecorder.stop();
    final usedPath = stopPath ?? _recordFilePath;
    if (_isCancelled.value || usedPath == null) return;

    final durationMs = DateTime.now().difference(_recordStartAt!).inMilliseconds;
    final file = File(usedPath.toString());
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final name = 'vm_${DateTime.now().millisecondsSinceEpoch}.m4a';

    DateTime now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    String peroid = hour >= 12 ? "PM" : "AM";

    String time = '$hour:${minute.toString().padLeft(2, '0')} $peroid';

    final tmpPath = await _tempM4aPath();
    await File(tmpPath).writeAsBytes(bytes, flush: true);

    // Push to local stream for UI
    incomingAudioController.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'from': from,
      'to': to,
      'name': name,
      'mime': 'audio/mp4',
      'time': time,
      'duration': durationMs,
      'wave': List<double>.from(waveformSamples),
      'bytes': bytes,
      'type': 'audio',
      'url': tmpPath,
    });

    // Send to server
    socketService.socket.emit('audio', {
      'from': from,
      'to': to,
      'name': name,
      'mime': 'audio/mp4',
      'time': time,
      'duration': durationMs,
      'wave': waveformSamples,
      'data': base64Encode(bytes),
      'type': 'audio',
    });
  }

  Future<String> _tempM4aPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/vm_${DateTime.now().microsecondsSinceEpoch}.m4a';
  }

  double _dbToUnit(double db) {
    final clamped = db.clamp(-60, 0.0);
    return math.pow(10, clamped / 20).toDouble();
  }

}
