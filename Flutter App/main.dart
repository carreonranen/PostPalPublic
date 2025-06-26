//This is the main.dart for the flutter app, this is where the app starts and initialized to give proper time for the homepage to load
//This is because the home page contains a 3D model which can take some time to load

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_page.dart';
import 'screens/monitor_weight.dart';
import 'screens/motions_pages.dart';
import 'screens/images_page.dart';
import 'screens/videos_page.dart'; 
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const PostPalApp());
}

class PostPalApp extends StatelessWidget {
  const PostPalApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PostPal',
      theme: ThemeData(brightness: Brightness.dark),
      initialRoute: HomePage.routeName,
      routes: {
        HomePage.routeName: (_) => const HomePage(),
        MonitorWeightScreen.routeName: (_) => const MonitorWeightScreen(),
        MotionsPage.routeName: (_) => const MonitorMotionScreen(),
        ImagesPage.routeName: (_) => const ImagesPage(),
        VideosPage.routeName: (_) => const VideosPage(),
      },
    );
  }