import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

// void main() {
//   runApp(SinPlotApp());
// }

class SinPlotApp extends StatelessWidget {
  const SinPlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: Text('Sin(x) Plot')),
        body: Padding(padding: EdgeInsets.all(16.0), child: SinChart()),
      ),
    );
  }
}

class SinChart extends StatelessWidget {
  const SinChart({super.key});

  List<FlSpot> generateSinData() {
    List<FlSpot> spots = [];
    for (double x = 0; x <= 2 * pi; x += 0.1) {
      spots.add(FlSpot(x, sin(x)));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: generateSinData(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            belowBarData: BarAreaData(show: false),
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
