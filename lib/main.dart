import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'getx_video_editor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'AIGC 视频编辑器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const GetxVideoEditor(),
      // GetX 配置
      defaultTransition: Transition.fade,
      debugShowCheckedModeBanner: false,
    );
  }
}