
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LiveViewerScreen extends StatefulWidget {
  final String streamId;
  final String streamerId;

  const LiveViewerScreen({
    super.key,
    required this.streamId,
    required this.streamerId,
  });

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  final TextEditingController _commentController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;
  bool _hasFollowed = false;
  int _likesGiven = 0;

  @override
  void initState() {
    super.initState();
    _addViewer();
    _checkIfFollowed();
    _loadLikesGiven();
  }

  Future<void> _addViewer() async {
    final viewerRef = FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .collection('viewers')
        .doc(user!.uid);

    final doc = await viewerRef.get();
    if (!doc.exists) {
      await viewerRef.set({
        'userId': user!.uid,
        'timestamp': Timestamp.now(),
        'likesGiven': 0,
      });
    }
  }

  Future<void> _loadLikesGiven() async {
    final viewerDoc = await FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .collection('viewers')
        .doc(user!.uid)
        .get();

    if (viewerDoc.exists) {
      final data = viewerDoc.data();
      setState(() {
        _likesGiven = data?['likesGiven'] ?? 0;
      });
    }
  }

  Future<void> _checkIfFollowed() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.streamerId)
        .collection('followers')
        .doc(user!.uid)
        .get();

    setState(() {
      _hasFollowed = doc.exists;
    });
  }

  Future<void> _toggleFollow() async {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.streamerId)
        .collection('followers')
        .doc(user!.uid);

    if (_hasFollowed) {
      await ref.delete();
    } else {
      await ref.set({'followedAt': Timestamp.now()});
    }

    setState(() {
      _hasFollowed = !_hasFollowed;
    });
  }

  Future<void> _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .collection('comments')
        .add({
      'userId': user!.uid,
      'comment': _commentController.text.trim(),
      'timestamp': Timestamp.now(),
    });
    _commentController.clear();
  }

  Future<void> _sendLike() async {
    if (_likesGiven >= 400) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You\'ve reached the like limit for this live.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final docRef =
        FirebaseFirestore.instance.collection('liveStreams').doc(widget.streamId);
    final viewerRef = docRef.collection('viewers').doc(user!.uid);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final liveSnap = await transaction.get(docRef);
      final viewerSnap = await transaction.get(viewerRef);

      final currentLikes = liveSnap.data()?['likes'] ?? 0;
      final currentUserLikes = viewerSnap.data()?['likesGiven'] ?? 0;

      if (currentUserLikes < 400) {
        transaction.update(docRef, {'likes': currentLikes + 1});
        transaction.update(viewerRef, {'likesGiven': currentUserLikes + 1});
        setState(() {
          _likesGiven = currentUserLikes + 1;
        });
      }
    });
  }

  @override
  void dispose() {
    FirebaseFirestore.instance
        .collection('liveStreams')
        .doc(widget.streamId)
        .collection('viewers')
        .doc(user!.uid)
        .delete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Placeholder camera feed background
          Container(color: Colors.black),

          // Comments
          Positioned(
            bottom: 100,
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
                  height: 120,
                  child: ListView(
                    reverse: true,
                    children: snapshot.data!.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          data['comment'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),

          // Viewers (Horizontal)
          Positioned(
            top: 50,
            left: 10,
            height: 50,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('liveStreams')
                  .doc(widget.streamId)
                  .collection('viewers')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox();
                }
                return SizedBox(
                  height: 50,
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: snapshot.data!.docs.map((doc) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: CircleAvatar(
                          backgroundColor: Colors.white30,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),

          // Follow button
          Positioned(
            top: 50,
            right: 10,
            child: ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: Text(_hasFollowed ? 'Following' : '+ Follow'),
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
                hintStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.black.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendComment(),
            ),
          ),

          // Like heart
          Positioned(
            bottom: 20,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.red, size: 35),
              onPressed: _sendLike,
            ),
          ),
        ],
      ),
    );
  }
}





