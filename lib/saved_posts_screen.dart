import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'comment_page.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  List<String> savedPostIds = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    setState(() {
      savedPostIds = List<String>.from(userDoc.data()?['savedPosts'] ?? []);
    });
  }

  void _toggleSave(String postId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
    if (savedPostIds.contains(postId)) {
      await userRef.update({
        'savedPosts': FieldValue.arrayRemove([postId])
      });
    } else {
      await userRef.update({
        'savedPosts': FieldValue.arrayUnion([postId])
      });
    }
    _loadSavedPosts();
  }

  void _toggleLike(String postId, List likes) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    if (likes.contains(currentUserId)) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([currentUserId]),
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([currentUserId]),
        'likesCount': FieldValue.increment(1),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (savedPostIds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Saved Posts")),
        body: Center(child: Text("No saved posts yet.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Saved Posts")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where(FieldPath.documentId, whereIn: savedPostIds)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final postData = post.data() as Map<String, dynamic>;
              final postId = post.id;
              final caption = postData['caption'] ?? '';
              final imageUrl = postData['imageUrl'] ?? '';
              final createdAt = (postData['createdAt'] as Timestamp?)?.toDate();
              final likes = List<String>.from(postData['likes'] ?? []);
              final comments = List.from(postData['comments'] ?? []);
              final hasLiked = likes.contains(currentUserId);
              final isSaved = savedPostIds.contains(postId);
              final userId = postData['userId'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return const SizedBox();

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final username = userData['username'] ?? 'CHOMI User';
                  final profileImageUrl = userData['profileImageUrl'];

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundImage: profileImageUrl != null
                                ? NetworkImage(profileImageUrl)
                                : const AssetImage("assets/avatar.png")
                                    as ImageProvider,
                          ),
                          title: Text(username),
                          subtitle: Text(
                            createdAt != null
                                ? DateFormat('MMM d, h:mm a').format(createdAt)
                                : '',
                          ),
                        ),
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(imageUrl),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(caption),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 10),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  hasLiked ? Icons.favorite : Icons.favorite_border,
                                  color: hasLiked ? Colors.red : Colors.grey,
                                ),
                                onPressed: () => _toggleLike(postId, likes),
                              ),
                              Text('${likes.length} likes'),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(Icons.comment),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CommentPage(postId: postId),
                                    ),
                                  );
                                },
                              ),
                              Text('${comments.length} comments'),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: Icon(
                                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                                  color: isSaved ? Colors.orange : Colors.grey,
                                ),
                                onPressed: () => _toggleSave(postId),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: const Icon(Icons.share),
                                onPressed: () => Share.share(
                                    "$caption\n\nShared via CHOMI App"),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

