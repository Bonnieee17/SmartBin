import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserTable extends StatelessWidget {
  final List<Map<String, dynamic>> records;

  const UserTable({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 800),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(theme.dividerColor.withValues(alpha: 0.05)),
          horizontalMargin: 12,
          columnSpacing: 24,
          columns: [
            DataColumn(label: Text("USER ID", style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color))),
            DataColumn(label: Text("WASTE TYPE", style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color))),
            DataColumn(label: Text("DATE", style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color))),
            DataColumn(label: Text("POINTS", style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color))),
            DataColumn(label: Text("STATUS", style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color))),
          ],
          rows: records.map((activity) {
            final createdAt = activity['created_at'] != null 
                ? DateTime.parse(activity['created_at']) 
                : DateTime.now();
            
            final dateStr = DateFormat('MMM d, h:mm a').format(createdAt);
            final userId = activity['user_id']?.toString() ?? "Unknown";
            final shortId = userId.length > 8 ? userId.substring(0, 8) : userId;

            return DataRow(cells: [
              DataCell(Text(shortId, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color))),
              DataCell(Text(activity['waste_type'] ?? "Other", style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
              DataCell(Text(dateStr, style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
              DataCell(Text("+${activity['points_earned'] ?? 0}", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("Verified", style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
