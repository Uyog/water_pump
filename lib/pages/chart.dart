import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Model class for consumption data.
class ConsumptionData {
  final String time;
  final double consumption;

  ConsumptionData({required this.time, required this.consumption});

  factory ConsumptionData.fromJson(Map<String, dynamic> json) {
    return ConsumptionData(
      time: json['time'],
      consumption: (json['consumption'] as num).toDouble(),
    );
  }
}

class Chart extends StatefulWidget {
  const Chart({super.key});

  @override
  State<Chart> createState() => _ChartState();
}

class _ChartState extends State<Chart> {
  List<ConsumptionData> consumptionData = [];
  String selectedPeriod = "day"; // "day", "month", or "year"
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  /// Fetches consumption data from the backend.
  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
    });
    final url = Uri.parse("http://localhost:8000/api/consumption?period=$selectedPeriod");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> jsonList = json.decode(response.body);
        List<ConsumptionData> data = jsonList
            .map((e) => ConsumptionData.fromJson(e))
            .toList();
        setState(() {
          consumptionData = data;
        });
      } else {
        print("Error fetching consumption data: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Helper to create a bar chart group for a given data point.
  BarChartGroupData makeGroupData(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: Colors.blue,
          width: 16,
          borderRadius: BorderRadius.circular(4),
        )
      ],
    );
  }

  /// Builds the bar chart widget.
  Widget buildBarChart() {
    if (consumptionData.isEmpty) {
      return const Center(child: Text("No consumption data available"));
    }
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < consumptionData.length; i++) {
      barGroups.add(makeGroupData(i, consumptionData[i].consumption));
    }
    double maxY = consumptionData
        .map((e) => e.consumption)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2, // Increase maxY slightly for spacing
        barGroups: barGroups,
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                int index = value.toInt();
                if (index >= 0 && index < consumptionData.length) {
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
        borderData: FlBorderData(show: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in a Scaffold to provide a Material widget ancestor.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consumption Chart'),
      ),
      body: Column(
        children: [
          // Dropdown for selecting the aggregation period.
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
                  setState(() {
                    selectedPeriod = value;
                  });
                  fetchData();
                }
              },
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: buildBarChart(),
                  ),
          ),
        ],
      ),
    );
  }
}
