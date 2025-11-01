import 'package:flutter/material.dart';
import '../../common/widgets/app_button.dart';
import '../../common/widgets/app_card.dart';


class HomePage extends StatelessWidget {
  const HomePage({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FridgeRadar')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Welcome!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Scan a barcode to add a new item.')),
                  AppButton(label: 'Scan', onPressed: () {}),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppButton(label: 'Add item', icon: Icons.add, onPressed: () {}),
          ],
        ),
      ),
    );
  }
}