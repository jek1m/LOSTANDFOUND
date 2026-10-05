import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/found_item_registration.dart';
import '../utils/geohash_query.dart';

Map<String, dynamic> buildFoundItemFirestoreData({
  required String atcId,
  required FoundItemRegistration item,
  required String imageUrl,
}) {
  final latitude = item.latitude;
  final longitude = item.longitude;
  final administrativeArea = [
    item.sido.trim(),
    item.sigungu.trim(),
    item.eupmyeondong.trim(),
  ].where((region) => region.isNotEmpty).join(' ');
  final geohash = latitude != null && longitude != null
      ? encodeGeohash(latitude, longitude, precision: 8)
      : '';

  return <String, dynamic>{
    'atcId': atcId,
    'fdPrdtNm': item.itemName.trim(),
    'prdtClNmMg': item.category.trim(),
    'prdtClNmMn': '',
    'fndPlace': administrativeArea,
    'fndDescription': item.description.trim(),
    'fdYmd': _formatDate(item.foundAt),
    'fdFilePathImg': imageUrl,
    'tel': item.contact.trim(),
    'polUse': 'user',
    'password': item.password.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'geohash': geohash,
    'sido': item.sido.trim(),
    'sigungu': item.sigungu.trim(),
    'eupmyeondong': item.eupmyeondong.trim(),
  };
}

String _formatDate(DateTime date) {
  return '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

abstract class FoundItemRepository {
  Future<String> registerFoundItem(
    FoundItemRegistration item, {
    XFile? image,
  });
}

class FirebaseFoundItemRepository implements FoundItemRepository {
  const FirebaseFoundItemRepository();

  static const String _collectionName = 'found_items';

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  @override
  Future<String> registerFoundItem(
    FoundItemRegistration item, {
    XFile? image,
  }) async {
    final atcId = _createAtcId();

    Reference? uploadedImageRef;
    var firestoreSaved = false;
    var imageUrl = '';
    var currentStage = '등록 준비';

    try {
      debugPrint('[습득물 등록] 시작: $atcId');

      if (image != null) {
        currentStage = '이미지 읽기';
        debugPrint('[습득물 등록] $currentStage');

        final imageBytes = await image
            .readAsBytes()
            .timeout(const Duration(seconds: 15));

        if (imageBytes.isEmpty) {
          throw StateError('선택한 이미지가 비어 있습니다.');
        }

        final extension = _imageExtension(image.name);

        uploadedImageRef = _storage
            .ref()
            .child('found_items')
            .child(atcId)
            .child('main.$extension');

        currentStage = 'Firebase Storage 이미지 업로드';
        debugPrint('[습득물 등록] $currentStage');

        final uploadSnapshot = await uploadedImageRef
            .putData(
              imageBytes,
              SettableMetadata(
                contentType:
                    image.mimeType ?? _contentType(extension),
                customMetadata: {
                  'atcId': atcId,
                  'polUse': 'user',
                },
              ),
            )
            .timeout(const Duration(seconds: 30));

        currentStage = '이미지 다운로드 URL 생성';
        debugPrint('[습득물 등록] $currentStage');

        imageUrl = await uploadSnapshot.ref
            .getDownloadURL()
            .timeout(const Duration(seconds: 15));
      }

      final data = buildFoundItemFirestoreData(
        atcId: atcId,
        item: item,
        imageUrl: imageUrl,
      );

      currentStage = 'Cloud Firestore 정보 저장';
      debugPrint('[습득물 등록] $currentStage');

      await _firestore
          .collection(_collectionName)
          .doc(atcId)
          .set(data)
          .timeout(const Duration(seconds: 20));

      firestoreSaved = true;
      debugPrint('[습득물 등록] 완료: $atcId');

      return atcId;
    } on TimeoutException {
      throw Exception(
        '$currentStage 시간이 초과되었습니다. '
        'Firebase Storage 활성화 여부와 보안 규칙을 확인해 주세요.',
      );
    } on FirebaseException catch (e) {
      throw Exception(
        '$currentStage 실패 '
        '[${e.plugin}/${e.code}]: ${e.message ?? 'Firebase 오류'}',
      );
    } catch (e) {
      throw Exception('$currentStage 실패: $e');
    } finally {
      if (uploadedImageRef != null && !firestoreSaved) {
        try {
          await uploadedImageRef
              .delete()
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          // 이미지 정리 실패가 원래 오류를 가리지 않게 함
        }
      }
    }
  }

  // S + 등록 날짜 8자리 + 숫자 8자리
  // 예: S2026071112345678
  String _createAtcId() {
    final now = DateTime.now();

    final datePart =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';

    final numberPart =
        (now.microsecondsSinceEpoch % 100000000)
            .toString()
            .padLeft(8, '0');

    return 'S$datePart$numberPart';
  }

  String _imageExtension(String fileName) {
    final lowerName = fileName.toLowerCase().trim();
    final extension = lowerName.contains('.')
        ? lowerName.split('.').last
        : 'jpg';

    const allowedExtensions = {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
    };

    return allowedExtensions.contains(extension)
        ? extension
        : 'jpg';
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

}

class MockFoundItemRepository implements FoundItemRepository {
  const MockFoundItemRepository();

  @override
  Future<String> registerFoundItem(
    FoundItemRegistration item, {
    XFile? image,
  }) async {
    await Future<void>.delayed(
      const Duration(milliseconds: 500),
    );

    return 'MOCK_FOUND_ITEM';
  }
}
