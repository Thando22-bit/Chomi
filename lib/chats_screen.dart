// ✅ Full ChatsScreen.dart — Voice Notes, Edit, Delete-for-me, Delete-for-all

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:just_audio/just_audio.dart';

class ChatsScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatsScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  final recorder = FlutterSoundRecorder();
  final uuid = const Uuid();

  String? recordedFilePath;
  bool isRecording = false;
  String? editingMessageId;

  bool isBlocked = false;
  bool isOtherBlocked = false;

  final player = AudioPlayer(); // ✅ Single audio player
  String? currentlyPlayingId;

  String _chatId() {
    final ids = [userId, widget.otherUserId]..sort();
    return ids.join('_');
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    final tempDir = await getTemporaryDirectory();
    recordedFilePath = '${tempDir.path}/${uuid.v4()}.aac';

    await recorder.openRecorder();
    await recorder.startRecorder(toFile: recordedFilePath);
    setState(() => isRecording = true);
  }

  Future<void> _stopRecordingAndSend() async {
    final filePath = await recorder.stopRecorder();
    await recorder.closeRecorder();
    setState(() => isRecording = false);

    if (filePath != null) {
      final ref = FirebaseStorage.instance.ref().child('voice_notes/${path.basename(filePath)}');
      await ref.putFile(File(filePath));
      final url = await ref.getDownloadURL();

      await _sendMessage(audioUrl: url);
    }
  }

  Future<void> _sendMessage({String? text, String? imageUrl, String? audioUrl}) async {
    if (isBlocked || isOtherBlocked) return;
    if ((text == null || text.isEmpty) && imageUrl == null && audioUrl == null) return;

    final messageData = {
      'senderId': userId,
      'receiverId': widget.otherUserId,
      'timestamp': Timestamp.now(),
      'seen': false,
      'deletedFor': [],
      if (text != null) 'text': text,
      if (imageUrl != null) 'image': imageUrl,
      if (audioUrl != null) 'audio': audioUrl,
    };

    if (editingMessageId != null) {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId())
          .collection('messages')
          .doc(editingMessageId)
          .update({'text': text});
      editingMessageId = null;
    } else {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId())
          .collection('messages')
          .add(messageData);
    }

    messageController.clear();
    setState(() {});
  }

  Future<void> _pickAndSendImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images/${DateTime.now().millisecondsSinceEpoch}_${path.basename(picked.path)}');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await _sendMessage(imageUrl: url);
    }
  }

  Future<void> _markSeen(DocumentSnapshot doc) async {
    if (doc['receiverId'] == userId && doc['seen'] == false) {
      await doc.reference.update({'seen': true});
    }
  }

  Widget _buildAudioMessage(Map<String, dynamic> data, String messageId, bool isMe) {
    final isPlaying = currentlyPlayingId == messageId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.orange.withOpacity(0.2) : Colors.grey[850],
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
            onPressed: () async {
              if (isPlaying) {
                await player.pause();
                setState(() => currentlyPlayingId = null);
              } else {
                await player.stop(); // stop any previous
                await player.setUrl(data['audio']);
                await player.play();
                setState(() => currentlyPlayingId = messageId);

                player.playerStateStream.listen((state) {
                  if (state.processingState == ProcessingState.completed) {
                    setState(() => currentlyPlayingId = null);
                  }
                });
              }
            },
          ),
          const SizedBox(width: 6),
          const Icon(Icons.mic, size: 18, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            "Voice note",
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(width: 6),
          Icon(
            data['seen'] ? Icons.done_all : Icons.done,
            size: 18,
            color: data['seen'] ? Colors.orange : Colors.white54,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> data, String messageId, bool isMe) {
    // Hide if deleted for me
    if (data['deletedFor'] != null && (data['deletedFor'] as List).contains(userId)) {
      return const SizedBox.shrink();
    }

    // Deleted for everyone
    if (data['deletedForAll'] == true) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          "This message was deleted",
          style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
        ),
      );
    }

    // Text
    if (data['text'] != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.orange.withOpacity(0.2) : Colors.grey[850],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(data['text'], style: const TextStyle(color: Colors.white)),
      );
    }

    // Image
    if (data['image'] != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(data['image'], height: 150, fit: BoxFit.cover),
      );
    }

    // Audio
    if (data['audio'] != null) {
      return _buildAudioMessage(data, messageId, isMe);
    }

    return const SizedBox.shrink();
  }

  Widget _buildMessage(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isMe = data['senderId'] == userId;
    _markSeen(doc);

    return GestureDetector(
      onLongPress: isMe
          ? () {
              showModalBottomSheet(
                context: context,
                builder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data['text'] != null)
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Edit'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            messageController.text = data['text'] ?? '';
                            editingMessageId = doc.id;
                          });
                        },
                      ),
                    ListTile(
                      leading: const Icon(Icons.delete),
                      title: const Text('Delete for me'),
                      onTap: () async {
                        Navigator.pop(context);
                        await doc.reference.update({
                          'deletedFor': FieldValue.arrayUnion([userId])
                        });
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_forever),
                      title: const Text('Delete for everyone'),
                      onTap: () async {
                        Navigator.pop(context);
                        await doc.reference.update({
                          'text': null,
                          'image': null,
                          'audio': null,
                          'deletedForAll': true,
                        });
                      },
                    ),
                  ],
                ),
              );
            }
          : null,
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMessageContent(data, doc.id, isMe),
                  Text(
                    DateFormat('hh:mm a').format(data['timestamp'].toDate()),
                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUserName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId())
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (scrollController.hasClients) {
                    scrollController.jumpTo(scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: scrollController,
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _buildMessage(messages[i]),
                );
              },
            ),
          ),
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                if (isRecording)
                  Expanded(
                    child: Text("🔴 Recording...", style: TextStyle(color: Colors.redAccent)),
                  )
                else
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(isRecording ? Icons.stop : Icons.mic, color: Colors.orange),
                  onPressed: isRecording ? _stopRecordingAndSend : _startRecording,
                ),
                if (!isRecording)
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.orange),
                    onPressed: () => _sendMessage(text: messageController.text.trim()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

