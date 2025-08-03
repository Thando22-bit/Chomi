import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  String selectedFilter = 'all';
  double totalApprovedThisMonth = 0;

  @override
  void initState() {
    super.initState();
    _calculateMonthlyApproved();
  }

  Future<void> _calculateMonthlyApproved() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final snapshot = await FirebaseFirestore.instance
        .collection('withdrawals')
        .where('status', isEqualTo: 'approved')
        .where('requestedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .get();

    double total = 0;
    for (var doc in snapshot.docs) {
      final amount = (doc.data()['amount'] ?? 0).toDouble();
      total += amount;
    }

    setState(() => totalApprovedThisMonth = total);
  }

  Future<void> _updateStatus(String docId, String newStatus, String userId) async {
    await FirebaseFirestore.instance.collection('withdrawals').doc(docId).update({
      'status': newStatus,
    });

    await _sendWithdrawalNotification(userId, newStatus);
    _calculateMonthlyApproved();
  }

  Future<void> _sendWithdrawalNotification(String userId, String status) async {
    String message;
    switch (status) {
      case 'approved':
        message = "Your withdrawal has been approved.";
        break;
      case 'rejected':
        message = "Your withdrawal has been rejected.";
        break;
      default:
        message = "Your withdrawal is pending review.";
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'type': 'withdrawal',
      'message': message,
      'fromUserId': 'admin',
      'fromUsername': 'Admin',
      'fromProfileImage': '', // optional: replace with app logo URL
      'timestamp': FieldValue.serverTimestamp(),
      'isNew': true,
    });

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'unreadNotifications': FieldValue.increment(1),
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != '1qvSXPuGGqZ3fvGbbMadqk9v6IV2') {
      return const Scaffold(body: Center(child: Text("Access Denied")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            "Total Approved This Month: R${totalApprovedThisMonth.toStringAsFixed(2)}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButton<String>(
              value: selectedFilter,
              onChanged: (value) {
                setState(() => selectedFilter = value!);
              },
              items: const [
                DropdownMenuItem(value: 'all', child: Text("All")),
                DropdownMenuItem(value: 'pending', child: Text("Pending")),
                DropdownMenuItem(value: 'approved', child: Text("Approved")),
                DropdownMenuItem(value: 'rejected', child: Text("Rejected")),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: selectedFilter == 'all'
                  ? FirebaseFirestore.instance
                      .collection('withdrawals')
                      .orderBy('requestedAt', descending: true)
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('withdrawals')
                      .where('status', isEqualTo: selectedFilter)
                      .orderBy('requestedAt', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No withdrawal requests."));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final amount = data['amount'] ?? 0.0;
                    final status = data['status'] ?? 'pending';
                    final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
                    final userId = data['userId'];

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) return const SizedBox.shrink();
                        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

                        final username = userData?['username'] ?? "User";
                        final points = (userData?['points'] ?? 0).toDouble();
                        final bankDetails = userData?['bankDetails'] ?? {};
                        final bankName = bankDetails['bankName'] ?? 'N/A';
                        final accountNumber = bankDetails['accountNumber'] ?? 'N/A';
                        final accountType = bankDetails['accountType'] ?? 'N/A';

                        return ListTile(
                          leading: const Icon(Icons.account_circle),
                          title: Text("R${amount.toStringAsFixed(2)} by $username"),
                          subtitle: Text(
                            requestedAt != null
                                ? DateFormat('MMM d, yyyy • hh:mm a').format(requestedAt)
                                : "No date",
                          ),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                              ),
                              builder: (context) {
                                return Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Username: $username", style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 6),
                                      Text("Total Points: ${points.toStringAsFixed(2)}"),
                                      const Divider(),
                                      Text("Bank Name: $bankName"),
                                      Text("Account Number: $accountNumber"),
                                      Text("Account Type: $accountType"),
                                      const Divider(),
                                      Text("Requested Amount: R${amount.toStringAsFixed(2)}"),
                                      Text("Requested At: ${DateFormat('MMM d, yyyy • hh:mm a').format(requestedAt!)}"),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (status == 'pending') ...[
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () => _updateStatus(docId, 'approved', userId),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: () => _updateStatus(docId, 'rejected', userId),
                                ),
                              ] else
                                _statusChip(status),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Rejected';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withOpacity(0.1),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }
}


