import 'package:flutter/material.dart';

class StudentMaterialsScreen extends StatelessWidget {
  const StudentMaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Materiales del Curso',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Aquí verás los materiales de tus cursos'),
          ],
        ),
      ),
    );
  }
}