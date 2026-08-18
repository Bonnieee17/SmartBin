import 'package:flutter/material.dart';

class PointsCard extends StatelessWidget {
  const PointsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              "Eco Points",
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 16),

            Text(
              "450 Points",
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            LinearProgressIndicator(
              value: 0.90,
              borderRadius: BorderRadius.circular(20),
            ),

            const SizedBox(height: 10),

            Text(
              "50 points away from GCash ₱50 reward",
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}