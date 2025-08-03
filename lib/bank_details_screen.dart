import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BankDetailsScreen extends StatefulWidget {
  const BankDetailsScreen({super.key});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountTypeController = TextEditingController();

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  Future<void> _loadBankDetails() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = doc.data();

    if (data != null && data['bankDetails'] != null) {
      final bank = data['bankDetails'];
      _accountNameController.text = bank['accountName'] ?? '';
      _bankNameController.text = bank['bankName'] ?? '';
      _accountNumberController.text = bank['accountNumber'] ?? '';
      _accountTypeController.text = bank['accountType'] ?? '';
    }

    setState(() => isLoading = false);
  }

  Future<void> _saveBankDetails() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final data = {
      'accountName': _accountNameController.text.trim(),
      'bankName': _bankNameController.text.trim(),
      'accountNumber': _accountNumberController.text.trim(),
      'accountType': _accountTypeController.text.trim(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'bankDetails': data});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bank details saved successfully")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bank Details")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(_accountNameController, "Account Holder Name"),
                    _buildTextField(_bankNameController, "Bank Name"),
                    _buildTextField(_accountNumberController, "Account Number", isNumber: true),
                    _buildTextField(_accountTypeController, "Account Type (e.g. Savings)"),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: _saveBankDetails,
                      icon: const Icon(Icons.save),
                      label: const Text("Save"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) =>
            value == null || value.trim().isEmpty ? "Required field" : null,
      ),
    );
  }
}

