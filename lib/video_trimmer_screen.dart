import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';

class VideoTrimmerScreen extends StatefulWidget {
  final File file;

  const VideoTrimmerScreen({super.key, required this.file});

  @override
  State<VideoTrimmerScreen> createState() => _VideoTrimmerScreenState();
}

class _VideoTrimmerScreenState extends State<VideoTrimmerScreen> {
  final Trimmer _trimmer = Trimmer();
  double _startValue = 0.0;
  double _endValue = 0.0;
  bool _isPlaying = false;
  bool _progressVisibility = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  void _loadVideo() async {
    await _trimmer.loadVideo(videoFile: widget.file);
    setState(() {});
  }

  void _saveTrimmedVideo() async {
    setState(() => _progressVisibility = true);
    await _trimmer.saveTrimmedVideo(
      startValue: _startValue,
      endValue: _endValue,
      onSave: (outputPath) {
        setState(() => _progressVisibility = false);
        Navigator.pop(context, outputPath);
      },
    );
  }

  void _togglePlayback() async {
    await _trimmer.videoPlaybackControl(
      startValue: _startValue,
      endValue: _endValue,
    );
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text("Trim Video", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          children: [
            if (_progressVisibility) const LinearProgressIndicator(),
            Expanded(child: VideoViewer(trimmer: _trimmer)),
            TrimViewer(
              trimmer: _trimmer,
              viewerHeight: 60.0,
              viewerWidth: MediaQuery.of(context).size.width,
              maxVideoLength: const Duration(seconds: 30),
              onChangeStart: (value) => setState(() => _startValue = value),
              onChangeEnd: (value) => setState(() => _endValue = value),
              onChangePlaybackState: (isPlaying) => setState(() => _isPlaying = isPlaying),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _togglePlayback,
                  color: Colors.orange,
                  iconSize: 30,
                ),
                TextButton(
                  onPressed: _saveTrimmedVideo,
                  child: const Text("SAVE", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}




