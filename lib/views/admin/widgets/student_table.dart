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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 900),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.05)),
          horizontalMargin: 20,
          columnSpacing: 40,
          columns: const [
            DataColumn(label: Text("STUDENT NAME", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("STUDENT ID", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("TOTAL POINTS", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("LEVEL", style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text("JOINING DATE", style: TextStyle(fontWeight: FontWeight.bold))),
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
                    backgroundColor: Colors.green.withOpacity(0.1),
                    child: Text(
                      (student['full_name'] ?? "U")[0].toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(student['full_name'] ?? "Unknown"),
                ],
              )),
              DataCell(Text(student['student_id'] ?? "N/A")),
              DataCell(Text("$points pts", style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getLevelColor(level).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getLevelColor(level).withOpacity(0.3)),
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
              DataCell(Text(dateStr, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
