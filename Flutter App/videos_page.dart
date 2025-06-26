import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});
  static const routeName = '/videos';

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  final _storage = FirebaseStorage.instance;
  late Future<List<Reference>> _videosFuture;

  @override
  void initState() {
    super.initState();
    _videosFuture = _loadVideos();
  }

  Future<List<Reference>> _loadVideos() async {
    final listResult = await _storage.ref('videos').listAll();
    return listResult.items.reversed.toList(); // newest first
  }

  @override
  Widget build(BuildContext context) {
    final accent = Colors.tealAccent.shade200;
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text('Mailbox Videos'),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // same vignette background
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.3,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                stops: const [0.4, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: FutureBuilder<List<Reference>>(
              future: _videosFuture,
              builder: (c, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error loading videos',
                      style: TextStyle(color: Colors.red.shade300),
                    ),
                  );
                }
                final videos = snap.data!;
                if (videos.isEmpty) {
                  return Center(
                    child: Text(
                      'No videos yet',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    itemCount: videos.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                    itemBuilder: (ctx, i) {
                      final ref = videos[i];
                      return GestureDetector(
                        onTap: () async {
                          final url = await ref.getDownloadURL();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => _FullScreenVideoPage(videoUrl: url),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // blurred background placeholder
                              BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  color: Colors.black.withOpacity(0.2),
                                ),
                              ),
                              // big Play icon centered
                              const Center(
                                child: Icon(
                                  Icons.play_circle_outline,
                                  size: 48,
                                  color: Colors.white70,
                                ),
                              ),
                              // optional: video filename overlay at bottom
                              Positioned(
                                bottom: 6,
                                left: 6,
                                right: 6,
                                child: FutureBuilder<FullMetadata>(
                                  future: ref.getMetadata(),
                                  builder: (c2, mSnap) {
                                    final name = ref.name;
                                    return Container(
                                      padding: const EdgeInsets.all(4),
                                      color: Colors.black54,
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 10,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenVideoPage extends StatefulWidget {
  final String videoUrl;
  const _FullScreenVideoPage({required this.videoUrl});

  @override
  State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: true,
          looping: false,
        );
        setState(() {});
      });
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child:
            _chewieController != null
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
