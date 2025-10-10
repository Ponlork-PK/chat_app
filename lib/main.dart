import 'package:chat_app/controller/chat_controller.dart';
import 'package:chat_app/my_app.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(ChatController(), permanent: true);
  runApp(const MyApp());
}
