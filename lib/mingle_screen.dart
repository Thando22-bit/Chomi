import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'chats_screen.dart';

class MingleScreen extends StatefulWidget {
  const MingleScreen({super.key});

  @override
  State<MingleScreen> createState() => _MingleScreenState();
}

class _MingleScreenState extends State<MingleScreen> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  List<DocumentSnapshot> users = [];
  int currentIndex = 0;
  bool loading = true;
  int userDistance = 20;
  PageController imageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserDistance().then((_) => _loadMingleUsers());
  }

  Future<void> _loadCurrentUserDistance() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      userDistance = (userDoc['mingleSettings']['distance'] ?? 20).toInt();
    }
  }

  Future<void> _loadMingleUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();

    setState(() {
      users = snapshot.docs.where((doc) {
        if (doc.id == userId) return false;
        final settings = doc['mingleSettings'];
        if (settings == null || settings['imageUrls'] == null) return false;
        final otherDistance = (settings['distance'] ?? 0).toInt();
        return (otherDistance - userDistance).abs() <= 2;
      }).toList();
      loading = false;
    });
  }

  void _nextProfile() {
    if (currentIndex < users.length - 1) {
      setState(() {
        currentIndex++;
      });
      imageController.jumpToPage(0);
    }
  }

  Future<void> _acceptUser(String otherUserId, String otherUserName) async {
    final matchRef = FirebaseFirestore.instance.collection('matches');

    await matchRef.doc(userId).collection('liked').doc(otherUserId).set({'timestamp': Timestamp.now()});
    final check = await matchRef.doc(otherUserId).collection('liked').doc(userId).get();

    if (check.exists) {
      await matchRef.doc(userId).collection('matches').doc(otherUserId).set({'matchedAt': Timestamp.now()});
      await matchRef.doc(otherUserId).collection('matches').doc(userId).set({'matchedAt': Timestamp.now()});

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatsScreen(
              otherUserId: otherUserId,
              otherUserName: otherUserName,
            ),
          ),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎉 It’s a Match!")));
    }

    _nextProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (users.isEmpty || currentIndex >= users.length) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("No more users nearby 😢", style: TextStyle(color: Colors.white)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    userDistance += 5;
                    loading = true;
                    _loadMingleUsers();
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text("Increase Search Range"),
              )
            ],
          ),
        ),
      );
    }

    final user = users[currentIndex];
    final data = user['mingleSettings'];
    final List imageUrls = data['imageUrls'] ?? [];
    final String bio = data['bio'] ?? '';
    final String gender = data['gender'] ?? 'Unknown';
    final String location = data['location'] ?? '';
    final int age = data['age'] ?? 18;
    final String distance = (data['distance'] ?? 0).toString();
    final String otherUserId = user.id;
    final String otherUserName = user['username'] ?? 'Chomi';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: imageController,
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        imageUrls[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loading) =>
                            loading == null ? child : const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    if (index == 0)
                      const Positioned(
                        right: 10,
                        top: 10,
                        child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54),
                      ),
                  ],
                );
              },
            ),

            // Back button
            Positioned(
              top: 10,
              left: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Info section
            Positioned(
              left: 20,
              right: 20,
              bottom: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$gender, $age',
                      style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('📍 $location  |  ${distance}km',
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 12),
                  Text(bio, style: const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),

            // Image indicators
            if (imageUrls.length > 1)
              Positioned(
                bottom: 180,
                left: 0,
                right: 0,
                child: Center(
                  child: SmoothPageIndicator(
                    controller: imageController,
                    count: imageUrls.length,
                    effect: const ExpandingDotsEffect(
                      dotColor: Colors.white38,
                      activeDotColor: Colors.orange,
                      dotHeight: 8,
                      dotWidth: 8,
                    ),
                  ),
                ),
              ),

            // Action buttons
            Positioned(
              bottom: 30,
              left: 30,
              right: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FloatingActionButton(
                    heroTag: 'decline',
                    onPressed: _nextProfile,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.close),
                  ),
                  FloatingActionButton(
                    heroTag: 'accept',
                    onPressed: () => _acceptUser(otherUserId, otherUserName),
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.favorite),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

