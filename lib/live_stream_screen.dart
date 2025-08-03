import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LiveStreamScreen extends StatefulWidget {
  final String streamId;
  final CameraController cameraController;

  const LiveStreamScreen({
    super.key,
    required this.streamId,
    required this.cameraController,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isPaused = false;
  int _likeCount = 0;
  int _viewerCount = 0;

  late CameraController _cameraController;

  @override
  void initState() {
    super.initState();
    _cameraController = widget.cameraController;
    _listenToLikes();
    _listenToViewers();
  }

  void _listenToLikes() {
    FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _likeCount = snapshot.data()?['likes'] ?? 0;
          _isPaused = snapshot.data()?['isPaused'] ?? false;
        });
      }
    });
  }

  void _listenToViewers() {
    FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .collection('viewers')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _viewerCount = snapshot.docs.length;
      });
    });
  }

  Future<void> _togglePause() async {
    await FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .update({'isPaused': !_isPaused});
  }

  Future<void> _endStream() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .get();

    final totalLikes = doc.data()?['likes'] ?? 0;
    final earnedPoints = (totalLikes / 100).floor(); // 1000 likes = 10 pts

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final existingPoints = userSnap.data()?['points'] ?? 0;

      transaction.update(userRef, {
        'points': existingPoints + earnedPoints,
      });

      transaction.update(doc.reference, {
        'isEnded': true,
      });
    });

    Navigator.pop(context);
  }

  Future<void> _flipCamera() async {
    final cameras = await availableCameras();
    final lensDirection = _cameraController.description.lensDirection;
    final newCamera = cameras.firstWhere(
      (camera) => camera.lensDirection != lensDirection,
      orElse: () => cameras.first,
    );

    final newController = CameraController(newCamera, ResolutionPreset.medium);
    await newController.initialize();

    setState(() {
      _cameraController = newController;
    });
  }

  Future<void> _sendComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (_commentController.text.trim().isEmpty || user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    await FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .collection('comments')
        .add({
      'userId': user.uid,
      'comment': _commentController.text.trim(),
      'timestamp': Timestamp.now(),
      'username': userDoc['username'] ?? 'User',
      'profilePic': userDoc['profilePic'] ?? '',
    });

    _commentController.clear();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isPaused
              ? const Center(
                  child: Text(
                    '⏸️ Live Paused',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                )
              : Positioned.fill(child: CameraPreview(_cameraController)),

          // Top controls
          Positioned(
            top: 40,
            right: 20,
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _togglePause,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(_isPaused ? 'Resume' : 'Pause'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _endStream,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("End"),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _flipCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("Flip"),
                ),
              ],
            ),
          ),

          // Live tag + viewers
          Positioned(
            top: 40,
            left: 20,
            child: Row(
              children: [
                const Icon(Icons.fiber_manual_record, color: Colors.red),
                const SizedBox(width: 5),
                const Text(
                  "Live Stream",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(width: 15),
                Icon(Icons.visibility,
                    color: Colors.white.withOpacity(0.7), size: 20),
                const SizedBox(width: 4),
                Text(
                  "$_viewerCount",
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),

          // Comments section
          Positioned(
            bottom: 80,
            left: 10,
            right: 10,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('liveStreams')
                  .doc(widget.streamId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox();
                }
                return SizedBox(
                  height: 150,
                  child: ListView(
                    reverse: true,
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundImage:
                                  (data['profilePic'] != null &&
                                          data['profilePic'] != '')
                                      ? NetworkImage(data['profilePic'])
                                      : const AssetImage(
                                              'assets/default_avatar.png')
                                          as ImageProvider,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['username'] ?? 'User',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    data['comment'] ?? '',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),

          // Comment input
          Positioned(
            bottom: 20,
            left: 10,
            right: 60,
            child: TextField(
              controller: _commentController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type your comment...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (_) => _sendComment(),
            ),
          ),

          // Like heart
          Positioned(
            bottom: 20,
            right: 10,
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.favorite, color: Colors.red, size: 35),
                    Text(
                      '$_likeCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


