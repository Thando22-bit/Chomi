import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LiveViewerScreen extends StatefulWidget {
  final String streamId;
  final String streamerId;
  final String streamerName;

  const LiveViewerScreen({
    super.key,
    required this.streamId,
    required this.streamerId,
    required this.streamerName,
  });

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen>
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  int _likeCount = 0;
  int _userLikes = 0;
  List<Widget> _hearts = [];
  Timer? _cleanupTimer;

  @override
  void initState() {
    super.initState();
    _listenToLikes();
    _startHeartCleanup();
    _incrementViewerCount();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _cleanupTimer?.cancel();
    _decrementViewerCount();
    super.dispose();
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
        });
      }
    });
  }

  Future<void> _incrementViewerCount() async {
    await FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .collection('viewers')
        .doc(user!.uid)
        .set({
      'userId': user!.uid,
      'username': user!.displayName ?? 'CHOMI User',
      'joinedAt': Timestamp.now(),
      'profilePic': user!.photoURL ?? '',
    });
  }

  Future<void> _decrementViewerCount() async {
    await FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .collection('viewers')
        .doc(user!.uid)
        .delete();
  }

  void _sendComment() async {
    if (_commentController.text.trim().isEmpty || user == null) return;
    await FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .collection('comments')
        .add({
      'userId': user!.uid,
      'username': user!.displayName ?? 'CHOMI User',
      'profilePic': user!.photoURL ?? '',
      'comment': _commentController.text.trim(),
      'timestamp': Timestamp.now(),
    });
    _commentController.clear();
  }

  void _sendLike() async {
    if (_userLikes >= 400) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have reached the like limit!')),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .update({'likes': FieldValue.increment(1)});

    setState(() {
      _userLikes++;
      _addHeart();
    });
  }

  void _addHeart() {
    final random = Random();
    final heart = Positioned(
      bottom: 100,
      left: 20 + random.nextDouble() * 100,
      child: AnimatedOpacity(
        opacity: 0,
        duration: const Duration(seconds: 2),
        child: const Icon(Icons.favorite, color: Colors.red, size: 30),
      ),
    );
    setState(() {
      _hearts.add(heart);
    });
  }

  void _startHeartCleanup() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _hearts.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main Stream UI
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.live_tv, color: Colors.red, size: 100),
                  const SizedBox(height: 10),
                  Text(
                    "@${widget.streamerName}",
                    style: const TextStyle(color: Colors.white, fontSize: 22),
                  ),
                  const Text("Live Now",
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),

          // Floating hearts
          ..._hearts,

          // Comments list
          Positioned(
            top: 50,
            left: 10,
            right: 10,
            bottom: 100,
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

                return ListView(
                  reverse: true,
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Container(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage:
                                NetworkImage(data['profilePic'] ?? ''),
                            backgroundColor: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['username'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
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
                hintText: 'Say something...',
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

          // Like button
          Positioned(
            bottom: 20,
            right: 10,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _sendLike,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.favorite, color: Colors.red, size: 35),
                      Text(
                        '$_likeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


