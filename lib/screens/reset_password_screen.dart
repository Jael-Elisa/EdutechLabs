import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _passwordUpdated = false;

  bool _showLengthError = false;
  bool _showUppercaseError = false;
  bool _showLowercaseError = false;
  bool _showNumberError = false;
  bool _showSpecialCharError = false;
  bool _showNoSpacesError = false;
  bool _showMaxLengthError = false;
  bool _showCommonPasswordError = false;
  
  // Lista de contraseñas comunes (puedes expandir esta lista)
  final List<String> _commonPasswords = [
    'password', '12345678', 'qwerty123', 'admin123', 'welcome1',
    '123456789', 'password1', '1234567890', 'abcd1234', 'sunshine1',
    'iloveyou1', 'monkey123', 'football1', 'charlie1', 'dragon123'
  ];

  // Expresiones regulares mejoradas
  final RegExp _uppercaseRegExp = RegExp(r'[A-Z]');
  final RegExp _lowercaseRegExp = RegExp(r'[a-z]');
  final RegExp _numberRegExp = RegExp(r'[0-9]');
  final RegExp _specialCharRegExp = RegExp(r'[!@#$%^&*(),.?":{}|<>]');
  final RegExp _noSpacesRegExp = RegExp(r'^\S*$');
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
      
      // También validar confirmación si ya hay texto
      if (_confirmPasswordController.text.isNotEmpty) {
        _validateConfirmPasswordOnType(_confirmPasswordController.text);
      }
    });
  }

  void _validateConfirmPasswordOnType(String value) {
    if (mounted) {
      setState(() {});
    }
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
        else if (password.length > 50)
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

  Future<void> _updatePassword() async {
    if (_passwordUpdated) return;

    // Validar formulario
    if (!_formKey.currentState!.validate()) {
      // Enfocar el primer campo con error
      FocusScope.of(context).requestFocus(FocusNode());
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_passwordController.text.isEmpty) {
          FocusScope.of(context).requestFocus(
            _passwordController.text.isEmpty 
              ? _passwordFocusNode 
              : _confirmPasswordFocusNode
          );
        }
      });
      return;
    }

    // Validaciones adicionales
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

    // Mostrar confirmación antes de actualizar
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.updateUser(
        UserAttributes(password: password),
      );
      
      // Opcional: cerrar todas las sesiones excepto la actual
      await supabase.auth.signOut();
      
      if (!mounted) return;

      setState(() => _passwordUpdated = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Contraseña actualizada exitosamente. '
            'Por seguridad, se ha cerrado tu sesión. '
            'Inicia sesión nuevamente con tu nueva contraseña.',
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) {
        _showErrorDialog('Error de autenticación', e.message);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'Error inesperado',
          'No se pudo actualizar la contraseña. Por favor intenta nuevamente.'
        );
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
        title: const Text('Confirmar cambio'),
        content: const Text(
          '¿Estás seguro de que deseas cambiar tu contraseña? '
          'Se cerrará tu sesión actual por seguridad.'
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
      return 'Por favor ingresa tu nueva contraseña';
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

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor confirma tu contraseña';
    }
    
    if (value.trim() != _passwordController.text.trim()) {
      return 'Las contraseñas no coinciden';
    }
    
    return null;
  }

  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus && _passwordController.text.isNotEmpty) {
        _formKey.currentState?.validate();
      }
    });
    _confirmPasswordFocusNode.addListener(() {
      if (!_confirmPasswordFocusNode.hasFocus && 
          _confirmPasswordController.text.isNotEmpty) {
        _formKey.currentState?.validate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: const Text('Nueva Contraseña'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isLoading) return;
            if (_passwordController.text.isNotEmpty || 
                _confirmPasswordController.text.isNotEmpty) {
              _showExitConfirmation();
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Nueva Contraseña',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Establece una contraseña segura',
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
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(30),
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
                    children: [
                      if (_passwordUpdated) ...[
                        const Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '¡Contraseña Actualizada!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tu contraseña ha sido actualizada exitosamente. '
                          'Por seguridad, se ha cerrado tu sesión. '
                          'Inicia sesión nuevamente con tu nueva contraseña.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => context.go('/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                            ),
                            child: const Text('Ir al Login'),
                          ),
                        ),
                      ] else ...[
                        // Campo de nueva contraseña
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          onChanged: _validatePasswordOnType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Nueva Contraseña',
                            labelStyle: const TextStyle(
                              color: Colors.white70,
                            ),
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
                          validator: _validatePassword,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(
                              _confirmPasswordFocusNode
                            );
                          },
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Requisitos de contraseña
                        _buildPasswordRequirements(),
                        
                        const SizedBox(height: 12),
                        
                        // Indicador de fortaleza
                        _buildPasswordStrengthIndicator(),
                        
                        const SizedBox(height: 20),
                        
                        // Campo de confirmación
                        TextFormField(
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          onChanged: _validateConfirmPasswordOnType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Confirmar Contraseña',
                            labelStyle: const TextStyle(
                              color: Colors.white70,
                            ),
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
                                () => _obscureConfirmPassword = 
                                    !_obscureConfirmPassword,
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
                          validator: _validateConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _updatePassword(),
                        ),
                        
                        const SizedBox(height: 25),
                        
                        // Botón de actualizar
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _updatePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: Colors.blueAccent.withOpacity(0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Actualizar Contraseña',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Icon(Icons.security, size: 20),
                                    ],
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Botón de cancelar
                        TextButton(
                          onPressed: _isLoading 
                              ? null 
                              : () {
                                  if (_passwordController.text.isNotEmpty || 
                                      _confirmPasswordController.text.isNotEmpty) {
                                    _showExitConfirmation();
                                  } else {
                                    context.go('/login');
                                  }
                                },
                          child: Text(
                            'Cancelar',
                            style: TextStyle(
                              color: _isLoading 
                                  ? Colors.grey 
                                  : Colors.blueAccent,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        
                        // Información adicional
                        const SizedBox(height: 10),
                        const Text(
                          '💡 Consejo: Usa una contraseña única que no hayas usado en otros servicios.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text(
          'Tienes cambios sin guardar. '
          '¿Estás seguro de que deseas salir?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/login');
            },
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }
}

/*
1. Validaciones adicionales:
✅ No permitir espacios en la contraseña

✅ Limitar longitud máxima (128 caracteres)

✅ Detectar contraseñas comunes

✅ Detectar secuencias obvias (123, abc, etc.)

✅ Detectar caracteres repetidos excesivos

2. Mejoras en la UI:
✅ Indicadores visuales de éxito/error

✅ Barra de progreso mejorada con puntuación

✅ Mensajes descriptivos de fortaleza

✅ Iconos de check/error en tiempo real

3. Validaciones en tiempo real:
✅ Validación mientras se escribe

✅ Actualización automática de la confirmación

✅ Feedback visual inmediato

4. Manejo de errores mejorado:
✅ Diálogos de confirmación

✅ Diálogos de error específicos

✅ Validación de salida con cambios pendientes

✅ Manejo de excepciones específicas de Supabase

5. Experiencia de usuario:
✅ Focus management mejorado

✅ Navegación por teclado (next/done)

✅ Consejos de seguridad

✅ Confirmación antes de acciones importantes

✅ Prevención de navegación accidental

6. Seguridad adicional:
✅ Lista de contraseñas comunes

✅ Validación de patrones predecibles

✅ Verificación de variedad de caracteres

✅ Puntuación de fortaleza detallada */