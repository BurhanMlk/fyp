/**
 * AI Service Layer — Handles LLM integration, intent detection,
 * language processing, and intelligent responses.
 */
const OpenAI = require('openai');
const { LANG_DETECT } = require('../utils/languageDetector');

class AIService {
  constructor() {
    this.openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
    this.systemPrompt = this._buildSystemPrompt();
  }

  _buildSystemPrompt() {
    return `You are BloodBridge AI — an expert assistant for blood donation management.

YOUR CAPABILITIES:
1. Guide donors through registration, verification, and donation process
2. Help recipients request blood and find matching donors
3. Assist admins with approvals, verifications, and inventory management
4. Detect suspicious documents and activities
5. Track blood inventory across banks
6. Handle emergency blood requests
7. Send donation reminders (90-day cycle)

RULES:
- Reply in the SAME language as the user (English or Urdu)
- Be polite, professional, and empathetic
- NEVER give medical advice — always refer to doctors
- For verification issues, tell user to contact admin
- Keep responses concise and actionable
- Use step-by-step guidance

BLOOD BRIDGE APP KNOWLEDGE:
- Registration: Sign Up → fill name,email,phone,blood group,password → select role → submit
- Donor Verification: Admin verifies donor documents (CNIC front/back, blood test report)
- Donation: Go to Features → Blood Request → accept request → donate → wait 90 days
- Recipient Request: Search Donors → tap Request → fill reason & phone → admin approves → view donor contacts
- Blood Groups: O- universal donor, AB+ universal recipient
- Emergency: Create emergency request → system finds nearest blood → admin notified
- Eligibility: Donors must wait 3 months between donations
- Organizations: 4 types can register — University, University Society, NGO, and Blood Bank/Hospital. They register via the Organization Registration screen (select type, fill details, create admin account). The application becomes PENDING and the Super Admin approves/rejects it. The Super Admin can also Suspend, Activate, or Delete organizations from Organization Management (delete icon on each row with confirmation).
- NGO/Society Admin dashboard Quick Actions after approval: Add Member (by email), Campaign (create a blood donation campaign with title/date/target units), Create Event (donation event with date + time), and Reports (members, active donors, blood group distribution, campaigns & events count).

USER-SPECIFIC GUIDANCE:
- Use userRole (donor/recipient/admin) to personalize responses
- Use conversation context (lastIntent, currentStep) to continue flows
- Always check if user has pending verifications or requests`;
  }

  async chat(message, context = {}) {
    const { userRole, userId, userName, language, history = [] } = context;
    const detectedLang = language || LANG_DETECT(message);

    const messages = [
      { role: 'system', content: this.systemPrompt },
      { role: 'system', content: `Current user: ${userName || 'Guest'} (${userRole || 'user'}). Reply in ${detectedLang === 'ur' ? 'Urdu' : 'English'}.` },
      ...history.slice(-10).map(m => ({ role: m.role, content: m.content })),
      { role: 'user', content: message },
    ];

    try {
      const response = await this.openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages,
        temperature: 0.7,
        max_tokens: 500,
      });
      return {
        reply: response.choices[0].message.content,
        language: detectedLang,
        intent: await this._classifyIntent(message),
        confidence: 0.9,
      };
    } catch (err) {
      return this._fallbackResponse(message, detectedLang);
    }
  }

  async _classifyIntent(message) {
    const intents = {
      'donate_blood': /donate|donor|give blood|عطیہ|خون دینا/i,
      'request_blood': /need blood|request|recipient|چاہیے|مریض|ضرورت/i,
      'register': /register|signup|create account|رجسٹر|سائن اپ/i,
      'verify': /verify|document|approve|upload|تصدیق|دستاویز/i,
      'organization': /organization|ngo|society|university|blood bank|تنظیم|این جی او|سوسائٹی|یونیورسٹی/i,
      'org_management': /delete organization|remove organization|suspend|reject|حذف|منظور|معلق/i,
      'campaign_event': /campaign|event|report|quick action|مہم|تقریب|رپورٹ/i,
      'blood_banks': /hospital|blood bank|banks|ہسپتال|بلڈ بینک/i,
      'emergency': /emergency|urgent|critical|ایمرجنسی|فوری/i,
      'eligibility': /eligible|when|wait|months|اہل|کب|انتظار/i,
      'blood_groups': /blood group|compatible|گروپ|مطابقت/i,
      'contact_admin': /talk.*admin|support|help me|ticket|ایڈمن|مدد/i,
      'donation_history': /history|previous|record|تاریخ|پچھلا/i,
      'profile': /my profile|account|settings|پروفائل|سیٹنگ/i,
      'help': /help|guide|how|کیسے|مدد/i,
    };
    for (const [intent, regex] of Object.entries(intents)) {
      if (regex.test(message)) return intent;
    }
    return 'general_chat';
  }

  _fallbackResponse(msg, lang) {
    const en = "I understand you're asking about: \"" + msg.substring(0, 50) + "\". Let me help you. Type 'help' to see what I can do.";
    const ur = "میں سمجھ گیا آپ پوچھ رہے ہیں: \"" + msg.substring(0, 50) + "\"। 'مدد' لکھیں میں بتاتا ہوں کیا کر سکتا ہوں۔";
    return { reply: lang === 'ur' ? ur : en, language: lang, intent: 'fallback', confidence: 0.3 };
  }

  /** Detect fake/suspicious documents */
  async analyzeDocument(fileUrl, metadata = {}) {
    const flags = [];
    if (metadata.size && metadata.size < 5000) flags.push('file_too_small');
    if (metadata.name && /copy|fake|edited|photoshop/i.test(metadata.name)) flags.push('suspicious_name');
    if (metadata.uploadCount > 3) flags.push('multiple_rapid_uploads');
    const isSuspicious = flags.length > 0;
    return {
      isSuspicious,
      flags,
      recommendation: isSuspicious ? 'manual_review' : 'auto_approve',
      confidence: isSuspicious ? 0.6 + flags.length * 0.1 : 0.95,
    };
  }
}

module.exports = new AIService();
