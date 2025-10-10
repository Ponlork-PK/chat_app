import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class VoiceController extends GetxController{
  final record = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;

  final isRecording = false.obs;
  final second = 0.obs;
  final samples = <double>[].obs;
  final _cancelled = false.obs;
  DateTime? _start;
  String? _filePath;

  late final IO.Socket socket;

  final inComing = StreamController<Map<String, dynamic>>.broadcast();

  void wireIncoming(){
    socket.on('audio', (payloat){
      if(payloat is! Map) return;

      final bytes = _toBytes(payloat['data']);
      final wave = _toDoubleList(payloat['wave']);
      final id = payloat['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      final from = payloat['from'];
      final to = payloat['to'];
      final name = payloat['name'] ?? 'voice.m4a';
      final mime = payloat['mime'] ?? 'audio/mp4';
      final time = payloat['time'] ?? '';
      final duration = payloat['duration'] ?? 0;

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
      });
    });
  }

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
        numChannels: 0,
      ), 
      path: _filePath.toString(),
    );

    _ampSub = record.onAmplitudeChanged(const Duration(milliseconds: 60)).listen((a){
      final v = _mapDbToUnit(a.current);
      samples.add(v);
      if(samples.length > 48) samples.removeAt(0);
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
    if(_cancelled.value && used == null) return;

    final durationMs = DateTime.now().difference(_start!).inMilliseconds;
    final file = File(used.toString());
    if(!await file.exists()) return;

    final bytes = await file.readAsBytes();
    final nowIso = DateTime.now().toIso8601String();
    final name = 'vm_${DateTime.now().millisecondsSinceEpoch}.m4a';

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
    });

    socket.emit('audio', {
      'from': from,
      'to': to,
      'name': name,
      'mime': 'audio',
      'time': nowIso,
      'duration': durationMs,
      'wave': samples,
      'data': bytes,
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
