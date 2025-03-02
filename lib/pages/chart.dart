import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Provides the LineChart widget and related classes.
import 'package:http/http.dart' as http; // Used for making HTTP requests.
import 'dart:convert'; // Used for JSON decoding.

/// Model class for consumption data.
class ConsumptionData {
  final String time; // The label for the x-axis (e.g., hour, day, or month).
  final double consumption; // The consumption value (y-axis).

  // Constructor with required parameters.
  ConsumptionData({required this.time, required this.consumption});

  // Factory constructor to create a ConsumptionData instance from JSON.
  factory ConsumptionData.fromJson(Map<String, dynamic> json) {
    return ConsumptionData(
      time: json['time'], // Extracts the "time" field from the JSON.
      consumption: (json['consumption'] as num).toDouble(), // Converts the "consumption" field to a double.
    );
  }
}

/// The main Chart widget which is stateful because data is fetched and updated.
class Chart extends StatefulWidget {
  const Chart({super.key});

  @override
  State<Chart> createState() => _ChartState();
}

class _ChartState extends State<Chart> {
  // List to hold the fetched consumption data.
  List<ConsumptionData> consumptionData = [];
  // Selected aggregation period: "day", "month", or "year".
  String selectedPeriod = "day";
  // Flag to indicate whether data is being loaded.
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // When the widget is initialized, fetch the consumption data.
    fetchData();
  }

  /// Fetches consumption data from the backend API.
  Future<void> fetchData() async {
    // Indicate that loading has started.
    setState(() {
      isLoading = true;
    });
    // Construct the API URL with the selected period as a query parameter.
    final url = Uri.parse("http://localhost:8000/api/consumption?period=$selectedPeriod");
    try {
      // Perform the GET request.
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // Decode the JSON response.
        List<dynamic> jsonList = json.decode(response.body);
        // Map the JSON objects to a list of ConsumptionData instances.
        List<ConsumptionData> data = jsonList.map((e) => ConsumptionData.fromJson(e)).toList();
        // Update the state with the fetched data.
        setState(() {
          consumptionData = data;
        });
      } else {
        // Print an error message if the status code is not 200.
        print("Error fetching consumption data: ${response.statusCode}");
      }
    } catch (e) {
      // Catch and print any exceptions during the request.
      print("Error: $e");
    } finally {
      // Stop the loading indicator regardless of the outcome.
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Builds a line chart using FL Chart's LineChart widget.
  Widget buildLineChart() {
    // If no consumption data is available, display a message.
    if (consumptionData.isEmpty) {
      return const Center(child: Text("No consumption data available"));
    }

    // Convert the consumptionData list to a list of FlSpot (x, y coordinate) objects.
    // We use the index as the x-coordinate and the consumption value as y.
    List<FlSpot> spots = [];
    for (int i = 0; i < consumptionData.length; i++) {
      spots.add(FlSpot(i.toDouble(), consumptionData[i].consumption));
    }

    // Determine the maximum y value from the consumption data for scaling.
    double maxY = consumptionData
        .map((e) => e.consumption)
        .fold<double>(0, (prev, element) => prev > element ? prev : element);
    // Increase maxY slightly for visual spacing.
    maxY *= 1.2;

    // Build and return the LineChart widget.
    return LineChart(
      LineChartData(
        // Configure grid lines if needed.
        gridData: FlGridData(show: true),
        // Set up axis titles and labels.
        titlesData: FlTitlesData(
          // Left axis (y-axis) configuration.
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, // Display y-axis labels.
              reservedSize: 40, // Reserve space for the labels.
              getTitlesWidget: (double value, TitleMeta meta) {
                // Format the y-axis label to one decimal place.
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          // Bottom axis (x-axis) configuration.
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, // Display x-axis labels.
              getTitlesWidget: (double value, TitleMeta meta) {
                int index = value.toInt(); // Convert x value to an index.
                if (index >= 0 && index < consumptionData.length) {
                  // Return the time label for the corresponding index.
                  return Text(
                    consumptionData[index].time,
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        // Remove the border lines around the chart.
        borderData: FlBorderData(show: false),
        // Define the data for the line chart.
        lineBarsData: [
          LineChartBarData(
            spots: spots, // The list of data points.
            isCurved: true, // Smooth the line curve.
            curveSmoothness: 0.2, // Adjust smoothness.
            color: Colors.blue, // Set the line color.
            barWidth: 3, // Set the width of the line.
            dotData: FlDotData(
              show: true, // Show dots at each data point.
              // Use getDotPainter to configure dot appearance.
              getDotPainter: (FlSpot spot, double xPercentage, LineChartBarData bar, int index) {
                return FlDotCirclePainter(
                  radius: 4, // Radius of the dot.
                  color: Colors.blue, // Color of the dot.
                  strokeWidth: 0, // No border stroke.
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true, // Fill the area below the line.
              color: Colors.blue.withOpacity(0.3), // Set a translucent fill color.
            ),
          ),
        ],
        // Set the maximum value on the y-axis.
        maxY: maxY,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in a Scaffold to provide the basic Material Design layout.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consumption Chart'),
      ),
      body: Column(
        children: [
          // Dropdown menu to select the aggregation period (day, month, year).
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: selectedPeriod,
              items: const [
                DropdownMenuItem(value: "day", child: Text("Day")),
                DropdownMenuItem(value: "month", child: Text("Month")),
                DropdownMenuItem(value: "year", child: Text("Year")),
              ],
              onChanged: (value) {
                if (value != null) {
                  // Update the selected period and fetch new data.
                  setState(() {
                    selectedPeriod = value;
                  });
                  fetchData();
                }
              },
            ),
          ),
          // Expanded widget to fill the available space with the chart or a loading indicator.
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator()) // Show loading indicator while data is being fetched.
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    // Display the line chart built from consumption data.
                    child: buildLineChart(),
                  ),
          ),
        ],
      ),
    );
  }
}
