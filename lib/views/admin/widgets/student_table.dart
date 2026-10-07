import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudentTable extends StatelessWidget {
  final List<Map<String, dynamic>> students;

  const StudentTable({super.key, required this.students});

  String _calculateLevel(int points) {
    if (points >= 1000) return "Eco Legend";
    if (points >= 500) return "Green Warrior";
    if (points >= 200) return "Recycle Pro";
    if (points >= 50) return "Eco Scout";
    return "Seedling";
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case "Eco Legend": return Colors.amber;
      case "Green Warrior": return Colors.green;
      case "Recycle Pro": return Colors.blue;
      case "Eco Scout": return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 900),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(theme.dividerColor.withValues(alpha: 0.05)),
          horizontalMargin: 20,
          columnSpacing: 40,
          columns: [
            DataColumn(label: Text("STUDENT NAME", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color))),
            DataColumn(label: Text("STUDENT ID", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color))),
            DataColumn(label: Text("TOTAL POINTS", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color))),
            DataColumn(label: Text("LEVEL", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color))),
            DataColumn(label: Text("JOINING DATE", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodySmall?.color))),
          ],
          rows: students.map((student) {
            final createdAt = student['created_at'] != null 
                ? DateTime.parse(student['created_at']) 
                : DateTime.now();
            
            final dateStr = DateFormat('MMM d, yyyy').format(createdAt);
            final points = student['total_points'] ?? 0;
            final level = _calculateLevel(points);

            return DataRow(cells: [
              DataCell(Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      (student['full_name'] ?? "U")[0].toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(student['full_name'] ?? "Unknown", style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
                ],
              )),
              DataCell(Text(student['student_id'] ?? "N/A", style: TextStyle(color: theme.textTheme.bodyMedium?.color))),
              DataCell(Text("$points pts", style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getLevelColor(level).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getLevelColor(level).withValues(alpha: 0.3)),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    color: _getLevelColor(level),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )),
              DataCell(Text(dateStr, style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 13))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
