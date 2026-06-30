import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class ChatbotService {
  static final ChatbotService _instance = ChatbotService._();
  factory ChatbotService() => _instance;
  ChatbotService._();

  final List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> get history => _history;
  void clear() => _history.clear();

  bool _isUrdu(String t) => RegExp(r'[\u0600-\u06FF]').hasMatch(t);

  Future<Map<String, dynamic>> ask(String msg) async {
    final t = msg.trim();
    _history.add({'role': 'user', 'message': t});

    final urdu = _isUrdu(t);
    final lower = t.toLowerCase();
    String reply;

    // ===== GREETINGS =====
    if (RegExp(r'^(hi|hello|hey|helo)$', caseSensitive: false).hasMatch(lower)) {
      reply = urdu ? 'السلام علیکم! 👋\nمیں آپ کی کیا مدد کر سکتا ہوں؟ Type "help" for menu.' : 'Hello! 👋\nHow can I help you? Type "help" for menu.';
    }
    else if (RegExp(r'(salam|assalam|assalamualaikum|assalam o alaikum|aoa|adaab)', caseSensitive: false).hasMatch(lower)) {
      reply = urdu ? 'وعلیکم السلام! 👋\nمیں آپ کی کیا مدد کر سکتا ہوں؟ Type "help" for menu.' : 'Walaikum Assalam! 👋\nHow can I help you? Type "help" for menu.';
    }
    // ===== HELP MENU =====
    else if (lower == 'help' || lower == 'مدد' || lower.contains('menu')) {
      reply = _helpMenu(urdu);
    }
    // ===== NUMBERED OPTIONS (1-6) =====
    else if (RegExp(r'^[1-6]$').hasMatch(lower) || RegExp(r'^(1|2|3|4|5|6)[.)\s]').hasMatch(lower)) {
      final num = lower[0];
      reply = _guideByNumber(num, urdu);
    }
    // ===== DONATE / BLOOD DONATION =====
    else if (_matchAny(lower, ['donate','donor','blood donation','donation','عطیہ','خون دینا','khoon dena','1'])) {
      reply = _donateGuide(urdu);
    }
    // ===== FIND DONORS =====
    else if (_matchAny(lower, ['find donor','search donor','donors','need donor','ڈونر تلاش','2'])) {
      reply = _findDonorsGuide(urdu);
    }
    // ===== REGISTER / VERIFICATION =====
    else if (_matchAny(lower, ['register','signup','sign up','registration','verify','verification','رجسٹر','تصدیق','3'])) {
      reply = _registerVerifyGuide(urdu);
    }
    // ===== EMERGENCY =====
    else if (_matchAny(lower, ['emergency','urgent','emergency request','ایمرجنسی','فوری','4'])) {
      reply = await _emergencyGuide(urdu);
    }
    // ===== CONTACT ADMIN =====
    else if (_matchAny(lower, ['contact admin','admin','admin contact','talk admin','ایڈمن','admin se','5'])) {
      reply = await _contactAdminGuide(urdu);
    }
    // ===== ELIGIBILITY =====
    else if (_matchAny(lower, ['eligible','eligibility','can i donate','requirements','weight','age','hb','اہل','شرائط','6'])) {
      reply = _eligibilityGuide(urdu);
    }
    // ===== BLOOD GROUP =====
    else if (lower.contains('blood group') || lower.contains('group') || lower.contains('گروپ')) {
      reply = _bloodGroupInfo(urdu);
    }
    // ===== THANKS =====
    else if (_matchAny(lower, ['thanks','thank','thx','shukriya','شکریہ'])) {
      reply = urdu ? 'خوش آمدید! ❤️\nآپ کا خون زندگیاں بچا سکتا ہے۔' : "You're welcome! ❤️\nYour blood can save lives.";
    }
    // ===== BYE =====
    else if (_matchAny(lower, ['bye','goodbye','allah hafiz','خدا حافظ','khuda hafiz'])) {
      reply = urdu ? 'اللہ حافظ! 👋\nجب بھی مدد چاہیے بات کر سکتے ہیں۔' : 'Allah Hafiz! 👋\nChat anytime you need help.';
    }
    // ===== UNKNOWN =====
    else {
      reply = urdu
        ? 'معذرت! 😕\nمیں سمجھ نہیں پایا۔\n\nبراہ کرم "help" لکھیں — میں آپ کو مینو دکھاؤں گا۔'
        : 'Sorry! 😕\nI couldn\'t understand that.\n\nPlease type "help" — I will show you the menu.';
    }

    _history.add({'role': 'bot', 'message': reply});
    return {'message': reply, 'lang': urdu ? 'ur' : 'en'};
  }

  bool _matchAny(String text, List<String> words) {
    return words.any((w) => text.contains(w.toLowerCase()));
  }

  // ======================== HELP MENU ========================
  String _helpMenu(bool urdu) {
    return urdu
      ? '📋 مدد مینو:\n\n'
        '1️⃣  خون کا عطیہ\n'
        '2️⃣  ڈونر تلاش کریں\n'
        '3️⃣  رجسٹریشن اور تصدیق\n'
        '4️⃣  ایمرجنسی درخواست\n'
        '5️⃣  ایڈمن سے رابطہ\n'
        '6️⃣  اہلیت کی شرائط\n\n'
        '👉 براہ کرم 1 سے 6 میں سے کوئی نمبر لکھیں۔'
      : '📋 HELP MENU:\n\n'
        '1️⃣  Blood Donation\n'
        '2️⃣  Find Donors\n'
        '3️⃣  Register & Verification\n'
        '4️⃣  Emergency Request\n'
        '5️⃣  Contact Admin\n'
        '6️⃣  Eligibility Criteria\n\n'
        '👉 Please type a number from 1 to 6.';
  }

  // ======================== GUIDES BY NUMBER ========================
  String _guideByNumber(String num, bool urdu) {
    switch (num) {
      case '1': return _donateGuide(urdu);
      case '2': return _findDonorsGuide(urdu);
      case '3': return _registerVerifyGuide(urdu);
      case '4': return _emergencyGuideSync(urdu);
      case '5': return _contactAdminGuideSync(urdu);
      case '6': return _eligibilityGuide(urdu);
      default: return _helpMenu(urdu);
    }
  }

  // ---- 1: BLOOD DONATION ----
  String _donateGuide(bool urdu) {
    return urdu
      ? '🩸 خون کا عطیہ — مرحلہ وار گائیڈ:\n\n'
        '1️⃣  سب سے پہلے Sign Up کریں\n'
        '2️⃣  As a DONOR register karein\n'
        '3️⃣  Apni profile complete karein\n'
        '4️⃣  Login karein apni ID se\n'
        '5️⃣  Admin apki profile review karega\n'
        '6️⃣  Admin approve karega → phir ap donate kar sakte hain\n'
        '7️⃣  Features > Blood Request mein ja kar donate karein\n'
        '8️⃣  Har donation ke baad 90 din wait karna hoga\n\n'
        '❓ Mazeed help chahiye? Number 6 likhein eligibility ke liye.'
      : '🩸 BLOOD DONATION — Step by Step Guide:\n\n'
        '1️⃣  First, Sign Up on the app\n'
        '2️⃣  Register as a DONOR\n'
        '3️⃣  Complete your profile (name, email, blood group, etc.)\n'
        '4️⃣  Login with your ID\n'
        '5️⃣  Admin will review your profile\n'
        '6️⃣  Once admin approves → you can donate blood\n'
        '7️⃣  Go to Features > Blood Request to donate\n'
        '8️⃣  After donation, wait 90 days before next donation\n\n'
        '❓ Need more info? Type 6 for eligibility requirements.';
  }

  // ---- 2: FIND DONORS ----
  String _findDonorsGuide(bool urdu) {
    return urdu
      ? '🔍 ڈونر تلاش کریں — مرحلہ وار گائیڈ:\n\n'
        '1️⃣  Pehle Sign Up karein\n'
        '2️⃣  As a RECIPIENT register karein\n'
        '3️⃣  Apni ID banayein — profile complete karein\n'
        '4️⃣  Login karein\n'
        '5️⃣  Dashboard > Verification Status par jayein\n'
        '6️⃣  Apni report verify karwayein (CNIC + Blood Test Report upload)\n'
        '7️⃣  Phir Search Donors mein jayein\n'
        '8️⃣  Kisi bhi donor par Request button dabayein\n'
        '9️⃣  Reason aur phone number fill karein\n'
        '🔟  Admin approve karega → phir donor ka contact number dekh sakte hain\n\n'
        '❓ Koi masla? Type "help" for menu.'
      : '🔍 FIND DONORS — Step by Step Guide:\n\n'
        '1️⃣  First, Sign Up on the app\n'
        '2️⃣  Register as a RECIPIENT\n'
        '3️⃣  Create your ID — complete your profile\n'
        '4️⃣  Login to the app\n'
        '5️⃣  Go to Dashboard > Verification Status\n'
        '6️⃣  Get your report verified (Upload CNIC + Blood Test Report)\n'
        '7️⃣  Then go to Search Donors\n'
        '8️⃣  Tap the REQUEST button on any donor\n'
        '9️⃣  Fill reason and your phone number\n'
        '🔟  Admin approves → then you can see donor contact details\n\n'
        '❓ Any issue? Type "help" for menu.';
  }

  // ---- 3: REGISTER & VERIFICATION ----
  String _registerVerifyGuide(bool urdu) {
    return urdu
      ? '📝 رجسٹریشن اور تصدیق — گائیڈ:\n\n'
        '👤 AS A DONOR:\n'
        '1️⃣  Register karein as a Donor\n'
        '2️⃣  Profile complete karein\n'
        '3️⃣  Admin verify karega\n'
        '4️⃣  Phir ap blood donate kar sakte hain\n\n'
        '🏥 AS A RECIPIENT:\n'
        '1️⃣  Register karein as a Recipient\n'
        '2️⃣  Profile complete karein\n'
        '3️⃣  Documents upload karein (CNIC, Blood Test Report)\n'
        '4️⃣  Verification ke baad blood request kar sakte hain\n'
        '5️⃣  Patient ke liye blood get karein\n\n'
        '🚀 Dono roles ke liye:\n'
        '• Login zaroori hai\n'
        '• Verification ke bina koi feature use nahi kar sakte\n\n'
        '❓ Type "help" for menu.'
      : '📝 REGISTER & VERIFICATION — Guide:\n\n'
        '👤 AS A DONOR:\n'
        '1️⃣  Register as a Donor\n'
        '2️⃣  Complete your profile\n'
        '3️⃣  Admin verifies your profile\n'
        '4️⃣  Then you can donate blood\n\n'
        '🏥 AS A RECIPIENT:\n'
        '1️⃣  Register as a Recipient\n'
        '2️⃣  Complete your profile\n'
        '3️⃣  Upload documents (CNIC, Blood Test Report)\n'
        '4️⃣  After verification, you can request blood\n'
        '5️⃣  Get blood for your patient\n\n'
        '🚀 For both roles:\n'
        '• Login is required\n'
        '• No features work without verification\n\n'
        '❓ Type "help" for menu.';
  }

  // ---- 4: EMERGENCY REQUEST ----
  String _emergencyGuideSync(bool urdu) {
    return urdu
      ? '🚨 ایمرجنسی درخواست:\n\n'
        'Admin se raabta karne ke liye:\n'
        '📞 Helpline number check karne ke liye\n'
        '5️⃣ type karein — Contact Admin\n'
        'Wahan admin ka naam aur number show hoga.\n\n'
        '👉 Type "5" for admin contact details.\n'
        '👉 Ya Emergency Request screen se direct request create karein.'
      : '🚨 EMERGENCY REQUEST:\n\n'
        'To contact admin directly:\n'
        '📞 Type 5 — Contact Admin\n'
        'Admin name and number will be shown there.\n\n'
        '👉 Type "5" for admin contact details.\n'
        '👉 Or create emergency request from Emergency Request screen.';
  }

  Future<String> _emergencyGuide(bool urdu) async {
    final admin = await _fetchAdminContact();
    if (admin != null) {
      return urdu
        ? '🚨 ایمرجنسی — ایڈمن سے رابطہ:\n\n'
          '👤 ${admin['name']}\n'
          '📞 ${admin['phone']}\n\n'
          '👉 Fori call karein!\n'
          '👉 Ya Emergency Request screen se request banayein.'
        : '🚨 EMERGENCY — Contact Admin:\n\n'
          '👤 ${admin['name']}\n'
          '📞 ${admin['phone']}\n\n'
          '👉 Call immediately!\n'
          '👉 Or create request from Emergency Request screen.';
    }
    return _emergencyGuideSync(urdu);
  }

  // ---- 5: CONTACT ADMIN ----
  String _contactAdminGuideSync(bool urdu) {
    return urdu
      ? '📞 ایڈمن سے رابطہ:\n\n'
        'Admin ka contact lene ke liye type karein "admin contact"\n'
        'Ya app mein Support section se admin se raabta karein.'
      : '📞 CONTACT ADMIN:\n\n'
        'Type "admin contact" to get admin details.\n'
        'Or use Support section in the app to reach admin.';
  }

  Future<String> _contactAdminGuide(bool urdu) async {
    final admin = await _fetchAdminContact();
    if (admin != null) {
      return urdu
        ? '📞 ایڈمن سے رابطہ:\n\n'
          '👤 نام: ${admin['name']}\n'
          '📞 فون: ${admin['phone']}\n\n'
          '👉 Abhi call karein ya message karein!\n'
          '👉 Ya Support section se ticket create karein.'
        : '📞 CONTACT ADMIN:\n\n'
          '👤 Name: ${admin['name']}\n'
          '📞 Phone: ${admin['phone']}\n\n'
          '👉 Call or message now!\n'
          '👉 Or create a ticket from Support section.';
    }
    return _contactAdminGuideSync(urdu);
  }

  // ---- 6: ELIGIBILITY ----
  String _eligibilityGuide(bool urdu) {
    return urdu
      ? '✅ عطیہ کی اہلیت — شرائط:\n\n'
        '🎂 عمر: 18 سال یا اس سے زیادہ\n'
        '⚖️ وزن: کم از کم 55 کلوگرام\n'
        '   (مرد اور عورت دونوں کے لیے)\n'
        '🩸 HB Level (خواتین): کم از کم 13 g/dL\n'
        '⏰ وقفہ: ہر عطیہ کے بعد 90 دن\n'
        '💪 صحت: عام طور پر صحت مند ہونا ضروری\n\n'
        '⚠️ اگر آپ بیمار ہیں، خون نہ دیں۔\n'
        '❓ مزید سوال؟ "help" لکھیں۔'
      : '✅ DONATION ELIGIBILITY — Requirements:\n\n'
        '🎂 Age: 18 years or above\n'
        '⚖️ Weight: Minimum 55 kg\n'
        '   (for both Male and Female)\n'
        '🩸 HB Level (Female): Minimum 13 g/dL\n'
        '⏰ Gap: 90 days between donations\n'
        '💪 Health: Generally healthy\n\n'
        '⚠️ If you are sick, do NOT donate.\n'
        '❓ More questions? Type "help".';
  }

  // ---- BLOOD GROUP INFO ----
  String _bloodGroupInfo(bool urdu) {
    return urdu
      ? '🩸 بلڈ گروپ کی معلومات:\n\n'
        '• O- : یونیورسل ڈونر (سب کو دے سکتا)\n'
        '• AB+ : یونیورسل ریسیپینٹ (سب سے لے سکتا)\n'
        '• A+ : A+, AB+ کو دے سکتا\n'
        '• B+ : B+, AB+ کو دے سکتا\n'
        '• O+ : O+, A+, B+, AB+ کو دے سکتا\n\n'
        '❓ اپنا بلڈ گروپ جاننے کے لیے پروفائل دیکھیں۔'
      : '🩸 BLOOD GROUP INFO:\n\n'
        '• O- : Universal Donor\n'
        '• AB+ : Universal Recipient\n'
        '• A+ : Can donate to A+, AB+\n'
        '• B+ : Can donate to B+, AB+\n'
        '• O+ : Can donate to O+, A+, B+, AB+\n\n'
        '❓ Check your profile for your blood group.';
  }

  // ===== FETCH ADMIN CONTACT =====
  Future<Map<String, String>?> _fetchAdminContact() async {
    if (!FirebaseService.initialized) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', whereIn: ['admin', 'super_admin'])
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first.data();
        return {
          'name': d['name']?.toString() ?? 'Admin',
          'phone': d['phone']?.toString() ?? d['contact']?.toString() ?? 'N/A',
          'email': d['email']?.toString() ?? 'N/A',
        };
      }
    } catch (_) {}
    return null;
  }
}
