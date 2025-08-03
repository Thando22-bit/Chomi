import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'chats_screen.dart';
import 'full_screen_image_viewer.dart';

class ChomiHustleScreen extends StatefulWidget {
  const ChomiHustleScreen({super.key});

  @override
  State<ChomiHustleScreen> createState() => _ChomiHustleScreenState();
}

class _ChomiHustleScreenState extends State<ChomiHustleScreen> {
  String searchQuery = "";

  void _startChat(BuildContext context, String receiverId, String receiverName) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId == receiverId) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatsScreen(
          otherUserId: receiverId,
          otherUserName: receiverName,
        ),
      ),
    );
  }

  void _deletePost(BuildContext context, String postId) async {
    await FirebaseFirestore.instance.collection('hustlePosts').doc(postId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post deleted')),
    );
  }

  void _openSearchDialog() {
    final controller = TextEditingController(text: searchQuery);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Search Posts", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Enter keyword...",
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.orange),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.orange, width: 2),
              ),
            ),
            onSubmitted: (value) {
              setState(() {
                searchQuery = value.trim();
              });
              Navigator.pop(ctx);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  searchQuery = "";
                });
                Navigator.pop(ctx);
              },
              child: const Text("Clear", style: TextStyle(color: Colors.orange)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () {
                setState(() {
                  searchQuery = controller.text.trim();
                });
                Navigator.pop(ctx);
              },
              child: const Text("Search"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHustleOption(
                icon: Icons.work,
                label: 'Job Post',
                onTap: () => Navigator.pushNamed(context, '/jobPost'),
              ),
              _buildHustleOption(
                icon: Icons.business,
                label: 'Advertise',
                onTap: () => Navigator.pushNamed(context, '/businessAdvertise'),
              ),
              _buildHustleOption(
                icon: Icons.school,
                label: 'Brief CV',
                onTap: () => Navigator.pushNamed(context, '/briefCV'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Latest Hustle Posts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: _openSearchDialog,
                  icon: const Icon(Icons.search, color: Colors.orange),
                )
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('hustlePosts')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;

                //  Apply search filter
                if (searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final textData = [
                      data['objective'] ?? "",
                      data['education'] ?? "",
                      data['experience'] ?? "",
                      data['skills'] ?? "",
                      data['description'] ?? "",
                    ].join(" ").toLowerCase();
                    return textData.contains(searchQuery.toLowerCase());
                  }).toList();
                }

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No posts found 🔎',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final post = docs[index];
                    final data = post.data() as Map<String, dynamic>;
                    final postId = post.id;
                    final type = data['type'];
                    final userId = data['userId'];
                    final userName = data['userName'] ?? 'User';
                    final time = (data['createdAt'] as Timestamp?)?.toDate();
                    final images = List<String>.from(data['images'] ?? []);
                    final timeAgo = time != null
                        ? DateFormat('MMM d, h:mm a').format(time)
                        : '';

                    return _buildPostCard(
                      context,
                      data,
                      postId,
                      type,
                      userId,
                      userName,
                      timeAgo,
                      images,
                      currentUserId,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, Map<String, dynamic> data, String postId,
      String type, String userId, String userName, String timeAgo, List<String> images, String? currentUserId) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type == 'job'
                  ? '💼 Job Opportunity'
                  : type == 'advertise'
                      ? '📢 Business Ad'
                      : '📄 CV',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            if (type == 'job' || type == 'advertise')
              Text(data['description'] ?? '',
                  style: const TextStyle(color: Colors.white)),
            if (type == 'cv') ...[
              _cvSection('🎯 Objective', data['objective']),
              _cvSection('📚 Education', data['education']),
              _cvSection('💼 Experience', data['experience']),
              _cvSection('🛠 Skills', data['skills']),
              const SizedBox(height: 12),
              Card(
                color: Colors.black,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.orange, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.contact_phone, color: Colors.orange, size: 18),
                          SizedBox(width: 6),
                          Text("Contact Details",
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _cvText('📱 Phone', data['phone']),
                      _cvText('📧 Email', data['email']),
                      _cvText('📍 Location', data['location']),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            if (images.isNotEmpty)
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  itemBuilder: (context, i) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullScreenImageViewer(
                              imageUrls: images,
                              initialIndex: i,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            images[i],
                            height: 180,
                            width: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, e, st) =>
                                const Icon(Icons.image, color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(timeAgo,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _startChat(context, userId, userName),
                      icon: const Icon(Icons.message),
                      label: const Text("Message"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                    ),
                    if (currentUserId == userId) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePost(context, postId),
                      )
                    ]
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHustleOption(
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.orange,
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _cvSection(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey[850]!, Colors.grey[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cvText(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text("$label: $value",
          style: const TextStyle(color: Colors.white, fontSize: 14)),
    );
  }
}

