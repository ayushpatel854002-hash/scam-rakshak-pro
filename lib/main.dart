import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

// यह फंक्शन ऐप बंद होने पर भी बैकग्राउंड में SMS पढ़ेगा
@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage message) async {
  final body = message.body ?? '';
  final sender = message.address ?? 'Unknown';
  if (body.isEmpty) return;

  final result = checkScamMessage(body);
  if (isHighRiskScam(body, result)) {
    await showHighRiskAlert(sender, body);
  }
}

// स्कैम जांचने वाला मुख्य लॉजिक
String checkScamMessage(String msg) {
  final text = msg.toLowerCase();
  int score = 0;

  if (text.contains('http://') ||
      text.contains('https://') ||
      text.contains('bit.ly') ||
      text.contains('.xyz') ||
      text.contains('.apk') ||
      text.contains('.top') ||
      text.contains('.in/')) {
    score += 2;
  }
  if (text.contains('kyc') ||
      text.contains('pan card') ||
      text.contains('account block') ||
      text.contains('suspended') ||
      text.contains('electricity') ||
      text.contains('power cut')) {
    score += 2;
  }
  if (text.contains('lottery') ||
      text.contains('winner') ||
      text.contains('won') ||
      text.contains('reward') ||
      text.contains('cashback') ||
      text.contains('free') ||
      text.contains('click here')) {
    score += 2;
  }
  if (text.contains('otp') ||
      text.contains('pin') ||
      text.contains('upi') ||
      text.contains('paytm') ||
      text.contains('phonepe') ||
      text.contains('gpay')) {
    score += 1;
  }

  if (score >= 3) {
    return '⚠️ हाई रिस्क स्कैम! इस लिंक या नंबर पर भरोसा न करें।';
  } else if (score >= 1) {
    return '⚡ संदिग्ध संदेश! लिंक खोलने से पहले सावधानी बरतें।';
  } else {
    return '✅ यह संदेश सामान्य और सुरक्षित लग रहा है।';
  }
}

bool isHighRiskScam(String msg, String result) {
  final lowerMsg = msg.toLowerCase();
  final lowerRes = result.toLowerCase();

  bool hasRiskyLink = lowerMsg.contains('http://') ||
      lowerMsg.contains('https://') ||
      lowerMsg.contains('bit.ly') ||
      lowerMsg.contains('.xyz') ||
      lowerMsg.contains('.apk') ||
      lowerMsg.contains('.top') ||
      lowerMsg.contains('.in/');

  bool hasPaymentOrKycTrap = lowerMsg.contains('phonepe') ||
      lowerMsg.contains('paytm') ||
      lowerMsg.contains('gpay') ||
      lowerMsg.contains('kyc') ||
      lowerMsg.contains('block') ||
      lowerMsg.contains('lottery') ||
      lowerMsg.contains('won');

  return lowerRes.contains('हाई रिस्क') ||
      lowerRes.contains('संदिग्ध') ||
      hasRiskyLink ||
      hasPaymentOrKycTrap;
}

Future<void> showHighRiskAlert(String sender, String body) async {
  const AndroidInitializationSettings initSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await notificationsPlugin.initialize(
    const InitializationSettings(android: initSettings),
  );

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'scam_alert_channel',
    'Scam SMS Alerts',
    channelDescription: 'High risk scam SMS alerts',
    importance: Importance.max,
    priority: Priority.high,
  );

  await notificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    '🚨 SCAM ALERT: $sender से खतरनाक SMS!',
    body,
    const NotificationDetails(android: androidDetails),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const AndroidInitializationSettings initSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await notificationsPlugin.initialize(
    const InitializationSettings(android: initSettings),
  );
  runApp(const ScamRakshakApp());
}

class ScamRakshakApp extends StatelessWidget {
  const ScamRakshakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Scam Rakshak Pro',
      theme: ThemeData(primarySwatch: Colors.red),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Telephony telephony = Telephony.instance;
  final TextEditingController _msgController = TextEditingController();
  String _statusText = 'बैकग्राउंड SMS सुरक्षा चालू हो रही है...';
  String _manualResult = '';

  @override
  void initState() {
    super.initState();
    _startBackgroundListener();
  }

  Future<void> _startBackgroundListener() async {
    final bool? granted = await telephony.requestPhoneAndSmsPermissions;
    if (granted == true) {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          final body = message.body ?? '';
          final sender = message.address ?? 'Unknown';
          if (body.isEmpty) return;

          final result = checkScamMessage(body);
          if (isHighRiskScam(body, result)) {
            await showHighRiskAlert(sender, body);
          }
        },
        onBackgroundMessage: backgroundSmsHandler,
      );
      setState(() {
        _statusText = '🛡️ बैकग्राउंड SMS स्कैनर सक्रिय (Active) है!';
      });
    } else {
      setState(() {
        _statusText = '⚠️ कृपया ऐप को SMS की अनुमति (Permission) दें।';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scam Rakshak Pro'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green),
              ),
              child: Text(
                _statusText,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'कोई भी संदिग्ध मैसेज पेस्ट करके तुरंत जांचें:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _msgController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'यहाँ SMS या लिंक पेस्ट करें...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _manualResult = checkScamMessage(_msgController.text);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('मैसेज स्कैन करें',
                  style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            if (_manualResult.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange),
                ),
                child: Text(
                  _manualResult,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
