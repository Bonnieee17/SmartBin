import 'package:flutter/material.dart';

class ActivityCard extends StatelessWidget {
  final String title;
  final String points;
  final String date;

  const ActivityCard({
    super.key,
    required this.title,
    required this.points,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.recycling),
        ),
        title: Text(title),
        subtitle: Text(date),
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