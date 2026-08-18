import 'package:flutter/material.dart';

class HistoryCard extends StatelessWidget {
  final String wasteType;
  final String points;
  final String date;
  final String time;

  const HistoryCard({
    super.key,
    required this.wasteType,
    required this.points,
    required this.date,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
          Theme.of(context).colorScheme.primary,
          child: const Icon(
            Icons.recycling,
            color: Colors.white,
          ),
        ),

        title: Text(
          wasteType,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Text("$date • $time"),

        trailing: Text(
          points,
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}