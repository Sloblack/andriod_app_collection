import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'pages/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:recollection_application/providers/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log(
      'Error a nivel de plataforma: $error',
      name: 'GlobalError',
      error: error,
      stackTrace: stack
    );
    return true;
  };

  SystemChannels.lifecycle.setMessageHandler((msg) async {
    developer.log('Evento de ciclo de vida a nivel de sistema: $msg', name: 'AppLifecycle');
    return null;
  });
  
  FlutterError.onError = (FlutterErrorDetails details) {
    developer.log(
      'Error no capturado: ${details.exception}',
      name: 'GlobalError',
      error: details.exception,
      stackTrace: details.stack
    );
    FlutterError.presentError(details);
  };
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
  }

  void _handleIncomingLinks() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChannels.platform.invokeMethod<String>('getInitialLink').then((String? link) {
        if (link != null) {
          _handleNfcTag(link);
        }
      });
    });

    SystemChannels.platform.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onNewIntent') {
        final String? link = call.arguments as String?;
        if (link != null) {
          _handleNfcTag(link);
        }
      }
    });
  }

  void _handleNfcTag(String tagData) {
    developer.log('NFC Tag detectado: $tagData', name: 'NFCHandler');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Recollection App',
          theme: ThemeData.light(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          ),
          darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
          ),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const WelcomeScreen(),
          navigatorObservers: [
            _NavigatorObserver(),
          ],
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class _NavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    developer.log(
      'Navegación: Push a ${route.settings.name}',
      name: 'Navigation'
    );
    super.didPush(route, previousRoute);
  }
  
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    developer.log(
      'Navegación: Pop desde ${route.settings.name}',
      name: 'Navigation'
    );
    super.didPop(route, previousRoute);
  }
}