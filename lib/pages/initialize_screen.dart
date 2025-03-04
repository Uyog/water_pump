import 'dart:convert'; // Provides functions for encoding and decoding JSON data.
import 'package:flutter/material.dart'; // Flutter material package for UI components.
import 'package:http/http.dart' as http; // HTTP package to make network requests.
import 'package:water_pump/components/text_field.dart'; // Custom text field widget.
import 'package:water_pump/components/button.dart'; // Custom button widget.
import 'package:lottie/lottie.dart'; // Lottie package for playing animations.

// API base URL - update as necessary.
const String apiUrl = "http://localhost:8000/api";

/// LottieBackground Widget displays a Lottie animation as the background 
/// with a child widget on top of it.
class LottieBackground extends StatelessWidget {
  final Widget child; // Child widget to be displayed in the foreground.

  const LottieBackground({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The Lottie animation is centered in the background.
        Center(
          child: Lottie.asset(
            'assets/images/WaterBackground.json', // Path to the Lottie animation file.
            width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width.
            height: MediaQuery.of(context).size.height * 0.8, // 80% of screen height.
            fit: BoxFit.contain, // Scale the animation to fit within the given width and height.
          ),
        ),
        // The child widget is rendered in the foreground on top of the animation.
        child,
      ],
    );
  }
}

/// InitializeScreen Widget: A stateful widget that allows the user to initialize 
/// a simulation by entering the number of tanks and their capacities.
class InitializeScreen extends StatefulWidget {
  const InitializeScreen({super.key});
  
  @override
  State<InitializeScreen> createState() => _InitializeScreenState();
}

class _InitializeScreenState extends State<InitializeScreen> {
  // Controller for the text field that accepts the number of tanks.
  final TextEditingController _numTanksController = TextEditingController();
  // List of controllers for each tank's capacity input field.
  List<TextEditingController> _capacityControllers = [];
  int? numTanks; // Stores the number of tanks entered by the user.
  bool stepTwo = false; // Determines which step of the form to show.
  
  @override
  void dispose() {
    // Dispose of controllers to free up resources when the widget is removed.
    _numTanksController.dispose();
    for (var controller in _capacityControllers) {
      controller.dispose();
    }
    super.dispose();
  }
  
  /// Sends an HTTP POST request to initialize the simulation with the specified tank capacities.
  Future<void> _initializeSimulation() async {
    // Convert text input values to a list of double values.
    List<double> capacities = _capacityControllers
        .map((controller) => double.parse(controller.text))
        .toList();
    try {
      // Post the capacities to the backend API.
      final response = await http.post(
        Uri.parse("$apiUrl/initialize"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"capacities": capacities}),
      );
      // If the response is successful, return to the previous screen.
      if (response.statusCode == 200) {
        Navigator.pop(context);
      } else {
        // If the response is not successful, log an error.
        debugPrint("Initialization failed: ${response.body}");
      }
    } catch (e) {
      // Catch and log any exceptions that occur during the HTTP request.
      debugPrint("Error during initialization: $e");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App bar with the title.
      appBar: AppBar(
        title: const Text("Initialize Simulation"),
      ),
      // Use the LottieBackground widget to display the animated background.
      body: LottieBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            // Display different forms based on whether we're in step one or step two.
            child: stepTwo ? _buildCapacityForm() : _buildNumTanksForm(),
          ),
        ),
      ),
    );
  }
  
  /// Builds the form to input the number of tanks.
  Widget _buildNumTanksForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "Enter the number of tanks:",
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 16),
        // Custom text field for the number of tanks.
        CustomTextField(
          controller: _numTanksController,
          labelText: "Number of Tanks",
          prefixIcon: Icons.format_list_numbered,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 20),
        // Button to proceed to the next step.
        MyButton(
          text: "Next",
          onTap: () {
            // Validate the input for a positive integer.
            if (_numTanksController.text.isEmpty ||
                int.tryParse(_numTanksController.text) == null ||
                int.parse(_numTanksController.text) <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Enter a valid positive number of tanks")),
              );
              return;
            }
            // Update state: set the number of tanks and generate capacity controllers for each tank.
            setState(() {
              numTanks = int.parse(_numTanksController.text);
              _capacityControllers = List.generate(numTanks!, (_) => TextEditingController());
              stepTwo = true; // Proceed to the capacity input step.
            });
          },
        ),
      ],
    );
  }
  
  /// Builds the form to input the capacity for each tank.
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
          // Generate a text field for each tank based on the number of tanks.
          ...List.generate(numTanks!, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: CustomTextField(
                controller: _capacityControllers[index],
                labelText: "Capacity for Tank ${index + 1}",
                prefixIcon: Icons.opacity, // Icon representing liquid capacity.
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            );
          }),
          const SizedBox(height: 20),
          // Button to initialize the simulation using the provided capacities.
          MyButton(
            text: "Initialize Simulation",
            onTap: () {
              bool valid = true;
              // Validate each capacity input to ensure it is a positive number.
              for (var controller in _capacityControllers) {
                if (controller.text.isEmpty ||
                    double.tryParse(controller.text) == null ||
                    double.parse(controller.text) <= 0) {
                  valid = false;
                  break;
                }
              }
              // If validation fails, show a snackbar with an error message.
              if (!valid) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enter valid positive capacities for all tanks")),
                );
                return;
              }
              // If all inputs are valid, call the initialization function.
              _initializeSimulation();
            },
          ),
        ],
      ),
    );
  }
}
