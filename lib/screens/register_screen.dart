import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../app/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  String _selectedRole = 'student';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _showLengthError = false;
  bool _showUppercaseError = false;
  bool _showLowercaseError = false;
  bool _showNumberError = false;
  bool _showSpecialCharError = false;
  bool _showNoSpacesError = false;
  bool _showMaxLengthError = false;
  bool _showCommonPasswordError = false;
  bool _showEmailFormatError = false;
  bool _showEmailDomainError = false;
  
  // Lista de contraseñas comunes
  final List<String> _commonPasswords = [
    'password', '12345678', 'qwerty123', 'admin123', 'welcome1',
    '123456789', 'password1', '1234567890', 'abcd1234', 'sunshine1',
    'iloveyou1', 'monkey123', 'football1', 'charlie1', 'dragon123'
  ];
  
  // Dominios de email temporales comunes
  final List<String> _temporaryEmailDomains = [
    'tempmail.com', '10minutemail.com', 'mailinator.com', 'guerrillamail.com',
    'yopmail.com', 'trashmail.com', 'disposablemail.com', 'fakeinbox.com',
    'getairmail.com', 'throwawaymail.com'
  ];

  // Expresiones regulares mejoradas
  final RegExp _uppercaseRegExp = RegExp(r'[A-Z]');
  final RegExp _lowercaseRegExp = RegExp(r'[a-z]');
  final RegExp _numberRegExp = RegExp(r'[0-9]');
  final RegExp _specialCharRegExp = RegExp(r'[!@#$%^&*(),.?":{}|<>]');
  final RegExp _noSpacesRegExp = RegExp(r'^\S*$');
  final RegExp _emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  final RegExp _nameRegExp = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s']{3,50}$");
  final RegExp _noSequentialChars = RegExp(r'(abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz|012|123|234|345|456|567|678|789|890)', caseSensitive: false);
  final RegExp _noRepeatedChars = RegExp(r'(.)\1{2,}');

  void _validatePasswordOnType(String value) {
    if (value.isEmpty) {
      setState(() {
        _showLengthError = false;
        _showUppercaseError = false;
        _showLowercaseError = false;
        _showNumberError = false;
        _showSpecialCharError = false;
        _showNoSpacesError = false;
        _showMaxLengthError = false;
        _showCommonPasswordError = false;
      });
      return;
    }

    setState(() {
      _showLengthError = value.length < 8;
      _showUppercaseError = !_uppercaseRegExp.hasMatch(value);
      _showLowercaseError = !_lowercaseRegExp.hasMatch(value);
      _showNumberError = !_numberRegExp.hasMatch(value);
      _showSpecialCharError = !_specialCharRegExp.hasMatch(value);
      _showNoSpacesError = !_noSpacesRegExp.hasMatch(value);
      _showMaxLengthError = value.length > 128;
      _showCommonPasswordError = _commonPasswords.contains(value.toLowerCase());
    });
  }

  void _validateEmailOnType(String value) {
    if (value.isEmpty) {
      setState(() {
        _showEmailFormatError = false;
        _showEmailDomainError = false;
      });
      return;
    }

    setState(() {
      _showEmailFormatError = !_emailRegExp.hasMatch(value);
      
      // Verificar si es un dominio temporal
      if (!_showEmailFormatError) {
        final emailParts = value.split('@');
        if (emailParts.length == 2) {
          final domain = emailParts[1].toLowerCase();
          _showEmailDomainError = _temporaryEmailDomains.any(
            (tempDomain) => domain.contains(tempDomain)
          );
        } else {
          _showEmailDomainError = false;
        }
      } else {
        _showEmailDomainError = false;
      }
    });
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

  Widget _buildEmailRequirements() {
    final hasText = _emailController.text.isNotEmpty;
    if (!hasText) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Validación de email:',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        if (_showEmailFormatError)
          _buildRequirementError('Formato de email inválido')
        else
          _buildRequirementSuccess('✓ Formato válido'),
        
        if (_showEmailDomainError)
          _buildRequirementError(
            'Email temporal detectado. Usa un email permanente.',
            isWarning: true,
          ),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    final hasText = _passwordController.text.isNotEmpty;
    final password = _passwordController.text;
    
    if (!hasText) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Requisitos de seguridad:',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // Requisitos principales
        if (_showLengthError)
          _buildRequirementError('Debe tener al menos 8 caracteres')
        else
          _buildRequirementSuccess('✓ Al menos 8 caracteres'),
        
        if (_showUppercaseError)
          _buildRequirementError('Debe tener al menos una mayúscula (A-Z)')
        else if (hasText)
          _buildRequirementSuccess('✓ Al menos una mayúscula'),
        
        if (_showLowercaseError)
          _buildRequirementError('Debe tener al menos una minúscula (a-z)')
        else if (hasText)
          _buildRequirementSuccess('✓ Al menos una minúscula'),
        
        if (_showNumberError)
          _buildRequirementError('Debe tener al menos un número (0-9)')
        else if (hasText)
          _buildRequirementSuccess('✓ Al menos un número'),
        
        if (_showSpecialCharError)
          _buildRequirementError('Al menos un carácter especial (!@#\$%^&*)')
        else if (hasText)
          _buildRequirementSuccess('✓ Al menos un carácter especial'),
        
        if (_showNoSpacesError)
          _buildRequirementError('No debe contener espacios')
        else if (hasText)
          _buildRequirementSuccess('✓ Sin espacios'),
        
        if (_showMaxLengthError)
          _buildRequirementError('Máximo 128 caracteres')
        else if (password.length > 20)
          _buildRequirementSuccess('✓ Longitud adecuada'),
        
        if (_showCommonPasswordError)
          _buildRequirementError('Contraseña demasiado común', isWarning: true),
        
        // Validaciones adicionales
        if (hasText && password.length >= 8 && password.length <= 128)
          _buildPasswordAdditionalValidations(password),
      ],
    );
  }

  Widget _buildPasswordAdditionalValidations(String password) {
    final validations = <Widget>[];
    
    // Validar secuencias
    if (_noSequentialChars.hasMatch(password)) {
      validations.add(
        _buildRequirementError('Evita secuencias como "123" o "abc"', isWarning: true)
      );
    } else {
      validations.add(
        const Text(
          '✓ Sin secuencias obvias',
          style: TextStyle(fontSize: 12, color: Colors.green),
        )
      );
    }
    
    // Validar caracteres repetidos
    if (_noRepeatedChars.hasMatch(password)) {
      validations.add(
        _buildRequirementError('Evita muchos caracteres repetidos', isWarning: true)
      );
    }
    
    // Validar variedad de caracteres
    final uniqueChars = password.split('').toSet().length;
    if (uniqueChars < 5 && password.length >= 8) {
      validations.add(
        _buildRequirementError('Usa más variedad de caracteres', isWarning: true)
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: validations,
    );
  }

  Future<void> _register() async {
    // Validar formulario
    if (!_formKey.currentState!.validate()) {
      // Enfocar el primer campo con error
      FocusScope.of(context).requestFocus(FocusNode());
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_fullNameController.text.isEmpty) {
          _nameFocusNode.requestFocus();
        } else if (_emailController.text.isEmpty || _showEmailFormatError) {
          _emailFocusNode.requestFocus();
        } else if (_passwordController.text.isEmpty) {
          _passwordFocusNode.requestFocus();
        } else if (_confirmPasswordController.text.isEmpty) {
          _confirmPasswordFocusNode.requestFocus();
        }
      });
      return;
    }

    // Validaciones adicionales de contraseña
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      _showValidationDialog(
        'Las contraseñas no coinciden',
        'Por favor verifica que ambas contraseñas sean idénticas.'
      );
      return;
    }

    // Validar contraseña común
    if (_commonPasswords.contains(password.toLowerCase())) {
      _showValidationDialog(
        'Contraseña demasiado común',
        'Por tu seguridad, elige una contraseña menos predecible.'
      );
      return;
    }

    // Validar secuencias
    if (_noSequentialChars.hasMatch(password)) {
      _showValidationDialog(
        'Patrón detectado',
        'Tu contraseña contiene secuencias que son fáciles de adivinar.'
      );
      return;
    }

    // Validar caracteres repetidos
    if (_noRepeatedChars.hasMatch(password)) {
      _showValidationDialog(
        'Caracteres repetidos',
        'Evita usar el mismo carácter muchas veces seguidas.'
      );
      return;
    }

    // Validar email temporal
    if (_showEmailDomainError) {
      final confirmed = await _showEmailWarningDialog();
      if (!confirmed) return;
    }

    // Mostrar confirmación antes de registrar
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().signUp(
        _emailController.text.trim(),
        _passwordController.text,
        _fullNameController.text.trim(),
        _selectedRole,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Registro exitoso. '
              'Revisa tu email para verificar tu cuenta antes de iniciar sesión.',
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        context.go('/login');
      }
        } catch (e) {
      if (context.mounted) {
        _showErrorDialog('Error de registro', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar registro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Estás seguro de que deseas crear la cuenta con estos datos?'),
            const SizedBox(height: 10),
            Text('Nombre: ${_fullNameController.text.trim()}'),
            Text('Email: ${_emailController.text.trim()}'),
            Text('Rol: ${_selectedRole == 'student' ? 'Estudiante' : 'Docente'}'),
            const SizedBox(height: 10),
            const Text(
              'Recibirás un email de verificación para activar tu cuenta.',
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
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
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<bool> _showEmailWarningDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email temporal detectado'),
        content: const Text(
          'Has usado un dominio de email temporal. '
          'Estos emails no son recomendados para cuentas importantes. '
          '¿Deseas continuar de todos modos?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Usar otro email'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    ) ?? false;
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

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu contraseña';
    }

    final trimmedValue = value.trim();

    if (trimmedValue.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }

    if (trimmedValue.length > 128) {
      return 'La contraseña no puede exceder 128 caracteres';
    }

    if (!_uppercaseRegExp.hasMatch(trimmedValue)) {
      return 'Debe contener al menos una letra mayúscula (A-Z)';
    }

    if (!_lowercaseRegExp.hasMatch(trimmedValue)) {
      return 'Debe contener al menos una letra minúscula (a-z)';
    }

    if (!_numberRegExp.hasMatch(trimmedValue)) {
      return 'Debe contener al menos un número (0-9)';
    }

    if (!_specialCharRegExp.hasMatch(trimmedValue)) {
      return 'Debe contener al menos un carácter especial (!@#\$%^&* etc.)';
    }

    if (!_noSpacesRegExp.hasMatch(trimmedValue)) {
      return 'La contraseña no debe contener espacios';
    }

    if (_commonPasswords.contains(trimmedValue.toLowerCase())) {
      return 'Esta contraseña es demasiado común. Elige una más segura';
    }

    if (_noSequentialChars.hasMatch(trimmedValue)) {
      return 'Evita secuencias obvias como "123" o "abc"';
    }

    if (_noRepeatedChars.hasMatch(trimmedValue)) {
      return 'Evita muchos caracteres repetidos seguidos';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu correo electrónico';
    }

    final trimmedValue = value.trim();

    if (!_emailRegExp.hasMatch(trimmedValue)) {
      return 'Ingresa un correo electrónico válido';
    }

    // Verificar dominio temporal
    final emailParts = trimmedValue.split('@');
    if (emailParts.length == 2) {
      final domain = emailParts[1].toLowerCase();
      if (_temporaryEmailDomains.any((tempDomain) => domain.contains(tempDomain))) {
        return 'No se permiten emails temporales. Usa un email permanente.';
      }
    }

    return null;
  }

  String? _validateFullName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingresa tu nombre completo';
    }

    final trimmedValue = value.trim();

    if (trimmedValue.length < 3) {
      return 'El nombre debe tener al menos 3 caracteres';
    }

    if (trimmedValue.length > 50) {
      return 'El nombre no puede exceder 50 caracteres';
    }

    if (!_nameRegExp.hasMatch(trimmedValue)) {
      return 'Ingresa un nombre válido (solo letras, espacios y apóstrofes)';
    }

    // Validar que tenga al menos un nombre y un apellido
    final nameParts = trimmedValue.split(' ').where((part) => part.isNotEmpty).toList();
    if (nameParts.length < 2) {
      return 'Ingresa tu nombre y apellido';
    }

    for (final part in nameParts) {
      if (part.length < 2) {
        return 'Cada parte del nombre debe tener al menos 2 caracteres';
      }
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor confirma tu contraseña';
    }
    
    if (value.trim() != _passwordController.text.trim()) {
      return 'Las contraseñas no coinciden';
    }
    
    return null;
  }

  // Focus nodes para manejar la navegación
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && _fullNameController.text.isNotEmpty) {
        _formKey.currentState?.validate();
      }
    });
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus && _emailController.text.isNotEmpty) {
        _formKey.currentState?.validate();
      }
    });
    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus && _passwordController.text.isNotEmpty) {
        _formKey.currentState?.validate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxContentWidth =
              constraints.maxWidth > 900 ? 720.0 : constraints.maxWidth * 0.95;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1A237E),
                            Color(0xFF283593),
                            Color(0xFF303F9F),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.shade900.withOpacity(0.5),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.school,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Edutech Labs',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Crea tu cuenta para comenzar',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2337),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.blue.shade800.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Crear Cuenta',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Completa tus datos para registrarte',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            
                            // Campo de nombre completo
                            TextFormField(
                              controller: _fullNameController,
                              focusNode: _nameFocusNode,
                              style: const TextStyle(
                                height: 1,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Nombre completo',
                                labelStyle: const TextStyle(color: Colors.white70),
                                prefixIcon: const Icon(
                                  Icons.person,
                                  color: Colors.blueAccent,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF2A3045),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                errorStyle: TextStyle(
                                  color: Colors.red.shade300,
                                  fontSize: 12,
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade400,
                                    width: 1,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade400,
                                    width: 2,
                                  ),
                                ),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: _validateFullName,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).requestFocus(_emailFocusNode);
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Campo de email
                            TextFormField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              onChanged: _validateEmailOnType,
                              style: const TextStyle(
                                height: 1,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Correo electrónico',
                                labelStyle: const TextStyle(color: Colors.white70),
                                prefixIcon: const Icon(
                                  Icons.email,
                                  color: Colors.blueAccent,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF2A3045),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                errorStyle: TextStyle(
                                  color: Colors.red.shade300,
                                  fontSize: 12,
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade400,
                                    width: 1,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade400,
                                    width: 2,
                                  ),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: _validateEmail,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).requestFocus(_passwordFocusNode);
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildEmailRequirements(),
                            const SizedBox(height: 16),
                            
                            // Campo de rol
                            DropdownButtonFormField<String>(
                              value: _selectedRole,
                              dropdownColor: const Color(0xFF2A3045),
                              decoration: InputDecoration(
                                labelText: 'Rol',
                                labelStyle: const TextStyle(color: Colors.white70),
                                prefixIcon: const Icon(
                                  Icons.work,
                                  color: Colors.blueAccent,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF2A3045),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                              ),
                              iconEnabledColor: Colors.white70,
                              style: const TextStyle(color: Colors.white),
                              items: const [
                                DropdownMenuItem(
                                  value: 'student',
                                  child: Text('Estudiante'),
                                ),
                                DropdownMenuItem(
                                  value: 'teacher',
                                  child: Text('Docente'),
                                ),
                              ],
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() => _selectedRole = value!);
                                    },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Selecciona un rol';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Campo de contraseña
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              onChanged: _validatePasswordOnType,
                              style: const TextStyle(
                                height: 1,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                labelStyle: const TextStyle(color: Colors.white70),
                                prefixIcon: const Icon(
                                  Icons.lock,
                                  color: Colors.blueAccent,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF2A3045),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                                errorStyle: TextStyle(
                                  color: Colors.red.shade300,
                                  fontSize: 12,
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade400,
                                    width: 1,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade400,
                                    width: 2,
                                  ),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              validator: _validatePassword,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildPasswordRequirements(),
                            const SizedBox(height: 8),
                            _buildPasswordStrengthIndicator(),
                            const SizedBox(height: 16),
                            
                            // Campo de confirmar contraseña
                            TextFormField(
                              controller: _confirmPasswordController,
                              focusNode: _confirmPasswordFocusNode,
                              style: const TextStyle(
                                height: 1,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Confirmar contraseña',
                                labelStyle: const TextStyle(color: Colors.white70),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Colors.blueAccent,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF2A3045),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                                  ),
                                ),
                                errorStyle: TextStyle(
                                  color: Colors.red.shade300,
                                  fontSize: 12,
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade400,
                                    width: 1,
                                  ),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.red.shade400,
                                    width: 2,
                                  ),
                                ),
                              ),
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _register(),
                              validator: _validateConfirmPassword,
                            ),
                            const SizedBox(height: 24),
                            
                            // Botón de registro
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shadowColor: Colors.blueAccent.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'Registrarse',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Información adicional
                            const Text(
                              '💡 Consejo: Usa un email permanente y una contraseña única que no hayas usado en otros servicios.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            
                            // Enlace a login
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => context.go('/login'),
                              child: const Text(
                                '¿Ya tienes cuenta? Inicia sesión aquí',
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = _passwordController.text;
    if (password.isEmpty) return const SizedBox.shrink();

    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++; // Bonus por longitud extra
    if (_uppercaseRegExp.hasMatch(password)) score++;
    if (_lowercaseRegExp.hasMatch(password)) score++;
    if (_numberRegExp.hasMatch(password)) score++;
    if (_specialCharRegExp.hasMatch(password)) score++;
    if (!_noSequentialChars.hasMatch(password)) score++;
    if (!_noRepeatedChars.hasMatch(password)) score++;
    if (!_commonPasswords.contains(password.toLowerCase())) score++;
    if (password.length <= 128 && password.length > 20) score++; // Bonus por longitud óptima

    // Normalizar a un valor entre 0 y 1 para la barra de progreso
    final double value = score.clamp(0, 10) / 10.0;

    String strengthText;
    Color strengthColor;
    String description;

    if (score <= 3) {
      strengthText = 'Muy débil';
      strengthColor = Colors.red;
      description = 'Fácil de adivinar';
    } else if (score <= 5) {
      strengthText = 'Débil';
      strengthColor = Colors.orange;
      description = 'Mejorable';
    } else if (score <= 7) {
      strengthText = 'Media';
      strengthColor = Colors.amber;
      description = 'Aceptable';
    } else if (score <= 9) {
      strengthText = 'Fuerte';
      strengthColor = Colors.lightGreen;
      description = 'Buena seguridad';
    } else {
      strengthText = 'Muy fuerte';
      strengthColor = Colors.green;
      description = 'Excelente seguridad';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Seguridad: ',
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 14,
              ),
            ),
            Text(
              strengthText,
              style: TextStyle(
                color: strengthColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '$score/10',
              style: TextStyle(
                color: strengthColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.grey.shade800,
          valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            color: strengthColor,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }
}

/*
1. Validaciones de Nombre Completo:
✅ Longitud mínima (3) y máxima (50) caracteres

✅ Solo permite letras, espacios y apóstrofes

✅ Requiere nombre y apellido (al menos dos palabras)

✅ Cada parte del nombre debe tener al menos 2 caracteres

2. Validaciones de Email:
✅ Formato de email válido

✅ Detección de emails temporales (10minutemail, etc.)

✅ Diálogo de advertencia para emails temporales

✅ Validación en tiempo real

3. Validaciones de Contraseña (igual que en reset password):
✅ Longitud 8-128 caracteres

✅ Mayúsculas, minúsculas, números y caracteres especiales

✅ No espacios

✅ No contraseñas comunes

✅ No secuencias obvias (123, abc, etc.)

✅ No caracteres repetidos excesivos

✅ Barra de fortaleza mejorada

4. Manejo de Foco:
✅ Focus nodes para cada campo

✅ Navegación automática con teclado

✅ Enfoque automático al primer campo con error

5. Diálogos de Confirmación:
✅ Diálogo de confirmación antes del registro

✅ Muestra todos los datos ingresados

✅ Diálogo de advertencia para emails temporales

✅ Diálogos de error específicos

6. Mejoras de UX:
✅ Mensajes de éxito/error mejorados

✅ Consejos de seguridad visibles

✅ Validación en tiempo real mejorada

✅ Snackbars más informativos

7. Manejo de Errores:
✅ Captura de excepciones específicas de Auth

✅ Mensajes de error amigables

✅ Fallback para errores inesperados

8. Validaciones Adicionales:
✅ Contraseña demasiado corta/larga

✅ Dominios de email bloqueados

✅ Patrones de contraseña predecibles

✅ Variedad de caracteres
 */