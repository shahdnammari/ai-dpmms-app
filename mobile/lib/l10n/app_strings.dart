import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// Lightweight localization helper — add keys here as screens are updated.
class S {
  final String _lang;
  const S._(this._lang);

  factory S.of(BuildContext context) =>
      S._(SettingsService.instance.locale.languageCode);

  bool get _ar => _lang == 'ar';
  bool get _he => _lang == 'he';

  String _t(String en, String ar, String he) =>
      _ar ? ar : _he ? he : en;

  // ── Navigation ──────────────────────────────────────────────────
  String get home => _t('Home', 'الرئيسية', 'בית');
  String get medications => _t('Medications', 'الأدوية', 'תרופות');
  String get notifications => _t('Notifications', 'الإشعارات', 'התראות');
  String get reports => _t('Reports', 'التقارير', 'דוחות');

  // ── Greetings ────────────────────────────────────────────────────
  String get goodMorning => _t('Good morning', 'صباح الخير', 'בוקר טוב');
  String get goodAfternoon => _t('Good afternoon', 'مساء الخير', 'צהריים טובים');
  String get goodEvening => _t('Good evening', 'مساء النور', 'ערב טוב');

  // ── Common actions ───────────────────────────────────────────────
  String get cancel => _t('Cancel', 'إلغاء', 'ביטול');
  String get delete => _t('Delete', 'حذف', 'מחק');
  String get edit => _t('Edit', 'تعديل', 'ערוך');
  String get save => _t('Save', 'حفظ', 'שמור');
  String get add => _t('Add', 'إضافة', 'הוסף');
  String get close => _t('Close', 'إغلاق', 'סגור');
  String get share => _t('Share', 'مشاركة', 'שתף');
  String get print => _t('Print', 'طباعة', 'הדפס');
  String get details => _t('Details', 'تفاصيل', 'פרטים');
  String get notSignedIn => _t('Not signed in', 'غير مسجل الدخول', 'לא מחובר');

  // ── Home tab ─────────────────────────────────────────────────────
  String get dailyProgress => _t('Daily Progress', 'التقدم اليومي', 'התקדמות יומית');
  String get todayChecklist =>
      _t("Today's Checklist", 'قائمة اليوم', 'רשימת המטלות היומית');
  String get noMedsToday => _t(
    'No medications scheduled for today.',
    'لا توجد أدوية مجدولة لليوم.',
    'אין תרופות מתוזמנות להיום.',
  );
  String takenOf(int t, int total) => _ar
      ? '$t من $total تم أخذه'
      : _he
          ? '$t מתוך $total נלקחו'
          : '$t of $total Taken';
  String get statusTaken => _t('Taken', 'تم أخذه', 'נלקח');
  String get statusSkipped => _t('Skipped', 'تم تخطيه', 'דולג');
  String get statusScheduled => _t('Scheduled', 'مجدول', 'מתוזמן');
  String get take => _t('Take', 'خذ', 'קח');
  String get skip => _t('Skip', 'تخطَّ', 'דלג');
  String get addMedication => _t('Add medication', 'إضافة دواء', 'הוסף תרופה');

  // ── Popup menu ───────────────────────────────────────────────────
  String get menuSetting => _t('Setting', 'الإعدادات', 'הגדרות');
  String get menuHelp => _t('Help & Support', 'المساعدة والدعم', 'עזרה ותמיכה');
  String get menuLogout => _t('Logout', 'تسجيل خروج', 'התנתק');

  // ── Help sheet ───────────────────────────────────────────────────
  String get helpTitle => _t('Help & Support', 'المساعدة والدعم', 'עזרה ותמיכה');
  String get helpBody => _t(
    'For help with medications, reminders, or account issues,\nplease contact support or talk to your doctor.',
    'للمساعدة في الأدوية أو التذكيرات أو مشاكل الحساب،\nيرجى التواصل مع الدعم أو التحدث مع طبيبك.',
    'לקבלת עזרה בנושא תרופות, תזכורות או בעיות חשבון,\nאנא צור קשר עם התמיכה או שוחח עם הרופא שלך.',
  );

  // ── Profile screen ───────────────────────────────────────────────
  String get profileTitle => _t('Profile', 'الملف الشخصي', 'פרופיל');
  String get settingsTitle => _t('Settings', 'الإعدادات', 'הגדרות');
  String get logoutButton => _t('Logout', 'تسجيل خروج', 'התנתק');
  String get userName => _t('User Name', 'اسم المستخدم', 'שם משתמש');
  String get email => _t('Email', 'البريد الإلكتروني', 'אימייל');
  String get gender => _t('Gender', 'الجنس', 'מין');
  String get birthday => _t('Birthday', 'تاريخ الميلاد', 'תאריך לידה');
  String get role => _t('Role', 'الدور', 'תפקיד');
  String get medicalConditions =>
      _t('Medical Conditions', 'الحالات الطبية', 'מצבים רפואיים');
  String get tapToAddConditions =>
      _t('Tap to add conditions', 'انقر لإضافة حالات', 'הקש להוסיף מצבים');
  String get selectBirthday =>
      _t('Select birthday', 'اختر تاريخ الميلاد', 'בחר תאריך לידה');
  String get female => _t('Female', 'أنثى', 'נקבה');
  String get male => _t('Male', 'ذكر', 'זכר');
  String get rolePatient => _t('Patient', 'مريض', 'מטופל');
  String get roleDoctor => _t('Doctor', 'طبيب', 'רופא');
  String get profileUpdated => _t(
    'Profile updated successfully',
    'تم تحديث الملف الشخصي بنجاح',
    'הפרופיל עודכן בהצלחה',
  );
  String get profileSelectGender =>
      _t('Please select gender', 'الرجاء اختيار الجنس', 'אנא בחר מין');
  String get profileSelectBirthday => _t(
    'Please select birthday',
    'الرجاء اختيار تاريخ الميلاد',
    'אנא בחר תאריך לידה',
  );
  String get logoutConfirmTitle => _t('Logout?', 'تسجيل الخروج؟', 'התנתק?');
  String get logoutConfirmMsg => _t(
    'Are you sure you want to logout?',
    'هل أنت متأكد أنك تريد تسجيل الخروج؟',
    'האם אתה בטוח שברצונך להתנתק?',
  );
  String get enterName =>
      _t('Please enter your name', 'الرجاء إدخال اسمك', 'אנא הזן את שמך');
  String get nameTooShort =>
      _t('Name is too short', 'الاسم قصير جداً', 'השם קצר מדי');
  String get enterEmail => _t(
    'Please enter your email',
    'الرجاء إدخال بريدك الإلكتروني',
    'אנא הזן את האימייל שלך',
  );
  String get invalidEmail =>
      _t('Enter a valid email', 'أدخل بريداً إلكترونياً صحيحاً', 'הזן אימייל תקין');

  // ── Settings screen ──────────────────────────────────────────────
  String get appearanceSection => _t('APPEARANCE', 'المظهر', 'מראה');
  String get themeTitle => _t('Theme', 'السمة', 'ערכת נושא');
  String get fontSizeTitle => _t('Font Size', 'حجم الخط', 'גודל גופן');
  String get languageSection => _t('LANGUAGE', 'اللغة', 'שפה');
  String get appLanguageTitle => _t('App Language', 'لغة التطبيق', 'שפת האפליקציה');
  String get securitySection =>
      _t('PRIVACY & SECURITY', 'الخصوصية والأمان', 'פרטיות ואבטחה');
  String get changePasswordTitle =>
      _t('Change Password', 'تغيير كلمة المرور', 'שנה סיסמה');
  String get changePasswordSub => _t(
    'Send a reset link to your email',
    'إرسال رابط إعادة التعيين إلى بريدك',
    'שלח קישור לאיפוס לאימייל שלך',
  );
  String get themeLight => _t('Light', 'فاتح', 'בהיר');
  String get themeDark => _t('Dark', 'داكن', 'כהה');
  String get themeSystem =>
      _t('System default', 'تلقائي (حسب الجهاز)', 'ברירת מחדל של המכשיר');
  String get fontSmall => _t('Small', 'صغير', 'קטן');
  String get fontMedium => _t('Medium', 'متوسط', 'בינוני');
  String get fontLarge => _t('Large', 'كبير', 'גדול');
  String get textPreviewLabel =>
      _t('Text preview', 'معاينة النص', 'תצוגה מקדימה');
  String get textPreviewContent => _t(
    'Dose: 1 tablet twice daily',
    'الجرعة: ١ قرص مرتين يومياً',
    'מינון: טבלית 1 פעמיים ביום',
  );

  // ── Medications list ─────────────────────────────────────────────
  String get searchHint =>
      _t('Search medication...', 'ابحث عن دواء...', 'חפש תרופה...');
  String get deleteMedTitle => _t('Delete medication?', 'حذف الدواء؟', 'מחק תרופה?');
  String deleteConfirm(String name) => _ar
      ? 'هل أنت متأكد من حذف "$name"؟'
      : _he
          ? 'האם אתה בטוח שברצונך למחוק "$name"?'
          : 'Are you sure you want to delete "$name"?';
  String get viewOnly => _t('View Only', 'عرض فقط', 'צפייה בלבד');
  String get noMedsDay =>
      _t('No medications for this day.', 'لا توجد أدوية لهذا اليوم.', 'אין תרופות ליום זה.');
  String medDeleted(String name) => _ar ? 'تم حذف $name' : _he ? '$name נמחק' : '$name deleted';

  // ── Medication form ──────────────────────────────────────────────
  String get addMedicationTitle => _t('Add Medication', 'إضافة دواء', 'הוסף תרופה');
  String get editMedicationTitle => _t('Edit Medication', 'تعديل الدواء', 'ערוך תרופה');
  String get medicationName => _t('Medication Name', 'اسم الدواء', 'שם התרופה');
  String get dose => _t('Dose', 'الجرعة', 'מינון');
  String get timeLabel => _t('Time', 'الوقت', 'זמן');
  String get repeatLabel => _t('Repeat', 'التكرار', 'חזרה');
  String get enableReminder => _t('Enable Reminder', 'تفعيل التذكير', 'הפעל תזכורת');
  String get noteLabel => _t('Note', 'ملاحظة', 'הערה');
  String get addTime => _t('Add Time', 'إضافة وقت', 'הוסף זמן');
  String get addAnotherTime => _t('Add Another Time', 'إضافة وقت آخر', 'הוסף זמן נוסף');
  String get selectTime => _t('Select Time', 'اختر الوقت', 'בחר זמן');
  String get discardChanges => _t('Discard changes?', 'تجاهل التغييرات؟', 'בטל שינויים?');
  String get discardMessage => _t(
    'Any information you have entered will not be saved.',
    'لن يتم حفظ أي معلومات أدخلتها.',
    'כל המידע שהזנת לא יישמר.',
  );
  String get keepEditing => _t('Keep editing', 'استمر في التعديل', 'המשך עריכה');
  String get discard => _t('Discard', 'تجاهل', 'בטל');
  String get medAdded => _t('Medication added ✅', 'تم إضافة الدواء ✅', 'התרופה נוספה ✅');
  String get medUpdated =>
      _t('Medication updated ✅', 'تم تحديث الدواء ✅', 'התרופה עודכנה ✅');
  String get enterMedName =>
      _t('Please enter the medication name.', 'الرجاء إدخال اسم الدواء.', 'אנא הזן את שם התרופה.');
  String get enterDose =>
      _t('Please enter the dose.', 'الرجاء إدخال الجرعة.', 'אנא הזן את המינון.');
  String get enterTime =>
      _t('Please add at least one time.', 'الرجاء إضافة وقت واحد على الأقل.', 'אנא הוסף לפחות זמן אחד.');

  // ── Medication details ───────────────────────────────────────────
  String get scheduleLabel => _t('Schedule', 'الجدول', 'לוח זמנים');
  String get reminderLabel => _t('Reminder', 'التذكير', 'תזכורת');
  String get recentActivity => _t('Recent Activity', 'النشاط الأخير', 'פעילות אחרונה');
  String get noRecentActivity =>
      _t('No recent activity.', 'لا يوجد نشاط مؤخراً.', 'אין פעילות אחרונה.');
  String get everyDay => _t('Every day', 'كل يوم', 'כל יום');
  String get noRepeatDays => _t('No repeat days', 'لا أيام تكرار', 'אין ימי חזרה');
  String get timesPerDay1 =>
      _t('1 time per day', 'مرة واحدة في اليوم', 'פעם אחת ביום');
  String timesPerDayN(int n) => _ar
      ? '$n مرات في اليوم'
      : _he
          ? '$n פעמים ביום'
          : '$n times per day';
  String get viewMedication => _t('View Medication', 'عرض الدواء', 'צפה בתרופה');
  String get medReminder =>
      _t('Medication reminder', 'تذكير بالدواء', 'תזכורת לתרופה');
  String get doctorMessage =>
      _t('Doctor message', 'رسالة طبيب', 'הודעת רופא');
  String timeToTake(String name) => _ar
      ? 'حان وقت تناول $name'
      : _he
          ? 'זמן לקחת $name'
          : 'Time to take $name';
  String scheduledAt(String t) =>
      _ar ? 'مجدول في $t' : _he ? 'מתוזמן ב-$t' : 'Scheduled at $t';

  // ── Notifications ────────────────────────────────────────────────
  String get noNotifications =>
      _t('No notifications yet.', 'لا توجد إشعارات بعد.', 'אין התראות עדיין.');
  String get justNow => _t('Just now', 'الآن', 'עכשיו');
  String minsAgo(int m) =>
      _ar ? 'منذ $mد' : _he ? 'לפני $mד' : '${m}m ago';
  String hoursAgo(int h) =>
      _ar ? 'منذ $hس' : _he ? 'לפני $hש' : '${h}h ago';
  String get yesterday => _t('Yesterday', 'أمس', 'אתמול');
  String daysAgo(int d) =>
      _ar ? 'منذ $d أيام' : _he ? 'לפני $d ימים' : '${d}d ago';

  // ── Reports ──────────────────────────────────────────────────────
  String get reportWeek => _t('Week', 'أسبوع', 'שבוע');
  String get reportMonth => _t('Month', 'شهر', 'חודש');
  String get exportReport => _t('Export Report', 'تصدير التقرير', 'ייצא דוח');
  String get exportPdf => _t('Export as PDF', 'تصدير كـ PDF', 'ייצא כ-PDF');
  String get exportButton => _t('Export', 'تصدير', 'ייצא');
  String get noReportData =>
      _t('No report data yet.', 'لا توجد بيانات تقرير بعد.', 'אין נתוני דוח עדיין.');
  String get noChartData =>
      _t('No chart data yet.', 'لا توجد بيانات رسم بياني بعد.', 'אין נתוני תרשים עדיין.');
  String get adherence => _t('Adherence', 'الالتزام', 'עמידה');
  String get missed => _t('Missed', 'الفائت', 'פוספסו');
  String get bestDay => _t('Best Day', 'أفضل يوم', 'היום הטוב ביותר');
  String get bestWeek => _t('Best Week', 'أفضل أسبוع', 'השבוע הטוב ביותר');
  String get mostMissed => _t('Most Missed', 'الأكثر فواتاً', 'הכי פוספס');
  String get weeklyOverview => _t('Weekly Overview', 'نظرة عامة أسبوعية', 'סקירה שבועית');
  String get monthlyOverview =>
      _t('Monthly Overview', 'نظرة عامة شهرية', 'סקירה חודשית');

  // ── AI chat screen ────────────────────────────────────────────────
  String get aiWelcome => _t(
    "Hello! I'm your personal medical assistant. Ask me anything about your medications or health routine.",
    'مرحباً! أنا مساعدك الطبي الشخصي. اسألني أي شيء عن أدويتك أو روتينك الصحي.',
    'שלום! אני העוזר הרפואי האישי שלך. שאל אותי כל שאלה על התרופות שלך או על שגרת הבריאות שלך.',
  );
  String get aiHint => _t(
    'Ask about your medications…',
    'اسأل عن أدويتك...',
    'שאל על התרופות שלך...',
  );
  String get aiError => _t(
    "Sorry, I couldn't get a response. Please try again.",
    'عذراً، لم أتمكن من الحصول على رد. يرجى المحاولة مرة أخرى.',
    'מצטער, לא הצלחתי לקבל תשובה. אנא נסה שוב.',
  );
}
