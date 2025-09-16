import 'package:chat_app/screens/select_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat App',
      theme: ThemeData(
        appBarTheme: AppBarThemeData(
          centerTitle: true,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 8,
          titleTextStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          actionsIconTheme: IconThemeData(size: 28,),
        ),
      ),
      home: SelectScreen(),
    );
  }
}
