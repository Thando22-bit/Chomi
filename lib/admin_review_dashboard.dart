import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminReviewDashboard extends StatefulWidget {
  const AdminReviewDashboard({super.key});

  @override
  State<AdminReviewDashboard> createState() => _AdminReviewDashboardState();
}

class _AdminReviewDashboardState extends State<AdminReviewDashboard> {
  String selectedStatus = 'all';

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('withdrawals')
        .doc(docId)
        .update({'status': newStatus});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Marked as $newStatus")),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Review Dashboard'),
        backgroundColor: Colors.orange,
        leading: IconButton(
          icon: const Icon(Icons.home, color: Colors.white),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) => setState(() => selectedStatus = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text("All")),
              PopupMenuItem(value: 'pending', child: Text("Pending")),
              PopupMenuItem(value: 'approved', child: Text("Approved")),
              PopupMenuItem(value: 'rejected', child: Text("Rejected")),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('withdrawals')
            .orderBy('requestedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs.where((doc) {
            if (selectedStatus == 'all') return true;
            return doc['status'] == selectedStatus;
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text("No withdrawals found."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;

              final userId = data['userId'] ?? 'N/A';
              final amount = data['amount'] ?? 0.0;
              final status = data['status'] ?? 'pending';
              final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text("User ID: $userId"),
                  subtitle: Text(
                    "Amount: R${amount.toStringAsFixed(2)}\n"
                    "Date: ${requestedAt != null ? DateFormat('MMM d, yyyy • hh:mm a').format(requestedAt) : 'N/A'}",
                  ),
                  trailing: status == 'pending'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _updateStatus(docId, 'approved'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _updateStatus(docId, 'rejected'),
                            ),
                          ],
                        )
                      : Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: status == 'approved'
                                ? Colors.green
                                : status == 'rejected'
                                    ? Colors.red
                                    : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}


