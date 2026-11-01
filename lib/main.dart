import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show EagerGestureRecognizer;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_api.dart';
import 'auth_flow.dart';
import 'auth_token_store.dart';
import 'gamification.dart';
import 'math_engine.dart';
import 'math_history.dart';

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

enum _Destination { home, lessons, calculator, community, settings }

class MathevoShell extends StatefulWidget {
  const MathevoShell({
    super.key,
    required this.records,
    required this.onCalculation,
    required this.darkMode,
    required this.onDarkModeChanged,
    required this.onClearHistory,
    required this.onLogOut,
    required this.progress,
    required this.onDailyChallengeComplete,
    required this.onLearningActivity,
    required this.onLessonComplete,
    required this.displayName,
    required this.username,
    required this.profileImagePath,
    required this.onOpenHistory,
    required this.onOpenNotifications,
    required this.onPickProfilePhoto,
    required this.onSaveProfile,
  });

  final List<CalculationRecord> records;
  final ValueChanged<CalculationRecord> onCalculation;
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onClearHistory;
  final VoidCallback onLogOut;
  final UserProgress progress;
  final Future<UserProgress> Function(DateTime) onDailyChallengeComplete;
  final Future<UserProgress> Function(String) onLearningActivity;
  final Future<UserProgress> Function(String) onLessonComplete;
  final String displayName;
  final String username;
  final String? profileImagePath;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenNotifications;
  final VoidCallback onPickProfilePhoto;
  final Future<void> Function({
    String? name,
    String? username,
    String? imagePath,
  })
  onSaveProfile;

  @override
  State<MathevoShell> createState() => _MathevoShellState();
}

class _MathevoShellState extends State<MathevoShell> {
  _Destination _selected = _Destination.home;
  final _calculatorPageKey = GlobalKey<_CalculatorPageState>();
  bool _hideNavigation = false;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        records: widget.records,
        progress: widget.progress,
        onDailyChallengeComplete: widget.onDailyChallengeComplete,
        onOpenCalculator: () => _select(_Destination.calculator),
        onOpenLessons: () => _select(_Destination.lessons),
        onOpenCommunity: () => _select(_Destination.community),
        displayName: widget.displayName,
        username: widget.username,
        onOpenHistory: widget.onOpenHistory,
        onOpenNotifications: widget.onOpenNotifications,
      ),
      LessonsPage(
        progress: widget.progress,
        onLearningActivity: widget.onLearningActivity,
        onLessonComplete: widget.onLessonComplete,
      ),
      CalculatorPage(
        key: _calculatorPageKey,
        records: widget.records,
        onCalculation: widget.onCalculation,
        onFullscreenChanged: (value) => setState(() => _hideNavigation = value),
      ),
      CommunityPage(displayName: widget.displayName),
      SettingsPage(
        darkMode: widget.darkMode,
        onDarkModeChanged: widget.onDarkModeChanged,
        onClearHistory: widget.onClearHistory,
        onLogOut: widget.onLogOut,
        displayName: widget.displayName,
        username: widget.username,
        profileImagePath: widget.profileImagePath,
        onPickProfilePhoto: widget.onPickProfilePhoto,
        onSaveProfile: widget.onSaveProfile,
      ),
    ];
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, _) => SafeArea(
          bottom: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: IndexedStack(index: _selected.index, children: pages),
              ),
              if (!_hideNavigation)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _FloatingNavigation(
                    selected: _selected,
                    onSelect: _select,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _select(_Destination destination) {
    if (_selected == _Destination.calculator &&
        destination != _Destination.calculator) {
      _calculatorPageKey.currentState?.finishSession();
    }
    setState(() {
      _selected = destination;
      _hideNavigation = false;
    });
  }
}

class _FloatingNavigation extends StatelessWidget {
  const _FloatingNavigation({required this.selected, required this.onSelect});
  final _Destination selected;
  final ValueChanged<_Destination> onSelect;

  static const _items = [
    (destination: _Destination.home, label: 'Home', icon: Icons.home_outlined),
    (
      destination: _Destination.lessons,
      label: 'Lessons',
      icon: Icons.menu_book_outlined,
    ),
    (
      destination: _Destination.calculator,
      label: 'Calculator',
      icon: Icons.calculate_outlined,
    ),
    (
      destination: _Destination.community,
      label: 'Community',
      icon: Icons.people_outline_rounded,
    ),
    (
      destination: _Destination.settings,
      label: 'Settings',
      icon: Icons.settings_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 4),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .16),
                    blurRadius: 24,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    key: const Key('floating-navigation-capsule'),
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF202735) : Colors.white)
                          .withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFE5E8EF),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (final item in _items)
                          Expanded(
                            child: _NavItem(
                              label: item.label,
                              key: ValueKey('nav-${item.label.toLowerCase()}'),
                              icon: item.icon,
                              selected: selected == item.destination,
                              onTap: () => onSelect(item.destination),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final inactiveColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : _navy.withValues(alpha: .72);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          radius: 28,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          child: SizedBox(
            height: 58,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 17,
                      color: selected ? _accent : inactiveColor,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label == 'Calculator' ? 'Calc' : label,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: 8,
                        height: 1.05,
                        color: selected ? _accent : inactiveColor,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.records,
    required this.onOpenCalculator,
    required this.progress,
    required this.onDailyChallengeComplete,
    required this.onOpenLessons,
    required this.onOpenCommunity,
    required this.displayName,
    required this.username,
    required this.onOpenHistory,
    required this.onOpenNotifications,
  });
  final List<CalculationRecord> records;
  final VoidCallback onOpenCalculator;
  final UserProgress progress;
  final Future<UserProgress> Function(DateTime) onDailyChallengeComplete;
  final VoidCallback onOpenLessons;
  final VoidCallback onOpenCommunity;
  final String displayName;
  final String username;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenNotifications;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: '',
      subtitle: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardHeader(
            displayName: displayName,
            onHistory: onOpenHistory,
            onNotifications: onOpenNotifications,
            onLeaderboards: () => _openLeaderboard(
              context,
              displayName: displayName,
              username: username,
              progress: progress,
            ),
          ),
          const SizedBox(height: 10),
          _ProgressOverview(progress: progress),
          const SizedBox(height: 10),
          const Text(
            'Your workspace',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _DashboardGrid(
            latestCalculation: records.isEmpty ? null : records.first,
            onCalculator: onOpenCalculator,
            onLessons: onOpenLessons,
            onCommunity: onOpenCommunity,
            onGraphing: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Graphing is not available in this build yet.'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _DailyChallengeCard(
            onComplete: onDailyChallengeComplete,
            progress: progress,
          ),
          const SizedBox(height: 10),
          _LeaderboardPreview(
            displayName: displayName,
            username: username,
            progress: progress,
          ),
          const SizedBox(height: 12),
          _RecentActivity(
            records: records,
            progress: progress,
            onViewAll: onOpenHistory,
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.displayName,
    required this.onHistory,
    required this.onNotifications,
    required this.onLeaderboards,
  });
  final String displayName;
  final VoidCallback onHistory, onNotifications, onLeaderboards;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/brand/mathevo-logo.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 5),
                const Text(
                  'Mathevo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            Text(
              displayName == 'Your name'
                  ? 'Good morning'
                  : 'Good morning, $displayName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      IconButton(
        style: _headerActionStyle,
        iconSize: 17,
        onPressed: onHistory,
        tooltip: 'History',
        icon: const Icon(Icons.history_rounded),
      ),
      IconButton(
        style: _headerActionStyle,
        iconSize: 17,
        onPressed: onNotifications,
        tooltip: 'Notifications',
        icon: const Icon(Icons.notifications_none_rounded),
      ),
      IconButton(
        style: _headerActionStyle,
        iconSize: 17,
        onPressed: onLeaderboards,
        tooltip: 'Leaderboards',
        icon: const Icon(Icons.leaderboard_outlined),
      ),
    ],
  );
}

final _headerActionStyle = IconButton.styleFrom(
  foregroundColor: const Color(0xFF625B58),
  backgroundColor: Colors.white,
  minimumSize: const Size(32, 32),
  maximumSize: const Size(32, 32),
  padding: EdgeInsets.zero,
  side: const BorderSide(color: Color(0xFFF0EAE6)),
  shape: const CircleBorder(),
);

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({
    required this.latestCalculation,
    required this.onCalculator,
    required this.onLessons,
    required this.onCommunity,
    required this.onGraphing,
  });
  final CalculationRecord? latestCalculation;
  final VoidCallback onCalculator, onLessons, onCommunity, onGraphing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: constraints.maxWidth < 350 ? 1.35 : 1.65,
      children: [
        _WorkspaceTile(
          title: 'Calculator',
          subtitle: latestCalculation == null
              ? 'Solve an expression'
              : '${latestCalculation!.expression} = ${latestCalculation!.result}',
          icon: Icons.calculate_outlined,
          color: _accent,
          onTap: onCalculator,
        ),
        _WorkspaceTile(
          title: 'Graphing',
          subtitle: 'No saved graphs yet',
          icon: Icons.show_chart_rounded,
          color: const Color(0xFF16A6B5),
          onTap: onGraphing,
        ),
        _WorkspaceTile(
          title: 'Lessons',
          subtitle: 'No learning module in progress',
          icon: Icons.menu_book_outlined,
          color: const Color(0xFF8155D9),
          onTap: onLessons,
        ),
        _WorkspaceTile(
          title: 'Community',
          subtitle: 'Community feed unavailable',
          icon: Icons.people_outline_rounded,
          color: const Color(0xFF13A98D),
          onTap: onCommunity,
        ),
      ],
    ),
  );
}

class _WorkspaceTile extends StatelessWidget {
  const _WorkspaceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFEFEAE6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: color.withValues(alpha: .13),
              child: Icon(icon, color: color, size: 16),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ActivityItem {
  const _ActivityItem(this.at, this.title, this.detail, this.icon);
  final DateTime at;
  final String title, detail;
  final IconData icon;
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({
    required this.records,
    required this.progress,
    required this.onViewAll,
  });
  final List<CalculationRecord> records;
  final UserProgress progress;
  final VoidCallback onViewAll;
  @override
  Widget build(BuildContext context) {
    final activity = <_ActivityItem>[
      for (final record in records)
        _ActivityItem(
          record.createdAt,
          'Calculation',
          _calculationSummary(record),
          Icons.calculate_outlined,
        ),
      for (final dayKey in progress.completedDays)
        _challengeActivity(dayKey, progress.completionTimes[dayKey]),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent activity',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(onPressed: onViewAll, child: const Text('View history')),
          ],
        ),
        const SizedBox(height: 8),
        if (activity.isEmpty)
          const _SectionCard(
            child: Text(
              'Your calculations and completed learning activities will appear here.',
            ),
          ),
        for (final item in activity.take(10))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(13),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: .24),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: _accent.withValues(alpha: .11),
                      child: Icon(item.icon, color: _accent, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.detail.length > 52
                                ? '${item.detail.substring(0, 52)}…'
                                : item.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      TimeOfDay.fromDateTime(item.at).format(context),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  _ActivityItem _challengeActivity(String dayKey, DateTime? completedAt) {
    final date = DateTime.parse(dayKey);
    final challenge = DailyChallenge.forDate(date);
    return _ActivityItem(
      completedAt ?? date,
      'Daily challenge completed',
      challenge.expression,
      Icons.local_fire_department_outlined,
    );
  }

  String _calculationSummary(CalculationRecord record) {
    final firstLine = record.expression.split('\n').first.trim();
    final resultSeparator = firstLine.lastIndexOf(' = ');
    return resultSeparator < 0
        ? firstLine
        : firstLine.substring(0, resultSeparator).trim();
  }
}

class _ProgressOverview extends StatelessWidget {
  const _ProgressOverview({required this.progress});
  final UserProgress progress;

  @override
  Widget build(BuildContext context) {
    final days = progress.lastSevenDays;
    const weekNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'DAY STREAK',
                  value: '${progress.streakOn(DateTime.now())}',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFFF9B45),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'TOTAL XP',
                  value: '${progress.xp}',
                  icon: Icons.bolt_rounded,
                  color: _accent,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'BEST STREAK',
                  value: '${progress.bestStreak}',
                  icon: Icons.emoji_events_outlined,
                  color: const Color(0xFF7C5CE1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'This week',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
              ),
              const Spacer(),
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Tooltip(
                  message:
                      weekNames[DateTime.now()
                              .subtract(Duration(days: 6 - i))
                              .weekday -
                          1],
                  child: CircleAvatar(
                    radius: 5,
                    backgroundColor: days[i]
                        ? _accent
                        : _accent.withValues(alpha: .13),
                    child: days[i]
                        ? const Icon(Icons.check, size: 9, color: Colors.white)
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Semantics(
            image: true,
            label: label,
            child: SizedBox(
              width: 20,
              height: 22,
              child: Image.asset(
                switch (label) {
                  'DAY STREAK' => 'Animated/Fire.gif',
                  'TOTAL XP' => 'Animated/XP.gif',
                  _ => 'Animated/Trophy.gif',
                },
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) {
                  debugPrint('Unable to load dashboard GIF: $error');
                  return Icon(icon, color: color, size: 20);
                },
              ),
            ),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(letterSpacing: .1, fontSize: 8),
      ),
    ],
  );
}

class _DailyChallengeCard extends StatefulWidget {
  const _DailyChallengeCard({required this.onComplete, required this.progress});
  final Future<UserProgress> Function(DateTime) onComplete;
  final UserProgress progress;
  @override
  State<_DailyChallengeCard> createState() => _DailyChallengeCardState();
}

class _DailyChallengeCardState extends State<_DailyChallengeCard> {
  final _answer = TextEditingController();
  String? _message;
  late bool _completed = widget.progress.completedOn(_date);
  bool _busy = false;
  late final DateTime _date = DateTime.now();
  late final DailyChallenge _challenge = DailyChallenge.forDate(_date);

  @override
  void didUpdateWidget(covariant _DailyChallengeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_completed && widget.progress.completedOn(_date)) {
      _completed = true;
      _message = 'Completed today. Your XP and streak are saved.';
    }
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy || _completed) return;
    try {
      final expected = const MathEngine()
          .calculate(_challenge.expression)
          .value!;
      final entered = const MathEngine().calculate(_answer.text).value!;
      if ((expected - entered).abs() > 1e-9 * (1 + expected.abs())) {
        setState(() => _message = 'Not quite. Try another way.');
        return;
      }
      setState(() => _busy = true);
      await widget.onComplete(_date);
      if (mounted) {
        setState(() {
          _completed = true;
          _busy = false;
          _message = 'Correct! +10 XP. Come back tomorrow to grow your streak.';
        });
      }
    } catch (_) {
      setState(() => _message = 'Enter a valid numeric answer.');
    }
  }

  @override
  Widget build(BuildContext context) => _SectionCard(
    backgroundColor: const Color(0xFFFFF4F0),
    borderColor: const Color(0xFFFFD9D7),
    padding: 12,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: _accent),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'DAILY CHALLENGE',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: .6,
                ),
              ),
            ),
            Text(
              _challenge.dateKey,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _challenge.expression.replaceAll('*', 'x'),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _answer,
                  enabled: !_completed,
                  keyboardType: TextInputType.none,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Answer...',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _check(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: FilledButton(
                onPressed: _completed || _busy ? null : _check,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _completed
                      ? 'Done'
                      : _busy
                      ? 'Saving'
                      : 'Check',
                ),
              ),
            ),
          ],
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            style: TextStyle(
              color: _completed
                  ? Colors.green.shade700
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    ),
  );
}

class _LeaderboardPreview extends StatelessWidget {
  const _LeaderboardPreview({
    required this.displayName,
    required this.username,
    required this.progress,
  });
  final String displayName;
  final String username;
  final UserProgress progress;

  @override
  Widget build(BuildContext context) => _SectionCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.leaderboard_outlined, color: _accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Leaderboards',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 5),
              Text('Local rank: #1 of 1 | ${progress.xp} XP'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _openLeaderboard(
                    context,
                    displayName: displayName,
                    username: username,
                    progress: progress,
                  ),
                  child: const Text('See more'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

void _openLeaderboard(
  BuildContext context, {
  required String displayName,
  required String username,
  required UserProgress progress,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _LeaderboardDetails(
    displayName: displayName,
    username: username,
    progress: progress,
  ),
);

class _LeaderboardDetails extends StatelessWidget {
  const _LeaderboardDetails({
    required this.displayName,
    required this.username,
    required this.progress,
  });

  final String displayName;
  final String username;
  final UserProgress progress;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .78,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      children: [
        const Text(
          'Leaderboard',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text('Your ranking on this device'),
        const SizedBox(height: 18),
        _SectionCard(
          child: Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFB547)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Local rank #1 of 1',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('${progress.xp} XP'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(displayName == 'Your name' ? 'You' : displayName),
            subtitle: Text(username),
            trailing: Text('${progress.xp} XP'),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Global rankings need shared player accounts and a leaderboard service. This list shows only your real, device-local standing; it does not invent other players.',
        ),
      ],
    ),
  );
}

enum _CalculatorMode {
  basic,
  scientific,
  geometry,
  trigonometry,
  graphing,
  algebra,
  calculus,
  numberSystem,
  drawing,
}

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    super.key,
    required this.records,
    required this.onCalculation,
    required this.onFullscreenChanged,
    this.bottomPadding = 100,
  });
  final List<CalculationRecord> records;
  final ValueChanged<CalculationRecord> onCalculation;
  final ValueChanged<bool> onFullscreenChanged;
  final double bottomPadding;

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final _input = TextEditingController();
  final _numerator = TextEditingController();
  final _denominator = TextEditingController();
  final _numberA = TextEditingController();
  final _numberB = TextEditingController();
  final _geometryFirst = TextEditingController();
  final _geometrySecond = TextEditingController();
  final _integralLowerInput = TextEditingController(text: '0');
  final _integralUpperInput = TextEditingController(text: '2');
  final _drawingBoundaryKey = GlobalKey();
  final _engine = const MathEngine();
  TextRecognizer? _recognizer;
  _CalculatorMode _mode = _CalculatorMode.basic;
  bool _fractionBuilder = false;
  bool _fractionDenominatorSelected = false;
  bool _sourceEditorVisible = false;
  bool _errorDialogOpen = false;
  bool _conversionOnly = true;
  bool _recognizingDrawing = false;
  bool _answerShown = false;
  bool _showVisualization = false;
  bool _showVisualizationDetails = false;
  bool _showExpressionPlot = false;
  bool _visualIs3D = false;
  double _visualZoom = 1;
  double _visualAngle = 62;
  double _visualRotationX = -.18;
  double _visualRotationY = .28;
  Offset? _lastVisualizationPointer;
  double _visualHypotenuse = 20;
  double _geometryVisualFirst = 3;
  double _geometryVisualSecond = 4;
  double _graphSlope = 1.5;
  double _graphIntercept = 1;
  double _graphX = 2;
  double _integralLower = 0;
  double _integralUpper = 2;
  int _sourceBase = 10;
  int _targetBase = 2;
  String _numberOperator = '+';
  String _geometryOperation = 'Circle area';
  bool _geometryUsesSecond = false;
  final List<List<Offset>> _drawingStrokes = [];
  List<Offset> _activeStroke = [];
  String? _recognizedExpression;
  String? _drawingStatus;
  String? _result;
  String? _error;
  bool _resultIsExact = false;
  Timer? _drawingDebounce;
  final List<String> _sessionBreakdown = [];
  String? _sessionFinalResult;
  bool _sessionIsExact = true;
  String _calculusOperation = 'Derivative';
  bool _angleDegrees = true;
  String _triangleFunction = 'sin';
  bool _triangleHasCoefficient = false;

  @override
  void dispose() {
    _drawingDebounce?.cancel();
    _input.dispose();
    _numerator.dispose();
    _denominator.dispose();
    _numberA.dispose();
    _numberB.dispose();
    _geometryFirst.dispose();
    _geometrySecond.dispose();
    _integralLowerInput.dispose();
    _integralUpperInput.dispose();
    final recognizer = _recognizer;
    if (recognizer != null) unawaited(recognizer.close());
    super.dispose();
  }

  void _insert(String value) {
    FocusScope.of(context).unfocus();
    if (_fractionBuilder) {
      final controller = _fractionDenominatorSelected
          ? _denominator
          : _numerator;
      final selection = controller.selection;
      final start = selection.isValid
          ? selection.start
          : controller.text.length;
      final end = selection.isValid ? selection.end : controller.text.length;
      controller.value = TextEditingValue(
        text: controller.text.replaceRange(start, end, value),
        selection: TextSelection.collapsed(offset: start + value.length),
      );
      setState(() {});
      return;
    }
    if (_answerShown) {
      final isOperator = const {'+', '-', '*', '/', '^'}.contains(value);
      _input.text = isOperator ? (_result ?? '') : '';
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      _answerShown = false;
      _result = null;
    }
    final selection = _input.selection;
    final start = selection.isValid ? selection.start : _input.text.length;
    final end = selection.isValid ? selection.end : _input.text.length;
    final text = _input.text.replaceRange(start, end, value);
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    _updateResult();
  }

  void _insertFraction() {
    if (_numerator.text.trim().isEmpty || _denominator.text.trim().isEmpty) {
      _showCalculationError('Enter both a numerator and denominator.');
      return;
    }
    setState(() {
      _fractionBuilder = false;
    });
    _insert('(${_numerator.text})/(${_denominator.text})');
  }

  void _showCalculationError(String message) {
    if (!mounted || _errorDialogOpen) return;
    _errorDialogOpen = true;
    _error = message;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.error_outline_rounded),
        title: const Text('Check the expression'),
        content: Text(_error ?? message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    ).whenComplete(() {
      _error = null;
      _errorDialogOpen = false;
    });
  }

  String _mathTexFromSource(String source) {
    var tex = source.trim();
    if (tex.isEmpty) return r'\square';
    tex = tex.replaceAll('3.141592653589793', r'\pi');
    tex = tex.replaceAllMapped(
      RegExp(r'\(([^()]*)\)\s*/\s*\(([^()]*)\)'),
      (m) => '\\frac{${m[1]}}{${m[2]}}',
    );
    tex = tex.replaceAllMapped(
      RegExp(r'(?<![A-Za-z])([A-Za-z0-9.]+)\s*/\s*([A-Za-z0-9.]+)(?![A-Za-z])'),
      (m) => '\\frac{${m[1]}}{${m[2]}}',
    );
    tex = tex.replaceAllMapped(
      RegExp(r'\b(sqrt|cbrt)\(([^()]*)\)'),
      (m) => m[1] == 'sqrt' ? '\\sqrt{${m[2]}}' : '\\sqrt[3]{${m[2]}}',
    );
    tex = tex.replaceAllMapped(
      RegExp(r'\b(abs)\(([^()]*)\)'),
      (m) => r'\left|' + m[2]! + r'\right|',
    );
    tex = tex.replaceAll('(', r'\left(').replaceAll(')', r'\right)');
    tex = tex.replaceAllMapped(
      RegExp(
        r'\b(arcsin|arccos|arctan|sin|cos|tan|sec|csc|cot|log|ln)\\left\(',
      ),
      (m) => '\\${m[1]}\\left(',
    );
    tex = tex.replaceAllMapped(
      RegExp(r'\^([A-Za-z0-9]+)'),
      (m) => '^{${m[1]}}',
    );
    return tex
        .replaceAll('*', r'\times ')
        .replaceAll('/', r'\div ')
        .replaceAll('<=', r'\leq ')
        .replaceAll('>=', r'\geq ')
        .replaceAll('!=', r'\neq ')
        .replaceAll('≈', r'\approx ');
  }

  String get _expressionTex {
    if (_mode == _CalculatorMode.geometry && _input.text.trim().isEmpty) {
      return switch (_geometryOperation) {
        'Circle area' => r'A=\pi r^2',
        'Circle circumference' => r'C=2\pi r',
        'Rectangle area' => r'A=wh',
        'Rectangle perimeter' => r'P=2w+2h',
        'Triangle area' => r'A=\frac{1}{2}bh',
        'Pythagorean hypotenuse' => r'c=\sqrt{a^2+b^2}',
        'Parallelogram area' => r'A=bh',
        'Cylinder volume' => r'V=\pi r^2h',
        'Cylinder surface area' => r'SA=2\pi rh+2\pi r^2',
        'Cone volume' => r'V=\frac{1}{3}\pi r^2h',
        'Cone surface area' => r'SA=\pi r(r+\sqrt{h^2+r^2})',
        'Sphere volume' => r'V=\frac{4}{3}\pi r^3',
        'Sphere surface area' => r'SA=4\pi r^2',
        _ => r'\square',
      };
    }
    final body = _mathTexFromSource(_input.text);
    if (_mode != _CalculatorMode.calculus) return body;
    return switch (_calculusOperation) {
      'Derivative' => '\\frac{d}{dx}\\left($body\\right)',
      'Indefinite integral' => '\\int $body\\,dx',
      _ =>
        '\\int_{${_integralLowerInput.text}}^{${_integralUpperInput.text}} $body\\,dx',
    };
  }

  void _updateResult() {
    if (_mode == _CalculatorMode.algebra || _mode == _CalculatorMode.calculus) {
      setState(() {
        _result = null;
        _error = null;
        _answerShown = false;
      });
      return;
    }
    try {
      final result = _mode == _CalculatorMode.graphing
          ? MathResult(
              input: _input.text,
              value: _engine.evaluateAt(_input.text, _graphX),
              kind: MathResultKind.approximate,
              significantDigits: 12,
            )
          : _calculateExpression(_input.text);
      final formatted = result.displayValue;
      setState(() {
        _result = formatted;
        _error = null;
        _resultIsExact = result.kind == MathResultKind.exact;
        _answerShown = false;
      });
    } on MathInputException catch (error) {
      setState(() {
        _error = _input.text.trim().isEmpty ? null : error.message;
        _result = null;
        _resultIsExact = false;
        _answerShown = false;
      });
    }
  }

  String _angleAdjustedExpression(String source) {
    var result = source.replaceAllMapped(
      RegExp(r'\b(sec|csc|cot)\(([^()]*)\)'),
      (match) => switch (match[1]) {
        'sec' => '(1/cos(${match[2]}))',
        'csc' => '(1/sin(${match[2]}))',
        _ => '(1/tan(${match[2]}))',
      },
    );
    if (!_angleDegrees ||
        !{
          _CalculatorMode.scientific,
          _CalculatorMode.trigonometry,
          _CalculatorMode.geometry,
        }.contains(_mode)) {
      return result;
    }
    const toRadians = '0.017453292519943295';
    const toDegrees = '57.29577951308232';
    result = result.replaceAllMapped(
      RegExp(r'\b(sin|cos|tan)\(([^()]*)\)'),
      (match) => '${match[1]}((${match[2]})*$toRadians)',
    );
    result = result.replaceAllMapped(
      RegExp(r'\b(arcsin|arccos|arctan)\(([^()]*)\)'),
      (match) => '((${match[1]}(${match[2]}))*$toDegrees)',
    );
    return result;
  }

  MathResult _calculateExpression(String source) =>
      _engine.calculate(_angleAdjustedExpression(source));

  void _evaluate() {
    FocusScope.of(context).unfocus();
    final expression = _input.text.trim();
    if (expression.isEmpty) return;
    try {
      if (_mode == _CalculatorMode.geometry) {
        _calculateGeometry(commit: true);
        return;
      }
      if (_mode == _CalculatorMode.algebra) {
        final answer = expression.contains(';')
            ? _engine.solveLinearSystem(expression).display
            : _engine.solveEquation(expression).display;
        setState(() {
          _result = answer;
          _error = null;
          _resultIsExact = false;
          _answerShown = true;
        });
        _appendSessionEntry(expression, answer, exact: false);
        return;
      }
      if (_mode == _CalculatorMode.calculus) {
        if (_calculusOperation == 'Derivative') {
          final derivative = _engine.differentiate(expression);
          final answer = 'd/dx = $derivative';
          setState(() {
            _result = answer;
            _error = null;
            _resultIsExact = true;
            _answerShown = true;
          });
          _appendSessionEntry('d/dx ($expression)', derivative, exact: true);
          return;
        }
        if (_calculusOperation == 'Indefinite integral') {
          final answer = _engine.integrateIndefinite(expression);
          setState(() {
            _result = answer;
            _error = null;
            _resultIsExact = true;
            _answerShown = true;
          });
          _appendSessionEntry('Integral of $expression', answer, exact: true);
          return;
        }
        final lower = double.parse(_integralLowerInput.text.trim());
        final upper = double.parse(_integralUpperInput.text.trim());
        final calculation = _engine.integrateDefinite(
          expression,
          lower: lower,
          upper: upper,
        );
        final answer = '\u2248 ${calculation.displayValue}';
        setState(() {
          _result = answer;
          _error = null;
          _resultIsExact = false;
          _answerShown = true;
        });
        _appendSessionEntry(
          '\u222B[$lower,$upper] $expression dx',
          answer,
          exact: false,
        );
        return;
      }
      if (_mode == _CalculatorMode.graphing) {
        final value = _engine.evaluateAt(expression, _graphX);
        final answer =
            'f(${_graphX.toStringAsFixed(2)}) = ${formatApproximateValue(value)}';
        setState(() {
          _result = answer;
          _error = null;
          _resultIsExact = false;
          _answerShown = true;
        });
        _appendSessionEntry(
          'f(x) = $expression; x = $_graphX',
          answer,
          exact: false,
        );
        return;
      }
      final calculation = _calculateExpression(expression);
      final answer = '\u2248 ${calculation.displayValue}';
      setState(() {
        _result = answer;
        _error = null;
        _resultIsExact = calculation.kind == MathResultKind.exact;
        _answerShown = true;
      });
      _appendSessionEntry(
        expression,
        answer,
        exact: calculation.kind == MathResultKind.exact,
      );
    } on MathInputException catch (error) {
      setState(() {
        _result = null;
        _answerShown = false;
        _error = error.message;
      });
      _showCalculationError(error.message);
    } on Object {
      final message = _mode == _CalculatorMode.calculus
          ? 'Enter a valid expression and finite numeric bounds.'
          : 'Check the equation and try again.';
      setState(() {
        _result = null;
        _answerShown = false;
        _error = message;
      });
      _showCalculationError(message);
    }
  }

  void _calculateGeometry({bool commit = false}) {
    try {
      final first = double.parse(_geometryFirst.text.trim());
      final second = double.tryParse(_geometrySecond.text.trim()) ?? 0;
      final needsSecond = const {
        'Rectangle area',
        'Rectangle perimeter',
        'Triangle area',
        'Pythagorean hypotenuse',
        'Parallelogram area',
        'Cylinder volume',
        'Cylinder surface area',
        'Cone volume',
        'Cone surface area',
      }.contains(_geometryOperation);
      if (!first.isFinite || (needsSecond && !second.isFinite)) {
        throw const FormatException();
      }
      if (first < 0 || (needsSecond && second < 0)) {
        throw const MathInputException('Lengths cannot be negative.');
      }
      final result = switch (_geometryOperation) {
        'Circle area' => math.pi * first * first,
        'Circle circumference' => 2 * math.pi * first,
        'Rectangle area' => first * second,
        'Rectangle perimeter' => 2 * (first + second),
        'Triangle area' => first * second / 2,
        'Parallelogram area' => first * second,
        'Pythagorean hypotenuse' => math.sqrt(first * first + second * second),
        'Cylinder volume' => math.pi * first * first * second,
        'Cylinder surface area' => 2 * math.pi * first * (first + second),
        'Cone volume' => math.pi * first * first * second / 3,
        'Cone surface area' =>
          math.pi *
              first *
              (first + math.sqrt(first * first + second * second)),
        'Sphere volume' => 4 / 3 * math.pi * first * first * first,
        'Sphere surface area' => 4 * math.pi * first * first,
        _ => throw const MathInputException('Select a geometry operation.'),
      };
      final answer = formatApproximateValue(result);
      final expression = _geometryExpression(first, second);
      setState(() {
        _input.text = expression;
        _result = answer;
        _error = null;
        _resultIsExact = false;
        _answerShown = commit;
      });
      if (commit) _appendSessionEntry(expression, answer, exact: false);
    } on MathInputException catch (error) {
      setState(() {
        _error = error.message;
        _result = null;
        _answerShown = false;
      });
      if (commit) _showCalculationError(error.message);
    } on Object {
      const message = 'Enter valid non-negative dimensions.';
      setState(() {
        _error = message;
        _result = null;
        _answerShown = false;
      });
      if (commit) _showCalculationError(message);
    }
  }

  String _numberForExpression(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  String _geometryExpression(double first, double second) {
    final a = _numberForExpression(first);
    final b = _numberForExpression(second);
    const pi = '3.141592653589793';
    return switch (_geometryOperation) {
      'Circle area' => '$pi*($a)^2',
      'Circle circumference' => '2*$pi*$a',
      'Rectangle area' => '$a*$b',
      'Rectangle perimeter' => '2*$a+2*$b',
      'Triangle area' => '($a*$b)/2',
      'Pythagorean hypotenuse' => 'sqrt($a^2+$b^2)',
      'Parallelogram area' => '$a*$b',
      'Cylinder volume' => '$pi*($a)^2*$b',
      'Cylinder surface area' => '2*$pi*$a*$b+2*$pi*($a)^2',
      'Cone volume' => '($pi*($a)^2*$b)/3',
      'Cone surface area' => '$pi*$a*($a+sqrt($b^2+$a^2))',
      'Sphere volume' => '(4*$pi*($a)^3)/3',
      'Sphere surface area' => '4*$pi*($a)^2',
      _ => a,
    };
  }

  void _pressGeometryDigit(String key) {
    FocusScope.of(context).unfocus();
    final controller = _geometryUsesSecond ? _geometrySecond : _geometryFirst;
    if (key == 'C') {
      controller.clear();
      _input.clear();
    } else {
      final selection = controller.selection;
      final start = selection.isValid
          ? selection.start
          : controller.text.length;
      final end = selection.isValid ? selection.end : controller.text.length;
      final value = key == 'DEL'
          ? controller.text.replaceRange(
              start == end && start > 0 ? start - 1 : start,
              end,
              '',
            )
          : controller.text.replaceRange(start, end, key);
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(
          offset: key == 'DEL' && start == end && start > 0
              ? start - 1
              : start + key.length,
        ),
      );
    }
    _calculateGeometry();
  }

  void _appendSessionEntry(
    String expression,
    String result, {
    required bool exact,
  }) {
    _sessionBreakdown.add('${_prettyExpression(expression)} = $result');
    _sessionFinalResult = result;
    _sessionIsExact = _sessionIsExact && exact;
  }

  void finishSession() {
    if (_sessionBreakdown.isEmpty || _sessionFinalResult == null) return;
    final record = CalculationRecord(
      expression: _sessionBreakdown.join('\n'),
      result: _sessionFinalResult!,
      createdAt: DateTime.now(),
      isExact: _sessionIsExact,
      calculationCount: _sessionBreakdown.length,
    );
    _sessionBreakdown.clear();
    _sessionFinalResult = null;
    _sessionIsExact = true;
    _input.clear();
    _result = null;
    _answerShown = false;
    widget.onCalculation(record);
  }

  void continueWithHistory(CalculationRecord record) {
    setState(() {
      _sessionBreakdown
        ..clear()
        ..addAll(
          record.expression.split('\n').where((line) => line.trim().isNotEmpty),
        );
      _sessionFinalResult = record.result;
      _sessionIsExact = record.isExact;
      _input.text = record.result;
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      _result = record.result;
      _answerShown = true;
      _error = null;
    });
  }

  String _prettyExpression(String expression) => expression
      .replaceAllMapped(RegExp(r'([+*/^])'), (match) => ' ${match[0]} ')
      .replaceAllMapped(RegExp(r'(?<!^)(?<!e)-'), (match) => ' - ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void _exitDrawingMode() {
    setState(() {
      _mode = _CalculatorMode.basic;
      _answerShown = false;
    });
    widget.onFullscreenChanged(false);
  }

  void _calculateNumberSystem({bool commit = false}) {
    try {
      if (_numberA.text.trim().isEmpty ||
          (!_conversionOnly && _numberB.text.trim().isEmpty)) {
        setState(() {
          _result = null;
          _error = null;
          _answerShown = false;
        });
        return;
      }
      final first = BigInt.parse(_numberA.text.trim(), radix: _sourceBase);
      var answer = first;
      BigInt? divisionRemainder;
      var expression = '${_numberA.text.trim()} (base $_sourceBase)';
      if (!_conversionOnly) {
        final second = BigInt.parse(_numberB.text.trim(), radix: _sourceBase);
        expression =
            '${_numberA.text.trim()} $_numberOperator '
            '${_numberB.text.trim()} (base $_sourceBase)';
        if ((_numberOperator == '<<' || _numberOperator == '>>') &&
            (second.isNegative || second > BigInt.from(4096))) {
          throw const FormatException('Shift amount must be from 0 to 4096.');
        }
        answer = switch (_numberOperator) {
          '+' => first + second,
          '-' => first - second,
          '*' => first * second,
          '&' => first & second,
          '|' => first | second,
          '^' => first ^ second,
          '%' when second != BigInt.zero => first.remainder(second),
          '%' => throw const FormatException('Cannot divide by zero.'),
          '<<' => first << second.toInt(),
          '>>' => first >> second.toInt(),
          '/' when second != BigInt.zero => first ~/ second,
          '/' => throw const FormatException('Cannot divide by zero.'),
          _ => first,
        };
        if (_numberOperator == '/') {
          divisionRemainder = first.remainder(second);
        }
      }
      final converted = answer.toRadixString(_targetBase).toUpperCase();
      final remainder =
          divisionRemainder == null || divisionRemainder == BigInt.zero
          ? ''
          : ' r ${divisionRemainder.toRadixString(_targetBase).toUpperCase()}';
      final result = '$converted$remainder (base $_targetBase)';
      setState(() {
        _result = result;
        _error = null;
        _answerShown = commit;
      });
      if (commit) _appendSessionEntry(expression, result, exact: true);
    } on FormatException catch (error) {
      final message = error.message.toString().contains('divide')
          ? 'Cannot divide by zero.'
          : error.message.toString().contains('Shift amount')
          ? error.message.toString()
          : 'Use digits valid for base $_sourceBase.';
      setState(() {
        _result = null;
        _error = message;
        _answerShown = false;
      });
      if (commit) _showCalculationError(message);
    }
  }

  void _scheduleDrawingRecognition() {
    _drawingDebounce?.cancel();
    _drawingDebounce = Timer(
      const Duration(milliseconds: 1400),
      _recognizeDrawing,
    );
  }

  Future<void> _recognizeDrawing() async {
    if (_drawingStrokes.isEmpty || _recognizingDrawing || !mounted) return;
    final renderObject = _drawingBoundaryKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;
    setState(() {
      _recognizingDrawing = true;
      _drawingStatus = 'Reading the expression...';
    });
    Directory? tempDirectory;
    try {
      final image = await renderObject.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw const FormatException();
      tempDirectory = await Directory.systemTemp.createTemp('mathverse-draw-');
      final file = File('${tempDirectory.path}/expression.png');
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final recognizer = _recognizer ??= TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      final expression = recognized.text
          .replaceAll(
            RegExp(r'\b(times|multiply by)\b', caseSensitive: false),
            '*',
          )
          .replaceAll(
            RegExp(r'\b(divided by|over)\b', caseSensitive: false),
            '/',
          )
          .replaceAll(RegExp(r'\b(plus)\b', caseSensitive: false), '+')
          .replaceAll(RegExp(r'\b(minus)\b', caseSensitive: false), '-')
          .replaceAll(String.fromCharCode(0x00D7), '*')
          .replaceAll('x', '*')
          .replaceAll('X', '*')
          .replaceAll(String.fromCharCode(0x00F7), '/')
          .replaceAll(String.fromCharCode(0x2212), '-')
          .replaceAll(String.fromCharCode(0x2013), '-')
          .replaceAll(String.fromCharCode(0x03C0), '3.141592653589793')
          .replaceAll(RegExp(r'(?<=\d)[oO](?=\d|\b)'), '0')
          .replaceAll(RegExp(r'(?<=\d)[Il|](?=\d|\b)'), '1')
          .replaceAll(
            RegExp(r'\bpi\b', caseSensitive: false),
            '3.141592653589793',
          )
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r'[^0-9.+\-*/^()]'), '');
      if (expression.isEmpty) {
        const message = 'No expression recognized. Write larger and clearer.';
        setState(() {
          _recognizedExpression = null;
          _result = null;
          _drawingStatus = 'Could not read the handwriting.';
        });
        _showCalculationError(message);
        return;
      }
      final result = _engine.calculate(expression);
      setState(() {
        _recognizedExpression = expression;
        _result = result.displayValue;
        _resultIsExact = result.kind == MathResultKind.exact;
        _answerShown = true;
        _error = null;
        _drawingStatus = 'Solved automatically';
      });
      _appendSessionEntry(
        'Handwritten: ${_prettyExpression(expression)}',
        result.displayValue,
        exact: result.kind == MathResultKind.exact,
      );
    } on MathInputException catch (error) {
      final message = 'Recognized text could not be solved: ${error.message}';
      setState(() {
        _recognizedExpression = null;
        _result = null;
        _drawingStatus = 'Expression read, but unsupported.';
      });
      _showCalculationError(message);
    } on Object {
      const message = 'Could not read the drawing. Write larger and clearer.';
      setState(() {
        _drawingStatus = 'Recognition failed.';
      });
      _showCalculationError(message);
    } finally {
      if (tempDirectory != null) await tempDirectory.delete(recursive: true);
      if (mounted) setState(() => _recognizingDrawing = false);
    }
  }

  void _clearDrawing() {
    _drawingDebounce?.cancel();
    setState(() {
      _drawingStrokes.clear();
      _activeStroke = [];
      _recognizedExpression = null;
      _drawingStatus = null;
      _result = null;
      _error = null;
    });
  }

  void _undoDrawingStroke() {
    _drawingDebounce?.cancel();
    setState(() {
      if (_activeStroke.isNotEmpty) {
        _activeStroke = [];
      } else if (_drawingStrokes.isNotEmpty) {
        _drawingStrokes.removeLast();
      }
      _recognizedExpression = null;
      _drawingStatus = null;
      _result = null;
    });
  }

  void _pressFunction(String key) {
    FocusScope.of(context).unfocus();
    if (key.startsWith('CALC_')) {
      setState(() {
        _calculusOperation = switch (key) {
          'CALC_DERIVATIVE' => 'Derivative',
          'CALC_INTEGRAL' => 'Indefinite integral',
          _ => 'Definite integral',
        };
        _result = null;
        _answerShown = false;
      });
    } else if (_fractionBuilder && key == 'C') {
      (_fractionDenominatorSelected ? _denominator : _numerator).clear();
      setState(() {});
    } else if (_fractionBuilder && key == 'DEL') {
      final controller = _fractionDenominatorSelected
          ? _denominator
          : _numerator;
      if (controller.text.isNotEmpty) {
        controller.text = controller.text.substring(
          0,
          controller.text.length - 1,
        );
      }
    } else if (key == 'C') {
      _input.clear();
      _updateResult();
    } else if (key == 'DEL') {
      final selection = _input.selection;
      var start = selection.isValid
          ? selection.start
          : (_input.text.isEmpty ? 0 : _input.text.length - 1);
      final end = selection.isValid ? selection.end : _input.text.length;
      if (selection.isValid && start == end && start > 0) start--;
      _input.value = TextEditingValue(
        text: _input.text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
      );
      _updateResult();
    } else if (key == 'a/b') {
      FocusScope.of(context).unfocus();
      setState(() {
        _fractionBuilder = true;
        _fractionDenominatorSelected = false;
        _sourceEditorVisible = false;
        _answerShown = false;
        _result = null;
        _numerator.clear();
        _denominator.clear();
      });
    } else if (key == 'EVAL') {
      _evaluate();
    } else {
      _insert(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _CalculatorMode.drawing) {
      return _buildDrawingCalculator(context);
    }
    final child = _showVisualization
        ? _buildVisualization(context)
        : _buildCalculator(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 650),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0015)
            ..rotateY((1 - animation.value) * math.pi / 2),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_showVisualization ? 'visualization' : 'calculator'),
        child: child,
      ),
    );
  }

  Widget _buildCalculator(BuildContext context) {
    return _PageFrame(
      title: '',
      subtitle: '',
      bottomPadding: widget.bottomPadding,
      fillAvailable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final mode in _CalculatorMode.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(switch (mode) {
                              _CalculatorMode.basic => 'Basic',
                              _CalculatorMode.scientific => 'Scientific',
                              _CalculatorMode.geometry => 'Geometry',
                              _CalculatorMode.trigonometry => 'Trigonometry',
                              _CalculatorMode.graphing => 'Graphing',
                              _CalculatorMode.algebra => 'Algebra',
                              _CalculatorMode.calculus => 'Integral calculus',
                              _CalculatorMode.numberSystem => 'Number systems',
                              _CalculatorMode.drawing => 'Draw',
                            }),
                            selected: _mode == mode,
                            onSelected: (_) {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _mode = mode;
                                _showVisualization = false;
                                _sourceEditorVisible = false;
                                _error = null;
                                _result = null;
                                _answerShown = false;
                                _recognizedExpression = null;
                                if (mode == _CalculatorMode.drawing) {
                                  _drawingStrokes.clear();
                                  _activeStroke = [];
                                  _drawingStatus = null;
                                }
                              });
                              widget.onFullscreenChanged(
                                mode == _CalculatorMode.drawing,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_mode != _CalculatorMode.numberSystem &&
                  _mode != _CalculatorMode.drawing)
                IconButton.filledTonal(
                  tooltip: 'Flip to visualization',
                  onPressed: _openVisualization,
                  icon: const Icon(Icons.view_in_ar_rounded),
                ),
            ],
          ),
          const SizedBox(height: 5),
          if ({
            _CalculatorMode.scientific,
            _CalculatorMode.trigonometry,
          }.contains(_mode)) ...[
            Align(
              alignment: Alignment.centerRight,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('DEG')),
                  ButtonSegment(value: false, label: Text('RAD')),
                ],
                selected: {_angleDegrees},
                onSelectionChanged: (selection) {
                  setState(() => _angleDegrees = selection.first);
                  _updateResult();
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (_mode == _CalculatorMode.numberSystem)
            _buildNumberSystemCalculator(context)
          else if (_mode == _CalculatorMode.drawing)
            _buildDrawingCalculator(context)
          else if (_mode == _CalculatorMode.geometry)
            Expanded(child: _buildGeometryCalculator(context, fill: true))
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_mode == _CalculatorMode.algebra) ...[
                    const Text(
                      'Solve linear/quadratic equations in x, or enter a 2×2 system separated by ;.',
                    ),
                    const SizedBox(height: 5),
                  ],
                  if (_mode == _CalculatorMode.calculus) ...[
                    Wrap(
                      spacing: 6,
                      children: [
                        ChoiceChip(
                          label: const Text('Derivative'),
                          selected: _calculusOperation == 'Derivative',
                          onSelected: (_) => setState(() {
                            _calculusOperation = 'Derivative';
                            _result = null;
                            _answerShown = false;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Indefinite integral'),
                          selected: _calculusOperation == 'Indefinite integral',
                          onSelected: (_) => setState(() {
                            _calculusOperation = 'Indefinite integral';
                            _result = null;
                            _answerShown = false;
                          }),
                        ),
                        ChoiceChip(
                          label: const Text('Definite integral'),
                          selected: _calculusOperation == 'Definite integral',
                          onSelected: (_) => setState(() {
                            _calculusOperation = 'Definite integral';
                            _result = null;
                            _answerShown = false;
                          }),
                        ),
                      ],
                    ),
                    if (_calculusOperation == 'Definite integral') ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _integralLowerInput,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Lower bound',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _integralUpperInput,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Upper bound',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 5),
                  ],
                  Expanded(
                    child: _buildExpressionAnswer(context, expand: true),
                  ),
                  const SizedBox(height: 5),
                  _buildFunctionRow(),
                  const SizedBox(height: 3),
                  _buildResponsiveKeypad(context),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String get _visualizationTitle => switch (_mode) {
    _CalculatorMode.geometry => 'Geometry workspace',
    _CalculatorMode.trigonometry => 'Trigonometry: right triangle',
    _CalculatorMode.algebra => 'Algebra: equations and systems',
    _CalculatorMode.calculus => 'Calculus: function and area',
    _ => 'Function graph',
  };
  double get _visualizationValue {
    if (_mode == _CalculatorMode.geometry) {
      final a = _geometryVisualFirst;
      final b = _geometryVisualSecond;
      return switch (_geometryOperation) {
        'Circle area' => math.pi * a * a,
        'Circle circumference' => 2 * math.pi * a,
        'Rectangle area' => a * b,
        'Rectangle perimeter' => 2 * (a + b),
        'Triangle area' => a * b / 2,
        'Pythagorean hypotenuse' => math.sqrt(a * a + b * b),
        'Parallelogram area' => a * b,
        'Cylinder volume' => math.pi * a * a * b,
        'Cylinder surface area' => 2 * math.pi * a * (a + b),
        'Cone volume' => math.pi * a * a * b / 3,
        'Cone surface area' => math.pi * a * (a + math.sqrt(a * a + b * b)),
        'Sphere volume' => 4 / 3 * math.pi * a * a * a,
        'Sphere surface area' => 4 * math.pi * a * a,
        _ => double.nan,
      };
    }
    if (_mode == _CalculatorMode.trigonometry) {
      final radians = _visualAngle * math.pi / 180;
      return switch (_triangleFunction) {
        'cos' =>
          _triangleHasCoefficient
              ? _visualHypotenuse * math.cos(radians)
              : math.cos(radians),
        'tan' =>
          (_triangleHasCoefficient ? _visualHypotenuse : 1) * math.tan(radians),
        _ =>
          _triangleHasCoefficient
              ? _visualHypotenuse * math.sin(radians)
              : math.sin(radians),
      };
    }
    if (_mode == _CalculatorMode.calculus) {
      try {
        final expression = _input.text.trim().isEmpty ? 'x^2' : _input.text;
        return switch (_calculusOperation) {
          'Derivative' => _engine.evaluateAt(
            _engine.differentiate(expression),
            _graphX,
          ),
          'Indefinite integral' => _engine.evaluateAt(
            _engine
                .integrateIndefinite(expression)
                .replaceFirst(RegExp(r'\s*\+\s*C$'), ''),
            _graphX,
          ),
          _ =>
            _engine
                .integrateDefinite(
                  expression,
                  lower: _integralLower,
                  upper: _integralUpper,
                )
                .value!,
        };
      } on Object {
        return double.nan;
      }
    }
    if (_mode == _CalculatorMode.graphing && _input.text.trim().isNotEmpty) {
      try {
        return _engine.evaluateAt(_input.text, _graphX);
      } on Object {
        return double.nan;
      }
    }
    return _graphSlope * _graphX + _graphIntercept;
  }

  String get _visualizationFormula {
    if (_mode == _CalculatorMode.geometry) {
      return _geometryExpression(_geometryVisualFirst, _geometryVisualSecond);
    }
    if (_mode == _CalculatorMode.trigonometry) {
      return switch (_triangleFunction) {
        'cos' => _triangleHasCoefficient ? 'H * cos(theta)' : 'cos(theta)',
        'tan' =>
          _triangleHasCoefficient
              ? 'H * tan(theta)'
              : 'tan(theta) = opposite / adjacent',
        _ => _triangleHasCoefficient ? 'H * sin(theta)' : 'sin(theta)',
      };
    }
    if (_mode == _CalculatorMode.calculus) {
      final expression = _input.text.trim().isEmpty ? 'x^2' : _input.text;
      return switch (_calculusOperation) {
        'Derivative' =>
          "Derivative of $expression at x=${_graphX.toStringAsFixed(1)}",
        'Indefinite integral' => 'Antiderivative of $expression',
        _ =>
          'Integral of $expression from ${_integralLower.toStringAsFixed(1)} to ${_integralUpper.toStringAsFixed(1)}',
      };
    }
    if (_mode == _CalculatorMode.graphing && _input.text.trim().isNotEmpty) {
      return 'f(x) = ${_input.text}';
    }
    return 'f(${_graphX.toStringAsFixed(1)}) = ${_graphSlope.toStringAsFixed(1)} * ${_graphX.toStringAsFixed(1)} + ${_graphIntercept.toStringAsFixed(1)}';
  }

  String get _visualizationFormulaTex {
    if (_mode == _CalculatorMode.calculus) {
      final body = _mathTexFromSource(
        _input.text.trim().isEmpty ? 'x^2' : _input.text,
      );
      return switch (_calculusOperation) {
        'Derivative' =>
          '\\left.\\frac{d}{dx}\\left($body\\right)\\right|_{x=${_numberForExpression(_graphX)}}',
        'Indefinite integral' => '\\int $body\\,dx',
        _ =>
          '\\int_{${_numberForExpression(_integralLower)}}^{${_numberForExpression(_integralUpper)}} $body\\,dx',
      };
    }
    return _mathTexFromSource(_visualizationFormula);
  }

  void _openVisualization() {
    _showVisualizationDetails = false;
    _showExpressionPlot = false;
    _visualZoom = 1;
    final expression = _input.text.toLowerCase().replaceAll(' ', '');
    if (_mode == _CalculatorMode.geometry) {
      _geometryVisualFirst = double.tryParse(_geometryFirst.text) ?? 3;
      _geometryVisualSecond = double.tryParse(_geometrySecond.text) ?? 4;
      _visualIs3D = const {
        'Cylinder volume',
        'Cylinder surface area',
        'Cone volume',
        'Cone surface area',
        'Sphere volume',
        'Sphere surface area',
      }.contains(_geometryOperation);
    } else if (_mode == _CalculatorMode.trigonometry) {
      final trig = RegExp(
        r'^(\d+(?:\.\d+)?)\*?(?:sin|cos|tan)\((\d+(?:\.\d+)?)\)',
      ).firstMatch(expression);
      _triangleFunction =
          RegExp(r'(sin|cos|tan)\(').firstMatch(expression)?.group(1) ?? 'sin';
      _triangleHasCoefficient = trig != null;
      if (trig != null) {
        _visualHypotenuse =
            double.tryParse(trig.group(1)!) ?? _visualHypotenuse;
        final rawAngle = double.tryParse(trig.group(2)!) ?? _visualAngle;
        _visualAngle = (_angleDegrees ? rawAngle : rawAngle * 180 / math.pi)
            .clamp(5, 85)
            .toDouble();
      } else {
        final angle = RegExp(
          r'(?:theta|angle|θ|(?:sin|cos|tan)\()=?(-?\d+(?:\.\d+)?)',
        ).firstMatch(expression);
        if (angle != null) {
          final rawAngle = double.tryParse(angle.group(1)!) ?? _visualAngle;
          _visualAngle = (_angleDegrees ? rawAngle : rawAngle * 180 / math.pi)
              .clamp(5, 85)
              .toDouble();
        }
        final hypotenuse = RegExp(
          r'(?:hyp|hypotenuse|h)=?(\d+(?:\.\d+)?)',
        ).firstMatch(expression);
        if (hypotenuse != null) {
          _visualHypotenuse =
              (double.tryParse(hypotenuse.group(1)!) ?? _visualHypotenuse)
                  .clamp(1, 30)
                  .toDouble();
        }
      }
    } else if (_mode == _CalculatorMode.algebra ||
        _mode == _CalculatorMode.graphing) {
      final linear = RegExp(
        r'^y=([-+]?(?:\d+(?:\.\d*)?|\.\d+))\*?x(?:([-+](?:\d+(?:\.\d*)?|\.\d+)))?$',
      ).firstMatch(expression);
      if (linear != null) {
        _graphSlope = double.tryParse(linear.group(1)!) ?? _graphSlope;
        _graphIntercept = double.tryParse(linear.group(2) ?? '0') ?? 0;
      }
    }
    if (_mode == _CalculatorMode.calculus &&
        _calculusOperation == 'Definite integral') {
      _integralLower =
          double.tryParse(_integralLowerInput.text) ?? _integralLower;
      _integralUpper =
          double.tryParse(_integralUpperInput.text) ?? _integralUpper;
      if (_integralLower > _integralUpper) {
        final swap = _integralLower;
        _integralLower = _integralUpper;
        _integralUpper = swap;
      }
    }
    setState(() => _showVisualization = true);
  }

  void _returnFromVisualization() {
    if (_mode == _CalculatorMode.geometry) {
      _geometryFirst.text = _numberForExpression(_geometryVisualFirst);
      _geometrySecond.text = _numberForExpression(_geometryVisualSecond);
      final expression = _geometryExpression(
        _geometryVisualFirst,
        _geometryVisualSecond,
      );
      setState(() {
        _input.text = expression;
        _result = null;
        _answerShown = false;
        _showVisualization = false;
      });
      return;
    }
    if (_mode == _CalculatorMode.calculus) {
      _integralLowerInput.text = _numberForExpression(_integralLower);
      _integralUpperInput.text = _numberForExpression(_integralUpper);
      setState(() {
        _answerShown = false;
        _result = null;
        _showVisualization = false;
      });
      return;
    }
    if (_mode == _CalculatorMode.trigonometry) {
      final angle = _angleDegrees ? _visualAngle : _visualAngle * math.pi / 180;
      final factor = _triangleHasCoefficient
          ? '${_numberForExpression(_visualHypotenuse)}*'
          : '';
      setState(() {
        _input.text =
            '$factor$_triangleFunction(${_numberForExpression(angle)})';
        _result = null;
        _answerShown = false;
        _showVisualization = false;
      });
      return;
    }
    if (_mode == _CalculatorMode.graphing || _mode == _CalculatorMode.algebra) {
      final expr =
          '${_numberForExpression(_graphSlope)}*x${_graphIntercept < 0 ? '' : '+'}${_numberForExpression(_graphIntercept)}';
      setState(() {
        _input.text = _mode == _CalculatorMode.algebra ? '$expr=0' : expr;
        _result = null;
        _answerShown = false;
        _showVisualization = false;
      });
      return;
    }
    final value = _visualizationValue;
    if (!value.isFinite) {
      _showCalculationError(
        'This expression cannot be evaluated at the selected values.',
      );
      setState(() {
        _showVisualization = false;
      });
      return;
    }
    final answer = value.toStringAsFixed(4);
    _input.text = answer;
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _result = answer;
    _resultIsExact = false;
    _answerShown = false;
    setState(() => _showVisualization = false);
  }

  Widget _buildVisualization(BuildContext context) {
    final isGeometry = _mode == _CalculatorMode.geometry;
    final isTriangle = _mode == _CalculatorMode.trigonometry;
    final colors = Theme.of(context).colorScheme;
    return _PageFrame(
      title: 'Visualization',
      subtitle: _visualizationTitle,
      bottomPadding: widget.bottomPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: _returnFromVisualization,
                  icon: const Icon(Icons.flip_to_back_rounded),
                  label: const Text('Flip back to calculator'),
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                ),
              ),
              TextButton.icon(
                key: const Key('visualization-plot-toggle'),
                onPressed: () => setState(() {
                  _showVisualizationDetails = false;
                  _showExpressionPlot = !_showExpressionPlot;
                }),
                icon: Icon(
                  _showExpressionPlot
                      ? Icons.view_in_ar_rounded
                      : Icons.show_chart_rounded,
                ),
                label: Text(_showExpressionPlot ? 'Model' : 'Plot'),
              ),
              TextButton.icon(
                key: const Key('visualization-details-toggle'),
                onPressed: () => setState(() {
                  _showExpressionPlot = false;
                  _showVisualizationDetails = !_showVisualizationDetails;
                }),
                icon: Icon(
                  _showVisualizationDetails
                      ? Icons.view_in_ar_rounded
                      : Icons.flip_rounded,
                ),
                label: Text(_showVisualizationDetails ? 'Model' : 'Details'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('2D')),
              ButtonSegment(value: true, label: Text('3D')),
            ],
            selected: {_visualIs3D},
            onSelectionChanged: (selection) =>
                setState(() => _visualIs3D = selection.first),
          ),
          const SizedBox(height: 10),
          Container(
            height: 310,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2230),
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: _visualIs3D && !_showVisualizationDetails
                        ? {
                            EagerGestureRecognizer:
                                GestureRecognizerFactoryWithHandlers<
                                  EagerGestureRecognizer
                                >(EagerGestureRecognizer.new, (recognizer) {}),
                          }
                        : const {},
                    child: Listener(
                      onPointerDown: (event) =>
                          _lastVisualizationPointer = event.localPosition,
                      onPointerMove: (event) {
                        final previous = _lastVisualizationPointer;
                        if (!_visualIs3D ||
                            _showVisualizationDetails ||
                            previous == null) {
                          return;
                        }
                        final delta = event.localPosition - previous;
                        _lastVisualizationPointer = event.localPosition;
                        setState(() {
                          const fullTurn = 2 * math.pi;
                          _visualRotationY =
                              (_visualRotationY + delta.dx * .008) % fullTurn;
                          _visualRotationX =
                              (_visualRotationX + delta.dy * .008) % fullTurn;
                        });
                      },
                      onPointerUp: (_) => _lastVisualizationPointer = null,
                      onPointerCancel: (_) => _lastVisualizationPointer = null,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) =>
                            AnimatedBuilder(
                              animation: animation,
                              child: child,
                              builder: (context, child) => Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, .001)
                                  ..rotateY(
                                    (1 - animation.value) * math.pi / 2,
                                  ),
                                child: child,
                              ),
                            ),
                        child: _showVisualizationDetails
                            ? _buildVisualizationDetails(context)
                            : CustomPaint(
                                key: const Key('visualization-canvas'),
                                painter: _MathVisualizationPainter(
                                  mode: _mode,
                                  is3D: _visualIs3D,
                                  zoom: _visualZoom,
                                  expressionPlot: _showExpressionPlot,
                                  calculusOperation: _calculusOperation,
                                  rotationX: _visualRotationX,
                                  rotationY: _visualRotationY,
                                  angle: _visualAngle,
                                  hypotenuse: _visualHypotenuse,
                                  slope: _graphSlope,
                                  intercept: _graphIntercept,
                                  lower: _integralLower,
                                  upper: _integralUpper,
                                  selectedX: _graphX,
                                  expression: _input.text,
                                  geometryOperation: _geometryOperation,
                                  geometryFirst: _geometryVisualFirst,
                                  geometrySecond: _geometryVisualSecond,
                                ),
                                child: const SizedBox.expand(),
                              ),
                      ),
                    ),
                  ),
                ),
                if (_visualIs3D && !_showVisualizationDetails)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Column(
                      children: [
                        _VisualizationZoomButton(
                          icon: Icons.add_rounded,
                          label: 'Zoom in',
                          onPressed: () => setState(
                            () =>
                                _visualZoom = (_visualZoom * 1.2).clamp(.55, 3),
                          ),
                        ),
                        const SizedBox(height: 6),
                        _VisualizationZoomButton(
                          icon: Icons.remove_rounded,
                          label: 'Zoom out',
                          onPressed: () => setState(
                            () =>
                                _visualZoom = (_visualZoom / 1.2).clamp(.55, 3),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_visualIs3D) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Drag horizontally and vertically to orbit | yaw ${(_visualRotationY * 180 / math.pi).round()}° | pitch ${(_visualRotationX * 180 / math.pi).round()}°',
                    key: const Key('visualization-orientation'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  key: const Key('visualization-reset-view'),
                  tooltip: 'Reset 3D view',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _visualRotationX = -.18;
                    _visualRotationY = .28;
                    _visualZoom = 1;
                  }),
                  icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
                ),
              ],
            ),
          ],
          if (_visualIs3D &&
              _showExpressionPlot &&
              !_showVisualizationDetails &&
              (_mode == _CalculatorMode.geometry || isTriangle)) ...[
            const SizedBox(height: 8),
            _buildFaceAreaBreakdown(context),
          ],
          const SizedBox(height: 10),
          _SectionCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 34,
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Math.tex(
                            _visualizationFormulaTex,
                            mathStyle: MathStyle.display,
                            textStyle: const TextStyle(fontSize: 20),
                            onErrorFallback: (_) => Text(_visualizationFormula),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Adjusted result',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _visualizationValue.isFinite
                      ? _visualizationValue.toStringAsFixed(4)
                      : 'Cannot evaluate',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isTriangle) ...[
            _visualSlider(
              context,
              label: 'Angle θ',
              value: _visualAngle,
              min: 5,
              max: 85,
              divisions: 80,
              display: '${_visualAngle.toStringAsFixed(0)}°',
              onChanged: (value) => setState(() => _visualAngle = value),
            ),
            _visualSlider(
              context,
              label: 'Hypotenuse length',
              value: _visualHypotenuse,
              min: 1,
              max: 30,
              divisions: 58,
              display: _visualHypotenuse.toStringAsFixed(1),
              onChanged: (value) => setState(() => _visualHypotenuse = value),
            ),
          ] else if (isGeometry) ...[
            _visualSlider(
              context,
              label: _geometryOperation.contains('Rectangle')
                  ? 'Width'
                  : 'Radius / base',
              value: _geometryVisualFirst,
              min: .1,
              max: 20,
              divisions: 199,
              display: _geometryVisualFirst.toStringAsFixed(1),
              onChanged: (value) =>
                  setState(() => _geometryVisualFirst = value),
            ),
            if (const {
              'Rectangle area',
              'Rectangle perimeter',
              'Triangle area',
              'Pythagorean hypotenuse',
              'Parallelogram area',
              'Cylinder volume',
              'Cylinder surface area',
              'Cone volume',
              'Cone surface area',
            }.contains(_geometryOperation))
              _visualSlider(
                context,
                label: 'Height / second side',
                value: _geometryVisualSecond,
                min: .1,
                max: 20,
                divisions: 199,
                display: _geometryVisualSecond.toStringAsFixed(1),
                onChanged: (value) =>
                    setState(() => _geometryVisualSecond = value),
              ),
          ] else if (_mode == _CalculatorMode.calculus &&
              _calculusOperation == 'Definite integral') ...[
            Text(
              'Integration interval  [${_integralLower.toStringAsFixed(1)}, ${_integralUpper.toStringAsFixed(1)}]',
            ),
            RangeSlider(
              values: RangeValues(_integralLower, _integralUpper),
              min: -4,
              max: 4,
              divisions: 80,
              labels: RangeLabels(
                _integralLower.toStringAsFixed(1),
                _integralUpper.toStringAsFixed(1),
              ),
              onChanged: (range) => setState(() {
                _integralLower = range.start;
                _integralUpper = range.end;
              }),
            ),
          ] else if (_mode == _CalculatorMode.calculus) ...[
            _visualSlider(
              context,
              label: 'Evaluate at x',
              value: _graphX,
              min: -5,
              max: 5,
              divisions: 100,
              display: _graphX.toStringAsFixed(1),
              onChanged: (value) => setState(() => _graphX = value),
            ),
          ] else if (_mode == _CalculatorMode.graphing &&
              _input.text.trim().isNotEmpty) ...[
            _visualSlider(
              context,
              label: 'Evaluate at x',
              value: _graphX,
              min: -5,
              max: 5,
              divisions: 100,
              display: _graphX.toStringAsFixed(1),
              onChanged: (value) => setState(() => _graphX = value),
            ),
          ] else ...[
            _visualSlider(
              context,
              label: 'Slope m',
              value: _graphSlope,
              min: -5,
              max: 5,
              divisions: 100,
              display: _graphSlope.toStringAsFixed(1),
              onChanged: (value) => setState(() => _graphSlope = value),
            ),
            _visualSlider(
              context,
              label: 'Intercept b',
              value: _graphIntercept,
              min: -10,
              max: 10,
              divisions: 100,
              display: _graphIntercept.toStringAsFixed(1),
              onChanged: (value) => setState(() => _graphIntercept = value),
            ),
            _visualSlider(
              context,
              label: 'Evaluate at x',
              value: _graphX,
              min: -5,
              max: 5,
              divisions: 100,
              display: _graphX.toStringAsFixed(1),
              onChanged: (value) => setState(() => _graphX = value),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _returnFromVisualization,
            icon: const Icon(Icons.flip_to_back_rounded),
            label: const Text('Use adjusted expression in calculator'),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizationDetails(BuildContext context) => Container(
    key: const Key('visualization-details'),
    width: double.infinity,
    height: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF1E2230),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _mode == _CalculatorMode.geometry
              ? _geometryOperation
              : _visualizationTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Math.tex(
                _visualizationFormulaTex,
                mathStyle: MathStyle.display,
                textStyle: const TextStyle(
                  color: Color(0xFF6DE4F2),
                  fontSize: 30,
                ),
                onErrorFallback: (_) => Text(
                  _visualizationFormula,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _visualizationMeasureDescription,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70, height: 1.35),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                _visualizationMeasureLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFFFFC66D),
                ),
              ),
            ),
            Text(
              _visualizationValue.isFinite
                  ? _visualizationValue.toStringAsFixed(4)
                  : 'Cannot evaluate',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  List<_FaceAreaMeasurement> get _visualFaceAreas {
    const front = Color(0xFF36C9E8);
    const back = Color(0xFF286FA8);
    const adjacent = Color(0xFF35C46A);
    const opposite = Color(0xFFFF625A);
    const hypotenuse = Color(0xFF9B7EDE);
    const top = Color(0xFFFFC66D);

    if (_mode == _CalculatorMode.trigonometry) {
      final radians = _visualAngle * math.pi / 180;
      final c = _visualHypotenuse;
      final b = c * math.cos(radians);
      final h = c * math.sin(radians);
      final depth = c * .36;
      return [
        _FaceAreaMeasurement(
          'Front triangle',
          r'\frac{1}{2}bh',
          b * h / 2,
          front,
        ),
        _FaceAreaMeasurement(
          'Back triangle',
          r'\frac{1}{2}bh',
          b * h / 2,
          back,
        ),
        _FaceAreaMeasurement('Adjacent wall', r'b\cdot d', b * depth, adjacent),
        _FaceAreaMeasurement('Opposite wall', r'h\cdot d', h * depth, opposite),
        _FaceAreaMeasurement(
          'Hypotenuse wall',
          r'c\cdot d',
          c * depth,
          hypotenuse,
        ),
      ];
    }

    final first = _geometryVisualFirst;
    final second = _geometryVisualSecond;
    final operation = _geometryOperation;
    if (operation.contains('Cone')) {
      final slant = math.sqrt(first * first + second * second);
      final lateral = math.pi * first * slant;
      final base = math.pi * first * first;
      return [
        _FaceAreaMeasurement('Curved side', r'\pi r\ell', lateral, front),
        _FaceAreaMeasurement('Circular base', r'\pi r^2', base, top),
        _FaceAreaMeasurement(
          'Combined total',
          r'\pi r\ell+\pi r^2',
          lateral + base,
          back,
          isCombined: true,
        ),
      ];
    }
    if (operation.contains('Cylinder')) {
      final wall = 2 * math.pi * first * second;
      final disk = math.pi * first * first;
      return [
        _FaceAreaMeasurement('Curved side', r'2\pi rh', wall, front),
        _FaceAreaMeasurement('Top face', r'\pi r^2', disk, back),
        _FaceAreaMeasurement('Bottom face', r'\pi r^2', disk, top),
        _FaceAreaMeasurement(
          'Combined total',
          r'2\pi rh+2\pi r^2',
          wall + 2 * disk,
          back,
          isCombined: true,
        ),
      ];
    }
    if (operation.contains('Sphere')) {
      final area = 4 * math.pi * first * first;
      return [
        _FaceAreaMeasurement(
          'Continuous curved surface',
          r'4\pi r^2',
          area,
          front,
        ),
      ];
    }

    final depth = math.min(first, second) * .62;
    if (operation.contains('Triangle') || operation.contains('Pythagorean')) {
      final triangle = first * second / 2;
      return [
        _FaceAreaMeasurement(
          'Front triangle',
          r'\frac{1}{2}bh',
          triangle,
          front,
        ),
        _FaceAreaMeasurement('Back triangle', r'\frac{1}{2}bh', triangle, back),
        _FaceAreaMeasurement('Base side', r'b\cdot d', first * depth, adjacent),
        _FaceAreaMeasurement(
          'Height side',
          r'h\cdot d',
          second * depth,
          opposite,
        ),
        _FaceAreaMeasurement(
          'Sloped side',
          r'\sqrt{b^2+h^2}\cdot d',
          math.sqrt(first * first + second * second) * depth,
          hypotenuse,
        ),
      ];
    }
    if (operation.contains('Rectangle') ||
        operation.contains('Parallelogram')) {
      return [
        _FaceAreaMeasurement('Front face', r'w\cdot h', first * second, front),
        _FaceAreaMeasurement('Back face', r'w\cdot h', first * second, back),
        _FaceAreaMeasurement('Top face', r'w\cdot d', first * depth, top),
        _FaceAreaMeasurement(
          'Bottom face',
          r'w\cdot d',
          first * depth,
          adjacent,
        ),
        _FaceAreaMeasurement(
          'Right face',
          r'h\cdot d',
          second * depth,
          opposite,
        ),
        _FaceAreaMeasurement(
          'Left face',
          r'h\cdot d',
          second * depth,
          hypotenuse,
        ),
      ];
    }
    if (operation.startsWith('Circle')) {
      final disk = math.pi * first * first;
      final wall = 2 * math.pi * first * depth;
      return [
        _FaceAreaMeasurement('Top face', r'\pi r^2', disk, back),
        _FaceAreaMeasurement('Bottom face', r'\pi r^2', disk, top),
        _FaceAreaMeasurement('Curved side', r'2\pi rd', wall, front),
      ];
    }
    return const [];
  }

  Widget _buildFaceAreaBreakdown(BuildContext context) {
    final areas = _visualFaceAreas;
    if (areas.isEmpty) return const SizedBox.shrink();
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '3D surface decomposition',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: areas
                    .map(
                      (area) => _FaceAreaCard(
                        area: area,
                        width: width,
                        diagram: _buildFaceDiagram(area),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Colored face areas match the shaded surfaces in the 3D plot. Combined total includes all surfaces.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildFaceDiagram(_FaceAreaMeasurement area) {
    var kind = 'rectangle';
    var first = _geometryVisualFirst;
    var second = _geometryVisualSecond;
    if (area.isCombined) {
      kind = 'none';
    } else if (_mode == _CalculatorMode.trigonometry) {
      final radians = _visualAngle * math.pi / 180;
      final adjacent = _visualHypotenuse * math.cos(radians);
      final opposite = _visualHypotenuse * math.sin(radians);
      final depth = _visualHypotenuse * .36;
      if (area.label.contains('triangle')) {
        kind = 'triangle';
        first = adjacent;
        second = opposite;
      } else if (area.label.contains('Adjacent')) {
        first = adjacent;
        second = depth;
      } else if (area.label.contains('Opposite')) {
        first = opposite;
        second = depth;
      } else {
        first = _visualHypotenuse;
        second = depth;
      }
    } else if (_geometryOperation.contains('Cone')) {
      if (area.label == 'Curved side') {
        kind = 'sector';
        first = math.sqrt(
          _geometryVisualFirst * _geometryVisualFirst +
              _geometryVisualSecond * _geometryVisualSecond,
        );
        second = 2 * math.pi * _geometryVisualFirst / first;
      } else {
        kind = 'circle';
        first = _geometryVisualFirst;
      }
    } else if (_geometryOperation.contains('Cylinder')) {
      if (area.label == 'Curved side') {
        kind = 'rectangle';
        first = 2 * math.pi * _geometryVisualFirst;
        second = _geometryVisualSecond;
      } else {
        kind = 'circle';
        first = _geometryVisualFirst;
      }
    } else if (_geometryOperation.contains('Sphere')) {
      kind = 'sphere';
      first = _geometryVisualFirst;
    } else if (_geometryOperation.contains('Triangle') ||
        _geometryOperation.contains('Pythagorean')) {
      if (area.label.contains('triangle')) {
        kind = 'triangle';
        first = _geometryVisualFirst;
        second = _geometryVisualSecond;
      } else {
        final depth =
            math.min(_geometryVisualFirst, _geometryVisualSecond) * .62;
        if (area.label.contains('Base')) {
          first = _geometryVisualFirst;
          second = depth;
        } else if (area.label.contains('Height')) {
          first = _geometryVisualSecond;
          second = depth;
        } else {
          first = math.sqrt(
            _geometryVisualFirst * _geometryVisualFirst +
                _geometryVisualSecond * _geometryVisualSecond,
          );
          second = depth;
        }
      }
    } else if (_geometryOperation.contains('Rectangle') ||
        _geometryOperation.contains('Parallelogram')) {
      final depth = math.min(_geometryVisualFirst, _geometryVisualSecond) * .62;
      if (area.label.contains('Front') || area.label.contains('Back')) {
        first = _geometryVisualFirst;
        second = _geometryVisualSecond;
      } else if (area.label.contains('Top') || area.label.contains('Bottom')) {
        first = _geometryVisualFirst;
        second = depth;
      } else {
        first = _geometryVisualSecond;
        second = depth;
      }
    } else if (_geometryOperation.startsWith('Circle')) {
      if (area.label == 'Curved side') {
        kind = 'rectangle';
        first = 2 * math.pi * _geometryVisualFirst;
        second = math.max(_geometryVisualFirst * .32, .25);
      } else {
        kind = 'circle';
        first = _geometryVisualFirst;
      }
    }
    return SizedBox(
      height: 62,
      width: double.infinity,
      child: CustomPaint(
        painter: _FaceDiagramPainter(
          kind: kind,
          first: first,
          second: second,
          color: area.color,
        ),
      ),
    );
  }

  String get _visualizationMeasureLabel {
    if (_mode == _CalculatorMode.geometry) {
      if (_geometryOperation.contains('Volume')) return 'Volume';
      if (_geometryOperation.contains('surface area')) return 'Surface area';
      if (_geometryOperation.contains('circumference') ||
          _geometryOperation.contains('hypotenuse') ||
          _geometryOperation.contains('perimeter')) {
        return 'Length';
      }
      return 'Area';
    }
    if (_mode == _CalculatorMode.calculus &&
        _calculusOperation == 'Definite integral') {
      return 'Signed area on [${_numberForExpression(_integralLower)}, ${_numberForExpression(_integralUpper)}]';
    }
    if (_mode == _CalculatorMode.trigonometry) return 'Computed side value';
    return 'f(${_numberForExpression(_graphX)})';
  }

  String get _visualizationMeasureDescription {
    if (_mode == _CalculatorMode.geometry) {
      if (_geometryOperation.contains('Cylinder')) {
        return 'The cyan mesh is the cylinder surface. Red, green, and blue axes show its 3D orientation.';
      }
      if (_geometryOperation.contains('Cone')) {
        return 'The shaded cone surface follows the radius and height. The amber mesh edges make the solid depth visible.';
      }
      if (_geometryOperation.contains('Sphere')) {
        return 'The cyan mesh wraps the sphere in latitude and longitude bands. Rotate it to inspect the surface from every side.';
      }
      if (_geometryOperation.contains('area')) {
        return 'The shaded faces mark the region associated with this area formula; the axes identify its 3D orientation.';
      }
      return 'The solid is built from the selected dimensions. The colored axes show its position in three-dimensional space.';
    }
    if (_mode == _CalculatorMode.calculus &&
        _calculusOperation == 'Definite integral') {
      return 'The highlighted region represents the signed area between the curve and x-axis over the selected bounds.';
    }
    if (_mode == _CalculatorMode.trigonometry) {
      return 'The colored sides identify the adjacent, opposite, and hypotenuse lengths for the selected angle.';
    }
    return 'The surface maps the expression over x and y. Use the colored axes to track each dimension.';
  }

  Widget _visualSlider(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(display, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      Slider(
        value: value.clamp(min, max).toDouble(),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    ],
  );

  Widget _buildExpressionAnswer(
    BuildContext context, {
    double? height,
    bool expand = false,
  }) {
    final cardHeight = expand
        ? null
        : height ??
              (_mode == _CalculatorMode.calculus
                  ? 120.0
                  : _mode == _CalculatorMode.geometry
                  ? 84.0
                  : (MediaQuery.sizeOf(context).height * .18)
                        .clamp(112.0, 142.0)
                        .toDouble());
    const panelColor = Colors.white;
    if (_answerShown) {
      return Container(
        key: const Key('calculation-result-panel'),
        height: cardHeight,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEFE9E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _resultIsExact ? 'Exact answer' : 'Answer',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  key: const Key('calculation-result'),
                  label: _result ?? '--',
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Math.tex(
                      _mathTexFromSource(_result ?? '--'),
                      key: const Key('calculation-result-math'),
                      mathStyle: MathStyle.display,
                      textStyle: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                      onErrorFallback: (_) => Text(_result ?? '--'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      height: cardHeight,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFE9E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Expression')),
              TextButton.icon(
                key: const Key('expression-edit-toggle'),
                onPressed: () => setState(
                  () => _sourceEditorVisible = !_sourceEditorVisible,
                ),
                icon: Icon(
                  _sourceEditorVisible ? Icons.functions : Icons.edit,
                  size: 16,
                ),
                label: Text(_sourceEditorVisible ? 'Math view' : 'Edit'),
              ),
            ],
          ),
          Expanded(
            child: _sourceEditorVisible
                ? TextField(
                    key: const Key('expression-input'),
                    controller: _input,
                    autofocus: true,
                    onChanged: (_) => _updateResult(),
                    onSubmitted: (_) => _evaluate(),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: '12 + 8',
                      border: InputBorder.none,
                    ),
                  )
                : _fractionBuilder
                ? Row(
                    children: [
                      if (_input.text.isNotEmpty)
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Math.tex(
                              _expressionTex,
                              mathStyle: MathStyle.display,
                              textStyle: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      _inlineFractionEditor(),
                    ],
                  )
                : _input.text.trim().isEmpty &&
                      _mode != _CalculatorMode.geometry
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Enter an expression',
                      style: TextStyle(color: Colors.black45, fontSize: 18),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Math.tex(
                        _expressionTex,
                        mathStyle: MathStyle.display,
                        textStyle: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                        onErrorFallback: (_) =>
                            const Text('Complete the expression'),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _inlineFractionEditor() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 32, child: _fractionField(_numerator, false)),
            Container(height: 2, color: Theme.of(context).colorScheme.primary),
            SizedBox(height: 32, child: _fractionField(_denominator, true)),
          ],
        ),
      ),
      IconButton(
        key: const Key('fraction-insert'),
        tooltip: 'Insert fraction into expression',
        onPressed: _insertFraction,
        icon: const Icon(Icons.check_circle_outline_rounded),
      ),
    ],
  );

  Widget _fractionField(TextEditingController controller, bool denominator) =>
      TextField(
        controller: controller,
        readOnly: true,
        textAlign: TextAlign.center,
        onTap: () => setState(() => _fractionDenominatorSelected = denominator),
        decoration: const InputDecoration(
          hintText: '\u25A1',
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      );

  Widget _buildFunctionRow() {
    final List<(String, String)> functions = switch (_mode) {
      _CalculatorMode.algebra => [
        ('x', 'x'),
        ('y', 'y'),
        ('=', '='),
        (';', ';'),
        ('^', '^'),
        ('(', '('),
        (')', ')'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _CalculatorMode.calculus => [
        ('x', 'x'),
        ('^', '^'),
        ('d/dx', 'CALC_DERIVATIVE'),
        ('\u222B', 'CALC_INTEGRAL'),
        ('\u222B\u2090\u1D47', 'CALC_DEFINITE_INTEGRAL'),
        ('sin', 'sin('),
        ('cos', 'cos('),
        ('tan', 'tan('),
        ('sqrt', 'sqrt('),
        ('ln', 'ln('),
        ('(', '('),
        (')', ')'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _CalculatorMode.graphing => [
        ('x', 'x'),
        ('^', '^'),
        ('sin', 'sin('),
        ('cos', 'cos('),
        ('tan', 'tan('),
        ('sqrt', 'sqrt('),
        ('(', '('),
        (')', ')'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _CalculatorMode.geometry || _CalculatorMode.trigonometry => [
        ('sin', 'sin('),
        ('cos', 'cos('),
        ('tan', 'tan('),
        ('sec', 'sec('),
        ('csc', 'csc('),
        ('cot', 'cot('),
        ('×', '*'),
        ('a/b', 'a/b'),
        ('(', '('),
        (')', ')'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _CalculatorMode.scientific => [
        ('sin', 'sin('),
        ('cos', 'cos('),
        ('tan', 'tan('),
        ('sec', 'sec('),
        ('csc', 'csc('),
        ('cot', 'cot('),
        ('asin', 'arcsin('),
        ('acos', 'arccos('),
        ('atan', 'arctan('),
        ('sqrt', 'sqrt('),
        ('log', 'log('),
        ('ln', 'ln('),
        ('x^y', '^'),
        ('e^x', 'e^('),
        ('!', '!'),
        ('pi', '3.141592653589793'),
        ('e', '2.718281828459045'),
        ('abs', 'abs('),
        ('(', '('),
        (')', ')'),
        ('a/b', 'a/b'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _ => [
        ('(', '('),
        (')', ')'),
        ('^', '^'),
        ('%', '%'),
        ('a/b', 'a/b'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
    };
    return SizedBox(
      height: 34,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (label, key) in functions)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    key: ValueKey('function-key-$key'),
                    onPressed: () => _pressFunction(key),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(36, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _functionKeyVisual(label, key),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _functionKeyVisual(String label, String key) {
    if (key == 'DEL') return const Icon(Icons.backspace_outlined, size: 17);
    final tex = switch (key) {
      'sqrt(' => r'\sqrt{\square}',
      'cbrt(' => r'\sqrt[3]{\square}',
      'a/b' => r'\frac{\square}{\square}',
      '^' => r'\square^{\square}',
      'e^(' => r'e^x',
      '3.141592653589793' => r'\pi',
      'abs(' => r'|x|',
      'sin(' => r'\sin(\square)',
      'cos(' => r'\cos(\square)',
      'tan(' => r'\tan(\square)',
      'sec(' => r'\sec(\square)',
      'csc(' => r'\csc(\square)',
      'cot(' => r'\cot(\square)',
      'arcsin(' => r'\arcsin(\square)',
      'arccos(' => r'\arccos(\square)',
      'arctan(' => r'\arctan(\square)',
      'ln(' => r'\ln(\square)',
      'log(' => r'\log(\square)',
      '*' => r'\times',
      '/' => r'\div',
      'CALC_DERIVATIVE' => r'\frac{d}{dx}',
      'CALC_INTEGRAL' => r'\int \square\,dx',
      'CALC_DEFINITE_INTEGRAL' => r'\int_{a}^{b}\square\,dx',
      _ => null,
    };
    if (tex == null) return Text(label);
    return Math.tex(
      tex,
      mathStyle: MathStyle.text,
      textStyle: const TextStyle(fontSize: 16),
      onErrorFallback: (_) => Text(label),
    );
  }

  Widget _buildResponsiveKeypad(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final keyHeight = (screen.height * .043).clamp(27.0, 36.0).toDouble();
    final gap = screen.width < 360 ? 4.0 : 6.0;
    final numberGridHeight = keyHeight * 4 + gap * 3;
    final keypadHeight = keyHeight * 5 + gap * 4;
    const numberKeys = [
      '7',
      '8',
      '9',
      '4',
      '5',
      '6',
      '1',
      '2',
      '3',
      '0',
      '.',
      '00',
    ];
    return SizedBox(
      height: keypadHeight,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.center,
              child: SizedBox(
                height: numberGridHeight,
                child: GridView.count(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisExtent: keyHeight,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  children: [
                    for (final key in numberKeys)
                      _calculatorKey(context, key, () => _insert(key)),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              children: [
                for (final (label, value) in const [
                  ('+', '+'),
                  ('-', '-'),
                  ('×', '*'),
                  ('÷', '/'),
                ]) ...[
                  SizedBox(
                    height: keyHeight,
                    width: double.infinity,
                    child: _calculatorKey(
                      context,
                      label,
                      () => _insert(value),
                      emphasized: true,
                    ),
                  ),
                  SizedBox(height: gap),
                ],
                SizedBox(
                  height: keyHeight,
                  width: double.infinity,
                  child: _calculatorKey(context, '=', _evaluate, primary: true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calculatorKey(
    BuildContext context,
    String label,
    VoidCallback onPressed, {
    bool emphasized = false,
    bool primary = false,
  }) => SizedBox.expand(
    child: primary
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: FittedBox(child: _basicKeyVisual(label)),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: emphasized
                  ? Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: .55)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: FittedBox(child: _basicKeyVisual(label)),
          ),
  );

  Widget _buildNumberSystemCalculator(BuildContext context) {
    const bases = [2, 8, 10, 16];
    Widget picker(String label, int value, ValueChanged<int?> onChanged) =>
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, isDense: true),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                isExpanded: true,
                items: [
                  for (final base in bases)
                    DropdownMenuItem(
                      value: base,
                      child: Text('$base${_baseLabel(base)}'),
                    ),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        );
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Convert')),
              ButtonSegment(value: false, label: Text('Calculate')),
            ],
            selected: {_conversionOnly},
            onSelectionChanged: (selection) {
              setState(() {
                _conversionOnly = selection.first;
                _answerShown = false;
                _result = null;
              });
              _calculateNumberSystem();
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              picker('Input base', _sourceBase, (base) {
                if (base == null) return;
                setState(() {
                  _sourceBase = base;
                  _answerShown = false;
                });
                _calculateNumberSystem();
              }),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded),
              const SizedBox(width: 8),
              picker('Output base', _targetBase, (base) {
                if (base == null) return;
                setState(() {
                  _targetBase = base;
                  _answerShown = false;
                });
                _calculateNumberSystem();
              }),
            ],
          ),
          if (_answerShown) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Answer'),
                  const SizedBox(height: 6),
                  SelectableText(
                    _result ?? '--',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (!_conversionOnly && _numberOperator == '/')
                    Text(
                      'Quotient and remainder are shown in base $_targetBase.',
                    ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  _numberA.clear();
                  _numberB.clear();
                  _result = null;
                  _answerShown = false;
                }),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('New calculation'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            TextField(
              controller: _numberA,
              onChanged: (_) => _calculateNumberSystem(),
              keyboardType: TextInputType.text,
              style: Theme.of(context).textTheme.titleMedium,
              decoration: InputDecoration(
                labelText: _conversionOnly
                    ? 'Value in base $_sourceBase'
                    : 'First value in base $_sourceBase',
                hintText: _sourceBase == 16 ? 'FF' : '1010',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _numberSystemEditActions(_numberA),
              ),
            ),
            if (!_conversionOnly) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  for (final operation in [
                    '+',
                    '-',
                    '*',
                    '/',
                    '%',
                    '&',
                    '|',
                    '^',
                    '<<',
                    '>>',
                  ])
                    ChoiceChip(
                      label: Text(
                        {
                              '%': 'mod',
                              '&': 'AND',
                              '|': 'OR',
                              '^': 'XOR',
                            }[operation] ??
                            operation,
                      ),
                      selected: operation == _numberOperator,
                      onSelected: (_) {
                        setState(() => _numberOperator = operation);
                        _calculateNumberSystem();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _numberB,
                onChanged: (_) => _calculateNumberSystem(),
                keyboardType: TextInputType.text,
                style: Theme.of(context).textTheme.titleMedium,
                decoration: InputDecoration(
                  labelText: 'Second value in base $_sourceBase',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: _numberSystemEditActions(_numberB),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => _calculateNumberSystem(commit: true),
                child: const Text('='),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _numberSystemEditActions(TextEditingController controller) => SizedBox(
    width: 96,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Delete last digit',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          padding: EdgeInsets.zero,
          onPressed: () {
            final text = controller.text;
            final selection = controller.selection;
            final start = selection.isValid ? selection.start : text.length;
            final end = selection.isValid ? selection.end : text.length;
            final from = start == end && start > 0 ? start - 1 : start;
            controller.value = TextEditingValue(
              text: text.replaceRange(from, end, ''),
              selection: TextSelection.collapsed(offset: from),
            );
            _calculateNumberSystem();
          },
          icon: const Icon(Icons.backspace_outlined, size: 17),
        ),
        IconButton(
          tooltip: 'Clear value',
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          padding: EdgeInsets.zero,
          onPressed: () {
            controller.clear();
            _calculateNumberSystem();
          },
          icon: const Icon(Icons.clear_rounded, size: 18),
        ),
      ],
    ),
  );

  Widget _basicKeyVisual(String label) {
    final tex = switch (label) {
      '×' => r'\times',
      '÷' => r'\div',
      '−' => '-',
      _ => null,
    };
    if (tex == null) return Text(label);
    return Math.tex(
      tex,
      mathStyle: MathStyle.text,
      textStyle: const TextStyle(fontSize: 19),
    );
  }

  Widget _buildGeometryCalculator(BuildContext context, {bool fill = false}) {
    const operations = [
      'Circle area',
      'Circle circumference',
      'Rectangle area',
      'Rectangle perimeter',
      'Triangle area',
      'Pythagorean hypotenuse',
      'Parallelogram area',
      'Cylinder volume',
      'Cylinder surface area',
      'Cone volume',
      'Cone surface area',
      'Sphere volume',
      'Sphere surface area',
    ];
    final twoDimensions = const {
      'Rectangle area',
      'Rectangle perimeter',
      'Triangle area',
      'Pythagorean hypotenuse',
      'Parallelogram area',
      'Cylinder volume',
      'Cylinder surface area',
      'Cone volume',
      'Cone surface area',
    }.contains(_geometryOperation);
    final geometryGridHeight =
        (((MediaQuery.sizeOf(context).width - 44) / 4 / 2.1) * 4 + 12)
            .clamp(156.0, 210.0)
            .toDouble();
    String firstLabel = switch (_geometryOperation) {
      'Rectangle area' || 'Rectangle perimeter' => 'Length',
      'Triangle area' => 'Base',
      'Pythagorean hypotenuse' => 'First side',
      'Cylinder volume' ||
      'Cylinder surface area' ||
      'Cone volume' ||
      'Cone surface area' => 'Radius',
      _ => 'Radius',
    };
    String secondLabel = switch (_geometryOperation) {
      'Rectangle area' || 'Rectangle perimeter' => 'Width',
      'Triangle area' => 'Height',
      'Parallelogram area' => 'Height',
      'Cylinder volume' ||
      'Cylinder surface area' ||
      'Cone volume' ||
      'Cone surface area' => 'Height',
      _ => 'Second side',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fill)
          Expanded(child: _buildExpressionAnswer(context, expand: true))
        else
          _buildExpressionAnswer(context),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: _geometryOperation,
          decoration: const InputDecoration(
            labelText: 'Geometry operation',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          items: [
            for (final operation in operations)
              DropdownMenuItem(value: operation, child: Text(operation)),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _geometryOperation = value;
              _geometryFirst.clear();
              _geometrySecond.clear();
              _input.clear();
              _geometryUsesSecond = false;
              _result = null;
              _answerShown = false;
            });
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _geometryFirst,
                readOnly: true,
                onTap: () => setState(() => _geometryUsesSecond = false),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) {
                  if (_geometrySecond.text.isNotEmpty || !twoDimensions) {
                    _calculateGeometry();
                  }
                },
                decoration: InputDecoration(
                  labelText: firstLabel,
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (twoDimensions) ...[
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _geometrySecond,
                  readOnly: true,
                  onTap: () => setState(() => _geometryUsesSecond = true),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _calculateGeometry(),
                  decoration: InputDecoration(
                    labelText: secondLabel,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: geometryGridHeight,
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            crossAxisCount: 4,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 2.1,
            children: [
              for (final key in [
                '7',
                '8',
                '9',
                '4',
                '5',
                '6',
                '1',
                '2',
                '3',
                'C',
                '0',
                '.',
                'DEL',
              ])
                OutlinedButton(
                  key: ValueKey('geometry-key-$key'),
                  onPressed: () => _pressGeometryDigit(key),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(key),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _calculateGeometry(commit: true),
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Calculate'),
        ),
      ],
    );
  }

  String _baseLabel(int base) => switch (base) {
    2 => ' (Binary)',
    8 => ' (Octal)',
    10 => ' (Decimal)',
    16 => ' (Hex)',
    _ => '',
  };
  Widget _buildDrawingCalculator(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to calculator',
          onPressed: _exitDrawingMode,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Handwritten calculation'),
        actions: [
          IconButton(
            tooltip: 'Delete last stroke',
            onPressed: _undoDrawingStroke,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: _clearDrawing,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          TextButton(
            onPressed: _recognizingDrawing ? null : _recognizeDrawing,
            child: const Text('Analyze'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _drawingStatus ??
                          'Write a math expression anywhere on the canvas.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (_recognizingDrawing)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: RepaintBoundary(
                  key: _drawingBoundaryKey,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) => setState(() {
                      _drawingDebounce?.cancel();
                      _activeStroke = [details.localPosition];
                    }),
                    onPanUpdate: (details) => setState(
                      () => _activeStroke = [
                        ..._activeStroke,
                        details.localPosition,
                      ],
                    ),
                    onPanEnd: (_) {
                      if (_activeStroke.length > 1) {
                        _drawingStrokes.add(_activeStroke);
                      }
                      setState(() => _activeStroke = []);
                      _scheduleDrawingRecognition();
                    },
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CustomPaint(
                          painter: _ExpressionDrawingPainter([
                            ..._drawingStrokes,
                            if (_activeStroke.isNotEmpty) _activeStroke,
                          ]),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_recognizedExpression != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Recognized expression'),
                          Math.tex(
                            _mathTexFromSource(_recognizedExpression!),
                            mathStyle: MathStyle.display,
                            textStyle: Theme.of(context).textTheme.titleLarge,
                            onErrorFallback: (_) =>
                                Text(_recognizedExpression!),
                          ),
                          if (_result != null) ...[
                            const Text('Answer'),
                            Math.tex(
                              _mathTexFromSource(_result!),
                              mathStyle: MathStyle.display,
                              textStyle: Theme.of(context).textTheme.titleLarge,
                              onErrorFallback: (_) => Text(_result!),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_recognizedExpression != null)
                      IconButton(
                        tooltip: 'Edit expression',
                        onPressed: () {
                          _input.text = _recognizedExpression!;
                          _updateResult();
                          _exitDrawingMode();
                        },
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExpressionDrawingPainter extends CustomPainter {
  const _ExpressionDrawingPainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.white, BlendMode.src);
    final paint = Paint()
      ..color = const Color(0xFF17233D)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 2.5, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExpressionDrawingPainter oldDelegate) =>
      !identical(strokes, oldDelegate.strokes);
}

typedef _PlotPoint3 = (double, double, double);

class _MathVisualizationPainter extends CustomPainter {
  const _MathVisualizationPainter({
    required this.mode,
    required this.is3D,
    required this.zoom,
    required this.expressionPlot,
    required this.calculusOperation,
    required this.rotationX,
    required this.rotationY,
    required this.angle,
    required this.hypotenuse,
    required this.slope,
    required this.intercept,
    required this.lower,
    required this.upper,
    required this.selectedX,
    required this.expression,
    required this.geometryOperation,
    required this.geometryFirst,
    required this.geometrySecond,
  });

  final _CalculatorMode mode;
  final bool is3D;
  final double zoom;
  final bool expressionPlot;
  final String calculusOperation;
  final double rotationX, rotationY;
  final double angle, hypotenuse, slope, intercept, lower, upper, selectedX;
  final String expression;
  final String geometryOperation;
  final double geometryFirst, geometrySecond;

  bool get _triangle => mode == _CalculatorMode.trigonometry;

  String get _sourceExpression =>
      _plotExpression.trim().isEmpty ? 'x^2' : _plotExpression.trim();

  List<String> get _equationSides {
    final cleaned = _sourceExpression.replaceAll('×', '*').replaceAll('÷', '/');
    final sides = cleaned.split(RegExp(r'(?<![<>])=(?![=])'));
    if (sides.length < 2) return [cleaned, '0'];
    return [sides.first, sides.skip(1).join('=')];
  }

  bool get _hasXYVariables =>
      RegExp(r'\bx\b').hasMatch(_sourceExpression) &&
      RegExp(r'\by\b').hasMatch(_sourceExpression);

  bool get _hasXYZVariables =>
      _hasXYVariables && RegExp(r'\bz\b').hasMatch(_sourceExpression);

  bool get _isExplicitZFunction =>
      RegExp(r'^\s*z\s*=').hasMatch(_sourceExpression);

  String get _explicitZFunction =>
      RegExp(r'^\s*z\s*=\s*(.+)$').firstMatch(_sourceExpression)?.group(1) ??
      _sourceExpression;

  void _paintImplicitCurve(Canvas canvas, Size size) {
    const cells = 84;
    const minimum = -1.6;
    const maximum = 1.6;
    const margin = 30.0;
    final plotWidth = size.width - margin * 2;
    final plotHeight = size.height - margin * 2;
    final plotSize = math.min(plotWidth, plotHeight);
    final left = (size.width - plotSize) / 2;
    final top = (size.height - plotSize) / 2;
    const engine = MathEngine();
    final (leftExpression, rightExpression) = (
      _equationSides.first,
      _equationSides.last,
    );
    double sample(double x, double y) {
      try {
        final variables = {'x': x, 'y': y};
        return engine.evaluateAtVariables(leftExpression, variables) -
            engine.evaluateAtVariables(rightExpression, variables);
      } on Object {
        return double.nan;
      }
    }

    Offset point(double x, double y) => Offset(
      left + (x - minimum) / (maximum - minimum) * plotSize,
      top + (maximum - y) / (maximum - minimum) * plotSize,
    );

    final values = List<double>.filled((cells + 1) * (cells + 1), double.nan);
    int index(int x, int y) => y * (cells + 1) + x;
    double coordinate(int value) =>
        minimum + (maximum - minimum) * value / cells;
    for (var y = 0; y <= cells; y++) {
      for (var x = 0; x <= cells; x++) {
        values[index(x, y)] = sample(coordinate(x), coordinate(y));
      }
    }

    final region = Path();
    final contour = Path();
    const edges = [(0, 1), (1, 2), (2, 3), (3, 0)];
    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < cells; x++) {
        final xs = [x, x + 1, x + 1, x];
        final ys = [y, y, y + 1, y + 1];
        final f = [
          values[index(xs[0], ys[0])],
          values[index(xs[1], ys[1])],
          values[index(xs[2], ys[2])],
          values[index(xs[3], ys[3])],
        ];
        if (f.any((value) => !value.isFinite)) continue;
        final centerValue = sample(
          (coordinate(x) + coordinate(x + 1)) / 2,
          (coordinate(y) + coordinate(y + 1)) / 2,
        );
        if (centerValue.isFinite && centerValue <= 0) {
          region.addRect(
            Rect.fromLTRB(
              point(coordinate(x), coordinate(y + 1)).dx,
              point(coordinate(x), coordinate(y + 1)).dy,
              point(coordinate(x + 1), coordinate(y)).dx,
              point(coordinate(x + 1), coordinate(y)).dy,
            ),
          );
        }
        final crossings = <Offset>[];
        for (final (a, b) in edges) {
          if ((f[a] < 0) == (f[b] < 0)) continue;
          final amount = (f[a] / (f[a] - f[b])).clamp(0.0, 1.0);
          final px =
              coordinate(xs[a]) +
              (coordinate(xs[b]) - coordinate(xs[a])) * amount;
          final py =
              coordinate(ys[a]) +
              (coordinate(ys[b]) - coordinate(ys[a])) * amount;
          crossings.add(point(px, py));
        }
        for (var crossing = 0; crossing + 1 < crossings.length; crossing += 2) {
          contour
            ..moveTo(crossings[crossing].dx, crossings[crossing].dy)
            ..lineTo(crossings[crossing + 1].dx, crossings[crossing + 1].dy);
        }
      }
    }

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: .12)
      ..strokeWidth = .7;
    for (var tick = -1; tick <= 1; tick++) {
      final x = point(tick.toDouble(), 0).dx;
      final y = point(0, tick.toDouble()).dy;
      canvas.drawLine(Offset(x, top), Offset(x, top + plotSize), gridPaint);
      canvas.drawLine(Offset(left, y), Offset(left + plotSize, y), gridPaint);
    }
    canvas.drawPath(
      region,
      Paint()..color = const Color(0xFFAC5DEB).withValues(alpha: .34),
    );
    canvas.drawRect(
      Rect.fromLTWH(left, top, plotSize, plotSize),
      Paint()
        ..color = Colors.white.withValues(alpha: .68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      contour,
      Paint()
        ..color = const Color(0xFF75E5F2)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    final origin = point(0, 0);
    canvas.drawLine(
      Offset(left, origin.dy),
      Offset(left + plotSize, origin.dy),
      Paint()..color = const Color(0xFF57D68D).withValues(alpha: .85),
    );
    canvas.drawLine(
      Offset(origin.dx, top + plotSize),
      Offset(origin.dx, top),
      Paint()..color = const Color(0xFFFF625A).withValues(alpha: .85),
    );
    _label(
      canvas,
      'Implicit equation region',
      const Offset(14, 12),
      Colors.white,
    );
    _label(
      canvas,
      'Shaded side: F(x,y) ≤ 0',
      Offset(14, size.height - 22),
      const Color(0xFFFFC66D),
    );
  }

  void _paintImplicitSurface(Canvas canvas, Size size) {
    const cells = 12;
    const minimum = -1.5;
    const maximum = 1.5;
    const engine = MathEngine();
    final (leftExpression, rightExpression) = (
      _equationSides.first,
      _equationSides.last,
    );
    double coordinate(int value) =>
        minimum + (maximum - minimum) * value / cells;
    int index(int x, int y, int z) => (z * (cells + 1) + y) * (cells + 1) + x;
    final values = List<double>.filled(
      (cells + 1) * (cells + 1) * (cells + 1),
      double.nan,
    );
    for (var z = 0; z <= cells; z++) {
      for (var y = 0; y <= cells; y++) {
        for (var x = 0; x <= cells; x++) {
          try {
            final variables = {
              'x': coordinate(x),
              'y': coordinate(y),
              'z': coordinate(z),
            };
            values[index(x, y, z)] =
                engine.evaluateAtVariables(leftExpression, variables) -
                engine.evaluateAtVariables(rightExpression, variables);
          } on Object {
            values[index(x, y, z)] = double.nan;
          }
        }
      }
    }

    final triangles = <(_PlotPoint3, _PlotPoint3, _PlotPoint3)>[];
    const corners = <(int, int, int)>[
      (0, 0, 0),
      (1, 0, 0),
      (1, 1, 0),
      (0, 1, 0),
      (0, 0, 1),
      (1, 0, 1),
      (1, 1, 1),
      (0, 1, 1),
    ];
    const tetrahedra = [
      (0, 5, 1, 6),
      (0, 1, 2, 6),
      (0, 2, 3, 6),
      (0, 3, 7, 6),
      (0, 7, 4, 6),
      (0, 4, 5, 6),
    ];
    const tetraEdges = [(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)];
    for (var z = 0; z < cells; z++) {
      for (var y = 0; y < cells; y++) {
        for (var x = 0; x < cells; x++) {
          final points = corners
              .map(
                (corner) => (
                  coordinate(x + corner.$1),
                  coordinate(y + corner.$2),
                  coordinate(z + corner.$3),
                ),
              )
              .toList(growable: false);
          final field = corners
              .map(
                (corner) =>
                    values[index(x + corner.$1, y + corner.$2, z + corner.$3)],
              )
              .toList(growable: false);
          if (field.any((value) => !value.isFinite)) continue;
          for (final tetra in tetrahedra) {
            final ids = [tetra.$1, tetra.$2, tetra.$3, tetra.$4];
            final intersections = <_PlotPoint3>[];
            for (final (edgeA, edgeB) in tetraEdges) {
              final a = ids[edgeA], b = ids[edgeB];
              if ((field[a] < 0) == (field[b] < 0)) continue;
              final t = (field[a] / (field[a] - field[b])).clamp(0.0, 1.0);
              intersections.add((
                points[a].$1 + (points[b].$1 - points[a].$1) * t,
                points[a].$2 + (points[b].$2 - points[a].$2) * t,
                points[a].$3 + (points[b].$3 - points[a].$3) * t,
              ));
            }
            if (intersections.length == 3) {
              triangles.add((
                intersections[0],
                intersections[1],
                intersections[2],
              ));
            } else if (intersections.length == 4) {
              triangles
                ..add((intersections[0], intersections[1], intersections[2]))
                ..add((intersections[0], intersections[2], intersections[3]));
            }
          }
        }
      }
    }

    final cx = math.cos(rotationX), sx = math.sin(rotationX);
    final cy = math.cos(rotationY), sy = math.sin(rotationY);
    _PlotPoint3 rotate(_PlotPoint3 point) {
      final x = point.$1 * cy + point.$3 * sy;
      final z1 = -point.$1 * sy + point.$3 * cy;
      return (x, point.$2 * cx - z1 * sx, point.$2 * sx + z1 * cx);
    }

    Offset project(_PlotPoint3 point) {
      final rotated = rotate(point);
      final perspective = 4.2 / (4.2 + rotated.$3 / 1.5);
      final scale = math.min(size.width, size.height) * .34 * perspective;
      return Offset(
        size.width / 2 + rotated.$1 * scale,
        size.height / 2 - rotated.$2 * scale,
      );
    }

    final sorted = [...triangles]
      ..sort((a, b) {
        double depth((_PlotPoint3, _PlotPoint3, _PlotPoint3) triangle) =>
            (rotate(triangle.$1).$3 +
                rotate(triangle.$2).$3 +
                rotate(triangle.$3).$3) /
            3;
        return depth(a).compareTo(depth(b));
      });
    var totalSurfaceArea = 0.0;
    var largestFaceArea = 0.0;
    var largestFaceSides = (0.0, 0.0, 0.0);
    double distance(_PlotPoint3 a, _PlotPoint3 b) => math.sqrt(
      math.pow(a.$1 - b.$1, 2) +
          math.pow(a.$2 - b.$2, 2) +
          math.pow(a.$3 - b.$3, 2),
    );
    double faceArea(_PlotPoint3 a, _PlotPoint3 b, _PlotPoint3 c) {
      final ab = (b.$1 - a.$1, b.$2 - a.$2, b.$3 - a.$3);
      final ac = (c.$1 - a.$1, c.$2 - a.$2, c.$3 - a.$3);
      final cross = (
        ab.$2 * ac.$3 - ab.$3 * ac.$2,
        ab.$3 * ac.$1 - ab.$1 * ac.$3,
        ab.$1 * ac.$2 - ab.$2 * ac.$1,
      );
      return math.sqrt(
            cross.$1 * cross.$1 + cross.$2 * cross.$2 + cross.$3 * cross.$3,
          ) /
          2;
    }

    for (final triangle in sorted) {
      final area = faceArea(triangle.$1, triangle.$2, triangle.$3);
      totalSurfaceArea += area;
      if (area > largestFaceArea) {
        largestFaceArea = area;
        largestFaceSides = (
          distance(triangle.$1, triangle.$2),
          distance(triangle.$2, triangle.$3),
          distance(triangle.$3, triangle.$1),
        );
      }
      final points = [
        project(triangle.$1),
        project(triangle.$2),
        project(triangle.$3),
      ];
      final path = Path()
        ..moveTo(points[0].dx, points[0].dy)
        ..lineTo(points[1].dx, points[1].dy)
        ..lineTo(points[2].dx, points[2].dy)
        ..close();
      final centerZ = (triangle.$1.$3 + triangle.$2.$3 + triangle.$3.$3) / 3;
      final tint = ((centerZ - minimum) / (maximum - minimum)).clamp(0.0, 1.0);
      final color = Color.lerp(
        const Color(0xFF7753D6),
        const Color(0xFFFF8C9E),
        tint,
      )!;
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: .88));
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFE5D8FF).withValues(alpha: .27)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .55,
      );
    }
    _paint3DAxes(canvas, size, project);
    _label(
      canvas,
      'Implicit surface F(x,y,z) = 0',
      const Offset(14, 12),
      Colors.white,
    );
    _label(
      canvas,
      'Expression surface - drag to orbit',
      Offset(14, size.height - 22),
      const Color(0xFFFFC66D),
    );
    _metricBadge(
      canvas,
      'Σ face area ≈ ${totalSurfaceArea.toStringAsFixed(2)} units²',
      Offset(14, size.height - 56),
      const Color(0xFF9BE7FF),
      maxWidth: size.width - 28,
    );
    _metricBadge(
      canvas,
      'Face sides ${largestFaceSides.$1.toStringAsFixed(2)}, ${largestFaceSides.$2.toStringAsFixed(2)}, ${largestFaceSides.$3.toStringAsFixed(2)} | area ${largestFaceArea.toStringAsFixed(3)}',
      const Offset(14, 38),
      const Color(0xFFFFC66D),
      maxWidth: size.width - 28,
    );
  }

  void _paint3DAxes(
    Canvas canvas,
    Size size,
    Offset Function((double, double, double)) project,
  ) {
    const axisDefinitions = <((double, double, double), Color, String)>[
      ((1.65, 0, 0), Color(0xFFFF625A), 'x'),
      ((0, 1.65, 0), Color(0xFF57D68D), 'y'),
      ((0, 0, 1.65), Color(0xFF4A86FF), 'z'),
    ];
    final origin = project((0, 0, 0));
    for (final (end, color, label) in axisDefinitions) {
      final finish = project(end);
      canvas.drawLine(
        origin,
        finish,
        Paint()
          ..color = color
          ..strokeWidth = 2.1,
      );
      _label(canvas, label, finish + const Offset(3, -10), color);
    }
  }

  String get _plotExpression {
    if (mode != _CalculatorMode.calculus) return expression;
    final source = expression.trim().isEmpty ? 'x^2' : expression;
    try {
      if (calculusOperation == 'Derivative') {
        return const MathEngine().differentiate(source);
      }
      if (calculusOperation == 'Indefinite integral') {
        return const MathEngine()
            .integrateIndefinite(source)
            .replaceFirst(RegExp(r'\s*\+\s*C$'), '');
      }
    } on Object {
      return source;
    }
    return source;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF1E2230), BlendMode.src);
    if (expressionPlot) {
      if (mode == _CalculatorMode.geometry) {
        if (is3D) {
          _paint3DGeometry(canvas, size);
        } else {
          _paintGeometry(canvas, size);
        }
      } else if (_triangle) {
        _paintTriangle(canvas, size);
      } else if (is3D) {
        if (_hasXYZVariables && !_isExplicitZFunction) {
          _paintImplicitSurface(canvas, size);
        } else {
          _paintSurface(canvas, size);
        }
      } else if (_hasXYVariables && !_isExplicitYFunction) {
        _paintImplicitCurve(canvas, size);
      } else if (_isExplicitYFunction) {
        _paintGraph(canvas, size, functionExpression: _explicitYFunction);
      } else if (mode == _CalculatorMode.calculus &&
          calculusOperation == 'Definite integral') {
        _paintIntegral(canvas, size);
      } else {
        _paintGraph(canvas, size);
      }
      return;
    }
    final transformCanvas =
        is3D &&
        mode != _CalculatorMode.geometry &&
        mode != _CalculatorMode.trigonometry;
    if (transformCanvas) {
      final centerX = size.width / 2;
      final centerY = size.height / 2;
      final transform = Matrix4.identity()
        ..setEntry(3, 2, .001)
        ..translateByDouble(centerX, centerY, 0, 1)
        ..rotateX(rotationX)
        ..rotateY(rotationY)
        ..scaleByDouble(zoom, zoom, 1, 1)
        ..translateByDouble(-centerX, -centerY, 0, 1);
      canvas.save();
      canvas.transform(transform.storage);
    }
    if (mode == _CalculatorMode.geometry) {
      if (is3D) {
        _paint3DGeometry(canvas, size);
      } else {
        _paintGeometry(canvas, size);
      }
    } else if (_triangle) {
      _paintTriangle(canvas, size);
    } else if (is3D) {
      _paintSurface(canvas, size);
    } else if (mode == _CalculatorMode.calculus &&
        calculusOperation == 'Definite integral') {
      _paintIntegral(canvas, size);
    } else if (mode == _CalculatorMode.calculus &&
        calculusOperation == 'Derivative') {
      _paintDerivative(canvas, size);
    } else if (mode == _CalculatorMode.calculus) {
      _paintGraph(canvas, size);
    } else {
      _paintGraph(canvas, size);
    }
    if (transformCanvas) canvas.restore();
  }

  bool get _isExplicitYFunction {
    final match = RegExp(r'^\s*y\s*=\s*(.+)$').firstMatch(_sourceExpression);
    return match != null && !RegExp(r'\by\b').hasMatch(match.group(1)!);
  }

  String get _explicitYFunction =>
      RegExp(r'^\s*y\s*=\s*(.+)$').firstMatch(_sourceExpression)?.group(1) ??
      _sourceExpression;

  void _paint3DGeometry(Canvas canvas, Size size) {
    // Scientific convention: X red, Y green, Z blue. Solid surfaces use a
    // cool cyan/blue fill with amber edge highlights for clear depth cues.
    const xColor = Color(0xFFFF625A);
    const yColor = Color(0xFF57D68D);
    const zColor = Color(0xFF4A86FF);
    const surfaceColor = Color(0xFF36C9E8);
    const rearColor = Color(0xFF286FA8);
    const baseColor = Color(0xFFFFC66D);
    const sideColor = Color(0xFF35C46A);
    const secondarySideColor = Color(0xFFFF625A);
    const thirdSideColor = Color(0xFF9B7EDE);
    final radius = geometryFirst.clamp(.1, 20).toDouble();
    final secondary = geometrySecond.clamp(.1, 20).toDouble();
    final vertices = <(double, double, double)>[];
    final faces = <(int, int, int)>[];
    final faceColors = <Color>[];

    void face(int a, int b, int c, Color color) {
      faces.add((a, b, c));
      faceColors.add(color);
    }

    void quad(int a, int b, int c, int d, Color color) {
      face(a, b, c, color);
      face(a, c, d, color);
    }

    final operation = geometryOperation;
    if (operation.contains('Sphere')) {
      const latitudes = 16;
      const longitudes = 28;
      for (var lat = 0; lat <= latitudes; lat++) {
        final phi = -math.pi / 2 + math.pi * lat / latitudes;
        for (var lon = 0; lon <= longitudes; lon++) {
          final theta = 2 * math.pi * lon / longitudes;
          vertices.add((
            radius * math.cos(phi) * math.cos(theta),
            radius * math.sin(phi),
            radius * math.cos(phi) * math.sin(theta),
          ));
        }
      }
      for (var lat = 0; lat < latitudes; lat++) {
        for (var lon = 0; lon < longitudes; lon++) {
          final a = lat * (longitudes + 1) + lon;
          final b = a + longitudes + 1;
          quad(a, a + 1, b + 1, b, surfaceColor);
        }
      }
    } else if (operation.contains('Cone')) {
      const sides = 40;
      final h = secondary;
      vertices.add((0, h / 2, 0));
      for (var i = 0; i < sides; i++) {
        final angle = 2 * math.pi * i / sides;
        vertices.add((
          radius * math.cos(angle),
          -h / 2,
          radius * math.sin(angle),
        ));
      }
      final baseCenter = vertices.length;
      vertices.add((0, -h / 2, 0));
      for (var i = 0; i < sides; i++) {
        final next = (i + 1) % sides;
        face(0, i + 1, next + 1, surfaceColor);
        face(baseCenter, next + 1, i + 1, baseColor);
      }
    } else if (operation.contains('Cylinder') ||
        operation.startsWith('Circle')) {
      const sides = 40;
      final h = operation.startsWith('Circle')
          ? math.max(radius * .32, .25)
          : secondary;
      for (var cap = 0; cap < 2; cap++) {
        final y = cap == 0 ? -h / 2 : h / 2;
        for (var i = 0; i < sides; i++) {
          final angle = 2 * math.pi * i / sides;
          vertices.add((radius * math.cos(angle), y, radius * math.sin(angle)));
        }
      }
      final bottomCenter = vertices.length;
      vertices.add((0, -h / 2, 0));
      final topCenter = vertices.length;
      vertices.add((0, h / 2, 0));
      for (var i = 0; i < sides; i++) {
        final next = (i + 1) % sides;
        quad(i, next, sides + next, sides + i, surfaceColor);
        face(bottomCenter, next, i, baseColor);
        face(topCenter, sides + i, sides + next, rearColor);
      }
    } else {
      // Area/perimeter operations become a shallow prism. Right-triangle
      // calculations use the same base/height in a triangular prism.
      final length = radius;
      final height = secondary;
      final depth = math.min(length, height) * .62;
      if (operation.contains('Triangle') || operation.contains('Pythagorean')) {
        final points = <(double, double)>[
          (-length / 2, -height / 2),
          (length / 2, -height / 2),
          (length * .1, height / 2),
        ];
        for (final z in [-depth / 2, depth / 2]) {
          for (final point in points) {
            vertices.add((point.$1, point.$2, z));
          }
        }
        face(0, 1, 2, surfaceColor);
        face(3, 5, 4, rearColor);
        for (var i = 0; i < 3; i++) {
          final next = (i + 1) % 3;
          quad(
            i,
            next,
            3 + next,
            3 + i,
            [sideColor, secondarySideColor, thirdSideColor][i],
          );
        }
      } else {
        final x = length / 2, y = height / 2, z = depth / 2;
        vertices.addAll([
          (-x, -y, -z),
          (x, -y, -z),
          (x, y, -z),
          (-x, y, -z),
          (-x, -y, z),
          (x, -y, z),
          (x, y, z),
          (-x, y, z),
        ]);
        quad(0, 3, 2, 1, surfaceColor);
        quad(4, 5, 6, 7, rearColor);
        quad(0, 1, 5, 4, sideColor);
        quad(1, 2, 6, 5, secondarySideColor);
        quad(2, 3, 7, 6, baseColor);
        quad(3, 0, 4, 7, thirdSideColor);
      }
    }

    final scale =
        math.min(size.width, size.height) *
        .31 *
        zoom /
        math.max(radius, secondary).clamp(.1, 20);
    (double, double, double) rotate((double, double, double) p) {
      final cy = math.cos(rotationY), sy = math.sin(rotationY);
      final cx = math.cos(rotationX), sx = math.sin(rotationX);
      final x = p.$1 * cy + p.$3 * sy;
      final z1 = -p.$1 * sy + p.$3 * cy;
      final y = p.$2 * cx - z1 * sx;
      final z = p.$2 * sx + z1 * cx;
      return (x, y, z);
    }

    Offset project((double, double, double) p) {
      final q = rotate(p);
      final perspective = 4.2 / (4.2 + q.$3 / math.max(radius, secondary));
      final s = scale * perspective;
      return Offset(size.width * .5 + q.$1 * s, size.height * .52 - q.$2 * s);
    }

    final transformed = vertices.map(rotate).toList(growable: false);
    final orderedFaceIndices = List<int>.generate(faces.length, (i) => i)
      ..sort((indexA, indexB) {
        double depth((int, int, int) f) =>
            (transformed[f.$1].$3 +
                transformed[f.$2].$3 +
                transformed[f.$3].$3) /
            3;
        return depth(faces[indexA]).compareTo(depth(faces[indexB]));
      });
    for (final faceIndex in orderedFaceIndices) {
      final f = faces[faceIndex];
      final a = transformed[f.$1], b = transformed[f.$2], c = transformed[f.$3];
      final ab = (b.$1 - a.$1, b.$2 - a.$2, b.$3 - a.$3);
      final ac = (c.$1 - a.$1, c.$2 - a.$2, c.$3 - a.$3);
      final normal = (
        ab.$2 * ac.$3 - ab.$3 * ac.$2,
        ab.$3 * ac.$1 - ab.$1 * ac.$3,
        ab.$1 * ac.$2 - ab.$2 * ac.$1,
      );
      final magnitude = math.sqrt(
        normal.$1 * normal.$1 + normal.$2 * normal.$2 + normal.$3 * normal.$3,
      );
      final light = magnitude == 0
          ? .45
          : ((normal.$1 * -.35 + normal.$2 * .55 + normal.$3 * .76) / magnitude)
                .abs();
      final shade = (.34 + light * .62).clamp(.32, .94);
      final path = Path()
        ..moveTo(project(vertices[f.$1]).dx, project(vertices[f.$1]).dy)
        ..lineTo(project(vertices[f.$2]).dx, project(vertices[f.$2]).dy)
        ..lineTo(project(vertices[f.$3]).dx, project(vertices[f.$3]).dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = faceColors[faceIndex].withValues(alpha: shade),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFB8F4FF).withValues(alpha: .54)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .65,
      );
    }

    void axis((double, double, double) end, Color color, String label) {
      final start = project((0, 0, 0));
      final finish = project(end);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(start, finish, paint);
      final direction = finish - start;
      if (direction.distance > 0) {
        final unit = direction / direction.distance;
        final normal = Offset(-unit.dy, unit.dx);
        final arrow = Path()
          ..moveTo(finish.dx, finish.dy)
          ..lineTo(
            finish.dx - unit.dx * 8 + normal.dx * 4,
            finish.dy - unit.dy * 8 + normal.dy * 4,
          )
          ..lineTo(
            finish.dx - unit.dx * 8 - normal.dx * 4,
            finish.dy - unit.dy * 8 - normal.dy * 4,
          )
          ..close();
        canvas.drawPath(arrow, Paint()..color = color);
      }
      _label(canvas, label, finish + const Offset(3, -11), color);
    }

    axis((radius * 1.35, 0, 0), xColor, 'x');
    axis((0, secondary * .75, 0), yColor, 'y');
    axis((0, 0, radius * 1.35), zColor, 'z');
    _label(canvas, geometryOperation, const Offset(14, 12), Colors.white);
  }

  void _paintGeometry(Canvas canvas, Size size) {
    final c = Offset(size.width * .5, size.height * .53);
    final scale = math.min(size.width * .032, size.height * .032);
    final a = geometryFirst.clamp(.1, 20) * scale;
    final b = geometrySecond.clamp(.1, 20) * scale;
    final stroke = Paint()
      ..color = const Color(0xFF4A86FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final green = Paint()
      ..color = const Color(0xFF35C46A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = const Color(0xFF4A86FF).withValues(alpha: .18)
      ..style = PaintingStyle.fill;
    if (geometryOperation.startsWith('Circle')) {
      final r = math.min(a, math.min(size.width * .3, size.height * .34));
      if (geometryOperation == 'Circle area') {
        canvas.drawCircle(c, r, fill);
      }
      canvas.drawCircle(c, r, stroke);
      if (is3D) {
        canvas.drawOval(
          Rect.fromCenter(
            center: c + const Offset(0, 12),
            width: r * 2,
            height: r * .55,
          ),
          green,
        );
      }
    } else if (geometryOperation.startsWith('Rectangle') ||
        geometryOperation == 'Parallelogram area') {
      final w = math.min(a, size.width * .62),
          h = math.min(b, size.height * .55);
      final l = c.dx - w / 2, t = c.dy - h / 2;
      final skew = geometryOperation == 'Parallelogram area' ? w * .2 : 0.0;
      final p = Path()
        ..moveTo(l + skew, t)
        ..lineTo(l + w + skew, t)
        ..lineTo(l + w, t + h)
        ..lineTo(l, t + h)
        ..close();
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
      if (is3D) {
        const d = Offset(22, -16);
        for (final point in [
          Offset(l + skew, t),
          Offset(l + w + skew, t),
          Offset(l + w, t + h),
          Offset(l, t + h),
        ]) {
          canvas.drawLine(point, point + d, green);
        }
      }
    } else if (geometryOperation == 'Triangle area' ||
        geometryOperation == 'Pythagorean hypotenuse') {
      final w = math.min(a, size.width * .62),
          h = math.min(b, size.height * .55);
      final l = c.dx - w / 2, base = c.dy + h / 2;
      final p = Path()
        ..moveTo(l, base)
        ..lineTo(l + w, base)
        ..lineTo(l + w * .62, base - h)
        ..close();
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
      if (geometryOperation == 'Pythagorean hypotenuse') {
        canvas.drawLine(
          Offset(l + w * .62, base - h),
          Offset(l + w * .62, base),
          green,
        );
      }
    } else if (geometryOperation.contains('Cylinder')) {
      final r = math.min(a, size.width * .25),
          h = math.min(b, size.height * .48);
      final rect = Rect.fromCenter(center: c, width: r * 2, height: h);
      canvas.drawRect(rect, fill);
      canvas.drawLine(
        Offset(rect.left, rect.top),
        Offset(rect.left, rect.bottom),
        stroke,
      );
      canvas.drawLine(
        Offset(rect.right, rect.top),
        Offset(rect.right, rect.bottom),
        stroke,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.dx, rect.top),
          width: r * 2,
          height: r * .55,
        ),
        stroke,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(c.dx, rect.bottom),
          width: r * 2,
          height: r * .55,
        ),
        0,
        math.pi,
        false,
        stroke,
      );
      if (is3D) {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(c.dx, rect.bottom),
            width: r * 2,
            height: r * .55,
          ),
          math.pi,
          math.pi,
          false,
          green,
        );
      }
    } else if (geometryOperation.contains('Cone')) {
      final r = math.min(a, size.width * .27),
          h = math.min(b, size.height * .53);
      final top = Offset(c.dx, c.dy - h / 2),
          left = Offset(c.dx - r, c.dy + h / 2),
          right = Offset(c.dx + r, c.dy + h / 2);
      final p = Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
      final base = Rect.fromCenter(
        center: Offset(c.dx, c.dy + h / 2),
        width: r * 2,
        height: r * .55,
      );
      canvas.drawArc(base, 0, math.pi, false, stroke);
      if (is3D) canvas.drawArc(base, math.pi, math.pi, false, green);
    } else {
      final r = math.min(a, math.min(size.width * .28, size.height * .34));
      canvas.drawCircle(c, r, fill);
      canvas.drawCircle(c, r, stroke);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2, height: r * .72),
        green,
      );
    }
    _label(canvas, geometryOperation, const Offset(16, 14), Colors.white);
    _label(
      canvas,
      is3D ? '3D solid preview' : '2D shape preview',
      Offset(16, size.height - 22),
      const Color(0xFF78A5FF),
    );
  }

  void _paintTriangle(Canvas canvas, Size size) {
    if (is3D) {
      _paintTriangleSolid(canvas, size);
      return;
    }
    final baseY = size.height * .78;
    final startX = size.width * .12;
    final radians = angle * math.pi / 180;
    final scale = math.min(
      size.width * .68 / (hypotenuse * math.cos(radians)),
      size.height * .54 / (hypotenuse * math.sin(radians)),
    );
    final start = Offset(startX, baseY);
    final apex = Offset(
      startX + hypotenuse * math.cos(radians) * scale,
      baseY - hypotenuse * math.sin(radians) * scale,
    );
    final end = Offset(apex.dx, baseY);
    final extrusion = is3D ? const Offset(24, -17) : Offset.zero;
    if (is3D) {
      final front = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(end.dx, end.dy)
        ..lineTo(apex.dx, apex.dy)
        ..close();
      final back = Path()
        ..moveTo(start.dx + extrusion.dx, start.dy + extrusion.dy)
        ..lineTo(end.dx + extrusion.dx, end.dy + extrusion.dy)
        ..lineTo(apex.dx + extrusion.dx, apex.dy + extrusion.dy)
        ..close();
      final side = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(end.dx, end.dy)
        ..lineTo(end.dx + extrusion.dx, end.dy + extrusion.dy)
        ..lineTo(start.dx + extrusion.dx, start.dy + extrusion.dy)
        ..close();
      canvas.drawPath(
        side,
        Paint()..color = const Color(0xFF36C9E8).withValues(alpha: .28),
      );
      canvas.drawPath(
        back,
        Paint()..color = const Color(0xFF286FA8).withValues(alpha: .22),
      );
      canvas.drawPath(
        front,
        Paint()..color = const Color(0xFF36C9E8).withValues(alpha: .22),
      );
    }
    final blue = Paint()
      ..color = const Color(0xFF4A86FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final red = Paint()
      ..color = const Color(0xFFFF594D)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final green = Paint()
      ..color = const Color(0xFF35C46A)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, apex, blue);
    canvas.drawLine(apex, end, red);
    canvas.drawLine(start, end, green);
    if (is3D) {
      canvas.drawLine(start, start + extrusion, blue..strokeWidth = 1.5);
      canvas.drawLine(apex, apex + extrusion, blue..strokeWidth = 1.5);
      canvas.drawLine(end, end + extrusion, blue..strokeWidth = 1.5);
      canvas.drawLine(start + extrusion, apex + extrusion, blue);
      canvas.drawLine(apex + extrusion, end + extrusion, red);
      canvas.drawLine(start + extrusion, end + extrusion, green);
    }
    final adjacent = hypotenuse * math.cos(radians);
    final opposite = hypotenuse * math.sin(radians);
    _label(
      canvas,
      'Hypotenuse = ${hypotenuse.toStringAsFixed(1)}',
      Offset(size.width * .07, size.height * .30),
      const Color(0xFF4A86FF),
    );
    _label(
      canvas,
      'Opposite = ${opposite.toStringAsFixed(2)}',
      Offset(size.width * .54, size.height * .34),
      const Color(0xFFFF594D),
    );
    _label(
      canvas,
      'Adjacent = ${adjacent.toStringAsFixed(2)}',
      Offset(size.width * .35, size.height * .83),
      const Color(0xFF35C46A),
    );
    _label(
      canvas,
      'θ = ${angle.toStringAsFixed(0)}°',
      Offset(start.dx + 12, baseY - 30),
      const Color(0xFF78A5FF),
    );
    canvas.drawCircle(start, 4, Paint()..color = Colors.white);
    canvas.drawCircle(end, 4, Paint()..color = Colors.white);
    canvas.drawCircle(apex, 4, Paint()..color = const Color(0xFF4A86FF));
  }

  void _paintTriangleSolid(Canvas canvas, Size size) {
    const xColor = Color(0xFFFF625A);
    const yColor = Color(0xFF57D68D);
    const zColor = Color(0xFF4A86FF);
    const surfaceColor = Color(0xFF36C9E8);
    final radians = angle * math.pi / 180;
    final adjacent = hypotenuse * math.cos(radians);
    final opposite = hypotenuse * math.sin(radians);
    final triangleArea = adjacent * opposite / 2;
    final depth = hypotenuse * .36;
    final sceneScale =
        math.min(
          size.width * .52 / (adjacent + depth),
          size.height * .46 / (opposite + depth),
        ) *
        zoom;
    final cy = math.cos(rotationY), sy = math.sin(rotationY);
    final cx = math.cos(rotationX), sx = math.sin(rotationX);
    final originX = size.width * .5;
    final originY = size.height * .52;
    var sceneShift = Offset.zero;

    (double, double, double) rotate((double, double, double) p) {
      final x = p.$1 * cy + p.$3 * sy;
      final z1 = -p.$1 * sy + p.$3 * cy;
      final y = p.$2 * cx - z1 * sx;
      final z = p.$2 * sx + z1 * cx;
      return (x, y, z);
    }

    Offset project((double, double, double) p) {
      final q = rotate(p);
      final perspective = 4.5 / (4.5 + q.$3 / hypotenuse);
      return Offset(
            originX + q.$1 * sceneScale * perspective,
            originY - q.$2 * sceneScale * perspective,
          ) +
          sceneShift;
    }

    const a = (0.0, 0.0, 0.0);
    final b = (adjacent, 0.0, 0.0);
    final c = (adjacent, opposite, 0.0);
    final backA = (0.0, 0.0, depth);
    final backB = (adjacent, 0.0, depth);
    final backC = (adjacent, opposite, depth);
    final projectedVertices = [
      a,
      b,
      c,
      backA,
      backB,
      backC,
    ].map(project).toList(growable: false);
    final left = projectedVertices.map((point) => point.dx).reduce(math.min);
    final right = projectedVertices.map((point) => point.dx).reduce(math.max);
    final top = projectedVertices.map((point) => point.dy).reduce(math.min);
    final bottom = projectedVertices.map((point) => point.dy).reduce(math.max);
    sceneShift = Offset(
      size.width * .5 - (left + right) / 2,
      size.height * .52 - (top + bottom) / 2,
    );
    final faces = <(List<(double, double, double)>, Color, double)>[
      ([a, b, c], surfaceColor, .86),
      ([backA, backC, backB], const Color(0xFF286FA8), .5),
      ([a, backA, backB, b], yColor, .48),
      ([b, backB, backC, c], xColor, .48),
      ([c, backC, backA, a], const Color(0xFF9B7EDE), .48),
    ];
    faces.sort((left, right) {
      double depthOf((List<(double, double, double)>, Color, double) face) =>
          face.$1.map((p) => rotate(p).$3).reduce((x, y) => x + y) /
          face.$1.length;
      return depthOf(left).compareTo(depthOf(right));
    });
    for (final face in faces) {
      final points = face.$1.map(project).toList(growable: false);
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = face.$2.withValues(alpha: face.$3),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFB8F4FF).withValues(alpha: .62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }

    void edge(
      (double, double, double) from,
      (double, double, double) to,
      Color color,
    ) => canvas.drawLine(
      project(from),
      project(to),
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    edge(a, b, yColor);
    edge(b, c, xColor);
    edge(c, a, const Color(0xFF9B7EDE));
    edge(backA, backB, yColor.withValues(alpha: .7));
    edge(backB, backC, xColor.withValues(alpha: .7));
    edge(backC, backA, zColor.withValues(alpha: .7));
    edge(a, backA, zColor);
    edge(b, backB, zColor);
    edge(c, backC, zColor);

    final angleArc = Path();
    final arcRadius = hypotenuse * .14;
    for (var step = 0; step <= 18; step++) {
      final arcAngle = radians * step / 18;
      final point = project((
        arcRadius * math.cos(arcAngle),
        arcRadius * math.sin(arcAngle),
        0,
      ));
      if (step == 0) {
        angleArc.moveTo(point.dx, point.dy);
      } else {
        angleArc.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      angleArc,
      Paint()
        ..color = const Color(0xFFFFC66D)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    final hypotenuseLabel = project((adjacent * .5, opposite * .54, 0));
    final adjacentLabel = project((adjacent * .5, 0, 0));
    final oppositeLabel = project((adjacent, opposite * .5, 0));
    _label(
      canvas,
      'Hypotenuse = ${hypotenuse.toStringAsFixed(1)}',
      Offset(hypotenuseLabel.dx - 65, hypotenuseLabel.dy - 24),
      zColor,
    );
    _label(
      canvas,
      'Adjacent = ${adjacent.toStringAsFixed(2)}',
      Offset(adjacentLabel.dx - 25, adjacentLabel.dy + 8),
      yColor,
    );
    _label(
      canvas,
      'Opposite = ${opposite.toStringAsFixed(2)}',
      Offset(oppositeLabel.dx + 8, oppositeLabel.dy - 8),
      xColor,
    );
    _metricBadge(
      canvas,
      'Shaded triangle | A = ½bh = ${triangleArea.toStringAsFixed(2)} units²',
      const Offset(12, 12),
      const Color(0xFFFFFFFF),
      maxWidth: size.width - 24,
    );
    _label(
      canvas,
      'θ = ${angle.toStringAsFixed(0)}°',
      project((.18 * adjacent, .05 * opposite, 0)) + const Offset(4, -18),
      const Color(0xFFFFC66D),
    );
  }

  void _paintAxes(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .09)
      ..strokeWidth = 1;
    for (var index = 1; index < 8; index++) {
      final x = size.width * index / 8;
      final y = size.height * index / 7;
      canvas.drawLine(Offset(x, 20), Offset(x, size.height - 28), grid);
      canvas.drawLine(Offset(24, y), Offset(size.width - 18, y), grid);
    }
    final axis = Paint()
      ..color = Colors.white.withValues(alpha: .65)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(28, size.height * .72),
      Offset(size.width - 18, size.height * .72),
      axis,
    );
    canvas.drawLine(
      Offset(size.width * .5, 16),
      Offset(size.width * .5, size.height - 20),
      axis,
    );
  }

  void _paintGraph(Canvas canvas, Size size, {String? functionExpression}) {
    _paintAxes(canvas, size);
    final plottedExpression = functionExpression ?? _plotExpression;
    Offset point(double x) {
      var y = slope * x + intercept;
      if (plottedExpression.trim().isNotEmpty &&
          (mode == _CalculatorMode.graphing ||
              mode == _CalculatorMode.calculus)) {
        try {
          y = const MathEngine().evaluateAt(plottedExpression, x);
        } on Object {
          y = double.nan;
        }
      }
      return Offset(size.width * (.5 + x / 12), size.height * (.72 - y / 24));
    }

    final path = Path();
    var connected = false;
    for (var index = 0; index <= 80; index++) {
      final x = -6 + index * 12 / 80;
      final p = point(x);
      if (!p.dy.isFinite) {
        connected = false;
      } else if (!connected) {
        path.moveTo(p.dx, p.dy);
        connected = true;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF4A86FF)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    final selected = point(selectedX);
    if (selected.dx.isFinite && selected.dy.isFinite) {
      canvas.drawCircle(selected, 6, Paint()..color = const Color(0xFFFF594D));
    }
    _label(
      canvas,
      expression.trim().isEmpty
          ? 'y = ${slope.toStringAsFixed(1)}x + ${intercept.toStringAsFixed(1)}'
          : 'y = ${functionExpression ?? expression}',
      const Offset(20, 16),
      Colors.white,
    );
    _label(
      canvas,
      'x = ${selectedX.toStringAsFixed(1)}',
      selected.dx.isFinite && selected.dy.isFinite
          ? Offset(selected.dx + 8, selected.dy - 22)
          : const Offset(20, 38),
      const Color(0xFFFF8A7F),
    );
  }

  void _paintDerivative(Canvas canvas, Size size) {
    final source = expression.trim().isEmpty ? 'x^2' : expression;
    _paintGraph(canvas, size, functionExpression: source);
    try {
      final derivative = const MathEngine().differentiate(source);
      final slopeAtPoint = const MathEngine().evaluateAt(derivative, selectedX);
      final yAtPoint = const MathEngine().evaluateAt(source, selectedX);
      final point = Offset(
        size.width * (.5 + selectedX / 12),
        size.height * (.72 - yAtPoint / 24),
      );
      const leftX = -5.5;
      const rightX = 5.5;
      double tangentY(double x) => yAtPoint + slopeAtPoint * (x - selectedX);
      canvas.drawLine(
        Offset(
          size.width * (.5 + leftX / 12),
          size.height * (.72 - tangentY(leftX) / 24),
        ),
        Offset(
          size.width * (.5 + rightX / 12),
          size.height * (.72 - tangentY(rightX) / 24),
        ),
        Paint()
          ..color = const Color(0xFFFF594D)
          ..strokeWidth = 2.5,
      );
      canvas.drawCircle(point, 5, Paint()..color = const Color(0xFFFF594D));
      _label(
        canvas,
        "f'(${selectedX.toStringAsFixed(1)}) = ${slopeAtPoint.toStringAsFixed(2)}",
        Offset(point.dx + 8, point.dy - 18),
        const Color(0xFFFF8A7F),
      );
    } on Object {
      _label(
        canvas,
        'Enter a differentiable function',
        const Offset(18, 18),
        Colors.white,
      );
    }
  }

  void _paintIntegral(Canvas canvas, Size size) {
    _paintAxes(canvas, size);
    final integrand = expression.trim().isEmpty ? 'x^2' : expression;
    double f(double x) {
      try {
        return const MathEngine().evaluateAt(integrand, x).clamp(-10, 10);
      } on Object {
        return 0;
      }
    }

    Offset point(double x) =>
        Offset(size.width * (.5 + x / 10), size.height * (.72 - f(x) / 28));
    final fill = Path()..moveTo(point(lower).dx, size.height * .72);
    for (var index = 0; index <= 60; index++) {
      final x = lower + (upper - lower) * index / 60;
      fill.lineTo(point(x).dx, point(x).dy);
    }
    fill.lineTo(point(upper).dx, size.height * .72);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = const Color(0xFF35C46A).withValues(alpha: .34)
        ..style = PaintingStyle.fill,
    );
    final curve = Path();
    for (var index = 0; index <= 80; index++) {
      final x = -5 + index * 10 / 80;
      final p = point(x);
      if (index == 0) {
        curve.moveTo(p.dx, p.dy);
      } else {
        curve.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = const Color(0xFF4A86FF)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
    _label(canvas, 'y = $integrand', const Offset(20, 16), Colors.white);
    _label(
      canvas,
      'a = ${lower.toStringAsFixed(1)}',
      Offset(point(lower).dx - 22, size.height * .76),
      const Color(0xFF78A5FF),
    );
    _label(
      canvas,
      'b = ${upper.toStringAsFixed(1)}',
      Offset(point(upper).dx - 22, size.height * .76),
      const Color(0xFF78A5FF),
    );
  }

  void _paintSurface(Canvas canvas, Size size) {
    const cells = 18;
    const min = -3.0;
    const max = 3.0;
    const engine = MathEngine();
    final enteredExpression = _plotExpression.trim();
    final source = _isExplicitZFunction
        ? _explicitZFunction
        : enteredExpression.isNotEmpty
        ? enteredExpression
        : mode == _CalculatorMode.calculus
        ? 'x^2+y^2'
        : '($slope)*x+($intercept)';
    final values = List<double>.filled((cells + 1) * (cells + 1), 0);
    int index(int x, int y) => y * (cells + 1) + x;
    double coordinate(int step) => min + (max - min) * step / cells;
    for (var y = 0; y <= cells; y++) {
      for (var x = 0; x <= cells; x++) {
        try {
          final px = coordinate(x), py = coordinate(y);
          values[index(x, y)] = engine.evaluateAtVariables(source, {
            'x': px,
            'y': py,
          });
        } on Object {
          values[index(x, y)] = double.nan;
        }
      }
    }
    final cosX = math.cos(rotationX), sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY), sinY = math.sin(rotationY);
    Offset project(double x, double y, double z) {
      final rotatedX = x * cosY + z * sinY;
      final rotatedZ = -x * sinY + z * cosY;
      final rotatedY = y * cosX - rotatedZ * sinX;
      final depth = y * sinX + rotatedZ * cosX;
      final perspective = 4.2 / (4.2 + depth / 1.5);
      final scale = math.min(size.width, size.height) * .13 * perspective;
      return Offset(
        size.width * .5 + rotatedX * scale,
        size.height * .55 - rotatedY * scale,
      );
    }

    double triangleArea(_PlotPoint3 a, _PlotPoint3 b, _PlotPoint3 c) {
      final ab = (b.$1 - a.$1, b.$2 - a.$2, b.$3 - a.$3);
      final ac = (c.$1 - a.$1, c.$2 - a.$2, c.$3 - a.$3);
      final cross = (
        ab.$2 * ac.$3 - ab.$3 * ac.$2,
        ab.$3 * ac.$1 - ab.$1 * ac.$3,
        ab.$1 * ac.$2 - ab.$2 * ac.$1,
      );
      return math.sqrt(
            cross.$1 * cross.$1 + cross.$2 * cross.$2 + cross.$3 * cross.$3,
          ) /
          2;
    }

    var meshArea = 0.0;
    var patchCount = 0;
    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < cells; x++) {
        final z = [
          values[index(x, y)],
          values[index(x + 1, y)],
          values[index(x + 1, y + 1)],
          values[index(x, y + 1)],
        ];
        if (z.any((value) => !value.isFinite)) continue;
        final vertices = <_PlotPoint3>[
          (coordinate(x), coordinate(y), z[0].clamp(-5, 5)),
          (coordinate(x + 1), coordinate(y), z[1].clamp(-5, 5)),
          (coordinate(x + 1), coordinate(y + 1), z[2].clamp(-5, 5)),
          (coordinate(x), coordinate(y + 1), z[3].clamp(-5, 5)),
        ];
        final average = z.reduce((a, b) => a + b) / z.length;
        final tint = ((average.clamp(-5, 5) + 5) / 10).toDouble();
        final faceColor = Color.lerp(
          const Color(0xFF7046C8),
          const Color(0xFF42C7D5),
          tint,
        )!;
        for (final face in [(0, 1, 2), (0, 2, 3)]) {
          final a = vertices[face.$1],
              b = vertices[face.$2],
              c = vertices[face.$3];
          final area = triangleArea(a, b, c);
          meshArea += area;
          patchCount++;
          final p = [
            project(a.$1, a.$2, a.$3),
            project(b.$1, b.$2, b.$3),
            project(c.$1, c.$2, c.$3),
          ];
          final triangle = Path()
            ..moveTo(p[0].dx, p[0].dy)
            ..lineTo(p[1].dx, p[1].dy)
            ..lineTo(p[2].dx, p[2].dy)
            ..close();
          canvas.drawPath(
            triangle,
            Paint()..color = faceColor.withValues(alpha: .82),
          );
          canvas.drawPath(
            triangle,
            Paint()
              ..color = const Color(0xFFE5F5FF).withValues(alpha: .58)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .7,
          );
        }
      }
    }
    final origin = project(0, 0, 0);
    for (final (end, color, label) in <(_PlotPoint3, Color, String)>[
      ((3.4, 0, 0), const Color(0xFFFF625A), 'x'),
      ((0, 3.4, 0), const Color(0xFF57D68D), 'y'),
      ((0, 0, 4), const Color(0xFF4A86FF), 'z'),
    ]) {
      final finish = project(end.$1, end.$2, end.$3);
      canvas.drawLine(
        origin,
        finish,
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      _label(canvas, label, finish + const Offset(3, -10), color);
    }
    _label(canvas, 'z = $source', const Offset(14, 12), Colors.white);
    _metricBadge(
      canvas,
      '$patchCount shaded faces | surface area ≈ ${meshArea.toStringAsFixed(2)} units²',
      Offset(12, size.height - 38),
      const Color(0xFF9BE7FF),
      maxWidth: size.width - 24,
    );
  }

  void _label(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 210);
    final bounds = canvas.getLocalClipBounds();
    final safeOffset = Offset(
      offset.dx.clamp(
        bounds.left + 4,
        math.max(bounds.left + 4, bounds.right - painter.width - 4),
      ),
      offset.dy.clamp(
        bounds.top + 4,
        math.max(bounds.top + 4, bounds.bottom - painter.height - 4),
      ),
    );
    painter.paint(canvas, safeOffset);
  }

  void _metricBadge(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(1, maxWidth - 16));
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        offset.dx,
        offset.dy,
        painter.width + 16,
        painter.height + 10,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xFF111827).withValues(alpha: .82),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: .42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    painter.paint(canvas, offset + const Offset(8, 5));
  }

  @override
  bool shouldRepaint(covariant _MathVisualizationPainter oldDelegate) => true;
}

class LessonsPage extends StatelessWidget {
  const LessonsPage({
    super.key,
    required this.progress,
    required this.onLearningActivity,
    required this.onLessonComplete,
  });

  final UserProgress progress;
  final Future<UserProgress> Function(String) onLearningActivity;
  final Future<UserProgress> Function(String) onLessonComplete;

  @override
  Widget build(BuildContext context) => _LessonsContent(
    progress: progress,
    onLearningActivity: onLearningActivity,
    onLessonComplete: onLessonComplete,
  );
}

class _LessonsContent extends StatefulWidget {
  const _LessonsContent({
    required this.progress,
    required this.onLearningActivity,
    required this.onLessonComplete,
  });

  final UserProgress progress;
  final Future<UserProgress> Function(String) onLearningActivity;
  final Future<UserProgress> Function(String) onLessonComplete;

  @override
  State<_LessonsContent> createState() => _LessonsContentState();
}

class _LessonsContentState extends State<_LessonsContent> {
  static const _orderOfOperationsId = 'lesson.order-of-operations.v1';
  final _search = TextEditingController();
  String _category = 'All';
  String _query = '';
  static const _categories = [
    'All',
    'Algebra',
    'Calculus',
    'Geometry',
    'Statistics',
    'Linear algebra',
  ];
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openOrderOfOperations() async {
    await widget.onLearningActivity(_orderOfOperationsId);
    if (!mounted) return;
    final completed = await showDialog<bool>(
      context: context,
      builder: (context) => const _OrderOfOperationsLesson(),
    );
    if (completed == true && mounted) {
      await widget.onLessonComplete(_orderOfOperationsId);
    }
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Lessons',
    subtitle: 'Search learning materials',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 19),
                    hintText: 'Search lessons',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Filter lessons',
              onPressed: _showFilters,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _categories.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    right: i == _categories.length - 1 ? 0 : 8,
                  ),
                  child: ChoiceChip(
                    label: Text(_categories[i]),
                    selected: _category == _categories[i],
                    onSelected: (_) =>
                        setState(() => _category = _categories[i]),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Continue learning',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _SectionCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFFFE7EC),
              child: Icon(Icons.functions_rounded, color: _accent, size: 16),
            ),
            title: const Text('Order of Operations'),
            subtitle: Text(
              widget.progress.completedLearningIds.contains(
                    _orderOfOperationsId,
                  )
                  ? 'Completed - +20 XP earned'
                  : 'Learn operation order - +5 XP to start, +20 XP to finish',
            ),
            trailing: IconButton(
              tooltip: 'Open Order of Operations lesson',
              onPressed: _openOrderOfOperations,
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
            onTap: _openOrderOfOperations,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Popular topics',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _SectionCard(
          child: Text(
            'Topic popularity requires shared, privacy-safe learner activity. No shared usage counts are available yet${_query.isEmpty ? '' : ' matching "$_query"'}${_category == 'All' ? '' : ' in $_category'}.',
          ),
        ),
      ],
    ),
  );

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final category in _categories)
              ListTile(
                title: Text(category),
                trailing: category == _category
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, category),
              ),
          ],
        ),
      ),
    );
    if (result != null && mounted) setState(() => _category = result);
  }
}

class _OrderOfOperationsLesson extends StatefulWidget {
  const _OrderOfOperationsLesson();

  @override
  State<_OrderOfOperationsLesson> createState() =>
      _OrderOfOperationsLessonState();
}

class _OrderOfOperationsLessonState extends State<_OrderOfOperationsLesson> {
  final _answer = TextEditingController();
  String? _feedback;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    if (_answer.text.trim() == '16') {
      Navigator.pop(context, true);
    } else {
      setState(() => _feedback = 'Try multiplication before addition.');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Order of Operations'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Do multiplication before addition. In 6 + 2 * 5, solve 2 * 5 first, then add 6.',
        ),
        const SizedBox(height: 14),
        const Text('What is 6 + 2 * 5?'),
        const SizedBox(height: 8),
        TextField(
          key: const Key('lesson-answer-input'),
          controller: _answer,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(),
          decoration: const InputDecoration(
            labelText: 'Answer',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _checkAnswer(),
        ),
        if (_feedback != null) ...[
          const SizedBox(height: 8),
          Text(
            _feedback!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Close'),
      ),
      FilledButton(onPressed: _checkAnswer, child: const Text('Check answer')),
    ],
  );
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, required this.displayName});
  final String displayName;
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  static const _postsKey = 'mathverse.community.posts.v1';
  final _search = TextEditingController();
  String _tab = 'For you';
  String _searchIn = 'Posts';
  List<_CommunityPost> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_postsKey);
    if (raw == null) return;
    try {
      final posts = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(_CommunityPost.fromJson)
          .toList();
      if (mounted) setState(() => _posts = posts);
    } on Object {
      // Ignore invalid cached data so it cannot prevent opening Community.
    }
  }

  Future<void> _createPost() async {
    final content = await showDialog<String>(
      context: context,
      builder: (_) => const _CreatePostDialog(),
    );
    if (content == null || !mounted) return;
    final updated = [
      _CommunityPost(
        author: widget.displayName,
        content: content,
        createdAt: DateTime.now(),
      ),
      ..._posts,
    ];
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _postsKey,
      jsonEncode(updated.map((post) => post.toJson()).toList()),
    );
    if (mounted) setState(() => _posts = updated);
  }

  List<_CommunityPost> get _visiblePosts {
    final query = _search.text.trim().toLowerCase();
    final posts = _posts
        .where(
          (post) =>
              query.isEmpty ||
              post.content.toLowerCase().contains(query) ||
              post.author.toLowerCase().contains(query),
        )
        .toList();
    return _tab == 'Top' ? posts.reversed.toList() : posts;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Community',
    subtitle: 'Questions, ideas, and learning together',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 19),
                    hintText: 'Search posts or users',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    suffixText: _searchIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Search filter',
              onPressed: _chooseSearchFilter,
              icon: const Icon(Icons.tune_rounded),
            ),
            IconButton.filled(
              tooltip: 'Create post',
              onPressed: _createPost,
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final tab in ['For you', 'Recent', 'Top'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Center(child: Text(tab)),
                    selected: _tab == tab,
                    onSelected: (_) => setState(() => _tab = tab),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_visiblePosts.isEmpty)
          _SectionCard(
            child: Text(
              _search.text.isEmpty
                  ? 'No posts yet. Start the conversation with a question or math idea.'
                  : 'No posts found matching: ${_search.text}',
            ),
          )
        else
          for (final post in _visiblePosts)
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          post.author.isEmpty
                              ? '?'
                              : post.author[0].toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.author,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _formatPostDate(post.createdAt),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(post.content),
                ],
              ),
            ),
      ],
    ),
  );

  Future<void> _chooseSearchFilter() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final type in ['Posts', 'Users'])
              ListTile(
                title: Text('Search $type'),
                trailing: type == _searchIn ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, type),
              ),
          ],
        ),
      ),
    );
    if (result != null && mounted) setState(() => _searchIn = result);
  }
}

class _CreatePostDialog extends StatefulWidget {
  const _CreatePostDialog();

  @override
  State<_CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<_CreatePostDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create a post'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      minLines: 3,
      maxLines: 7,
      maxLength: 1000,
      decoration: const InputDecoration(
        hintText: 'Ask a math question or share what you learned.',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final value = _controller.text.trim();
          if (value.isNotEmpty) Navigator.pop(context, value);
        },
        child: const Text('Post'),
      ),
    ],
  );
}

class _CommunityPost {
  const _CommunityPost({
    required this.author,
    required this.content,
    required this.createdAt,
  });
  final String author;
  final String content;
  final DateTime createdAt;
  Map<String, Object> toJson() => {
    'author': author,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };
  factory _CommunityPost.fromJson(Map<String, dynamic> json) => _CommunityPost(
    author: json['author'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

String _formatPostDate(DateTime date) {
  final age = DateTime.now().difference(date);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inDays < 1) return '${age.inHours}h ago';
  return '${age.inDays}d ago';
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.darkMode,
    required this.onDarkModeChanged,
    required this.onClearHistory,
    required this.onLogOut,
    required this.displayName,
    required this.username,
    required this.profileImagePath,
    required this.onPickProfilePhoto,
    required this.onSaveProfile,
  });
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final VoidCallback onClearHistory;
  final VoidCallback onLogOut;
  final String displayName, username;
  final String? profileImagePath;
  final VoidCallback onPickProfilePhoto;
  final Future<void> Function({
    String? name,
    String? username,
    String? imagePath,
  })
  onSaveProfile;

  @override
  Widget build(BuildContext context) => _PageFrame(
    title: 'Settings',
    subtitle: 'App preferences and local data',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsSection(
          title: 'Account',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage:
                    profileImagePath != null &&
                        File(profileImagePath!).existsSync()
                    ? FileImage(File(profileImagePath!))
                    : null,
                child:
                    profileImagePath == null ||
                        !File(profileImagePath!).existsSync()
                    ? const Icon(Icons.person_outline)
                    : null,
              ),
              title: Text(displayName),
              subtitle: Text(username),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editProfile(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Change profile photo'),
              onTap: onPickProfilePhoto,
            ),
            _unavailableTile(
              context,
              Icons.person_outline,
              'Profile information',
              'Birthday and address are not collected in this local-only build.',
            ),
            _unavailableTile(
              context,
              Icons.lock_outline,
              'Privacy & security',
              'Passwords, email verification, biometrics, and account security require an account service.',
            ),
            _unavailableTile(
              context,
              Icons.notifications_outlined,
              'Notifications',
              'Push notifications are not configured yet.',
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Log out'),
              subtitle: const Text('Return to the welcome page'),
              onTap: onLogOut,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: 'Appearance',
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Dark appearance'),
              value: darkMode,
              onChanged: onDarkModeChanged,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              subtitle: const Text('English (available now)'),
              onTap: () => _showInfo(
                context,
                'Language',
                'Additional translations are not included yet.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: 'App settings',
          children: [
            _unavailableTile(
              context,
              Icons.accessibility_new,
              'Accessibility',
              'More accessibility preferences are planned.',
            ),
            _unavailableTile(
              context,
              Icons.functions,
              'Math input settings',
              'The current calculator uses expression text input.',
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.cloud_off_outlined),
              title: Text('Offline mode'),
              subtitle: Text(
                'Calculations work offline. Cloud sync is not available.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSection(
          title: 'About',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline),
              title: const Text('Help & support'),
              onTap: () => _showInfo(
                context,
                'Help & support',
                'Support contact details are not configured yet.',
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline),
              title: Text('About Mathevo'),
              subtitle: Text(
                'Version 1.0.0+1 | Offline mathematics foundation',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline),
              title: const Text('Clear calculation history'),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear history?'),
                    content: const Text(
                      'This removes calculation history stored on this device.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) onClearHistory();
              },
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _editProfile(BuildContext context) async {
    var name = displayName;
    var handle = username;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: displayName,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (value) => name = value.trim(),
            ),
            TextFormField(
              initialValue: username,
              decoration: const InputDecoration(labelText: 'Username'),
              onChanged: (value) =>
                  handle = value.startsWith('@') ? value : '@$value',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save == true && name.isNotEmpty && handle.length > 1) {
      await onSaveProfile(name: name, username: handle);
    }
  }

  Widget _unavailableTile(
    BuildContext context,
    IconData icon,
    String title,
    String explanation,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _showInfo(context, title, explanation),
  );

  void _showInfo(BuildContext context, String title, String message) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      const SizedBox(height: 6),
      _SectionCard(child: Column(children: children)),
    ],
  );
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottomPadding = 96,
    this.fillAvailable = false,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final double bottomPadding;
  final bool fillAvailable;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth > 720 ? 680.0 : constraints.maxWidth;
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          height: fillAvailable ? constraints.maxHeight : null,
          child: fillAvailable
              ? Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.isNotEmpty || subtitle.isNotEmpty) ...[
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              top: title.isNotEmpty ? 5 : 0,
                            ),
                            child: Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      Expanded(child: child),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title.isNotEmpty || subtitle.isNotEmpty) ...[
                        if (title.isNotEmpty)
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                        if (subtitle.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(
                              top: title.isNotEmpty ? 5 : 0,
                            ),
                            child: Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      child,
                    ],
                  ),
                ),
        ),
      );
    },
  );
}

class _FaceAreaMeasurement {
  const _FaceAreaMeasurement(
    this.label,
    this.formula,
    this.area,
    this.color, {
    this.isCombined = false,
  });

  final String label;
  final String formula;
  final double area;
  final Color color;
  final bool isCombined;
}

class _FaceAreaCard extends StatelessWidget {
  const _FaceAreaCard({
    required this.area,
    required this.width,
    required this.diagram,
  });

  final _FaceAreaMeasurement area;
  final double width;
  final Widget diagram;

  @override
  Widget build(BuildContext context) => Container(
    key: Key('face-area-${area.label.toLowerCase().replaceAll(' ', '-')}'),
    width: width,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: area.isCombined
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : area.color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: area.isCombined
            ? Theme.of(context).colorScheme.outlineVariant
            : area.color.withValues(alpha: .55),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (!area.isCombined) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: area.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                area.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (!area.isCombined) ...[const SizedBox(height: 7), diagram],
        const SizedBox(height: 6),
        SizedBox(
          height: 20,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Math.tex(
              area.formula,
              mathStyle: MathStyle.text,
              textStyle: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${area.area.toStringAsFixed(2)} units²',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _FaceDiagramPainter extends CustomPainter {
  const _FaceDiagramPainter({
    required this.kind,
    required this.first,
    required this.second,
    required this.color,
  });

  final String kind;
  final double first;
  final double second;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (kind == 'none') return;
    final center = Offset(size.width / 2, size.height / 2);
    final fill = Paint()..color = color.withValues(alpha: .22);
    final outline = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    if (kind == 'circle' || kind == 'sphere') {
      final radius = math.min(size.height * .42, size.width * .18);
      canvas.drawCircle(center, radius, fill);
      canvas.drawCircle(center, radius, outline);
      if (kind == 'sphere') {
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: radius * .78,
            height: radius * 2,
          ),
          outline,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: radius * 2,
            height: radius * .72,
          ),
          outline,
        );
      } else {
        canvas.drawLine(
          center,
          center + Offset(radius * .72, -radius * .68),
          outline,
        );
      }
      return;
    }
    if (kind == 'sector') {
      final radius = math.min(size.height * .43, size.width * .27);
      final sweep = second.clamp(.18, math.pi * 2).toDouble();
      final start = -math.pi / 2 - sweep / 2;
      final path = Path()..moveTo(center.dx, center.dy);
      const points = 32;
      for (var i = 0; i <= points; i++) {
        final theta = start + sweep * i / points;
        path.lineTo(
          center.dx + radius * math.cos(theta),
          center.dy + radius * math.sin(theta),
        );
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, outline);
      return;
    }
    if (kind == 'triangle') {
      final scale = math.min(
        size.width * .58 / math.max(first, .1),
        size.height * .75 / math.max(second, .1),
      );
      final width = first * scale;
      final height = second * scale;
      final rect = Rect.fromCenter(
        center: center,
        width: width,
        height: height,
      );
      final path = Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.right, rect.top)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, outline);
      return;
    }

    final ratio = (first / math.max(second, .1)).clamp(.3, 4.0);
    final height = math.min(size.height * .58, size.width * .34 / ratio);
    final width = height * ratio;
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, outline);
    canvas.drawLine(
      Offset(rect.left, center.dy),
      Offset(rect.right, center.dy),
      outline..color = color.withValues(alpha: .5),
    );
  }

  @override
  bool shouldRepaint(covariant _FaceDiagramPainter oldDelegate) =>
      kind != oldDelegate.kind ||
      first != oldDelegate.first ||
      second != oldDelegate.second ||
      color != oldDelegate.color;
}

class _VisualizationZoomButton extends StatelessWidget {
  const _VisualizationZoomButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .94),
    shape: const CircleBorder(),
    elevation: 2,
    child: IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.backgroundColor,
    this.borderColor,
    this.padding = 14,
  });
  final Widget child;
  final Color? backgroundColor;
  final Color? borderColor;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? const Color(0xFFEFEAE6)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .018),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Material(color: Colors.transparent, child: child),
  );
}

class _ContinuedCalculatorPage extends StatefulWidget {
  const _ContinuedCalculatorPage({
    required this.record,
    required this.records,
    required this.onCalculation,
  });
  final CalculationRecord record;
  final List<CalculationRecord> records;
  final ValueChanged<CalculationRecord> onCalculation;

  @override
  State<_ContinuedCalculatorPage> createState() =>
      _ContinuedCalculatorPageState();
}

class _ContinuedCalculatorPageState extends State<_ContinuedCalculatorPage> {
  final _calculatorKey = GlobalKey<_CalculatorPageState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _calculatorKey.currentState?.continueWithHistory(widget.record);
      }
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: true,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) {
        _calculatorKey.currentState?.finishSession();
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Continue calculation')),
      body: SafeArea(
        child: CalculatorPage(
          key: _calculatorKey,
          records: widget.records,
          onCalculation: widget.onCalculation,
          onFullscreenChanged: (_) {},
          bottomPadding: 12,
        ),
      ),
    ),
  );
}

class _HistoryPage extends StatelessWidget {
  const _HistoryPage({required this.records, required this.onContinue});

  final List<CalculationRecord> records;
  final ValueChanged<CalculationRecord> onContinue;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('History')),
    body: records.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 42),
                  SizedBox(height: 12),
                  Text(
                    'No calculations yet',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Your saved computations will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'All ${records.length} saved computations',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final record in records)
                _HistoryTile(record: record, onContinue: onContinue),
            ],
          ),
  );
}

class _CalculationDetailPage extends StatelessWidget {
  const _CalculationDetailPage({
    required this.record,
    required this.onContinue,
  });
  final CalculationRecord record;
  final ValueChanged<CalculationRecord> onContinue;

  @override
  Widget build(BuildContext context) {
    final steps = record.expression
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    final localDate = record.createdAt.toLocal();
    return Scaffold(
      appBar: AppBar(title: const Text('Calculation details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(
            'Calculation session',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')} at ${TimeOfDay.fromDateTime(localDate).format(context)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Calculation breakdown',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < steps.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SectionCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${index + 1}.',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        steps[index],
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Final answer',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                SelectableText(
                  record.result,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(record.isExact ? 'Exact result' : 'Approximate result'),
                if (record.calculationCount > 1)
                  Text(
                    '${record.calculationCount} calculations in this session',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              onContinue(record);
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Continue working'),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, required this.onContinue});
  final CalculationRecord record;
  final ValueChanged<CalculationRecord> onContinue;

  @override
  Widget build(BuildContext context) {
    final firstLine = record.expression.split('\n').first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => _CalculationDetailPage(
                record: record,
                onContinue: onContinue,
              ),
            ),
          ),
          child: _SectionCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.result,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        record.calculationCount > 1
                            ? '${record.calculationCount} calculations - tap to view breakdown'
                            : 'Tap to view calculation',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
                const SizedBox(width: 8),
                Text(
                  '${record.createdAt.toLocal().month.toString().padLeft(2, '0')}/${record.createdAt.toLocal().day.toString().padLeft(2, '0')}\n${TimeOfDay.fromDateTime(record.createdAt.toLocal()).format(context)}',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
