import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class BusinessAdvertiseScreen extends StatefulWidget {
  const BusinessAdvertiseScreen({super.key});

  @override
  State<BusinessAdvertiseScreen> createState() => _BusinessAdvertiseScreenState();
}

class _BusinessAdvertiseScreenState extends State<BusinessAdvertiseScreen> {
  final TextEditingController _captionController = TextEditingController();
  final List<File> _selectedImages = [];
  bool _isLoading = false;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.length + _selectedImages.length > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can select up to 10 images.")),
      );
      return;
    }

    setState(() {
      _selectedImages.addAll(pickedFiles.map((file) => File(file.path)));
    });
  }

  Future<List<String>> _uploadImages() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    List<String> downloadUrls = [];

    for (File image in _selectedImages) {
      final fileName = 'advert_${const Uuid().v4()}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('hustle_adverts')
          .child(userId)
          .child(fileName);

      await ref.putFile(image);
      final url = await ref.getDownloadURL();
      downloadUrls.add(url);
    }

    return downloadUrls;
  }

  Future<void> _submitAdPost() async {
    if (_selectedImages.isEmpty || _captionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add images and a caption.")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final imageUrls = await _uploadImages();

      await FirebaseFirestore.instance.collection('hustlePosts').add({
        'userId': user!.uid,
        'type': 'advertise',
        'description': _captionController.text.trim(),
        'images': imageUrls,
        'createdAt': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Advertisement posted successfully!")),
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
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text("Post Advertisement"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _selectedImages.isEmpty
                    ? const Center(
                        child: Text(
                          "Tap to select up to 10 images",
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImages[index],
                                height: 180,
                                width: 180,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _captionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Describe your business or service...",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitAdPost,
                icon: const Icon(Icons.business),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Post Advertisement"),
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
    );
  }
}

