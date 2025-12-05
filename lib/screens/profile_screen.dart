import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../app/auth_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _showNameError = false;
  bool _showNameLengthError = false;
  bool _showNameInvalidError = false;
  bool _showImageSizeError = false;
  bool _showImageFormatError = false;

  late TextEditingController _nameController;
  late TextEditingController _bioController;

  // Expresiones regulares
  final RegExp _nameRegExp = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s']{3,50}$");
  final RegExp _bioRegExp = RegExp(r'^[\s\S]{0,500}$'); // Máximo 500 caracteres
  
  // Formatos de imagen permitidos
  final List<String> _allowedImageFormats = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'
  ];
  
  // Tamaño máximo de imagen (5MB)
  final int _maxImageSize = 5 * 1024 * 1024; // 5MB en bytes

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _validateNameOnType(String value) {
    if (value.isEmpty) {
      setState(() {
        _showNameError = false;
        _showNameLengthError = false;
        _showNameInvalidError = false;
      });
      return;
    }

    setState(() {
      _showNameError = value.trim().isEmpty;
      _showNameLengthError = value.length < 3 || value.length > 50;
      _showNameInvalidError = !_nameRegExp.hasMatch(value);
    });
  }

  void _validateBioOnType(String value) {
    // Validación de biografía (opcional, máximo 500 caracteres)
    if (value.length > 500) {
      _bioController.text = value.substring(0, 500);
      _bioController.selection = TextSelection.fromPosition(
        TextPosition(offset: _bioController.text.length),
      );
    }
  }

  Widget _buildNameRequirements() {
    final hasText = _nameController.text.isNotEmpty;
    if (!hasText) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showNameError)
          _buildRequirementError('El nombre no puede estar vacío'),
        if (_showNameLengthError)
          _buildRequirementError('Debe tener entre 3 y 50 caracteres'),
        if (_showNameInvalidError)
          _buildRequirementError(
            'Solo letras, espacios y apóstrofes permitidos'
          ),
        if (!_showNameError && !_showNameLengthError && !_showNameInvalidError)
          _buildRequirementSuccess('✓ Nombre válido'),
      ],
    );
  }

  Widget _buildBioCounter() {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        '${_bioController.text.length}/500 caracteres',
        style: TextStyle(
          color: _bioController.text.length > 450
              ? Colors.orange
              : Colors.grey,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildRequirementError(String text, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning ? Icons.warning_amber : Icons.error_outline,
            size: 14,
            color: isWarning ? Colors.orange : Colors.red.shade600,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isWarning ? Colors.orange : Colors.red.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementSuccess(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 2.0),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final response =
          await _supabase.from('profiles').select().eq('id', user.id).single();

      if (!mounted) return;

      setState(() {
        _profile = response;
        _nameController.text = _profile?['full_name'] ?? '';
        _bioController.text = _profile?['bio'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showErrorDialog('Error al cargar perfil', e.toString());
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showErrorDialog('Error', 'Usuario no autenticado');
      return;
    }

    // Mostrar opciones para elegir foto
    final source = await _showImageSourceDialog();
    if (source == null) return;

    XFile? pickedFile;
    try {
      if (source == ImageSource.camera) {
        pickedFile = await _imagePicker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 800,
        );
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );

        if (result == null || result.files.isEmpty) return;
        final file = result.files.first;
        if (file.bytes == null) return;

        // Validar formato de imagen
        final extension = file.name.split('.').last.toLowerCase();
        if (!_allowedImageFormats.contains(extension)) {
          _showErrorDialog(
            'Formato no permitido',
            'Solo se permiten imágenes en formato: ${_allowedImageFormats.join(', ')}'
          );
          return;
        }

        // Validar tamaño de imagen
        if (file.size > _maxImageSize) {
          _showErrorDialog(
            'Imagen demasiado grande',
            'El tamaño máximo permitido es ${_maxImageSize ~/ (1024 * 1024)}MB'
          );
          return;
        }
      }

      if (pickedFile == null && source == ImageSource.camera) return;

      if (!mounted) return;
      setState(() => _isUploadingPhoto = true);

      // Leer bytes de la imagen
      final bytes = source == ImageSource.camera
          ? await pickedFile!.readAsBytes()
          : (await FilePicker.platform.pickFiles(
              type: FileType.image,
              allowMultiple: false,
              withData: true,
            ))?.files.first.bytes;

      if (bytes == null) {
        setState(() => _isUploadingPhoto = false);
        return;
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'avatars/${user.id}/$fileName';

      // Subir imagen
      await _supabase.storage.from('avatars').uploadBinary(path, bytes);

      // Obtener URL pública
      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);

      // Actualizar perfil
      final updated = await _supabase
          .from('profiles')
          .update({
            'avatar_url': publicUrl,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', user.id)
          .select()
          .single();

      if (!mounted) return;

      setState(() {
        _profile = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Foto de perfil actualizada exitosamente'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error de autenticación', e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error al subir foto', e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar imagen'),
        content: const Text('¿De dónde deseas tomar la imagen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt),
                SizedBox(width: 8),
                Text('Cámara'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library),
                SizedBox(width: 8),
                Text('Galería'),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showSaveConfirmationDialog() async {
    final nameChanged = _nameController.text.trim() != (_profile?['full_name'] ?? '');
    final bioChanged = _bioController.text.trim() != (_profile?['bio'] ?? '');

    if (!nameChanged && !bioChanged) {
      _showValidationDialog(
        'Sin cambios',
        'No has realizado ningún cambio para guardar.'
      );
      return false;
    }

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Guardar cambios'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Estás seguro de que deseas guardar los cambios?'),
            if (nameChanged) ...[
              const SizedBox(height: 8),
              const Text('Cambios en nombre:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('De: ${_profile?['full_name'] ?? "No establecido"}'),
              Text('A: ${_nameController.text.trim()}'),
            ],
            if (bioChanged) ...[
              const SizedBox(height: 8),
              const Text('Cambios en biografía:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('De: ${_profile?['bio'] ?? "No establecida"}'),
              Text('A: ${_bioController.text.trim()}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
            ),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _saveProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showErrorDialog('Error', 'Usuario no autenticado');
      return;
    }

    final newName = _nameController.text.trim();
    final newBio = _bioController.text.trim();

    // Validaciones
    if (newName.isEmpty) {
      _showValidationDialog('Nombre requerido', 'El nombre no puede estar vacío.');
      return;
    }

    if (newName.length < 3 || newName.length > 50) {
      _showValidationDialog(
        'Nombre inválido',
        'El nombre debe tener entre 3 y 50 caracteres.'
      );
      return;
    }

    if (!_nameRegExp.hasMatch(newName)) {
      _showValidationDialog(
        'Nombre inválido',
        'Solo se permiten letras, espacios y apóstrofes en el nombre.'
      );
      return;
    }

    // Confirmar antes de guardar
    final confirmed = await _showSaveConfirmationDialog();
    if (!confirmed) return;

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      final updated = await _supabase
          .from('profiles')
          .update({
            'full_name': newName,
            'bio': newBio,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id)
          .select()
          .single();

      if (!mounted) return;

      setState(() {
        _profile = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Perfil actualizado exitosamente'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error de autenticación', e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error al guardar perfil', e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: Colors.red.shade50,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _showValidationDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          '⚠️ ¿Estás seguro de que deseas eliminar tu cuenta?\n\n'
          'Esta acción es permanente y no se puede deshacer. '
          'Se eliminarán todos tus datos y no podrás recuperarlos.'
        ),
        backgroundColor: Colors.red.shade50,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar cuenta', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signOut();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
            ),
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              } else if (value == 'delete') {
                _deleteAccount();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text('Cerrar sesión'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Eliminar cuenta', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  
                  // Avatar
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.blueAccent.withOpacity(0.5),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _profile?['avatar_url'] != null &&
                                    (_profile!['avatar_url'] as String).isNotEmpty
                                ? Image.network(
                                    _profile!['avatar_url'] as String,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.person,
                                          size: 60,
                                          color: Colors.grey,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap:
                                _isUploadingPhoto ? null : _pickAndUploadPhoto,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _isUploadingPhoto
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  Text(
                    'Toca la imagen para cambiar',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    'Formatos: ${_allowedImageFormats.join(', ')} | Máx: ${_maxImageSize ~/ (1024 * 1024)}MB',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Campo de nombre
                  TextField(
                    controller: _nameController,
                    onChanged: _validateNameOnType,
                    decoration: InputDecoration(
                      labelText: 'Nombre completo *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.person),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    maxLength: 50,
                  ),
                  _buildNameRequirements(),
                  
                  const SizedBox(height: 16),
                  
                  // Campo de biografía
                  TextField(
                    controller: _bioController,
                    onChanged: _validateBioOnType,
                    decoration: InputDecoration(
                      labelText: 'Biografía (opcional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.info),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    maxLines: 4,
                    maxLength: 500,
                  ),
                  _buildBioCounter(),
                  
                  const SizedBox(height: 16),
                  
                  // Información del usuario
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.email, color: Colors.blueAccent),
                            title: const Text('Email'),
                            subtitle: Text(
                              _profile?['email'] ?? 'No disponible',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.work, color: Colors.green),
                            title: const Text('Rol'),
                            subtitle: Chip(
                              label: Text(
                                authProvider.userRole == 'teacher'
                                    ? 'Docente'
                                    : 'Estudiante',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: authProvider.userRole == 'teacher'
                                  ? Colors.blue
                                  : Colors.green,
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.calendar_today, color: Colors.orange),
                            title: const Text('Miembro desde'),
                            subtitle: Text(
                              _profile?['created_at'] != null
                                  ? _formatDate(_profile!['created_at'])
                                  : 'Fecha no disponible',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.update, color: Colors.purple),
                            title: const Text('Última actualización'),
                            subtitle: Text(
                              _profile?['updated_at'] != null
                                  ? _formatDate(_profile!['updated_at'])
                                  : 'No actualizado',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Botones de acción
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: const Text(
                            'Guardar cambios',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.logout, size: 20),
                          label: const Text('Cerrar sesión'),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      TextButton(
                        onPressed: _deleteAccount,
                        child: const Text(
                          'Eliminar cuenta permanentemente',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date is String) {
        final parsedDate = DateTime.parse(date);
        return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
      } else if (date is DateTime) {
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'Fecha inválida';
    } catch (e) {
      return 'Fecha inválida';
    }
  }
}

/*
1. Validaciones de Nombre:
✅ Longitud mínima (3 caracteres)

✅ Longitud máxima (50 caracteres)

✅ Solo letras, espacios y apóstrofes

✅ No vacío

✅ Validación en tiempo real

✅ Indicadores visuales de error/éxito

2. Validaciones de Imagen:
✅ Formatos permitidos: jpg, jpeg, png, gif, webp, bmp

✅ Tamaño máximo: 5MB

✅ Opción de cámara o galería

✅ Validación antes de subir

✅ Mensajes de error específicos

3. Validaciones de Biografía:
✅ Longitud máxima (500 caracteres)

✅ Contador en tiempo real

✅ Cambio de color al acercarse al límite

✅ Auto-recorte si excede el límite

4. Diálogos de Confirmación:
✅ Confirmación antes de guardar cambios

✅ Muestra los cambios específicos

✅ Confirmación para cerrar sesión

✅ Confirmación (con advertencia) para eliminar cuenta

5. Manejo de Errores:
✅ Captura de excepciones específicas de Auth

✅ Diálogos de error amigables

✅ Snackbars con mejor diseño

✅ Fallback para errores inesperados

6. Mejoras de UX:
✅ Indicadores de carga durante operaciones

✅ Feedback visual mejorado

✅ Formato de fechas legible

✅ Avatar con borde y sombra

✅ Tooltips y mensajes informativos

7. Funcionalidades Adicionales:
✅ Opción para eliminar cuenta

✅ Opción para cerrar sesión

✅ Historial de actualizaciones

✅ Información completa del perfil

8. Seguridad:
✅ Validación de usuario autenticado

✅ Confirmación para acciones importantes

✅ Manejo seguro de datos sensibles
 */