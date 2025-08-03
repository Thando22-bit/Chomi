import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'live_stream_screen.dart'; 

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  late CameraController _cameraController;
  bool _isCameraInitialized = false;
  bool _isFrontCamera = true;

  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _likeTargetController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final selectedCamera = _isFrontCamera ? cameras.first : cameras.last;

    _cameraController = CameraController(selectedCamera, ResolutionPreset.medium);
    await _cameraController.initialize();
    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  Future<void> _toggleCamera() async {
    setState(() {
      _isCameraInitialized = false;
      _isFrontCamera = !_isFrontCamera;
    });
    await _initializeCamera();
  }

  Future<void> _startLive() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final streamId = const Uuid().v4();
    final username = user.displayName ?? 'CHOMI User';  // Username of the current user
    final profileImage = user.photoURL ?? '';  // Profile image URL

    // Create the live stream entry in Firestore
    await FirebaseFirestore.instance.collection('liveStreams').doc(streamId).set({
      'streamId': streamId,
      'userId': user.uid,
      'username': username,
      'topic': _topicController.text.trim(),
      'likeTarget': int.tryParse(_likeTargetController.text.trim()) ?? 0,
      'filterTag': _filterController.text.trim(),
      'createdAt': Timestamp.now(),
      'likes': 0,
      'views': 0,
      'isPaused': false,
      'isEnded': false,
    });

    // Notify all followers of the user that they are live
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final followers = List<String>.from(userDoc['followers'] ?? []);

    for (var followerId in followers) {
      await FirebaseFirestore.instance.collection('users').doc(followerId).collection('notifications').add({
        'type': 'live',
        'message': '$username is live now! Click to join!',
        'fromUserId': user.uid,
        'fromUsername': username,  // Passed the username
        'fromProfileImage': profileImage,  // Passed profile image URL
        'streamId': streamId,
        'timestamp': FieldValue.serverTimestamp(),
        'isNew': true,
        'isEnded': false, // Live is still ongoing
      });

      // Increment the unread notification count for followers
      await FirebaseFirestore.instance.collection('users').doc(followerId).update({
        'unreadNotifications': FieldValue.increment(1),
      });
    }

    // Navigate to the live stream screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveStreamScreen(
          streamId: streamId,
          cameraController: _cameraController,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _topicController.dispose();
    _likeTargetController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isCameraInitialized)
            CameraPreview(_cameraController)
          else
            const Center(child: CircularProgressIndicator()),

          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                _buildTextField(_topicController, 'Topic'),
                const SizedBox(height: 10),
                _buildTextField(_likeTargetController, 'Like Target (optional)', isNumber: true),
                const SizedBox(height: 10),
                _buildTextField(_filterController, 'Filter Tag (optional)'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleCamera,
                      icon: const Icon(Icons.flip_camera_ios),
                      label: const Text("Flip"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _startLive,
                      child: const Text("Go Live"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black.withOpacity(0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}












