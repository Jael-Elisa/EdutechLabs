import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../app/auth_provider.dart';
// Importa las nuevas pantallas
import 'teacher/teacher_courses_screen.dart';
import 'teacher/course_creation_screen.dart';
import 'teacher/teacher_materials_screen.dart';
import 'student/student_courses_screen.dart';
import 'student/student_materials_screen.dart';
import 'student/grades_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _teacherScreens = [
    const TeacherCoursesScreen(),
    const CourseCreationScreen(),
    const TeacherMaterialsScreen(),
    const ProfileScreen(),
  ];

  final List<Widget> _studentScreens = [
    const StudentCoursesScreen(),
    const StudentMaterialsScreen(),
    const GradesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userRole = authProvider.userRole ?? 'student';
    
    final screens = userRole == 'teacher' ? _teacherScreens : _studentScreens;
    final bottomNavItems = userRole == 'teacher' 
      ? _teacherBottomNavItems 
      : _studentBottomNavItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edutech Labs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              context.go('/login');
            },
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: bottomNavItems,
      ),
    );
  }

  final _teacherBottomNavItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Mis Cursos'),
    BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Crear Curso'),
    BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Materiales'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
  ];

  final _studentBottomNavItems = const [
    BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Cursos'),
    BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Materiales'),
    BottomNavigationBarItem(icon: Icon(Icons.grade), label: 'Calificaciones'),
    BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
  ];
}