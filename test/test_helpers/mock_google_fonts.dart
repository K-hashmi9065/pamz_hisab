import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sets up offline mock font handling for GoogleFonts in widget tests.
/// Intercepts asset bundle requests for Google Fonts (AssetManifest.bin, AssetManifest.json, and font binaries).
void setUpMockGoogleFonts() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  binding.setMockMessageHandler('flutter/assets', (ByteData? message) async {
    if (message == null) return null;
    final key = utf8.decode(message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));

    if (key == 'AssetManifest.bin') {
      final manifestMap = <String, List<Map<String, Object>>>{
        'google_fonts/NotoSans-Regular.ttf': [{'asset': 'google_fonts/NotoSans-Regular.ttf'}],
        'google_fonts/NotoSans-Medium.ttf': [{'asset': 'google_fonts/NotoSans-Medium.ttf'}],
        'google_fonts/NotoSans-SemiBold.ttf': [{'asset': 'google_fonts/NotoSans-SemiBold.ttf'}],
        'google_fonts/NotoSans-Bold.ttf': [{'asset': 'google_fonts/NotoSans-Bold.ttf'}],
        'google_fonts/Poppins-Regular.ttf': [{'asset': 'google_fonts/Poppins-Regular.ttf'}],
        'google_fonts/Poppins-Medium.ttf': [{'asset': 'google_fonts/Poppins-Medium.ttf'}],
        'google_fonts/Poppins-SemiBold.ttf': [{'asset': 'google_fonts/Poppins-SemiBold.ttf'}],
        'google_fonts/Poppins-Bold.ttf': [{'asset': 'google_fonts/Poppins-Bold.ttf'}],
        'google_fonts/RobotoMono-Regular.ttf': [{'asset': 'google_fonts/RobotoMono-Regular.ttf'}],
        'google_fonts/RobotoMono-Medium.ttf': [{'asset': 'google_fonts/RobotoMono-Medium.ttf'}],
        'google_fonts/RobotoMono-Bold.ttf': [{'asset': 'google_fonts/RobotoMono-Bold.ttf'}],
      };
      return const StandardMessageCodec().encodeMessage(manifestMap);
    }

    if (key == 'AssetManifest.json') {
      final manifest = {
        'google_fonts/NotoSans-Regular.ttf': ['google_fonts/NotoSans-Regular.ttf'],
        'google_fonts/NotoSans-Medium.ttf': ['google_fonts/NotoSans-Medium.ttf'],
        'google_fonts/NotoSans-SemiBold.ttf': ['google_fonts/NotoSans-SemiBold.ttf'],
        'google_fonts/NotoSans-Bold.ttf': ['google_fonts/NotoSans-Bold.ttf'],
        'google_fonts/Poppins-Regular.ttf': ['google_fonts/Poppins-Regular.ttf'],
        'google_fonts/Poppins-Medium.ttf': ['google_fonts/Poppins-Medium.ttf'],
        'google_fonts/Poppins-SemiBold.ttf': ['google_fonts/Poppins-SemiBold.ttf'],
        'google_fonts/Poppins-Bold.ttf': ['google_fonts/Poppins-Bold.ttf'],
        'google_fonts/RobotoMono-Regular.ttf': ['google_fonts/RobotoMono-Regular.ttf'],
        'google_fonts/RobotoMono-Medium.ttf': ['google_fonts/RobotoMono-Medium.ttf'],
        'google_fonts/RobotoMono-Bold.ttf': ['google_fonts/RobotoMono-Bold.ttf'],
      };
      final jsonStr = jsonEncode(manifest);
      final encoded = utf8.encode(jsonStr);
      return ByteData.view(Uint8List.fromList(encoded).buffer);
    }

    if (key.startsWith('google_fonts/') || key.endsWith('.ttf') || key.endsWith('.otf')) {
      final bytes = base64Decode(_kMockFontBase64);
      return ByteData.view(bytes.buffer);
    }

    return null;
  });
}

// Minimal valid TrueType font binary
const String _kMockFontBase64 =
    'AAEAAAASAQAIAAAgR0RFRgAiAAAA/AAAABxHUE9TAA8AAAAgAAAAHEdTVUIAAAAAAAAg'
    'AAAACkdTSUcAFAAAACAAAAAgT1NFMlMmA6AAAAAgAAAARGNtYXABABIAAAAAAgAAABhj'
    'YXNwAAAAAQAAACAAAAAIaGVhZAY9/nAAAAAgAAAANmhoZWECWwO/AAAAIAAAACRobXR4'
    'AAAAAQAAACAAAAAIbG9jYQAAAAABAAAAAm1heHAAEgAEAAAAIAAAACRuYW1lA8gDkgAA'
    'ACAAAAAocG9zdAADAAAAAAAgAAAAIAAAAAEAAAEAAAABAQAA';
