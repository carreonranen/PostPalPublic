// lib/screens/motions_pages.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class MotionsPage extends StatefulWidget {
  const MotionsPage({super.key});
  static const routeName = '/motions';

  @override
  State<MotionsPage> createState() => _MotionsPageState();
}

class _MotionsPageState extends State<MotionsPage> {
  late final DatabaseReference _motionsRef;
  final List<int> _timestamps = [];

  @override
  void initState() {
    super.initState();
    _motionsRef = FirebaseDatabase.instance.ref('mailbox/status/motions');
    // Listen for each new motion push
    _motionsRef.onChildAdded.listen((event) {
      final val = event.snapshot.value;
      if (val is int) {
        setState(() {
          _timestamps.insert(0, val);
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
    return DateFormat.yMd().add_jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final accent = Colors.tealAccent.shade200;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white),
        title: const Text('Motion Events'),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Stack(
          children: [
            // Vignette background
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
            // Content card
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child:
                          _timestamps.isEmpty
                              ? Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  'No motion events yet',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                              : ListView.separated(
                                shrinkWrap: true,
                                itemCount: _timestamps.length,
                                separatorBuilder:
                                    (_, __) => Divider(color: Colors.white24),
                                itemBuilder: (_, i) {
                                  final ts = _timestamps[i];
                                  return ListTile(
                                    leading: Icon(
                                      Icons.motion_photos_on,
                                      color: accent,
                                    ),
                                    title: Text(
                                      _formatTime(ts),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Motion detected',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  );
                                },
                              ),
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
