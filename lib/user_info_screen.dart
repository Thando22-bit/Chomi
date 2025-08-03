import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import 'post_widget.dart';
import 'chats_screen.dart';

class UserInfoScreen extends StatefulWidget {
  final String userId;
  const UserInfoScreen({super.key, required this.userId});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final currentUser = FirebaseAuth.instance.currentUser!;
  Map<String, dynamic>? userData;
  bool isMe = false;
  bool isFollowing = false;

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        userData = data;
        isMe = currentUser.uid == widget.userId;
        isFollowing = List<String>.from(data['followers'] ?? []).contains(currentUser.uid);
      });
    }
  }

  Future<void> toggleFollow() async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
    final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

    setState(() => isFollowing = !isFollowing);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      if (isFollowing) {
        tx.update(userRef, {'followers': FieldValue.arrayUnion([currentUser.uid])});
        tx.update(currentUserRef, {'following': FieldValue.arrayUnion([widget.userId])});

        // Send follow notification
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        final userData = userDoc.data()!;

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('notifications')
            .add({
          'type': 'follow',
          'message': '${userData['username']} started following you',
          'fromUserId': currentUser.uid,
          'fromUsername': userData['username'],
          'fromProfileImage': userData['profileImage'],
          'timestamp': FieldValue.serverTimestamp(),
          'isNew': true,
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .update({'unreadNotifications': FieldValue.increment(1)});
      } else {
        tx.update(userRef, {'followers': FieldValue.arrayRemove([currentUser.uid])});
        tx.update(currentUserRef, {'following': FieldValue.arrayRemove([widget.userId])});
      }
    });

    fetchUser();
  }

  Widget _buildCount(String label, int count) {
    return Column(
      children: [
        Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  Future<String?> _showReportDialog() async {
    TextEditingController reasonController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Report User'),
          content: TextField(
            controller: reasonController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Enter reason for reporting',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, reasonController.text);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _showProfileImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: Stack(
            children: [
              Center(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
              Positioned(
                top: 30,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: RefreshIndicator(
        onRefresh: fetchUser,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  if (userData!['profileImage'] != null) {
                    _showProfileImage(userData!['profileImage']);
                  }
                },
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: userData!['profileImage'] != null
                      ? NetworkImage(userData!['profileImage'])
                      : const AssetImage("assets/avatar.png") as ImageProvider,
                ),
              ),
              const SizedBox(height: 10),
              Text(userData!['username'] ?? 'User', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(userData!['bio'] ?? '', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCount('Followers', (userData!['followers'] ?? []).length),
                  const SizedBox(width: 20),
                  _buildCount('Following', (userData!['following'] ?? []).length),
                ],
              ),
              const SizedBox(height: 10),

              if (userData!['verified'] == true)
                const Icon(Icons.verified, color: Color(0xFFFFD700), size: 18),

              const SizedBox(height: 10),

              if (!isMe)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: toggleFollow,
                      style: TextButton.styleFrom(
                        backgroundColor: isFollowing ? Colors.orange : Colors.white,
                        foregroundColor: isFollowing ? Colors.white : Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                      child: Text(isFollowing ? 'Following' : 'Follow'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatsScreen(
                              otherUserId: widget.userId,
                              otherUserName: userData!['username'],
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text("Message"),
                    ),
                    const SizedBox(width: 10),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (value) async {
                        if (value == 'report') {
                          final reason = await _showReportDialog();
                          if (reason != null && reason.trim().isNotEmpty) {
                            await FirebaseFirestore.instance.collection('reports').add({
                              'reportedUserId': widget.userId,
                              'reportedBy': currentUser.uid,
                              'reason': reason.trim(),
                              'timestamp': Timestamp.now(),
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User reported successfully')),
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'report', child: Text('Report User')),
                      ],
                    ),
                  ],
                ),

              if (isMe)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    ).then((_) => fetchUser());
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text("Edit Profile"),
                ),

              const Divider(thickness: 1),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text("Posts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .where('uid', isEqualTo: widget.userId)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text("No posts yet"),
                    );
                  }

                  final posts = snapshot.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final postData = posts[index].data() as Map<String, dynamic>;
                      final postId = posts[index].id;
                      return PostWidget(postData: postData, postId: postId);
                    },
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}







