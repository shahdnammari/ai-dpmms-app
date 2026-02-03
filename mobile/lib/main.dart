import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI-DPMMS',
      home: const HealthCheckPage(),
    );
  }
}

class HealthCheckPage extends StatefulWidget {
  const HealthCheckPage({super.key});

  @override
  State<HealthCheckPage> createState() => _HealthCheckPageState();
}

class _HealthCheckPageState extends State<HealthCheckPage> {
  String result = "Loading...";

  @override
  void initState() {
    super.initState();
    checkHealth();
  }

  Future<void> checkHealth() async {
    try {
      final res = await http.get(
        Uri.parse("http://127.0.0.1:8000/api/health"),
      );
      final data = jsonDecode(res.body);
      setState(() {
        result = data["message"];
      });
    } catch (e) {
      setState(() {
        result = "Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI-DPMMS Health Check")),
      body: Center(child: Text(result, style: const TextStyle(fontSize: 18))),
    );
  }
}
