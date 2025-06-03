import 'package:flutter/material.dart';

class RepairRequestDetail extends StatelessWidget {
  const RepairRequestDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repair Request Detail'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Some Text',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            // Ostatak vašeg koda
          ],
        ),
      ),
    );
  }
}
