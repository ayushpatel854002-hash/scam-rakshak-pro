import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const List<String> validActivationKeys = [
  'SRP-PRO-2026',
  'AYUSH-VIP-999',
  'RAKSHAK-GOLD-101',
  'SCAM-SHIELD-777',
];

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  final body = message.body ?? '';
  final sender = message.address ?? 'Unknown';
  if (ScamEngine.isScamMessage(body)) {
    await _showScamNotification(sender, body);
  }
}

Future<void> _showScamNotification(String sender, String body) async {
  const androidDetails = AndroidNotificationDetails(
    'scam_alert_channel',
    'Scam Rakshak Alerts',
    channelDescription: 'High priority alerts for fraud SMS',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );
  const details = NotificationDetails(android: androidDetails);
  await notificationsPlugin.show(
    DateTime.now().millisecond,
    '⚠️ सावधान! संदिग्ध स्कैम SMS ($sender)',
    'इस मैसेज में फर्जी लिंक या फ्रॉड के संकेत मिले हैं। लिंक पर क्लिक न करें!',
    details,
  );
}

class ScamEngine {
  static final List<String> dangerKeywords = [
    'kyc',
    'pan card',
    'account block',
    'account suspend',
    'electricity bill',
    'power disconnect',
    'lottery',
    'prize won',
    'kbc',
    'apk',
    '.apk',
    'bit.ly',
    'tinyurl',
    'ngrok',
    'refund',
    'cashback claim',
    'sbi yono',
    'hdfc update',
    'icici update',
    'customs',
    'parcel held',
    'digital arrest',
    'trai',
    'sim block',
    '24 hours',
    'urgent update',
    'click here',
    'verify now',
  ];

  static bool isScamMessage(String text) {
    final lower = text.toLowerCase();
    int score = 0;

    for (final word in dangerKeywords) {
      if (lower.contains(word)) {
        score += 2;
      }
    }

    if (lower.contains('http://') || lower.contains('https://') || lower.contains('www.')) {
      score += 2;
    }

    if (lower.contains('.apk')) {
      score += 5;
    }

    return score >= 3;
  }

  static String analyzeDetailed(String text) {
    final lower = text.toLowerCase();
    List<String> reasons = [];

    if (lower.contains('.apk')) {
      reasons.add('• खतरनाक .APK ऐप डाउनलोड लिंक मौजूद है (हैक होने का सीधा खतरा)।');
    }
    if (lower.contains('http://') || lower.contains('https://')) {
      reasons.add('• बाहरी वेब लिंक मौजूद है—अनजान लिंक से बैंक डिटेल चोरी हो सकती है।');
    }
    if (lower.contains('kyc') || lower.contains('pan') || lower.contains('block') || lower.contains('suspend')) {
      reasons.add('• बैंक/KYC या सिम बंद होने का डर दिखाकर जल्दबाज़ी कराई जा रही है।');
    }
    if (lower.contains('electricity') || lower.contains('disconnect')) {
      reasons.add('• बिजली कटने का नकली मैसेज (यह एक प्रसिद्ध स्कैम तरीका है)।');
    }
    if (lower.contains('lottery') || lower.contains('prize') || lower.contains('won') || lower.contains('cashback')) {
      reasons.add('• मुफ्त इनाम/लॉटरी का लालच दिया जा रहा है।');
    }

    if (reasons.isEmpty && isScamMessage(text)) {
      reasons.add('• मैसेज की भाषा संदिग्ध फ्रॉड पैटर्न से मेल खाती है।');
    }

    return reasons.join('\n');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await notificationsPlugin.initialize(initSettings);

  runApp(const ScamRakshakApp());
}

class ScamRakshakApp extends StatelessWidget {
  const ScamRakshakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Scam Rakshak Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC62828)),
        useMaterial3: true,
      ),
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
  final TextEditingController _smsController = TextEditingController();

  bool _isBackgroundActive = false;
  bool _isProUnlocked = false;
  String _statusMessage = 'परमिशन की जांच हो रही है...';
  String? _scanResultTitle;
  String? _scanResultDetails;
  bool _isDangerResult = false;
  final List<String> _recentAlerts = [];

  @override
  void initState() {
    super.initState();
    _initSmsProtection();
  }

  Future<void> _initSmsProtection() async {
    try {
      final bool? granted = await telephony.requestPhoneAndSmsPermissions;
      if (granted != null && granted) {
        telephony.listenIncomingSms(
          onNewMessage: (SmsMessage message) {
            final body = message.body ?? '';
            final sender = message.address ?? 'Unknown';
            if (ScamEngine.isScamMessage(body)) {
              _showScamNotification(sender, body);
              setState(() {
                _recentAlerts.insert(0, '[$sender]: $body');
              });
            }
          },
          onBackgroundMessage: backgroundMessageHandler,
          listenInBackground: true,
        );
        setState(() {
          _isBackgroundActive = true;
          _statusMessage = 'बैकग्राउंड SMS स्कैनर सक्रिय (Active) है!';
        });
      } else {
        setState(() {
          _isBackgroundActive = false;
          _statusMessage = 'SMS परमिशन बंद है — नीचे टैप करके चालू करें';
        });
      }
    } catch (e) {
      setState(() {
        _isBackgroundActive = false;
        _statusMessage = 'बैकग्राउंड स्कैनर चालू करने के लिए टैप करें';
      });
    }
  }

  void _manualScan() {
    final text = _smsController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया पहले कोई SMS या लिंक पेस्ट करें।')),
      );
      return;
    }

    final isScam = ScamEngine.isScamMessage(text);
    setState(() {
      _isDangerResult = isScam;
      if (isScam) {
        _scanResultTitle = '🚨 खतरा! यह एक स्कैम / फ्रॉड मैसेज हो सकता है';
        _scanResultDetails = ScamEngine.analyzeDetailed(text);
      } else {
        _scanResultTitle = '✅ सुरक्षित: इसमें कोई स्पष्ट स्कैम लिंक नहीं मिला';
        _scanResultDetails = 'फिर भी किसी को अपना OTP या बैंक पिन कभी न बताएं।';
      }
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          isProUnlocked: _isProUnlocked,
          isBackgroundActive: _isBackgroundActive,
          onProStatusChanged: (unlocked) {
            setState(() {
              _isProUnlocked = unlocked;
            });
          },
          onRetryPermission: _initSmsProtection,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFC62828),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Text('Scam Rakshak Pro', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_isProUnlocked) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings & Pro Activation',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _initSmsProtection,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isBackgroundActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isBackgroundActive ? Colors.green : Colors.orange,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isBackgroundActive ? Icons.verified_user : Icons.warning_amber_rounded,
                      color: _isBackgroundActive ? Colors.green[800] : Colors.orange[800],
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _isBackgroundActive ? Colors.green[900] : Colors.orange[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'कोई भी संदिग्ध मैसेज पेस्ट करके तुरंत जांचें:',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _smsController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'यहाँ SMS या लिंक पेस्ट करें...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _manualScan,
              icon: const Icon(Icons.security),
              label: const Text('मैसेज स्कैन करें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
            if (_scanResultTitle != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isDangerResult ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isDangerResult ? Colors.red : Colors.green, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _scanResultTitle!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _isDangerResult ? Colors.red[900] : Colors.green[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_scanResultDetails ?? '', style: const TextStyle(fontSize: 13.5, height: 1.4)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_recentAlerts.isNotEmpty) ...[
              const Text(
                'बैकग्राउंड में पकड़े गए संदिग्ध SMS:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red),
              ),
              const SizedBox(height: 8),
              ..._recentAlerts.map(
                (alert) => Card(
                  color: const Color(0xFFFFEBEE),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(alert, style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final bool isProUnlocked;
  final bool isBackgroundActive;
  final ValueChanged<bool> onProStatusChanged;
  final VoidCallback onRetryPermission;

  const SettingsScreen({
    super.key,
    required this.isProUnlocked,
    required this.isBackgroundActive,
    required this.onProStatusChanged,
    required this.onRetryPermission,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _keyController = TextEditingController();
  late bool _unlocked;

  @override
  void initState() {
    super.initState();
    _unlocked = widget.isProUnlocked;
  }

  void _verifyKey() {
    final entered = _keyController.text.trim().toUpperCase();
    if (validActivationKeys.contains(entered)) {
      setState(() {
        _unlocked = true;
      });
      widget.onProStatusChanged(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('🎉 बधाई हो! Scam Rakshak Pro अनलॉक हो गया है!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('❌ गलत Activation Key! कृपया सही Pro Key डालें।'),
        ),
      );
    }
  }

  void _showPaymentInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pro Activation Key कैसे प्राप्त करें?'),
        content: const Text(
          '1. Pro प्लान शुल्क: ₹99 (लाइफटाइम वैलिडिटी)\n'
          '2. पेमेंट करने के बाद स्क्रीनशॉट भेजें।\n'
          '3. आपको तुरंत आपकी व्यक्तिगत ऑफ़लाइन Activation Key मिल जाएगी, जिसे यहाँ डालकर आप सभी प्रो फीचर्स अनलॉक कर सकते हैं।',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ठीक है'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFC62828),
        foregroundColor: Colors.white,
        title: const Text('Settings & Security'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _unlocked ? Icons.workspace_premium : Icons.lock_outline,
                        color: _unlocked ? Colors.amber[800] : const Color(0xFFC62828),
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _unlocked ? 'Pro Membership सक्रिय है' : 'Pro Version अनलॉक करें',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _unlocked
                        ? 'आपका ऐप पूरी तरह अनलॉक है। सभी ऑफ़लाइन सुरक्षा फीचर्स सक्रिय हैं।'
                        : 'प्रीमियम सुरक्षा और फुल प्रोटेक्शन अनलॉक करने के लिए अपनी Activation Key डालें:',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13.5),
                  ),
                  if (!_unlocked) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _keyController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Activation Key डालें (उदा. SRP-PRO-2026)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.vpn_key),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _verifyKey,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Key सत्यापित करें', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _showPaymentInfo,
                          icon: const Icon(Icons.currency_rupee, size: 18),
                          label: const Text('Key खरीदें'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, color: Colors.green, size: 26),
                      SizedBox(width: 10),
                      Text(
                        '100% ऑफ़लाइन और हैक-प्रूफ़ सुरक्षा',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '• जीरो डेटा लीक: आपके SMS या बैंक मैसेज किसी बाहरी सर्वर या इंटरनेट पर नहीं भेजे जाते।\n'
                    '• ऑन-डिवाइस स्कैनिंग: सारा विश्लेषण सीधे आपके फ़ोन के प्रोसेसर पर ऑफ़लाइन होता है।\n'
                    '• बैकग्राउंड रीयल-टाइम गार्ड: नया फ्रॉड SMS आते ही तुरंत चेतावनी नोटिफ़िकेशन मिलता है।',
                    style: TextStyle(fontSize: 13.5, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: d
