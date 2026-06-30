import 'package:flutter/material.dart';

class FoundRegisterPage extends StatelessWidget {
  const FoundRegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text(
          '습득물 등록',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.add_circle_outline,
              size: 70,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(height: 20),
            const Text(
              '습득물 등록 화면',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '나중에 사진 업로드, AI 자동 분류, 위치 등록, 상세 정보 입력 기능을 연결할 화면입니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '추후 구현 예정',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  Text('• 습득물 이미지 업로드'),
                  Text('• AI 자동 분류'),
                  Text('• 습득 위치 선택'),
                  Text('• 습득 일자 입력'),
                  Text('• 연락처 및 상세 설명 입력'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
