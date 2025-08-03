import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BriefCVScreen extends StatefulWidget {
  const BriefCVScreen({super.key});

  @override
  State<BriefCVScreen> createState() => _BriefCVScreenState();
}

class _BriefCVScreenState extends State<BriefCVScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _objectiveController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isLoading = false;

  Future<void> _submitCV() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('hustlePosts').add({
        'userId': user!.uid,
        'type': 'cv',
        'objective': _objectiveController.text.trim(),
        'skills': _skillsController.text.trim(),
        'education': _educationController.text.trim(),
        'experience': '', // Reserved for future 
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("CV posted successfully!")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _objectiveController.dispose();
    _skillsController.dispose();
    _educationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Widget _buildInputField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    int maxLines = 1,
    bool requiredField = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        validator: requiredField
            ? (value) =>
                value == null || value.trim().isEmpty ? 'Required field' : null
            : null,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.orange),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[850],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text("Brief CV"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildInputField(
                label: '🎯 Objective - Why should we hire you?',
                icon: Icons.person_outline,
                controller: _objectiveController,
                maxLines: 4,
              ),
              _buildInputField(
                label: '🛠 Skills - List your skills',
                icon: Icons.build,
                controller: _skillsController,
                maxLines: 4,
              ),
              _buildInputField(
                label: '📚 Education',
                icon: Icons.school,
                controller: _educationController,
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),
              _buildInputField(
                label: '📞 Phone Number',
                icon: Icons.phone,
                controller: _phoneController,
              ),
              _buildInputField(
                label: '✉️ Email Address',
                icon: Icons.email,
                controller: _emailController,
              ),
              _buildInputField(
                label: '📍 Physical Address',
                icon: Icons.location_on,
                controller: _addressController,
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitCV,
                  icon: const Icon(Icons.send),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Post CV"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



