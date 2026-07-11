import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/found_item_registration.dart';

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
    final atcId = await _createAtcId();

    Reference? uploadedImageRef;
    String imageUrl = '';

    try {
      if (image != null) {
        final extension = _imageExtension(image.name);

        uploadedImageRef = _storage
            .ref()
            .child('found_items')
            .child(atcId)
            .child('main.$extension');

        final bytes = await image.readAsBytes();
        if (bytes.isEmpty) {
          throw StateError('선택한 이미지가 비어 있습니다.');
        }

        await uploadedImageRef.putData(
          bytes,
          SettableMetadata(
            contentType: image.mimeType ?? _contentType(extension),
            customMetadata: {
              'atcId': atcId,
              'polUse': 'user',
            },
          ),
        );

        imageUrl = await uploadedImageRef.getDownloadURL();
      }

      final latitude = item.latitude;
      final longitude = item.longitude;

      final geohash = latitude != null && longitude != null
          ? _encodeGeohash(latitude, longitude, precision: 8)
          : '';

      final data = <String, dynamic>{
        'atcId': atcId,
        'fdPrdtNm': item.itemName.trim(),
        'prdtClNmMg': item.category.trim(),
        'prdtClNmMn': '',
        'fndPlace': item.foundPlace.trim(),
        'fndDescription': item.description.trim(),
        'fdYmd': _formatDate(item.foundAt),
        'fdFilePathImg': imageUrl,
        'tel': item.contact.trim(),
        'polUse': 'user',
        'password': hashFoundItemPassword(atcId, item.password),
        'latitude': latitude,
        'longitude': longitude,
        'geohash': geohash,
        'sido': item.sido.trim(),
        'sigungu': item.sigungu.trim(),
        'eupmyeondong': item.eupmyeondong.trim(),
      };

      await _firestore
          .collection(_collectionName)
          .doc(atcId)
          .set(data);

      return atcId;
    } catch (_) {
      if (uploadedImageRef != null) {
        try {
          await uploadedImageRef.delete();
        } catch (_) {
          // 원래 예외를 유지한다.
        }
      }
      rethrow;
    }
  }

  Future<String> _createAtcId() async {
    final now = DateTime.now();
    final datePart =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';

    final random = Random.secure();

    for (var attempt = 0; attempt < 10; attempt++) {
      final numberPart = random
          .nextInt(100000000)
          .toString()
          .padLeft(8, '0');

      final atcId = 'S$datePart$numberPart';

      final existing = await _firestore
          .collection(_collectionName)
          .doc(atcId)
          .get();

      if (!existing.exists) {
        return atcId;
      }
    }

    throw StateError('고유한 습득물 ID를 생성하지 못했습니다.');
  }

  String _formatDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _imageExtension(String fileName) {
    final lowerName = fileName.toLowerCase().trim();
    final extension =
        lowerName.contains('.') ? lowerName.split('.').last : 'jpg';

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
        final midpoint =
            (longitudeInterval[0] + longitudeInterval[1]) / 2;

        if (longitude >= midpoint) {
          characterValue |= bits[bitIndex];
          longitudeInterval[0] = midpoint;
        } else {
          longitudeInterval[1] = midpoint;
        }
      } else {
        final midpoint =
            (latitudeInterval[0] + latitudeInterval[1]) / 2;

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

String hashFoundItemPassword(String atcId, String rawPassword) {
  return sha256
      .convert(utf8.encode('$atcId::$rawPassword'))
      .toString();
}

class MockFoundItemRepository implements FoundItemRepository {
  const MockFoundItemRepository();

  @override
  Future<String> registerFoundItem(
    FoundItemRegistration item, {
    XFile? image,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return 'MOCK_FOUND_ITEM';
  }
}
