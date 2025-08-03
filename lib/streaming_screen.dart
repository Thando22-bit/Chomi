
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'live_viewer_screen.dart';
import 'goLive_screen.dart';

class StreamingScreen extends StatelessWidget {
  const StreamingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('liveStreams')
                .where('isEnded', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final streams = snapshot.data!.docs;
              if (streams.isEmpty) {
                return const Center(child: Text("No one is live right now"));
              }
              return PageView.builder(
                scrollDirection: Axis.vertical,
                itemCount: streams.length,
                itemBuilder: (context, index) {
                  final data = streams[index].data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LiveViewerScreen(
                          streamerId: data['userId'],
                          streamerName: data['username'] ?? 'CHOMI',
                          streamId: streams[index].id,
                        ),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        image: data['thumbnailUrl'] != null
                            ? DecorationImage(
                                image: NetworkImage(data['thumbnailUrl']),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: Colors.black,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_circle_fill,
                                size: 70, color: Colors.white),
                            const SizedBox(height: 10),
                            Text(
                              data['topic'] ?? 'Live Stream',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '@${data['username']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          Positioned(
            top: 50,
            right: 20,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
             onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GoLiveScreen()),
              ),
              icon: const Icon(Icons.videocam, color: Colors.white),
              label: const Text("Go Live", style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }
}



