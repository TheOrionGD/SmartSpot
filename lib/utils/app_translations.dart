import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

/// Centralized i18n translation dictionary supporting:
/// - English
/// - Tamil (தமிழ்)
/// - Spanish (Español)
/// - Hindi (हिन्दी)
class AppTranslations {
  AppTranslations._();

  static const List<String> supportedLanguages = [
    'English',
    'Tamil (தமிழ்)',
    'Spanish (Español)',
    'Hindi (हिन्दी)',
  ];

  static const Map<String, Map<String, String>> _dictionary = {
    'English': {
      'app_name': 'SmartSpot',
      'home': 'Home',
      'analytics': 'Analytics',
      'completed': 'Completed',
      'settings': 'Settings',
      'profile': 'Profile',
      'search_hint': 'Search reminders...',
      'no_reminders': 'No reminders yet',
      'add_reminder': 'Add Reminder',
      'voice_quick_add': 'Voice / Quick Add',
      'remind_me_to': 'Remind me to…',
      'use_this': 'Use this',
      'edit_profile': 'Edit Profile',
      'full_name': 'Full Name',
      'email_address': 'Email Address',
      'phone_number': 'Phone Number',
      'bio': 'Bio / About You',
      'save_changes': 'Save Changes',
      'logout': 'Logout',
      'language': 'Language',
      'theme_mode': 'Theme Mode',
      'notifications': 'Notifications',
      'quiet_hours': 'Quiet Hours',
      'kpi_summary': 'Overview Summary',
      'category_dist': 'Category Distribution',
      'weekly_trend': '7-Day Activity Trend',
      'priority_breakdown': 'Priority Breakdown',
      'top_locations': 'Top Geofence Spots',
      'time_activity': 'Time-of-Day Activity',
      'smart_insights': 'Predictive Intelligence',
      'total': 'Total',
      'pending': 'Pending',
      'archived': 'Archived',
      'cancel': 'Cancel',
      'continue': 'Continue',
      'allow': 'Allow',
      'get_started': 'Get Started',
    },
    'Tamil (தமிழ்)': {
      'app_name': 'ஸ்மார்ட்ஸ்பாட்',
      'home': 'முகப்பு',
      'analytics': 'பகுப்பாய்வு',
      'completed': 'முடிந்தது',
      'settings': 'அமைப்புகள்',
      'profile': 'சுயவிவரம்',
      'search_hint': 'நினைவூட்டல்களைத் தேடுக...',
      'no_reminders': 'இன்னும் நினைவூட்டல்கள் இல்லை',
      'add_reminder': 'நினைவூட்டல் சேர்',
      'voice_quick_add': 'குரல் / விரைவு சேர்ப்பு',
      'remind_me_to': 'எனக்கு நினைவூட்டு…',
      'use_this': 'இதனைப் பயன்படுத்து',
      'edit_profile': 'சுயவிவரத்தை திருத்து',
      'full_name': 'முழு பெயர்',
      'email_address': 'மின்னஞ்சல் முகவரி',
      'phone_number': 'தொலைபேசி எண்',
      'bio': 'சுய குறிப்பு',
      'save_changes': 'மாற்றங்களைச் சேமி',
      'logout': 'வெளியேறு',
      'language': 'மொழி',
      'theme_mode': 'தீம் பயன்முறை',
      'notifications': 'அறிவிப்புகள்',
      'quiet_hours': 'அமைதி நேரம்',
      'kpi_summary': 'பொதுவான சுருக்கம்',
      'category_dist': 'வகைப்பாடு பங்கீடு',
      'weekly_trend': '7 நாள் செயல்பாடு',
      'priority_breakdown': 'முன்னுரிமை பகுப்பாய்வு',
      'top_locations': 'முக்கிய இடங்கள்',
      'time_activity': 'நேர அடிப்படையிலான செயல்பாடு',
      'smart_insights': 'நுண்ணறிவு பகுப்பாய்வு',
      'total': 'மொத்தம்',
      'pending': 'நிலுவையில்',
      'archived': 'காப்பகப்படுத்தப்பட்டது',
      'cancel': 'ரத்துசெய்',
      'continue': 'தொடர்க',
      'allow': 'அனுமதி',
      'get_started': 'தொடங்குவோம்',
    },
    'Spanish (Español)': {
      'app_name': 'SmartSpot',
      'home': 'Inicio',
      'analytics': 'Analítica',
      'completed': 'Completado',
      'settings': 'Ajustes',
      'profile': 'Perfil',
      'search_hint': 'Buscar recordatorios...',
      'no_reminders': 'Aún no hay recordatorios',
      'add_reminder': 'Añadir Recordatorio',
      'voice_quick_add': 'Voz / Añadir Rápido',
      'remind_me_to': 'Recordarme…',
      'use_this': 'Usar esto',
      'edit_profile': 'Editar Perfil',
      'full_name': 'Nombre Completo',
      'email_address': 'Correo Electrónico',
      'phone_number': 'Número de Teléfono',
      'bio': 'Biografía',
      'save_changes': 'Guardar Cambios',
      'logout': 'Cerrar Sesión',
      'language': 'Idioma',
      'theme_mode': 'Modo de Tema',
      'notifications': 'Notificaciones',
      'quiet_hours': 'Horas de Silencio',
      'kpi_summary': 'Resumen General',
      'category_dist': 'Distribución por Categorías',
      'weekly_trend': 'Tendencia de 7 Días',
      'priority_breakdown': 'Desglose por Prioridad',
      'top_locations': 'Lugares Principales',
      'time_activity': 'Actividad por Hora',
      'smart_insights': 'Inteligencia Predictiva',
      'total': 'Total',
      'pending': 'Pendiente',
      'archived': 'Archivado',
      'cancel': 'Cancelar',
      'continue': 'Continuar',
      'allow': 'Permitir',
      'get_started': 'Empezar',
    },
    'Hindi (हिन्दी)': {
      'app_name': 'स्मार्टस्पॉट',
      'home': 'होम',
      'analytics': 'विश्लेषण',
      'completed': 'पूरा हुआ',
      'settings': 'सेटिंग्स',
      'profile': 'प्रोफ़ाइल',
      'search_hint': 'रिमाइंडर खोजें...',
      'no_reminders': 'अभी कोई रिमाइंडर नहीं',
      'add_reminder': 'रिमाइंडर जोड़ें',
      'voice_quick_add': 'वॉयस / त्वरित जोड़ें',
      'remind_me_to': 'मुझे याद दिलाएं…',
      'use_this': 'इसका उपयोग करें',
      'edit_profile': 'प्रोफ़ाइल संपादित करें',
      'full_name': 'पूरा नाम',
      'email_address': 'ईमेल पता',
      'phone_number': 'फ़ोन नंबर',
      'bio': 'बायो / परिचय',
      'save_changes': 'बदलाव सहेजें',
      'logout': 'लॉगआउट',
      'language': 'भाषा',
      'theme_mode': 'थीम मोड',
      'notifications': 'सूचनाएं',
      'quiet_hours': 'शांत समय',
      'kpi_summary': 'सामान्य अवलोकन',
      'category_dist': 'श्रेणी वितरण',
      'weekly_trend': '7 दिनों की गतिविधि',
      'priority_breakdown': 'प्राथमिकता विश्लेषण',
      'top_locations': 'प्रमुख स्थान',
      'time_activity': 'समय-आधारित गतिविधि',
      'smart_insights': 'पूर्वानुमानित बुद्धिमत्ता',
      'total': 'कुल',
      'pending': 'लंबित',
      'archived': 'संग्रहीत',
      'cancel': 'रद्द करें',
      'continue': 'जारी रखें',
      'allow': 'अनुमति दें',
      'get_started': 'शुरू करें',
    },
  };

  /// Returns the translated text for [key] based on active language in [BuildContext].
  static String tr(BuildContext context, String key) {
    final lang = context.watch<SettingsProvider>().language;
    return getText(lang, key);
  }

  /// Returns the translated text for [key] given a language string.
  static String getText(String language, String key) {
    // Normalise language key match
    String normalizedLang = 'English';
    if (language.contains('Tamil') || language.contains('தமிழ்')) {
      normalizedLang = 'Tamil (தமிழ்)';
    } else if (language.contains('Spanish') || language.contains('Español')) {
      normalizedLang = 'Spanish (Español)';
    } else if (language.contains('Hindi') || language.contains('हिन्दी')) {
      normalizedLang = 'Hindi (हिन्दी)';
    }

    final dict = _dictionary[normalizedLang] ?? _dictionary['English']!;
    return dict[key] ?? _dictionary['English']![key] ?? key;
  }
}
