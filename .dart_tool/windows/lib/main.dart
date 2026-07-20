import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/employee_dashboard_screen.dart';  // ✅ Add this
import 'screens/superadmin_dashboard_screen.dart'; // ✅ Add this
import 'services/notification_service.dart';
import 'services/auth_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await NotificationService().init(navigatorKey);

  runApp(const CrmApp());
}

class CrmApp extends StatelessWidget {
  const CrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CRM Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      navigatorKey: navigatorKey,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final loggedIn = await AuthService.isLoggedIn();
      
      if (loggedIn) {
        _userData = await AuthService.getUserData();
      }
      
      if (mounted) {
        setState(() {
          _isLoggedIn = loggedIn && _userData != null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('⚠️ Error checking login status: $e');
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isLoggedIn && _userData != null) {
      final role = (_userData!["role"] ?? "").toString().trim().toLowerCase();
      
      Widget dashboard;
      if (role == "employee") {
        dashboard = EmployeeDashboardScreen(user: _userData!);
      } else if (role == "admin") {
        dashboard = DashboardScreen(user: _userData!);
      } else if (role == "superadmin") {
        dashboard = SuperAdminDashboardScreen(user: _userData!);
      } else {
        dashboard = const LoginScreen();
      }
      
      return dashboard;
    }

    return const LoginScreen();
  }
}