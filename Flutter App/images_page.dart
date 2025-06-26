// lib/screens/images_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImagesPage extends StatefulWidget {
  const ImagesPage({super.key});
  static const routeName = '/images';

  @override
  State<ImagesPage> createState() => _ImagesPageState();
}

class _ImagesPageState extends State<ImagesPage> {
  final _storage = FirebaseStorage.instance;
  late Future<List<Reference>> _imagesFuture;

  @override
  void initState() {
    super.initState();
    _imagesFuture = _loadImages();
  }

  Future<List<Reference>> _loadImages() async {
    final listResult = await _storage.ref('images').listAll();
    return listResult.items.reversed.toList();
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
        title: const Text('Mailbox Images'),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Dark radial vignette
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
              future: _imagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading images',
                      style: TextStyle(color: Colors.red.shade300),
                    ),
                  );
                }
                final images = snapshot.data!;
                if (images.isEmpty) {
                  return Center(
                    child: Text(
                      'No images yet',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    itemCount: images.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                    itemBuilder: (context, i) {
                      final ref = images[i];
                      return GestureDetector(
                        onTap: () async {
                          // fetch the download URL once, then push full-screen
                          final url = await ref.getDownloadURL();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _FullScreenImagePage(url: url),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Frosted glass backdrop
                              BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  color: Colors.black.withOpacity(0.2),
                                ),
                              ),

                              // Thumbnail loader
                              FutureBuilder<String>(
                                future: ref.getDownloadURL(),
                                builder: (c, urlSnap) {
                                  if (urlSnap.connectionState !=
                                      ConnectionState.done) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }
                                  if (urlSnap.hasError) {
                                    return const Center(
                                      child: Icon(
                                        Icons.error,
                                        color: Colors.red,
                                      ),
                                    );
                                  }
                                  return CachedNetworkImage(
                                    imageUrl: urlSnap.data!,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),

                              // timestamp overlay
                              Positioned(
                                bottom: 6,
                                left: 6,
                                right: 6,
                                child: FutureBuilder<FullMetadata>(
                                  future: ref.getMetadata(),
                                  builder: (c, metaSnap) {
                                    String txt = '';
                                    if (metaSnap.connectionState ==
                                            ConnectionState.done &&
                                        !metaSnap.hasError) {
                                      final m = metaSnap.data!;
                                      final ts = m.updated ?? m.timeCreated;
                                      if (ts != null) {
                                        txt =
                                            ts.toLocal().toString().split(
                                              '.',
                                            )[0];
                                      }
                                    }
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                        horizontal: 4,
                                      ),
                                      color: Colors.black54,
                                      child: Text(
                                        txt,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white70,
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

/// A simple full-screen viewer with pinch/drag.
class _FullScreenImagePage extends StatelessWidget {
  final String url;
  const _FullScreenImagePage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 1,
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: url,
            placeholder:
                (_, __) => const CircularProgressIndicator(color: Colors.white),
            errorWidget:
                (_, __, ___) => const Icon(Icons.error, color: Colors.red),
          ),
        ),
      ),
    );
  }
}
