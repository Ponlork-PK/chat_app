import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chat_app/model/message.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatController extends GetxController {

  final ScrollController scrollController = ScrollController();

  final threads = <String, RxList<Message>>{}.obs;

  late final IO.Socket socket;
  final isConnected = false.obs;
  bool _initialized = false;
  late String _selfId;

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

  String _threadKey(String a, String b) =>
      (a.compareTo(b) <= 0) ? '$a-$b' : '$b-$a';

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

  void setupSocket({required String myId}) {
    if (_initialized) return;
    _initialized = true;
    _selfId = myId;

    socket = IO.io(
      'http://localhost:3000',
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

    socket.on('media', _handleIncomingMedia);
    socket.on('audio', _handleIncomingAudio);
  }

  void connectIfNeeded() {
    if (_initialized && !socket.connected) {
      try {
        socket.connect();
      } catch (_) {}
    }
  }

  Future<void> _handleIncomingMedia(dynamic data) async {
    if (data is! Map) return;

    final id = (data['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString();
    final from = data['from']?.toString() ?? '';
    final to = data['to']?.toString() ?? '';
    final type = data['type']?.toString() ?? 'image';
    final name = data['name']?.toString() ?? '';
    final mime = data['mime']?.toString() ?? '';
    final time = data['time']?.toString() ?? '';
    final b64 = data['data'] as String?;

    String? localPath;
    if (b64 != null) {
      final bytes = base64Decode(b64);
      final ext = _extensionFromMime(mime, fallback: p.extension(name));
      final file = await _writeTempFileWithExt(
        bytes,
        ext: (type == 'file' || type == 'video' || type == 'voice')
            ? (ext.isEmpty ? '.bin' : ext)
            : ext,
      );
      localPath = file.path;
    }

    appendMessage(
      from,
      to,
      Message(
        id: id,
        from: from,
        to: to,
        message: '',
        sentByMe: from,
        time: time,
        type: type,
        url: localPath,
        name: name,
        mime: mime,
      ),
    );
  }

  Future<void> _handleIncomingAudio(dynamic payload) async {
    if (payload is! Map) return;

    // prevent local echo
    if (payload['from']?.toString() == _selfId) return;

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

    incomingAudioController.add({
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

  Future<void> sendImageTo(String receiverId, {bool fromCamera = false}) async {
    final file = fromCamera ? await _pickImageFromCamera() : await _pickImageFromGallery();
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final mime = lookupMimeType(file.path) ?? 'image/jpeg';
    final name = p.basename(file.path);

    final payload = {
      'from': _selfId,
      'to': receiverId,
      'type': 'image',
      'url': file.path,
      'name': name,
      'mime': mime,
      'data': base64Encode(bytes),
      'time': DateTime.now().toIso8601String(),
    };

    socket.emitWithAck('media', payload, ack: (res) {
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
      'from': _selfId,
      'to': receiverId,
      'type': 'video',
      'url': file.path,
      'name': name,
      'mime': mime,
      'data': base64Encode(bytes),
      'time': DateTime.now().microsecondsSinceEpoch.toString(),
    };

    socket.emitWithAck('media', payload, ack: (res) {
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
    socket.emit('audio', {
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
    final file = File(p.join(dir.path, 'm_${DateTime.now().microsecondsSinceEpoch}$ext'));
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<String> _tempM4aPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/vm_${DateTime.now().microsecondsSinceEpoch}.m4a';
  }

  double _dbToUnit(double db) {
    final clamped = db.clamp(-60, 0.0);
    return math.pow(10, clamped / 20).toDouble();
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
}
