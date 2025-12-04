// lib/app/router.dart
import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/register_screen.dart';
import '../screens/home_screen.dart';
import '../screens/teacher/course_creation_screen.dart';
import '../screens/teacher/teacher_courses_screen.dart';
import '../screens/teacher/teacher_materials_screen.dart';
import '../screens/teacher/course_comments_screen.dart';
import '../screens/student/student_courses_screen.dart';
import '../screens/student/student_materials_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/notifications_screen.dart';

final router = GoRouter(
  initialLocation: '/login',
  routes: [
    // Rutas principales
    GoRoute(
      path: '/',
      name: 'root',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const ProfileScreen(),
    ),

    // ✅ RUTAS DEL TEACHER
    GoRoute(
      path: '/teacher/courses',
      name: 'teacher_courses',
      builder: (context, state) => const TeacherCoursesScreen(),
    ),
    GoRoute(
      path: '/teacher/create-course',
      name: 'teacher_create_course',
      builder: (context, state) => const CourseCreationScreen(),
    ),
    GoRoute(
      path: '/teacher/materials',
      name: 'teacher_materials',
      builder: (context, state) => const TeacherMaterialsScreen(),
    ),
    GoRoute(
      path: '/course-comments',
      name: 'course_comments',
      builder: (context, state) {
        final course = state.extra as Map<String, dynamic>;
        return CourseCommentsScreen(course: course);
      },
    ),

    // ✅ RUTAS DEL STUDENT
    GoRoute(
      path: '/student/courses',
      name: 'student_courses',
      builder: (context, state) => const StudentCoursesScreen(),
    ),
    GoRoute(
      path: '/student/materials',
      name: 'student_materials',
      builder: (context, state) => const StudentMaterialsScreen(),
    ),
    // En tu router.dart, agrega esta ruta:
    GoRoute(
      path: '/forgot-password',
      name: 'forgot_password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      name: 'reset_password',
      builder: (context, state) => const ResetPasswordScreen(),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
  ],
);
