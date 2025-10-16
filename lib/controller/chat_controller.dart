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

  Future<File?> _pickImageFromGallery() async {
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

  Future<File?> _pickVideoFromGallery() async {
    final XFile? video = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    return video != null ? File(video.path) : null;
  }

  Future<File?> _pickVideoFromCamera() async {
    final XFile? video = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 5),
    );
    return video != null ? File(video.path) : null;
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

  Future<void> sendImageTo(String receiverId, {bool fromCamera = false}) async {
    final file = fromCamera ? await _pickImageFromCamera() : await _pickImageFromGallery();
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(file.path) ?? 'image/jpeg';
    final name = p.basename(file.path);

    final payload = {
      'from': myId,
      'to': receiverId,
      'type': 'image',
      'url': file.path,
      'name': name,
      'mime': mime,
      'data': base64Encode(bytes),
      'time': DateTime.now().toIso8601String(),
    };

    socketService.socket.emitWithAck('media', payload, ack: (res) {
      print('Media ack: $res');
    });

    scrollToBottom();
  }

  Future<void> sendVideoTo(String receiverId, {bool fromCamera = false}) async {
    final file = fromCamera ? await _pickVideoFromCamera() : await _pickVideoFromGallery();
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(file.path) ?? 'video/mp4';
    final name = p.basename(file.path);

    final payload = {
      'from': myId,
      'to': receiverId,
      'type': 'video',
      'url': file.path,
      'name': name,
      'mime': mime,
      'data': base64Encode(bytes),
      'time': DateTime.now().microsecondsSinceEpoch.toString(),
    };

    socketService.socket.emitWithAck('media', payload, ack: (res) {
      print('Media ack: $res');
    });

    scrollToBottom();
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
    final nowIso = DateTime.now().toIso8601String();
    final name = 'vm_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final tmpPath = await _tempM4aPath();
    await File(tmpPath).writeAsBytes(bytes, flush: true);

    // Push to local stream for UI
    incomingAudioController.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'from': from,
      'to': to,
      'name': name,
      'mime': 'audio/mp4',
      'time': nowIso,
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
      'time': nowIso,
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
