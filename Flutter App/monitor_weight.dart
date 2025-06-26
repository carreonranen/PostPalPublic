// lib/screens/monitor_weight.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'motions_pages.dart';

class MonitorWeightScreen extends StatefulWidget {
  const MonitorWeightScreen({super.key});
  static const routeName = '/monitor_weight';

  @override
  State<MonitorWeightScreen> createState() => _MonitorWeightScreenState();
}

class _MonitorWeightScreenState extends State<MonitorWeightScreen>
    with SingleTickerProviderStateMixin {
  late final DatabaseReference _weightRef;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'mailbox_alerts',
    'Mailbox Alerts',
    description: 'Notifications for PostPal weight alerts',
    importance: Importance.high,
  );
  static const double _weightThreshold = 600.0;
  bool _hasNotified = false;
  double _currentWeight = 0.0;
  int _updatedAt = 0;
  final List<double> _history = [];

  @override
  void initState() {
    super.initState();
    _weightRef = FirebaseDatabase.instance.ref('mailbox/status/weight');
    _initNotifications();
    _weightRef.onValue.listen(_onWeightChange);
  }

  void _onWeightChange(DatabaseEvent event) {
    final w = (event.snapshot.value as num?)?.toDouble() ?? 0.0;
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    setState(() {
      _currentWeight = w;
      _updatedAt = ts;
      _history.add(w);
      if (_history.length > 20) _history.removeAt(0);
    });
    if (w >= _weightThreshold && !_hasNotified) {
      _hasNotified = true;
      HapticFeedback.lightImpact();
      _localNotif.show(
        0,
        '📬 Mail Detected!',
        'Your mailbox now has ${w.toStringAsFixed(0)} g of mail.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  Future<void> _initNotifications() async {
    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotif.initialize(
      const InitializationSettings(android: androidInit),
    );
    final fm = FirebaseMessaging.instance;
    await fm.requestPermission(alert: true, badge: true, sound: true);
    await fm.subscribeToTopic('mailboxAlerts');
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      final a = msg.notification?.android;
      if (n != null && a != null) {
        _localNotif.show(
          n.hashCode,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              icon: a.smallIcon,
            ),
          ),
        );
      }
    });
  }

  String _formatTimestamp(int seconds) {
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
    return DateFormat.yMd().add_jm().format(dt);
  }

  String get _weightStatus {
    if (_currentWeight < 100) {
      return 'Mailbox is still relatively empty';
    } else if (_currentWeight < 300) {
      return 'Mailbox has some mail';
    } else if (_currentWeight < 500) {
      return 'Mailbox has mail in it';
    } else {
      return 'Mailbox is most likely full and should be emptied';
    }
  }

  void _refreshWeight() {
    _weightRef.once();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Colors.tealAccent.shade200;
    final progress = (_currentWeight / _weightThreshold).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white),
        title: const Text('Mailbox Weight'),
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
            // Centered content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: const Duration(seconds: 1),
                            builder:
                                (_, pct, __) => CircularPercentIndicator(
                                  radius: 80,
                                  lineWidth: 8,
                                  animation: false,
                                  percent: pct,
                                  backgroundColor: Colors.grey.shade800,
                                  progressColor:
                                      pct < 0.5
                                          ? Colors.green
                                          : pct < 0.8
                                          ? Colors.amber
                                          : Colors.red,
                                  center: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.mail, size: 36, color: accent),
                                      Text(
                                        '${(pct * 100).round()}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '${_currentWeight.toStringAsFixed(2)} g',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _weightStatus,
                              key: ValueKey(_weightStatus),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_history.isNotEmpty) ...[
                            SizedBox(
                              height: 60,
                              child: LineChart(
                                LineChartData(
                                  gridData: FlGridData(show: false),
                                  titlesData: FlTitlesData(show: false),
                                  borderData: FlBorderData(show: false),
                                  lineTouchData: LineTouchData(enabled: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots:
                                          _history
                                              .asMap()
                                              .entries
                                              .map(
                                                (e) => FlSpot(
                                                  e.key.toDouble(),
                                                  e.value,
                                                ),
                                              )
                                              .toList(),
                                      isCurved: true,
                                      dotData: FlDotData(show: false),
                                      color: accent,
                                      barWidth: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(
                            'Updated: ${_formatTimestamp(_updatedAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                shape: const StadiumBorder(),
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              icon: const Icon(Icons.motion_photos_on),
                              label: const Text('View Motion Events'),
                              onPressed:
                                  () => Navigator.pushNamed(
                                    context,
                                    MotionsPage.routeName,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accent,
        foregroundColor: Colors.black,
        onPressed: _refreshWeight,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

class MonitorMotionScreen extends StatefulWidget {
  const MonitorMotionScreen({super.key});
  static const routeName = '/monitor_motion';

  @override
  State<MonitorMotionScreen> createState() => _MonitorMotionScreenState();
}

class _MonitorMotionScreenState extends State<MonitorMotionScreen> {
  late final DatabaseReference _motionRef;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'motion_alerts',
    'Motion Alerts',
    description: 'Notifications for PostPal motion events',
    importance: Importance.high,
  );

  String _lastMotion = 'Never';
  int _lastNotifTime = 0;
  static const int _cooldown = 60 * 60 * 2;

  @override
  void initState() {
    super.initState();
    _motionRef = FirebaseDatabase.instance.ref('mailbox/status/last_motion');
    _initNotifications();
    _motionRef.onValue.listen((evt) {
      final timestamp = evt.snapshot.value as String? ?? 'Never';
      setState(() => _lastMotion = timestamp);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (timestamp != 'Never' && now - _lastNotifTime > _cooldown) {
        _lastNotifTime = now;
        HapticFeedback.mediumImpact();
        _localNotif.show(
          1,
          '📸 Motion Detected',
          'Your mailbox was accessed at $timestamp',
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  Future<void> _initNotifications() async {
    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotif.initialize(
      const InitializationSettings(android: androidInit),
    );
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
        title: const Text('Last Motion Detected'),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.motion_photos_on, size: 64, color: accent),
                      const SizedBox(height: 24),
                      Text(
                        _lastMotion,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
