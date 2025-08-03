import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_post_screen.dart';
import 'earnings_screen.dart';
import 'settings_screen.dart';
import 'user_info_screen.dart';
import 'search_history_screen.dart';
import 'post_feed_list.dart';
import 'withdrawal_history_screen.dart';
import 'admin_panel_screen.dart';
import 'chat_list_screen.dart';
import 'streaming_screen.dart';
import 'chomi_hustle_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _postController = TextEditingController();
  final String adminUID = '1qvSXPuGGqZ3fvGbbMadqk9v6IV2';
  int _selectedIndex = 0;
  int _unreadNotifications = 0;
  int _unreadChats = 0;

  @override
  void initState() {
    super.initState();
    _listenForNotificationCount();
    _listenForChatCount();
  }

  void _listenForNotificationCount() {
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          setState(() {
            _unreadNotifications = data['unreadNotifications'] ?? 0;
          });
        }
      });
    }
  }

  void _listenForChatCount() {
    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final value = data['unreadChats'] ?? 0;
          setState(() {
            _unreadChats = value;
          });
        }
      });
    }
  }

  void _reloadHome() => setState(() {});

  void _navigateToUserInfo(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserInfoScreen(userId: userId)),
    );
  }

  void _navigateToCreatePost() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostPage()),
    );
  }

  Widget _buildPostInputBox(User? currentUser) {
    if (currentUser == null) return const SizedBox();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final image = userData?['profileImage'];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _navigateToUserInfo(currentUser.uid),
                child: CircleAvatar(
                  radius: 22,
                  backgroundImage: (image != null && image is String && image.isNotEmpty)
                      ? NetworkImage(image)
                      : const AssetImage('assets/avatar.png') as ImageProvider,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TextField(
                    controller: _postController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(
                      hintText: "What's your thought?",
                      hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.camera_alt, color: isDark ? Colors.white : Colors.black),
                onPressed: _navigateToCreatePost,
              ),
              IconButton(
                icon: Icon(Icons.send, color: isDark ? Colors.white : Colors.black),
                onPressed: () async {
                  final text = _postController.text.trim();
                  if (text.isEmpty || currentUser == null) return;

                  final userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUser.uid)
                      .get();
                  final isVerified = userDoc.data()?['verified'] ?? false;

                  await FirebaseFirestore.instance.collection('posts').add({
                    'uid': currentUser.uid,
                    'caption': text,
                    'timestamp': Timestamp.now(),
                    'likes': [],
                    'likesCount': 0,
                    'imageUrls': [],
                    'verified': isVerified,
                  });

                  _postController.clear();
                  FocusScope.of(context).unfocus();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return PostFeedList(
          header: _buildPostInputBox(user),
          blockedUserIds: const [],
        );
      case 1:
        return const StreamingScreen();
      case 2:
        return const ChatListScreen();
      case 3:
        return const ChomiHustleScreen();
      case 4:
        return const NotificationsScreen();
      default:
        return const Center(child: Text("Coming Soon"));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in")),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      appBar: _selectedIndex == 3
              ? null
            
            :AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isDark ? Colors.grey[900] : Colors.orange,
        title: GestureDetector(
          onTap: _reloadHome,
          child: const Text(
            "CHOMI",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchHistoryScreen()));
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            onSelected: (value) {
              if (value == 'earnings') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()));
              } else if (value == 'withdrawals') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const WithdrawalHistoryScreen()));
              } else if (value == 'settings') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              } else if (value == 'admin') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'earnings', child: Text('Your Earnings')),
              const PopupMenuItem(value: 'withdrawals', child: Text('Withdrawal History')),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              if (user!.uid == adminUID)
                const PopupMenuItem(value: 'admin', child: Text('Admin Panel')),
            ],
          )
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: isDark ? Colors.grey : Colors.black,
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        type: BottomNavigationBarType.fixed,
        onTap: (index) async {
          if (index == 2 && user != null) {
            await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
              'unreadChats': 0,
            });
            setState(() {
              _selectedIndex = index;
              _unreadChats = 0;
            });
          } else if (index == 4 && user != null) {
            await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
              'unreadNotifications': 0,
            });
            setState(() {
              _selectedIndex = index;
              _unreadNotifications = 0;
            });
          } else {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.radio), label: 'Live'),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline),
                if (_unreadChats > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$_unreadChats',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Chats',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.business_center), label: 'Hustle'),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        '$_unreadNotifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Notify',
          ),
        ],
      ),
    );
  }
}



