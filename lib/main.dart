import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:firebase_core/firebase_core.dart';
import 'package:john_estacio_website/app/router/app_router.dart';
import 'package:john_estacio_website/core/utils/time_zone_service.dart';
import 'package:john_estacio_website/firebase_options.dart';
import 'package:john_estacio_website/theme.dart';

void main() async {
  // Ensure that Flutter bindings are initialized before any Flutter code runs.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize IANA time zone database (DST-safe performance times)
  await TimeZoneService.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use MaterialApp.router to enable the GoRouter configuration
    return MaterialApp.router(
      title: 'John Estacio | Composer',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
    );
  }
}