import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:image_picker/image_picker.dart';

import '../models/found_item_ai_analysis.dart';

class FoundItemAiService {
  FoundItemAiService({
    FirebaseFunctions? functions,
  }) : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  Future<FoundItemAiAnalysis> analyzeImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = _guessMimeType(image.name);

    final callable = _functions.httpsCallable('analyzeFoundItemImage');

    final result = await callable.call<Map<String, dynamic>>({
      'imageBase64': base64Image,
      'mimeType': mimeType,
    });

    final data = Map<String, dynamic>.from(result.data);

    return FoundItemAiAnalysis.fromJson(data);
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }
}