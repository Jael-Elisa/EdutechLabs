import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class DownloadHelper {
  static Future<void> downloadFileWeb({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    // Validar que estamos en web
    if (!kIsWeb) {
      print('⚠️ Este método solo funciona en web');
      return;
    }

    // Validaciones de entrada
    if (bytes.isEmpty) {
      print('❌ Error: bytes vacíos para el archivo: $fileName');
      return;
    }

    if (fileName.isEmpty || fileName.trim().isEmpty) {
      print('❌ Error: nombre de archivo vacío o inválido');
      return;
    }

    // Sanitizar nombre de archivo
    final sanitizedFileName = _sanitizeFileName(fileName);
    if (sanitizedFileName.isEmpty) {
      print('❌ Error: nombre de archivo no válido después de sanitizar');
      return;
    }

    try {
      print(
          '🚀 Iniciando descarga REAL para: $sanitizedFileName (${bytes.length} bytes)');

      // Validar que el documento HTML esté disponible
      if (html.document.body == null) {
        print('❌ Error: documento HTML no disponible');
        await _downloadFallbackWeb(bytes, sanitizedFileName, mimeType);
        return;
      }

      // Usar tipo MIME proporcionado o determinar automáticamente
      final finalMimeType = mimeType ?? getMimeType(sanitizedFileName);
      
      // Validar tipo MIME
      if (finalMimeType.isEmpty) {
        print('⚠️ Tipo MIME vacío, usando tipo por defecto');
      }

      final blob = html.Blob([bytes], finalMimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Validar que la URL se creó correctamente
      if (url.isEmpty) {
        throw Exception('No se pudo crear URL para el blob');
      }

      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', sanitizedFileName)
        ..style.display = 'none';

      // Añadir al DOM
      html.document.body!.append(anchor);

      // Intentar descargar
      try {
        anchor.click();
        print('✅ Descarga iniciada: $sanitizedFileName');
      } catch (clickError) {
        print('❌ Error al hacer click: $clickError');
        await _downloadFallbackWeb(bytes, sanitizedFileName, finalMimeType);
        return;
      }

      // Limpiar recursos después de un tiempo
      Future.delayed(const Duration(seconds: 1), () {
        try {
          anchor.remove();
          html.Url.revokeObjectUrl(url);
          print('🧹 Recursos liberados');
        } catch (cleanupError) {
          print('⚠️ Error al limpiar recursos: $cleanupError');
        }
      });
    } catch (e, stackTrace) {
      print('❌ Error en descarga web: $e');
      print('Stack trace: $stackTrace');

      // Intentar método alternativo
      await _downloadFallbackWeb(bytes, sanitizedFileName, mimeType);
    }
  }

  static Future<void> _downloadFallbackWeb(
    Uint8List bytes,
    String fileName,
    String? mimeType,
  ) async {
    try {
      print('🔄 Usando fallback para: $fileName');

      // Validar entrada
      if (bytes.isEmpty) {
        throw Exception('bytes vacíos');
      }

      if (fileName.isEmpty) {
        throw Exception('nombre de archivo vacío');
      }

      // Usar tipo MIME proporcionado o determinar automáticamente
      final finalMimeType = mimeType ?? getMimeType(fileName);
      
      final base64 = base64Encode(bytes);
      final dataUri = 'data:$finalMimeType;base64,$base64';

      // Validar que el documento HTML esté disponible
      if (html.document.body == null) {
        throw Exception('documento HTML no disponible');
      }

      final anchor = html.AnchorElement(href: dataUri)
        ..setAttribute('download', fileName)
        ..style.display = 'none';

      html.document.body!.append(anchor);
      
      try {
        anchor.click();
        print('✅ Fallback ejecutado exitosamente');
      } catch (clickError) {
        print('❌ Error en fallback al hacer click: $clickError');
        throw clickError;
      }

      // Limpiar después de un tiempo
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          anchor.remove();
        } catch (e) {
          print('⚠️ Error al limpiar anchor: $e');
        }
      });
    } catch (e, stackTrace) {
      print('❌ Fallback también falló: $e');
      print('Stack trace: $stackTrace');

      // Último intento: abrir en nueva pestaña
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

      // Validar entrada
      if (bytes.isEmpty) {
        throw Exception('bytes vacíos');
      }

      // Usar tipo MIME proporcionado o determinar automáticamente
      final finalMimeType = mimeType ?? getMimeType(fileName);
      
      final base64 = base64Encode(bytes);
      final dataUri = 'data:$finalMimeType;base64,$base64';

      // Intentar abrir en nueva pestaña
      final newWindow = html.window.open(dataUri, '_blank');
      
      // Verificar si se abrió correctamente
      if (newWindow == null) {
        throw Exception('No se pudo abrir nueva pestaña (probablemente bloqueada por popup blocker)');
      }
      
      print('✅ Abierto en nueva pestaña');
    } catch (e, stackTrace) {
      print('💥 Todo falló: $e');
      print('Stack trace: $stackTrace');
      
      // Mostrar mensaje al usuario (en un entorno real, podrías mostrar un SnackBar)
      _showErrorMessageToUser('No se pudo descargar el archivo: $fileName');
    }
  }

  static String getMimeType(String fileName) {
    // Validar entrada
    if (fileName.isEmpty) {
      return 'application/octet-stream';
    }

    final extension = fileName.split('.').last.toLowerCase();
    
    // Si no hay extensión o el archivo comienza con punto
    if (extension.isEmpty || extension == fileName.toLowerCase()) {
      return 'application/octet-stream';
    }

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
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'csv':
        return 'text/csv';
      case 'xml':
        return 'application/xml';
      default:
        return 'application/octet-stream';
    }
  }

  static Future<void> downloadFile({
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    // Validaciones básicas antes de proceder
    if (bytes.isEmpty) {
      print('❌ Error: no hay datos para descargar');
      return;
    }

    if (fileName.isEmpty || fileName.trim().isEmpty) {
      print('❌ Error: nombre de archivo inválido');
      return;
    }

    final sanitizedFileName = _sanitizeFileName(fileName);
    if (sanitizedFileName.isEmpty) {
      print('❌ Error: nombre de archivo no válido');
      return;
    }

    if (kIsWeb) {
      await downloadFileWeb(
        bytes: bytes,
        fileName: sanitizedFileName,
        mimeType: mimeType,
      );
    } else {
      print('📱 Plataforma no web, usar método móvil');
      // Aquí podrías implementar la lógica para móvil si es necesario
      _handleNonWebPlatform(bytes, sanitizedFileName, mimeType);
    }
  }

  static void _handleNonWebPlatform(
    Uint8List bytes,
    String fileName,
    String? mimeType,
  ) {
    print('📱 Implementar lógica de descarga para plataforma móvil');
    print('Archivo: $fileName, Tamaño: ${bytes.length} bytes');
    
    // En una implementación real, aquí usarías:
    // - path_provider para obtener directorios
    // - File de dart:io para escribir el archivo
    // - share_plus para compartir o abrir el archivo
  }

  static String _sanitizeFileName(String fileName) {
    if (fileName.isEmpty) return '';
    
    // Reemplazar caracteres no válidos en nombres de archivo
    final sanitized = fileName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_') // Caracteres no permitidos en Windows
        .replaceAll(RegExp(r'[\r\n]'), '') // Quitar saltos de línea
        .replaceAll(RegExp(r'\s+'), ' ') // Reducir múltiples espacios
        .trim();
    
    // Limitar longitud del nombre de archivo (evitar problemas con sistemas de archivos)
    const maxLength = 100;
    if (sanitized.length > maxLength) {
      final extension = sanitized.split('.').last;
      final nameWithoutExtension = sanitized.substring(0, sanitized.lastIndexOf('.'));
      
      if (extension.length >= maxLength) {
        return 'file.$extension'.substring(0, maxLength);
      }
      
      final maxNameLength = maxLength - extension.length - 1;
      final trimmedName = nameWithoutExtension.substring(0, maxNameLength);
      return '$trimmedName.$extension';
    }
    
    return sanitized;
  }

  static void _showErrorMessageToUser(String message) {
    // En un entorno real, esto podría mostrar un SnackBar o diálogo
    // Dado que estamos en una clase helper sin contexto, solo imprimimos
    print('💡 Mensaje para el usuario: $message');
    
    // Alternativa: podrías usar un global key o event bus para notificar a la UI
    // Ejemplo básico:
    try {
      // Intentar mostrar alerta nativa del navegador (solo para debugging)
      if (kIsWeb) {
        html.window.alert('Error: $message');
      }
    } catch (e) {
      print('⚠️ No se pudo mostrar alerta: $e');
    }
  }

  // Método adicional para validar archivos antes de intentar descargar
  static bool validateFileForDownload({
    required Uint8List bytes,
    required String fileName,
    int maxSizeInBytes = 50 * 1024 * 1024, // 50MB por defecto
  }) {
    // Validar bytes
    if (bytes.isEmpty) {
      print('❌ Validación fallida: archivo vacío');
      return false;
    }

    // Validar tamaño máximo
    if (bytes.length > maxSizeInBytes) {
      print('❌ Validación fallida: archivo demasiado grande (${bytes.length} bytes > $maxSizeInBytes bytes)');
      return false;
    }

    // Validar nombre de archivo
    final sanitized = _sanitizeFileName(fileName);
    if (sanitized.isEmpty) {
      print('❌ Validación fallida: nombre de archivo inválido');
      return false;
    }

    // Validar tipo de archivo (opcional, basado en extensión)
    final extension = sanitized.split('.').last.toLowerCase();
    if (extension.isEmpty || extension == sanitized.toLowerCase()) {
      print('⚠️ Advertencia: archivo sin extensión');
      // No fallamos aquí, solo advertimos
    }

    print('✅ Validación exitosa para: $sanitized (${bytes.length} bytes)');
    return true;
  }
}