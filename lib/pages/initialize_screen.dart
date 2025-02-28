import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:water_pump/components/text_field.dart';
import 'package:water_pump/components/button.dart';
import 'package:lottie/lottie.dart';

// Update the URL as needed.
const String apiUrl = "http://localhost:8000/api";

/// LottieBackground Widget
class LottieBackground extends StatelessWidget {
  final Widget child;
  const LottieBackground({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Center the Lottie animation on the screen.
        Center(
          child: Lottie.asset(
            'assets/images/WaterBackground.json', // Ensure this file is in your assets and declared in pubspec.yaml
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            fit: BoxFit.contain,
          ),
        ),
        // Foreground content.
        child,
      ],
    );
  }
}

/// InitializeScreen Widget
class InitializeScreen extends StatefulWidget {
  const InitializeScreen({super.key});
  
  @override
  State<InitializeScreen> createState() => _InitializeScreenState();
}

class _InitializeScreenState extends State<InitializeScreen> {
  final TextEditingController _numTanksController = TextEditingController();
  List<TextEditingController> _capacityControllers = [];
  int? numTanks;
  bool stepTwo = false;
  
  @override
  void dispose() {
    _numTanksController.dispose();
    for (var controller in _capacityControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  Future<void> _initializeSimulation() async {
    List<double> capacities = _capacityControllers
        .map((controller) => double.parse(controller.text))
        .toList();
    try {
      final response = await http.post(
        Uri.parse("$apiUrl/initialize"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"capacities": capacities}),
      );
      if (response.statusCode == 200) {
        Navigator.pop(context);
      } else {
        debugPrint("Initialization failed: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error during initialization: $e");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Initialize Simulation"),
      ),
      body: LottieBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: stepTwo ? _buildCapacityForm() : _buildNumTanksForm(),
          ),
        ),
      ),
    );
  }
  
  Widget _buildNumTanksForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Enter the number of tanks:",
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _numTanksController,
          labelText: "Number of Tanks",
          prefixIcon: Icons.format_list_numbered,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        MyButton(
          text: "Next",
          onTap: () {
            if (_numTanksController.text.isEmpty ||
                int.tryParse(_numTanksController.text) == null ||
                int.parse(_numTanksController.text) <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Enter a valid positive number of tanks")),
              );
              return;
            }
            setState(() {
              numTanks = int.parse(_numTanksController.text);
              _capacityControllers = List.generate(numTanks!, (_) => TextEditingController());
              stepTwo = true;
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildCapacityForm() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Enter the capacity for each tank:",
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 10),
          ...List.generate(numTanks!, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: CustomTextField(
                controller: _capacityControllers[index],
                labelText: "Capacity for Tank ${index + 1}",
                prefixIcon: Icons.opacity,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            );
          }),
          const SizedBox(height: 20),
          MyButton(
            text: "Initialize Simulation",
            onTap: () {
              bool valid = true;
              for (var controller in _capacityControllers) {
                if (controller.text.isEmpty ||
                    double.tryParse(controller.text) == null ||
                    double.parse(controller.text) <= 0) {
                  valid = false;
                  break;
                }
              }
              if (!valid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enter valid positive capacities for all tanks")),
                );
                return;
              }
              _initializeSimulation();
            },
          ),
        ],
      ),
    );
  }
}
