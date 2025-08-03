import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chats_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  String searchQuery = "";
  int unreadChats = 0;

  // Function to get the unread chats count
  Future<void> _getUnreadChatsCount() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    setState(() {
      unreadChats = userDoc.data()?['unreadChats'] ?? 0;
    });
  }

  // Function to reset unreadChats count when chat screen is opened
  Future<void> _resetUnreadChatsCount() async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'unreadChats': 0,
    });
    _getUnreadChatsCount(); // Fetch updated unread count
  }

  Future<void> _toggleBlockUser(String otherUserId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final doc = await userRef.get();
    final blocked = List<String>.from(doc.data()?['blockedUsers'] ?? []);

    if (blocked.contains(otherUserId)) {
      await userRef.update({
        'blockedUsers': FieldValue.arrayRemove([otherUserId])
      });
    } else {
      await userRef.update({
        'blockedUsers': FieldValue.arrayUnion([otherUserId])
      });
    }
    setState(() {});
  }

  Future<void> _deleteChat(String otherUserId) async {
    final chatId = [userId, otherUserId]..sort();
    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId.join('_'))
        .collection('messages');

    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await messagesRef.get();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> _chatUsersStream() async* {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    while (true) {
      final List<Map<String, dynamic>> chatUsers = [];

      for (var doc in snapshot.docs) {
        if (doc.id != userId) {
          final chatId = [userId, doc.id]..sort();
          final chatDoc = await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatId.join('_'))
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          if (chatDoc.docs.isNotEmpty) {
            final lastMessage = chatDoc.docs.first.data();

            final typingSnapshot = await FirebaseFirestore.instance
                .collection('typing')
                .doc(chatId.join('_'))
                .get();

            final isTyping = typingSnapshot.exists && typingSnapshot.data()![doc.id] == true;

            final onlineSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .doc(doc.id)
                .get();

            final isOnline = onlineSnapshot.data()?['isOnline'] ?? false;

            final currentUserDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();

            final blocked = List<String>.from(currentUserDoc.data()?['blockedUsers'] ?? []);
            //if (blocked.contains(doc.id)) continue;

            chatUsers.add({
              'userId': doc.id,
              'name': doc['username'],
              'profileImage': doc['profileImage'],
              'lastMessage': isTyping ? 'typing...' : (lastMessage['text'] ?? 'Media'),
              'timestamp': lastMessage['timestamp'],
              'seen': lastMessage['seen'],
              'senderId': lastMessage['senderId'],
              'isOnline': isOnline,
              'isTyping': isTyping,
            });
          }
        }
      }

      yield chatUsers;
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  @override
  void initState() {
    super.initState();
    _getUnreadChatsCount();
    _resetUnreadChatsCount();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isDark ? Colors.black : Colors.orange,
        centerTitle: true,
        title: const Text(
          "Chats",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatUsersStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!
              .where((user) => user['name']
                  .toString()
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()))
              .toList();

          if (users.isEmpty) {
            return const Center(child: Text("No chats yet"));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isMe = user['senderId'] == userId;

              return ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(user['profileImage']),
                      radius: 25,
                    ),
                    if (user['isOnline'])
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  user['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                  subtitle: Text(
                                user['lastMessage'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: user['isTyping']
                                      ? Colors.orange
                                      : isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                  fontStyle: user['isTyping'] ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),

                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (user['timestamp'] as Timestamp)
                          .toDate()
                          .toLocal()
                          .toString()
                          .substring(11, 16),
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (!user['seen'] && !isMe)
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          "1",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  // Reset unreadChats when chat is opened
                  _resetUnreadChatsCount();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatsScreen(
                        otherUserId: user['userId'],
                        otherUserName: user['name'],
                      ),
                    ),
                  );
                },
                    onLongPress: () async {
                    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
                    final doc = await userRef.get();
                    final blocked = List<String>.from(doc.data()?['blockedUsers'] ?? []);
                    final isBlocked = blocked.contains(user['userId']);

                    showModalBottomSheet(
                      context: context,
                      builder: (_) => Wrap(
                        children: [
                          ListTile(
                            leading: Icon(isBlocked ? Icons.lock_open : Icons.block),
                            title: Text(isBlocked ? "Unblock " : "Block "),
                            onTap: () {
                              _toggleBlockUser(user['userId']);
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete),
                            title: const Text("Delete Chat"),
                            onTap: () {
                              _deleteChat(user['userId']);
                              Navigator.pop(context);
                            },
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





