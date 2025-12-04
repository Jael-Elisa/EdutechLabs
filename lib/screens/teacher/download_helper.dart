import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class DownloadHelper {
  static Future<void> downloadFileWeb({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    if (!kIsWeb) {
      print('⚠️ Este método solo funciona en web');
      return;
    }

    try {
      print(
          '🚀 Iniciando descarga REAL para: $fileName (${bytes.length} bytes)');

      final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');

      final url = html.Url.createObjectUrlFromBlob(blob);

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';

      html.document.body?.append(anchor);

      anchor.click();

      print('✅ Descarga iniciada: $fileName');

      Future.delayed(const Duration(seconds: 1), () {
        anchor.remove();
        html.Url.revokeObjectUrl(url);
        print('🧹 Recursos liberados');
      });
    } catch (e) {
      print('❌ Error en descarga web: $e');

      await _downloadFallbackWeb(bytes, fileName, mimeType);
    }
  }

  static Future<void> _downloadFallbackWeb(
    Uint8List bytes,
    String fileName,
    String? mimeType,
  ) async {
    try {
      print('🔄 Usando fallback para: $fileName');

      final base64 = base64Encode(bytes);
      final mime = mimeType ?? 'application/octet-stream';
      final dataUri = 'data:$mime;base64,$base64';

      final anchor = html.AnchorElement(href: dataUri)
        ..setAttribute('download', fileName)
        ..style.display = 'none';

      html.document.body?.append(anchor);
      anchor.click();

      Future.delayed(const Duration(milliseconds: 100), () {
        anchor.remove();
      });

      print('✅ Fallback ejecutado');
    } catch (e) {
      print('❌ Fallback también falló: $e');

      _openInNewTab(bytes, fileName, mimeType);
    }
  }

  static void _openInNewTab(
    Uint8List bytes,
    String fileName,
    String? mimeType,
  ) {
    try {
      print('🔗 Abriendo en nueva pestaña: $fileName');

      final base64 = base64Encode(bytes);
      final mime = mimeType ?? 'application/octet-stream';
      final dataUri = 'data:$mime;base64,$base64';

      html.window.open(dataUri, '_blank');
    } catch (e) {
      print('💥 Todo falló: $e');
    }
  }

  static String getMimeType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      case 'html':
      case 'htm':
        return 'text/html';
      case 'json':
        return 'application/json';
      case 'zip':
        return 'application/zip';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'application/octet-stream';
    }
  }

  static Future<void> downloadFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    if (kIsWeb) {
      await downloadFileWeb(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
    } else {
      print('📱 Plataforma no web, usar método móvil');
    }
  }
}
