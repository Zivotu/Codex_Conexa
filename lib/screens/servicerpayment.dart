// lib/screens/servicerpayment.dart

import 'package:flutter/material.dart';

class ServicerPaymentScreen extends StatelessWidget {
  const ServicerPaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sustav naplate'),
      ),
      body: const Center(
        child: Text('Postavke sustava naplate servisera'),
      ),
    );
  }
}
