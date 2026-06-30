import 'package:flutter/material.dart';

class LostSearchPage extends StatelessWidget {
  const LostSearchPage({super.key});

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
          '분실물 검색',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(
              Icons.search,
              size: 70,
              color: Color(0xFF7C3AED),
            ),
            const SizedBox(height: 20),
            const Text(
              '분실물 검색 화면',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '나중에 물품 분류, 물품명, 날짜, 지역 검색 기능을 연결할 화면입니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text('• 물품 분류 선택'),
                  Text('• 분실물명 또는 키워드 입력'),
                  Text('• 분실 일자 선택'),
                  Text('• 지역 선택'),
                  Text('• 검색 결과 화면 이동'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}