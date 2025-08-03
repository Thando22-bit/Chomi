import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'comment_page.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  DocumentSnapshot<Map<String, dynamic>>? currentUserDoc;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    setState(() {
      currentUserDoc = snapshot;
    });
  }

  void _toggleLike(String postId, List likes) async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final isLiked = likes.contains(currentUserId);

    await postRef.update({
      'likes': isLiked
          ? FieldValue.arrayRemove([currentUserId])
          : FieldValue.arrayUnion([currentUserId]),
      'likesCount': FieldValue.increment(isLiked ? -1 : 1),
    });
  }

  Future<void> _trackUniqueView(String postId) async {
    final viewRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .collection('views')
        .doc(currentUserId);

    final viewDoc = await viewRef.get();
    if (!viewDoc.exists) {
      await viewRef.set({'viewedAt': Timestamp.now()});
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'views': FieldValue.increment(1),
      });
    }
  }

  void _reportPost(String postId) {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report Post"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: "Reason"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                await FirebaseFirestore.instance.collection('reports').add({
                  'postId': postId,
                  'reportedBy': currentUserId,
                  'reason': reason,
                  'timestamp': Timestamp.now(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Reported")),
                );
              }
            },
            child: const Text("Submit"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserDoc == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final followingList = List<String>.from(currentUserDoc!['following'] ?? []);
    final savedPosts = List<String>.from(currentUserDoc!['savedPosts'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text("CHOMI Feed"),
        centerTitle: true,
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, postSnapshot) {
          if (!postSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = postSnapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final postData = post.data() as Map<String, dynamic>;
              final postId = post.id;
              final userId = postData['userId'];

              _trackUniqueView(postId);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return const SizedBox();

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;

                  final username = userData?['username'] ?? 'CHOMI User';
                  final profileUrl = userData?['profileImageUrl'];
                  final caption = postData['caption'] ?? '';
                  final imageUrl = postData['imageUrl'] ?? '';
                  final createdAt =
                      (postData['createdAt'] as Timestamp?)?.toDate();
                  final likes = List<String>.from(postData['likes'] ?? []);
                  final likeCount = postData['likesCount'] ?? 0;
                  final views = postData['views'] ?? 0;
                  final isLiked = likes.contains(currentUserId);
                  final isSaved = savedPosts.contains(postId);
                  final isFollowing = followingList.contains(userId);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundImage: profileUrl != null
                                ? NetworkImage(profileUrl)
                                : const AssetImage("assets/avatar.png") as ImageProvider,
                          ),
                          title: Text(username),
                          subtitle: Text(createdAt != null
                              ? DateFormat('MMM d, h:mm a').format(createdAt)
                              : ''),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'report') {
                                _reportPost(postId);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'report', child: Text("Report")),
                            ],
                          ),
                        ),
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(imageUrl),
                          ),
                        if (caption.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(caption),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _toggleLike(postId, likes),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) =>
                                      ScaleTransition(scale: animation, child: child),
                                  child: Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    key: ValueKey(isLiked),
                                    color: isLiked ? Colors.red : Colors.grey,
                                    size: 26,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('$likeCount'),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.comment),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommentPage(postId: postId),
                                  ),
                                ),
                              ),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('posts')
                                    .doc(postId)
                                    .collection('comments')
                                    .snapshots(),
                                builder: (context, commentSnapshot) {
                                  final commentCount = commentSnapshot.data?.docs.length ?? 0;
                                  return Text('$commentCount comments');
                                },
                              ),
                              const SizedBox(width: 12),
                              AnimatedBuilder(
                                animation: Listenable.merge([]),
                                builder: (_, __) => IconButton(
                                  icon: AnimatedScale(
                                    scale: 1,
                                    duration: const Duration(milliseconds: 200),
                                    child: const Icon(Icons.share),
                                  ),
                                  onPressed: () {
                                    Share.share(
                                        "$caption\n\nShared via CHOMI App 🔥");
                                  },
                                ),
                              ),
                              const Spacer(),
                              Text('$views views',
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
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













