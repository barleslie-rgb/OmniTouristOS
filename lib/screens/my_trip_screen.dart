import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/trip_state_service.dart';
import '../services/passport_service.dart';
import '../services/expense_service.dart';

class MyTripScreen extends StatefulWidget {
  final String language;
  final String backendUrl;
  final Function(int targetIndex)? onNavigateTab;
  final Function(String city, String state, String country)? onCityChange;

  const MyTripScreen({
    Key? key,
    required this.language,
    this.backendUrl = "https://omni-backend-pk28.onrender.com",
    this.onNavigateTab,
    this.onCityChange,
  }) : super(key: key);

  @override
  State<MyTripScreen> createState() => _MyTripScreenState();
}

class _MyTripScreenState extends State<MyTripScreen> {
  Map<String, dynamic> _user = {};
  Map<String, dynamic> _trip = {};
  List<TripExpense> _recentExpenses = [];
  double _todaySpendSum = 0.0;

  bool _isLoading = true;
  Timer? _clockTimer;
  DateTime _currentClock = DateTime.now();

  String _travelMode = "Home";
  String _liveTemperature = "29°C";
  bool _isNight = false;
  bool _isFetchingWeather = false;
  bool _isGuest = false;

  Position? _lastKnownPosition;
  late FlutterTts _flutterTts;

  static const Map<String, Map<String, String>> _dict = {
    "English": {
      "greeting_morning": "Good Morning, {name}!",
      "greeting_afternoon": "Good Afternoon, {name}!",
      "greeting_evening": "Good Evening, {name}!",
      "guest_default": "Leslie",
      "action_translate": "Translate\n& Lens",
      "action_bargain": "Bargain\nPal",
      "action_ar": "AR\nRadar",
      "action_passport": "Passport\nStamps",
      "no_activities": "No upcoming activities",
      "scheduled_plans": "scheduled plans today",
      "add_plans_sub": "Add your plans, tickets or reminders.",
      "add_activity_btn": "+ Add Activity",
      "emergency_header": "Emergency Lifelines",
      "emergency_sub": "Instant regional first-responder directory",
      "hospital": "Hospital",
      "police": "Police",
      "fire_station": "Fire Station",
      "chemist": "24h Chemist",
      "explore_tools": "Explore & Tools",
      "tool_destination": "Destination\nExplorer",
      "tool_railway": "Railway\nTransit",
      "tool_chat": "Guide\nChat",
      "tool_vault": "Family\nVault",
      "tool_gems": "Community\nGems",
      "tool_scanner": "Paper Pilot\nScanner",
      "tool_converter": "Converter\nStudio",
      "tool_more": "More\nFeatures",
      "add_activity_title": "Add Schedule Activity",
      "venue_label": "Venue / Spot Location",
      "activity_label": "Activity / Plan Title",
      "save_btn": "Save Activity",
      "cancel_btn": "Cancel",
      "sos_tab_label": "SOS",
    },
    "Marathi": {
      "greeting_morning": "शुभ सकाळ, {name}!",
      "greeting_afternoon": "शुभ दुपार, {name}!",
      "greeting_evening": "शुभ संध्याकाळ, {name}!",
      "guest_default": "लेस्ली",
      "action_translate": "भाषांतर\nव लेन्स",
      "action_bargain": "भावतोल\nमित्र",
      "action_ar": "दिशादर्शक\nकम्पास",
      "action_passport": "पर्यटन\nशिक्के",
      "no_activities": "कोणतीही आगामी योजना नाही",
      "scheduled_plans": "नियोजित योजना आज",
      "add_plans_sub": "तुमच्या सहलीच्या योजना व स्मरणपत्रे जोडा.",
      "add_activity_btn": "+ कृती जोडा",
      "emergency_header": "तातडीच्या आपत्कालीन सेवा",
      "emergency_sub": "आवश्यक सेवांशी त्वरित थेट संपर्क",
      "hospital": "रुग्णालय",
      "police": "पोलीस ठाणे",
      "fire_station": "अग्निशामक",
      "chemist": "२४ तास मेडिकल",
      "explore_tools": "अन्वेषण आणि साधने",
      "tool_destination": "पर्यटन स्थळे\nमार्गदर्शक",
      "tool_railway": "रेल्वे\nमाहिती",
      "tool_chat": "पर्यटन\nसंवाद",
      "tool_vault": "कौटुंबिक\nतिजोरी",
      "tool_gems": "स्थानिक\nरत्ने",
      "tool_scanner": "पेपर पायलट\nस्कॅनर",
      "tool_converter": "कन्व्हर्टर\nस्टुडिओ",
      "tool_more": "इतर\nसुविधा",
      "add_activity_title": "नवीन योजना जोडा",
      "venue_label": "स्थळ / स्थान",
      "activity_label": "कार्यक्रमाचे नाव",
      "save_btn": "जतन करा",
      "cancel_btn": "रद्द करा",
      "sos_tab_label": "मदत",
    },
    "Hindi": {
      "greeting_morning": "सुप्रभात, {name}!",
      "greeting_afternoon": "शुभ दोपहर, {name}!",
      "greeting_evening": "शुभ संध्या, {name}!",
      "guest_default": "लेस्ली",
      "action_translate": "अनुवाद\nव लेंस",
      "action_bargain": "मोलभाव\nमित्र",
      "action_ar": "दिशा\nरडार",
      "action_passport": "पासपोर्ट\nमुहर",
      "no_activities": "कोई आगामी योजना नहीं",
      "scheduled_plans": "निर्धारित योजनाएं आज",
      "add_plans_sub": "अपनी योजनाएं, टिकट या रिमाइंडर जोड़ें।",
      "add_activity_btn": "+ गतिविधि जोड़ें",
      "emergency_header": "आपातकालीन हेल्पलाइन",
      "emergency_sub": "आवश्यक सेवाओं तक त्वरित सीधी पहुंच",
      "hospital": "अस्पताल",
      "police": "पुलिस",
      "fire_station": "दमकल केंद्र",
      "chemist": "24 घंटे मेडिकल",
      "explore_tools": "एक्सप्लोर और टूल्स",
      "tool_destination": "गंतव्य\nखोजें",
      "tool_railway": "रेलवे\nट्रांजिट",
      "tool_chat": "गाइड\nचैट",
      "tool_vault": "फैमिली\nवॉल्ट",
      "tool_gems": "लोकल\nस्थान",
      "tool_scanner": "पेपर पायलट\nस्कॅनर",
      "tool_converter": "कन्वर्टर\nस्टूडियो",
      "tool_more": "अन्य\nसुविधाएं",
      "add_activity_title": "योजना गतिविधि जोड़ें",
      "venue_label": "स्थान / पता",
      "activity_label": "योजना का शीर्षक",
      "save_btn": "सहेजें",
      "cancel_btn": "रद्द करें",
      "sos_tab_label": "मदद",
    },
    "Gujarati": {
      "greeting_morning": "સુપ્રભાત, {name}!",
      "greeting_afternoon": "શુભ બપોર, {name}!",
      "greeting_evening": "શુભ સંધ્યા, {name}!",
      "guest_default": "લેસ્લી",
      "action_translate": "અનુવાદ\nઅને લેન્સ",
      "action_bargain": "ભાવતોલ\nમિત્ર",
      "action_ar": "એઆર\nરડાર",
      "action_passport": "પાસપોર્ટ\nસિક્કા",
      "no_activities": "કોઈ નવી યોજના નથી",
      "scheduled_plans": "આજની નિર્ધારિત યોજનાઓ",
      "add_plans_sub": "તમારી યોજનાઓ અથવા રીમાઇન્ડર્સ ઉમેરો.",
      "add_activity_btn": "+ યોજના ઉમેરો",
      "emergency_header": "ઇમરજન્સી સેવાઓ",
      "emergency_sub": "પ્રાદેશિક તાત્કાલિક સહાય ડિરેક્ટરી",
      "hospital": "હોસ્પિટલ",
      "police": "પોલીસ સ્ટેશન",
      "fire_station": "ફાયર બ્રિગેડ",
      "chemist": "૨૪ કલાક મેડિકલ",
      "explore_tools": "અન્વેષણ અને સાધનો",
      "tool_destination": "સ્થળો\nશોધો",
      "tool_railway": "રેલ્વે\nમાહિતી",
      "tool_chat": "ગાઇડ\nચેટ",
      "tool_vault": "ફેમિલી\nવોલ્ટ",
      "tool_gems": "સ્થાનિક\nરત્નો",
      "tool_scanner": "પેપર પાયલટ\nસ્કેનર",
      "tool_converter": "કન્વર્ટર\nસ્ટુડિયો",
      "tool_more": "વધુ\nસાધનો",
      "add_activity_title": "નવી યોજના ઉમેરો",
      "venue_label": "સ્થળનું નામ",
      "activity_label": "યોજનાનું નામ",
      "save_btn": "સાચવો",
      "cancel_btn": "રદ કરો",
      "sos_tab_label": "મદદ",
    },
    "Bengali": {
      "greeting_morning": "সুপ্রভাত, {name}!",
      "greeting_afternoon": "শুভ অপরাহ্ন, {name}!",
      "greeting_evening": "শুভ সন্ধ্যা, {name}!",
      "guest_default": "লেসলি",
      "action_translate": "অনুবাদ\nও লেন্স",
      "action_bargain": "দরদাম\nবন্ধু",
      "action_ar": "এআর\nরাডার",
      "action_passport": "পাসপোর্ট\nস্ট্যাম্প",
      "no_activities": "কোনো আসন্ন পরিকল্পনা নেই",
      "scheduled_plans": "আজকের নির্ধারিত পরিকল্পনা",
      "add_plans_sub": "আপনার ভ্রমণের পরিকল্পনা যোগ করুন।",
      "add_activity_btn": "+ পরিকল্পনা যোগ করুন",
      "emergency_header": "জরুরী হেল্পলাইন",
      "emergency_sub": "প্রয়োজনীয় জরুরী সহায়তা পরিষেবা",
      "hospital": "হাসপাতাল",
      "police": "থানা",
      "fire_station": "দমকল কেন্দ্র",
      "chemist": "২৪ ঘণ্টার ফার্মেসি",
      "explore_tools": "অন্বেষণ এবং সরঞ্জাম",
      "tool_destination": "গন্তব্য\nসন্ধান",
      "tool_railway": "রেলওয়ে\nট্রানজিট",
      "tool_chat": "গাইড\nচ্যাট",
      "tool_vault": "পারিবারিক\nভল্ট",
      "tool_gems": "স্থানীয়\nদর্শনীয় স্থান",
      "tool_scanner": "পেপার পাইলট\nস্ক্যানার",
      "tool_converter": "কনভার্টার\nস্টুডিও",
      "tool_more": "আরও\nসুবিধা",
      "add_activity_title": "কার্যক্রম যোগ করুন",
      "venue_label": "স্থান / ঠিকানা",
      "activity_label": "পরিকল্পনার শিরোনাম",
      "save_btn": "সংরক্ষণ করুন",
      "cancel_btn": "বাতিল",
      "sos_tab_label": "সাহায্য",
    },
    "Tamil": {
      "greeting_morning": "காலை வணக்கம், {name}!",
      "greeting_afternoon": "மதிய வணக்கம், {name}!",
      "greeting_evening": "மாலை வணக்கம், {name}!",
      "guest_default": "லெஸ்லி",
      "action_translate": "மொழிபெயர்ப்பு\n& லென்ஸ்",
      "action_bargain": "பேரம்பேசும்\nதோழன்",
      "action_ar": "ஏஆர்\nராடார்",
      "action_passport": "பாஸ்போர்ட்\nமுத்திரைகள்",
      "no_activities": "வரவிருக்கும் திட்டங்கள் இல்லை",
      "scheduled_plans": "இன்றைய திட்டமிடப்பட்ட நிகழ்வுகள்",
      "add_plans_sub": "உங்கள் பயணத் திட்டங்களைச் சேர்க்கவும்.",
      "add_activity_btn": "+ நிகழ்வைச் சேர்",
      "emergency_header": "அவசர உதவி எண்கள்",
      "emergency_sub": "உடனடி பிராந்திய உதவி டைரக்டரி",
      "hospital": "மருத்துவமனை",
      "police": "காவல் நிலையம்",
      "fire_station": "தீயணைப்பு நிலையம்",
      "chemist": "24 மணி நேர மருந்தகம்",
      "explore_tools": "ஆராய்வு & கருவிகள்",
      "tool_destination": "இடங்களை\nஆராய்க",
      "tool_railway": "ரயில்வே\nபோக்குவரத்து",
      "tool_chat": "வழிகாட்டி\nஅரட்டை",
      "tool_vault": "குடும்ப\nபெட்டகம்",
      "tool_gems": "உள்ளூர்\nசிறப்புகள்",
      "tool_scanner": "பேப்பர் பைலட்\nஸ்கேனர்",
      "tool_converter": "மாற்றி\nஸ்டுடியோ",
      "tool_more": "கூடுதல்\nகருவிகள்",
      "add_activity_title": "நிகழ்வைச் சேர்க்கவும்",
      "venue_label": "இடம்",
      "activity_label": "திட்டத்தின் பெயர்",
      "save_btn": "சேமிக்கவும்",
      "cancel_btn": "ரத்துசெய்",
      "sos_tab_label": "உதவி",
    },
    "Telugu": {
      "greeting_morning": "శుభోదయం, {name}!",
      "greeting_afternoon": "శుభ మధ్యాహ్నం, {name}!",
      "greeting_evening": "శుభ సాయంత్రం, {name}!",
      "guest_default": "లెస్లీ",
      "action_translate": "అనువాదం\n& లెన్స్",
      "action_bargain": "బేరసారాల\nమిత్రుడు",
      "action_ar": "ఏఆర్\nరాడార్",
      "action_passport": "పాస్‌పోర్ట్\nస్టాంపులు",
      "no_activities": "రాబోయే ప్రణాళికలు లేవు",
      "scheduled_plans": "ఈరోజు షెడ్యూల్ చేసిన ప్రణాళికలు",
      "add_plans_sub": "మీ ప్రయాణ ప్రణాళికలను జోడించండి.",
      "add_activity_btn": "+ ఈవెంట్ జోడించు",
      "emergency_header": "అత్యవసర హెల్ప్‌లైన్లు",
      "emergency_sub": "తక్షణ ప్రాంతీయ అత్యవసర డైరెక్టరీ",
      "hospital": "ఆసుపత్రి",
      "police": "పోలీస్ స్టేషన్",
      "fire_station": "అగ్నిమాపక కేంద్రం",
      "chemist": "24 గంటల మెడికల్",
      "explore_tools": "అన్వేషణ & ఉపకరణాలు",
      "tool_destination": "గమ్యస్థానాలు\nఅన్వేషించండి",
      "tool_railway": "రైల్వే\nసమాచారం",
      "tool_chat": "గైడ్\nచాట్",
      "tool_vault": "ఫ్యామిలీ\nవాల్ట్",
      "tool_gems": "స్థానిక\nరత్నాలు",
      "tool_scanner": "పేపర్ పైలట్\nస్కానర్",
      "tool_converter": "కన్వర్టర్\nస్టూడియో",
      "tool_more": "మరిన్ని\nఫీచర్లు",
      "add_activity_title": "కార్యక్రమాన్ని జోడించండి",
      "venue_label": "ప్రదేశం",
      "activity_label": "ప్రణాళిక శీర్షిక",
      "save_btn": "సేవ్ చేయండి",
      "cancel_btn": "రద్దు చేయండి",
      "sos_tab_label": "సహాయం",
    },
    "Kannada": {
      "greeting_morning": "ಶುಭೋದಯ, {name}!",
      "greeting_afternoon": "ಶುಭ ಮಧ್ಯಾಹ್ನ, {name}!",
      "greeting_evening": "ಶುಭ ಸಂಜೆ, {name}!",
      "guest_default": "ಲೆಸ್ಲಿ",
      "action_translate": "ಅನುವಾದ\n& ಲೆನ್ಸ್",
      "action_bargain": "ಚೌಕಾಶಿ\nಮಿತ್ರ",
      "action_ar": "ಎಆರ್\nರಾಡಾರ್",
      "action_passport": "ಪಾಸ್‌ಪೋರ್ಟ್\nಸ್ಟ್ಯಾಂಪ್",
      "no_activities": "ಯಾವುದೇ ಮುಂಬರುವ ಯೋಜನೆಗಳಿಲ್ಲ",
      "scheduled_plans": "ಇಂದಿನ ನಿಗದಿತ ಯೋಜನೆಗಳು",
      "add_plans_sub": "ನಿಮ್ಮ ಯೋಜನೆಗಳು ಮತ್ತು ಟಿಕೆಟ್‌ಗಳನ್ನು ಸೇರಿಸಿ.",
      "add_activity_btn": "+ ಯೋಜನೆ ಸೇರಿಸಿ",
      "emergency_header": "ತುರ್ತು ಸಹಾಯವಾಣಿ",
      "emergency_sub": "ಪ್ರಾದೇಶಿಕ ಪ್ರಥಮ ಸ್ಪಂದನ ಡೈರೆಕ್ಟರಿ",
      "hospital": "ಆಸ್ಪತ್ರೆ",
      "police": "ಪೊಲೀಸ್ ಠಾಣೆ",
      "fire_station": "ಅಗ್ನಿಶಾಮಕ ಠಾಣೆ",
      "chemist": "24 ಗಂಟೆ ಔಷಧಾಲಯ",
      "explore_tools": "ಅನ್ವೇಷಣೆ ಮತ್ತು ಉಪಕರಣಗಳು",
      "tool_destination": "ತಾಣಗಳನ್ನು\nಹುಡುಕಿ",
      "tool_railway": "ರೈಲ್ವೆ\nಮಾಹಿತಿ",
      "tool_chat": "ಮಾರ್ಗದರ್ಶಿ\nಚಾಟ್",
      "tool_vault": "ಕುಟುಂಬದ\nಖಜಾನೆ",
      "tool_gems": "ಸ್ಥಳೀಯ\nವಿಶೇಷತೆ",
      "tool_scanner": "ಪೇಪರ್ ಪೈಲಟ್\nಸ್ಕ್ಯಾನರ್",
      "tool_converter": "ಪರಿವರ್ತಕ\nಸ್ಟುಡಿಯೋ",
      "tool_more": "ಹೆಚ್ಚಿನ\nಸೌಲಭ್ಯಗಳು",
      "add_activity_title": "ಯೋಜನೆಯನ್ನು ಸೇರಿಸಿ",
      "venue_label": "ಸ್ಥಳ",
      "activity_label": "ಯೋಜನೆಯ ಹೆಸರು",
      "save_btn": "ಉಳಿಸಿ",
      "cancel_btn": "ರದ್ದುಮಾಡಿ",
      "sos_tab_label": "ಸಹಾಯ",
    },
    "Malayalam": {
      "greeting_morning": "സുപ്രഭാതം, {name}!",
      "greeting_afternoon": "ശുഭ ഉച്ചതിരിഞ്ഞ്, {name}!",
      "greeting_evening": "ശുഭ സായാഹ്നം, {name}!",
      "guest_default": "ലെസ്ലി",
      "action_translate": "വിവർത്തനം\n& ലെൻസ്",
      "action_bargain": "വിലപേശൽ\nകൂട്ടുകാരൻ",
      "action_ar": "എആർ\nറഡാർ",
      "action_passport": "പാസ്പോർട്ട്\nസ്റ്റാമ്പുകൾ",
      "no_activities": "വരാനിരിക്കുന്ന പ്ലാനുകളൊന്നുമില്ല",
      "scheduled_plans": "ഇന്നത്തെ ഷെഡ്യൂൾ ചെയ്ത പ്ലാനുകൾ",
      "add_plans_sub": "നിങ്ങളുടെ യാത്രാ പദ്ധതികൾ ചേർക്കുക.",
      "add_activity_btn": "+ പ്ലാൻ ചേർക്കുക",
      "emergency_header": "അടിയന്തര ഹെൽപ്പ് ലൈനുകൾ",
      "emergency_sub": "പ്രാദേശിക അടിയന്തര സഹായ ഡയറക്ടറി",
      "hospital": "ആശുപത്രി",
      "police": "പോലീസ് സ്റ്റേഷൻ",
      "fire_station": "ഫയർ സ്റ്റേഷൻ",
      "chemist": "24 മണിക്കൂർ മെഡിക്കൽ",
      "explore_tools": "അന്വേഷണവും ഉപകരണങ്ങളും",
      "tool_destination": "സ്ഥലങ്ങൾ\nകണ്ടെത്തുക",
      "tool_railway": "റെയിൽവേ\nവിവരങ്ങൾ",
      "tool_chat": "ഗൈഡ്\nചാറ്റ്",
      "tool_vault": "കുടുംബ\nവോൾട്ട്",
      "tool_gems": "പ്രാദേശിക\nകാഴ്ചകൾ",
      "tool_scanner": "പേപ്പർ പൈലറ്റ്\nസ്കാനർ",
      "tool_converter": "കൺവെർട്ടർ\nസ്റ്റുഡിയോ",
      "tool_more": "കൂടുതൽ\nസേവനങ്ങൾ",
      "add_activity_title": "പ്ലാൻ ചേർക്കുക",
      "venue_label": "സ്ഥലം",
      "activity_label": "പ്ലാൻ പേര്",
      "save_btn": "സംരക്ഷിക്കുക",
      "cancel_btn": "റദ്ദാക്കുക",
      "sos_tab_label": "സഹായം",
    },
    "Punjabi": {
      "greeting_morning": "ਸ਼ੁਭ ਸਵੇਰ, {name}!",
      "greeting_afternoon": "ਸ਼ੁਭ ਦੁਪਹਿਰ, {name}!",
      "greeting_evening": "ਸ਼ੁਭ ਸ਼ਾਮ, {name}!",
      "guest_default": "ਲੈਸਲੀ",
      "action_translate": "ਅਨੁਵਾਦ\nਅਤੇ ਲੈਂਸ",
      "action_bargain": "ਮੁੱਲ-ਭਾਵ\nਮਿੱਤਰ",
      "action_ar": "ਏਆਰ\nਰਾਡਾਰ",
      "action_passport": "ਪਾਸਪੋਰਟ\nਮੋਹਰਾਂ",
      "no_activities": "ਕੋਈ ਆਗਾਮੀ ਯੋਜਨਾ ਨਹੀਂ",
      "scheduled_plans": "ਅੱਜ ਦੀਆਂ ਨਿਰਧਾਰਤ ਯੋਜਨਾਵਾਂ",
      "add_plans_sub": "ਆਪਣੀਆਂ ਯਾਤਰਾ ਯੋਜਨਾਵਾਂ ਸ਼ਾਮਲ ਕਰੋ।",
      "add_activity_btn": "+ ਯੋਜਨਾ ਜੋੜੋ",
      "emergency_header": "ਐਮਰਜੈਂਸੀ ਹੈਲਪਲਾਈਨ",
      "emergency_sub": "ਖੇਤਰੀ ਐਮਰਜੈਂਸੀ ਸਹਾਇਤਾ ਡਾਇਰੈਕਟਰੀ",
      "hospital": "ਹਸਪਤਾਲ",
      "police": "ਪੁਲਿਸ ਸਟੇਸ਼ਨ",
      "fire_station": "ਫਾਇਰ ਬ੍ਰਿਗੇਡ",
      "chemist": "24 ਘੰਟੇ ਮੈਡੀਕਲ",
      "explore_tools": "ਖੋਜ ਅਤੇ ਸਾਧਨ",
      "tool_destination": "ਸਥਾਨਾਂ ਦੀ\nਖੋਜ",
      "tool_railway": "ਰੇਲਵੇ\nਟ੍ਰਾਂਜ਼ਿਟ",
      "tool_chat": "ਗਾਈਡ\nਗੱਲਬਾਤ",
      "tool_vault": "ਪਰਿਵਾਰਕ\nਵਾਲਟ",
      "tool_gems": "ਸਥਾਨਕ\nਸਥਾਨ",
      "tool_scanner": "ਪੇਪਰ ਪਾਇਲਟ\nਸਕੈਨਰ",
      "tool_converter": "ਕਨਵਰਟਰ\nਸਟੂਡੀਓ",
      "tool_more": "ਹੋਰ\nਸਹੂਲਤਾਂ",
      "add_activity_title": "ਯੋਜਨਾ ਜੋੜੋ",
      "venue_label": "ਸਥਾਨ",
      "activity_label": "ਯੋਜਨਾ ਦਾ ਸਿਰਲੇਖ",
      "save_btn": "ਸੰਭਾਲੋ",
      "cancel_btn": "ਰੱਦ ਕਰੋ",
      "sos_tab_label": "ਮਦਦ",
    },
    "Odia": {
      "greeting_morning": "ଶୁଭ ସକାଳ, {name}!",
      "greeting_afternoon": "ଶୁଭ ଅପରାହ୍ନ, {name}!",
      "greeting_evening": "ଶୁଭ ସନ୍ଧ୍ୟା, {name}!",
      "guest_default": "ଲେସଲି",
      "action_translate": "ଅନୁବାଦ\nଓ ଲେନ୍ସ",
      "action_bargain": "ଦରଦାମ\nସାଥୀ",
      "action_ar": "ଏଆର\nରାଡାର",
      "action_passport": "ପାସପୋର୍ଟ\nଷ୍ଟାମ୍ପ",
      "no_activities": "କୌଣସି ଆଗାମୀ ଯୋଜନା ନାହିଁ",
      "scheduled_plans": "ଆଜିର ନିର୍ଦ୍ଧାରିତ ଯୋଜନା",
      "add_plans_sub": "ଆପଣଙ୍କର ଭ୍ରମଣ ଯୋଜନା ଯୋଡ଼ନ୍ତୁ।",
      "add_activity_btn": "+ ଯୋଜନା ଯୋଡ଼ନ୍ତୁ",
      "emergency_header": "ଜରୁରୀକାଳୀନ ହେଲ୍ପଲାଇନ",
      "emergency_sub": "ଆଞ୍ଚଳିକ ଜରୁରୀକାଳୀନ ସହାୟତା",
      "hospital": "ଡାକ୍ତରଖାନା",
      "police": "ଥାନା",
      "fire_station": "ଅଗ୍ନିଶମ ବାହିନୀ",
      "chemist": "୨୪ ଘଣ୍ଟା ମେଡିକାଲ",
      "explore_tools": "ଅନ୍ୱେଷଣ ଏବଂ ଉପକରଣ",
      "tool_destination": "ସ୍ଥାନ\nଖୋଜନ୍ତୁ",
      "tool_railway": "ରେଳବାଇ\nସୂଚନା",
      "tool_chat": "ଗାଇଡ୍\nଚାଟ୍",
      "tool_vault": "ପାରିବାରିକ\nଭଲ୍ଟ",
      "tool_gems": "ସ୍ଥାନୀୟ\nଆକର୍ଷଣ",
      "tool_scanner": "ପେପର ପାଇଲଟ\nସ୍କାନର",
      "tool_converter": "କନଭର୍ଟର\nଷ୍ଟୁଡିଓ",
      "tool_more": "ଅଧିକ\nସୁବିଧା",
      "add_activity_title": "ଯୋଜନା ଯୋଡ଼ନ୍ତୁ",
      "venue_label": "ସ୍ଥାନ",
      "activity_label": "ଯୋଜନାର ନାମ",
      "save_btn": "ସାଇତନ୍ତୁ",
      "cancel_btn": "ବାତିଲ",
      "sos_tab_label": "ସାହାଯ୍ୟ",
    },
    "Arabic": {
      "greeting_morning": "صباح الخير، {name}!",
      "greeting_afternoon": "مساء الخير، {name}!",
      "greeting_evening": "مساء الخير، {name}!",
      "guest_default": "ليزلي",
      "action_translate": "الترجمة\nوالعدسة",
      "action_bargain": "مساعد\nالمساومة",
      "action_ar": "رادار\nالواقع المعزز",
      "action_passport": "أختام\nالجواز",
      "no_activities": "لا توجد أنشطة قادمة",
      "scheduled_plans": "خطط مجدولة اليوم",
      "add_plans_sub": "أضف خطط رحلتك أو تذاكرك هنا.",
      "add_activity_btn": "+ إضافة نشاط",
      "emergency_header": "طوارئ الرحلة",
      "emergency_sub": "دليل المستجيب الأول الإقليمي الفوري",
      "hospital": "مستشفى",
      "police": "مركز شرطة",
      "fire_station": "إطفاء",
      "chemist": "صيدلية 24 ساعة",
      "explore_tools": "استكشف والأدوات",
      "tool_destination": "مستكشف\nالوجهات",
      "tool_railway": "نقل\nالقطارات",
      "tool_chat": "محادثة\nالمرشد",
      "tool_vault": "خزينة\nالعائلة",
      "tool_gems": "الأماكن\nالمميزة",
      "tool_scanner": "ماسح\nالوثائق",
      "tool_converter": "استوديو\nالتحويل",
      "tool_more": "المزيد من\nالميزات",
      "add_activity_title": "إضافة نشاط مجدول",
      "venue_label": "الموقع / العنوان",
      "activity_label": "عنوان الخطة / النشاط",
      "save_btn": "حفظ النشاط",
      "cancel_btn": "إلغاء",
      "sos_tab_label": "طوارئ",
    },
    "French": {
      "greeting_morning": "Bonjour, {name} !",
      "greeting_afternoon": "Bon après-midi, {name} !",
      "greeting_evening": "Bonsoir, {name} !",
      "guest_default": "Leslie",
      "action_translate": "Traduire\n& Lens",
      "action_bargain": "Négociateur\nMalin",
      "action_ar": "Radar\nAR",
      "action_passport": "Tampons\nPasseport",
      "no_activities": "Aucune activité à venir",
      "scheduled_plans": "activités prévues aujourd'hui",
      "add_plans_sub": "Ajoutez vos billets, visites et rappels.",
      "add_activity_btn": "+ Ajouter une activité",
      "emergency_header": "Lignes d'urgence",
      "emergency_sub": "Assistance et secours régionaux immédiats",
      "hospital": "Hôpital",
      "police": "Police",
      "fire_station": "Pompiers",
      "chemist": "Pharmacie 24h",
      "explore_tools": "Explorer & Outils",
      "tool_destination": "Explorateur\nde Lieux",
      "tool_railway": "Transit\nFerroviaire",
      "tool_chat": "Chat\nGuide",
      "tool_vault": "Coffre-fort\nFamille",
      "tool_gems": "Lieux\nSecrets",
      "tool_scanner": "Scanner\nde Documents",
      "tool_converter": "Studio de\nConversion",
      "tool_more": "Plus d'\nOptions",
      "add_activity_title": "Ajouter une activité",
      "venue_label": "Lieu / Emplacement",
      "activity_label": "Titre du projet",
      "save_btn": "Enregistrer",
      "cancel_btn": "Annuler",
      "sos_tab_label": "SOS",
    },
    "German": {
      "greeting_morning": "Guten Morgen, {name}!",
      "greeting_afternoon": "Guten Tag, {name}!",
      "greeting_evening": "Guten Abend, {name}!",
      "guest_default": "Leslie",
      "action_translate": "Übersetzen\n& Lens",
      "action_bargain": "Feilsch-\nPartner",
      "action_ar": "AR\nRadar",
      "action_passport": "Reisepass-\nStempel",
      "no_activities": "Keine bevorstehenden Aktivitäten",
      "scheduled_plans": "geplante Aktivitäten heute",
      "add_plans_sub": "Fügen Sie Ihre Pläne, Tickets oder Erinnerungen hinzu.",
      "add_activity_btn": "+ Aktivität hinzufügen",
      "emergency_header": "Notfall-Hotlines",
      "emergency_sub": "Direktes Verzeichnis regionaler Notdienste",
      "hospital": "Krankenhaus",
      "police": "Polizei",
      "fire_station": "Feuerwehr",
      "chemist": "24h Apotheke",
      "explore_tools": "Entdecken & Werkzeuge",
      "tool_destination": "Reiseziel-\nEntdecker",
      "tool_railway": "Bahn-\nTransit",
      "tool_chat": "Reiseleiter-\nChat",
      "tool_vault": "Familien-\nTresor",
      "tool_gems": "Geheim-\ntipps",
      "tool_scanner": "Dokumenten-\nScanner",
      "tool_converter": "Währungs-\nStudio",
      "tool_more": "Mehr\nFunktionen",
      "add_activity_title": "Aktivität planen",
      "venue_label": "Ort / Treffpunkt",
      "activity_label": "Titel der Aktivität",
      "save_btn": "Speichern",
      "cancel_btn": "Abbrechen",
      "sos_tab_label": "SOS",
    },
    "Spanish": {
      "greeting_morning": "¡Buenos días, {name}!",
      "greeting_afternoon": "¡Buenas tardes, {name}!",
      "greeting_evening": "¡Buenas noches, {name}!",
      "guest_default": "Leslie",
      "action_translate": "Traducir\ny Lens",
      "action_bargain": "Amigo de\nRegateo",
      "action_ar": "Radar\nAR",
      "action_passport": "Sellos de\nPasaporte",
      "no_activities": "No hay actividades próximas",
      "scheduled_plans": "planes programados hoy",
      "add_plans_sub": "Añade tus entradas, recorridos y notas.",
      "add_activity_btn": "+ Añadir actividad",
      "emergency_header": "Líneas de Emergencia",
      "emergency_sub": "Directorio de primeros auxilios y socorro",
      "hospital": "Hospital",
      "police": "Policía",
      "fire_station": "Bomberos",
      "chemist": "Farmacia 24h",
      "explore_tools": "Explorar y Herramientas",
      "tool_destination": "Explorador de\nDestinos",
      "tool_railway": "Tránsito\nFerroviario",
      "tool_chat": "Chat con\nel Guía",
      "tool_vault": "Bóveda\nFamiliar",
      "tool_gems": "Joyas\nLocales",
      "tool_scanner": "Escáner de\nDocumentos",
      "tool_converter": "Estudio de\nConversión",
      "tool_more": "Más\nOpciones",
      "add_activity_title": "Añadir actividad al plan",
      "venue_label": "Lugar / Dirección",
      "activity_label": "Título de la actividad",
      "save_btn": "Guardar",
      "cancel_btn": "Cancelar",
      "sos_tab_label": "SOS",
    },
    "Italian": {
      "greeting_morning": "Buongiorno, {name}!",
      "greeting_afternoon": "Buon pomeriggio, {name}!",
      "greeting_evening": "Buonasera, {name}!",
      "guest_default": "Leslie",
      "action_translate": "Traduci\n& Lens",
      "action_bargain": "Guida alla\nTrattativa",
      "action_ar": "Radar\nAR",
      "action_passport": "Timbri\nPassaporto",
      "no_activities": "Nessuna attività in programma",
      "scheduled_plans": "attività pianificate oggi",
      "add_plans_sub": "Aggiungi biglietti, tour o promemoria.",
      "add_activity_btn": "+ Aggiungi attività",
      "emergency_header": "Linee di Emergenza",
      "emergency_sub": "Pronto intervento e assistenza medica",
      "hospital": "Ospedale",
      "police": "Polizia",
      "fire_station": "Vigili del Fuoco",
      "chemist": "Farmacia 24h",
      "explore_tools": "Esplora & Strumenti",
      "tool_destination": "Esploratore\nDestinazioni",
      "tool_railway": "Transito\nFerroviario",
      "tool_chat": "Chat con\nla Guida",
      "tool_vault": "Cassaforte\nFamiglia",
      "tool_gems": "Perle\nLocali",
      "tool_scanner": "Scanner\nDocumenti",
      "tool_converter": "Studio\nConversione",
      "tool_more": "Altre\nFunzioni",
      "add_activity_title": "Pianifica attività",
      "venue_label": "Luogo / Indirizzo",
      "activity_label": "Titolo attività",
      "save_btn": "Salva",
      "cancel_btn": "Annulla",
      "sos_tab_label": "SOS",
    },
    "Portuguese": {
      "greeting_morning": "Bom dia, {name}!",
      "greeting_afternoon": "Boa tarde, {name}!",
      "greeting_evening": "Boa noite, {name}!",
      "guest_default": "Leslie",
      "action_translate": "Traduzir\n& Lens",
      "action_bargain": "Amigo de\nNegociação",
      "action_ar": "Radar\nAR",
      "action_passport": "Carimbos de\nPassaporte",
      "no_activities": "Nenhuma atividade agendada",
      "scheduled_plans": "planos agendados para hoje",
      "add_plans_sub": "Adicione bilhetes, passeios e lembretes.",
      "add_activity_btn": "+ Adicionar atividade",
      "emergency_header": "Linhas de Emergência",
      "emergency_sub": "Diretório de socorro e serviços médicos",
      "hospital": "Hospital",
      "police": "Polícia",
      "fire_station": "Bombeiros",
      "chemist": "Farmácia 24h",
      "explore_tools": "Explorar & Ferramentas",
      "tool_destination": "Explorador de\nDestinos",
      "tool_railway": "Trânsito\nFerroviário",
      "tool_chat": "Chat com\no Guia",
      "tool_vault": "Cofre\nFamiliar",
      "tool_gems": "Segredos\nLocais",
      "tool_scanner": "Scanner de\nDocumentos",
      "tool_converter": "Estúdio de\nConversão",
      "tool_more": "Mais\nRecursos",
      "add_activity_title": "Adicionar atividade",
      "venue_label": "Localização",
      "activity_label": "Nome da atividade",
      "save_btn": "Salvar",
      "cancel_btn": "Cancelar",
      "sos_tab_label": "SOS",
    },
    "Russian": {
      "greeting_morning": "Доброе утро, {name}!",
      "greeting_afternoon": "Добрый день, {name}!",
      "greeting_evening": "Добрый вечер, {name}!",
      "guest_default": "Лесли",
      "action_translate": "Переводчик\nи Lens",
      "action_bargain": "Помощник\nпо торгам",
      "action_ar": "AR\nРадар",
      "action_passport": "Штампы в\nпаспорте",
      "no_activities": "Нет запланированных дел",
      "scheduled_plans": "планов на сегодня",
      "add_plans_sub": "Добавьте билеты, экскурсии и напоминания.",
      "add_activity_btn": "+ Добавить",
      "emergency_header": "Службы экстренной помощи",
      "emergency_sub": "Горячие линии и экстренная помощь",
      "hospital": "Больница",
      "police": "Полиция",
      "fire_station": "Пожарная служба",
      "chemist": "Круглосуточная аптека",
      "explore_tools": "Инструменты и гид",
      "tool_destination": "Гид по\nгороду",
      "tool_railway": "Поезда и\nвокзалы",
      "tool_chat": "Чат с\nгидом",
      "tool_vault": "Семейный\nсейф",
      "tool_gems": "Секретные\nместа",
      "tool_scanner": "Сканер\nдокументов",
      "tool_converter": "Конвертер\nвалют",
      "tool_more": "Другие\nфункции",
      "add_activity_title": "Запланировать дело",
      "venue_label": "Место / адрес",
      "activity_label": "Название мероприятия",
      "save_btn": "Сохранить",
      "cancel_btn": "Отмена",
      "sos_tab_label": "SOS",
    },
    "Japanese": {
      "greeting_morning": "おはようございます、{name}さん！",
      "greeting_afternoon": "こんにちは、{name}さん！",
      "greeting_evening": "こんばんは、{name}さん！",
      "guest_default": "レスリー",
      "action_translate": "翻訳 &\nレンズ",
      "action_bargain": "価格交渉\nアシスト",
      "action_ar": "AR\nレーダー",
      "action_passport": "パスポート\nスタンプ",
      "no_activities": "予定はありません",
      "scheduled_plans": "件の予定（本日）",
      "add_plans_sub": "チケットや旅程を追加しましょう。",
      "add_activity_btn": "+ 予定を追加",
      "emergency_header": "緊急連絡先",
      "emergency_sub": "地域の緊急救助・医療機関案内",
      "hospital": "病院",
      "police": "警察署",
      "fire_station": "消防署",
      "chemist": "24時間薬局",
      "explore_tools": "探索 & ツール",
      "tool_destination": "観光スポット\nガイド",
      "tool_railway": "鉄道・交通\n案内",
      "tool_chat": "AIガイド\nチャット",
      "tool_vault": "ファミリー\n保管庫",
      "tool_gems": "隠れた\n名所",
      "tool_scanner": "書類\nスキャナー",
      "tool_converter": "通貨\n換算",
      "tool_more": "その他の\n機能",
      "add_activity_title": "新しい予定を追加",
      "venue_label": "場所 / スポット名",
      "activity_label": "予定のタイトル",
      "save_btn": "保存する",
      "cancel_btn": "キャンセル",
      "sos_tab_label": "SOS",
    },
    "Chinese": {
      "greeting_morning": "早上好，{name}！",
      "greeting_afternoon": "下午好，{name}！",
      "greeting_evening": "晚上好，{name}！",
      "guest_default": "莱斯利",
      "action_translate": "翻译\n与镜头",
      "action_bargain": "砍价\n助手",
      "action_ar": "AR\n雷达",
      "action_passport": "护照\n印章",
      "no_activities": "暂无待办活动",
      "scheduled_plans": "项今日计划",
      "add_plans_sub": "添加您的出行计划、门票或提醒事项。",
      "add_activity_btn": "+ 添加活动",
      "emergency_header": "紧急求助热线",
      "emergency_sub": "当地急救与安全保障热线",
      "hospital": "医院",
      "police": "警察局",
      "fire_station": "消防站",
      "chemist": "24小时药房",
      "explore_tools": "探索与实用工具",
      "tool_destination": "目的地\n探索",
      "tool_railway": "火车\n交通",
      "tool_chat": "导游\n咨询",
      "tool_vault": "家庭\n保险库",
      "tool_gems": "特色\n景点",
      "tool_scanner": "文书\n扫描仪",
      "tool_converter": "汇率\n换算",
      "tool_more": "更多\n功能",
      "add_activity_title": "添加行程活动",
      "venue_label": "地点 / 地址",
      "activity_label": "活动名称",
      "save_btn": "保存",
      "cancel_btn": "取消",
      "sos_tab_label": "求助",
    },
    "Thai": {
      "greeting_morning": "สวัสดีตอนเช้า, {name}!",
      "greeting_afternoon": "สวัสดีตอนบ่าย, {name}!",
      "greeting_evening": "สวัสดีตอนเย็น, {name}!",
      "guest_default": "เลสลี่",
      "action_translate": "แปลภาษา\n& เลนส์",
      "action_bargain": "ผู้ช่วย\nต่อราคา",
      "action_ar": "เออาร์\nเรดาร์",
      "action_passport": "ตราประทับ\nพาสปอร์ต",
      "no_activities": "ไม่มีกิจกรรมที่กำลังจะมาถึง",
      "scheduled_plans": "แผนการเดินทางวันนี้",
      "add_plans_sub": "เพิ่มแผนการเดินทาง ตั๋ว หรือบันทึกของคุณ",
      "add_activity_btn": "+ เพิ่มกิจกรรม",
      "emergency_header": "สายด่วนฉุกเฉิน",
      "emergency_sub": "ศูนย์ให้ความช่วยเหลือและกู้ภัยฉุกเฉิน",
      "hospital": "โรงพยาบาล",
      "police": "สถานีตำรวจ",
      "fire_station": "สถานีดับเพลิง",
      "chemist": "ร้านขายยา 24 ชม.",
      "explore_tools": "สำรวจ & เครื่องมือ",
      "tool_destination": "ค้นหา\nสถานที่",
      "tool_railway": "ข้อมูล\nรถไฟ",
      "tool_chat": "แชทกับ\nไกด์",
      "tool_vault": "ตู้เซฟ\nครอบครัว",
      "tool_gems": "สถานที่\nแนะนำ",
      "tool_scanner": "สแกนเนอร์\nเอกสาร",
      "tool_converter": "คำนวณ\nอัตราแลกเปลี่ยน",
      "tool_more": "ฟังก์ชัน\nเพิ่มเติม",
      "add_activity_title": "เพิ่มกิจกรรมในแผน",
      "venue_label": "สถานที่",
      "activity_label": "ชื่อกิจกรรม",
      "save_btn": "บันทึก",
      "cancel_btn": "ยกเลิก",
      "sos_tab_label": "ฉุกเฉิน",
    },
    "Vietnamese": {
      "greeting_morning": "Chào buổi sáng, {name}!",
      "greeting_afternoon": "Chào buổi chiều, {name}!",
      "greeting_evening": "Chào buổi tối, {name}!",
      "guest_default": "Leslie",
      "action_translate": "Dịch thuật\n& Ống kính",
      "action_bargain": "Trợ lý\nTrả giá",
      "action_ar": "Radar\nAR",
      "action_passport": "Con dấu\nHộ chiếu",
      "no_activities": "Không có hoạt động sắp tới",
      "scheduled_plans": "kế hoạch dự kiến hôm nay",
      "add_plans_sub": "Thêm lịch trình, vé hoặc ghi chú của bạn.",
      "add_activity_btn": "+ Thêm hoạt động",
      "emergency_header": "Đường dây nóng Khẩn cấp",
      "emergency_sub": "Danh bạ cứu trợ và hỗ trợ khẩn cấp",
      "hospital": "Bệnh viện",
      "police": "Đồn Cảnh sát",
      "fire_station": "Trạm Cứu hỏa",
      "chemist": "Hiệu thuốc 24h",
      "explore_tools": "Khám phá & Tiện ích",
      "tool_destination": "Khám phá\nĐiểm đến",
      "tool_railway": "Giao thông\nĐường sắt",
      "tool_chat": "Trò chuyện\nHướng dẫn viên",
      "tool_vault": "Két sắt\nGia đình",
      "tool_gems": "Địa điểm\nĐộc đáo",
      "tool_scanner": "Máy quét\nTài liệu",
      "tool_converter": "Quy đổi\nNgoại tệ",
      "tool_more": "Tính năng\nKhác",
      "add_activity_title": "Thêm lịch trình mới",
      "venue_label": "Địa điểm / Vị trí",
      "activity_label": "Tên hoạt động",
      "save_btn": "Lưu hoạt động",
      "cancel_btn": "Hủy",
      "sos_tab_label": "SOS",
    },
    "Indonesian": {
      "greeting_morning": "Selamat Pagi, {name}!",
      "greeting_afternoon": "Selamat Siang, {name}!",
      "greeting_evening": "Selamat Malam, {name}!",
      "guest_default": "Leslie",
      "action_translate": "Terjemahan\n& Lensa",
      "action_bargain": "Asisten\nTawar Harga",
      "action_ar": "Radar\nAR",
      "action_passport": "Stempel\nPaspor",
      "no_activities": "Tidak ada kegiatan mendatang",
      "scheduled_plans": "rencana terjadwal hari ini",
      "add_plans_sub": "Tambahkan tiket, tur, atau catatan perjalanan.",
      "add_activity_btn": "+ Tambah Rencana",
      "emergency_header": "Saluran Darurat",
      "emergency_sub": "Direktori bantuan dan tanggap darurat lokal",
      "hospital": "Rumah Sakit",
      "police": "Kantor Polisi",
      "fire_station": "Pemadam Kebakaran",
      "chemist": "Apotek 24 Jam",
      "explore_tools": "Jelajah & Alat",
      "tool_destination": "Pencari\nDestinasi",
      "tool_railway": "Transportasi\nKereta",
      "tool_chat": "Obrolan\nPemandu",
      "tool_vault": "Brankas\nKeluarga",
      "tool_gems": "Wisata\nLokal",
      "tool_scanner": "Pemindai\nDokumen",
      "tool_converter": "Konversi\nMata Uang",
      "tool_more": "Fitur\nLainnya",
      "add_activity_title": "Tambah Rencana Kegiatan",
      "venue_label": "Lokasi / Tempat",
      "activity_label": "Judul Kegiatan",
      "save_btn": "Simpan",
      "cancel_btn": "Batal",
      "sos_tab_label": "Darurat",
    },
  };

  String _t(String key) {
    final lang = widget.language.trim();
    if (_dict.containsKey(lang) && _dict[lang]!.containsKey(key)) {
      return _dict[lang]![key]!;
    }
    return _dict["English"]![key] ?? key;
  }

  static const List<String> _weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  static const List<String> _months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

  String _formatNativeDate(DateTime dt) {
    return "${_weekdays[dt.weekday - 1]}, ${dt.day} ${_months[dt.month - 1]}";
  }

  String _formatNativeTime(int hour, int minute) {
    final period = hour >= 12 ? "PM" : "AM";
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return "${h.toString().padLeft(2, '0')}:$m $period";
  }

  final Map<String, Map<String, dynamic>> _cityThemes = {
    "vasai-virar": {
      "name": "Vasai-Virar",
      "state": "Maharashtra",
      "country": "India",
      "image": "assets/images/dashboard_fort.png",
      "fallback_image": "https://images.unsplash.com/photo-1590050752117-238cb0fb12b1?auto=format&fit=crop&w=1200&q=80",
      "lat": 19.47,
      "lon": 72.80,
    },
    "mumbai": {
      "name": "Mumbai",
      "state": "Maharashtra",
      "country": "India",
      "image": "https://images.unsplash.com/photo-1570168007204-dfb528c6958f?auto=format&fit=crop&w=1200&q=80",
      "fallback_image": "https://images.unsplash.com/photo-1570168007204-dfb528c6958f?auto=format&fit=crop&w=1200&q=80",
      "lat": 18.92,
      "lon": 72.83,
    },
    "goa": {
      "name": "Goa",
      "state": "Goa",
      "country": "India",
      "image": "https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=1200&q=80",
      "fallback_image": "https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=1200&q=80",
      "lat": 15.29,
      "lon": 74.12,
    },
    "palghar": {
      "name": "Palghar",
      "state": "Maharashtra",
      "country": "India",
      "image": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80",
      "fallback_image": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80",
      "lat": 19.69,
      "lon": 72.76,
    },
  };

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
    _loadState();
    _checkLocationAndStamps();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentClock = DateTime.now();
          _isNight = _currentClock.hour >= 19 || _currentClock.hour < 6;
        });
        if (_currentClock.second == 0 && _currentClock.minute % 15 == 0) {
          _fetchLiveWeather();
          _checkLocationAndStamps();
        }
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final supaUser = Supabase.instance.client.auth.currentUser;
      final isGuest = supaUser != null ? false : (prefs.getBool('omni_is_guest_mode') ?? false);

      Map<String, dynamic> user = {};
      Map<String, dynamic> trip = {};
      List<TripExpense> expenses = [];

      try {
        user = await TripStateService.getUserProfile().timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        user = {"name": "Leslie", "email": "barleslie@gmail.com"};
      }

      try {
        trip = await TripStateService.getActiveTrip().timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        trip = {
          "destination": {"city": "Vasai-Virar", "state": "Maharashtra", "country": "India"},
          "today_itinerary": []
        };
      }

      try {
        expenses = await ExpenseService.loadExpenses().timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        expenses = [];
      }

      final now = DateTime.now();
      final double todaySum = expenses
          .where((e) => e.createdAt.year == now.year && e.createdAt.month == now.month && e.createdAt.day == now.day)
          .fold(0.0, (acc, cur) => acc + cur.amountLocal);

      if (mounted) {
        setState(() {
          _user = user;
          _trip = trip;
          _isGuest = isGuest;
          _recentExpenses = expenses.take(3).toList();
          _todaySpendSum = todaySum;
          _isNight = _currentClock.hour >= 19 || _currentClock.hour < 6;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _user = {"name": "Leslie", "email": "barleslie@gmail.com"};
          _trip = {
            "destination": {"city": "Vasai-Virar", "state": "Maharashtra", "country": "India"},
            "today_itinerary": []
          };
          _recentExpenses = [];
          _todaySpendSum = 0.0;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _fetchLiveWeather();
      }
    }
  }

  Future<void> _checkLocationAndStamps() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.denied ||
          hasPermission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );

      if (mounted) setState(() => _lastKnownPosition = pos);

      final unlocked = await PassportService.evaluateProximity(pos);
      if (unlocked != null && mounted) {
        _showCelebrationModal(unlocked);
      }
    } catch (_) {}
  }

  void _showCelebrationModal(PassportStamp stamp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(stamp.colorHex).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.stars_rounded, size: 54, color: Color(stamp.colorHex)),
            ),
            const SizedBox(height: 14),
            const Text(
              "🎉 Passport Stamp Unlocked!",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              "You arrived at ${stamp.name} in ${stamp.city}.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                stamp.title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(stamp.colorHex)),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(stamp.colorHex),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openPassportModal(context);
                },
                child: const Text("View in Stamp Book", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getResolvedDisplayName() {
    try {
      final supaUser = Supabase.instance.client.auth.currentUser;
      if (supaUser != null) {
        final meta = supaUser.userMetadata;
        if (meta != null) {
          final String? fullName = meta['full_name']?.toString() ?? meta['name']?.toString();
          if (fullName != null && fullName.trim().isNotEmpty) {
            return fullName.trim().split(' ').first;
          }
        }
        if (supaUser.email != null && supaUser.email!.contains('@')) {
          final emailPrefix = supaUser.email!.split('@').first;
          if (emailPrefix.isNotEmpty) {
            return emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
          }
        }
      }
    } catch (_) {}

    if (_isGuest) return _t("guest_default");

    if (_user["name"] != null && _user["name"].toString().trim().isNotEmpty) {
      return _user["name"].toString().trim().split(' ').first;
    }
    if (_user["full_name"] != null && _user["full_name"].toString().trim().isNotEmpty) {
      return _user["full_name"].toString().trim().split(' ').first;
    }

    return "Leslie";
  }

  String _getGreeting() {
    final hour = _currentClock.hour;
    final name = _getResolvedDisplayName();
    String rawTemplate;
    if (hour < 12) {
      rawTemplate = _t("greeting_morning");
    } else if (hour < 17) {
      rawTemplate = _t("greeting_afternoon");
    } else {
      rawTemplate = _t("greeting_evening");
    }
    return rawTemplate.replaceAll("{name}", name);
  }

  Future<void> _fetchLiveWeather() async {
    if (_isFetchingWeather) return;
    _isFetchingWeather = true;

    try {
      final dest = _trip["destination"] ?? {};
      final String currentCityRaw = (dest["city"] ?? "Vasai-Virar").toString();
      final cityTheme = _cityThemes[currentCityRaw.toLowerCase()] ?? _cityThemes["vasai-virar"]!;

      final double lat = (cityTheme["lat"] as num?)?.toDouble() ?? 19.47;
      final double lon = (cityTheme["lon"] as num?)?.toDouble() ?? 72.80;

      final url = Uri.parse("https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m");
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data["current"] != null && data["current"]["temperature_2m"] != null) {
          final tempVal = (data["current"]["temperature_2m"] as num).round();
          if (mounted) setState(() => _liveTemperature = "$tempVal°C");
        }
      }
    } catch (_) {
      if (_liveTemperature == "--°C") setState(() => _liveTemperature = "29°C");
    } finally {
      if (mounted) setState(() => _isFetchingWeather = false);
    }
  }

  Future<void> _callNumber(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse("tel:$clean");
    try {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _navigateToLocation(double lat, double lng, String label) async {
    final cleanLabel = Uri.encodeComponent(label);
    final googleMapsUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$cleanLabel&travelmode=walking");

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        final fallbackUrl = Uri.parse("geo:$lat,$lng?q=$lat,$lng($cleanLabel)");
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to launch map navigation: $e")),
        );
      }
    }
  }

  Map<String, Map<String, String>> _getActiveLifelines() {
    final city = (_trip["destination"]?["city"] ?? "Vasai-Virar").toString().toLowerCase();

    if (city.contains("palghar")) {
      return {
        "hospital": {"title": _t("hospital"), "phone": "02525-252244", "sub": "Palghar Rural District General Hospital"},
        "police": {"title": _t("police"), "phone": "02525-251100", "sub": "Palghar Town Police Station"},
        "fire": {"title": _t("fire_station"), "phone": "08805915101", "sub": "Palghar Municipal Fire Brigade"},
        "pharmacy": {"title": _t("chemist"), "phone": "02525-254300", "sub": "Sanjivani 24x7 Emergency Medical"},
        "ambulance": {"title": "Ambulance (108)", "phone": "09850674169", "sub": "24h Rural Cardiac Ambulance Fleet"},
        "women": {"title": "Women Helpline", "phone": "1091", "sub": "Palghar Police Women Protection Cell"},
      };
    }

    return {
      "hospital": {"title": _t("hospital"), "phone": "0250-2324200", "sub": "Cardinal Gracias Memorial Hospital"},
      "police": {"title": _t("police"), "phone": "0250-2327011", "sub": "Manikpur / Vasai Police Station"},
      "fire": {"title": _t("fire_station"), "phone": "0250-2334258", "sub": "VVCMC Fire Control (Navghar)"},
      "pharmacy": {"title": _t("chemist"), "phone": "07428094028", "sub": "Ozone 24 Hrs Emergency Pharmacy"},
      "ambulance": {"title": "Ambulance (108)", "phone": "07350632424", "sub": "24h ICU Ambulance Fleet"},
      "women": {"title": "Women Cell", "phone": "1091", "sub": "MBVV Police Women Safety Cell"},
    };
  }

  void _showAllLifelinesModal(BuildContext context, String cityName, Map<String, Map<String, String>> lifelines) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFDC2626).withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("$cityName ${_t("emergency_header")}", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        Text(_t("emergency_sub"), style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
                children: [
                  _buildModalRow(Icons.local_hospital_rounded, const Color(0xFFE11D48), _t("hospital"), lifelines["hospital"]!),
                  const SizedBox(height: 14),
                  _buildModalRow(Icons.local_police_rounded, const Color(0xFF0284C7), _t("police"), lifelines["police"]!),
                  const SizedBox(height: 14),
                  _buildModalRow(Icons.fire_truck_rounded, const Color(0xFFEA580C), _t("fire_station"), lifelines["fire"]!),
                  const SizedBox(height: 14),
                  _buildModalRow(Icons.medication_rounded, const Color(0xFF059669), _t("chemist"), lifelines["pharmacy"]!),
                  const SizedBox(height: 14),
                  _buildModalRow(Icons.airport_shuttle_rounded, const Color(0xFF991B1B), "Ambulance", lifelines["ambulance"]!),
                  const SizedBox(height: 14),
                  _buildModalRow(Icons.security_rounded, const Color(0xFF9333EA), "Women Safety Helpline", lifelines["women"]!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalRow(IconData icon, Color color, String label, Map<String, String> data) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              Text(data["sub"] ?? data["title"]!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _callNumber(data["phone"]!),
          icon: const Icon(Icons.call_rounded, size: 14),
          label: Text(data["phone"]!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildHeroBackdrop(String assetPath, String fallbackUrl) {
    if (assetPath.startsWith("assets/")) {
      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.network(fallbackUrl, fit: BoxFit.cover),
      );
    }
    return Image.network(assetPath, fit: BoxFit.cover);
  }

  void _openBargainPalModal(BuildContext context) {
    final itemCtrl = TextEditingController(text: "Handmade Souvenir");
    final priceCtrl = TextEditingController(text: "500");
    String selectedCurrency = "INR";
    Map<String, dynamic>? evaluationResult;
    bool isEvaluating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          final systemNavPadding = MediaQuery.of(ctx).padding.bottom;

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, bottomInset > 0 ? bottomInset + 16 : systemNavPadding + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
                            child: const Icon(Icons.price_check_rounded, color: Color(0xFFD97706), size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Text("Bargain Pal • Street Haggler", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: itemCtrl,
                          decoration: InputDecoration(
                            labelText: "Item Name",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: "Price (₹)",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isEvaluating
                          ? null
                          : () async {
                              setModalState(() => isEvaluating = true);
                              try {
                                final cleanUrl = widget.backendUrl.replaceAll(RegExp(r'/+$'), '');
                                final res = await http.post(
                                  Uri.parse("$cleanUrl/api/v1/bargain-evaluate"),
                                  headers: {"Content-Type": "application/json"},
                                  body: jsonEncode({
                                    "item_name": itemCtrl.text,
                                    "quoted_price": double.tryParse(priceCtrl.text) ?? 100.0,
                                    "currency": selectedCurrency,
                                    "city": _trip["destination"]?["city"] ?? "Vasai-Virar",
                                    "target_language": widget.language,
                                  }),
                                ).timeout(const Duration(seconds: 12));

                                if (res.statusCode == 200) {
                                  final d = jsonDecode(res.body);
                                  if (d["status"] == "success") {
                                    setModalState(() => evaluationResult = d["data"]);
                                  }
                                }
                              } catch (_) {}
                              setModalState(() => isEvaluating = false);
                            },
                      icon: isEvaluating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.analytics_rounded, size: 20),
                      label: Text(
                        isEvaluating ? "Checking Local Rates..." : "Evaluate Price Sanity",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                    ),
                  ),
                  if (evaluationResult != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "VERDICT: ${evaluationResult!['verdict'] ?? 'Evaluation Complete'}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: evaluationResult!['rating_color'] == "green"
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                              Text("Fair: ₹${evaluationResult!['estimated_fair_price'] ?? '—'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(evaluationResult!['advice'] ?? "", style: const TextStyle(fontSize: 12.5, color: Color(0xFF451A03))),
                          const Divider(height: 16, color: Color(0xFFFDE68A)),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "\"${evaluationResult!['polite_counter_phrase'] ?? ''}\"",
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      evaluationResult!['phonetic'] ?? evaluationResult!['phrase_translation'] ?? "",
                                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.volume_up_rounded, color: Color(0xFFD97706)),
                                onPressed: () async {
                                  await _flutterTts.stop();
                                  await _flutterTts.speak(evaluationResult!['polite_counter_phrase'] ?? "");
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openArRadarModal(BuildContext context) {
    final dest = _trip["destination"] ?? {};
    final String currentCityRaw = (dest["city"] ?? "Vasai-Virar").toString().toLowerCase();

    List<Map<String, dynamic>> landmarks;
    if (currentCityRaw.contains("mumbai")) {
      landmarks = [
        {"name": "Gateway of India", "dist": "Colaba Waterfront • Tap to Navigate", "lat": 18.9220, "lng": 72.8347, "color": const Color(0xFF38BDF8), "icon": Icons.fort_rounded},
        {"name": "Chhatrapati Shivaji Terminus (CSMT)", "dist": "Heritage Junction • Transit", "lat": 18.9400, "lng": 72.8354, "color": const Color(0xFF4ADE80), "icon": Icons.train_rounded},
        {"name": "Marine Drive Promenade", "dist": "Queen's Necklace • Scenic Walk", "lat": 18.9432, "lng": 72.8230, "color": const Color(0xFFFBBF24), "icon": Icons.beach_access_rounded},
      ];
    } else {
      landmarks = [
        {"name": "Bassein Fort (Fort Vasai)", "dist": "650m Ahead • Tap to Walk", "lat": 19.3308, "lng": 72.8149, "color": const Color(0xFF38BDF8), "icon": Icons.fort_rounded},
        {"name": "Vasai Road Railway Station", "dist": "1.2km North-East • Transit Hub", "lat": 19.3807, "lng": 72.8322, "color": const Color(0xFF4ADE80), "icon": Icons.train_rounded},
        {"name": "Suruchi Casuarina Beach", "dist": "2.4km West • Coastal Shoreline", "lat": 19.3496, "lng": 72.7842, "color": const Color(0xFFFBBF24), "icon": Icons.beach_access_rounded},
      ];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.84,
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: const Center(child: Icon(Icons.explore_rounded, size: 84, color: Colors.white10)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.radar_rounded, color: Color(0xFF38BDF8), size: 24),
                          SizedBox(width: 8),
                          Text("AR Landmark Radar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Text("Tap any floating badge to launch turn-by-turn walking route", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  const SizedBox(height: 32),
                  for (int i = 0; i < landmarks.length; i++) ...[
                    _buildFloatingArBadge(
                      landmarks[i]["name"],
                      landmarks[i]["dist"],
                      landmarks[i]["icon"],
                      landmarks[i]["color"],
                      (i * 45.0) + 16.0,
                      () {
                        Navigator.pop(ctx);
                        _navigateToLocation(landmarks[i]["lat"], landmarks[i]["lng"], landmarks[i]["name"]);
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.navigation_rounded, color: Color(0xFF38BDF8), size: 18),
                        SizedBox(width: 8),
                        Text("GPS Compass Online • Tap Any Badge to Navigate", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingArBadge(
    String name,
    String distance,
    IconData icon,
    Color color,
    double leftPadding,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.7), width: 1.5),
              boxShadow: [BoxShadow(color: color.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(distance, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Icon(Icons.directions_walk_rounded, color: color, size: 12),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPassportModal(BuildContext context) async {
    List<PassportStamp> stamps = await PassportService.getStamps(currentPosition: _lastKnownPosition);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          int unlockedCount = stamps.where((s) => s.isUnlocked).length;

          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.82,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 24),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Travel Passport & Stamps", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A))),
                              Text("$unlockedCount of ${stamps.length} Heritage Stamps Collected", style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      itemCount: stamps.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemBuilder: (context, i) {
                        final s = stamps[i];
                        final color = Color(s.colorHex);

                        String distLabel = "Locating distance...";
                        if (s.distanceMeters != null) {
                          if (s.distanceMeters! < 1000) {
                            distLabel = "${s.distanceMeters!.round()}m away";
                          } else {
                            distLabel = "${(s.distanceMeters! / 1000).toStringAsFixed(1)} km away";
                          }
                        }

                        return InkWell(
                          onTap: () {
                            if (!s.isUnlocked) {
                              _navigateToLocation(s.lat, s.lng, s.name);
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: s.isUnlocked ? color.withOpacity(0.05) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: s.isUnlocked ? color.withOpacity(0.4) : const Color(0xFFE2E8F0),
                                width: s.isUnlocked ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: s.isUnlocked ? color.withOpacity(0.12) : const Color(0xFFE2E8F0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    s.isUnlocked ? Icons.stars_rounded : Icons.lock_outline_rounded,
                                    color: s.isUnlocked ? color : const Color(0xFF94A3B8),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                    color: s.isUnlocked ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s.city,
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: s.isUnlocked ? color : const Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: s.isUnlocked ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    s.isUnlocked
                                        ? "Unlocked • ${_formatNativeDate(s.unlockedAt ?? DateTime.now())}"
                                        : "$distLabel • Tap to Walk",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: s.isUnlocked ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
  }

  void _showQuickAddSpendModal(BuildContext context) {
    HapticFeedback.selectionClick();
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String selectedCategory = 'Food & Dining';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, bottomPadding + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Quick Log Spend",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: "Amount (₹)",
                          prefixText: "₹ ",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: "What was it for?",
                          hintText: "e.g. Chai, Rickshaw",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final val = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (val > 0) {
                        HapticFeedback.mediumImpact();
                        final homeCurr = await ExpenseService.getHomeCurrency();
                        final newExpense = TripExpense(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleCtrl.text.trim().isEmpty ? selectedCategory : titleCtrl.text.trim(),
                          category: selectedCategory,
                          amountLocal: val,
                          currencyLocal: 'INR',
                          amountHome: ExpenseService.convertFromInr(val, homeCurr),
                          currencyHome: homeCurr,
                          paymentMethod: 'Cash',
                          splitCount: 1,
                          createdAt: DateTime.now(),
                        );
                        await ExpenseService.addExpense(newExpense);
                        Navigator.pop(ctx);
                        _loadState();
                      }
                    },
                    child: const Text("Record Spend", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    final dest = _trip["destination"] ?? {};
    final String currentCityRaw = (dest["city"] ?? "Vasai-Virar").toString();
    final cityTheme = _cityThemes[currentCityRaw.toLowerCase()] ?? _cityThemes["vasai-virar"]!;

    final String activeCity = cityTheme["name"]!;
    final String imagePath = cityTheme["image"]!;
    final String fallbackUrl = cityTheme["fallback_image"]!;

    final itinerary = List<Map<String, dynamic>>.from(_trip["today_itinerary"] ?? []);
    final lifelines = _getActiveLifelines();

    final dateString = _formatNativeDate(_currentClock);
    final timeString = _formatNativeTime(_currentClock.hour, _currentClock.minute);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await _loadState();
              await _fetchLiveWeather();
              await _checkLocationAndStamps();
            },
            color: const Color(0xFF2563EB),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: 40 + MediaQuery.of(context).padding.bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Banner
                  Container(
                    height: 220,
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(22),
                        bottomRight: Radius.circular(22),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(22),
                        bottomRight: Radius.circular(22),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildHeroBackdrop(imagePath, fallbackUrl),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withOpacity(0.05),
                                  Colors.black.withOpacity(0.35),
                                  Colors.black.withOpacity(0.92),
                                ],
                                stops: const [0.0, 0.40, 1.0],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  _travelMode == "Transit" ? "Live Transit Cockpit" : _getGreeting(),
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.40),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF93C5FD)),
                                          const SizedBox(width: 6),
                                          Text("$dateString • $timeString", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.16),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white24),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                                            size: 16,
                                            color: _isNight ? const Color(0xFF93C5FD) : const Color(0xFFFBBF24),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(_liveTemperature, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Mode Toggle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _travelMode = "Home"),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _travelMode == "Home" ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: _travelMode == "Home" ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))] : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.home_rounded, size: 14, color: _travelMode == "Home" ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text("Home Base", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _travelMode == "Home" ? const Color(0xFF0F172A) : const Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setState(() => _travelMode = "Transit"),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _travelMode == "Transit" ? const Color(0xFF2563EB) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: _travelMode == "Transit" ? [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 1))] : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.near_me_rounded, size: 14, color: _travelMode == "Transit" ? Colors.white : const Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text("On Transit", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: _travelMode == "Transit" ? Colors.white : const Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: const [
                            Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                            SizedBox(width: 4),
                            Text("Offline Sandboxed", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Flight & Stay Hub Shortcut (Route 14)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      onTap: () {
                        if (widget.onNavigateTab != null) {
                          widget.onNavigateTab!(14);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                              child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    "Search Flights & Stays",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                  ),
                                  Text(
                                    "Direct In-App Comparison • Fares in ₹ (INR)",
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Quick Action Tiles
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildTopActionTile(
                          icon: Icons.translate_rounded,
                          label: _t("action_translate"),
                          iconColor: const Color(0xFF2563EB),
                          onTap: () {
                            if (widget.onNavigateTab != null) widget.onNavigateTab!(4);
                          },
                        ),
                        const SizedBox(width: 10),
                        _buildTopActionTile(
                          icon: Icons.price_change_rounded,
                          label: _t("action_bargain"),
                          iconColor: const Color(0xFFD97706),
                          onTap: () => _openBargainPalModal(context),
                        ),
                        const SizedBox(width: 10),
                        _buildTopActionTile(
                          icon: Icons.radar_rounded,
                          label: _t("action_ar"),
                          iconColor: const Color(0xFF0284C7),
                          onTap: () => _openArRadarModal(context),
                        ),
                        const SizedBox(width: 10),
                        _buildTopActionTile(
                          icon: Icons.card_membership_rounded,
                          label: _t("action_passport"),
                          iconColor: const Color(0xFF9333EA),
                          onTap: () => _openPassportModal(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Today's Activity Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF16A34A), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  itinerary.isEmpty ? _t("no_activities") : "${itinerary.length} ${_t("scheduled_plans")}",
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 2),
                                Text(_t("add_plans_sub"), style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDBEAFE),
                              foregroundColor: const Color(0xFF2563EB),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _showAddActivityDialog(context),
                            child: Text(_t("add_activity_btn"), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (itinerary.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: itinerary.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final item = itinerary[index];
                            final completed = item["is_completed"] ?? false;
                            return ListTile(
                              leading: Checkbox(
                                activeColor: const Color(0xFF16A34A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                value: completed,
                                onChanged: (_) async {
                                  await TripStateService.toggleItineraryItem(item["id"]);
                                  _loadState();
                                },
                              ),
                              title: Text(
                                item["spot_title"] ?? "",
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  decoration: completed ? TextDecoration.lineThrough : null,
                                  color: completed ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Text(
                                "${item["time_slot"] ?? ""} • ${item["category"] ?? ""}",
                                style: TextStyle(fontSize: 11.5, color: completed ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Recent Expenses Tray
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 8),
                                  const Text("Recent Spends", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                  const SizedBox(width: 6),
                                  Text("(Today: ₹${_todaySpendSum.toStringAsFixed(0)})", style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                ],
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _showQuickAddSpendModal(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                                      child: Row(
                                        children: const [
                                          Icon(Icons.add_rounded, size: 14, color: Color(0xFF2563EB)),
                                          SizedBox(width: 2),
                                          Text("Add", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      if (widget.onNavigateTab != null) widget.onNavigateTab!(13);
                                    },
                                    child: const Text("View Ledger →", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _recentExpenses.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Text("No expenses logged yet. Tap '+ Add' to record one.", style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                                )
                              : Column(
                                  children: _recentExpenses.map((exp) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF64748B)),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    exp.title,
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text("₹${exp.amountLocal.toStringAsFixed(0)}", style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(_t("explore_tools"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  ),

                  const SizedBox(height: 12),

                  // 8-Tile Tools Directory Grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.82,
                      children: [
                        _buildToolGridTile(
                          icon: Icons.explore_rounded,
                          iconColor: const Color(0xFF2563EB),
                          bgTint: const Color(0xFFEFF6FF),
                          label: _t("tool_destination"),
                          onTap: () {
                            if (widget.onNavigateTab != null) widget.onNavigateTab!(2);
                          },
                        ),
                        _buildToolGridTile(
                          icon: Icons.train_rounded,
                          iconColor: const Color(0xFF059669),
                          bgTint: const Color(0xFFECFDF5),
                          label: _t("tool_railway"),
                          onTap: () {
                            if (widget.onNavigateTab != null) widget.onNavigateTab!(5);
                          },
                        ),
                        _buildToolGridTile(
                          icon: Icons.support_agent_rounded,
                          iconColor: const Color(0xFF9333EA),
                          bgTint: const Color(0xFFFAF5FF),
                          label: _t("tool_chat"),
                          onTap: () {
                            if (widget.onNavigateTab != null) widget.onNavigateTab!(3);
                          },
                        ),
                        _buildToolGridTile(
                          icon: Icons.folder_special_rounded,
                          iconColor: const Color(0xFFEA580C),
                          bgTint: const Color(0xFFFFF7ED),
                          label: _t("tool_vault"),
                          onTap: () {
                            if (widget.onNavigateTab != null) widget.onNavigateTab!(6);
                          },
                        ),
                        _buildToolGridTile(
                          icon: Icons.star_rounded,
                          iconColor: const Color(0xFFE11D48),
                          bgTint: const Color(0xFFFFF1F2),
                          label: _t("tool_gems"),
                          onTap: () {
                            if (widget.onNavigateTab != null) widget.onNavigateTab!(7);
                          },
                        ),
                        _buildToolGridTile(
                          icon: Icons.document_scanner_rounded,
                          iconColor: const Color(0xFF0D9488),
                          bgTint: const Color(0xFFF0FDFA),
                          label: _t("tool_scanner"),
                          onTap: () {
                            if (widget.onNavigateTab != null) widget.onNavigateTab!(1);
                          },
                        ),
                        _buildToolGridTile(
                          icon: Icons.currency_exchange_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          bgTint: const Color(0xFFF5F3FF),
                          label: _t("tool_converter"),
                          onTap: () {
                            if (widget.onNavigateTab != null) widget.onNavigateTab!(8);
                          },
                        ),
                        _buildToolGridTile(
                          icon: Icons.grid_view_rounded,
                          iconColor: const Color(0xFF475569),
                          bgTint: const Color(0xFFF8FAFC),
                          label: _t("tool_more"),
                          onTap: () {
                            Scaffold.of(context).openDrawer();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Edge-Docked SOS Tab
          Positioned(
            right: -2,
            top: MediaQuery.of(context).size.height * 0.44,
            child: GestureDetector(
              onTap: () => _showAllLifelinesModal(context, activeCity, lifelines),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(-2, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                    SizedBox(height: 4),
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        "SOS",
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionTile({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B), height: 1.15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolGridTile({
    required IconData icon,
    required Color iconColor,
    required Color bgTint,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bgTint, shape: BoxShape.circle), child: Icon(icon, size: 20, color: iconColor)),
            const SizedBox(height: 5),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF334155), height: 1.15)),
          ],
        ),
      ),
    );
  }

  void _showAddActivityDialog(BuildContext context) {
    final titleController = TextEditingController();
    final venueController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final dateStr = _formatNativeDate(selectedDate);
          final timeStr = _formatNativeTime(selectedTime.hour, selectedTime.minute);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(_t("add_activity_title"), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: _t("activity_label"),
                      hintText: "e.g. Bassein Fort Tour",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: venueController,
                    decoration: InputDecoration(
                      labelText: _t("venue_label"),
                      hintText: "e.g. Vasai West Coastal Gate",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text("Date", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setModalState(() => selectedDate = picked);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(width: 10),
                          Text(dateStr, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("Time", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final pickedTime = await showTimePicker(context: context, initialTime: selectedTime);
                      if (pickedTime != null) setModalState(() => selectedTime = pickedTime);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF2563EB)),
                          const SizedBox(width: 10),
                          Text(timeStr, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(_t("cancel_btn"))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  if (titleController.text.trim().isNotEmpty) {
                    final combinedDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                    final venueText = venueController.text.trim().isNotEmpty ? " @ ${venueController.text.trim()}" : "";
                    final displayLabel = "$dateStr at $timeStr$venueText";
                    await TripStateService.addItineraryItem(titleController.text.trim(), "Planned Schedule", displayLabel, scheduledDateTime: combinedDateTime);
                    Navigator.pop(ctx);
                    _loadState();
                  }
                },
                child: Text(_t("save_btn")),
              ),
            ],
          );
        },
      ),
    );
  }
}