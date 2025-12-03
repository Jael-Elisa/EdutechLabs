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
import '../widgets/notifications_icon_button.dart';

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
    final bottomNavItems =
        userRole == 'teacher' ? _teacherBottomNavItems : _studentBottomNavItems;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: const Text(
          'Edutech Labs',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (userRole == 'student') const NotificationsIconButton(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authProvider.signOut();
              context.go('/login');
            },
          ),
          // Badge de rol de usuario
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
            ),
            child: Text(
              userRole == 'teacher' ? 'Profesor' : 'Estudiante',
              style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.logout,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            onPressed: () async {
              final shouldLogout = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF1E2337),
                  title: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    '¿Estás seguro de que quieres cerrar sesión?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Cerrar Sesión'),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true) {
                await authProvider.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0F1C), Color(0xFF1A1F2C)],
          ),
        ),
        child: screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E2337),
          border: Border(
            top: BorderSide(
              color: Colors.blue.shade800.withOpacity(0.3),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: bottomNavItems,
          backgroundColor: const Color(0xFF1E2337),
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.blueGrey.shade400,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
            color: Colors.blueGrey.shade400,
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // Removí 'const' de las listas y de los constructores que no son constantes
  final List<BottomNavigationBarItem> _teacherBottomNavItems = [
    BottomNavigationBarItem(
      icon: const Icon(Icons.school),
      activeIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.school, color: Colors.blueAccent),
      ),
      label: 'Mis Cursos',
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.add),
      activeIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.add, color: Colors.blueAccent),
      ),
      label: 'Crear Curso',
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.library_books),
      activeIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.library_books, color: Colors.blueAccent),
      ),
      label: 'Materiales',
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.person),
      activeIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.person, color: Colors.blueAccent),
      ),
      label: 'Perfil',
    ),
  ];

  final List<BottomNavigationBarItem> _studentBottomNavItems = [
    BottomNavigationBarItem(
      icon: const Icon(Icons.school),
      activeIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.school, color: Colors.blueAccent),
      ),
      label: 'Cursos',
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.library_books),
      activeIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.library_books, color: Colors.blueAccent),
      ),
      label: 'Materiales',
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.grade),
      activeIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.grade, color: Colors.blueAccent),
      ),
      label: 'Calificaciones',
    ),
    BottomNavigationBarItem(
      icon: const Icon(Icons.person),
      activeIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.person, color: Colors.blueAccent),
      ),
      label: 'Perfil',
    ),
  ];
}
