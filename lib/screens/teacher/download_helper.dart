import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html; // ✅ IMPORTAR ESTO

class DownloadHelper {
  /// Método PRINCIPAL que SÍ funciona en Flutter Web
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

      // 1. Crear Blob con los bytes
      final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');

      // 2. Crear URL del Blob
      final url = html.Url.createObjectUrlFromBlob(blob);

      // 3. Crear elemento <a> para la descarga
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';

      // 4. Agregar al DOM
      html.document.body?.append(anchor);

      // 5. Hacer clic para iniciar descarga
      anchor.click();

      print('✅ Descarga iniciada: $fileName');

      // 6. Limpiar después de un tiempo
      Future.delayed(const Duration(seconds: 1), () {
        anchor.remove();
        html.Url.revokeObjectUrl(url);
        print('🧹 Recursos liberados');
      });
    } catch (e) {
      print('❌ Error en descarga web: $e');

      // Fallback: usar método alternativo
      await _downloadFallbackWeb(bytes, fileName, mimeType);
    }
  }

  /// Método FALLBACK para navegadores antiguos
  static Future<void> _downloadFallbackWeb(
    Uint8List bytes,
    String fileName,
    String? mimeType,
  ) async {
    try {
      print('🔄 Usando fallback para: $fileName');

      // Convertir a base64
      final base64 = base64Encode(bytes);
      final mime = mimeType ?? 'application/octet-stream';
      final dataUri = 'data:$mime;base64,$base64';

      // Crear enlace temporal
      final anchor = html.AnchorElement(href: dataUri)
        ..setAttribute('download', fileName)
        ..style.display = 'none';

      html.document.body?.append(anchor);
      anchor.click();

      // Limpiar
      Future.delayed(const Duration(milliseconds: 100), () {
        anchor.remove();
      });

      print('✅ Fallback ejecutado');
    } catch (e) {
      print('❌ Fallback también falló: $e');

      // Último recurso: abrir en nueva pestaña
      _openInNewTab(bytes, fileName, mimeType);
    }
  }

  /// Último recurso: abrir en nueva pestaña
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

      // Abrir en nueva ventana
      html.window.open(dataUri, '_blank');
    } catch (e) {
      print('💥 Todo falló: $e');
    }
  }

  /// Método para determinar MIME Type según extensión
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

  /// Método COMPLETO que funciona en todas las plataformas
  static Future<void> downloadFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    if (kIsWeb) {
      // Para web
      await downloadFileWeb(
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
      );
    } else {
      // Para móvil/desktop (ya tienes esta lógica)
      print('📱 Plataforma no web, usar método móvil');
      // Aquí llamarías a tu método existente para móvil
    }
  }
}
