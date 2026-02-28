import 'package:flutter/material.dart';

class TrashTile extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const TrashTile({super.key, required this.onTap, required this.count});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.grey[300],
                child: const Icon(Icons.delete, color: Colors.grey, size: 50),
              ),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Recycle Bin',
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),

          Text(
            "$count items",
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}
