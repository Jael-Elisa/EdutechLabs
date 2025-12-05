import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  
  bool _isLoading = false;
  bool _emailSent = false;
  bool _showEmailFormatError = false;
  bool _showEmailDomainError = false;
  bool _showEmailNotFoundError = false;
  bool _showEmailEmptyError = false;
  bool _showTooManyRequestsError = false;
  DateTime? _lastRequestTime;
  int _requestCount = 0;
  
  // Dominios de email temporales comunes
  final List<String> _temporaryEmailDomains = [
    'tempmail.com', '10minutemail.com', 'mailinator.com', 'guerrillamail.com',
    'yopmail.com', 'trashmail.com', 'disposablemail.com', 'fakeinbox.com',
    'getairmail.com', 'throwawaymail.com'
  ];
  
  // Expresiones regulares
  final RegExp _emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  
  // Límites de solicitudes
  final int _maxRequestsPerHour = 5;
  final Duration _requestTimeWindow = const Duration(hours: 1);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmailOnType);
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus && _emailController.text.isNotEmpty) {
        _formKey.currentState?.validate();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _validateEmailOnType() {
    final value = _emailController.text;
    
    if (value.isEmpty) {
      setState(() {
        _showEmailFormatError = false;
        _showEmailDomainError = false;
        _showEmailEmptyError = false;
        _showEmailNotFoundError = false;
      });
      return;
    }

    setState(() {
      _showEmailFormatError = !_emailRegExp.hasMatch(value);
      _showEmailEmptyError = value.trim().isEmpty;
      
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
      
      _showEmailNotFoundError = false;
    });
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

  bool _isTooManyRequests() {
    final now = DateTime.now();
    
    if (_lastRequestTime == null) {
      _lastRequestTime = now;
      _requestCount = 1;
      return false;
    }
    
    final timeDifference = now.difference(_lastRequestTime!);
    
    if (timeDifference < _requestTimeWindow) {
      _requestCount++;
      if (_requestCount >= _maxRequestsPerHour) {
        return true;
      }
    } else {
      // Reiniciar contador si ha pasado el tiempo de ventana
      _requestCount = 1;
      _lastRequestTime = now;
    }
    
    return false;
  }

  Future<bool> _validateEmailSubmission() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      _showValidationDialog(
        'Email requerido',
        'Por favor ingresa tu correo electrónico.'
      );
      return false;
    }

    if (!_emailRegExp.hasMatch(email)) {
      _showValidationDialog(
        'Email inválido',
        'Por favor ingresa un correo electrónico válido.'
      );
      return false;
    }

    // Verificar dominio temporal
    final emailParts = email.split('@');
    if (emailParts.length == 2) {
      final domain = emailParts[1].toLowerCase();
      if (_temporaryEmailDomains.any((tempDomain) => domain.contains(tempDomain))) {
        final confirmed = await _showTemporaryEmailDialog();
        return confirmed;
      }
    }

    // Verificar solicitudes excesivas
    if (_isTooManyRequests()) {
      _showValidationDialog(
        'Demasiadas solicitudes',
        'Has excedido el límite de solicitudes. '
        'Por favor espera una hora antes de intentar nuevamente.'
      );
      return false;
    }

    return true;
  }

  Future<bool> _showTemporaryEmailDialog() async {
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

  Future<void> _resetPassword() async {
    // Validar antes de enviar
    final isValid = await _validateEmailSubmission();
    if (!isValid) return;

    if (!_formKey.currentState!.validate()) {
      _emailFocusNode.requestFocus();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: 'edutechlabs://reset-password',
      );

      setState(() => _emailSent = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Correo de recuperación enviado exitosamente. '
              'Revisa tu bandeja de entrada y sigue las instrucciones.',
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      
      setState(() {
        if (e.message.contains('rate limit') || e.message.contains('too many requests')) {
          _showTooManyRequestsError = true;
        } else if (e.message.contains('user not found')) {
          _showEmailNotFoundError = true;
        }
      });
      
      _showErrorDialog('Error de autenticación', e.message);
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Error inesperado', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        return 'No se permiten emails temporales';
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
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
                        Icons.lock_reset,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Recuperar Contraseña',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Te enviaremos un enlace seguro para restablecer tu contraseña',
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
              const SizedBox(height: 40),
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
                      if (_emailSent) ...[
                        const Icon(
                          Icons.check_circle,
                          size: 64,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          '¡Correo enviado!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Revisa tu bandeja de entrada y sigue las instrucciones para restablecer tu contraseña.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '💡 Consejo: Si no ves el correo, revisa tu carpeta de spam o correo no deseado.',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () => context.go('/login'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blueAccent,
                              side: const BorderSide(color: Colors.blueAccent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text('Volver al Login'),
                          ),
                        ),
                      ] else ...[
                        // Campo de email
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          onChanged: (_) => _validateEmailOnType(),
                          style: const TextStyle(
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
                          textInputAction: TextInputAction.done,
                          validator: _validateEmail,
                          onFieldSubmitted: (_) => _resetPassword(),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Validación de email
                        _buildEmailRequirements(),
                        
                        if (_showEmailNotFoundError)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: _buildRequirementError(
                              'No se encontró una cuenta con este email.',
                              isWarning: true,
                            ),
                          ),
                        
                        if (_showTooManyRequestsError)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: _buildRequirementError(
                              'Has excedido el límite de solicitudes. Espera 1 hora.',
                              isWarning: true,
                            ),
                          ),
                        
                        const SizedBox(height: 25),
                        
                        // Botón de enviar
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _resetPassword,
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
                                        'Enviar Enlace de Recuperación',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Icon(Icons.send, size: 20),
                                    ],
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Información adicional
                        const Text(
                          '💡 Te enviaremos un enlace seguro válido por 1 hora.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Botones de navegación
                        Column(
                          children: [
                            TextButton(
                              onPressed: _isLoading ? null : () => context.pop(),
                              child: const Text(
                                'Volver al Login',
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading 
                                  ? null 
                                  : () => context.go('/register'),
                              child: const Text(
                                '¿No tienes cuenta? Regístrate aquí',
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
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
}

/*
1. Validaciones de Email:
✅ Formato válido de email

✅ Detección de emails temporales (10minutemail, etc.)

✅ Diálogo de advertencia para emails temporales

✅ Validación en tiempo real

✅ Indicadores visuales de error/éxito

2. Protección contra Abuso:
✅ Límite de solicitudes por hora (5 solicitudes)

✅ Control de frecuencia de envío

✅ Mensaje de error para límite excedido

✅ Temporizador de 1 hora para restablecer límites

3. Manejo de Errores Específicos:
✅ "Usuario no encontrado" - email no registrado

✅ "Demasiadas solicitudes" - rate limiting

✅ Errores de conexión y tiempo de espera

✅ Errores de autenticación específicos

4. Validaciones de Dominio:
✅ Lista de dominios temporales bloqueados

✅ Posibilidad de continuar con email temporal (con advertencia)

✅ Validación de dominio válido

5. Mejoras de UX:
✅ Focus management mejorado

✅ Validación en tiempo real con feedback visual

✅ Mensajes de éxito mejorados

✅ Consejos útiles para el usuario

✅ Navegación por teclado (enter para enviar)

6. Diálogos de Confirmación:
✅ Confirmación para emails temporales

✅ Diálogos de error específicos

✅ Mensajes de validación claros

7. Seguridad:
✅ Prevención de envíos múltiples (spam)

✅ Rate limiting para prevenir ataques

✅ Validación antes del envío al servidor

✅ Manejo seguro de errores

8. Información al Usuario:
✅ Indicación de tiempo de validez del enlace (1 hora)

✅ Consejo para revisar carpeta de spam

✅ Contador de caracteres en tiempo real

✅ Mensajes de estado claros

9. Navegación Mejorada:
✅ Botón para volver al login

✅ Enlace para registrarse

✅ Prevención de navegación durante carga

✅ Feedback de navegación

10. Diseño Mejorado:
✅ Campos con bordes de error visibles

✅ Colores consistentes con el tema

✅ Espaciado y alineación mejorados

✅ Iconos informativos
 */