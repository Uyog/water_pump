import 'dart:async'; // Provides Timer and other asynchronous utilities.
import 'dart:convert'; // Provides JSON encoding and decoding functions.
import 'package:flutter/material.dart'; // Flutter's material design widgets.
import 'package:http/http.dart' as http; // For making HTTP requests.
import 'package:water_pump/components/button.dart'; // Custom button component.
import 'package:water_pump/pages/initialize_screen.dart'; // Screen to initialize simulation.
import 'package:water_pump/pages/chart.dart';  // Screen to display charts.

// Base URL for the API.
const String apiUrl = "http://localhost:8000/api";

/// Model class representing a Tank.
class Tank {
  final int id; // Unique identifier for the tank.
  final double capacity; // Maximum capacity (liters) of the tank.
  final double waterLevel; // Current water level in the tank.
  final String state; // Current state (e.g., "active", "refill", "idle") of the tank.
  final String lastEvent; // Description or timestamp of the last event for the tank.
  final double sensor; // Sensor reading associated with the tank.

  Tank({
    required this.id,
    required this.capacity,
    required this.waterLevel,
    required this.state,
    required this.lastEvent,
    required this.sensor,
  });

  /// Creates a Tank instance from a JSON object.
  factory Tank.fromJson(Map<String, dynamic> json) {
    return Tank(
      id: json['id'],
      capacity: (json['capacity'] as num).toDouble(),
      waterLevel: (json['water_level'] as num).toDouble(),
      state: json['state'],
      lastEvent: json['last_event'],
      sensor: (json['sensor'] as num).toDouble(),
    );
  }
}

/// Model class representing system-wide data.
class SystemData {
  final bool manualOverride; // Indicates if manual override is enabled.
  final bool deactivated; // Indicates if the system is currently deactivated.

  SystemData({required this.manualOverride, required this.deactivated});

  /// Creates a SystemData instance from a JSON object.
  factory SystemData.fromJson(Map<String, dynamic> json) {
    return SystemData(
      manualOverride: json['manual_override'],
      deactivated: json['deactivated'],
    );
  }
}

/// SmartPump screen that displays tank information and system controls.
class SmartPump extends StatefulWidget {
  const SmartPump({super.key});

  @override
  State<SmartPump> createState() => _SmartPumpState();
}

class _SmartPumpState extends State<SmartPump> {
  Timer? _timer; // Timer for periodic data fetching.
  List<Tank> tanks = []; // List to store fetched tank objects.
  SystemData? systemData; // Stores system-wide settings.
  bool _lowWaterAlertShown = false; // Flag to prevent repeated low water alerts.

  @override
  void initState() {
    super.initState();
    fetchData(); // Fetch initial data.
    // Set up a timer to poll the backend every second.
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed.
    super.dispose();
  }

  /// Fetches tank and system data from the API.
  Future<void> fetchData() async {
    try {
      // Fetch tank data.
      final response = await http.get(Uri.parse("$apiUrl/tanks"));
      if (response.statusCode == 200) {
        List<dynamic> jsonData = json.decode(response.body);
        List<Tank> fetchedTanks =
            jsonData.map((data) => Tank.fromJson(data)).toList();
        setState(() {
          tanks = fetchedTanks;
        });
      }
      // Fetch system data.
      final sysResponse = await http.get(Uri.parse("$apiUrl/system"));
      if (sysResponse.statusCode == 200) {
        setState(() {
          systemData = SystemData.fromJson(json.decode(sysResponse.body));
        });
      }
    } catch (e) {
      // Log any errors that occur during fetching.
      debugPrint("Error fetching data: $e");
    }
    // After updating data, check if a low water alert needs to be shown.
    _checkLowWaterAlert();
  }

  /// Sends a command to the backend to set the state of a tank.
  Future<void> setTankState(int id, String action) async {
    try {
      final response = await http.post(
        Uri.parse("$apiUrl/tanks/$id/set_state"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"action": action}),
      );
      if (response.statusCode == 200) {
        // Refresh data after state change.
        fetchData();
      }
    } catch (e) {
      debugPrint("Error setting tank state: $e");
    }
  }

  /// Toggles the manual override setting of the system.
  Future<void> toggleManual() async {
    try {
      final response =
          await http.post(Uri.parse("$apiUrl/system/toggle_manual"));
      if (response.statusCode == 200) {
        // Refresh data after toggling.
        fetchData();
      }
    } catch (e) {
      debugPrint("Error toggling manual override: $e");
    }
  }

  /// Toggles the simulation cycle between active and deactivated states.
  Future<void> toggleCycle() async {
    try {
      // Choose the appropriate endpoint based on the current state.
      final endpoint = (systemData != null && systemData!.deactivated)
          ? "activate_cycle"
          : "deactivate_cycle";
      final response = await http.post(Uri.parse("$apiUrl/system/$endpoint"));
      if (response.statusCode == 200) {
        // Refresh data after toggling the cycle.
        fetchData();
      }
    } catch (e) {
      debugPrint("Error toggling cycle: $e");
    }
  }

  /// Checks if the active tank's water level is below 25% capacity.
  /// If so, shows a non-dismissable alert prompting a refill.
  void _checkLowWaterAlert() {
    if (systemData != null && systemData!.manualOverride) {
      // Find the active tank.
      Tank? activeTank;
      for (Tank tank in tanks) {
        if (tank.state.toLowerCase() == "active") {
          activeTank = tank;
          break;
        }
      }
      if (activeTank != null) {
        // Define critical threshold as 25% of the tank's capacity.
        double threshold = activeTank.capacity * 0.25;
        if (activeTank.waterLevel < threshold && !_lowWaterAlertShown) {
          _lowWaterAlertShown = true;
          // Display a blocking alert dialog.
          showDialog(
            context: context,
            barrierDismissible: false, // Prevent dismissal by tapping outside.
            builder: (context) {
              return AlertDialog(
                title: const Text("Low Water Alert"),
                content: const Text(
                    "Water below threshold. Please refill the tank."),
                actions: [
                  TextButton(
                    onPressed: () {
                      // When user taps "Refill", send a command to refill the active tank.
                      setTankState(activeTank!.id, "refill");
                      _lowWaterAlertShown = false;
                      Navigator.of(context).pop(); // Close the dialog.
                    },
                    child: const Text("Refill"),
                  ),
                ],
              );
            },
          );
        }
      }
    }
  }

  /// Retrieves notifications from the backend and displays them in an alert dialog.
  Future<void> _showNotifications() async {
    try {
      final response = await http.get(Uri.parse("$apiUrl/alerts"));
      if (response.statusCode == 200) {
        List<dynamic> alertsJson = json.decode(response.body);
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text(
                "Notifications",
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: alertsJson.isEmpty
                  ? const Text("No notifications.",
                      style: TextStyle(fontSize: 16))
                  : SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: alertsJson.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            leading: const Icon(Icons.warning,
                                color: Colors.orange),
                            title: Text(
                              alertsJson[index].toString(),
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        },
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () async {
                    // Clear alerts on the backend.
                    await http.post(Uri.parse("$apiUrl/alerts/clear"));
                    Navigator.of(context).pop(); // Close dialog.
                  },
                  child: const Text("Clear",
                      style: TextStyle(color: Colors.blue)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog.
                  },
                  child: const Text("Close",
                      style: TextStyle(color: Colors.blue)),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    }
  }

  /// Builds and returns a statistics card that shows aggregated system information.
  Widget buildStatisticsCard() {
    // If there are no tanks, return an empty container.
    if (tanks.isEmpty) return Container();

    // Calculate the total capacity and total water level from all tanks.
    double totalCapacity = tanks.fold(0, (sum, tank) => sum + tank.capacity);
    double totalWater = tanks.fold(0, (sum, tank) => sum + tank.waterLevel);
    // Calculate overall fullness as a fraction.
    double overallFraction = totalCapacity > 0 ? totalWater / totalCapacity : 0;
    double overallPercent = overallFraction * 100;

    // Count tanks by state.
    int activeCount =
        tanks.where((tank) => tank.state.toLowerCase() == "active").length;
    int refillCount =
        tanks.where((tank) => tank.state.toLowerCase() == "refill").length;
    int idleCount =
        tanks.where((tank) => tank.state.toLowerCase() == "idle").length;

    // Return a Card widget containing system statistics.
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "System Statistics",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xff0197F6),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Total Capacity: ${totalCapacity.toStringAsFixed(2)} L",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              "Total Water: ${totalWater.toStringAsFixed(2)} L",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              "Overall Fullness: ${overallPercent.toStringAsFixed(2)}%",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            // Display a progress bar showing overall fullness.
            LinearProgressIndicator(
              value: overallFraction,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation(Color(0xff0197F6)),
            ),
            const SizedBox(height: 12),
            // Display counts for each tank state.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Active: $activeCount",
                    style: const TextStyle(fontSize: 16)),
                Text("Refill: $refillCount",
                    style: const TextStyle(fontSize: 16)),
                Text("Idle: $idleCount",
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set default background color.
      appBar: AppBar(
        backgroundColor: const Color(0xff0197F6),
        title: const Text(
          "Smart Pump System",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Notification icon button.
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            tooltip: "View Notifications",
            onPressed: _showNotifications,
          ),
          // Button to navigate to the Initialize Simulation screen.
          IconButton(
            icon: const Icon(Icons.settings_input_component, color: Colors.white),
            tooltip: "Initialize Simulation",
            onPressed: () async {
              // Navigate to the InitializeScreen, then refresh data on return.
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InitializeScreen()),
              );
              fetchData();
            },
          ),
          // Button to navigate to the Chart screen.
          IconButton(
            icon: const Icon(Icons.show_chart, color: Colors.white),
            tooltip: "View Consumption Chart",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const Chart()),
              );
            },
          ),
        ],
      ),
      // Main body of the screen.
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // If system data is available, show a Switch for manual override.
            if (systemData != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SwitchListTile(
                  activeColor: const Color(0xff0197F6),
                  title: const Text(
                    "Manual Override",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  value: systemData!.manualOverride,
                  onChanged: (val) => toggleManual(),
                ),
              ),
            // If system data is available, show a button to activate or deactivate the system.
            if (systemData != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: MyButton(
                  text: systemData!.deactivated ? "Reactivate System" : "Deactivate System",
                  onTap: toggleCycle,
                ),
              ),
            const SizedBox(height: 16),
            // Display the statistics card.
            buildStatisticsCard(),
            const SizedBox(height: 16),
            // ListView displaying individual tank cards.
            Expanded(
              child: ListView.builder(
                itemCount: tanks.length,
                itemBuilder: (context, index) {
                  Tank tank = tanks[index];
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Tank ${tank.id}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xff0197F6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Capacity: ${tank.capacity}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Water Level: ${tank.waterLevel.toStringAsFixed(2)} (Sensor: ${tank.sensor.toStringAsFixed(2)})",
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "State: ${tank.state}",
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Last Event: ${tank.lastEvent}",
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          // Progress bar showing water level relative to capacity.
                          LinearProgressIndicator(
                            value: tank.waterLevel / tank.capacity,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation(Color(0xff0197F6)),
                          ),
                          // If manual override is enabled, show state control buttons.
                          if (systemData != null && systemData!.manualOverride)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton(
                                    onPressed: () => setTankState(tank.id, "active"),
                                    child: const Text("Active",
                                        style: TextStyle(
                                            color: Color(0xff0197F6),
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  TextButton(
                                    onPressed: () => setTankState(tank.id, "refill"),
                                    child: const Text("Refill",
                                        style: TextStyle(
                                            color: Color(0xff0197F6),
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  TextButton(
                                    onPressed: () => setTankState(tank.id, "idle"),
                                    child: const Text("Idle",
                                        style: TextStyle(
                                            color: Color(0xff0197F6),
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
