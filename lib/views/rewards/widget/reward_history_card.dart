import 'package:flutter/material.dart';

class RewardHistoryCard extends StatelessWidget {
  final String rewardName;
  final String date;
  final String reference;

  const RewardHistoryCard({
    super.key,
    required this.rewardName,
    required this.date,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.check),
        ),

        title: Text(rewardName),

        subtitle: Text(
          "$date\nReference: $reference",
        ),

        isThreeLine: true,

        trailing: Text(
          "Completed",
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}