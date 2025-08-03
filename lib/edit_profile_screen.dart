import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  File? _selectedImage;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    final data = doc.data();
    if (data != null) {
      _usernameController.text = data['username'] ?? '';
      _bioController.text = data['bio'] ?? '';
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _loading = true);
    String? imageUrl;

    if (_selectedImage != null) {
      final ref = FirebaseStorage.instance.ref().child('profile_images/${currentUser.uid}');
      await ref.putFile(_selectedImage!);
      imageUrl = await ref.getDownloadURL();
    }

    final updates = {
      'username': _usernameController.text.trim(),
      'bio': _bioController.text.trim(),
    };

    if (imageUrl != null) {
      updates['profileImage'] = imageUrl;
    }

    await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update(updates);
    setState(() => _loading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : const AssetImage("assets/avatar.png") as ImageProvider,
                      child: const Align(
                        alignment: Alignment.bottomRight,
                        child: Icon(Icons.edit, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: "Username"),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _bioController,
                    decoration: const InputDecoration(labelText: "Bio"),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text("Save Changes"),
                  ),
                ],
              ),
            ),
    );
  }
}

