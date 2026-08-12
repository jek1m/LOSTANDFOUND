import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../lost_models/lost_item.dart';
import 'found_item_edit_page.dart';

class FoundItemManagePage extends StatefulWidget {
  const FoundItemManagePage({
    super.key,
    required this.password,
  });

  final String password;

  @override
  State<FoundItemManagePage> createState() => _FoundItemManagePageState();
}

class _FoundItemManagePageState extends State<FoundItemManagePage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<LostItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('found_items')
          .where('password', isEqualTo: widget.password)
          .where('polUse', isEqualTo: 'user')
          .get(const GetOptions(source: Source.server));

      final items = snapshot.docs
          .map(LostItem.fromDoc)
          .where((item) => item.atcId.startsWith('S'))
          .toList()
        ..sort((a, b) {
          final aDate = a.fdYmd ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.fdYmd ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

      if (!mounted) return;

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.code == 'permission-denied'
            ? '등록물에 접근할 권한이 없습니다. Firestore 보안 규칙을 확인해 주세요.'
            : '등록물을 불러오지 못했습니다. (${error.code})';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '등록물을 불러오지 못했습니다.';
      });
    }
  }

  Future<void> _openItem(LostItem item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FoundItemEditPage(
          item: item,
          password: widget.password,
        ),
      ),
    );

    if (changed == true && mounted) {
      await _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          '수정 / 삭제',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _MessageView(
        icon: Icons.error_outline,
        title: '목록을 불러오지 못했습니다',
        message: _errorMessage!,
        action: OutlinedButton(
          onPressed: _loadItems,
          child: const Text('다시 시도'),
        ),
      );
    }

    if (_items.isEmpty) {
      return const _MessageView(
        icon: Icons.inventory_2_outlined,
        title: '일치하는 등록물이 없습니다',
        message: '입력한 비밀번호로 등록된 습득물을 찾지 못했습니다.',
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Text(
            '등록물 ${_items.length}건',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadItems,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _items[index];
                return _ManageItemCard(
                  item: item,
                  onTap: () => _openItem(item),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ManageItemCard extends StatelessWidget {
  const _ManageItemCard({
    required this.item,
    required this.onTap,
  });

  final LostItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumbnail(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.fdPrdtNm,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        if (item.prdtClNmMg != null)
                          _categoryBadge(item.prdtClNmMg!),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      Icons.calendar_today_outlined,
                      '습득일 ${_formatDate(item.fdYmd)}',
                    ),
                    const SizedBox(height: 4),
                    _infoRow(Icons.location_on_outlined, _locationText),
                    if (item.fndDescription != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        item.fndDescription!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _locationText {
    final parts = <String>[
      if (item.sido != null) item.sido!,
      if (item.sigungu != null) item.sigungu!,
      if (item.eupmyeondong != null) item.eupmyeondong!,
      if (item.fndPlace != null) item.fndPlace!,
    ];

    return parts.isEmpty ? '지역 정보 없음' : parts.join(' ');
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '날짜 없음';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Widget _thumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 76,
        height: 76,
        color: const Color(0xFFEAF2FF),
        child: item.fdFilePathImg == null
            ? const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF2563EB),
                size: 32,
              )
            : Image.network(
                item.fdFilePathImg!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Color(0xFF9CA3AF),
                ),
              ),
      ),
    );
  }

  Widget _categoryBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        category,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF374151),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF6B7280)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
