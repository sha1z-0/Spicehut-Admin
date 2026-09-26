import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/sign_in_screen.dart';
import 'screens/privacy_policy_modal.dart';
import 'screens/age_verification_screen.dart';
import 'screens/permissions_screen.dart';
import 'services/order_notification_service.dart';
import 'services/logger_service.dart';
import 'services/printer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await PrinterService.initialize();
  } catch (e, stack) {
    LoggerService.error('Failed to initialize PrinterService', e, stack, 'Main');
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _ageVerified = false;
  bool _privacyAccepted = false;
  bool _permissionsRequested = false;
  bool _isLoading = true;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _checkFirstRun();
    OrderNotificationService.instance.initialize(_navigatorKey);
  }

  Future<void> _checkFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? ageVerified = prefs.getBool('age_verified');
    final bool? privacyAccepted = prefs.getBool('privacy_policy_accepted');
    final bool? permissionsRequested = prefs.getBool('permissions_requested');
    
    LoggerService.debug('Age verified: $ageVerified', 'Main');
    LoggerService.debug('Privacy policy accepted: $privacyAccepted', 'Main');
    LoggerService.debug('Permissions requested: $permissionsRequested', 'Main');
    
    if (mounted) {
      setState(() {
        _ageVerified = ageVerified ?? false;
        _privacyAccepted = privacyAccepted ?? false;
        _permissionsRequested = permissionsRequested ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyAge() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('age_verified', true);
    if (mounted) {
      setState(() {
        _ageVerified = true;
      });
    }
  }

  Future<void> _acceptPrivacyPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_policy_accepted', true);
    if (mounted) {
      setState(() {
        _privacyAccepted = true;
      });
    }
  }

  Future<void> _onPermissionsRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_requested', true);
    if (mounted) {
      setState(() {
        _permissionsRequested = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    // Screen priority: Age verification -> Privacy policy -> Permissions -> Sign in
    Widget homeScreen;
    
    if (!_ageVerified) {
      homeScreen = AgeVerificationScreen(
        onAgeVerified: _verifyAge,
      );
    } else if (!_privacyAccepted) {
      homeScreen = Scaffold(
        body: PrivacyPolicyModal(
          onAccepted: _acceptPrivacyPolicy,
        ),
      );
    } else if (!_permissionsRequested) {
      homeScreen = PermissionsScreen(
        onPermissionsRequested: _onPermissionsRequested,
      );
    } else {
      homeScreen = const SignInScreen();
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'SpiceHut Admin',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        primaryColor: const Color(0xFFFF7A00),
        useMaterial3: true,
        
        // Smooth page transitions
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        
        // Dialog theme with backdrop blur
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
        ),
        
        // Bottom sheet theme
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          modalBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        
        // Card theme for consistent elevation
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        
        // Popup menu theme
        popupMenuTheme: PopupMenuThemeData(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: homeScreen,
    );
  }
}
