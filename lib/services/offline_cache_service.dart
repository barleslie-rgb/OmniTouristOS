import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class SurvivalPhrase {
  final String category;
  final String english;
  final Map<String, String> translations;
  final Map<String, String> phonetics;

  const SurvivalPhrase({
    required this.category,
    required this.english,
    required this.translations,
    this.phonetics = const {},
  });

  String getTranslation(String lang) {
    if (translations.containsKey(lang)) return translations[lang]!;
    return english;
  }

  String? getPhonetic(String lang) {
    return phonetics[lang];
  }
}

class OfflineCacheService {
  static const String _dossierPrefix = "omni_offline_dossier_";
  static const String _emergencyPrefix = "omni_offline_sos_";
  static const String _packedCitiesKey = "omni_packed_cities_list";

  // -------------------------------------------------------------
  // 1. "PACK MY CITY" 1-TAP COMPLETE OFFLINE PRE-DOWNLOAD
  // -------------------------------------------------------------
  static Future<bool> packCityForOffline({
    required String city,
    required String state,
    required String country,
    required String backendUrl,
    required String language,
  }) async {
    final cleanCity = city.trim();
    try {
      final cleanUrl = backendUrl.replaceAll(RegExp(r'/+$'), '');

      // 1. Fetch & cache destination guide
      final guideUri = Uri.parse(
        "$cleanUrl/api/v1/explore-city?city=${Uri.encodeComponent(cleanCity)}&state=${Uri.encodeComponent(state)}&country=${Uri.encodeComponent(country)}&target_language=${Uri.encodeComponent(language)}",
      );
      final res = await http.get(guideUri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await saveCityDossier(cleanCity, data);
      }

      // 2. Fetch & cache verified local community gems
      await SupabaseService.getPlacesForCity(cleanCity);

      // 3. Mark city as successfully packed
      final prefs = await SharedPreferences.getInstance();
      final List<String> packed = prefs.getStringList(_packedCitiesKey) ?? [];
      if (!packed.contains(cleanCity.toLowerCase())) {
        packed.add(cleanCity.toLowerCase());
        await prefs.setStringList(_packedCitiesKey, packed);
      }
      return true;
    } catch (e) {
      debugPrint("Pack city error: $e");
      return false;
    }
  }

  static Future<bool> isCityPacked(String city) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> packed = prefs.getStringList(_packedCitiesKey) ?? [];
    return packed.contains(city.trim().toLowerCase());
  }

  // -------------------------------------------------------------
  // 2. CITY DOSSIER OFFLINE CACHING
  // -------------------------------------------------------------
  static Future<void> saveCityDossier(String city, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = "$_dossierPrefix${city.toLowerCase().trim()}";
      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      debugPrint("Offline dossier save notice: $e");
    }
  }

  static Future<Map<String, dynamic>?> getCachedCityDossier(String city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = "$_dossierPrefix${city.toLowerCase().trim()}";
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Offline dossier read notice: $e");
    }
    return null;
  }

  // -------------------------------------------------------------
  // 3. GUARANTEED EMERGENCY LIFELINE PERSISTENCE
  // -------------------------------------------------------------
  static Future<void> saveEmergencyDirectory(String city, Map<String, dynamic> directory) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = "$_emergencyPrefix${city.toLowerCase().trim()}";
      await prefs.setString(key, jsonEncode(directory));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getEmergencyDirectory(String city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = "$_emergencyPrefix${city.toLowerCase().trim()}";
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        return jsonDecode(raw) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // -------------------------------------------------------------
  // 4. MULTI-LANGUAGE OFFLINE SURVIVAL DICTIONARY
  // -------------------------------------------------------------
  static const List<SurvivalPhrase> survivalPhrases = [
    SurvivalPhrase(
      category: "Emergency & Medical",
      english: "I need an ambulance immediately!",
      translations: {
        "Hindi": "मुझे तुरंत एक एम्बुलेंस चाहिए!",
        "Marathi": "मला लगेच रुग्णवाहिका हवी आहे!",
        "Spanish": "¡Necesito una ambulancia de inmediato!",
        "French": "J'ai besoin d'une ambulance immédiatement !",
        "German": "Ich brauche sofort einen Krankenwagen!",
        "Italian": "Ho bisogno di un'ambulanza immediatamente!",
        "Portuguese": "Preciso de uma ambulância imediatamente!",
        "Russian": "Мне срочно нужна скорая помощь!",
        "Arabic": "أحتاج إلى سيارة إسعاف فوراً!",
        "Chinese": "我需要立即叫救护车！",
        "Japanese": "救急車をすぐに呼んでください！",
        "Tamil": "எனக்கு உடனடியாக ஆம்புலன்ஸ் வேண்டும்!",
        "Gujarati": "મને તરત જ એમ્બ્યુલન્સની જરૂર છે!",
      },
      phonetics: {
        "Hindi": "Mujhe turant ek ambulance chahiye!",
        "Marathi": "Mala lagech rugnavahika havi aahe!",
        "Russian": "Mne srochno nuzhna skoraya pomoshch!",
        "Arabic": "Ahtaju ila sayyarat is'af fawran!",
        "Chinese": "Wǒ xūyào lìjí jiào jiùhùchē!",
        "Japanese": "Kyuukyuusha o sugu ni yonde kudasai!",
        "Tamil": "Enakku udanadiyaga ambulance vendum!",
        "Gujarati": "Mane tarat ja ambulance ni jaroor chhe!",
      },
    ),
    SurvivalPhrase(
      category: "Emergency & Medical",
      english: "Where is the nearest hospital?",
      translations: {
        "Hindi": "सबसे नजदीकी अस्पताल कहां है?",
        "Marathi": "जवळचे रुग्णालय कुठे आहे?",
        "Spanish": "¿Dónde está el hospital más cercano?",
        "French": "Où se trouve l'hôpital le plus proche ?",
        "German": "Wo ist das nächste Krankenhaus?",
        "Italian": "Dov'è l'ospedale più vicino?",
        "Portuguese": "Onde fica o hospital mais próximo?",
        "Russian": "Где находится ближайшая больница?",
        "Arabic": "أين يقع أقرب مستشفى؟",
        "Chinese": "最近的医院在哪里？",
        "Japanese": "一番近い病院はどこですか？",
        "Tamil": "அருகிலுள்ள மருத்துவமனை எங்கே உள்ளது?",
        "Gujarati": "સૌથી નજીકની હોસ્પિટલ ક્યાં છે?",
      },
      phonetics: {
        "Hindi": "Sabse nazdeeki aspataal kahan hai?",
        "Marathi": "Javalche rugnalay kuthe aahe?",
        "Russian": "Gde nakhoditsya blizhayshaya bol'nitsa?",
        "Arabic": "Ayna yaqa'u aqrabu mustashfa?",
        "Chinese": "Zuìjìn de yīyuàn zài nǎlǐ?",
        "Japanese": "Ichiban chikai byouin wa doko desu ka?",
        "Tamil": "Arugilulla maruthuvamanai enge ullathu?",
        "Gujarati": "Sauthi najik ni hospital kya chhe?",
      },
    ),
    SurvivalPhrase(
      category: "Emergency & Medical",
      english: "Please call the police right now!",
      translations: {
        "Hindi": "कृपया तुरंत पुलिस को बुलाएं!",
        "Marathi": "कृपया ताबडतोब पोलिसांना बोलवा!",
        "Spanish": "¡Por favor llame a la policía ahora mismo!",
        "French": "Appelez la police tout de suite s'il vous plaît !",
        "German": "Bitte rufen Sie sofort die Polizei!",
        "Italian": "Per favore chiamate subito la polizia!",
        "Portuguese": "Por favor, chame a polícia agora mesmo!",
        "Russian": "Пожалуйста, вызовите полицию прямо сейчас!",
        "Arabic": "يرجى الاتصال بالشرطة الآن!",
        "Chinese": "请立刻报警！",
        "Japanese": "今すぐ警察を呼んでください！",
        "Tamil": "தயவுசெய்து உடனே போலீஸை அழையுங்கள்!",
        "Gujarati": "કૃપા કરીને તરત જ પોલીસને બોલાવો!",
      },
      phonetics: {
        "Hindi": "Kripya turant police ko bulayein!",
        "Marathi": "Krupaya tabadtob polisanna bolva!",
        "Russian": "Pozhaluysta, vyzovite politsiyu pryamo seychas!",
        "Arabic": "Yurja al-ittisal bi-l-shurtah al-an!",
        "Chinese": "Qǐng lìkè bàojǐng!",
        "Japanese": "Ima sugu keisatsu o yonde kudasai!",
        "Tamil": "Thayavuseithu udane police-ai azhaiyungal!",
        "Gujarati": "Krupa karine tarat ja police ne bolavo!",
      },
    ),
    SurvivalPhrase(
      category: "Emergency & Medical",
      english: "I am feeling very dizzy and sick.",
      translations: {
        "Hindi": "मुझे बहुत चक्कर और बीमारी महसूस हो रही है।",
        "Marathi": "मला खूप चक्कर येत आहे आणि अस्वस्थ वाटत आहे.",
        "Spanish": "Me siento muy mareado y enfermo.",
        "French": "Je me sens très étourdi et malade.",
        "German": "Mir ist sehr schwindelig und übel.",
        "Italian": "Mi sento molto stordito e malato.",
        "Portuguese": "Estou me sentindo muito tonto e doente.",
        "Russian": "У меня кружится голова, мне плохо.",
        "Arabic": "أشعر بدوار شديد ووعكة صحية.",
        "Chinese": "我觉得很头晕，身体不舒服。",
        "Japanese": "めまいがして気分がとても悪いです。",
        "Tamil": "எனக்கு மயக்கமாகவும் உடம்பு சரியில்லாமலும் இருக்கிறது.",
        "Gujarati": "મને ખૂબ ચક્કર આવી રહ્યા છે અને તબિયત ખરાબ લાગે છે.",
      },
      phonetics: {
        "Hindi": "Mujhe bahut chakkar aur bimari mehsoos ho rahi hai.",
        "Marathi": "Mala khoop chakkar yet aahe aani aswasth vaatat aahe.",
        "Russian": "U menya kruzhitsya golova, mne plokho.",
        "Arabic": "Ash'uru bi-duwarin shadeed wa wa'katin sihhiyyah.",
        "Chinese": "Wǒ juéde hěn tóuyūn, shēntǐ bù shūfu.",
        "Japanese": "Memai ga shite kibun ga totemo warui desu.",
        "Tamil": "Enakku mayakkamaga irukkirathu.",
        "Gujarati": "Mane khoob chakkar aavi rahya chhe.",
      },
    ),
    SurvivalPhrase(
      category: "Emergency & Medical",
      english: "Where is a 24-hour medical shop / pharmacy?",
      translations: {
        "Hindi": "२४ घंटे खुली रहने वाली दवाई की दुकान कहां है?",
        "Marathi": "२४ तास चालू असलेले मेडिकल कुठे आहे?",
        "Spanish": "¿Dónde hay una farmacia abierta las 24 horas?",
        "French": "Où y a-t-il une pharmacie ouverte 24h/24 ?",
        "German": "Wo gibt es eine 24-Stunden-Apotheke?",
        "Italian": "Dov'è una farmacia aperta 24 ore su 24?",
        "Portuguese": "Onde há uma farmácia 24 horas?",
        "Russian": "Где круглосуточная аптека?",
        "Arabic": "أين توجد صيدلية تعمل على مدار 24 ساعة؟",
        "Chinese": "哪里有24小时营业的药店？",
        "Japanese": "24時間営業の薬局はどこですか？",
        "Tamil": "24 மணி நேர மருந்தகம் எங்குள்ளது?",
        "Gujarati": "૨૪ કલાક ખુલ્લી રહેતી દવાની દુકાન ક્યાં છે?",
      },
      phonetics: {
        "Hindi": "Chauvees ghante khuli rehne wali dawai ki dukaan kahan hai?",
        "Marathi": "Chovvis taas chaalu aslele medical kuthe aahe?",
        "Russian": "Gde kruglosutochnaya apteka?",
        "Arabic": "Ayna tojad saydaliyya ta'mal 24 sa'ah?",
        "Chinese": "Nǎlǐ yǒu èrshísì xiǎoshí yíngyè de yàodiàn?",
        "Japanese": "Nijuuyon jikan eigyou no yakkyoku wa doko desu ka?",
        "Tamil": "Irupathunaangu mani nera marunthagam engullathu?",
        "Gujarati": "Chovis kalak khulli rehti dava ni dukan kya chhe?",
      },
    ),
    SurvivalPhrase(
      category: "Transit & Directions",
      english: "Where is the railway station?",
      translations: {
        "Hindi": "रेलवे स्टेशन किस तरफ है?",
        "Marathi": "रेल्वे स्टेशन कोणत्या बाजूला आहे?",
        "Spanish": "¿Dónde está la estación de tren?",
        "French": "Où est la gare ferroviaire ?",
        "German": "Wo ist der Bahnhof?",
        "Italian": "Dov'è la stazione ferroviaria?",
        "Portuguese": "Onde fica a estação de trem?",
        "Russian": "Где находится железнодорожный вокзал?",
        "Arabic": "أين محطة القطار؟",
        "Chinese": "火车站往哪边走？",
        "Japanese": "駅はどちらの方向ですか？",
        "Tamil": "ரயில் நிலையம் எங்கே உள்ளது?",
        "Gujarati": "રેલ્વે સ્ટેશન કઈ તરફ છે?",
      },
      phonetics: {
        "Hindi": "Railway station kis taraf hai?",
        "Marathi": "Railway station konthya baajula aahe?",
        "Russian": "Gde nakhoditsya zheleznodorozhnyy vokzal?",
        "Arabic": "Ayna mahattat al-qitar?",
        "Chinese": "Huǒchēzhàn wǎng nǎbiān zǒu?",
        "Japanese": "Eki wa dochira no houkou desu ka?",
        "Tamil": "Railway station enge ullathu?",
        "Gujarati": "Railway station kai taraf chhe?",
      },
    ),
    SurvivalPhrase(
      category: "Transit & Directions",
      english: "Please turn on the taxi meter.",
      translations: {
        "Hindi": "कृपया मीटर चालू कीजिए।",
        "Marathi": "कृपया मीटर चालू करा.",
        "Spanish": "Por favor encienda el taxímetro.",
        "French": "Veuillez allumer le taximètre s'il vous plaît.",
        "German": "Bitte schalten Sie das Taxameter ein.",
        "Italian": "Per favore accenda il tassametro.",
        "Portuguese": "Por favor, ligue o taxímetro.",
        "Russian": "Пожалуйста, включите счетчик такси.",
        "Arabic": "يرجى تشغيل العداد من فضلك.",
        "Chinese": "请打表计价。",
        "Japanese": "タクシーのメーターを入れてください。",
        "Tamil": "தயவுசெய்து மீட்டரை போடுங்கள்.",
        "Gujarati": "કૃપા કરીને મીટર ચાલુ કરો.",
      },
      phonetics: {
        "Hindi": "Kripya meter chaalu keejiye.",
        "Marathi": "Krupaya meter chaalu kara.",
        "Russian": "Pozhaluysta, vklyuchite schetchik taksi.",
        "Chinese": "Qǐng dǎbiǎo jìjià.",
        "Japanese": "Takushii no meetaa o irete kudasai.",
        "Tamil": "Thayavuseithu meter-ai podungal.",
        "Gujarati": "Krupa karine meter chalu karo.",
      },
    ),
    SurvivalPhrase(
      category: "Street & Dining",
      english: "Is this completely vegetarian (pure veg)?",
      translations: {
        "Hindi": "क्या यह बिल्कुल शुद्ध शाकाहारी है?",
        "Marathi": "हे पूर्णपणे शाकाहारी आहे का?",
        "Spanish": "¿Esto es completamente vegetariano?",
        "French": "Est-ce entièrement végétarien ?",
        "German": "Ist das komplett vegetarisch?",
        "Italian": "È completamente vegetariano?",
        "Portuguese": "Isso é totalmente vegetariano?",
        "Russian": "Это полностью вегетарианское блюдо?",
        "Arabic": "هل هذا نباتي تماماً؟",
        "Chinese": "这完全是素食吗？",
        "Japanese": "これは完全にベジタリアンですか？",
        "Tamil": "இது முழுக்க முழுக்க சைவ உணவா?",
        "Gujarati": "શું આ સંપૂર્ણપણે શુદ્ધ શાકાહારી છે?",
      },
      phonetics: {
        "Hindi": "Kya yeh bilkul shuddh shaakahari hai?",
        "Marathi": "He poornapane shaakahari aahe ka?",
        "Russian": "Eto polnost'yu vegetarianskoye blyudo?",
        "Chinese": "Zhè wánquán shì sùshí ma?",
        "Japanese": "Kore wa kanzen ni bejitarian desu ka?",
        "Tamil": "Ithu muzhukka muzhukka saiva unava?",
        "Gujarati": "Shu aa sampoornpane shuddh shakahari chhe?",
      },
    ),
    SurvivalPhrase(
      category: "Street & Dining",
      english: "Do you accept UPI or QR code digital payment?",
      translations: {
        "Hindi": "क्या आप यूपीआई या क्यूआर कोड स्वीकार करते हैं?",
        "Marathi": "तुम्ही यूपीआय किंवा क्यूआर कोड स्वीकारता का?",
        "Spanish": "¿Acepta pago con código QR / digital?",
        "French": "Acceptez-vous le paiement par code QR / numérique ?",
        "German": "Akzeptieren Sie UPI oder QR-Code-Zahlung?",
        "Italian": "Accettate pagamenti tramite codice QR o digitali?",
        "Portuguese": "Você aceita pagamento por QR code ou digital?",
        "Russian": "Вы принимаете оплату по QR-коду?",
        "Arabic": "هل تقبل الدفع الرقمي عبر رمز QR أو UPI؟",
        "Chinese": "你支持扫码（二维码/UPI）支付吗？",
        "Japanese": "QRコードやデジタル決済は使えますか？",
        "Tamil": "நீங்கள் UPI அல்லது QR குறியீடு கட்டணத்தை ஏற்றுக்கொள்கிறீர்களா?",
        "Gujarati": "તમે UPI કે QR કોડ પેમેન્ટ સ્વીકારો છો?",
      },
      phonetics: {
        "Hindi": "Kya aap UPI ya QR code scan lete hain?",
        "Marathi": "Tumhi UPI kinva QR code swikarta ka?",
        "Chinese": "Nǐ zhīchí sǎomǎ zhīfù ma?",
        "Japanese": "QR koudo ya dejitaru kessai wa tsukaemasu ka?",
        "Tamil": "Neengal UPI allathu QR code kattanam yerkireergala?",
        "Gujarati": "Tame UPI ke QR code payment sweekaro chho?",
      },
    ),
    SurvivalPhrase(
      category: "Haggling & Shopping",
      english: "That is too high. Please give me a fair price.",
      translations: {
        "Hindi": "यह बहुत ज्यादा है। कृपया सही दाम लगाइए।",
        "Marathi": "हे खूप जास्त आहे. कृपया योग्य भाव सांगा.",
        "Spanish": "Es demasiado caro. Deme un precio justo por favor.",
        "French": "C'est trop cher. Donnez-moi un prix raisonnable s'il vous plaît.",
        "German": "Das ist zu teuer. Bitte machen Sie einen fairen Preis.",
        "Italian": "È troppo alto. Per favore mi faccia un prezzo equo.",
        "Portuguese": "Está muito caro. Por favor, me dê um preço justo.",
        "Russian": "Это слишком дорого. Сделайте нормальную цену, пожалуйста.",
        "Arabic": "هذا السعر مرتفع جداً. أعطني سعراً عادلاً رجاءً.",
        "Chinese": "太贵了，请给个实在公道的价格。",
        "Japanese": "高すぎます。適正な価格にしてください。",
        "Tamil": "இது மிக அதிகம். நியாயமான விலையைக் கூறுங்கள்.",
        "Gujarati": "આ બહુ વધારે છે. મહેરબાની કરીને વાજબી ભાવ લગાવો.",
      },
      phonetics: {
        "Hindi": "Yeh bahut zyada hai. Kripya sahi daam lagaiye.",
        "Marathi": "He khoop jaast aahe. Krupaya yogya bhaav saanga.",
        "Russian": "Eto slishkom dorogo. Sdelayte normal'nuyu tsenu, pozhaluysta.",
        "Chinese": "Tài guì le, qǐng gěi gè shízài gōngdào de jiàgé.",
        "Japanese": "Takasugimasu. Tekisei na kakaku ni shite kudasai.",
        "Tamil": "Ithu miga athigam. Niyayamana vilaiyudan sollungal.",
        "Gujarati": "Aa bahu vadhare chhe. Vajbi bhav lagavo.",
      },
    ),
  ];
}