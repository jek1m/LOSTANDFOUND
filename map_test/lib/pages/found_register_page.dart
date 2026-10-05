import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/found_item_registration.dart';
import '../repositories/found_item_repository.dart';
import '../services/found_item_ai_service.dart';
import '../services/kakao_place_search_service.dart';

part 'found_location_region_resolver.dart';
part 'found_place_search_step.dart';

enum _RegisterStep {
  photo,
  analyzing,
  confirm,
  detail,
  location,
  placeSearch,
  complete,
}

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
    '\ubd80\uc0b0',
    '\ub300\uad6c',
    '\uc778\ucc9c',
    '\uad11\uc8fc',
    '\ub300\uc804',
    '\uc6b8\uc0b0',
    '\uc138\uc885',
    '\uacbd\uae30',
    '\uac15\uc6d0',
    '\ucda9\ubd81',
    '\ucda9\ub0a8',
    '\uc804\ubd81',
    '\uc804\ub0a8',
    '\uacbd\ubd81',
    '\uacbd\ub0a8',
    '\uc81c\uc8fc',
  ];

  static const Map<String, List<String>> _districtsByRegion = {
    '\uc11c\uc6b8': [
      '\uac15\ub0a8\uad6c',
      '\uac15\ub3d9\uad6c',
      '\uac15\ubd81\uad6c',
      '\uac15\uc11c\uad6c',
      '\uad00\uc545\uad6c',
      '\uad11\uc9c4\uad6c',
      '\uad6c\ub85c\uad6c',
      '\uae08\ucc9c\uad6c',
      '\ub178\uc6d0\uad6c',
      '\ub3c4\ubd09\uad6c',
      '\ub3d9\ub300\ubb38\uad6c',
      '\ub3d9\uc791\uad6c',
      '\ub9c8\ud3ec\uad6c',
      '\uc11c\ub300\ubb38\uad6c',
      '\uc11c\ucd08\uad6c',
      '\uc131\ub3d9\uad6c',
      '\uc131\ubd81\uad6c',
      '\uc1a1\ud30c\uad6c',
      '\uc591\ucc9c\uad6c',
      '\uc601\ub4f1\ud3ec\uad6c',
      '\uc6a9\uc0b0\uad6c',
      '\uc740\ud3c9\uad6c',
      '\uc885\ub85c\uad6c',
      '\uc911\uad6c',
      '\uc911\ub791\uad6c',
    ],
    '\ubd80\uc0b0': [
      '\uac15\uc11c\uad6c',
      '\uae08\uc815\uad6c',
      '\uae30\uc7a5\uad70',
      '\ub0a8\uad6c',
      '\ub3d9\uad6c',
      '\ub3d9\ub798\uad6c',
      '\ubd80\uc0b0\uc9c4\uad6c',
      '\ubd81\uad6c',
      '\uc0ac\uc0c1\uad6c',
      '\uc0ac\ud558\uad6c',
      '\uc11c\uad6c',
      '\uc218\uc601\uad6c',
      '\uc5f0\uc81c\uad6c',
      '\uc601\ub3c4\uad6c',
      '\uc911\uad6c',
      '\ud574\uc6b4\ub300\uad6c',
    ],
    '\ub300\uad6c': [
      '\uad70\uc704\uad70',
      '\ub0a8\uad6c',
      '\ub2ec\uc11c\uad6c',
      '\ub2ec\uc131\uad70',
      '\ub3d9\uad6c',
      '\ubd81\uad6c',
      '\uc11c\uad6c',
      '\uc218\uc131\uad6c',
      '\uc911\uad6c',
    ],
    '\uc778\ucc9c': [
      '\uac15\ud654\uad70',
      '\uacc4\uc591\uad6c',
      '\ub0a8\ub3d9\uad6c',
      '\ub3d9\uad6c',
      '\ubbf8\ucd94\ud640\uad6c',
      '\ubd80\ud3c9\uad6c',
      '\uc11c\uad6c',
      '\uc5f0\uc218\uad6c',
      '\uc639\uc9c4\uad70',
      '\uc911\uad6c',
    ],
    '\uad11\uc8fc': [
      '\uad11\uc0b0\uad6c',
      '\ub0a8\uad6c',
      '\ub3d9\uad6c',
      '\ubd81\uad6c',
      '\uc11c\uad6c',
    ],
    '\ub300\uc804': [
      '\ub300\ub355\uad6c',
      '\ub3d9\uad6c',
      '\uc11c\uad6c',
      '\uc720\uc131\uad6c',
      '\uc911\uad6c',
    ],
    '\uc6b8\uc0b0': [
      '\ub0a8\uad6c',
      '\ub3d9\uad6c',
      '\ubd81\uad6c',
      '\uc6b8\uc8fc\uad70',
      '\uc911\uad6c',
    ],
    '\uc138\uc885': ['\uc138\uc885\uc2dc'],
    '\uacbd\uae30': [
      '\uac00\ud3c9\uad70',
      '\uace0\uc591\uc2dc',
      '\uacfc\ucc9c\uc2dc',
      '\uad11\uba85\uc2dc',
      '\uad11\uc8fc\uc2dc',
      '\uad6c\ub9ac\uc2dc',
      '\uad70\ud3ec\uc2dc',
      '\uae40\ud3ec\uc2dc',
      '\ub0a8\uc591\uc8fc\uc2dc',
      '\ub3d9\ub450\ucc9c\uc2dc',
      '\ubd80\ucc9c\uc2dc',
      '\uc131\ub0a8\uc2dc',
      '\uc218\uc6d0\uc2dc',
      '\uc2dc\ud765\uc2dc',
      '\uc548\uc0b0\uc2dc',
      '\uc548\uc131\uc2dc',
      '\uc548\uc591\uc2dc',
      '\uc591\uc8fc\uc2dc',
      '\uc591\ud3c9\uad70',
      '\uc5ec\uc8fc\uc2dc',
      '\uc5f0\ucc9c\uad70',
      '\uc624\uc0b0\uc2dc',
      '\uc6a9\uc778\uc2dc',
      '\uc758\uc655\uc2dc',
      '\uc758\uc815\ubd80\uc2dc',
      '\uc774\ucc9c\uc2dc',
      '\ud30c\uc8fc\uc2dc',
      '\ud3c9\ud0dd\uc2dc',
      '\ud3ec\ucc9c\uc2dc',
      '\ud558\ub0a8\uc2dc',
      '\ud654\uc131\uc2dc',
    ],
    '\uac15\uc6d0': [
      '\uac15\ub989\uc2dc',
      '\uace0\uc131\uad70',
      '\ub3d9\ud574\uc2dc',
      '\uc0bc\ucc99\uc2dc',
      '\uc18d\ucd08\uc2dc',
      '\uc591\uad6c\uad70',
      '\uc591\uc591\uad70',
      '\uc601\uc6d4\uad70',
      '\uc6d0\uc8fc\uc2dc',
      '\uc778\uc81c\uad70',
      '\uc815\uc120\uad70',
      '\ucca0\uc6d0\uad70',
      '\ucd98\ucc9c\uc2dc',
      '\ud0dc\ubc31\uc2dc',
      '\ud3c9\ucc3d\uad70',
      '\ud64d\ucc9c\uad70',
      '\ud654\ucc9c\uad70',
      '\ud6a1\uc131\uad70',
    ],
    '\ucda9\ubd81': [
      '\uad34\uc0b0\uad70',
      '\ub2e8\uc591\uad70',
      '\ubcf4\uc740\uad70',
      '\uc601\ub3d9\uad70',
      '\uc625\ucc9c\uad70',
      '\uc74c\uc131\uad70',
      '\uc81c\ucc9c\uc2dc',
      '\uc99d\ud3c9\uad70',
      '\uc9c4\ucc9c\uad70',
      '\uccad\uc8fc\uc2dc',
      '\ucda9\uc8fc\uc2dc',
    ],
    '\ucda9\ub0a8': [
      '\uacc4\ub8e1\uc2dc',
      '\uacf5\uc8fc\uc2dc',
      '\uae08\uc0b0\uad70',
      '\ub17c\uc0b0\uc2dc',
      '\ub2f9\uc9c4\uc2dc',
      '\ubcf4\ub839\uc2dc',
      '\ubd80\uc5ec\uad70',
      '\uc11c\uc0b0\uc2dc',
      '\uc11c\ucc9c\uad70',
      '\uc544\uc0b0\uc2dc',
      '\uc608\uc0b0\uad70',
      '\ucc9c\uc548\uc2dc',
      '\uccad\uc591\uad70',
      '\ud0dc\uc548\uad70',
      '\ud64d\uc131\uad70',
    ],
    '\uc804\ubd81': [
      '\uace0\ucc3d\uad70',
      '\uad70\uc0b0\uc2dc',
      '\uae40\uc81c\uc2dc',
      '\ub0a8\uc6d0\uc2dc',
      '\ubb34\uc8fc\uad70',
      '\ubd80\uc548\uad70',
      '\uc21c\ucc3d\uad70',
      '\uc644\uc8fc\uad70',
      '\uc775\uc0b0\uc2dc',
      '\uc784\uc2e4\uad70',
      '\uc7a5\uc218\uad70',
      '\uc804\uc8fc\uc2dc',
      '\uc815\uc74d\uc2dc',
      '\uc9c4\uc548\uad70',
    ],
    '\uc804\ub0a8': [
      '\uac15\uc9c4\uad70',
      '\uace0\ud765\uad70',
      '\uace1\uc131\uad70',
      '\uad11\uc591\uc2dc',
      '\uad6c\ub840\uad70',
      '\ub098\uc8fc\uc2dc',
      '\ub2f4\uc591\uad70',
      '\ubaa9\ud3ec\uc2dc',
      '\ubb34\uc548\uad70',
      '\ubcf4\uc131\uad70',
      '\uc21c\ucc9c\uc2dc',
      '\uc2e0\uc548\uad70',
      '\uc5ec\uc218\uc2dc',
      '\uc601\uad11\uad70',
      '\uc601\uc554\uad70',
      '\uc644\ub3c4\uad70',
      '\uc7a5\uc131\uad70',
      '\uc7a5\ud765\uad70',
      '\uc9c4\ub3c4\uad70',
      '\ud568\ud3c9\uad70',
      '\ud574\ub0a8\uad70',
      '\ud654\uc21c\uad70',
    ],
    '\uacbd\ubd81': [
      '\uacbd\uc0b0\uc2dc',
      '\uacbd\uc8fc\uc2dc',
      '\uace0\ub839\uad70',
      '\uad6c\ubbf8\uc2dc',
      '\uae40\ucc9c\uc2dc',
      '\ubb38\uacbd\uc2dc',
      '\ubd09\ud654\uad70',
      '\uc0c1\uc8fc\uc2dc',
      '\uc131\uc8fc\uad70',
      '\uc548\ub3d9\uc2dc',
      '\uc601\ub355\uad70',
      '\uc601\uc591\uad70',
      '\uc601\uc8fc\uc2dc',
      '\uc601\ucc9c\uc2dc',
      '\uc608\ucc9c\uad70',
      '\uc6b8\ub989\uad70',
      '\uc6b8\uc9c4\uad70',
      '\uc758\uc131\uad70',
      '\uccad\ub3c4\uad70',
      '\uccad\uc1a1\uad70',
      '\uce60\uace1\uad70',
      '\ud3ec\ud56d\uc2dc',
    ],
    '\uacbd\ub0a8': [
      '\uac70\uc81c\uc2dc',
      '\uac70\ucc3d\uad70',
      '\uace0\uc131\uad70',
      '\uae40\ud574\uc2dc',
      '\ub0a8\ud574\uad70',
      '\ubc00\uc591\uc2dc',
      '\uc0ac\ucc9c\uc2dc',
      '\uc0b0\uccad\uad70',
      '\uc591\uc0b0\uc2dc',
      '\uc758\ub839\uad70',
      '\uc9c4\uc8fc\uc2dc',
      '\ucc3d\ub155\uad70',
      '\ucc3d\uc6d0\uc2dc',
      '\ud1b5\uc601\uc2dc',
      '\ud558\ub3d9\uad70',
      '\ud568\uc548\uad70',
      '\ud568\uc591\uad70',
      '\ud569\ucc9c\uad70',
    ],
    '\uc81c\uc8fc': ['\uc11c\uadc0\ud3ec\uc2dc', '\uc81c\uc8fc\uc2dc'],
  };

  _RegisterStep _step = _RegisterStep.photo;
  String _selectedCategory = '\uac00\ubc29';
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

    try {
      late final double latitude;
      late final double longitude;
      late String sido;
      late String sigungu;
      late final String eupmyeondong;
      late final String foundPlace;

      final selectedLocation = _selectedLocationLatLng;
      if (selectedLocation == null ||
          !(_mapLocation?.trim().isNotEmpty ?? false)) {
        throw StateError('지도 또는 장소 검색에서 습득 위치를 선택해 주세요.');
      }

      if (_sido.trim().isEmpty || _sigungu.trim().isEmpty) {
        throw StateError('선택한 위치의 지역 정보를 확인하지 못했습니다. 위치를 다시 선택해 주세요.');
      }

      latitude = selectedLocation.latitude;
      longitude = selectedLocation.longitude;
      sido = _sido.trim();
      sigungu = _sigungu.trim();
      eupmyeondong = _eupmyeondong.trim();
      foundPlace = [
        sido,
        sigungu,
        eupmyeondong,
      ].where((region) => region.isNotEmpty).join(' ');

      debugPrint(
        '최종 등록 위치: mode=${_useMapLocation ? 'map' : 'place-search'}, '
        'sido=$sido, sigungu=$sigungu, eupmyeondong=$eupmyeondong, '
        'lat=$latitude, lon=$longitude, foundPlace=$foundPlace',
      );

      final item = FoundItemRegistration(
        itemName: _itemNameController.text.trim(),
        category: _selectedCategory,
        foundAt: _foundDate,
        foundPlace: foundPlace,
        description: _descriptionController.text.trim(),
        contact: _contactController.text.trim(),
        password: _passwordController.text.trim(),
        latitude: latitude,
        longitude: longitude,
        sido: sido,
        sigungu: sigungu,
        eupmyeondong: eupmyeondong,
      );

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

  bool get _canSubmit {
    final hasLocation =
        _selectedLocationLatLng != null &&
        (_mapLocation?.trim().isNotEmpty ?? false) &&
        _sido.isNotEmpty &&
        _sigungu.isNotEmpty;
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
              passwordController: _passwordController,
              contactController: _contactController,
              descriptionController: _descriptionController,
              canSubmit: _canSubmit,
              isSubmitting: _isSubmitting,
              onBack: () => setState(() => _step = _RegisterStep.confirm),
              onClose: _close,
              onPickDate: _pickDate,
              onUseMapChanged: (value) {
                setState(() {
                  final modeChanged = _useMapLocation != value;
                  _useMapLocation = value;
                  if (modeChanged || !value) {
                    _mapLocation = null;
                    _selectedLocationLatLng = null;
                    _sido = '';
                    _sigungu = '';
                    _eupmyeondong = '';
                  }
                  if (!value) _step = _RegisterStep.placeSearch;
                });
              },
              onOpenMap: () => setState(() => _step = _RegisterStep.location),
              onOpenPlaceSearch: () {
                setState(() => _step = _RegisterStep.placeSearch);
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
            _RegisterStep.placeSearch => _PlaceSearchStep(
              key: const ValueKey('place-search'),
              onBack: () => setState(() => _step = _RegisterStep.detail),
              onClose: _close,
              onPickLocation: (location) {
                setState(() {
                  _useMapLocation = false;
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
    required this.onOpenPlaceSearch,
    required this.onFieldChanged,
    required this.onSubmit,
  });

  final String foundDateText;
  final bool useMapLocation;
  final String? mapLocation;
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
  final VoidCallback onOpenPlaceSearch;
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
          else
            _LocationButton(
              text: mapLocation ?? '건물 또는 장소를 검색해 주세요',
              selected: mapLocation != null,
              onTap: onOpenPlaceSearch,
            ),
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
      var region = await regionFuture;

      if (region.sido.isEmpty || region.sigungu.isEmpty) {
        region = _regionFromAddressLabel(label);
      }

      debugPrint(
        '선택 위치 확정: lat=${center.latitude}, lon=${center.longitude}, '
        'label=$label, sido=${region.sido}, sigungu=${region.sigungu}, '
        'eupmyeondong=${region.eupmyeondong}',
      );

      if (!mounted) {
        return;
      }

      if (region.sido.isEmpty || region.sigungu.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '선택한 위치의 시/군/구 정보를 확인하지 못했습니다. '
              '지도를 조금 이동한 뒤 다시 선택해 주세요.',
            ),
          ),
        );
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
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 정보를 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isResolvingAddress = false);
      }
    }
  }

  _RegionSelection _regionFromAddressLabel(String label) {
    final normalized = label.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty || normalized.contains(',')) {
      return _RegionSelection.empty;
    }

    final parts = normalized.split(' ');
    if (parts.length < 2) {
      return _RegionSelection.empty;
    }

    const sidoMap = {
      '서울': '서울특별시',
      '서울특별시': '서울특별시',
      '부산': '부산광역시',
      '부산광역시': '부산광역시',
      '대구': '대구광역시',
      '대구광역시': '대구광역시',
      '인천': '인천광역시',
      '인천광역시': '인천광역시',
      '광주': '광주광역시',
      '광주광역시': '광주광역시',
      '대전': '대전광역시',
      '대전광역시': '대전광역시',
      '울산': '울산광역시',
      '울산광역시': '울산광역시',
      '세종': '세종특별자치시',
      '세종특별자치시': '세종특별자치시',
      '경기': '경기도',
      '경기도': '경기도',
      '강원': '강원특별자치도',
      '강원도': '강원특별자치도',
      '강원특별자치도': '강원특별자치도',
      '충북': '충청북도',
      '충청북도': '충청북도',
      '충남': '충청남도',
      '충청남도': '충청남도',
      '전북': '전북특별자치도',
      '전라북도': '전북특별자치도',
      '전북특별자치도': '전북특별자치도',
      '전남': '전라남도',
      '전라남도': '전라남도',
      '경북': '경상북도',
      '경상북도': '경상북도',
      '경남': '경상남도',
      '경상남도': '경상남도',
      '제주': '제주특별자치도',
      '제주도': '제주특별자치도',
      '제주특별자치도': '제주특별자치도',
    };

    final sido = sidoMap[parts.first];
    if (sido == null) {
      return _RegionSelection.empty;
    }

    final sigungu = parts[1];
    final eupmyeondong = parts.length >= 3 ? parts[2] : '';

    return _RegionSelection(
      sido: sido,
      sigungu: sigungu,
      eupmyeondong: eupmyeondong,
    );
  }

  String _canonicalSido(String value) {
    const sidoMap = {
      '서울': '서울특별시',
      '서울특별시': '서울특별시',
      '부산': '부산광역시',
      '부산광역시': '부산광역시',
      '대구': '대구광역시',
      '대구광역시': '대구광역시',
      '인천': '인천광역시',
      '인천광역시': '인천광역시',
      '광주': '광주광역시',
      '광주광역시': '광주광역시',
      '대전': '대전광역시',
      '대전광역시': '대전광역시',
      '울산': '울산광역시',
      '울산광역시': '울산광역시',
      '세종': '세종특별자치시',
      '세종특별자치시': '세종특별자치시',
      '경기': '경기도',
      '경기도': '경기도',
      '강원': '강원특별자치도',
      '강원도': '강원특별자치도',
      '강원특별자치도': '강원특별자치도',
      '충북': '충청북도',
      '충청북도': '충청북도',
      '충남': '충청남도',
      '충청남도': '충청남도',
      '전북': '전북특별자치도',
      '전라북도': '전북특별자치도',
      '전북특별자치도': '전북특별자치도',
      '전남': '전라남도',
      '전라남도': '전라남도',
      '경북': '경상북도',
      '경상북도': '경상북도',
      '경남': '경상남도',
      '경상남도': '경상남도',
      '제주': '제주특별자치도',
      '제주도': '제주특별자치도',
      '제주특별자치도': '제주특별자치도',
    };

    return sidoMap[value.trim()] ?? value.trim();
  }

  Future<_RegionSelection> _resolveRegion(LatLng latLng) async {
    // 1차: Kakao Map SDK 자체 좌표 -> 행정구역 변환
    final controller = _mapController;
    if (controller != null) {
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

        if (selectedRegion != null) {
          final result = _normalizeResolvedRegion(
            sidoRaw: selectedRegion.region1DepthName?.trim() ?? '',
            sigunguRaw: selectedRegion.region2DepthName?.trim() ?? '',
            eupmyeondongRaw: selectedRegion.region3DepthName?.trim() ?? '',
          );

          if (result.sido.isNotEmpty && result.sigungu.isNotEmpty) {
            return result;
          }
        }
      } catch (e) {
        debugPrint('Kakao coord2RegionCode 실패: $e');
      }
    }

    // 2차: 기기 reverse geocoding으로 재시도.
    // lost_search_page에서도 이미 geocoding 패키지를 사용하고 있으므로
    // REST API 키를 앱에 넣지 않고 지역명을 얻을 수 있다.
    try {
      final placemarks = await Geocoding(locale: const Locale('ko', 'KR'))
          .placemarkFromCoordinates(latLng.latitude, latLng.longitude)
          .timeout(const Duration(seconds: 6));

      for (final placemark in placemarks) {
        final sidoCandidates = <String>[
          placemark.administrativeArea ?? '',
          placemark.locality ?? '',
        ];

        String sido = '';
        for (final candidate in sidoCandidates) {
          final normalized = _canonicalSido(candidate);
          if (_isSupportedSido(normalized)) {
            sido = normalized;
            break;
          }
        }

        if (sido.isEmpty) {
          continue;
        }

        final sigunguCandidates = <String>[
          placemark.subAdministrativeArea ?? '',
          placemark.locality ?? '',
          placemark.subLocality ?? '',
          placemark.name ?? '',
        ];

        String sigungu = '';
        for (final candidate in sigunguCandidates) {
          sigungu = _normalizeSigunguForSearch(sido, candidate);
          if (sigungu.isNotEmpty) {
            break;
          }
        }

        String eupmyeondong = '';
        for (final candidate in <String>[
          placemark.subLocality ?? '',
          placemark.thoroughfare ?? '',
          placemark.name ?? '',
        ]) {
          final value = candidate.trim();
          if (_looksLikeEupmyeondong(value)) {
            eupmyeondong = value.split(' ').last;
            break;
          }
        }

        // 세종은 일반적인 시/군/구 2단계가 없어서 앱의 대표 지역 키를 세종시로 통일
        if (sido == '세종특별자치시' && sigungu.isEmpty) {
          sigungu = '세종시';
        }

        if (sigungu.isNotEmpty) {
          return _RegionSelection(
            sido: sido,
            sigungu: sigungu,
            eupmyeondong: eupmyeondong,
          );
        }
      }
    } catch (e) {
      debugPrint('reverse geocoding 실패: $e');
    }

    return _RegionSelection.empty;
  }

  _RegionSelection _normalizeResolvedRegion({
    required String sidoRaw,
    required String sigunguRaw,
    required String eupmyeondongRaw,
  }) {
    final sido = _canonicalSido(sidoRaw);

    if (!_isSupportedSido(sido)) {
      return _RegionSelection.empty;
    }

    var sigungu = _normalizeSigunguForSearch(sido, sigunguRaw);
    var eupmyeondong = eupmyeondongRaw.trim();

    if (sido == '세종특별자치시') {
      sigungu = '세종시';
      if (eupmyeondong.isEmpty && _looksLikeEupmyeondong(sigunguRaw)) {
        eupmyeondong = sigunguRaw.trim().split(' ').last;
      }
    }

    return _RegionSelection(
      sido: sido,
      sigungu: sigungu,
      eupmyeondong: eupmyeondong,
    );
  }

  bool _isSupportedSido(String value) {
    return const {
      '서울특별시',
      '부산광역시',
      '대구광역시',
      '인천광역시',
      '광주광역시',
      '대전광역시',
      '울산광역시',
      '세종특별자치시',
      '경기도',
      '강원특별자치도',
      '충청북도',
      '충청남도',
      '전북특별자치도',
      '전라남도',
      '경상북도',
      '경상남도',
      '제주특별자치도',
    }.contains(value);
  }

  String _normalizeSigunguForSearch(String sido, String raw) {
    final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) {
      return '';
    }

    if (sido == '세종특별자치시') {
      return '세종시';
    }

    final tokens = value.split(' ');

    final isMetro = const {
      '서울특별시',
      '부산광역시',
      '대구광역시',
      '인천광역시',
      '광주광역시',
      '대전광역시',
      '울산광역시',
    }.contains(sido);

    if (isMetro) {
      for (final token in tokens) {
        if (token.endsWith('구') || token.endsWith('군')) {
          return token;
        }
      }
    } else {
      // 도 단위 지역은 수원시 팔달구처럼 들어와도 검색 필터 기준은 수원시.
      for (final token in tokens) {
        if (token.endsWith('시') || token.endsWith('군')) {
          return token;
        }
      }

      // 제주도는 제주시/서귀포시가 locality 쪽에만 잡히는 경우가 있다.
      if (sido == '제주특별자치도') {
        for (final token in tokens) {
          if (token == '제주시' || token == '서귀포시') {
            return token;
          }
        }
      }
    }

    return '';
  }

  bool _looksLikeEupmyeondong(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return false;
    }

    final last = value.split(RegExp(r'\s+')).last;
    return last.endsWith('읍') ||
        last.endsWith('면') ||
        last.endsWith('동') ||
        last.endsWith('가') ||
        last.endsWith('리');
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

class _SelectBox extends StatefulWidget {
  const _SelectBox({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  State<_SelectBox> createState() => _SelectBoxState();
}

class _SelectBoxState extends State<_SelectBox> {
  bool _isOpen = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _SelectBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.items != widget.items || oldWidget.value != widget.value) {
      _isOpen = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);

    if (_isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) {
          return;
        }

        final selectedIndex = widget.items.indexOf(widget.value);
        if (selectedIndex < 0) {
          return;
        }

        const itemHeight = 46.0;
        final targetOffset = selectedIndex * itemHeight;
        final maxOffset = _scrollController.position.maxScrollExtent;

        _scrollController.jumpTo(targetOffset.clamp(0.0, maxOffset));
      });
    }
  }

  void _select(String value) {
    widget.onChanged(value);
    setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final selectedValue = widget.items.contains(widget.value)
        ? widget.value
        : (widget.items.isNotEmpty ? widget.items.first : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.items.isEmpty ? null : _toggle,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isOpen
                      ? const Color(0xFF5271FF)
                      : const Color(0xFFD3DEFF),
                  width: _isOpen ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedValue.isEmpty ? '선택해 주세요' : selectedValue,
                      style: TextStyle(
                        color: selectedValue.isEmpty
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF111827),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 22,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: !_isOpen
              ? const SizedBox.shrink()
              : Container(
                  key: const ValueKey('inline-select-list'),
                  margin: const EdgeInsets.only(top: 6),
                  constraints: const BoxConstraints(maxHeight: 230),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD3DEFF)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: widget.items.length > 5,
                    child: ListView.separated(
                      controller: _scrollController,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: widget.items.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        final selected = item == selectedValue;

                        return Material(
                          color: selected
                              ? const Color(0xFFF3F7FF)
                              : Colors.white,
                          child: InkWell(
                            onTap: () => _select(item),
                            child: SizedBox(
                              height: 46,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: TextStyle(
                                          color: selected
                                              ? const Color(0xFF4263F5)
                                              : const Color(0xFF111827),
                                          fontSize: 14,
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(
                                        Icons.check,
                                        size: 18,
                                        color: Color(0xFF4263F5),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
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
