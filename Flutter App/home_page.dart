// lib/screens/home_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'monitor_weight.dart';
import 'motions_pages.dart';
import 'images_page.dart'; 
import 'videos_page.dart'; 

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  static const routeName = '/home';

  @override
  Widget build(BuildContext context) {
    final accent = Colors.tealAccent.shade200;
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          children: [
            // Top vignette section
            Expanded(
              child: Stack(
                children: [
                  // Background radial gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.5),
                        radius: 1.2,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  // Content
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'PostPal',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 65,
                            shadows: const [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black54,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // 3D Mailbox model
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 450,
                            height: 300,
                            child: ModelViewer(
                              src: 'assets/PostPal.glb',
                              alt: '3D Mailbox',
                              autoRotate: true,
                              cameraControls: true,
                              disableZoom: true,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Making mail simple & secure!',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            shadows: const [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black54,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Footer bar with blur + translucency
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _FooterButton(
                          icon: Icons.mail,
                          label: 'Mail',
                          accent: accent,
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                MonitorWeightScreen.routeName,
                              ),
                        ),
                        _FooterButton(
                          icon: Icons.motion_photos_on,
                          label: 'Motions',
                          accent: accent,
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                MotionsPage.routeName,
                              ),
                        ),
                        _FooterButton(
                          icon: Icons.image,
                          label: 'Images',
                          accent: accent,
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                ImagesPage.routeName, // ← new route
                              ),
                        ),
                        _FooterButton(
                          icon: Icons.videocam,
                          label: 'Videos',
                          accent: accent,
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                VideosPage.routeName,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _FooterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: accent),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}
