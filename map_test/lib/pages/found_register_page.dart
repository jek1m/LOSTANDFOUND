import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';

import '../models/found_item_registration.dart';
import '../repositories/found_item_repository.dart';
import '../services/found_item_ai_service.dart';

enum _RegisterStep { photo, analyzing, confirm, detail, location, complete }

class _LocationSelection {
  const _LocationSelection({
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

class _RegionSelection {
  const _RegionSelection({
    required this.sido,
    required this.sigungu,
    required this.eupmyeondong,
  });

  final String sido;
  final String sigungu;
  final String eupmyeondong;

  static const empty = _RegionSelection(
    sido: '',
    sigungu: '',
    eupmyeondong: '',
  );
}

class FoundRegisterPage extends StatefulWidget {
  const FoundRegisterPage({
    super.key,
    this.repository = const FirebaseFoundItemRepository(),
    this.aiService,
  });

  final FoundItemRepository repository;
  final FoundItemAiService? aiService;

  @override
  State<FoundRegisterPage> createState() => _FoundRegisterPageState();
}

class _FoundRegisterPageState extends State<FoundRegisterPage> {
  FoundItemAiService get _aiService => widget.aiService ?? FoundItemAiService();
  final _imagePicker = ImagePicker();
  final _itemNameController = TextEditingController(
    text: '\uac80\uc815 \uac00\ubc29',
  );
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<String> _categories = const [
    '\uac00\ubc29',
    '\uadc0\uae08\uc18d',
    '\ub3c4\uc11c\uc6a9\ud488',
    '\uc11c\ub958',
    '\uc0b0\uc5c5\uc6a9\ud488',
    '\uc1fc\ud551\ubc31',
    '\uc2a4\ud3ec\uce20\uc6a9\ud488',
    '\uc545\uae30',
    '\uc720\uac00\uc99d\uad8c',
    '\uc758\ub958',
    '\uc790\ub3d9\ucc28',
    '\uc804\uc790\uae30\uae30',
    '\uc9c0\uac11',
    '\uc99d\uba85\uc11c',
    '\ucef4\ud4e8\ud130',
    '\uce74\ub4dc',
    '\ud604\uae08',
    '\ud734\ub300\ud3f0',
    '\uae30\ud0c0\ubb3c\ud488',
  ];
  final List<String> _regions = const [
    '\uc11c\uc6b8',
    '\uacbd\uae30',
    '\uc778\ucc9c',
    '\uac15\uc6d0',
    '\ucda9\ubd81',
    '\ucda9\ub0a8',
    '\uc804\ubd81',
    '\uc804\ub0a8',
    '\uacbd\ubd81',
  ];
  final List<String> _districts = const [
    '\uac15\ub0a8\uad6c',
    '\uac15\ub3d9\uad6c',
    '\uac15\ubd81\uad6c',
    '\uac15\uc11c\uad6c',
    '\uad00\uc545\uad6c',
    '\uad11\uc9c4\uad6c',
    '\uad6c\ub85c\uad6c',
    '\ub9c8\ud3ec\uad6c',
    '\uc11c\ucd08\uad6c',
    '\uc1a1\ud30c\uad6c',
  ];

  _RegisterStep _step = _RegisterStep.photo;
  String _selectedCategory = '\uac00\ubc29';
  String _selectedRegion = '\uc11c\uc6b8';
  String _selectedDistrict = '\uac15\ub0a8\uad6c';
  DateTime _foundDate = DateTime.now();
  bool _useMapLocation = true;
  bool _isSubmitting = false;
  String? _mapLocation;
  LatLng? _selectedLocationLatLng;
  String _sido = '';
  String _sigungu = '';
  String _eupmyeondong = '';
  XFile? _selectedImage;

  @override
  void dispose() {
    _itemNameController.dispose();
    _passwordController.dispose();
    _contactController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _startAnalysis() async {
    final image = _selectedImage;

    if (image == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진을 먼저 등록해 주세요.')));
      return;
    }

    setState(() => _step = _RegisterStep.analyzing);

    try {
      final result = await _aiService.analyzeImage(image);

      if (!mounted) {
        return;
      }

      setState(() {
        if (result.itemName.trim().isNotEmpty) {
          _itemNameController.text = result.itemName.trim();
        }

        if (_categories.contains(result.category.trim())) {
          _selectedCategory = result.category.trim();
        } else {
          _selectedCategory = '기타물품';
        }

        if (result.description.trim().isNotEmpty) {
          _descriptionController.text = result.description.trim();
        }

        _step = _RegisterStep.confirm;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _step = _RegisterStep.photo);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI 분석 중 오류가 발생했습니다: $e')));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  void _clearImage() {
    setState(() => _selectedImage = null);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _foundDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _foundDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit || _isSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final foundPlace = _useMapLocation
        ? (_mapLocation ?? '지도에서 선택한 위치')
        : '${_normalizeSido(_selectedRegion)} $_selectedDistrict';

    final item = FoundItemRegistration(
      itemName: _itemNameController.text.trim(),
      category: _selectedCategory,
      foundAt: _foundDate,
      foundPlace: foundPlace,
      description: _descriptionController.text.trim(),
      contact: _contactController.text.trim(),
      password: _passwordController.text.trim(),
      latitude: _selectedLocationLatLng?.latitude,
      longitude: _selectedLocationLatLng?.longitude,
      sido: _useMapLocation ? _sido : _normalizeSido(_selectedRegion),
      sigungu: _useMapLocation ? _sigungu : _selectedDistrict,
      eupmyeondong: _useMapLocation ? _eupmyeondong : '',
    );

    try {
      final atcId = await widget.repository.registerFoundItem(
        item,
        image: _selectedImage,
      );

      debugPrint('습득물 등록 완료: $atcId');

      if (mounted) {
        setState(() => _step = _RegisterStep.complete);
      }
    } catch (e, stackTrace) {
      debugPrint('습득물 등록 실패: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('등록 중 문제가 발생했습니다: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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

  bool get _canSubmit {
    final hasLocation = _useMapLocation
        ? _mapLocation != null
        : _selectedRegion.isNotEmpty && _selectedDistrict.isNotEmpty;
    return hasLocation &&
        _passwordController.text.trim().isNotEmpty &&
        _contactController.text.trim().isNotEmpty;
  }

  void _close() {
    Navigator.pop(context);
  }

  String _dateLabel(DateTime date) {
    return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_step) {
            _RegisterStep.photo => _PhotoStep(
              key: const ValueKey('photo'),
              image: _selectedImage,
              onClose: _close,
              onClearImage: _clearImage,
              onPickFromCamera: () => _pickImage(ImageSource.camera),
              onPickFromGallery: () => _pickImage(ImageSource.gallery),
              onStartAnalysis: _startAnalysis,
            ),
            _RegisterStep.analyzing => _AnalyzingStep(
              key: const ValueKey('analyzing'),
              onClose: _close,
            ),
            _RegisterStep.confirm => _ConfirmStep(
              key: const ValueKey('confirm'),
              category: _selectedCategory,
              categories: _categories,
              image: _selectedImage,
              itemNameController: _itemNameController,
              onCategoryChanged: (value) {
                setState(() => _selectedCategory = value);
              },
              onClose: _close,
              onNext: () => setState(() => _step = _RegisterStep.detail),
            ),
            _RegisterStep.detail => _DetailStep(
              key: const ValueKey('detail'),
              foundDateText: _dateLabel(_foundDate),
              useMapLocation: _useMapLocation,
              mapLocation: _mapLocation,
              selectedRegion: _selectedRegion,
              selectedDistrict: _selectedDistrict,
              regions: _regions,
              districts: _districts,
              passwordController: _passwordController,
              contactController: _contactController,
              descriptionController: _descriptionController,
              canSubmit: _canSubmit,
              isSubmitting: _isSubmitting,
              onBack: () => setState(() => _step = _RegisterStep.confirm),
              onClose: _close,
              onPickDate: _pickDate,
              onUseMapChanged: (value) {
                setState(() => _useMapLocation = value);
              },
              onOpenMap: () => setState(() => _step = _RegisterStep.location),
              onRegionChanged: (value) {
                setState(() => _selectedRegion = value);
              },
              onDistrictChanged: (value) {
                setState(() => _selectedDistrict = value);
              },
              onFieldChanged: () => setState(() {}),
              onSubmit: _submit,
            ),
            _RegisterStep.location => _LocationStep(
              key: const ValueKey('location'),
              initialLocation: _selectedLocationLatLng,
              onBack: () => setState(() => _step = _RegisterStep.detail),
              onClose: _close,
              onPickLocation: (location) {
                setState(() {
                  _selectedLocationLatLng = location.latLng;
                  _mapLocation = location.label;
                  _sido = location.sido;
                  _sigungu = location.sigungu;
                  _eupmyeondong = location.eupmyeondong;
                  _step = _RegisterStep.detail;
                });
              },
            ),
            _RegisterStep.complete => _CompleteStep(
              key: const ValueKey('complete'),
              onDone: _close,
            ),
          },
        ),
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  const _StepShell({
    required this.title,
    required this.child,
    this.onBack,
    this.onClose,
    this.bottom,
    this.progress,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final Widget? bottom;
  final double? progress;

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
                  child: onBack == null
                      ? const SizedBox.shrink()
                      : IconButton(
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
                  child: onClose == null
                      ? const SizedBox.shrink()
                      : IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close, size: 22),
                        ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        if (progress != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _ProgressPair(progress: progress!),
          ),
        Expanded(child: child),
        if (bottom != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
            child: bottom,
          ),
      ],
    );
  }
}

class _PhotoStep extends StatelessWidget {
  const _PhotoStep({
    super.key,
    required this.image,
    required this.onClose,
    required this.onClearImage,
    required this.onPickFromCamera,
    required this.onPickFromGallery,
    required this.onStartAnalysis,
  });

  final XFile? image;
  final VoidCallback onClose;
  final VoidCallback onClearImage;
  final VoidCallback onPickFromCamera;
  final VoidCallback onPickFromGallery;
  final VoidCallback onStartAnalysis;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: '\uc2b5\ub4dd\ubb3c \ub4f1\ub85d',
      onClose: onClose,
      bottom: _GradientButton(
        text: '\uc2b5\ub4dd\ubb3c \uc790\ub3d9 \ubd84\ub958\ud558\uae30',
        icon: Icons.auto_awesome,
        enabled: image != null,
        onTap: onStartAnalysis,
      ),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _ImageUploadCard(
              image: image,
              size: 202,
              onTap: () {
                _showImageSourceSheet(
                  context,
                  onPickFromCamera: onPickFromCamera,
                  onPickFromGallery: onPickFromGallery,
                );
              },
            ),
            if (image != null)
              Positioned(
                right: -8,
                top: -8,
                child: GestureDetector(
                  onTap: onClearImage,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5484D),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnalyzingStep extends StatelessWidget {
  const _AnalyzingStep({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: 'AI \ubd84\uc11d \uc911',
      onClose: onClose,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AiSpinner(),
            SizedBox(height: 24),
            Text(
              'AI\uac00 \uc790\ub3d9\uc73c\ub85c \ubd84\ub958\ud558\uace0 \uc788\uc5b4\uc694...',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '\uc7a0\uc2dc\ub9cc \uae30\ub2e4\ub824 \uc8fc\uc138\uc694',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    super.key,
    required this.category,
    required this.categories,
    required this.image,
    required this.itemNameController,
    required this.onCategoryChanged,
    required this.onClose,
    required this.onNext,
  });

  final String category;
  final List<String> categories;
  final XFile? image;
  final TextEditingController itemNameController;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onClose;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: '\ubd84\ub958 \ud655\uc778',
      onClose: onClose,
      progress: 0.5,
      bottom: _PrimaryButton(
        text: '\ub2e4\uc74c',
        icon: Icons.chevron_right,
        onTap: onNext,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBD2FF)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF4F6CF6), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI\uac00 \ubd84\ub958\ud55c \uacb0\uacfc\uc785\ub2c8\ub2e4.\\n\uc815\ubcf4\uac00 \ub9de\ub294\uc9c0 \ud655\uc778\ud558\uace0 \ud544\uc694\ud558\uba74 \uc218\uc815\ud574 \uc8fc\uc138\uc694.',
                    style: TextStyle(
                      color: Color(0xFF3855F6),
                      fontSize: 12,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _FieldLabel('\ub4f1\ub85d\ub41c \uc0ac\uc9c4'),
          _ImageUploadCard(
            image: image,
            size: 178,
            compact: true,
            enabled: false,
            onTap: () {},
          ),
          const SizedBox(height: 18),
          const _FieldLabel('\ubb3c\ud488 \ubd84\ub958'),
          _SelectBox(
            value: category,
            items: categories,
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 16),
          const _FieldLabel('\ubb3c\ud488\uba85'),
          _InputBox(
            controller: itemNameController,
            hintText:
                '\ubb3c\ud488\uba85\uc744 \uc785\ub825\ud574 \uc8fc\uc138\uc694',
          ),
          const SizedBox(height: 6),
          const Text(
            '\uc9c1\uc811 \uc218\uc815\ud560 \uc218 \uc788\uc2b5\ub2c8\ub2e4',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DetailStep extends StatelessWidget {
  const _DetailStep({
    super.key,
    required this.foundDateText,
    required this.useMapLocation,
    required this.mapLocation,
    required this.selectedRegion,
    required this.selectedDistrict,
    required this.regions,
    required this.districts,
    required this.passwordController,
    required this.contactController,
    required this.descriptionController,
    required this.canSubmit,
    required this.isSubmitting,
    required this.onBack,
    required this.onClose,
    required this.onPickDate,
    required this.onUseMapChanged,
    required this.onOpenMap,
    required this.onRegionChanged,
    required this.onDistrictChanged,
    required this.onFieldChanged,
    required this.onSubmit,
  });

  final String foundDateText;
  final bool useMapLocation;
  final String? mapLocation;
  final String selectedRegion;
  final String selectedDistrict;
  final List<String> regions;
  final List<String> districts;
  final TextEditingController passwordController;
  final TextEditingController contactController;
  final TextEditingController descriptionController;
  final bool canSubmit;
  final bool isSubmitting;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final VoidCallback onPickDate;
  final ValueChanged<bool> onUseMapChanged;
  final VoidCallback onOpenMap;
  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onDistrictChanged;
  final VoidCallback onFieldChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      title: '\uc2b5\ub4dd\ubb3c \uc0c1\uc138 \uc815\ubcf4 \uc785\ub825',
      onBack: onBack,
      onClose: onClose,
      progress: 1,
      bottom: _PrimaryButton(
        text: isSubmitting
            ? '\ub4f1\ub85d \uc911...'
            : '\ub4f1\ub85d\ud558\uae30',
        enabled: canSubmit && !isSubmitting,
        onTap: onSubmit,
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        children: [
          const Text(
            '\uc2b5\ub4dd \uc815\ubcf4\ub97c \uc785\ub825\ud574 \uc8fc\uc138\uc694',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          const _RequiredLabel('\uc2b5\ub4dd \ub0a0\uc9dc'),
          _DateBox(text: foundDateText, onTap: onPickDate),
          const SizedBox(height: 14),
          const _RequiredLabel('\uc2b5\ub4dd \uc7a5\uc18c'),
          _SegmentedLocationControl(
            useMapLocation: useMapLocation,
            onChanged: onUseMapChanged,
          ),
          const SizedBox(height: 10),
          if (useMapLocation)
            _LocationButton(
              text:
                  mapLocation ??
                  '\uc9c0\ub3c4\uc5d0\uc11c \uc704\uce58\ub97c \uc120\ud0dd\ud574 \uc8fc\uc138\uc694',
              selected: mapLocation != null,
              onTap: onOpenMap,
            )
          else ...[
            _SelectBox(
              value: selectedRegion,
              items: regions,
              onChanged: onRegionChanged,
            ),
            const SizedBox(height: 8),
            _SelectBox(
              value: selectedDistrict,
              items: districts,
              onChanged: onDistrictChanged,
            ),
          ],
          const SizedBox(height: 14),
          const _RequiredLabel('\ud328\uc2a4\uc6cc\ub4dc'),
          _InputBox(
            controller: passwordController,
            hintText:
                '\ud328\uc2a4\uc6cc\ub4dc\ub97c \uc785\ub825\ud574 \uc8fc\uc138\uc694',
            obscureText: true,
            onChanged: (_) => onFieldChanged(),
          ),
          const SizedBox(height: 6),
          const Text(
            '\ub4f1\ub85d\ud55c \ubb3c\ud488\uc744 \uc218\uc815\ud560 \ub54c \ud544\uc694\ud569\ub2c8\ub2e4',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
          ),
          const SizedBox(height: 14),
          const _RequiredLabel('\uc5f0\ub77d\ucc98'),
          _InputBox(
            controller: contactController,
            hintText:
                '\uc774\uba54\uc77c, \uc804\ud654\ubc88\ud638 \ub4f1 \uc5f0\ub77d \uac00\ub2a5\ud55c \uc815\ubcf4\ub97c \uc785\ub825\ud574 \uc8fc\uc138\uc694',
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => onFieldChanged(),
          ),
          const SizedBox(height: 6),
          const Text(
            '?? 010-1234-5678, example@email.com',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('\uc0c1\uc138\uc124\uba85'),
          _InputBox(
            controller: descriptionController,
            hintText:
                '\uc2b5\ub4dd\ubb3c\uc5d0 \ub300\ud55c \ucd94\uac00 \uc815\ubcf4\ub97c \uc785\ub825\ud574 \uc8fc\uc138\uc694',
            maxLines: 4,
            onChanged: (_) => onFieldChanged(),
          ),
        ],
      ),
    );
  }
}

class _LocationStep extends StatefulWidget {
  const _LocationStep({
    super.key,
    required this.initialLocation,
    required this.onBack,
    required this.onClose,
    required this.onPickLocation,
  });

  final LatLng? initialLocation;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final ValueChanged<_LocationSelection> onPickLocation;

  @override
  State<_LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<_LocationStep> {
  KakaoMapController? _mapController;
  LatLng? _selectedCenter;
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  bool _isResolvingAddress = false;
  String? _locationMessage;

  @override
  void initState() {
    super.initState();
    _selectedCenter = widget.initialLocation;
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _locationMessage =
              '\uc704\uce58 \uc11c\ube44\uc2a4\uac00 \uaebc\uc838 \uc788\uc2b5\ub2c8\ub2e4. \uc704\uce58 \uc11c\ube44\uc2a4\ub97c \ucf1c\uace0 \ub2e4\uc2dc \uc2dc\ub3c4\ud574 \uc8fc\uc138\uc694.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoadingLocation = false;
          _locationMessage =
              '\uc704\uce58 \uad8c\ud55c\uc774 \uac70\ubd80\ub418\uc5c8\uc2b5\ub2c8\ub2e4. \uc704\uce58 \uad8c\ud55c\uc744 \ud5c8\uc6a9\ud574 \uc8fc\uc138\uc694.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _locationMessage =
              '\uc124\uc815\uc5d0\uc11c \uc704\uce58 \uad8c\ud55c\uc744 \ud5c8\uc6a9\ud574 \uc8fc\uc138\uc694.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = latLng;
        _selectedCenter = widget.initialLocation ?? latLng;
        _isLoadingLocation = false;
      });

      if (widget.initialLocation == null) {
        _mapController?.setCenter(latLng);
        _mapController?.setLevel(3);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingLocation = false;
        _locationMessage =
            '\ud604\uc7ac \uc704\uce58\ub97c \ubd88\ub7ec\uc62c \uc218 \uc5c6\uc2b5\ub2c8\ub2e4. \uc7a0\uc2dc \ud6c4 \ub2e4\uc2dc \uc2dc\ub3c4\ud574 \uc8fc\uc138\uc694.';
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
  }

  Future<void> _confirmLocation() async {
    if (_isResolvingAddress) {
      return;
    }

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

      final labelFuture = _resolveAddress(center);
      final regionFuture = _resolveRegion(center);
      final label = await labelFuture;
      final region = await regionFuture;

      if (!mounted) {
        return;
      }

      widget.onPickLocation(
        _LocationSelection(
          latLng: center,
          label: label,
          sido: region.sido,
          sigungu: region.sigungu,
          eupmyeondong: region.eupmyeondong,
        ),
      );
    } catch (_) {
      final center = _selectedCenter;
      if (mounted && center != null) {
        widget.onPickLocation(
          _LocationSelection(
            latLng: center,
            label: _latLngLabel(center),
            sido: '',
            sigungu: '',
            eupmyeondong: '',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResolvingAddress = false);
      }
    }
  }

  Future<_RegionSelection> _resolveRegion(LatLng latLng) async {
    final controller = _mapController;
    if (controller == null) {
      return _RegionSelection.empty;
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

      return _RegionSelection(
        sido: selectedRegion?.region1DepthName?.trim() ?? '',
        sigungu: selectedRegion?.region2DepthName?.trim() ?? '',
        eupmyeondong: selectedRegion?.region3DepthName?.trim() ?? '',
      );
    } catch (_) {
      return _RegionSelection.empty;
    }
  }

  Future<String> _resolveAddress(LatLng latLng) async {
    final controller = _mapController;
    if (controller == null) {
      return _latLngLabel(latLng);
    }

    try {
      final response = await controller
          .coord2Address(
            Coord2AddressRequest(x: latLng.longitude, y: latLng.latitude),
          )
          .timeout(const Duration(seconds: 3));

      if (response.list.isNotEmpty) {
        final address = response.list.first;
        return address.roadAddress?.addressName ??
            address.address?.addressName ??
            _latLngLabel(latLng);
      }
    } catch (_) {
      return _latLngLabel(latLng);
    }

    return _latLngLabel(latLng);
  }

  String _latLngLabel(LatLng latLng) {
    return '${latLng.latitude.toStringAsFixed(6)}, '
        '${latLng.longitude.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = widget.initialLocation ?? _currentLocation;

    return _StepShell(
      title: '\uc2b5\ub4dd \uc704\uce58 \uc120\ud0dd',
      onBack: widget.onBack,
      onClose: widget.onClose,
      child: Stack(
        children: [
          if (mapCenter == null)
            _LocationLoadingMap(
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
                },
                onCameraIdle: (latLng, _) {
                  setState(() => _selectedCenter = latLng);
                },
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
              child: _MapGuideBubble(
                isLoading: _isLoadingLocation,
                message: _locationMessage,
              ),
            ),
          if (mapCenter != null)
            Positioned(
              right: 18,
              bottom: 124,
              child: FloatingActionButton.small(
                heroTag: 'found-location-current',
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
              child: _MapSelectionPanel(
                latLng: _selectedCenter!,
                isResolvingAddress: _isResolvingAddress,
                onConfirm: _confirmLocation,
              ),
            ),
          Offstage(
            offstage: true,
            child: GestureDetector(
              onTap: _confirmLocation,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location, color: Color(0xFF4263F5)),
                    SizedBox(height: 8),
                    Text(
                      '\uc9c0\ub3c4\uc5d0\uc11c \uc6d0\ud558\ub294 \uc704\uce58\ub97c \uc120\ud0dd\ud558\uc138\uc694',
                      style: TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGuideBubble extends StatelessWidget {
  const _MapGuideBubble({required this.isLoading, required this.message});

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
              message ??
                  '\uc9c0\ub3c4\ub97c \uc6c0\uc9c1\uc5ec \uc911\uc559 \ud45c\uc2dc\uac00 \uc2b5\ub4dd \uc704\uce58\uc5d0 \ub9de\ub3c4\ub85d \ud574\uc8fc\uc138\uc694',
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

class _LocationLoadingMap extends StatelessWidget {
  const _LocationLoadingMap({
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
              isLoading
                  ? '\ud604\uc7ac \uc704\uce58\ub97c \ubd88\ub7ec\uc624\ub294 \uc911\uc785\ub2c8\ub2e4'
                  : message ?? '',
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
                label: const Text('\ub2e4\uc2dc \uc2dc\ub3c4'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapSelectionPanel extends StatelessWidget {
  const _MapSelectionPanel({
    required this.latLng,
    required this.isResolvingAddress,
    required this.onConfirm,
  });

  final LatLng latLng;
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
            '\uc120\ud0dd\ud560 \uc704\uce58',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${latLng.latitude.toStringAsFixed(6)}, '
            '${latLng.longitude.toStringAsFixed(6)}',
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _PrimaryButton(
            text: isResolvingAddress
                ? '\uc704\uce58 \ud655\uc778 \uc911...'
                : '\uc774 \uc704\uce58 \uc120\ud0dd',
            enabled: !isResolvingAddress,
            onTap: onConfirm,
          ),
        ],
      ),
    );
  }
}

class _CompleteStep extends StatelessWidget {
  const _CompleteStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 38),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFFD9F8DD),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF31C75A),
                size: 48,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '\ub4f1\ub85d \uc644\ub8cc!',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '\uc2b5\ub4dd\ubb3c\uc774 \uc131\uacf5\uc801\uc73c\ub85c \ub4f1\ub85d\ub418\uc5c8\uc2b5\ub2c8\ub2e4.\\n\uac80\uc0c9 \uacb0\uacfc\uc5d0\uc11c \ud655\uc778\ud560 \uc218 \uc788\uc2b5\ub2c8\ub2e4.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            _PrimaryButton(text: '\ud655\uc778', onTap: onDone),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.text,
    required this.onTap,
    this.icon,
    this.enabled = true,
  });

  final String text;
  final VoidCallback onTap;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9B2DF4), Color(0xFF4263F5)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4263F5).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.onTap,
    this.icon,
    this.enabled = true,
  });

  final String text;
  final VoidCallback onTap;
  final IconData? icon;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 6),
                Icon(icon, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressPair extends StatelessWidget {
  const _ProgressPair({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ProgressBar(active: true)),
        const SizedBox(width: 8),
        Expanded(child: _ProgressBar(active: progress >= 1)),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF5271FF) : const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _ImageUploadCard extends StatelessWidget {
  const _ImageUploadCard({
    required this.image,
    required this.size,
    required this.onTap,
    this.compact = false,
    this.enabled = true,
  });

  final XFile? image;
  final double size;
  final VoidCallback onTap;
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: Container(
        width: compact ? double.infinity : size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: image == null
            ? const _CameraAddPlaceholder()
            : _PickedImagePreview(image: image!),
      ),
    );
  }
}

class _CameraAddPlaceholder extends StatelessWidget {
  const _CameraAddPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.photo_camera_outlined,
            size: 74,
            color: Color(0xFF111827),
          ),
          Positioned(
            right: -12,
            bottom: 4,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF4263F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedImagePreview extends StatelessWidget {
  const _PickedImagePreview({required this.image});

  final XFile image;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: image.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          );
        }

        return const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4263F5),
            strokeWidth: 2,
          ),
        );
      },
    );
  }
}

void _showImageSourceSheet(
  BuildContext context, {
  required VoidCallback onPickFromCamera,
  required VoidCallback onPickFromGallery,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              _ImageSourceTile(
                icon: Icons.photo_camera_outlined,
                text: '\uce74\uba54\ub77c\ub85c \ucd2c\uc601',
                onTap: () {
                  Navigator.pop(context);
                  onPickFromCamera();
                },
              ),
              const SizedBox(height: 8),
              _ImageSourceTile(
                icon: Icons.photo_library_outlined,
                text: '\uc568\ubc94\uc5d0\uc11c \uc120\ud0dd',
                onTap: () {
                  Navigator.pop(context);
                  onPickFromGallery();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ImageSourceTile extends StatelessWidget {
  const _ImageSourceTile({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Icon(icon, color: const Color(0xFF4263F5)),
      title: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AiSpinner extends StatelessWidget {
  const _AiSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 94,
      height: 94,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 5,
            value: 0.78,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF9B2DF4)),
          ),
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Color(0xFFC084FC),
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4B5563),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          children: [
            TextSpan(text: text),
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFE5484D)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
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
    );
  }
}

class _SelectBox extends StatelessWidget {
  const _SelectBox({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: (value) {
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

class _DateBox extends StatelessWidget {
  const _DateBox({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD3DEFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFD3DEFF)),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _SegmentedLocationControl extends StatelessWidget {
  const _SegmentedLocationControl({
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
            child: _SegmentButton(
              text: '\uc9c0\ub3c4\uc5d0\uc11c \uc120\ud0dd',
              selected: useMapLocation,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegmentButton(
              text: '\uc9c0\uc5ed \uc120\ud0dd',
              selected: !useMapLocation,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
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

class _LocationButton extends StatelessWidget {
  const _LocationButton({
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
        child: Text(text, overflow: TextOverflow.ellipsis),
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
