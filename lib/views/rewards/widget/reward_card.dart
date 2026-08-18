import 'package:flutter/material.dart';

class RewardCard extends StatelessWidget {
  final String title;
  final String description;
  final String points;
  final IconData icon;
  final VoidCallback? onPressed;

  const RewardCard({
    super.key,
    required this.title,
    required this.description,
    required this.points,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Icon(icon, size: 28),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    points,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            FilledButton(
              onPressed: onPressed,
              child: const Text("Redeem"),
            ),
          ],
        ),
      ),
    );
  }
}