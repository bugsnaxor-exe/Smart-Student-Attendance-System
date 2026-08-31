import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'providers/attendance_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_dashboard_screen.dart';
import 'screens/teacher/teacher_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  await authProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<LocationProvider>(create: (_) => LocationProvider()),
        ChangeNotifierProvider<AttendanceProvider>(create: (_) => AttendanceProvider()),
      ],
      child: const EduAttendanceApp(),
    ),
  );
}

class EduAttendanceApp extends StatelessWidget {
  const EduAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduAttendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.isAuthenticated) {
            return const LoginScreen();
          }
          if (auth.isStudent) {
            return const StudentDashboardScreen();
          }
          return const TeacherDashboardScreen();
        },
      ),
    );
  }
}
