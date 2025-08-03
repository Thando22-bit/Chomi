import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_info_screen.dart';

class SearchHistoryScreen extends StatefulWidget {
  const SearchHistoryScreen({super.key});

  @override
  State<SearchHistoryScreen> createState() => _SearchHistoryScreenState();
}

class _SearchHistoryScreenState extends State<SearchHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _searchHistory = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _searchController.addListener(() {
      _performSearch(_searchController.text.trim());
    });
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('searchHistory') ?? [];
    });
  }

  Future<void> _saveSearchHistory(String term) async {
    if (term.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _searchHistory.remove(term);
    _searchHistory.insert(0, term);
    await prefs.setStringList('searchHistory', _searchHistory);
    _loadSearchHistory();
  }

  Future<void> _removeSearchItem(String term) async {
    final confirm = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete"),
        content: const Text("Do you want to delete this search?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("OK")),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      _searchHistory.remove(term);
      await prefs.setStringList('searchHistory', _searchHistory);
      _loadSearchHistory();
    }
  }

  Future<void> _performSearch(String keyword) async {
    if (keyword.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Get a limited number of users
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(30)
          .get();

      final matches = snapshot.docs.where((doc) {
        final data = doc.data();
        final username = (data['username'] ?? '').toString().toLowerCase();
        return username.contains(keyword.toLowerCase());
      }).map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();

      setState(() {
        _searchResults = matches;
        _isSearching = false;
      });

      _saveSearchHistory(keyword);
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      debugPrint("Search error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Something went wrong during search")),
      );
    }
  }

  void _navigateToUser(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserInfoScreen(userId: userId)),
    );
  }

  void _showUserOptions(String userId) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                setState(() {
                  _searchResults.removeWhere((user) => user['uid'] == userId);
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildUserTile(Map<String, dynamic> user) {
    return InkWell(
      onTap: () => _navigateToUser(user['uid']),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: user['profileImage'] != null
                      ? NetworkImage(user['profileImage'])
                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['username'] ?? 'User',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user['bio'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showUserOptions(user['uid']),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildHistoryTile(String term) {
    return InkWell(
      onTap: () {
        _searchController.text = term;
        _performSearch(term);
      },
      onLongPress: () => _removeSearchItem(term),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.orange,
              child: Icon(Icons.history, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                term,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.more_vert),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search users...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_searchController.text.isEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Recent",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Expanded(
                      child: _searchHistory.isEmpty
                          ? const Center(child: Text("No recent searches"))
                          : ListView.builder(
                              itemCount: _searchHistory.length,
                              itemBuilder: (context, index) {
                                return buildHistoryTile(_searchHistory[index]);
                              },
                            ),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator())
                    : _searchResults.isEmpty
                        ? const Center(child: Text("No users found"))
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              return buildUserTile(_searchResults[index]);
                            },
                          ),
              ),
          ],
        ),
      ),
    );
  }
}



