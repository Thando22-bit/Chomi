import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class CommentPage extends StatefulWidget {
  final String postId;
  const CommentPage({super.key, required this.postId});

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  final TextEditingController _commentController = TextEditingController();
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  File? _pickedImage;
  Map<String, bool> expandedReplies = {};
  Map<String, String> replyingTo = {};

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final fileName = path.basename(image.path);
      final ref = FirebaseStorage.instance.ref().child('comment_images/$fileName');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _incrementCommentCount() async {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    await postRef.update({'commentCount': FieldValue.increment(1)});
  }

  Future<void> _postComment({String? parentId}) async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _pickedImage == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    final userData = userDoc.data()!;
    String? imageUrl;

    if (_pickedImage != null) {
      imageUrl = await _uploadImage(_pickedImage!);
    }

    final commentData = {
      'userId': currentUserId,
      'username': userData['username'],
      'profileImageUrl': userData['profileImage'],
      'text': text,
      'image': imageUrl,
      'likes': [],
      'createdAt': Timestamp.now(),
      'isVerified': userData['verified'] ?? false,
    };

    if (parentId == null) {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add(commentData);
      await _incrementCommentCount();
    } else {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(parentId)
          .collection('replies')
          .add(commentData);
    }

    final postDoc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
    final postOwnerId = postDoc['uid'];

    if (postOwnerId != currentUserId) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(postOwnerId)
          .collection('notifications')
          .add({
        'type': 'comment',
        'message': '${userData['username']} commented on your post',
        'fromUserId': currentUserId,
        'fromUsername': userData['username'],
        'fromProfileImage': userData['profileImage'],
        'postId': widget.postId,
        'timestamp': FieldValue.serverTimestamp(),
        'isNew': true,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(postOwnerId)
          .update({'unreadNotifications': FieldValue.increment(1)});
    }

    //  Tagging logic
    final RegExp tagPattern = RegExp(r'@(\w+)');
    final matches = tagPattern.allMatches(text);
    for (var match in matches) {
      final taggedUsername = match.group(1);
      if (taggedUsername != null && taggedUsername != userData['username']) {
        final taggedQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: taggedUsername)
            .limit(1)
            .get();

        if (taggedQuery.docs.isNotEmpty) {
          final taggedUser = taggedQuery.docs.first;
          final taggedUserId = taggedUser.id;

          await FirebaseFirestore.instance
              .collection('users')
              .doc(taggedUserId)
              .collection('notifications')
              .add({
            'type': 'tag',
            'message': '${userData['username']} tagged you in a comment',
            'fromUserId': currentUserId,
            'fromUsername': userData['username'],
            'fromProfileImage': userData['profileImage'],
            'postId': widget.postId,
            'timestamp': FieldValue.serverTimestamp(),
            'isNew': true,
          });

          await FirebaseFirestore.instance
              .collection('users')
              .doc(taggedUserId)
              .update({'unreadNotifications': FieldValue.increment(1)});
        }
      }
    }

    _commentController.clear();
    replyingTo.clear();
    setState(() => _pickedImage = null);
  }

  Future<void> _toggleLike(DocumentReference ref, List likedBy) async {
    final liked = likedBy.contains(currentUserId);
    await ref.update({
      'likes': liked ? FieldValue.arrayRemove([currentUserId]) : FieldValue.arrayUnion([currentUserId])
    });
  }

  Future<void> editComment(DocumentReference ref, String oldText) async {
    final controller = TextEditingController(text: oldText);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await ref.update({'text': result});
    }
  }

  Future<void> _deleteComment(DocumentReference ref) async {
    await ref.delete();
  }

  // FIXED highlight for tags only
  List<TextSpan> _buildCommentTextSpans(String text) {
    final regex = RegExp(r'@[\w]+'); // detect @username
    final spans = <TextSpan>[];
    int start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  Widget _buildComment({
    required String id,
    required Map data,
    required DocumentReference ref,
    required bool isReply,
    String? parentId,
  }) {
    final isOwn = data['userId'] == currentUserId;
    final likedBy = List<String>.from(data['likes'] ?? []);
    final isLiked = likedBy.contains(currentUserId);

    return GestureDetector(
      onLongPress: isOwn
          ? () => showModalBottomSheet(
                context: context,
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text("Edit"),
                        onTap: () {
                          Navigator.pop(context);
                          editComment(ref, data['text']);
                        }),
                    ListTile(
                        leading: const Icon(Icons.delete),
                        title: const Text("Delete"),
                        onTap: () {
                          Navigator.pop(context);
                          _deleteComment(ref);
                        }),
                  ],
                ),
              )
          : null,
      child: Container(
        margin: EdgeInsets.only(left: isReply ? 40 : 10, top: 10, right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              CircleAvatar(radius: 16, backgroundImage: NetworkImage(data['profileImageUrl'] ?? '')),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data['username'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (data['isVerified'] == true)
                const Icon(Icons.verified, color: Color(0xFFFFD700), size: 18),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
              children: _buildCommentTextSpans(data['text'] ?? ''),
            ),
          ),
          if (data['image'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(child: Image.network(data['image'])),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(data['image'], height: 160),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                onTap: () => _toggleLike(ref, likedBy),
                child: Row(
                  children: [
                    Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 16, color: isLiked ? Colors.red : Colors.grey),
                    const SizedBox(width: 4),
                    Text('${likedBy.length}'),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              InkWell(
                onTap: () {
                  setState(() {
                    _commentController.text = '@${data['username']} ';
                    replyingTo['replyTo'] = parentId ?? id;
                  });
                },
                child: const Text("Reply", style: TextStyle(color: Colors.blue)),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildReplies(String parentId) {
    final showAll = expandedReplies[parentId] ?? false;
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(parentId)
          .collection('replies')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final replies = snapshot.data!.docs;
        final visible = showAll ? replies : replies.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (replies.length > 3)
              TextButton(
                onPressed: () => setState(() => expandedReplies[parentId] = !showAll),
                child: Text(showAll ? "Hide replies" : "View replies (${replies.length})"),
              ),
            ...visible.map((doc) => _buildComment(
                  id: doc.id,
                  data: doc.data() as Map,
                  ref: doc.reference,
                  isReply: true,
                  parentId: parentId,
                )),
          ],
        );
      },
    );
  }

  Widget _buildCommentList() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .orderBy('createdAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final comments = snapshot.data!.docs;

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          children: comments.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildComment(id: doc.id, data: data, ref: doc.reference, isReply: false),
                _buildReplies(doc.id),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Comments")),
      body: Column(
        children: [
          Expanded(child: _buildCommentList()),
          if (_pickedImage != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                children: [
                  Image.file(_pickedImage!, height: 100),
                  Positioned(
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _pickedImage = null),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.image), onPressed: _pickImage),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(hintText: "Write a comment..."),
                  ),
                ),
                const SizedBox(width: 5),
                ElevatedButton(
                  onPressed: () => _postComment(parentId: replyingTo['replyTo']),
                  child: const Text("Post"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}




