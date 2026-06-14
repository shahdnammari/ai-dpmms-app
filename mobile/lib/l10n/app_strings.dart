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
      _t('Message from your doctor', 'رسالة طبيب', 'הודעת רופא');
  String timeToTake(String name) => _ar
      ? 'حان وقت تناول $name'
      : _he
          ? 'זמן לקחת $name'
          : 'Time to take $name';
  String scheduledAt(String t) =>
      _ar ? 'مجدول في $t' : _he ? 'מתוזמן ב-$t' : 'Scheduled at $t';
  String doctorAddedMedication(String name) => _ar
      ? 'أضاف طبيبك "$name" إلى أدويتك'
      : _he
          ? 'הרופא שלך הוסיף "$name" לתרופות שלך'
          : 'Your doctor added "$name" to your medications';
  String doctorUpdatedMedication(String name) => _ar
      ? 'قام طبيبك بتحديث وصفة "$name"'
      : _he
          ? 'הרופא שלך עדכן את מרשם "$name" שלך'
          : 'Your doctor updated your "$name" prescription';

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
  String get doctorAiWelcome => _t(
    "Hello! I'm your AI clinical assistant. Ask me about patient adherence, treatment recommendations, or medication management.",
    'مرحباً! أنا مساعدك السريري الذكي. اسألني عن التزام المرضى أو توصيات العلاج أو إدارة الأدوية.',
    'שלום! אני העוזר הקליני החכם שלך. שאל אותי על עמידה של מטופלים, המלצות טיפול או ניהול תרופות.',
  );
  String get doctorAiHint => _t(
    'Ask about your patients…',
    'اسأل عن مرضاك...',
    'שאל על המטופלים שלך...',
  );
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

  // ── Doctor screens ───────────────────────────────────────────────
  String get patients => _t('Patients', 'المرضى', 'חולים');
  String get overview => _t('Overview', 'نظرة عامة', 'סקירה כללית');
  String get atRisk => _t('At Risk', 'في خطر', 'בסיכון');
  String get adherent => _t('Adherent', 'ملتزم', 'עומד');
  String get allFilter => _t('All', 'الكل', 'הכל');
  String get sendReminder => _t('Send Reminder', 'إرسال تذكير', 'שלח תזכורת');
  String get sendReminderQ => _t('Send Reminder?', 'إرسال تذكير؟', 'שלח תזכורת?');
  String get viewPatient => _t('View Patient', 'عرض المريض', 'צפה במטופל');
  String get noAlerts => _t(
    'No alerts at this time. All patients are on track.',
    'لا تنبيهات في هذا الوقت. جميع المرضى على المسار الصحيح.',
    'אין התראות כרגע. כל המטופלים עומדים ביעדים.',
  );
  String alertsCount(int n) =>
      _ar ? 'التنبيهات ($n)' : _he ? 'התראות ($n)' : 'ALERTS ($n)';
  String get patientsListTitle =>
      _t('Patients List', 'قائمة المرضى', 'רשימת מטופלים');
  String get searchPatientHint =>
      _t('Search Patient name...', 'ابحث عن مريض...', 'חפש מטופל...');
  String get noPatientsFound =>
      _t('No patients found.', 'لا يوجد مرضى.', 'לא נמצאו מטופלים.');
  String noMatchSearch(String q) => _ar
      ? 'لا يوجد مريض يطابق\n"$q"'
      : _he
          ? 'לא נמצאו מטופלים\n"$q"'
          : 'No patients match\n"$q"';
  String get addNewPatient =>
      _t('Add new patient', 'إضافة مريض جديد', 'הוסף מטופל חדש');
  String get nameAZ => _t('A–Z', 'أ–ي', 'א–ת');
  String get lowestAdherence =>
      _t('Lowest adherence', 'أقل التزام', 'עמידה נמוכה ביותר');
  String get mostMedications =>
      _t('Most medications', 'أكثر أدوية', 'הכי הרבה תרופות');
  String get allPatients => _t('All Patients', 'جميع المرضى', 'כל המטופלים');
  String get adherentPatients =>
      _t('Adherent Patients', 'المرضى الملتزمون', 'מטופלים עומדים');
  String get atRiskPatients =>
      _t('At Risk Patients', 'المرضى في خطر', 'מטופלים בסיכון');
  String get noPatientsCategory => _t(
    'No patients in this category.',
    'لا يوجد مرضى في هذه الفئة.',
    'אין מטופלים בקטגוריה זו.',
  );
  String get filterSent => _t('Sent', 'المرسل', 'נשלח');
  String get filterSystem => _t('System', 'النظام', 'מערכת');
  String get noSentMessages =>
      _t('No sent messages yet.', 'لا رسائل مرسلة بعد.', 'אין הודעות שנשלחו עדיין.');
  String get noSystemAlerts =>
      _t('No system alerts.', 'لا تنبيهات نظام.', 'אין התראות מערכת.');
  String get sendMessageBtn => _t('Send message', 'إرسال رسالة', 'שלח הודעה');
  String get selectPatient => _t('Select Patient', 'اختر مريض', 'בחר מטופל');
  String get noPatientsAvailable =>
      _t('No patients available.', 'لا يوجد مرضى متاحون.', 'אין מטופלים זמינים.');
  String get sendMessageTitle => _t('Send Message', 'إرسال رسالة', 'שלח הודעה');
  String get sendReminderTitle => _t('Send Reminder', 'إرسال تذكير', 'שלח תזכורת');
  String get titleLabel => _t('Title', 'العنوان', 'כותרת');
  String get selectMedOptional => _t(
    'Select Medication (optional)',
    'اختر دواء (اختياري)',
    'בחר תרופה (אופציונלי)',
  );
  String get messageField => _t('Message', 'الرسالة', 'הודעה');
  String get sendBtn => _t('Send', 'إرسال', 'שלח');
  String get loadingMedications =>
      _t('Loading medications...', 'جارٍ تحميل الأدوية...', 'טוען תרופות...');
  String get pleaseSelectPatient =>
      _t('Please select a patient.', 'الرجاء اختيار مريض.', 'אנא בחר מטופל.');
  String get messageCantBeEmpty => _t(
    'Message cannot be empty.',
    'لا يمكن أن تكون الرسالة فارغة.',
    'ההודעה לא יכולה להיות ריקה.',
  );
  String get noMedicationsYet =>
      _t('No medications yet.', 'لا توجد أدوية بعد.', 'אין תרופות עדיין.');
  String get loadingLabel => _t('Loading...', 'جارٍ التحميل...', 'טוען...');
  String get viewMore => _t('View more', 'عرض المزيد', 'הצג עוד');
  String get viewLess => _t('View less', 'عرض أقل', 'הצג פחות');
  String get viewReport => _t('View Report', 'عرض التقرير', 'צפה בדוח');
  String get everyday => _t('Everyday', 'كل يوم', 'כל יום');
  String get deletePatientTitle =>
      _t('Delete Patient', 'حذف المريض', 'מחק מטופל');
  String deletePatientConfirm(String name) => _ar
      ? 'هل أنت متأكد من إزالة "$name" من النظام؟'
      : _he
          ? 'האם אתה בטוח שברצונך להסיר "$name" מהמערכת?'
          : 'Are you sure you want to remove "$name" from the system?';
  String deletePatientWithUndo(String name) => _ar
      ? 'هل أنت متأكد من إزالة "$name" من النظام؟\n\nلا يمكن التراجع عن هذا الإجراء.'
      : _he
          ? 'האם אתה בטוח שברצונך להסיר "$name" מהמערכת?\n\nלא ניתן לבטל פעולה זו.'
          : 'Are you sure you want to remove "$name" from the system?\n\nThis action cannot be undone.';
  String get editMedication =>
      _t('Edit Medication', 'تعديل الدواء', 'ערוך תרופה');
  String nMedications(int n) => n == 1
      ? _t('1 Medication', 'دواء واحد', 'תרופה אחת')
      : _ar
          ? '$n أدوية'
          : _he
              ? '$n תרופות'
              : '$n Medications';
  String adherencePct(int pct) =>
      _ar ? 'الالتزام: $pct%' : _he ? 'עמידה: $pct%' : 'Adherence: $pct%';
  String get helpDoctorBody => _t(
    'For help with the dashboard, patients, or account issues,\nplease contact support.',
    'للمساعدة في لوحة التحكم أو المرضى أو مشاكل الحساب،\nيرجى التواصل مع الدعم.',
    'לקבלת עזרה עם לוח המחוונים, מטופלים, או בעיות חשבון,\nאנא צור קשר עם התמיכה.',
  );
  String toPatientName(String name) =>
      _ar ? 'إلى $name' : _he ? 'אל $name' : 'To $name';
  String reminderSentTo(String name) =>
      _ar ? 'تم إرسال التذكير إلى $name' : _he ? 'התזכורת נשלחה אל $name' : 'Reminder sent to $name';
  String messageSentTo(String name) =>
      _ar ? 'تم إرسال الرسالة إلى $name' : _he ? 'ההודעה נשלחה אל $name' : 'Message sent to $name';
  String get reminderFromDoctor =>
      _t('Reminder from your doctor', 'تذكير من طبيبك', 'תזכורת מהרופא שלך');
  String get messageFromDoctor =>
      _t('Message from your doctor', 'رسالة من طبيبك', 'הודעה מהרופא שלך');
  String get selectPatientHint =>
      _t('Select patient', 'اختر مريضاً', 'בחר מטופל');
  String removedPatient(String name) =>
      _ar ? '"$name" تمت إزالته' : _he ? '"$name" הוסר' : '"$name" removed';

  // ── Role select screen ───────────────────────────────────────────
  String get getStarted => _t('Get Started', 'ابدأ الآن', 'התחל');
  String get chooseOptionToContinue => _t(
    'Choose an option to continue',
    'اختر خياراً للمتابعة',
    'בחר אפשרות להמשיך',
  );
  String get swipeUpToStart =>
      _t('Swipe up to get started', 'اسحب للأعلى للبدء', 'החלק למעלה להתחלה');
  String get patientRoleSubtitle => _t(
    'Track medications & stay on schedule',
    'تتبع الأدوية والتزم بالجدول',
    'עקוב אחר תרופות והישאר בלוח הזמנים',
  );
  String get doctorRoleSubtitle => _t(
    'Monitor patients & manage care',
    'راقب المرضى وأدر الرعاية',
    'עקוב אחר מטופלים ונהל טיפול',
  );

  // ── Login & Register ──────────────────────────────────────────────
  String get loginTitle => _t('Login', 'تسجيل الدخول', 'כניסה');
  String get welcomeBack => _t('Welcome Back', 'مرحباً مجدداً', 'נעים מאוד שחזרת');
  String get loginSubtitle => _t(
    'Login to manage your medications',
    'سجّل دخولك لإدارة أدويتك',
    'היכנס לנהל את התרופות שלך',
  );
  String get password => _t('Password', 'كلمة المرور', 'סיסמה');
  String get enterEmailHint =>
      _t('Enter your email', 'أدخل بريدك الإلكتروني', 'הזן את האימייל שלך');
  String get enterPasswordHint =>
      _t('Enter your password', 'أدخل كلمة مرورك', 'הזן את הסיסמה שלך');
  String get forgotPassword =>
      _t('Forgot password?', 'هل نسيت كلمة المرور؟', 'שכחת סיסמה?');
  String get dontHaveAccount =>
      _t("Don't have an account?", 'ليس لديك حساب؟', 'אין לך חשבון?');
  String get register => _t('Register', 'تسجيل', 'הרשמה');
  String get createAccount => _t('Create Account', 'إنشاء حساب', 'צור חשבון');
  String get registerAs => _t('Register as', 'سجّل كـ', 'הירשם בתור');
  String get stepBasicInfo =>
      _t('Basic Info', 'المعلومات الأساسية', 'מידע בסיסי');
  String get stepHealthInfo =>
      _t('Health Info', 'معلومات صحية', 'מידע בריאותי');
  String get createPatientSubtitle => _t(
    "Let's start with your basic info",
    'لنبدأ بمعلوماتك الأساسية',
    'בואו נתחיל עם המידע הבסיסי שלך',
  );
  String get createDoctorSubtitle =>
      _t('Create your doctor account', 'أنشئ حساب طبيبك', 'צור את חשבון הרופא שלך');
  String get enterNameHint =>
      _t('Enter your name', 'أدخل اسمك', 'הזן את שמך');
  String get minPasswordHint =>
      _t('Min 6 characters', '٦ أحرف على الأقل', 'לפחות 6 תווים');
  String get medicalLicenseOptional => _t(
    'Medical License ID (optional)',
    'رقم الترخيص الطبي (اختياري)',
    'מספר רישיון רפואי (אופציונלי)',
  );
  String get enterLicenseHint =>
      _t('Enter license number', 'أدخل رقم الترخيص', 'הזן מספר רישיון');
  String get healthInfoSubtitle =>
      _t('Tell us about your health', 'أخبرنا عن صحتك', 'ספר לנו על בריאותך');
  String get dateOfBirth =>
      _t('Date of Birth', 'تاريخ الميلاد', 'תאריך לידה');
  String get medicalConditionsOptional => _t(
    'Medical Conditions (optional)',
    'الحالات الطبية (اختياري)',
    'מצבים רפואיים (אופציונלי)',
  );
  String get selectAllThatApply => _t(
    'Select all that apply',
    'اختر كل ما ينطبق',
    'בחר את כל האפשרויות המתאימות',
  );
  String get nextBtn => _t('Next', 'التالي', 'הבא');
  String get alreadyHaveAccount =>
      _t('Already have an account?', 'هل لديك حساب بالفعل؟', 'כבר יש לך חשבון?');
  String get accountCreated => _t(
    'Account created successfully',
    'تم إنشاء الحساب بنجاح',
    'החשבון נוצר בהצלחה',
  );
  // Auth validation & error messages
  String get authEmptyFields => _t(
    'Please fill all fields.',
    'يرجى ملء جميع الحقول.',
    'אנא מלא את כל השדות.',
  );
  String get authEnterEmailAndPassword => _t(
    'Please enter email and password.',
    'يرجى إدخال البريد الإلكتروني وكلمة المرور.',
    'אנא הזן אימייל וסיסמה.',
  );
  String get authInvalidEmailFormat => _t(
    'Enter a valid email address.',
    'أدخل عنوان بريد إلكتروني صالح.',
    'הזן כתובת אימייל תקינה.',
  );
  String get authWeakPassword => _t(
    'Password must be at least 6 characters.',
    'يجب أن تكون كلمة المرور 6 أحرف على الأقل.',
    'הסיסמה חייבת להכיל לפחות 6 תווים.',
  );
  String get authSelectGender => _t(
    'Please select your gender.',
    'يرجى اختيار جنسك.',
    'אנא בחר את המין שלך.',
  );
  String get authSelectBirthday => _t(
    'Please select your birthday.',
    'يرجى اختيار تاريخ ميلادك.',
    'אנא בחר את תאריך הלידה שלך.',
  );
  String get authUserNotFound => _t(
    'No account found for this email.',
    'لم يتم العثور على حساب لهذا البريد.',
    'לא נמצא חשבון עבור אימייל זה.',
  );
  String get authWrongPassword =>
      _t('Wrong password.', 'كلمة المرور خاطئة.', 'סיסמה שגויה.');
  String get authInvalidCredential => _t(
    'Invalid email or password.',
    'بريد إلكتروني أو كلمة مرور غير صالحين.',
    'אימייל או סיסמה לא תקינים.',
  );
  String get authUserDisabled => _t(
    'This user has been disabled.',
    'تم تعطيل هذا المستخدم.',
    'משתמש זה הושבת.',
  );
  String get authTooManyRequests => _t(
    'Too many attempts. Try again later.',
    'محاولات كثيرة جداً. حاول لاحقاً.',
    'יותר מדי ניסיונות. נסה שוב מאוחר יותר.',
  );
  String get authLoginFailed =>
      _t('Login failed.', 'فشل تسجيل الدخول.', 'הכניסה נכשלה.');
  String get authEmailInUse => _t(
    'This email is already registered.',
    'هذا البريد الإلكتروني مسجل بالفعل.',
    'אימייל זה כבר רשום.',
  );
  String get authWeakPasswordShort => _t(
    'Password is too weak (min 6 chars).',
    'كلمة المرور ضعيفة جداً (6 أحرف على الأقل).',
    'הסיסמה חלשה מדי (מינימום 6 תווים).',
  );
  String get authProfileNotFound => _t(
    'Profile not found. Please register again.',
    'الملف الشخصي غير موجود. يرجى التسجيل مرة أخرى.',
    'הפרופיל לא נמצא. אנא הירשם שוב.',
  );
  String get authInvalidRole => _t(
    'Invalid role. Please register again.',
    'دور غير صالح. يرجى التسجيل مرة أخرى.',
    'תפקיד לא תקין. אנא הירשם שוב.',
  );
  String get authSomethingWentWrong => _t(
    'Something went wrong. Please try again.',
    'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
    'משהו השתבש. אנא נסה שוב.',
  );
  String get authRegistrationFailed => _t(
    'Registration failed.',
    'فشل التسجيل.',
    'ההרשמה נכשלה.',
  );
  String conditionName(String key) {
    switch (key) {
      case 'Diabetes': return _t('Diabetes', 'السكري', 'סוכרת');
      case 'Hypertension': return _t('Hypertension', 'ارتفاع ضغط الدم', 'יתר לחץ דם');
      case 'Heart Disease': return _t('Heart Disease', 'أمراض القلب', 'מחלת לב');
      case 'Asthma': return _t('Asthma', 'الربو', 'אסתמה');
      case 'Kidney Disease': return _t('Kidney Disease', 'أمراض الكلى', 'מחלת כליות');
      case 'Arthritis': return _t('Arthritis', 'التهاب المفاصل', 'דלקת פרקים');
      case 'Thyroid Disorder': return _t('Thyroid Disorder', 'اضطراب الغدة الدرقية', 'הפרעת בלוטת התריס');
      case 'High Cholesterol': return _t('High Cholesterol', 'ارتفاع الكوليسترول', 'כולסטרול גבוה');
      default: return key;
    }
  }
}
