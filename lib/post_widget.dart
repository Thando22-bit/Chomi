import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'video_player_widget.dart';
import 'comment_page.dart';
import 'full_screen_image_viewer.dart';
import 'user_info_screen.dart';

class PostWidget extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String postId;

  const PostWidget({
    Key? key,
    required this.postData,
    required this.postId,
  }) : super(key: key);

  @override
  State<PostWidget> createState() => _PostWidgetState();
}

class _PostWidgetState extends State<PostWidget> with AutomaticKeepAliveClientMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  bool isLiked = false;
  int commentCount = 0;
  bool showFollowButton = false;
  String profileImageUrl = '';
  String username = '';
  DateTime? viewStartTime;
  DateTime? viewEndTime;
  int viewDuration = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkLikeStatus();
    _loadCommentCount();
    _loadUserInfo();
    _checkIfFollowing();
    viewStartTime = DateTime.now();
  }

  void _checkLikeStatus() {
    final likes = widget.postData['likes'] ?? [];
    setState(() {
      isLiked = likes.contains(currentUser?.uid);
    });
  }

  void _loadCommentCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .get();

    int total = 0;
    for (var comment in snapshot.docs) {
      total += 1;
      final replies = await comment.reference.collection('replies').get();
      total += replies.docs.length;
    }
    setState(() {
      commentCount = total;
    });
  }

  void _loadUserInfo() async {
    final uid = widget.postData['uid'];
    final snapshot = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (snapshot.exists) {
      final userData = snapshot.data()!;
      setState(() {
        username = userData['username'] ?? 'User';
        profileImageUrl = userData['profileImage'] ?? '';
      });
    }
  }

  void _checkIfFollowing() async {
    if (currentUser == null) return;
    final followingSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();

    final followingList = List<String>.from(followingSnapshot.data()?['following'] ?? []);
    final postUserId = widget.postData['uid'];

    if (postUserId != currentUser!.uid && !followingList.contains(postUserId)) {
      setState(() {
        showFollowButton = true;
      });
    }
  }

  void _followUser() {
    final postUserId = widget.postData['uid'];

    Future.microtask(() async {
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'following': FieldValue.arrayUnion([postUserId])
      });

      final userSnap = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      final userData = userSnap.data()!;
      final fromUsername = userData['username'];
      final profileImage = userData['profileImage'] ?? '';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(postUserId)
          .collection('notifications')
          .add({
        'type': 'follow',
        'message': '$fromUsername started following you',
        'fromUserId': currentUser!.uid,
        'fromUsername': fromUsername,
        'fromProfileImage': profileImage,
        'timestamp': FieldValue.serverTimestamp(),
        'isNew': true,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(postUserId)
          .update({'unreadNotifications': FieldValue.increment(1)});

      await _checkAndVerifyUser(postUserId);

      if (mounted) {
        setState(() {
          showFollowButton = false;
        });
      }
    });
  }

  Future<void> _checkAndVerifyUser(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = userDoc.data();

    if (data != null) {
      final followers = List<String>.from(data['followers'] ?? []);
      final isAlreadyVerified = data['verified'] == true;

      if (followers.length >= 100000 && !isAlreadyVerified) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'verified': true,
        });
        debugPrint('$userId just got verified automatically 🎉');
      }
    }
  }

  void _toggleLike() async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    final userId = currentUser?.uid;
    final likes = List<String>.from(widget.postData['likes'] ?? []);
    final postOwnerId = widget.postData['uid'];

    if (isLiked) {
      likes.remove(userId);
    } else {
      likes.add(userId!);

      if (postOwnerId != currentUser!.uid) {
        final userSnap = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final userData = userSnap.data()!;
        final fromUsername = userData['username'];
        final profileImage = userData['profileImage'] ?? '';

        await FirebaseFirestore.instance
            .collection('users')
            .doc(postOwnerId)
            .collection('notifications')
            .add({
          'type': 'like',
          'message': '$fromUsername liked your post',
          'fromUserId': userId,
          'fromUsername': fromUsername,
          'fromProfileImage': profileImage,
          'postId': widget.postId,
          'timestamp': FieldValue.serverTimestamp(),
          'isNew': true,
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(postOwnerId)
            .update({'unreadNotifications': FieldValue.increment(1)});
      }
    }

    await postRef.update({'likes': likes});
    setState(() {
      isLiked = !isLiked;
    });
  }

  void _deletePost() async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('posts').doc(widget.postId).delete();
    }
  }

  void _updatePostCaption() async {
    final TextEditingController controller = TextEditingController(text: widget.postData['caption']);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Caption'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new caption'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .update({'caption': controller.text});
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _trackViewDuration() {
    viewEndTime = DateTime.now();
    if (viewStartTime != null && viewEndTime != null) {
      final duration = viewEndTime!.difference(viewStartTime!);
      setState(() {
        viewDuration = duration.inSeconds;
      });

      FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({
        'viewDuration': FieldValue.increment(viewDuration),
      });
    }
  }

  void openFullScreenGallery(int startIndex, List imageUrls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: startIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String caption = widget.postData['caption'] ?? '';
    final List imageUrls = widget.postData['imageUrls'] ?? [];
    final String videoUrl = widget.postData['videoUrl'] ?? '';
    final Timestamp timestamp = widget.postData['timestamp'] ?? Timestamp.now();
    final String uid = widget.postData['uid'] ?? '';
    final likes = widget.postData['likes'] ?? [];

    return GestureDetector(
      onTap: _trackViewDuration,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? theme.cardColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black12, blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => UserInfoScreen(userId: uid)),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: profileImageUrl.isNotEmpty
                        ? NetworkImage(profileImageUrl)
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            username,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          if (widget.postData['verified'] == true)
                            const Icon(Icons.verified, color: Color(0xFFFFD700), size: 18),
                        ],
                      ),
                      Text(
                        DateFormat.yMMMd().add_jm().format(timestamp.toDate()),
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (showFollowButton)
                  ElevatedButton(
                    onPressed: _followUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: const Text('+', style: TextStyle(color: Colors.white)),
                  ),
                if (uid == currentUser?.uid)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') _deletePost();
                      if (value == 'update') _updatePostCaption();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'update', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(caption, style: theme.textTheme.bodyLarge),
              ),
            if (imageUrls.isNotEmpty)
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: imageUrls.length,
                        onPageChanged: (index) => setState(() => _currentImageIndex = index),
                        itemBuilder: (context, index) {
                          final imageUrl = imageUrls[index];
                          return GestureDetector(
                            onTap: () => openFullScreenGallery(index, imageUrls),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              fadeInDuration: const Duration(milliseconds: 100),
                              placeholder: (context, url) =>
                                  const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (imageUrls.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SmoothPageIndicator(
                        controller: _pageController,
                        count: imageUrls.length,
                        effect: const WormEffect(
                          dotHeight: 6,
                          dotWidth: 6,
                          spacing: 6,
                          activeDotColor: Colors.orange,
                          dotColor: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            if (videoUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    color: Colors.black,
                    child: VideoPlayerWidget(videoUrl: videoUrl),
                  ),
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : theme.iconTheme.color,
                  ),
                  onPressed: _toggleLike,
                ),
                Text('${likes.length}', style: theme.textTheme.bodyMedium),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  color: theme.iconTheme.color,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommentPage(postId: widget.postId),
                      ),
                    );
                  },
                ),
                Text('$commentCount', style: theme.textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



