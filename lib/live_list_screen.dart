import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LiveListScreen extends StatelessWidget {
  const LiveListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Now 🔴"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('liveStreams')
            .where('isEnded', isEqualTo: false)
            .orderBy('startedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final liveStreams = snapshot.data!.docs;

          if (liveStreams.isEmpty) {
            return const Center(child: Text("No one is live right now 😴"));
          }

          return ListView.builder(
            itemCount: liveStreams.length,
            itemBuilder: (context, index) {
              final stream = liveStreams[index];
              final data = stream.data() as Map<String, dynamic>;
              final streamerId = data['userId'];
              final username = data['username'] ?? 'CHOMI User';
              final topic = data['topic'] ?? 'Live Stream';

              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.videocam, color: Colors.white),
                ),
                title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(topic),
                trailing: const Icon(Icons.play_arrow),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/liveStream',
                    arguments: {
                      'streamerId': streamerId,
                      'streamId': stream.id,
                    },
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


