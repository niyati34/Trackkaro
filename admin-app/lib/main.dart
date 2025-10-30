import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'busdetail_page.dart';
import 'student_detail_page.dart';
import 'on_route_page.dart';
import 'standby_page.dart';
import 'out_of_service_page.dart';
import 'live_tracking_page.dart'; // Import LiveTrackingPage
import 'update_details_page.dart'; // Import UpdateDetailsPage
import 'package:provider/provider.dart';
import 'pie_chart_data_model.dart';
// Only import on web to avoid dart:ui_web on desktop/mobile
// ignore: uri_does_not_exist
import 'url_strategy_stub.dart' if (dart.library.js) 'url_strategy_web.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'live_camera.dart';
import 'notification.dart';
import 'debug_network.dart';

void main() async {
  try {
    await dotenv.load(fileName: "pro.env");
  } catch (e) {
    print('Environment file not found, using default values: $e');
    // Set default values if env file fails to load
    dotenv.env['BACKEND_API'] = 'https://new-track-karo-backend.onrender.com';
  }
  // Configure web URL strategy only on web
  configureAppUrlStrategy();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App Name',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/', // Set initial route to SplashScreen
      routes: {
        '/': (context) => SplashScreen(), // SplashScreen as the initial route
        '/login': (context) => LoginPage(), // Define route for LoginPage
        '/home': (context) => HomePage(), // Define route for HomePage
        '/busDetail': (context) =>
            BusDetailPage(), // Define route for BusDetailPage
        '/studentDetail': (context) =>
            StudentDetailPage(), // Define route for StudentDetailPage
        '/onRoute': (context) => OnRoutePage(), // Define route for OnRoutePage
        '/standby': (context) => StandbyPage(), // Define route for StandbyPage
        '/outOfService': (context) =>
            OutOfServicePage(), // Define route for OutOfServicePage
        '/liveTracking': (context) =>
            LiveTrackingPage(), // Define route for LiveTrackingPage
        '/debug': (context) => NetworkDebugPage(), // Debug route

        '/liveCamera': (context) =>
            LiveCameraPage(), // Define route for UpdateDetailsPage
        '/notification': (context) => NotificationPage(),
      },
    );
  }
}
