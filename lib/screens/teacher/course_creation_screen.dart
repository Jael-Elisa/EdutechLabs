import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CourseCreationScreen extends StatefulWidget {
  const CourseCreationScreen({super.key});

  @override
  State<CourseCreationScreen> createState() => _CourseCreationScreenState();
}

class _CourseCreationScreenState extends State<CourseCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _courseNameController = TextEditingController();
  final _courseDescriptionController = TextEditingController();
  final _courseCategoryController = TextEditingController();
  final _courseCodeController = TextEditingController(); // Opcional: solo para mostrar en UI
  bool _isLoading = false;

  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> _createCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Obtener el usuario actual
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes iniciar sesión para crear un curso'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Insertar el curso en la base de datos
      await supabase.from('courses').insert({
        'title': _courseNameController.text.trim(),
        'description': _courseDescriptionController.text.trim(),
        'category': _courseCategoryController.text.trim(),
        'teacher_id': user.id.toString(),
      }).select();

      setState(() => _isLoading = false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Curso creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/teacher/courses');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear el curso: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nuevo Curso'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : () => context.go('/teacher/courses'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Icon(Icons.library_add, size: 60, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                'Crear Nuevo Curso',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              // Nombre del curso
              TextFormField(
                controller: _courseNameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Curso',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa el nombre del curso';
                  }
                  if (value.trim().length < 3) {
                    return 'El nombre debe tener al menos 3 caracteres';
                  }
                  if (value.trim().length > 100) {
                    return 'El nombre no puede superar los 100 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Código del curso (opcional: solo UI, no se guarda en Supabase)
              TextFormField(
                controller: _courseCodeController,
                decoration: const InputDecoration(
                  labelText: 'Código del Curso (opcional)',
                  prefixIcon: Icon(Icons.code),
                  border: OutlineInputBorder(),
                  hintText: 'Ej: MAT-101',
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final regex = RegExp(r'^[A-Z]{3,5}-\d{3}$');
                    if (!regex.hasMatch(value.trim().toUpperCase())) {
                      return 'Formato inválido. Ejemplo: MAT-101';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Categoría
              TextFormField(
                controller: _courseCategoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Matemáticas, Programación, etc.',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa la categoría';
                  }
                  if (value.trim().length < 3) {
                    return 'La categoría debe tener al menos 3 caracteres';
                  }
                  if (RegExp(r'[<>"]').hasMatch(value)) {
                    return 'La categoría contiene caracteres inválidos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Descripción
              TextFormField(
                controller: _courseDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor ingresa una descripción';
                  }
                  if (value.trim().length < 10) {
                    return 'La descripción debe tener al menos 10 caracteres';
                  }
                  if (value.trim().length > 500) {
                    return 'La descripción no puede superar los 500 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              // Botón Crear
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createCourse,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear Curso'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _courseNameController.dispose();
    _courseDescriptionController.dispose();
    _courseCategoryController.dispose();
    _courseCodeController.dispose();
    super.dispose();
  }
}

/*
  ✅ Validaciones completas en todos los campos
  ✅ Validación del formato del código (solo UI)
  ✅ Insert correctamente sin columna inexistente
  ✅ Manejo de errores y context.mounted
  ✅ Bloqueo de botón mientras carga
  ✅ Limpieza de controllers
  ✅ Manejo de usuario no autenticado
  ✅ Navegación correcta
*/
    
      