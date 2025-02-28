import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:water_pump/components/button.dart';
import 'package:water_pump/pages/initialize_screen.dart';
import 'package:water_pump/pages/chart.dart';  // Import the chart page

// Update the URL as needed.
const String apiUrl = "http://localhost:8000/api";

/// Model classes
class Tank {
  final int id;
  final double capacity;
  final double waterLevel;
  final String state;
  final String lastEvent;
  final double sensor;

  Tank({
    required this.id,
    required this.capacity,
    required this.waterLevel,
    required this.state,
    required this.lastEvent,
    required this.sensor,
  });

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

class SystemData {
  final bool manualOverride;
  final bool deactivated;

  SystemData({required this.manualOverride, required this.deactivated});

  factory SystemData.fromJson(Map<String, dynamic> json) {
    return SystemData(
      manualOverride: json['manual_override'],
      deactivated: json['deactivated'],
    );
  }
}

/// SmartPump Screen
class SmartPump extends StatefulWidget {
  const SmartPump({super.key});

  @override
  State<SmartPump> createState() => _SmartPumpState();
}

class _SmartPumpState extends State<SmartPump> {
  Timer? _timer;
  List<Tank> tanks = [];
  SystemData? systemData;
  bool _lowWaterAlertShown = false; // Prevents repeated alerts

  @override
  void initState() {
    super.initState();
    fetchData();
    // Poll data every second.
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    try {
      final response = await http.get(Uri.parse("$apiUrl/tanks"));
      if (response.statusCode == 200) {
        List<dynamic> jsonData = json.decode(response.body);
        List<Tank> fetchedTanks =
            jsonData.map((data) => Tank.fromJson(data)).toList();
        setState(() {
          tanks = fetchedTanks;
        });
      }
      final sysResponse = await http.get(Uri.parse("$apiUrl/system"));
      if (sysResponse.statusCode == 200) {
        setState(() {
          systemData = SystemData.fromJson(json.decode(sysResponse.body));
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
    }
    _checkLowWaterAlert(); // Check after data update
  }

  Future<void> setTankState(int id, String action) async {
    try {
      final response = await http.post(
        Uri.parse("$apiUrl/tanks/$id/set_state"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"action": action}),
      );
      if (response.statusCode == 200) {
        fetchData();
      }
    } catch (e) {
      debugPrint("Error setting tank state: $e");
    }
  }

  Future<void> toggleManual() async {
    try {
      final response =
          await http.post(Uri.parse("$apiUrl/system/toggle_manual"));
      if (response.statusCode == 200) {
        fetchData();
      }
    } catch (e) {
      debugPrint("Error toggling manual override: $e");
    }
  }

  /// This function toggles the simulation cycle.
  Future<void> toggleCycle() async {
    try {
      final endpoint = (systemData != null && systemData!.deactivated)
          ? "activate_cycle"
          : "deactivate_cycle";
      final response = await http.post(Uri.parse("$apiUrl/system/$endpoint"));
      if (response.statusCode == 200) {
        fetchData();
      }
    } catch (e) {
      debugPrint("Error toggling cycle: $e");
    }
  }

  /// Checks if the active tank in manual mode is below threshold.
  /// If so, it freezes the system by showing a blocking dialog.
  void _checkLowWaterAlert() {
    if (systemData != null && systemData!.manualOverride) {
      // Look for the active tank.
      Tank? activeTank;
      for (Tank tank in tanks) {
        if (tank.state.toLowerCase() == "active") {
          activeTank = tank;
          break;
        }
      }
      if (activeTank != null) {
        // Define critical threshold as 25% of capacity.
        double threshold = activeTank.capacity * 0.25;
        if (activeTank.waterLevel < threshold && !_lowWaterAlertShown) {
          _lowWaterAlertShown = true;
          // Show a non-dismissable alert dialog.
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              return AlertDialog(
                title: const Text("Low Water Alert"),
                content: const Text(
                    "Water below threshold. Please refill the tank."),
                actions: [
                  TextButton(
                    onPressed: () {
                      // Set the active tank to refill.
                      setTankState(activeTank!.id, "refill");
                      _lowWaterAlertShown = false;
                      Navigator.of(context).pop();
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

  /// Shows notifications from the backend in an eye-catching dialog.
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
                    await http.post(Uri.parse("$apiUrl/alerts/clear"));
                    Navigator.of(context).pop();
                  },
                  child: const Text("Clear",
                      style: TextStyle(color: Colors.blue)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
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

  /// Builds a statistics card showing aggregated system information.
  Widget buildStatisticsCard() {
    if (tanks.isEmpty) return Container();

    double totalCapacity =
        tanks.fold(0, (sum, tank) => sum + tank.capacity);
    double totalWater =
        tanks.fold(0, (sum, tank) => sum + tank.waterLevel);
    double overallFraction = totalCapacity > 0 ? totalWater / totalCapacity : 0;
    double overallPercent = overallFraction * 100;

    int activeCount =
        tanks.where((tank) => tank.state.toLowerCase() == "active").length;
    int refillCount =
        tanks.where((tank) => tank.state.toLowerCase() == "refill").length;
    int idleCount =
        tanks.where((tank) => tank.state.toLowerCase() == "idle").length;

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
            LinearProgressIndicator(
              value: overallFraction,
              backgroundColor: Colors.grey[300],
              valueColor:
                  const AlwaysStoppedAnimation(Color(0xff0197F6)),
            ),
            const SizedBox(height: 12),
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
      backgroundColor: Colors.white, // Default white background
      appBar: AppBar(
        backgroundColor: const Color(0xff0197F6),
        title: const Text(
          "Smart Pump System",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            tooltip: "View Notifications",
            onPressed: _showNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.settings_input_component,
                color: Colors.white),
            tooltip: "Initialize Simulation",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const InitializeScreen()),
              );
              fetchData();
            },
          ),
          // New IconButton for navigating to the Chart screen.
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
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (systemData != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
            if (systemData != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: MyButton(
                  text: systemData!.deactivated
                      ? "Reactivate System"
                      : "Deactivate System",
                  onTap: toggleCycle,
                ),
              ),
            const SizedBox(height: 16),
            // Statistics card added here:
            buildStatisticsCard(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: tanks.length,
                itemBuilder: (context, index) {
                  Tank tank = tanks[index];
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
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
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: tank.waterLevel / tank.capacity,
                            backgroundColor: Colors.grey[300],
                            valueColor:
                                const AlwaysStoppedAnimation(
                                    Color(0xff0197F6)),
                          ),
                          if (systemData != null &&
                              systemData!.manualOverride)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        setTankState(tank.id, "active"),
                                    child: const Text("Active",
                                        style: TextStyle(
                                            color: Color(0xff0197F6),
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        setTankState(tank.id, "refill"),
                                    child: const Text("Refill",
                                        style: TextStyle(
                                            color: Color(0xff0197F6),
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        setTankState(tank.id, "idle"),
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
