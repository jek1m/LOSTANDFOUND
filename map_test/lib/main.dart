import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'pages/main_map_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await dotenv.load(fileName: '.env');

  final kakaoKey = dotenv.env['KAKAO_JAVASCRIPT_KEY'];

  if (kakaoKey == null || kakaoKey.isEmpty) {
    throw Exception('KAKAO_JAVASCRIPT_KEY가 .env 파일에 없습니다.');
  }

  AuthRepository.initialize(appKey: kakaoKey);

  // 상단 상태바 + 하단 내비게이션 바 숨김
  // 화면 가장자리에서 스와이프하면 잠깐 나타남
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainMapPage(),
    );
  }
}