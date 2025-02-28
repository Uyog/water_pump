import 'package:flutter/material.dart';
import 'package:water_pump/pages/pump.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Pump',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SmartPump(),
    );
  }
}
