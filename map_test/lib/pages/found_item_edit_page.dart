import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

import '../lost_models/lost_item.dart';

class FoundItemEditPage extends StatefulWidget {
  const FoundItemEditPage({
    super.key,
    required this.item,
    required this.password,
  });

  final LostItem item;
  final String password;

  @override
  State<FoundItemEditPage> createState() => _FoundItemEditPageState();
}

class _FoundItemEditPageState extends State<FoundItemEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _itemNameController;
  late final TextEditingController _contactController;
  late final TextEditingController _descriptionController;

  static const _categories = <String>[
    '가방',
    '귀금속',
    '도서용품',
    '서류',
    '산업용품',
    '쇼핑백',
    '스포츠용품',
    '악기',
    '유가증권',
    '의류',
    '자동차',
    '전자기기',
    '지갑',
    '증명서',
    '컴퓨터',
    '카드',
    '현금',
    '휴대폰',
    '기타물품',
  ];

  // 최초 등록 화면과 동일한 지역 선택 목록
  static const _regions = <String>[
    '서울',
    '경기',
    '인천',
    '강원',
    '충북',
    '충남',
    '전북',
    '전남',
    '경북',
  ];

  static const _districts = <String>[
    '강남구',
    '강동구',
    '강북구',
    '강서구',
    '관악구',
    '광진구',
    '구로구',
    '마포구',
    '서초구',
    '송파구',
  ];

  late String _selectedCategory;
  late DateTime _foundDate;

  late bool _useMapLocation;
  late String _selectedRegion;
  late String _selectedDistrict;
  LatLng? _selectedLocationLatLng;
  String? _mapLocationLabel;
  String _selectedSido = '';
  String _selectedSigungu = '';
  String _selectedEupmyeondong = '';
  bool _locationChanged = false;

  XFile? _newImage;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    _itemNameController = TextEditingController(text: widget.item.fdPrdtNm);
    _contactController = TextEditingController(text: widget.item.tel ?? '');
    _descriptionController = TextEditingController(
      text: widget.item.fndDescription ?? '',
    );

    final category = widget.item.prdtClNmMg;
    _selectedCategory = _categories.contains(category) ? category! : '기타물품';
    _foundDate = widget.item.fdYmd ?? DateTime.now();

    final hasCoordinates =
        widget.item.latitude != null && widget.item.longitude != null;
    _useMapLocation = hasCoordinates;
    _selectedLocationLatLng = hasCoordinates
        ? LatLng(widget.item.latitude!, widget.item.longitude!)
        : null;
    _selectedSido = widget.item.sido?.trim() ?? '';
    _selectedSigungu = widget.item.sigungu?.trim() ?? '';
    _selectedEupmyeondong = widget.item.eupmyeondong?.trim() ?? '';
    _mapLocationLabel = _existingLocationLabel();

    _selectedRegion = _shortSido(_selectedSido);
    if (!_regions.contains(_selectedRegion)) {
      _selectedRegion = '서울';
    }
    _selectedDistrict = _selectedSigungu.isNotEmpty
        ? _selectedSigungu
        : '강남구';
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _contactController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _foundDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      setState(() => _foundDate = picked);
    }
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image != null && mounted) {
      setState(() => _newImage = image);
    }
  }

  Future<void> _pickLocation() async {
    final selected = await Navigator.push<_EditLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => _FoundItemLocationEditPage(
          initialLocation: _selectedLocationLatLng,
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _useMapLocation = true;
        _selectedLocationLatLng = selected.latLng;
        _mapLocationLabel = selected.label;
        _selectedSido = selected.sido;
        _selectedSigungu = selected.sigungu;
        _selectedEupmyeondong = selected.eupmyeondong;
        _locationChanged = true;
      });
    }
  }

  String _existingLocationLabel() {
    final place = widget.item.fndPlace?.trim() ?? '';
    if (place.isNotEmpty && !_looksLikeCoordinates(place)) {
      return place;
    }

    final regionLabel = _regionLabel(
      widget.item.sido?.trim() ?? '',
      widget.item.sigungu?.trim() ?? '',
      widget.item.eupmyeondong?.trim() ?? '',
    );
    if (regionLabel.isNotEmpty) {
      return regionLabel;
    }

    return '지도에서 선택한 위치';
  }

  bool _looksLikeCoordinates(String value) {
    return RegExp(
      r'^\s*-?\d{1,3}(?:\.\d+)?\s*,\s*-?\d{1,3}(?:\.\d+)?\s*$',
    ).hasMatch(value);
  }

  String _regionLabel(String sido, String sigungu, String eupmyeondong) {
    return [
      sido,
      sigungu,
      eupmyeondong,
    ].where((value) => value.trim().isNotEmpty).join(' ');
  }

  String _normalizeSido(String value) {
    const sidoMap = {
      '서울': '서울특별시',
      '경기': '경기도',
      '인천': '인천광역시',
      '강원': '강원특별자치도',
      '충북': '충청북도',
      '충남': '충청남도',
      '전북': '전북특별자치도',
      '전남': '전라남도',
      '경북': '경상북도',
    };
    return sidoMap[value] ?? value;
  }

  String _shortSido(String value) {
    const shortMap = {
      '서울특별시': '서울',
      '경기도': '경기',
      '인천광역시': '인천',
      '강원특별자치도': '강원',
      '강원도': '강원',
      '충청북도': '충북',
      '충청남도': '충남',
      '전북특별자치도': '전북',
      '전라북도': '전북',
      '전라남도': '전남',
      '경상북도': '경북',
    };
    return shortMap[value] ?? value;
  }

  List<String> get _districtItems {
    if (_districts.contains(_selectedDistrict)) {
      return _districts;
    }
    return [_selectedDistrict, ..._districts];
  }

  void _changeLocationMode(bool useMap) {
    if (_useMapLocation == useMap) {
      return;
    }

    setState(() {
      _useMapLocation = useMap;
      _locationChanged = true;
    });
  }

  Future<void> _save() async {
    if (_isSaving || _isDeleting) return;
    if (!_formKey.currentState!.validate()) return;

    if (!widget.item.isAppRegistered || !widget.item.atcId.startsWith('S')) {
      _showMessage('사용자가 등록한 습득물만 수정할 수 있습니다.');
      return;
    }

    setState(() => _isSaving = true);

    Reference? newImageRef;
    String? newImageUrl;

    try {
      if (_newImage != null) {
        final bytes = await _newImage!.readAsBytes().timeout(
          const Duration(seconds: 15),
        );
        final extension = _imageExtension(_newImage!.name);

        newImageRef = FirebaseStorage.instance
            .ref()
            .child('found_items')
            .child(widget.item.atcId)
            .child('main.$extension');

        final upload = await newImageRef
            .putData(
              bytes,
              SettableMetadata(
                contentType: _newImage!.mimeType ?? _contentType(extension),
                customMetadata: {
                  'atcId': widget.item.atcId,
                  'polUse': 'user',
                },
              ),
            )
            .timeout(const Duration(seconds: 30));

        newImageUrl = await upload.ref
            .getDownloadURL()
            .timeout(const Duration(seconds: 15));
      }

      final updateData = <String, dynamic>{
        'fdPrdtNm': _itemNameController.text.trim(),
        'prdtClNmMg': _selectedCategory,
        'prdtClNmMn': '',
        'fndDescription': _descriptionController.text.trim(),
        'fdYmd': _formatDate(_foundDate),
        'tel': _contactController.text.trim(),
      };

      if (newImageUrl != null) {
        updateData['fdFilePathImg'] = newImageUrl;
      }

      // 위치는 텍스트 입력으로 받지 않는다. 최초 등록과 동일하게
      // 지도 선택 또는 지역 선택 결과만 저장한다.
      if (_locationChanged) {
        if (_useMapLocation) {
          final latLng = _selectedLocationLatLng;
          final label = _mapLocationLabel?.trim() ?? '';
          if (latLng == null || label.isEmpty) {
            throw StateError('지도에서 습득 위치를 선택해 주세요.');
          }

          updateData.addAll({
            'fndPlace': label,
            'latitude': latLng.latitude,
            'longitude': latLng.longitude,
            'geohash': _encodeGeohash(
              latLng.latitude,
              latLng.longitude,
              precision: 8,
            ),
            'sido': _selectedSido,
            'sigungu': _selectedSigungu,
            'eupmyeondong': _selectedEupmyeondong,
          });
        } else {
          final sido = _normalizeSido(_selectedRegion);
          final district = _selectedDistrict.trim();
          if (district.isEmpty) {
            throw StateError('지역을 선택해 주세요.');
          }

          updateData.addAll({
            'fndPlace': '$sido $district',
            'latitude': null,
            'longitude': null,
            'geohash': '',
            'sido': sido,
            'sigungu': district,
            'eupmyeondong': '',
          });
        }
      }

      final docRef = FirebaseFirestore.instance
          .collection('found_items')
          .doc(widget.item.atcId);

      final snapshot = await docRef.get(const GetOptions(source: Source.server));
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('수정할 등록물을 찾지 못했습니다.');
      }

      if (data['polUse'] != 'user' || data['password'] != widget.password) {
        throw StateError('수정 권한을 확인하지 못했습니다.');
      }

      await docRef.update(updateData).timeout(const Duration(seconds: 20));

      final oldImageUrl = widget.item.fdFilePathImg;
      if (newImageRef != null && oldImageUrl != null && oldImageUrl.isNotEmpty) {
        try {
          final oldRef = FirebaseStorage.instance.refFromURL(oldImageUrl);
          if (oldRef.fullPath != newImageRef.fullPath) {
            await oldRef.delete().timeout(const Duration(seconds: 10));
          }
        } catch (_) {
          // 새 정보 저장은 끝났으므로 이전 이미지 정리 실패는 수정 성공을 막지 않는다.
        }
      }

      if (!mounted) return;
      _showMessage('수정되었습니다.');
      Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      if (newImageRef != null && newImageUrl != null) {
        try {
          await newImageRef.delete().timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
      _showMessage('수정 중 오류가 발생했습니다. (${error.code})');
    } catch (error) {
      if (newImageRef != null && newImageUrl != null) {
        try {
          await newImageRef.delete().timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
      _showMessage('수정 중 오류가 발생했습니다: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (_isSaving || _isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('습득물 삭제'),
        content: const Text('이 등록물을 삭제하시겠습니까?\n삭제한 데이터는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('found_items')
          .doc(widget.item.atcId);

      final snapshot = await docRef.get(const GetOptions(source: Source.server));
      final data = snapshot.data();

      if (!snapshot.exists || data == null) {
        throw StateError('삭제할 등록물을 찾지 못했습니다.');
      }

      if (data['polUse'] != 'user' || data['password'] != widget.password) {
        throw StateError('삭제 권한을 확인하지 못했습니다.');
      }

      final imageUrl = data['fdFilePathImg'];
      if (imageUrl is String && imageUrl.trim().isNotEmpty) {
        try {
          await FirebaseStorage.instance
              .refFromURL(imageUrl)
              .delete()
              .timeout(const Duration(seconds: 15));
        } on FirebaseException catch (error) {
          if (error.code != 'object-not-found') rethrow;
        }
      }

      await docRef.delete().timeout(const Duration(seconds: 20));

      if (!mounted) return;
      _showMessage('삭제되었습니다.');
      Navigator.pop(context, true);
    } on FirebaseException catch (error) {
      _showMessage('삭제 중 오류가 발생했습니다. (${error.code})');
    } catch (error) {
      _showMessage('삭제 중 오류가 발생했습니다: $error');
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isSaving || _isDeleting;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          '습득물 수정 / 삭제',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _imageSection(),
            const SizedBox(height: 20),
            _label('습득물명'),
            TextFormField(
              controller: _itemNameController,
              decoration: _inputDecoration('습득물명을 입력해 주세요.'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? '습득물명을 입력해 주세요.'
                  : null,
            ),
            const SizedBox(height: 18),
            _label('분류'),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: _inputDecoration('분류'),
              items: _categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
            ),
            const SizedBox(height: 18),
            _label('습득일'),
            InkWell(
              onTap: busy ? null : _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: _inputDecoration('습득일'),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(_formatDate(_foundDate)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _label('습득 위치'),
            _EditSegmentedLocationControl(
              useMapLocation: _useMapLocation,
              onChanged: busy ? (_) {} : _changeLocationMode,
            ),
            const SizedBox(height: 10),
            if (_useMapLocation)
              _EditLocationButton(
                text: _mapLocationLabel ?? '지도에서 위치를 선택해 주세요',
                selected: _selectedLocationLatLng != null,
                onTap: busy ? () {} : _pickLocation,
              )
            else ...[
              _EditSelectBox(
                value: _selectedRegion,
                items: _regions,
                enabled: !busy,
                onChanged: (value) {
                  setState(() {
                    _selectedRegion = value;
                    _selectedDistrict = _districts.first;
                    _locationChanged = true;
                  });
                },
              ),
              const SizedBox(height: 8),
              _EditSelectBox(
                value: _selectedDistrict,
                items: _districtItems,
                enabled: !busy,
                onChanged: (value) {
                  setState(() {
                    _selectedDistrict = value;
                    _locationChanged = true;
                  });
                },
              ),
            ],
            const SizedBox(height: 18),
            _label('연락처'),
            TextFormField(
              controller: _contactController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration('연락처를 입력해 주세요.'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? '연락처를 입력해 주세요.'
                  : null,
            ),
            const SizedBox(height: 18),
            _label('상세 설명'),
            TextFormField(
              controller: _descriptionController,
              minLines: 4,
              maxLines: 7,
              decoration: _inputDecoration('습득물에 대한 설명을 입력해 주세요.'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: busy ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('수정 저장'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: busy ? null : _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                ),
                icon: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: const Text('삭제'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _imageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('사진'),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1.5,
            child: Container(
              color: const Color(0xFFEAF2FF),
              child: _newImage != null
                  ? FutureBuilder<Widget>(
                      future: _xFilePreview(_newImage!),
                      builder: (context, snapshot) =>
                          snapshot.data ??
                          const Center(child: CircularProgressIndicator()),
                    )
                  : widget.item.fdFilePathImg != null
                      ? Image.network(
                          widget.item.fdFilePathImg!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 52,
                            color: Color(0xFF2563EB),
                          ),
                        ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isSaving || _isDeleting ? null : _pickImage,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('사진 변경'),
        ),
      ],
    );
  }

  Future<Widget> _xFilePreview(XFile file) async {
    final bytes = await file.readAsBytes();
    return Image.memory(bytes, fit: BoxFit.cover);
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  String _imageExtension(String fileName) {
    final lowerName = fileName.toLowerCase().trim();
    final extension = lowerName.contains('.') ? lowerName.split('.').last : 'jpg';
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    return allowed.contains(extension) ? extension : 'jpg';
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  String _encodeGeohash(
    double latitude,
    double longitude, {
    int precision = 8,
  }) {
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    const bits = [16, 8, 4, 2, 1];

    final latitudeInterval = [-90.0, 90.0];
    final longitudeInterval = [-180.0, 180.0];
    final result = StringBuffer();

    var bitIndex = 0;
    var characterValue = 0;
    var useLongitude = true;

    while (result.length < precision) {
      if (useLongitude) {
        final midpoint = (longitudeInterval[0] + longitudeInterval[1]) / 2;
        if (longitude >= midpoint) {
          characterValue |= bits[bitIndex];
          longitudeInterval[0] = midpoint;
        } else {
          longitudeInterval[1] = midpoint;
        }
      } else {
        final midpoint = (latitudeInterval[0] + latitudeInterval[1]) / 2;
        if (latitude >= midpoint) {
          characterValue |= bits[bitIndex];
          latitudeInterval[0] = midpoint;
        } else {
          latitudeInterval[1] = midpoint;
        }
      }

      useLongitude = !useLongitude;

      if (bitIndex < 4) {
        bitIndex++;
      } else {
        result.write(base32[characterValue]);
        bitIndex = 0;
        characterValue = 0;
      }
    }

    return result.toString();
  }
}

class _EditLocation {
  const _EditLocation({
    required this.latLng,
    required this.label,
    required this.sido,
    required this.sigungu,
    required this.eupmyeondong,
  });

  final LatLng latLng;
  final String label;
  final String sido;
  final String sigungu;
  final String eupmyeondong;
}

class _FoundItemLocationEditPage extends StatefulWidget {
  const _FoundItemLocationEditPage({required this.initialLocation});

  final LatLng? initialLocation;

  @override
  State<_FoundItemLocationEditPage> createState() =>
      _FoundItemLocationEditPageState();
}

class _FoundItemLocationEditPageState extends State<_FoundItemLocationEditPage> {
  KakaoMapController? _mapController;
  LatLng? _selectedCenter;
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  bool _isResolvingAddress = false;
  bool _isPreviewResolving = false;
  String? _locationMessage;
  String? _selectedDisplayLabel;
  _EditRegionSelection _selectedRegionInfo = _EditRegionSelection.empty;
  Timer? _previewDebounce;

  @override
  void initState() {
    super.initState();
    _selectedCenter = widget.initialLocation;
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    if (mounted) {
      setState(() {
        _isLoadingLocation = true;
        _locationMessage = null;
      });
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
          _locationMessage =
              '위치 서비스가 꺼져 있습니다. 위치 서비스를 켜고 다시 시도해 주세요.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
          _locationMessage = '위치 권한이 거부되었습니다. 위치 권한을 허용해 주세요.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isLoadingLocation = false;
          _locationMessage = '설정에서 위치 권한을 허용해 주세요.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _currentLocation = latLng;
        _selectedCenter = widget.initialLocation ?? latLng;
        _isLoadingLocation = false;
      });

      if (widget.initialLocation == null) {
        _mapController?.setCenter(latLng);
        _mapController?.setLevel(3);
      }

      final center = _selectedCenter;
      if (center != null && _mapController != null) {
        await _updateSelectionPreview(center);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _locationMessage = '현재 위치를 불러올 수 없습니다. 잠시 후 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _moveToCurrentLocation() async {
    if (_currentLocation == null) {
      await _loadCurrentLocation();
      return;
    }

    _mapController?.setCenter(_currentLocation!);
    setState(() => _selectedCenter = _currentLocation!);
    await _updateSelectionPreview(_currentLocation!);
  }

  void _onCameraIdle(LatLng latLng) {
    setState(() {
      _selectedCenter = latLng;
      _isPreviewResolving = true;
      _selectedDisplayLabel = null;
    });

    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 350), () {
      _updateSelectionPreview(latLng);
    });
  }

  Future<void> _updateSelectionPreview(LatLng latLng) async {
    if (!mounted) return;

    setState(() => _isPreviewResolving = true);

    final addressFuture = _resolveAddress(latLng);
    final regionFuture = _resolveRegion(latLng);
    final address = await addressFuture;
    final region = await regionFuture;

    if (!mounted || _selectedCenter != latLng) return;

    setState(() {
      _selectedRegionInfo = region;
      _selectedDisplayLabel = _bestLocationLabel(address, region);
      _isPreviewResolving = false;
    });
  }

  Future<void> _confirmLocation() async {
    if (_isResolvingAddress) return;

    setState(() => _isResolvingAddress = true);

    try {
      final controller = _mapController;
      final selectedCenter = _selectedCenter;
      if (controller == null && selectedCenter == null) {
        return;
      }

      final center = controller == null
          ? selectedCenter!
          : await controller
                .getCenter()
                .timeout(
                  const Duration(seconds: 2),
                  onTimeout: () => selectedCenter!,
                )
                .catchError((_) => selectedCenter!);

      final addressFuture = _resolveAddress(center);
      final regionFuture = _resolveRegion(center);
      final address = await addressFuture;
      final region = await regionFuture;
      final label = _bestLocationLabel(address, region);

      if (!mounted) return;

      if (label == null || label.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('선택한 위치의 주소를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.'),
          ),
        );
        return;
      }

      Navigator.pop(
        context,
        _EditLocation(
          latLng: center,
          label: label,
          sido: region.sido,
          sigungu: region.sigungu,
          eupmyeondong: region.eupmyeondong,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResolvingAddress = false);
      }
    }
  }

  Future<_EditRegionSelection> _resolveRegion(LatLng latLng) async {
    final controller = _mapController;
    if (controller == null) {
      return _EditRegionSelection.empty;
    }

    try {
      final response = await controller
          .coord2RegionCode(
            Coord2RegionCodeRequest(x: latLng.longitude, y: latLng.latitude),
          )
          .timeout(const Duration(seconds: 3));

      Coord2RegionCode? selectedRegion;
      for (final region in response.list) {
        if (region.regionType == 'H') {
          selectedRegion = region;
          break;
        }
      }

      if (selectedRegion == null && response.list.isNotEmpty) {
        selectedRegion = response.list.first;
      }

      return _EditRegionSelection(
        sido: selectedRegion?.region1DepthName?.trim() ?? '',
        sigungu: selectedRegion?.region2DepthName?.trim() ?? '',
        eupmyeondong: selectedRegion?.region3DepthName?.trim() ?? '',
      );
    } catch (_) {
      return _EditRegionSelection.empty;
    }
  }

  Future<String?> _resolveAddress(LatLng latLng) async {
    final controller = _mapController;
    if (controller == null) {
      return null;
    }

    try {
      final response = await controller
          .coord2Address(
            Coord2AddressRequest(x: latLng.longitude, y: latLng.latitude),
          )
          .timeout(const Duration(seconds: 3));

      if (response.list.isNotEmpty) {
        final address = response.list.first;
        final value = address.roadAddress?.addressName ?? address.address?.addressName;
        if (value != null && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    } catch (_) {}

    return null;
  }

  String? _bestLocationLabel(
    String? address,
    _EditRegionSelection region,
  ) {
    if (address != null && address.trim().isNotEmpty) {
      return address.trim();
    }

    final regionText = [
      region.sido,
      region.sigungu,
      region.eupmyeondong,
    ].where((value) => value.trim().isNotEmpty).join(' ');

    return regionText.isEmpty ? null : regionText;
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = widget.initialLocation ?? _currentLocation;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _EditLocationStepShell(
          title: '습득 위치 선택',
          onBack: () => Navigator.pop(context),
          onClose: () => Navigator.pop(context),
          child: Stack(
            children: [
              if (mapCenter == null)
                _EditLocationLoadingMap(
                  isLoading: _isLoadingLocation,
                  message: _locationMessage,
                  onRetry: _loadCurrentLocation,
                )
              else
                Positioned.fill(
                  child: KakaoMap(
                    center: mapCenter,
                    currentLevel: 3,
                    zoomControl: true,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      controller.setCenter(mapCenter);
                      controller.setLevel(3);
                      _updateSelectionPreview(mapCenter);
                    },
                    onCameraIdle: (latLng, _) => _onCameraIdle(latLng),
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  ),
                ),
              if (mapCenter != null)
                IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 42),
                      child: Icon(
                        Icons.location_pin,
                        color: const Color(0xFFE5484D),
                        size: 46,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (mapCenter != null)
                Positioned(
                  left: 20,
                  right: 20,
                  top: 18,
                  child: _EditMapGuideBubble(
                    isLoading: _isLoadingLocation,
                    message: _locationMessage,
                  ),
                ),
              if (mapCenter != null)
                Positioned(
                  right: 18,
                  bottom: 124,
                  child: FloatingActionButton.small(
                    heroTag: 'edit-found-location-current',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4263F5),
                    onPressed: _moveToCurrentLocation,
                    child: const Icon(Icons.my_location),
                  ),
                ),
              if (_selectedCenter != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: _EditMapSelectionPanel(
                    label: _selectedDisplayLabel,
                    isPreviewResolving: _isPreviewResolving,
                    isResolvingAddress: _isResolvingAddress,
                    onConfirm: _confirmLocation,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditRegionSelection {
  const _EditRegionSelection({
    required this.sido,
    required this.sigungu,
    required this.eupmyeondong,
  });

  final String sido;
  final String sigungu;
  final String eupmyeondong;

  static const empty = _EditRegionSelection(
    sido: '',
    sigungu: '',
    eupmyeondong: '',
  );
}

class _EditLocationStepShell extends StatelessWidget {
  const _EditLocationStepShell({
    required this.title,
    required this.child,
    required this.onBack,
    required this.onClose,
  });

  final String title;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back, size: 20),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    strutStyle: const StrutStyle(
                      fontSize: 17,
                      height: 1.25,
                      forceStrutHeight: true,
                    ),
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 17,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(child: child),
      ],
    );
  }
}

class _EditMapGuideBubble extends StatelessWidget {
  const _EditMapGuideBubble({required this.isLoading, required this.message});

  final bool isLoading;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF4263F5),
              ),
            )
          else
            const Icon(Icons.touch_app, color: Color(0xFF4263F5), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message ?? '지도를 움직여 중앙 표시가 습득 위치에 맞도록 해주세요',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditLocationLoadingMap extends StatelessWidget {
  const _EditLocationLoadingMap({
    required this.isLoading,
    required this.message,
    required this.onRetry,
  });

  final bool isLoading;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 86),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF4263F5),
                ),
              )
            else
              const Icon(
                Icons.location_off,
                color: Color(0xFFEF4444),
                size: 38,
              ),
            const SizedBox(height: 14),
            Text(
              isLoading ? '현재 위치를 불러오는 중입니다' : message ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!isLoading) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditMapSelectionPanel extends StatelessWidget {
  const _EditMapSelectionPanel({
    required this.label,
    required this.isPreviewResolving,
    required this.isResolvingAddress,
    required this.onConfirm,
  });

  final String? label;
  final bool isPreviewResolving;
  final bool isResolvingAddress;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '선택할 위치',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              if (isPreviewResolving) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  isPreviewResolving
                      ? '해당 지역을 확인하는 중입니다...'
                      : (label ?? '주소를 확인하지 못했습니다.'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _EditPrimaryButton(
            text: isResolvingAddress ? '위치 확인 중...' : '이 위치 선택',
            enabled: !isResolvingAddress && !isPreviewResolving && label != null,
            onTap: onConfirm,
          ),
        ],
      ),
    );
  }
}

class _EditSegmentedLocationControl extends StatelessWidget {
  const _EditSegmentedLocationControl({
    required this.useMapLocation,
    required this.onChanged,
  });

  final bool useMapLocation;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _EditSegmentButton(
              text: '지도에서 선택',
              selected: useMapLocation,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _EditSegmentButton(
              text: '지역 선택',
              selected: !useMapLocation,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditSegmentButton extends StatelessWidget {
  const _EditSegmentButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF4263F5) : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditLocationButton extends StatelessWidget {
  const _EditLocationButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(selected ? Icons.location_on : Icons.my_location, size: 18),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected
            ? const Color(0xFF4263F5)
            : const Color(0xFF9CA3AF),
        side: const BorderSide(color: Color(0xFFD3DEFF)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EditSelectBox extends StatelessWidget {
  const _EditSelectBox({
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: !enabled
          ? null
          : (value) {
              if (value != null) {
                onChanged(value);
              }
            },
      icon: const Icon(Icons.keyboard_arrow_down),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD3DEFF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD3DEFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF5271FF), width: 1.4),
        ),
      ),
      style: const TextStyle(
        color: Color(0xFF111827),
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EditPrimaryButton extends StatelessWidget {
  const _EditPrimaryButton({
    required this.text,
    required this.onTap,
    this.enabled = true,
  });

  final String text;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF4263F5),
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF9CA3AF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
