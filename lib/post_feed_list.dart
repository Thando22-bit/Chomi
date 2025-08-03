import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_widget.dart';

class PostFeedList extends StatefulWidget {
  final Widget header;
  final List<String> blockedUserIds;

  const PostFeedList({
    super.key,
    required this.header,
    required this.blockedUserIds,
  });

  @override
  State<PostFeedList> createState() => _PostFeedListState();
}

class _PostFeedListState extends State<PostFeedList> {
  final currentUser = FirebaseAuth.instance.currentUser;
  List<String> blockedUserIds = [];

  @override
  void initState() {
    super.initState();
    fetchBlockedUsers();
  }

  Future<void> fetchBlockedUsers() async {
    if (currentUser == null) return;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    final data = userDoc.data();
    setState(() {
      blockedUserIds = List<String>.from(data?['blockedUsers'] ?? []);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Something went wrong: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              widget.header,
              const SizedBox(height: 20),
              const Center(child: Text("No posts available")),
            ],
          );
        }

        final posts = snapshot.data!.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              return data;
            })
            .where((postData) {
              final postOwnerId = postData['uid'];
              return !blockedUserIds.contains(postOwnerId);
            })
            .toList();

        posts.sort((a, b) {
          final aScore =
              (a['viewDuration'] ?? 0) + _timestampWeight(a['timestamp']);
          final bScore =
              (b['viewDuration'] ?? 0) + _timestampWeight(b['timestamp']);
          return bScore.compareTo(aScore);
        });

        return ListView.builder(
          key: const PageStorageKey('postList'),
          padding: const EdgeInsets.only(top: 10, bottom: 80),
          itemCount: posts.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: widget.header,
              );
            }

            final postData = posts[index - 1];
            final postId = postData['id'];

            return KeyedSubtree(
              key: ValueKey(postId),
              child: PostWidget(
                postData: postData,
                postId: postId,
              ),
            );
          },
        );
      },
    );
  }

  int _timestampWeight(dynamic timestamp) {
    try {
      final ts = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final ageInHours = now.difference(ts).inHours;
      return ageInHours < 48 ? (48 - ageInHours) : 0;
    } catch (_) {
      return 0;
    }
  }
}

