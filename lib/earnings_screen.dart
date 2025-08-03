import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'bank_details_screen.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int totalLikes = 0;
  int totalViews = 0;
  int totalComments = 0;
  bool isLoading = true;
  DateTime? lastWithdrawal;

  
  double get totalPoints =>
      (totalLikes * 1) + (totalViews * 0.1) + (totalComments * 2);
  double get totalEarnings => totalPoints / 1000; // 1000 pts = R1

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();

    final snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('uid', isEqualTo: currentUserId)
        .get();

    int likes = 0;
    int views = 0;
    int comments = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();

      final List likesList = (data['likes'] ?? []) as List;
      likes += likesList.length;

      final List viewsList = (data['views'] ?? []) as List;
      views += viewsList.length;

      comments += (data['commentCount'] ?? 0) as int;
    }

    final newPoints = double.parse(
        ((likes * 1) + (views * 0.1) + (comments * 2)).toStringAsFixed(2));

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .update({'points': newPoints});

    setState(() {
      totalLikes = likes;
      totalViews = views;
      totalComments = comments;
      lastWithdrawal =
          (userDoc.data()?['lastWithdrawalDate'] as Timestamp?)?.toDate();
      isLoading = false;
    });
  }

  Future<void> _handleWithdraw() async {
    final now = DateTime.now();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    if (totalEarnings < 100) {
      _showError("You need at least R100 to withdraw.");
      return;
    }

    if (lastWithdrawal != null &&
        lastWithdrawal!.month == now.month &&
        lastWithdrawal!.year == now.year) {
      _showError(
          "You can only withdraw once per month. Try again next month.");
      return;
    }

    // Save withdrawal request
    await FirebaseFirestore.instance.collection('withdrawals').add({
      'userId': currentUserId,
      'amount': double.parse(totalEarnings.toStringAsFixed(2)),
      'status': 'pending',
      'requestedAt': Timestamp.now(),
    });

    // Reset user points & set last withdrawal date
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .update({
      'lastWithdrawalDate': Timestamp.fromDate(now),
      'points': 0, // reset points after withdrawal
    });

    setState(() {
      lastWithdrawal = now;
      totalLikes = 0;
      totalViews = 0;
      totalComments = 0;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Withdrawal request submitted! Points reset.")),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Earnings"),
        centerTitle: true,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 15),

                  // Big Balance Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Column(
                        children: [
                          const Text(
                            "Current Balance",
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "R${totalEarnings.toStringAsFixed(2)}",
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  //  Info Card
                  Card(
                    elevation: 2,
                    child: Column(
                      children: [
                        _infoTile("Total Points",
                            "${totalPoints.toStringAsFixed(0)} pts"),
                        if (lastWithdrawal != null)
                          _infoTile(
                              "Last Withdrawal",
                              "${lastWithdrawal!.day}-${lastWithdrawal!.month}-${lastWithdrawal!.year}"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  //  Withdraw Button
                  ElevatedButton.icon(
                    onPressed: _handleWithdraw,
                    icon: const Icon(Icons.money),
                    label: const Text("Withdraw"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  //  Refresh Button
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh Balance"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  //  Bank Button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BankDetailsScreen()),
                      ).then((_) => _loadData());
                    },
                    icon: const Icon(Icons.account_balance),
                    label: const Text("Update/View Bank Details"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blueGrey,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoTile(String label, String value) {
    return ListTile(
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing:
          Text(value, style: const TextStyle(fontSize: 18, color: Colors.black87)),
    );
  }
}

