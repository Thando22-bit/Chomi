import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _captionController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  List<File> _selectedImages = [];
  File? _videoFile;
  bool isUploading = false;
  double progress = 0;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() => _selectedImages =
          pickedFiles.map((e) => File(e.path)).toList());
    }
  }

  Future<void> _pickVideo() async {
    final pickedVideo =
        await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (pickedVideo != null) {
      setState(() => _videoFile = File(pickedVideo.path));
    }
  }

  Future<File> _compressImage(File file, {int quality = 90}) async {
    final result = await FlutterImageCompress.compressWithFile(
      file.path,
      minWidth: 1080,
      minHeight: 1080,
      quality: quality,
    );
    final outPath =
        '${file.parent.path}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
    return File(outPath)..writeAsBytesSync(result!);
  }

  Future<void> _uploadPost() async {
    if (_captionController.text.trim().isEmpty &&
        _selectedImages.isEmpty &&
        _videoFile == null) return;

    setState(() {
      isUploading = true;
      progress = 0;
    });

    List<String> imageUrls = [];
    List<String> thumbnailUrls = [];

    //  Get verified status from user document
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final isVerified = userDoc.data()?['verified'] ?? false;

    if (_selectedImages.isNotEmpty) {
      final total = _selectedImages.length;
      int completed = 0;

      await Future.wait(_selectedImages.map((originalImage) async {
        final fullImage = await _compressImage(originalImage, quality: 90);
        final fullRef = FirebaseStorage.instance
            .ref()
            .child('posts/images/full_${DateTime.now().millisecondsSinceEpoch}_${path.basename(fullImage.path)}');
        await fullRef.putFile(fullImage);
        final fullUrl = await fullRef.getDownloadURL();
        imageUrls.add(fullUrl);

        final thumbImage = await _compressImage(originalImage, quality: 25);
        final thumbRef = FirebaseStorage.instance
            .ref()
            .child('posts/images/thumb_${DateTime.now().millisecondsSinceEpoch}_${path.basename(thumbImage.path)}');
        await thumbRef.putFile(thumbImage);
        final thumbUrl = await thumbRef.getDownloadURL();
        thumbnailUrls.add(thumbUrl);

        completed++;
        setState(() => progress = completed / total);
      }));
    }

    String? videoUrl;
    if (_videoFile != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('posts/videos/${DateTime.now().millisecondsSinceEpoch}_${path.basename(_videoFile!.path)}');
      await ref.putFile(_videoFile!);
      videoUrl = await ref.getDownloadURL();
    }

    await FirebaseFirestore.instance.collection('posts').add({
      'uid': user!.uid,
      'caption': _captionController.text.trim(),
      'imageUrls': imageUrls,
      'thumbnailUrls': thumbnailUrls,
      'videoUrl': videoUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [],
      'likesCount': 0,
      'type': videoUrl != null ? 'video' : 'image',
      'verified': isVerified,
    });

    setState(() {
      isUploading = false;
      progress = 0;
      _selectedImages.clear();
      _videoFile = null;
      _captionController.clear();
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text('Create Post', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Caption input
            TextField(
              controller: _captionController,
              maxLines: null,
              decoration: InputDecoration(
                labelText: 'Write a caption...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 15),

            // Image preview
            if (_selectedImages.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _selectedImages
                    .map((file) => ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(file,
                              width: 100, height: 100, fit: BoxFit.cover),
                        ))
                    .toList(),
              ),

            // Video preview
            if (_videoFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black),
                  child: const Center(
                      child: Text('Video selected',
                          style: TextStyle(color: Colors.white))),
                ),
              ),

            const SizedBox(height: 20),

            // Pick buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo),
                  label: const Text('Add Images'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                ElevatedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Add Video'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ],
            ),

            const SizedBox(height: 25),

            // Upload progress
            if (isUploading)
              Column(
                children: [
                  const Text("Uploading...",
                      style: TextStyle(fontSize: 14, color: Colors.orange)),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress),
                ],
              ),

            // Post button
            if (!isUploading)
              Center(
                child: ElevatedButton(
                  onPressed: _uploadPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 60, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Post',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}




