import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'providers/announcement_provider.dart';
import 'providers/gpa_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/timetable_provider.dart';
import 'screens/auth_screen.dart';
import 'services/notification_service.dart';
import 'services/backup_service.dart';
import 'providers/app_notification_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
  if (message.notification != null) {
    await AppNotificationProvider.saveMessageToPrefs(
      message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      message.notification!.title ?? 'New Message',
      message.notification!.body ?? '',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Setup FCM Background Handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Subscribe to 'all' topic for general announcements
  FirebaseMessaging.instance.subscribeToTopic('all');
  
  // Setup FCM Foreground Handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    if (message.notification != null) {
      await AppNotificationProvider.saveMessageToPrefs(
        message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        message.notification!.title ?? 'New Message',
        message.notification!.body ?? '',
      );
      AppNotificationProvider.updateStream.add(null);
      NotificationService.instance.showFCMNotification(message);
    }
  });

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await NotificationService.instance.init();
  await BackupService.instance.init();
  runApp(const MyApp());
}

class AppColors {
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF4A44CC);
  static const secondary = Color(0xFF00D4AA);
  static const accent = Color(0xFFFF6B9D);
  static const surface = Color(0xFF1E1E2E);
  static const surfaceCard = Color(0xFF252535);
  static const surfaceLight = Color(0xFFF8F7FF);
  static const surfaceCardLight = Color(0xFFFFFFFF);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GpaProvider()),
        ChangeNotifierProvider(create: (_) => TimetableProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AnnouncementProvider()),
        ChangeNotifierProvider(create: (_) => AppNotificationProvider()),
        ChangeNotifierProvider.value(value: BackupService.instance),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'ScheduleMate',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.light,
              ).copyWith(
                primary: AppColors.primary,
                secondary: AppColors.secondary,
                tertiary: AppColors.accent,
              ),
              fontFamily: 'Roboto',
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: AppColors.surfaceCardLight,
              ),
              appBarTheme: const AppBarTheme(
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: Color(0xFF1A1A2E),
                systemOverlayStyle: SystemUiOverlayStyle.dark,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.dark,
              ).copyWith(
                primary: AppColors.primary,
                secondary: AppColors.secondary,
                tertiary: AppColors.accent,
                surface: AppColors.surface,
                surfaceContainerHighest: AppColors.surfaceCard,
              ),
              fontFamily: 'Roboto',
              scaffoldBackgroundColor: AppColors.surface,
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: AppColors.surfaceCard,
              ),
              appBarTheme: const AppBarTheme(
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                systemOverlayStyle: SystemUiOverlayStyle.light,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF2C2C3E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF3C3C4E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            home: const AuthScreen(),
          );
        },
      ),
    );
  }
}
