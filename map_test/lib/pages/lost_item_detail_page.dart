import 'package:flutter/material.dart';

import '../lost_models/lost_item.dart';

class LostItemDetailPage extends StatelessWidget {
  const LostItemDetailPage({super.key, required this.item});

  final LostItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text(
          '분실물 상세',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            _ItemImage(item: item),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_category.isNotEmpty) ...[
                    _CategoryBadge(text: _category),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    item.fdPrdtNm,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ManagementNumberCard(atcId: item.atcId),
                  const SizedBox(height: 14),
                  _InfoCard(
                    rows: [
                      _InfoRowData(
                        icon: Icons.sell_outlined,
                        iconColor: const Color(0xFF5B7CFA),
                        label: '분실물 종류',
                        value: _category.isEmpty ? '정보 없음' : _category,
                      ),
                      _InfoRowData(
                        icon: Icons.calendar_today_outlined,
                        iconColor: const Color(0xFF22C55E),
                        label: '습득일자',
                        value: _formatDate(item.fdYmd),
                      ),
                      _InfoRowData(
                        icon: Icons.location_on_outlined,
                        iconColor: const Color(0xFFEF4444),
                        label: '습득장소',
                        value: _location,
                      ),
                      _InfoRowData(
                        icon: Icons.phone_outlined,
                        iconColor: const Color(0xFFF59E0B),
                        label: '연락처',
                        value: item.tel ?? '정보 없음',
                      ),
                    ],
                  ),
                  if (item.fndDescription != null) ...[
                    const SizedBox(height: 14),
                    _DescriptionCard(description: item.fndDescription!),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _category => [
    item.prdtClNmMg,
    item.prdtClNmMn,
  ].whereType<String>().where((value) => value.isNotEmpty).join('/');

  String get _location {
    final parts = [
      item.sido,
      item.sigungu,
      item.eupmyeondong,
      item.fndPlace,
    ].whereType<String>().where((value) => value.isNotEmpty).toList();
    return parts.isEmpty ? '정보 없음' : parts.join(' ');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '정보 없음';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _ItemImage extends StatelessWidget {
  const _ItemImage({required this.item});

  final LostItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.fdFilePathImg;
    return AspectRatio(
      aspectRatio: 1.35,
      child: Container(
        color: const Color(0xFFEFF4FA),
        child: imageUrl == null
            ? const Center(
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 68,
                  color: Color(0xFF94A3B8),
                ),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 58,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFDC4C55),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ManagementNumberCard extends StatelessWidget {
  const _ManagementNumberCard({required this.atcId});

  final String atcId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Row(
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFF1F5F9),
            child: Icon(Icons.tag, size: 18, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '분실물 관리번호',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                atcId,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              '습득 정보',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          const Divider(height: 1),
          for (var index = 0; index < rows.length; index++) ...[
            _InfoRow(data: rows[index]),
            if (index != rows.length - 1) const Divider(height: 1, indent: 54),
          ],
        ],
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.data});

  final _InfoRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: data.iconColor.withValues(alpha: 0.1),
            child: Icon(data.icon, size: 16, color: data.iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '상세 설명',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

final BoxDecoration _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: const Color(0xFFE2E8F0)),
);
