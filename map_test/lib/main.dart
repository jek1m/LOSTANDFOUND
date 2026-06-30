import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

import 'pages/main_map_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final kakaoKey = dotenv.env['KAKAO_JAVASCRIPT_KEY'];

  if (kakaoKey == null || kakaoKey.isEmpty) {
    throw Exception('KAKAO_JAVASCRIPT_KEY가 .env 파일에 없습니다.');
  }

  AuthRepository.initialize(appKey: kakaoKey);

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
