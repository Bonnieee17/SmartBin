import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserTable extends StatelessWidget {
  final List<Map<String, dynamic>> records;

  const UserTable({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 800),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.withOpacity(0.05)),
          horizontalMargin: 12,
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text("USER ID", style: TextStyle(fontSize: 12, color: Colors.grey))),
            DataColumn(label: Text("WASTE TYPE", style: TextStyle(fontSize: 12, color: Colors.grey))),
            DataColumn(label: Text("DATE", style: TextStyle(fontSize: 12, color: Colors.grey))),
            DataColumn(label: Text("POINTS", style: TextStyle(fontSize: 12, color: Colors.grey))),
            DataColumn(label: Text("STATUS", style: TextStyle(fontSize: 12, color: Colors.grey))),
          ],
          rows: records.map((activity) {
            final createdAt = activity['created_at'] != null 
                ? DateTime.parse(activity['created_at']) 
                : DateTime.now();
            
            final dateStr = DateFormat('MMM d, h:mm a').format(createdAt);
            final userId = activity['user_id']?.toString() ?? "Unknown";
            final shortId = userId.length > 8 ? userId.substring(0, 8) : userId;

            return DataRow(cells: [
              DataCell(Text(shortId, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(activity['waste_type'] ?? "Other")),
              DataCell(Text(dateStr)),
              DataCell(Text("+${activity['points_earned'] ?? 0}", style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text("Verified", style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.bold)),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

