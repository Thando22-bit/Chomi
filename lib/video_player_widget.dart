import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool loop;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.loop = true,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  static final Map<String, VideoPlayerController> _controllerCache = {};
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _showControls = false;
  bool _wasVisible = false;
  bool _viewCounted = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (_controllerCache.containsKey(widget.videoUrl)) {
      _controller = _controllerCache[widget.videoUrl]!;
    } else {
      _controller = VideoPlayerController.network(widget.videoUrl);
      await _controller.initialize();
      _controller.setLooping(widget.loop);
      _controller.setVolume(1);
      _controllerCache[widget.videoUrl] = _controller;
    }

    _controller.addListener(_handleProgress);
    setState(() => _isInitialized = true);
  }

  void _handleProgress() async {
    if (_viewCounted || !_controller.value.isInitialized) return;

    final position = _controller.value.position;
    final duration = _controller.value.duration;

    if (duration.inSeconds < 5) return; // avoid counting broken videos

    final watchedPercentage = position.inMilliseconds / duration.inMilliseconds;

    if (watchedPercentage >= 0.9) {
      _viewCounted = true;

      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('posts')
            .where('videoUrl', isEqualTo: widget.videoUrl)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final postId = snapshot.docs.first.id;
          final data = snapshot.docs.first.data();
          final views = (data['views'] as List?) ?? [];

          if (!views.contains(userId)) {
            views.add(userId);
            await FirebaseFirestore.instance
                .collection('posts')
                .doc(postId)
                .update({'views': views});

            print("✅ View counted for user: $userId");
          }
        } else {
          print("⚠️ No post found matching videoUrl.");
        }
      } catch (e) {
        print("🔥 Error updating views: $e");
      }
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller.play() : _controller.pause();
    });
  }

  void _seekForward() {
    final newPosition = _controller.value.position + const Duration(seconds: 5);
    _controller.seekTo(newPosition);
  }

  void _seekBackward() {
    final newPosition = _controller.value.position - const Duration(seconds: 5);
    _controller.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
    });
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction > 0.7;

    if (visible && !_wasVisible) {
      _controller.play();
      _isPlaying = true;
      setState(() {});
    } else if (!visible && _wasVisible) {
      _controller.pause();
      _isPlaying = false;
      setState(() {});
    }

    _wasVisible = visible;
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: _handleVisibilityChanged,
      child: _isInitialized
          ? GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                  if (_showControls)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black38,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.replay_5, color: Colors.white),
                                  onPressed: _seekBackward,
                                ),
                                IconButton(
                                  icon: Icon(
                                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  onPressed: _togglePlayPause,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.forward_5, color: Colors.white),
                                  onPressed: _seekForward,
                                ),
                              ],
                            ),
                            VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              colors: VideoProgressColors(
                                playedColor: Colors.orange,
                                backgroundColor: Colors.white38,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_controller.value.position),
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                  Text(
                                    _formatDuration(_controller.value.duration),
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _isMuted ? Icons.volume_off : Icons.volume_up,
                                    color: Colors.white,
                                  ),
                                  onPressed: _toggleMute,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}





