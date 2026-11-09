import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter, ImageByteFormat;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_api.dart';
import 'auth_flow.dart';
import 'auth_token_store.dart';
import 'gamification.dart';
import 'handwriting/stroke_symbol_model.dart';
import 'math_engine.dart';
import 'math_history.dart';
import 'statistics_probability_engine.dart';
import 'visualization/plot_formula.dart';

part 'ui/app_pages.dart';
part 'visualization/math_visualization_painter.dart';
part 'visualization/plot_2d_renderer.dart';
part 'visualization/plot_3d_renderer.dart';

void main() => runApp(const MathevoApp());

const _navy = Color(0xFF302523);
const _accent = Color(0xFFF43F65);
const _background = Color(0xFFFAF7F3);

class MathevoApp extends StatefulWidget {
  const MathevoApp({super.key, this.authApi, this.tokenStore});

  final AuthApi? authApi;
  final AuthTokenStore? tokenStore;

  @override
  State<MathevoApp> createState() => _MathevoAppState();
}

class _MathevoAppState extends State<MathevoApp> {
  late final AuthApi _authApi = widget.authApi ?? const HttpAuthApi();
  late final AuthTokenStore _tokenStore =
      widget.tokenStore ?? const SecureAuthTokenStore();
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _isReady = false;
  bool _isAuthenticated = false;
  bool _startAtWelcome = false;
  bool _darkMode = false;
  String _displayName = 'Your name';
  String _username = 'Username not set';
  String? _profileImagePath;
  final _history = MathHistory();
  final _progressRepository = ProgressRepository();
  List<CalculationRecord> _records = const [];
  UserProgress _progress = const UserProgress();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = await _tokenStore.readRefreshToken();
    final records = await _history.load();
    final progress = await _progressRepository.applyInactivityDecay(
      DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _isReady = true;
      _isAuthenticated =
          (prefs.getBool('mathverse.auth.signedIn') ?? false) &&
          refreshToken != null;
      _darkMode = prefs.getBool('mathverse.darkMode') ?? false;
      _displayName = prefs.getString('mathverse.profile.name') ?? _displayName;
      _username = prefs.getString('mathverse.profile.username') ?? _username;
      _profileImagePath = prefs.getString('mathverse.profile.image');
      _records = records;
      _progress = progress;
    });
  }

  Future<void> _setDarkMode(bool value) async {
    setState(() => _darkMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mathverse.darkMode', value);
  }

  Future<void> _saveProfile({
    String? name,
    String? username,
    String? imagePath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      await prefs.setString('mathverse.profile.name', name);
    }
    if (username != null) {
      await prefs.setString('mathverse.profile.username', username);
    }
    if (imagePath != null) {
      await prefs.setString('mathverse.profile.image', imagePath);
    }
    if (!mounted) return;
    setState(() {
      if (name != null) _displayName = name;
      if (username != null) _username = username;
      if (imagePath != null) _profileImagePath = imagePath;
    });
  }

  Future<void> _onAuthenticated(CloudAuthSession session) async {
    await _tokenStore.save(session);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mathverse.auth.signedIn', true);
    await prefs.setString('mathverse.profile.name', session.user.name);
    await prefs.setString('mathverse.profile.username', session.user.username);
    // Remove credentials left behind by older device-only auth builds after
    // this account has successfully authenticated with the cloud service.
    for (final key in [
      'mathverse.auth.email',
      'mathverse.auth.salt',
      'mathverse.auth.passwordHash',
      'mathverse.auth.hashIterations',
      'mathverse.auth.name',
    ]) {
      await prefs.remove(key);
    }
    if (!mounted) return;
    setState(() {
      _isAuthenticated = true;
      _startAtWelcome = false;
      _displayName = session.user.name;
      _username = session.user.username;
    });
  }

  Future<void> _pickProfilePhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) await _saveProfile(imagePath: image.path);
  }

  void _showHistory() {
    _navigatorKey.currentState?.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _HistoryPage(
          records: _records,
          onContinue: (record) {
            _navigatorKey.currentState?.push<void>(
              MaterialPageRoute<void>(
                builder: (_) => _ContinuedCalculatorPage(
                  record: record,
                  records: _records,
                  onCalculation: _addRecord,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _logOut() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken != null) {
      unawaited(_authApi.logOut(refreshToken).catchError((Object _) {}));
    }
    await _tokenStore.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mathverse.auth.signedIn', false);
    if (!mounted) return;
    setState(() {
      _isAuthenticated = false;
      _startAtWelcome = true;
    });
  }

  void _showNotifications() => showModalBottomSheet<void>(
    context: context,
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12),
            Text('There are no notifications on this device.'),
          ],
        ),
      ),
    ),
  );

  Future<void> _addRecord(CalculationRecord record) async {
    await _history.add(record);
    var progress = _progress;
    for (var i = 0; i < record.calculationCount; i++) {
      progress = await _progressRepository.recordCalculation(record.createdAt);
    }
    if (!mounted) return;
    setState(() {
      _records = [record, ..._records];
      _progress = progress;
    });
  }

  Future<void> _clearHistory() async {
    await _history.clear();
    if (mounted) setState(() => _records = const []);
  }

  Future<UserProgress> _completeDailyChallenge(DateTime date) async {
    final progress = await _progressRepository.completeDailyChallenge(
      date,
      completedAt: DateTime.now(),
    );
    if (mounted) setState(() => _progress = progress);
    return progress;
  }

  Future<UserProgress> _recordLearning(
    String lessonId, {
    bool completed = false,
  }) async {
    final progress = await _progressRepository.recordLearning(
      at: DateTime.now(),
      lessonId: lessonId,
      completed: completed,
    );
    if (mounted) setState(() => _progress = progress);
    return progress;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    title: '',
    debugShowCheckedModeBanner: false,
    themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
    themeAnimationDuration: const Duration(milliseconds: 420),
    themeAnimationCurve: Curves.easeInOutCubic,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        surface: Colors.white,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 14),
        bodyMedium: TextStyle(fontSize: 12),
        bodySmall: TextStyle(fontSize: 10),
        labelLarge: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 9),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFFFE7EC),
        labelStyle: const TextStyle(fontSize: 11, color: _navy),
        side: const BorderSide(color: Color(0xFFEDE7E3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF958B87)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFECE6E2)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        dense: true,
        minVerticalPadding: 3,
        horizontalTitleGap: 10,
        iconColor: Color(0xFF746D69),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          padding: const EdgeInsets.all(8),
          visualDensity: VisualDensity.compact,
        ),
      ),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        brightness: Brightness.dark,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 14),
        bodyMedium: TextStyle(fontSize: 12),
        bodySmall: TextStyle(fontSize: 10),
        labelLarge: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 9),
      ),
    ),
    home: !_isReady
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : !_isAuthenticated
        ? AuthFlow(
            startAtWelcome: _startAtWelcome,
            authApi: _authApi,
            onAuthenticated: _onAuthenticated,
          )
        : MathevoShell(
            records: _records,
            onCalculation: _addRecord,
            darkMode: _darkMode,
            onDarkModeChanged: _setDarkMode,
            onClearHistory: _clearHistory,
            onLogOut: _logOut,
            progress: _progress,
            onDailyChallengeComplete: _completeDailyChallenge,
            onLearningActivity: (id) => _recordLearning(id),
            onLessonComplete: (id) => _recordLearning(id, completed: true),
            displayName: _displayName,
            username: _username,
            profileImagePath: _profileImagePath,
            onOpenHistory: _showHistory,
            onOpenNotifications: _showNotifications,
            onPickProfilePhoto: _pickProfilePhoto,
            onSaveProfile: _saveProfile,
          ),
  );
}
