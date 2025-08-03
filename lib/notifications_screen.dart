import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'comment_page.dart';
import 'user_info_screen.dart';
import 'live_viewer_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _markNotificationsAsRead();
  }

  Future<void> _markNotificationsAsRead() async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
    await userRef.update({'unreadNotifications': 0});
  }

  Future<void> _deleteNotification(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  void _handleNotificationTap(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'];

    // Mark as read if it's still new
    if ((data['isNew'] ?? true) == true) {
      await doc.reference.update({'isNew': false});
    }

    if (type == 'like' || type == 'comment' || type == 'tag') {
      final postId = data['postId'];
      Navigator.push(context, MaterialPageRoute(builder: (_) => CommentPage(postId: postId)));
    } else if (type == 'follow' || type == 'unfollow') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => UserInfoScreen(userId: data['fromUserId'])));
    } else if (type == 'live') {
      final streamId = data['streamId'];
      final isLive = data['isEnded'] == false;

      if (isLive) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveViewerScreen(
              streamId: streamId,
              streamerId: data['fromUserId'],
              streamerName: data['fromUsername'],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This live stream has ended.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final allNotifications = snapshot.data!.docs;
          return ListView.builder(
            itemCount: allNotifications.length,
            itemBuilder: (context, index) {
              return _buildNotificationTile(allNotifications[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'];
    final fromUsername = data['fromUsername'] ?? 'Someone';
    final message = data['message'] ?? '';
    final profileImage = data['fromProfileImage'];
    final timestamp = data['timestamp'] as Timestamp?;
    final timeAgo = timestamp != null
        ? DateFormat.yMMMd().add_jm().format(timestamp.toDate())
        : '';
    final isNew = data['isNew'] ?? true;

    IconData icon;
    Color color;

    switch (type) {
      case 'like':
        icon = Icons.favorite;
        color = Colors.red;
        break;
      case 'comment':
      case 'tag':
        icon = Icons.comment;
        color = Colors.green;
        break;
      case 'follow':
        icon = Icons.person_add;
        color = Colors.orange;
        break;
      case 'unfollow':
        icon = Icons.person_off;
        color = Colors.redAccent;
        break;
      case 'live':
        icon = Icons.wifi;
        color = Colors.purple;
        break;
      case 'withdrawal':
        icon = Icons.account_balance_wallet;
        color = Colors.teal;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return GestureDetector(
      onTap: () => _handleNotificationTap(doc),
      onLongPress: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Notification'),
            content: const Text('Do you want to delete this notification?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                  onPressed: () {
                    _deleteNotification(doc.id);
                    Navigator.pop(context);
                  },
                  child: const Text('Delete')),
            ],
          ),
        );
      },
      child: Container(
        color: isNew ? Colors.orange.withOpacity(0.05) : Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: (profileImage != null && profileImage.isNotEmpty)
                ? NetworkImage(profileImage)
                : const AssetImage('assets/avatar.png') as ImageProvider,
          ),
          title: Text(
            fromUsername,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 2),
              Text(timeAgo, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          trailing: type == 'like'
              ? TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 1.0, end: 1.2),
                  curve: Curves.easeInOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: const Icon(Icons.favorite, color: Colors.red, size: 22),
                    );
                  },
                  onEnd: () {
                    setState(() {}); // repeat
                  },
                )
              : Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}


