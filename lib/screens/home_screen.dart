import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../app/auth_provider.dart';
import '../screens/profile_screen.dart';
import '../widgets/notifications_icon_button.dart';

class HomeShell extends StatefulWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndexForLocation(String location, String role) {
    if (role == 'teacher') {
      if (location.startsWith('/teacher/create-course')) return 1;
      if (location.startsWith('/teacher/materials')) return 2;
      if (location.startsWith('/profile')) return 3;
      return 0;
    } else {
      if (location.startsWith('/student/materials')) return 1;
      if (location.startsWith('/profile')) return 2;
      return 0;
    }
  }

  void _onNavTap(int index, String role) {
    if (role == 'teacher') {
      switch (index) {
        case 0:
          context.go('/teacher/courses');
          break;
        case 1:
          context.go('/teacher/create-course');
          break;
        case 2:
          context.go('/teacher/materials');
          break;
        case 3:
          context.go('/profile');
          break;
      }
    } else {
      switch (index) {
        case 0:
          context.go('/student/courses');
          break;
        case 1:
          context.go('/student/materials');
          break;
        case 2:
          context.go('/profile');
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userRole = authProvider.userRole ?? 'student';

    final routerState = GoRouterState.of(context);
    final location = routerState.uri.toString();
    final currentIndex = _currentIndexForLocation(location, userRole);

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
        child: widget.child,
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
          currentIndex: currentIndex,
          onTap: (index) => _onNavTap(index, userRole),
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
