import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_api.dart';
import 'auth_flow.dart';
import 'auth_token_store.dart';
import 'gamification.dart';
import 'math_engine.dart';
import 'math_history.dart';

void main() => runApp(const MathVerseApp());

const _navy = Color(0xFF17233D);
const _blue = Color(0xFF526DAB);
const _background = Color(0xFFF6F7FA);

class MathVerseApp extends StatefulWidget {
  const MathVerseApp({super.key, this.authApi, this.tokenStore});

  final AuthApi? authApi;
  final AuthTokenStore? tokenStore;

  @override
  State<MathVerseApp> createState() => _MathVerseAppState();
}

typedef MathevoApp = MathVerseApp;

class _MathVerseAppState extends State<MathVerseApp> {
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
            _navigatorKey.currentState?.pop();
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
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _background,
      colorScheme: ColorScheme.fromSeed(seedColor: _blue),
      fontFamily: 'Roboto',
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _blue,
        brightness: Brightness.dark,
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
        : MathVerseShell(
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

class MathVerseShell extends StatefulWidget {
  const MathVerseShell({
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
  State<MathVerseShell> createState() => _MathVerseShellState();
}

typedef MathevoShell = MathVerseShell;

class _MathVerseShellState extends State<MathVerseShell> {
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
        padding: const EdgeInsets.fromLTRB(34, 6, 34, 2),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
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
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
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
            height: 52,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  icon,
                  size: 21,
                  color: selected ? _blue : inactiveColor,
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
          const SizedBox(height: 14),
          _ProgressOverview(progress: progress),
          const SizedBox(height: 14),
          const Text(
            'Your workspace',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
          const SizedBox(height: 14),
          _DailyChallengeCard(
            onComplete: onDailyChallengeComplete,
            progress: progress,
          ),
          const SizedBox(height: 14),
          _LeaderboardPreview(
            displayName: displayName,
            username: username,
            progress: progress,
          ),
          const SizedBox(height: 18),
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
            const Text(
              'MathVerse',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            Text(
              displayName == 'Your name'
                  ? 'Good morning'
                  : 'Good morning, $displayName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      IconButton(
        onPressed: onHistory,
        tooltip: 'History',
        icon: const Icon(Icons.history_rounded),
      ),
      IconButton(
        onPressed: onNotifications,
        tooltip: 'Notifications',
        icon: const Icon(Icons.notifications_none_rounded),
      ),
      IconButton(
        onPressed: onLeaderboards,
        tooltip: 'Leaderboards',
        icon: const Icon(Icons.leaderboard_outlined),
      ),
    ],
  );
}

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
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: constraints.maxWidth < 350 ? .95 : 1.5,
      children: [
        _WorkspaceTile(
          title: 'Calculator',
          subtitle: latestCalculation == null
              ? 'Solve an expression'
              : '${latestCalculation!.expression} = ${latestCalculation!.result}',
          icon: Icons.calculate_outlined,
          color: _blue,
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
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: .32),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: color.withValues(alpha: .13),
              child: Icon(icon, color: color, size: 19),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
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
          '${record.expression} = ${record.result}',
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
            padding: const EdgeInsets.only(bottom: 8),
            child: _SectionCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.icon, color: _blue),
                title: Text(item.title),
                subtitle: Text(item.detail),
                trailing: Text(
                  TimeOfDay.fromDateTime(item.at).format(context),
                  style: Theme.of(context).textTheme.labelSmall,
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
    final answer = const MathEngine()
        .calculate(challenge.expression)
        .displayValue;
    return _ActivityItem(
      completedAt ?? date,
      'Daily challenge completed',
      '${challenge.expression} = $answer',
      Icons.local_fire_department_outlined,
    );
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
                  color: _blue,
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
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'This week',
                style: TextStyle(fontWeight: FontWeight.w600),
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
                    radius: 6,
                    backgroundColor: days[i]
                        ? _blue
                        : _blue.withValues(alpha: .13),
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
              width: 24,
              height: 30,
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
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
        ).textTheme.labelSmall?.copyWith(letterSpacing: .1, fontSize: 9),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: _blue),
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
        const SizedBox(height: 14),
        Text(
          _challenge.expression.replaceAll('*', 'x'),
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _answer,
          enabled: !_completed,
          keyboardType: TextInputType.none,
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Your answer',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _check(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _completed || _busy ? null : _check,
            child: Text(
              _completed
                  ? 'Done'
                  : _busy
                  ? 'Saving'
                  : 'Check',
            ),
          ),
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
        const Icon(Icons.leaderboard_outlined, color: _blue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Leaderboards',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 5),
              Text(
                'Local rank: #1 of 1 ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· ${progress.xp} XP',
              ),
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
  graphing,
  trigonometry,
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
    this.bottomPadding = 64,
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
  final _drawingBoundaryKey = GlobalKey();
  final _engine = const MathEngine();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  _CalculatorMode _mode = _CalculatorMode.basic;
  bool _fractionBuilder = false;
  bool _conversionOnly = true;
  bool _recognizingDrawing = false;
  bool _answerShown = false;
  int _sourceBase = 10;
  int _targetBase = 2;
  String _numberOperator = '+';
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
  double _triangleAngle = 41;
  double _triangleHypotenuse = 15.5;

  @override
  void dispose() {
    _drawingDebounce?.cancel();
    _input.dispose();
    _numerator.dispose();
    _denominator.dispose();
    _numberA.dispose();
    _numberB.dispose();
    unawaited(_recognizer.close());
    super.dispose();
  }

  void _insert(String value) {
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
      setState(() => _error = 'Enter both a numerator and denominator.');
      return;
    }
    _insert('(${_numerator.text})/(${_denominator.text})');
    setState(() {
      _fractionBuilder = false;
      _error = null;
    });
  }

  void _updateResult() {
    if (_mode == _CalculatorMode.graphing ||
        _mode == _CalculatorMode.algebra ||
        _mode == _CalculatorMode.calculus) {
      setState(() {
        _result = null;
        _error = null;
      });
      return;
    }
    try {
      final result = _engine.calculate(_input.text);
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
      });
    }
  }

  void _evaluate() {
    FocusScope.of(context).unfocus();
    final expression = _input.text.trim();
    if (expression.isEmpty) return;
    try {
      final calculation = _engine.calculate(expression);
      final answer = calculation.displayValue;
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
    }
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
        answer = switch (_numberOperator) {
          '+' => first + second,
          '-' => first - second,
          '*' => first * second,
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
      setState(() {
        _result = null;
        _error = error.message.toString().contains('divide')
            ? 'Cannot divide by zero.'
            : 'Use digits valid for base $_sourceBase.';
      });
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
      final recognized = await _recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      final expression = recognized.text
          .replaceAll(RegExp(r'(?i)\b(times|multiply by)\b'), '*')
          .replaceAll(RegExp(r'(?i)\b(divided by|over)\b'), '/')
          .replaceAll(RegExp(r'(?i)\b(plus)\b'), '+')
          .replaceAll(RegExp(r'(?i)\b(minus)\b'), '-')
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
        setState(() {
          _recognizedExpression = null;
          _result = null;
          _error = 'No expression recognized. Write larger and clearer.';
          _drawingStatus = 'Could not read the handwriting.';
        });
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
      setState(() {
        _recognizedExpression = null;
        _result = null;
        _error = 'Recognized text could not be solved: ${error.message}';
        _drawingStatus = 'Expression read, but unsupported.';
      });
    } on Object {
      setState(() {
        _error = 'Could not read the drawing. Write larger and clearer.';
        _drawingStatus = 'Recognition failed.';
      });
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

  void _pressFunction(String key) {
    if (key == 'C') {
      _input.clear();
      _updateResult();
    } else if (key == 'DEL') {
      final selection = _input.selection;
      final start = selection.isValid
          ? selection.start
          : (_input.text.isEmpty ? 0 : _input.text.length - 1);
      final end = selection.isValid ? selection.end : _input.text.length;
      _input.value = TextEditingValue(
        text: _input.text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
      );
      _updateResult();
    } else if (key == 'a/b') {
      setState(() => _fractionBuilder = !_fractionBuilder);
    } else {
      _insert(key);
    }
  }

  Future<void> _openTrianglePlot() async {
    final result = await Navigator.of(context).push<_TriangleParameters>(
      MaterialPageRoute<_TriangleParameters>(
        builder: (_) => _Triangle3DPage(
          angle: _triangleAngle,
          hypotenuse: _triangleHypotenuse,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _triangleAngle = result.angle;
      _triangleHypotenuse = result.hypotenuse;
      final radians = result.angle * math.pi / 180;
      _result = math.sin(radians).toStringAsFixed(4);
      _input.text = 'sin(${result.angle.toStringAsFixed(0)}°)';
      _answerShown = true;
    });
  }

  Widget _buildTrigonometryCalculator(BuildContext context) {
    final radians = _triangleAngle * math.pi / 180;
    final adjacent = _triangleHypotenuse * math.cos(radians);
    final opposite = _triangleHypotenuse * math.sin(radians);
    final area = adjacent * opposite / 2;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Right triangle and trigonometry'),
          const SizedBox(height: 8),
          Text(
            'sin(${_triangleAngle.toStringAsFixed(0)}°) = ${math.sin(radians).toStringAsFixed(4)}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Adjacent ${adjacent.toStringAsFixed(2)}  •  Opposite ${opposite.toStringAsFixed(2)}  •  Area ${area.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('open-3d-triangle-plot'),
            onPressed: _openTrianglePlot,
            icon: const Icon(Icons.view_in_ar_rounded),
            label: const Text('Open 3D triangle plot'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == _CalculatorMode.drawing) {
      return _buildDrawingCalculator(context);
    }
    return _PageFrame(
      title: 'Calculator',
      subtitle: '',
      bottomPadding: widget.bottomPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
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
                        _CalculatorMode.graphing => 'Graphing',
                        _CalculatorMode.trigonometry => 'Trigonometry',
                        _CalculatorMode.algebra => 'Algebra',
                        _CalculatorMode.calculus => 'Calculus',
                        _CalculatorMode.numberSystem => 'Number systems',
                        _CalculatorMode.drawing => 'Draw',
                      }),
                      selected: _mode == mode,
                      onSelected: (_) {
                        setState(() {
                          _mode = mode;
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
          const SizedBox(height: 5),
          if (_mode == _CalculatorMode.numberSystem)
            _buildNumberSystemCalculator(context)
          else if (_mode == _CalculatorMode.trigonometry)
            _buildTrigonometryCalculator(context)
          else if (_mode == _CalculatorMode.drawing)
            _buildDrawingCalculator(context)
          else if (_mode == _CalculatorMode.graphing ||
              _mode == _CalculatorMode.algebra ||
              _mode == _CalculatorMode.calculus)
            _SectionCard(
              child: Text(
                '${_mode.name[0].toUpperCase()}${_mode.name.substring(1)} operations are not available yet. This build has no graphing, symbolic algebra, or calculus engine.',
              ),
            )
          else
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildExpressionAnswer(context),
                  const SizedBox(height: 6),
                  _buildFunctionRow(),
                  const SizedBox(height: 5),
                  _buildResponsiveKeypad(context),
                  if (_fractionBuilder) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _numerator,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Numerator',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('/'),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _denominator,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Denominator',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Insert fraction',
                          onPressed: _insertFraction,
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      key: const Key('calculation-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpressionAnswer(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * .13)
        .clamp(76.0, 104.0)
        .toDouble();
    final panelColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: .48);
    if (_answerShown) {
      return Container(
        key: const Key('calculation-result-panel'),
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(15),
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
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    _result ?? '--',
                    key: const Key('calculation-result'),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
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
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        key: const Key('expression-input'),
        controller: _input,
        onChanged: (_) => _updateResult(),
        onSubmitted: (_) => _evaluate(),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        maxLines: 2,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        decoration: const InputDecoration(
          labelText: 'Expression',
          hintText: '12 + 8',
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildFunctionRow() {
    final functions = _mode == _CalculatorMode.scientific
        ? <(String, String)>[
            ('sin', 'sin('),
            ('cos', 'cos('),
            ('√', 'sqrt('),
            ('ln', 'log('),
            ('^', '^'),
            ('π', '3.141592653589793'),
            ('C', 'C'),
            ('DEL', 'DEL'),
          ]
        : <(String, String)>[
            ('(', '('),
            (')', ')'),
            ('^', '^'),
            ('a/b', 'a/b'),
            ('C', 'C'),
            ('DEL', 'DEL'),
          ];
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
                    onPressed: () => _pressFunction(key),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(36, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(label),
                  ),
                ),
              ),
          ],
        ),
      ),
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
                  ('x', '*'),
                  ('/', '/'),
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
            child: FittedBox(child: Text(label)),
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
            child: FittedBox(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
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
              ),
            ),
            if (!_conversionOnly) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  for (final operation in ['+', '-', '*', '/'])
                    ChoiceChip(
                      label: Text(operation),
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
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
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
                      if (_activeStroke.length > 1)
                        _drawingStrokes.add(_activeStroke);
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
            if (_recognizedExpression != null || _error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recognized: ${_recognizedExpression ?? '--'}'),
                          Text(
                            _result == null
                                ? (_error ?? '--')
                                : 'Answer: $_result',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
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

class _TriangleParameters {
  const _TriangleParameters({required this.angle, required this.hypotenuse});
  final double angle;
  final double hypotenuse;
}

class _Triangle3DPage extends StatefulWidget {
  const _Triangle3DPage({required this.angle, required this.hypotenuse});
  final double angle;
  final double hypotenuse;

  @override
  State<_Triangle3DPage> createState() => _Triangle3DPageState();
}

class _Triangle3DPageState extends State<_Triangle3DPage> {
  late double _angle = widget.angle;
  late double _hypotenuse = widget.hypotenuse;
  double _yaw = -.62;
  double _pitch = .42;
  double _zoom = 1.12;
  int? _orbitPointer;
  Offset? _lastOrbitPoint;

  double get _radians => _angle * math.pi / 180;
  double get _adjacent => _hypotenuse * math.cos(_radians);
  double get _opposite => _hypotenuse * math.sin(_radians);
  double get _triangleArea => _adjacent * _opposite / 2;
  double get _depth => _hypotenuse * .34;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('3D triangle plot'),
        actions: [
          IconButton(
            tooltip: 'Reset view',
            onPressed: () => setState(() {
              _yaw = -.62;
              _pitch = .42;
              _zoom = 1.12;
            }),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final chartHeight = math.min(constraints.maxWidth, 390.0);
            return SingleChildScrollView(
              physics: _orbitPointer == null
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: chartHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Listener(
                              key: const Key('triangle-3d-orbit-area'),
                              behavior: HitTestBehavior.opaque,
                              onPointerDown: (event) => setState(() {
                                _orbitPointer = event.pointer;
                                _lastOrbitPoint = event.localPosition;
                              }),
                              onPointerMove: (event) {
                                if (event.pointer != _orbitPointer ||
                                    _lastOrbitPoint == null) {
                                  return;
                                }
                                final delta =
                                    event.localPosition - _lastOrbitPoint!;
                                _lastOrbitPoint = event.localPosition;
                                setState(() {
                                  _yaw =
                                      (_yaw + delta.dx * .012) % (2 * math.pi);
                                  _pitch = (_pitch + delta.dy * .012).clamp(
                                    -1.48,
                                    1.48,
                                  );
                                });
                              },
                              onPointerUp: (event) {
                                if (event.pointer == _orbitPointer) {
                                  setState(() {
                                    _orbitPointer = null;
                                    _lastOrbitPoint = null;
                                  });
                                }
                              },
                              onPointerCancel: (event) {
                                if (event.pointer == _orbitPointer) {
                                  setState(() {
                                    _orbitPointer = null;
                                    _lastOrbitPoint = null;
                                  });
                                }
                              },
                              child: CustomPaint(
                                painter: _TrianglePrismPainter(
                                  angle: _angle,
                                  hypotenuse: _hypotenuse,
                                  yaw: _yaw,
                                  pitch: _pitch,
                                  zoom: _zoom,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Column(
                              children: [
                                _ZoomControl(
                                  label: '+',
                                  tooltip: 'Zoom in',
                                  onPressed: () => setState(
                                    () =>
                                        _zoom = (_zoom * 1.18).clamp(.65, 2.8),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                _ZoomControl(
                                  label: '−',
                                  tooltip: 'Zoom out',
                                  onPressed: () => setState(
                                    () =>
                                        _zoom = (_zoom / 1.18).clamp(.65, 2.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 10,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xD917233D),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Text(
                                  'Drag to orbit • + / − to zoom',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yaw ${(_yaw * 180 / math.pi).round()}°  •  Pitch ${(_pitch * 180 / math.pi).round()}°  •  Zoom ${_zoom.toStringAsFixed(1)}×',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Triangle sides',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 14,
                          runSpacing: 7,
                          children: [
                            _SideValue(
                              label: 'Hypotenuse',
                              value: _hypotenuse,
                              color: const Color(0xFF4A86FF),
                            ),
                            _SideValue(
                              label: 'Opposite',
                              value: _opposite,
                              color: const Color(0xFFFF625A),
                            ),
                            _SideValue(
                              label: 'Adjacent',
                              value: _adjacent,
                              color: const Color(0xFF35C46A),
                            ),
                            _SideValue(
                              label: 'Angle θ',
                              value: _angle,
                              color: const Color(0xFFFFD54A),
                              suffix: '°',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shaded face areas',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, box) {
                            final width = (box.maxWidth - 8) / 2;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _FaceAreaChip(
                                  width: width,
                                  color: const Color(0xFF24B8D0),
                                  label: 'Front triangle',
                                  formula: '½ × b × h',
                                  area: _triangleArea,
                                ),
                                _FaceAreaChip(
                                  width: width,
                                  color: const Color(0xFF526DAB),
                                  label: 'Back triangle',
                                  formula: '½ × b × h',
                                  area: _triangleArea,
                                ),
                                _FaceAreaChip(
                                  width: width,
                                  color: const Color(0xFF35C46A),
                                  label: 'Adjacent wall',
                                  formula: 'b × depth',
                                  area: _adjacent * _depth,
                                ),
                                _FaceAreaChip(
                                  width: width,
                                  color: const Color(0xFFFF625A),
                                  label: 'Opposite wall',
                                  formula: 'h × depth',
                                  area: _opposite * _depth,
                                ),
                                _FaceAreaChip(
                                  width: width,
                                  color: const Color(0xFF9B7EDE),
                                  label: 'Hypotenuse wall',
                                  formula: 'c × depth',
                                  area: _hypotenuse * _depth,
                                ),
                              ],
                            );
                          },
                        ),
                        const Divider(height: 22),
                        Text(
                          'Total prism surface area  ${(2 * _triangleArea + _depth * (_adjacent + _opposite + _hypotenuse)).toStringAsFixed(2)} units²',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _sliderCard(
                    context,
                    title: 'Angle θ',
                    value: _angle,
                    display: '${_angle.toStringAsFixed(0)}°',
                    min: 10,
                    max: 80,
                    onChanged: (value) => setState(() => _angle = value),
                  ),
                  const SizedBox(height: 8),
                  _sliderCard(
                    context,
                    title: 'Hypotenuse length',
                    value: _hypotenuse,
                    display: _hypotenuse.toStringAsFixed(1),
                    min: 5,
                    max: 35,
                    onChanged: (value) => setState(() => _hypotenuse = value),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      _TriangleParameters(
                        angle: _angle,
                        hypotenuse: _hypotenuse,
                      ),
                    ),
                    icon: const Icon(Icons.calculate_outlined),
                    label: Text(
                      'Use sin(${_angle.toStringAsFixed(0)}°) in calculator',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _sliderCard(
    BuildContext context, {
    required String title,
    required double value,
    required String display,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) => _SectionCard(
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Text(display, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _ZoomControl extends StatelessWidget {
  const _ZoomControl({
    required this.label,
    required this.tooltip,
    required this.onPressed,
  });
  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xEEFFFFFF),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Text(
        label,
        style: const TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: _navy,
        ),
      ),
    ),
  );
}

class _SideValue extends StatelessWidget {
  const _SideValue({
    required this.label,
    required this.value,
    required this.color,
    this.suffix = '',
  });
  final String label;
  final double value;
  final Color color;
  final String suffix;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text('$label ${value.toStringAsFixed(2)}$suffix'),
    ],
  );
}

class _FaceAreaChip extends StatelessWidget {
  const _FaceAreaChip({
    required this.width,
    required this.color,
    required this.label,
    required this.formula,
    required this.area,
  });
  final double width;
  final Color color;
  final String label;
  final String formula;
  final double area;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$formula = ${area.toStringAsFixed(2)} u²',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _TrianglePrismPainter extends CustomPainter {
  const _TrianglePrismPainter({
    required this.angle,
    required this.hypotenuse,
    required this.yaw,
    required this.pitch,
    required this.zoom,
  });
  final double angle;
  final double hypotenuse;
  final double yaw;
  final double pitch;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF1E2230), BlendMode.src);
    final theta = angle * math.pi / 180;
    final adjacent = hypotenuse * math.cos(theta);
    final opposite = hypotenuse * math.sin(theta);
    final depth = hypotenuse * .34;
    final cx = math.cos(pitch),
        sx = math.sin(pitch),
        cy = math.cos(yaw),
        sy = math.sin(yaw);
    final scale =
        math.min(size.width, size.height) *
        .72 /
        (hypotenuse + depth * .6) *
        zoom;
    (double, double, double) rotate((double, double, double) p) {
      final x = p.$1 * cy + p.$3 * sy;
      final z = -p.$1 * sy + p.$3 * cy;
      return (x, p.$2 * cx - z * sx, p.$2 * sx + z * cx);
    }

    Offset rawProject((double, double, double) p) {
      final q = rotate(p);
      final perspective = 6 / (6 + q.$3 / hypotenuse);
      return Offset(q.$1 * scale * perspective, -q.$2 * scale * perspective);
    }

    const a = (0.0, 0.0, 0.0);
    final b = (adjacent, 0.0, 0.0);
    final c = (adjacent, opposite, 0.0);
    final backA = (0.0, 0.0, depth);
    final backB = (adjacent, 0.0, depth);
    final backC = (adjacent, opposite, depth);
    final allVertices = [a, b, c, backA, backB, backC].map(rawProject).toList();
    final left = allVertices.map((point) => point.dx).reduce(math.min);
    final right = allVertices.map((point) => point.dx).reduce(math.max);
    final top = allVertices.map((point) => point.dy).reduce(math.min);
    final bottom = allVertices.map((point) => point.dy).reduce(math.max);
    final sceneShift = Offset(
      size.width * .5 - (left + right) * .5,
      size.height * .49 - (top + bottom) * .5,
    );
    Offset project((double, double, double) point) =>
        rawProject(point) + sceneShift;
    final faces = <({List<(double, double, double)> points, Color color})>[
      (points: [backA, backB, backC], color: const Color(0xFF526DAB)),
      (points: [a, backA, backB, b], color: const Color(0xFF35C46A)),
      (points: [b, backB, backC, c], color: const Color(0xFFFF625A)),
      (points: [c, backC, backA, a], color: const Color(0xFF9B7EDE)),
      (points: [a, b, c], color: const Color(0xFF24B8D0)),
    ];
    faces.sort((left, right) {
      double depthOf(List<(double, double, double)> points) =>
          points.map((p) => rotate(p).$3).reduce((x, y) => x + y) /
          points.length;
      return depthOf(left.points).compareTo(depthOf(right.points));
    });
    for (final face in faces) {
      final projected = face.points.map(project).toList();
      final path = Path()..moveTo(projected.first.dx, projected.first.dy);
      for (final point in projected.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = face.color.withValues(alpha: .88));
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: .76)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
    void edge(
      (double, double, double) p,
      (double, double, double) q,
      Color color,
      String label,
      Offset shift,
    ) {
      canvas.drawLine(
        project(p),
        project(q),
        Paint()
          ..color = color
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round,
      );
      final mid = (project(p) + project(q)) / 2 + shift;
      _text(canvas, label, mid, color, fontSize: 10);
    }

    edge(
      a,
      c,
      const Color(0xFF4A86FF),
      'c ${hypotenuse.toStringAsFixed(1)}',
      const Offset(-10, -14),
    );
    edge(
      b,
      c,
      const Color(0xFFFF625A),
      'h ${opposite.toStringAsFixed(1)}',
      const Offset(8, 0),
    );
    edge(
      a,
      b,
      const Color(0xFF35C46A),
      'b ${adjacent.toStringAsFixed(1)}',
      const Offset(0, 10),
    );
    for (final (p, q) in [(a, backA), (b, backB), (c, backC)]) {
      canvas.drawLine(
        project(p),
        project(q),
        Paint()
          ..color = const Color(0xFF4A86FF).withValues(alpha: .75)
          ..strokeWidth = 1.3,
      );
    }
    final arcRadius = math.min(adjacent, opposite) * .22;
    final arcPoints = <Offset>[];
    for (var index = 0; index <= 16; index++) {
      final t = theta * index / 16;
      arcPoints.add(
        project((arcRadius * math.cos(t), arcRadius * math.sin(t), 0)),
      );
    }
    final arc = Path()..moveTo(arcPoints.first.dx, arcPoints.first.dy);
    for (final point in arcPoints.skip(1)) {
      arc.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      arc,
      Paint()
        ..color = const Color(0xFFFFD54A)
        ..strokeWidth = 2.6
        ..style = PaintingStyle.stroke,
    );
    _text(
      canvas,
      'θ ${angle.toStringAsFixed(0)}°',
      project((arcRadius * 1.5, arcRadius * .6, 0)),
      const Color(0xFFFFD54A),
      fontSize: 10,
    );
    _drawAxes(canvas, size);
  }

  void _drawAxes(Canvas canvas, Size size) {
    final origin = Offset(size.width - 58, size.height - 54);
    for (final (vector, color, label) in <(Offset, Color, String)>[
      (const Offset(28, 0), const Color(0xFFFF625A), 'x'),
      (const Offset(0, -27), const Color(0xFF35C46A), 'y'),
      (const Offset(-19, -17), const Color(0xFF4A86FF), 'z'),
    ]) {
      final finish = origin + vector;
      canvas.drawLine(
        origin,
        finish,
        Paint()
          ..color = color
          ..strokeWidth = 1.8,
      );
      _text(canvas, label, finish, color, fontSize: 9);
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    Color color, {
    double fontSize = 11,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 110);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _TrianglePrismPainter oldDelegate) =>
      angle != oldDelegate.angle ||
      hypotenuse != oldDelegate.hypotenuse ||
      yaw != oldDelegate.yaw ||
      pitch != oldDelegate.pitch ||
      zoom != oldDelegate.zoom;
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
              child: TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search lessons',
                  border: OutlineInputBorder(),
                  isDense: true,
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
        const SizedBox(height: 14),
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
        const SizedBox(height: 18),
        const Text(
          'Continue learning',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _SectionCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE8EFFF),
              child: Icon(Icons.functions_rounded, color: _blue),
            ),
            title: const Text('Order of Operations'),
            subtitle: Text(
              widget.progress.completedLearningIds.contains(
                    _orderOfOperationsId,
                  )
                  ? 'Completed ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· +20 XP earned'
                  : 'Learn operation order ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· +5 XP to start, +20 XP to finish',
            ),
            trailing: IconButton(
              tooltip: 'Open Order of Operations lesson',
              onPressed: _openOrderOfOperations,
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
            onTap: _openOrderOfOperations,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Popular topics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _SectionCard(
          child: Text(
            'Topic popularity requires shared, privacy-safe learner activity. No shared usage counts are available yet${_query.isEmpty ? '' : ' matching ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“$_queryÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â'}${_category == 'All' ? '' : ' in $_category'}.',
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
          'Do multiplication before addition. In 6 + 2 ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 5, solve 2 ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 5 first, then add 6.',
        ),
        const SizedBox(height: 14),
        const Text('What is 6 + 2 ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 5?'),
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
    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a post'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          maxLength: 1000,
          decoration: const InputDecoration(
            hintText: 'Ask a math question or share what you learned?',
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
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
    controller.dispose();
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
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search posts or users',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixText: _searchIn,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Search filter',
              onPressed: _chooseSearchFilter,
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _createPost,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Create post'),
          ),
        ),
        const SizedBox(height: 10),
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
        const SizedBox(height: 12),
        if (_visiblePosts.isEmpty)
          _SectionCard(
            child: Text(
              _search.text.isEmpty
                  ? 'No posts yet. Start the conversation with a question or math idea.'
                  : 'No posts found for ?${_search.text}?.',
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
                  const SizedBox(height: 12),
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
              title: Text('About MathVerse'),
              subtitle: Text(
                'Version 1.0.0+1 ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· Offline mathematics foundation',
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
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
      ),
      const SizedBox(height: 8),
      _SectionCard(child: Column(children: children)),
    ],
  );
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottomPadding = 110,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final double bottomPadding;
  // THIS IS MY COMMENT LOL NVM THIS HAHAHAHAH
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth > 720 ? 680.0 : constraints.maxWidth;
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(22, 22, 22, bottomPadding),
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
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: title.isNotEmpty ? 5 : 0),
                      child: Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Theme.of(context).dividerColor.withValues(alpha: .35),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .025),
          blurRadius: 14,
          offset: const Offset(0, 4),
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
      if (mounted)
        _calculatorKey.currentState?.continueWithHistory(widget.record);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: true,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _calculatorKey.currentState?.finishSession();
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
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Calculation details'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(record.expression),
                    const SizedBox(height: 12),
                    Text(
                      'Final answer: ${record.result}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (record.calculationCount > 1)
                      Text(
                        '${record.calculationCount} calculations in this session',
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    onContinue(record);
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Continue working'),
                ),
              ],
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
                            ? '${record.calculationCount} calculations ? tap to view breakdown'
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
