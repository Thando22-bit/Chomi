import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
// Removed: import 'package:csv/csv.dart';
// Removed: import 'package:path_provider/path_provider.dart';

class AdminExportScreen extends StatefulWidget {
  const AdminExportScreen({super.key});

  @override
  State<AdminExportScreen> createState() => _AdminExportScreenState();
}

class _AdminExportScreenState extends State<AdminExportScreen> {
  bool isLoading = false;
  List<Map<String, dynamic>> exportData = [];

  Future<void> _generateExport() async {
    setState(() => isLoading = true);

    final withdrawalsSnapshot = await FirebaseFirestore.instance
        .collection('withdrawals')
        .where('status', isEqualTo: 'approved')
        .orderBy('requestedAt', descending: true)
        .get();

    List<Map<String, dynamic>> data = [];

    for (var doc in withdrawalsSnapshot.docs) {
      final withdrawal = doc.data();
      final userId = withdrawal['userId'];
      final amount = withdrawal['amount'] ?? 0;
      final requestedAt = (withdrawal['requestedAt'] as Timestamp?)?.toDate();

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final bank = userData?['bankDetails'] ?? {};

      data.add({
        'userId': userId,
        'amount': amount,
        'requestedAt': requestedAt?.toIso8601String() ?? '',
        'bankName': bank['bankName'] ?? '',
        'accountNumber': bank['accountNumber'] ?? '',
        'accountHolder': bank['accountHolder'] ?? '',
        'branchCode': bank['branchCode'] ?? '',
      });
    }

    setState(() {
      exportData = data;
      isLoading = false;
    });

    // CSV export disabled, so only show message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("CSV export is currently disabled.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Export")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: isLoading ? null : _generateExport,
              icon: const Icon(Icons.download),
              label: const Text("Load Withdrawals"),
            ),
            const SizedBox(height: 20),
            if (isLoading) const CircularProgressIndicator(),
            if (exportData.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: exportData.length,
                  itemBuilder: (context, index) {
                    final row = exportData[index];
                    return ListTile(
                      title: Text("User: ${row['userId']} - R${row['amount']}"),
                      subtitle: Text("Bank: ${row['bankName']} - ${row['accountNumber']}"),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}



