import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../main.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  static bool bypassNextLifecycleLock = false;

  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;
  String _message = 'Unlock ScheduleMate';

  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (AuthScreen.bypassNextLifecycleLock) {
        return;
      }
      if (_isAuthenticated) {
        setState(() {
          _isAuthenticated = false;
          _message = 'Unlock ScheduleMate';
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      if (AuthScreen.bypassNextLifecycleLock) {
        AuthScreen.bypassNextLifecycleLock = false;
        return;
      }
      if (!_isAuthenticated && !_isAuthenticating) {
        _authenticate();
      }
    }
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
        _message = 'Authenticating...';
      });
      
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();
      
      if (!canAuthenticate) {
        // If device doesn't support biometrics, just proceed
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
          });
        }
        return;
      }
      
      authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access your timetable and GPA data',
        biometricOnly: false,
      );
      
      setState(() {
        _isAuthenticating = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _isAuthenticating = false;
        _message = 'Authentication Error: ${e.message}';
      });
      return;
    }

    if (!mounted) return;

    if (authenticated) {
      setState(() {
        _isAuthenticated = true;
      });
    } else {
      setState(() {
        _message = 'Authentication failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated) {
      return const HomeScreen();
    }
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1E1E2E), const Color(0xFF252535)]
                : [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fingerprint_rounded,
                  size: 80,
                  color: isDark ? AppColors.primary : Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'ScheduleMate',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 48),
              if (!_isAuthenticating)
                ElevatedButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Unlock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.primary : Colors.white,
                    foregroundColor: isDark ? Colors.white : AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: Colors.black26,
                  ),
                ),
              if (_isAuthenticating)
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.primary : Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
