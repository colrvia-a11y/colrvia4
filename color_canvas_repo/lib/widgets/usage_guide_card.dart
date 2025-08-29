import 'package:flutter/material.dart';

class UsageGuideCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const UsageGuideCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final hex = (item['hex'] as String).replaceFirst('#', '');
    final color = Color(int.parse('0xff$hex'));
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color),
        title: Text('${(item['role'] as String).toUpperCase()} → ${item['surface']}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${item['finishRecommendation']} • ${item['sheen']}\n${item['howToUse']}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(item['brandName'] ?? '', style: const TextStyle(fontSize: 12)),
            Text(item['code'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}