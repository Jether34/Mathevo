part of '../main.dart';

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
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 7),
                const Flexible(
                  child: Text(
                    'Mathevo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
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
        iconSize: 23,
        onPressed: onHistory,
        tooltip: 'History',
        icon: const Icon(Icons.history_rounded),
      ),
      IconButton(
        style: _headerActionStyle,
        iconSize: 23,
        onPressed: onNotifications,
        tooltip: 'Notifications',
        icon: const Icon(Icons.notifications_none_rounded),
      ),
      IconButton(
        style: _headerActionStyle,
        iconSize: 23,
        onPressed: onLeaderboards,
        tooltip: 'Leaderboards',
        icon: const Icon(Icons.leaderboard_outlined),
      ),
    ],
  );
}

final _headerActionStyle = IconButton.styleFrom(
  foregroundColor: const Color(0xFF625B58),
  minimumSize: const Size(44, 44),
  maximumSize: const Size(44, 44),
  padding: EdgeInsets.zero,
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
      childAspectRatio: constraints.maxWidth < 350 ? 1.15 : 1.65,
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
                height: 44,
                child: TextField(
                  controller: _answer,
                  enabled: !_completed,
                  keyboardType: TextInputType.none,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Answer...',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _check(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              width: 78,
              child: FilledButton(
                onPressed: _completed || _busy ? null : _check,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(78, 44),
                  maximumSize: const Size(78, 44),
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
  discreteMath,
  statistics,
  probability,
  physics,
  drawing,
}

enum _DrawingResultMode { automatic, suggest, off }

enum _DrawingTool { pen, highlighter, eraser }

class _InkStroke {
  const _InkStroke({
    required this.points,
    required this.color,
    required this.width,
    this.isEraser = false,
  });

  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;
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
  final _integralLowerYInput = TextEditingController(text: '0');
  final _integralUpperYInput = TextEditingController(text: '1');
  final _integralLowerZInput = TextEditingController(text: '0');
  final _integralUpperZInput = TextEditingController(text: '1');
  final _limitApproachInput = TextEditingController(text: '0');
  final _drawingExpressionInput = TextEditingController();
  final _engine = const MathEngine();
  final _dataMathEngine = const StatisticsProbabilityEngine();
  TextRecognizer? _recognizer;
  StrokeSymbolModel? _strokeSymbolModel;
  _CalculatorMode _mode = _CalculatorMode.basic;
  bool _fractionBuilder = false;
  bool _fractionDenominatorSelected = false;
  int? _selectedIntegralBound;
  bool _errorDialogOpen = false;
  bool _conversionOnly = true;
  bool _numberBSelected = false;
  bool _recognizingDrawing = false;
  bool _readingStrokeSymbol = false;
  bool _drawingSolveSuggested = false;
  bool _buildingSymbolExpression = false;
  bool _answerShown = false;
  bool _showVisualization = false;
  bool _showVisualizationDetails = false;
  bool _showExpressionPlot = false;
  bool _visualIs3D = false;
  double _visualZoom = 1;
  double _visualAngle = 62;
  double _visualRotationX = 0;
  double _visualRotationY = 0;
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
  final List<_InkStroke> _drawingStrokes = [];
  final List<_InkStroke> _redoDrawingStrokes = [];
  List<Offset> _activeStroke = [];
  _DrawingTool _drawingTool = _DrawingTool.pen;
  _DrawingResultMode _drawingResultMode = _DrawingResultMode.automatic;
  Color _drawingInk = const Color(0xFF17233D);
  double _drawingInkWidth = 3.2;
  double _drawingPressure = 1;
  final Map<String, double> _drawingVariables = {};
  String? _recognizedExpression;
  String? _drawingStatus;
  List<StrokeSymbolPrediction> _strokeSymbolCandidates = [];
  String? _result;
  String? _error;
  bool _resultIsExact = false;
  Timer? _drawingDebounce;
  final List<String> _sessionBreakdown = [];
  String? _sessionFinalResult;
  bool _sessionIsExact = true;
  String _calculusFamily = 'Derivatives';
  String _calculusOperation = 'First derivative';
  String _derivativeNotation = 'Leibniz';
  String _partialVariable = 'x';
  final String _integrationVariable = 'x';
  bool _limitAtPositiveInfinity = true;
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
    _integralLowerYInput.dispose();
    _integralUpperYInput.dispose();
    _integralLowerZInput.dispose();
    _integralUpperZInput.dispose();
    _limitApproachInput.dispose();
    _drawingExpressionInput.dispose();
    final recognizer = _recognizer;
    if (recognizer != null) unawaited(recognizer.close());
    super.dispose();
  }

  void _insert(String value) {
    FocusScope.of(context).unfocus();
    if (_mode == _CalculatorMode.calculus && _selectedIntegralBound != null) {
      if (RegExp(r'^[0-9.\-]$').hasMatch(value)) {
        final controller = _calculusBoundControllers[_selectedIntegralBound!];
        final text = controller.text;
        final selection = controller.selection;
        final start = selection.isValid ? selection.start : text.length;
        final end = selection.isValid ? selection.end : text.length;
        controller.value = TextEditingValue(
          text: text.replaceRange(start, end, value),
          selection: TextSelection.collapsed(offset: start + value.length),
        );
        setState(() {});
        return;
      }
      _selectedIntegralBound = null;
    }
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

  List<TextEditingController> get _calculusBoundControllers => [
    _integralLowerInput,
    _integralUpperInput,
    _integralLowerYInput,
    _integralUpperYInput,
    _integralLowerZInput,
    _integralUpperZInput,
    _limitApproachInput,
  ];

  void _insertFraction() {
    if (_numerator.text.trim().isEmpty || _denominator.text.trim().isEmpty) {
      _showCalculationError('Enter both a numerator and denominator.');
      return;
    }
    final fraction = '(${_numerator.text})/(${_denominator.text})';
    setState(() => _fractionBuilder = false);
    if (_mode == _CalculatorMode.geometry) {
      final controller = _geometryUsesSecond ? _geometrySecond : _geometryFirst;
      controller.value = TextEditingValue(
        text: fraction,
        selection: TextSelection.collapsed(offset: fraction.length),
      );
      _calculateGeometry();
    } else {
      _insert(fraction);
    }
  }

  void _toggleSign() {
    if (!_fractionBuilder && _answerShown) {
      _input.text = _result ?? '';
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
      _result = null;
      _answerShown = false;
    }
    final controller = _fractionBuilder
        ? (_fractionDenominatorSelected ? _denominator : _numerator)
        : _input;
    final text = controller.text;
    final selection = controller.selection;
    final cursor = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    if (cursor != end) {
      final selected = text.substring(cursor, end);
      final toggled = selected.startsWith('-')
          ? selected.substring(1)
          : '-$selected';
      controller.value = TextEditingValue(
        text: text.replaceRange(cursor, end, toggled),
        selection: TextSelection.collapsed(offset: cursor + toggled.length),
      );
    } else {
      final prefix = text.substring(0, cursor);
      final number = RegExp(r'(-?(?:\d+\.?\d*|\.\d+))$').firstMatch(prefix);
      if (number == null) {
        _insert('-');
        return;
      }
      final token = number.group(1)!;
      final toggled = token.startsWith('-') ? token.substring(1) : '-$token';
      controller.value = TextEditingValue(
        text: text.replaceRange(number.start, cursor, toggled),
        selection: TextSelection.collapsed(
          offset: number.start + toggled.length,
        ),
      );
    }
    if (!_fractionBuilder) _updateResult();
    setState(() {});
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
      RegExp(r'\bpow\(([^,()]+),\s*([^()]+)\)'),
      (m) => '${m[1]}^{${m[2]}}',
    );
    tex = tex.replaceAllMapped(
      RegExp(r'\b(sqrt|cbrt)\(([^()]*)\)'),
      (m) => m[1] == 'sqrt' ? '\\sqrt{${m[2]}}' : '\\sqrt[3]{${m[2]}}',
    );
    tex = tex.replaceAllMapped(
      RegExp(r'\b(abs)\(([^()]*)\)'),
      (m) => r'\left|' + m[2]! + r'\right|',
    );
    tex = tex.replaceAllMapped(
      RegExp(
        r'\b(mean|average|median|mode|range|sum|count|variance|sampleVariance|stdev|sampleStdev|q1|q3|probability|complement|odds|binomial|combination|permutation|distance|velocity|speed|time)\(',
      ),
      (m) => '\\operatorname{${m[1]}}(',
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
    if (_calculusFamily == 'Derivatives') {
      final derivative = _derivativeNotation == 'Lagrange'
          ? (_calculusOperation == 'Second derivative' ? "f''" : "f'")
          : (_calculusOperation == 'Second derivative'
                ? r'\frac{d^2}{dx^2}'
                : r'\frac{d}{dx}');
      return '$derivative\\left($body\\right)';
    }
    if (_calculusFamily == 'Limits') return '\\lim_{x\\to a} $body';
    return switch (_calculusOperation) {
      'Indefinite integral' => '\\int $body\\,d$_integrationVariable',
      'Definite integral' =>
        '\\int_{${_integralLowerInput.text}}^{${_integralUpperInput.text}} $body\\,dx',
      'Double integral' => '\\iint $body\\,dx\\,dy',
      _ => '\\iiint $body\\,dx\\,dy\\,dz',
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
      if (_usesDataMathMode) {
        final result = _calculateDataMath(_input.text);
        setState(() {
          _result = result;
          _error = null;
          _resultIsExact = false;
          _answerShown = false;
        });
        return;
      }
      if (_mode == _CalculatorMode.graphing) {
        final graphLabel = _graphEquationLabel(_input.text);
        if (graphLabel != null) {
          setState(() {
            _result = graphLabel;
            _error = null;
            _resultIsExact = false;
            _answerShown = false;
          });
          return;
        }
      }
      if (_mode == _CalculatorMode.discreteMath) {
        final discrete = _engine.calculateDiscrete(_input.text);
        if (discrete != null) {
          setState(() {
            _result = discrete;
            _resultIsExact = false;
            _error = null;
            _answerShown = false;
          });
          return;
        }
      }
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

  bool get _usesDataMathMode =>
      _mode == _CalculatorMode.statistics ||
      _mode == _CalculatorMode.probability ||
      _mode == _CalculatorMode.physics;

  String _calculateDataMath(String expression) => switch (_mode) {
    _CalculatorMode.statistics => _dataMathEngine.calculateStatistics(
      expression,
    ),
    _CalculatorMode.probability => _dataMathEngine.calculateProbability(
      expression,
    ),
    _CalculatorMode.physics => _dataMathEngine.calculatePhysics(expression),
    _ => throw const MathInputException('Choose a math mode first.'),
  };

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

  String? _graphEquationLabel(String source) {
    final match = RegExp(
      r'^\s*([yz])\s*=\s*(.+)$',
      dotAll: true,
    ).firstMatch(source);
    if (match == null) return null;
    return '${match.group(1)} = ${match.group(2)}';
  }

  void _evaluate() {
    FocusScope.of(context).unfocus();
    final expression = _input.text.trim();
    if (expression.isEmpty) return;
    try {
      if (_usesDataMathMode) {
        final answer = _calculateDataMath(expression);
        setState(() {
          _result = answer;
          _error = null;
          _resultIsExact = false;
          _answerShown = true;
        });
        _appendSessionEntry(expression, answer, exact: false);
        return;
      }
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
        if (_calculusFamily == 'Derivatives') {
          final variable = _calculusOperation == 'Partial derivative'
              ? _partialVariable
              : 'x';
          final order = _calculusOperation == 'Second derivative' ? 2 : 1;
          var derivative = expression;
          for (var i = 0; i < order; i++) {
            derivative = _engine.differentiate(derivative, variable: variable);
          }
          final notation = _calculusOperation == 'Partial derivative'
              ? '∂/∂$variable'
              : _derivativeNotation == 'Lagrange'
              ? (order == 2 ? 'f″($variable)' : 'f′($variable)')
              : (order == 2 ? 'd²y/d$variable²' : 'dy/d$variable');
          setState(() {
            _result = '$notation = $derivative';
            _error = null;
            _resultIsExact = true;
            _answerShown = true;
          });
          _appendSessionEntry(
            '$notation ($expression)',
            derivative,
            exact: true,
          );
          return;
        }
        if (_calculusFamily == 'Integrals') {
          if (_calculusOperation == 'Indefinite integral') {
            final answer = _engine.integrateIndefinite(
              expression,
              variable: _integrationVariable,
            );
            setState(() {
              _result = answer;
              _error = null;
              _resultIsExact = true;
              _answerShown = true;
            });
            _appendSessionEntry(
              '∫ $expression d$_integrationVariable',
              answer,
              exact: true,
            );
            return;
          }
          final bounds = _calculusBoundControllers
              .take(6)
              .map((c) => double.parse(c.text.trim()))
              .toList();
          final MathResult result = _calculusOperation == 'Definite integral'
              ? _engine.integrateDefinite(
                  expression,
                  lower: bounds[0],
                  upper: bounds[1],
                  variable: _integrationVariable,
                )
              : _calculusOperation == 'Double integral'
              ? _engine.integrateDouble(
                  expression,
                  lowerX: bounds[0],
                  upperX: bounds[1],
                  lowerY: bounds[2],
                  upperY: bounds[3],
                )
              : _engine.integrateTriple(
                  expression,
                  lowerX: bounds[0],
                  upperX: bounds[1],
                  lowerY: bounds[2],
                  upperY: bounds[3],
                  lowerZ: bounds[4],
                  upperZ: bounds[5],
                );
          final answer = '≈ ${result.displayValue}';
          setState(() {
            _result = answer;
            _error = null;
            _resultIsExact = false;
            _answerShown = true;
          });
          _appendSessionEntry(
            '$_calculusOperation $expression',
            answer,
            exact: false,
          );
          return;
        }
        final side = switch (_calculusOperation) {
          'Left-hand limit' => LimitSide.left,
          'Right-hand limit' => LimitSide.right,
          'Limit at infinity' =>
            _limitAtPositiveInfinity
                ? LimitSide.positiveInfinity
                : LimitSide.negativeInfinity,
          _ => LimitSide.twoSided,
        };
        final point =
            side == LimitSide.positiveInfinity ||
                side == LimitSide.negativeInfinity
            ? 0.0
            : double.parse(_limitApproachInput.text.trim());
        final value = _engine.calculateLimit(
          expression,
          variable: 'x',
          point: point,
          side: side,
        );
        final limitText = value.isInfinite
            ? (value.isNegative ? '−∞' : '∞')
            : formatApproximateValue(value);
        final answer = 'lim = $limitText';
        setState(() {
          _result = answer;
          _error = null;
          _resultIsExact = false;
          _answerShown = true;
        });
        _appendSessionEntry(
          '$_calculusOperation $expression',
          answer,
          exact: false,
        );
        return;
      }
      if (_mode == _CalculatorMode.graphing) {
        final graphLabel = _graphEquationLabel(expression);
        if (graphLabel != null) {
          setState(() {
            _result = graphLabel;
            _error = null;
            _resultIsExact = false;
            _answerShown = true;
          });
          _appendSessionEntry(expression, graphLabel, exact: false);
          return;
        }
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
      if (_mode == _CalculatorMode.discreteMath) {
        final answer =
            _engine.calculateDiscrete(expression) ??
            _calculateExpression(expression).displayValue;
        setState(() {
          _result = answer;
          _error = null;
          _resultIsExact = false;
          _answerShown = true;
        });
        _appendSessionEntry(expression, answer, exact: false);
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
      double readDimension(TextEditingController controller) {
        final text = controller.text.trim();
        if (text.isEmpty) return 0;
        final value = _engine.calculate(text).value;
        if (value == null || !value.isFinite) throw const FormatException();
        return value;
      }

      final first = readDimension(_geometryFirst);
      final second = readDimension(_geometrySecond);
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
    if (_fractionBuilder) {
      if (key == 'C' || key == 'DEL') {
        _pressFunction(key);
      } else if (key == '±') {
        _toggleSign();
      } else {
        _insert(switch (key) {
          '×' => '*',
          '÷' => '/',
          'π' => 'pi',
          '√' => 'sqrt(',
          _ => key,
        });
      }
      return;
    }
    final controller = _geometryUsesSecond ? _geometrySecond : _geometryFirst;
    if (key == 'C') {
      controller.clear();
      _input.clear();
    } else if (key == '±') {
      final value = controller.text;
      controller.text = value.startsWith('-') ? value.substring(1) : '-$value';
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    } else {
      final inserted = switch (key) {
        '×' => '*',
        '÷' => '/',
        _ => key,
      };
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
          : controller.text.replaceRange(start, end, inserted);
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(
          offset: key == 'DEL' && start == end && start > 0
              ? start - 1
              : start + inserted.length,
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

  void _exitDrawingMode({_CalculatorMode destination = _CalculatorMode.basic}) {
    setState(() {
      _mode = destination;
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
        if (_numberOperator == 'pow' &&
            (second.isNegative || second > BigInt.from(4096))) {
          throw const FormatException(
            'The integer exponent must be from 0 to 4096.',
          );
        }
        answer = switch (_numberOperator) {
          '+' => first + second,
          '-' => first - second,
          '*' => first * second,
          '&' => first & second,
          '|' => first | second,
          '^' => first ^ second,
          'pow' => first.pow(second.toInt()),
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
    setState(() {
      _recognizingDrawing = true;
      _drawingStatus = 'Reading the expression...';
    });
    Directory? tempDirectory;
    try {
      final png = await _croppedDrawingPng();
      if (png == null) throw const FormatException();
      tempDirectory = await Directory.systemTemp.createTemp('mathverse-draw-');
      final file = File('${tempDirectory.path}/expression.png');
      await file.writeAsBytes(png);
      final recognizer = _recognizer ??= TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      var expression = _normalizeHandwrittenMath(recognized.text);
      var usedStrokeModel = false;
      if (expression.isEmpty) {
        expression = await _recognizeStrokeExpression() ?? '';
        usedStrokeModel = expression.isNotEmpty;
      }
      if (expression.isEmpty) {
        const message =
            'I could not read that yet. Write one clear line with larger symbols, then tap Analyze.';
        setState(() {
          _recognizedExpression = null;
          _drawingExpressionInput.clear();
          _result = null;
          _drawingSolveSuggested = false;
          _drawingStatus = message;
        });
        return;
      }
      setState(() {
        _recognizedExpression = expression;
        _drawingExpressionInput.text = expression;
        _result = null;
        _answerShown = false;
        _error = null;
        _drawingSolveSuggested = false;
        _drawingStatus = usedStrokeModel
            ? 'Possible expression read from your strokes. Check it before solving.'
            : 'Review the expression, then solve or continue editing.';
      });
      if (usedStrokeModel) {
        setState(() {
          _drawingSolveSuggested = true;
          _drawingStatus =
              'Possible expression read from your strokes. Check it, then tap Solve.';
        });
      } else if (_drawingResultMode == _DrawingResultMode.automatic) {
        _solveRecognizedDrawing();
      } else if (_drawingResultMode == _DrawingResultMode.suggest) {
        setState(() {
          _drawingSolveSuggested = true;
          _drawingStatus = 'Expression recognized. Tap Solve to calculate it.';
        });
      } else {
        setState(
          () => _drawingStatus = 'Expression recognized. Results are off.',
        );
      }
    } on MathInputException catch (error) {
      final message = 'Recognized text could not be solved: ${error.message}';
      setState(() {
        _recognizedExpression = null;
        _drawingExpressionInput.clear();
        _result = null;
        _drawingSolveSuggested = false;
        _drawingStatus = message;
      });
    } on Object {
      const message = 'Could not read the drawing. Write larger and clearer.';
      setState(() {
        _recognizedExpression = null;
        _drawingStatus = message;
        _drawingSolveSuggested = false;
      });
    } finally {
      if (tempDirectory != null) await tempDirectory.delete(recursive: true);
      if (mounted) setState(() => _recognizingDrawing = false);
    }
  }

  Future<Uint8List?> _croppedDrawingPng() async {
    final visible = _drawingStrokes.where((stroke) => stroke.points.isNotEmpty);
    final points = visible.expand((stroke) => stroke.points).toList();
    if (points.isEmpty) return null;
    final minX = points.map((point) => point.dx).reduce(math.min);
    final maxX = points.map((point) => point.dx).reduce(math.max);
    final minY = points.map((point) => point.dy).reduce(math.min);
    final maxY = points.map((point) => point.dy).reduce(math.max);
    final sourceWidth = math.max(1.0, maxX - minX);
    final sourceHeight = math.max(1.0, maxY - minY);
    const imageWidth = 1600;
    const imageHeight = 640;
    const padding = 64.0;
    final scale = math.min(
      (imageWidth - padding * 2) / sourceWidth,
      (imageHeight - padding * 2) / sourceHeight,
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
    for (final stroke in visible) {
      final mapped = stroke.points
          .map(
            (point) => ui.Offset(
              padding + (point.dx - minX) * scale,
              padding + (point.dy - minY) * scale,
            ),
          )
          .toList();
      final paint = ui.Paint()
        ..color = stroke.isEraser
            ? const ui.Color(0xFFFFFFFF)
            : const ui.Color(0xFF111111)
        ..strokeWidth = (stroke.width * scale).clamp(3.0, 30.0).toDouble()
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round
        ..style = ui.PaintingStyle.stroke;
      if (mapped.length == 1) {
        canvas.drawCircle(mapped.single, paint.strokeWidth / 2, paint);
      } else {
        final path = ui.Path()..moveTo(mapped.first.dx, mapped.first.dy);
        for (final point in mapped.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
    final image = await recorder.endRecording().toImage(
      imageWidth,
      imageHeight,
    );
    final data = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    if (data == null) return null;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<String?> _recognizeStrokeExpression() async {
    final model = _strokeSymbolModel ??= StrokeSymbolModel.fromJson(
      await rootBundle.loadString('assets/models/stroke_symbols.json'),
    );
    final strokes = _drawingStrokes
        .where((stroke) => !stroke.isEraser && stroke.points.isNotEmpty)
        .toList();
    if (strokes.isEmpty) return null;
    final allPoints = strokes.expand((stroke) => stroke.points).toList();
    final overallHeight = math.max(
      1.0,
      allPoints.map((point) => point.dy).reduce(math.max) -
          allPoints.map((point) => point.dy).reduce(math.min),
    );
    final joinGap = math.max(5.0, overallHeight * .22);
    final sorted = strokes.toList()
      ..sort((left, right) {
        final leftX = left.points.map((point) => point.dx).reduce(math.min);
        final rightX = right.points.map((point) => point.dx).reduce(math.min);
        return leftX.compareTo(rightX);
      });
    final groups = <List<_InkStroke>>[];
    var rightEdge = double.negativeInfinity;
    for (final stroke in sorted) {
      final leftEdge = stroke.points.map((point) => point.dx).reduce(math.min);
      final strokeRight = stroke.points
          .map((point) => point.dx)
          .reduce(math.max);
      if (groups.isEmpty || leftEdge > rightEdge + joinGap) {
        groups.add([stroke]);
        rightEdge = strokeRight;
      } else {
        groups.last.add(stroke);
        rightEdge = math.max(rightEdge, strokeRight);
      }
    }
    if (groups.length > 48) return null;
    final tokens = <String>[];
    for (final group in groups) {
      if (_looksLikeEquals(group)) {
        tokens.add('=');
        continue;
      }
      final features = await _featuresFromDrawingStrokes(
        model.inputSide,
        strokes: group,
      );
      if (features == null) return null;
      final predictions = model.predict(features);
      if (predictions.isEmpty || predictions.first.confidence < .25) {
        return null;
      }
      tokens.add(predictions.first.token.trim());
    }
    final expression = tokens.join();
    return RegExp(r'^[0-9+\-*/.^()=]+$').hasMatch(expression)
        ? expression
        : null;
  }

  bool _looksLikeEquals(List<_InkStroke> group) {
    if (group.length != 2) return false;
    final bounds = group.map((stroke) {
      final xs = stroke.points.map((point) => point.dx);
      final ys = stroke.points.map((point) => point.dy);
      return (
        xs.reduce(math.min),
        xs.reduce(math.max),
        ys.reduce(math.min),
        ys.reduce(math.max),
      );
    }).toList();
    final first = bounds[0];
    final second = bounds[1];
    final firstWidth = first.$2 - first.$1;
    final secondWidth = second.$2 - second.$1;
    final firstHeight = first.$4 - first.$3;
    final secondHeight = second.$4 - second.$3;
    final overlap =
        math.min(first.$2, second.$2) - math.max(first.$1, second.$1);
    final yGap = ((first.$3 + first.$4) / 2 - (second.$3 + second.$4) / 2)
        .abs();
    return firstWidth > 8 &&
        secondWidth > 8 &&
        firstHeight < firstWidth * .22 &&
        secondHeight < secondWidth * .22 &&
        overlap > math.min(firstWidth, secondWidth) * .55 &&
        yGap > 2 &&
        yGap < math.min(firstWidth, secondWidth) * .65;
  }

  Future<void> _recognizeOneStrokeSymbol() async {
    if (_drawingStrokes.isEmpty || _readingStrokeSymbol || !mounted) return;
    setState(() {
      _readingStrokeSymbol = true;
      _strokeSymbolCandidates = [];
      _drawingStatus = 'Reading one handwritten symbol...';
    });
    try {
      final model = _strokeSymbolModel ??= StrokeSymbolModel.fromJson(
        await rootBundle.loadString('assets/models/stroke_symbols.json'),
      );
      final features = await _featuresFromDrawingStrokes(model.inputSide);
      if (features == null) {
        setState(() {
          _drawingStatus =
              'No clear symbol found. Draw one symbol, then retry.';
        });
        return;
      }
      final predictions = model.predict(features);
      setState(() {
        _strokeSymbolCandidates = predictions;
        _drawingStatus =
            'Choose the closest symbol suggestion to add it to your expression.';
      });
    } on Object {
      setState(() {
        _strokeSymbolCandidates = [];
        _drawingStatus = 'The offline symbol reader could not load.';
      });
    } finally {
      if (mounted) setState(() => _readingStrokeSymbol = false);
    }
  }

  Future<List<double>?> _featuresFromDrawingStrokes(
    int inputSide, {
    List<_InkStroke>? strokes,
  }) async {
    final visible = (strokes ?? _drawingStrokes).where(
      (stroke) => stroke.points.isNotEmpty,
    );
    final points = visible
        .where((stroke) => !stroke.isEraser)
        .expand((stroke) => stroke.points)
        .toList();
    if (points.isEmpty) return null;
    final minX = points.map((point) => point.dx).reduce(math.min);
    final maxX = points.map((point) => point.dx).reduce(math.max);
    final minY = points.map((point) => point.dy).reduce(math.min);
    final maxY = points.map((point) => point.dy).reduce(math.max);
    final glyphSide = math.max(1.0, math.max(maxX - minX, maxY - minY));
    const rasterSide = 64;
    const margin = 10.0;
    final scale = (rasterSide - margin * 2) / glyphSide;
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    ui.Offset transform(Offset point) => ui.Offset(
      rasterSide / 2 + (point.dx - centerX) * scale,
      rasterSide / 2 + (point.dy - centerY) * scale,
    );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
    for (final stroke in visible) {
      final mapped = stroke.points.map(transform).toList();
      final paint = ui.Paint()
        ..color = const ui.Color(0xFF000000)
        ..strokeWidth = (stroke.width * scale).clamp(1.0, 14.0).toDouble()
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round
        ..style = ui.PaintingStyle.stroke
        ..blendMode = stroke.isEraser
            ? ui.BlendMode.clear
            : ui.BlendMode.srcOver;
      if (mapped.length == 1) {
        canvas.drawCircle(
          mapped.single,
          paint.strokeWidth / 2,
          paint..style = ui.PaintingStyle.fill,
        );
      } else {
        final path = ui.Path()..moveTo(mapped.first.dx, mapped.first.dy);
        for (final point in mapped.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
    final image = await recorder.endRecording().toImage(rasterSide, rasterSide);
    final data = await image.toByteData(format: ImageByteFormat.rawRgba);
    image.dispose();
    if (data == null) return null;
    return StrokeSymbolModel.featuresFromRgba(
      width: rasterSide,
      height: rasterSide,
      rgba: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      inputSide: inputSide,
    );
  }

  void _acceptStrokeSymbol(StrokeSymbolPrediction prediction) {
    final expression = '${_drawingExpressionInput.text}${prediction.token}';
    setState(() {
      _drawingExpressionInput.text = expression;
      _recognizedExpression = expression;
      _drawingStrokes.clear();
      _redoDrawingStrokes.clear();
      _activeStroke = [];
      _strokeSymbolCandidates = [];
      _buildingSymbolExpression = true;
      _result = null;
      _answerShown = false;
      _drawingSolveSuggested = false;
      _drawingStatus =
          'Added ${prediction.display}. Draw the next symbol or solve the expression.';
    });
  }

  void _beginDrawingStroke(Offset position) {
    final keepSymbolExpression = _buildingSymbolExpression;
    _drawingDebounce?.cancel();
    _drawingSolveSuggested = false;
    _strokeSymbolCandidates = [];
    if (!keepSymbolExpression) {
      _recognizedExpression = null;
      _drawingExpressionInput.clear();
    }
    _result = null;
    _drawingStatus = null;
    _activeStroke = [position];
  }

  String _normalizeHandwrittenMath(String handwriting) {
    final stacked = _verticalStackExpression(handwriting);
    if (stacked != null) return stacked;
    return handwriting
        .replaceAll(
          RegExp(r'\b(times|multiply by)\b', caseSensitive: false),
          '*',
        )
        .replaceAll(RegExp(r'\b(divided by|over)\b', caseSensitive: false), '/')
        .replaceAll(RegExp(r'\bplus\b', caseSensitive: false), '+')
        .replaceAll(RegExp(r'\bminus\b', caseSensitive: false), '-')
        .replaceAll(String.fromCharCode(0x00D7), '*')
        .replaceAll(String.fromCharCode(0x00F7), '/')
        .replaceAll(String.fromCharCode(0x2212), '-')
        .replaceAll(String.fromCharCode(0x2013), '-')
        .replaceAll(String.fromCharCode(0x03C0), 'pi')
        .replaceAllMapped(RegExp(r'(?<=\d)\s*[xX]\s*(?=[\d.(])'), (_) => '*')
        .replaceAll(RegExp(r'(?<=\d)[oO](?=\d|\b)'), '0')
        .replaceAll(RegExp(r'(?<=\d)[Il|](?=\d|\b)'), '1')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^0-9a-zA-Z.+\-*/^()=]'), '');
  }

  String? _verticalStackExpression(String handwriting) {
    final normalizedHandwriting = handwriting
        .replaceAll(String.fromCharCode(0x2014), '-')
        .replaceAll(String.fromCharCode(0x00D7), '*')
        .replaceAll(String.fromCharCode(0x00F7), '/');
    final lines = normalizedHandwriting
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim().replaceAll(',', '.'))
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 2) return null;
    final numberRows = <(String, String)>[];
    for (final line in lines) {
      if (RegExp(r'^[-_=|.]{2,}$').hasMatch(line)) continue;
      final match = RegExp(
        r'^([+\-*/xX]?)\s*(\d+(?:\.\d+)?)$',
      ).firstMatch(line);
      if (match == null) return null;
      var operator = match.group(1)!;
      if (operator.toLowerCase() == 'x') operator = '*';
      numberRows.add((operator, match.group(2)!));
    }
    if (numberRows.length < 2) return null;
    final expression = StringBuffer(numberRows.first.$2);
    for (final row in numberRows.skip(1)) {
      expression.write(row.$1.isEmpty ? '+' : row.$1);
      expression.write(row.$2);
    }
    return expression.toString();
  }

  void _solveRecognizedDrawing() {
    final source = _drawingExpressionInput.text.trim();
    if (source.isEmpty) return;
    final symbols = RegExp(
      r'[a-zA-Z]+',
    ).allMatches(source).map((match) => match.group(0)!).toSet();
    final assignment = RegExp(r'^([a-zA-Z])\s*=\s*(.+)$').firstMatch(source);
    try {
      if (symbols.contains('y') &&
          symbols.contains('x') &&
          RegExp(r'^\s*y\s*=', caseSensitive: false).hasMatch(source)) {
        setState(() {
          _recognizedExpression = source;
          _drawingStatus = 'Equation ready. Continue in Graphing to plot it.';
          _drawingSolveSuggested = false;
        });
        return;
      }
      if (assignment != null) {
        final name = assignment.group(1)!;
        final value = _engine.evaluateAtVariables(
          assignment.group(2)!,
          _drawingVariables,
        );
        _drawingVariables[name] = value;
        final formatted = _formatDrawingNumber(value);
        setState(() {
          _recognizedExpression = '$name = ${assignment.group(2)}';
          _result = '$name = $formatted';
          _drawingSolveSuggested = false;
          _drawingStatus = 'Saved $name for this drawing session.';
        });
        _appendSessionEntry(
          'Handwritten: $source',
          '$name = $formatted',
          exact: false,
        );
        return;
      }
      final expression = source.replaceFirst(RegExp(r'=+$'), '');
      final result = symbols.isEmpty
          ? _engine.calculate(expression)
          : _mathResultFromVariables(expression);
      setState(() {
        _recognizedExpression = expression;
        _result = result.displayValue;
        _resultIsExact = result.kind == MathResultKind.exact;
        _answerShown = true;
        _error = null;
        _drawingSolveSuggested = false;
        _drawingStatus = 'Solved. Check the transcription before continuing.';
      });
      _appendSessionEntry(
        'Handwritten: ${_prettyExpression(expression)}',
        result.displayValue,
        exact: result.kind == MathResultKind.exact,
      );
    } on MathInputException catch (error) {
      setState(() {
        _result = null;
        _drawingSolveSuggested = false;
        _drawingStatus = symbols.any(_drawingVariables.containsKey)
            ? 'Could not solve this expression: ${error.message}'
            : 'Unknown variable or unclear symbol. Edit the expression before solving.';
      });
    } on Object {
      setState(() {
        _result = null;
        _drawingSolveSuggested = false;
        _drawingStatus =
            'Could not solve this expression. Edit the transcription and try again.';
      });
    }
  }

  MathResult _mathResultFromVariables(String expression) {
    final value = _engine.evaluateAtVariables(expression, _drawingVariables);
    return MathResult(
      input: expression,
      value: value,
      kind: MathResultKind.approximate,
      significantDigits: 12,
    );
  }

  String _formatDrawingNumber(double value) =>
      formatApproximateValue(value, 10);

  void _clearDrawing() {
    _drawingDebounce?.cancel();
    setState(() {
      _drawingStrokes.clear();
      _redoDrawingStrokes.clear();
      _activeStroke = [];
      _strokeSymbolCandidates = [];
      _buildingSymbolExpression = false;
      _recognizedExpression = null;
      _drawingExpressionInput.clear();
      _drawingStatus = null;
      _drawingSolveSuggested = false;
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
        _redoDrawingStrokes.add(_drawingStrokes.removeLast());
      }
      _recognizedExpression = null;
      _drawingExpressionInput.clear();
      _drawingStatus = null;
      _drawingSolveSuggested = false;
      _result = null;
    });
    if (_drawingTool != _DrawingTool.eraser) _scheduleDrawingRecognition();
  }

  void _redoDrawingStroke() {
    if (_redoDrawingStrokes.isEmpty) return;
    setState(() {
      _drawingStrokes.add(_redoDrawingStrokes.removeLast());
      _drawingStatus = null;
    });
    _scheduleDrawingRecognition();
  }

  void _pressFunction(String key) {
    FocusScope.of(context).unfocus();
    if (key.startsWith('CALC_')) {
      final selection = switch (key) {
        'CALC_DERIVATIVE' || 'CALC_LEIBNIZ_FIRST' => (
          'Derivatives',
          'First derivative',
          'Leibniz',
          'x',
        ),
        'CALC_LAGRANGE_FIRST' => (
          'Derivatives',
          'First derivative',
          'Lagrange',
          'x',
        ),
        'CALC_LEIBNIZ_SECOND' => (
          'Derivatives',
          'Second derivative',
          'Leibniz',
          'x',
        ),
        'CALC_LAGRANGE_SECOND' => (
          'Derivatives',
          'Second derivative',
          'Lagrange',
          'x',
        ),
        'CALC_PARTIAL_X' => (
          'Derivatives',
          'Partial derivative',
          'Leibniz',
          'x',
        ),
        'CALC_PARTIAL_Y' => (
          'Derivatives',
          'Partial derivative',
          'Leibniz',
          'y',
        ),
        'CALC_PARTIAL_Z' => (
          'Derivatives',
          'Partial derivative',
          'Leibniz',
          'z',
        ),
        'CALC_INTEGRAL' => (
          'Integrals',
          'Indefinite integral',
          _derivativeNotation,
          'x',
        ),
        'CALC_DEFINITE_INTEGRAL' => (
          'Integrals',
          'Definite integral',
          _derivativeNotation,
          'x',
        ),
        'CALC_DOUBLE_INTEGRAL' => (
          'Integrals',
          'Double integral',
          _derivativeNotation,
          'x',
        ),
        'CALC_TRIPLE_INTEGRAL' => (
          'Integrals',
          'Triple integral',
          _derivativeNotation,
          'x',
        ),
        'CALC_LIMIT_LEFT' => (
          'Limits',
          'Left-hand limit',
          _derivativeNotation,
          'x',
        ),
        'CALC_LIMIT_RIGHT' => (
          'Limits',
          'Right-hand limit',
          _derivativeNotation,
          'x',
        ),
        'CALC_LIMIT_POS_INFINITY' => (
          'Limits',
          'Limit at infinity',
          _derivativeNotation,
          'x',
        ),
        'CALC_LIMIT_NEG_INFINITY' => (
          'Limits',
          'Limit at infinity',
          _derivativeNotation,
          'x',
        ),
        _ => ('Limits', 'Two-sided limit', _derivativeNotation, 'x'),
      };
      setState(() {
        _calculusFamily = selection.$1;
        _calculusOperation = selection.$2;
        _derivativeNotation = selection.$3;
        if (_calculusOperation == 'Partial derivative') {
          _partialVariable = selection.$4;
        }
        if (key == 'CALC_LIMIT_POS_INFINITY') _limitAtPositiveInfinity = true;
        if (key == 'CALC_LIMIT_NEG_INFINITY') _limitAtPositiveInfinity = false;
        _selectedIntegralBound = null;
        _result = null;
        _answerShown = false;
      });
    } else if (key == 'PERCENT') {
      _insert('/100');
    } else if (key == 'SIGN') {
      _toggleSign();
    } else if (key == 'VAR_C') {
      _insert('C');
    } else if (_mode == _CalculatorMode.calculus &&
        _selectedIntegralBound != null &&
        (key == 'C' || key == 'DEL')) {
      final controller = _calculusBoundControllers[_selectedIntegralBound!];
      if (key == 'C') {
        controller.clear();
      } else if (controller.text.isNotEmpty) {
        controller.text = controller.text.substring(
          0,
          controller.text.length - 1,
        );
      }
      setState(() {});
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
                              _CalculatorMode.calculus => 'Calculus',
                              _CalculatorMode.numberSystem => 'Number systems',
                              _CalculatorMode.discreteMath => 'Discrete math',
                              _CalculatorMode.statistics => 'Statistics',
                              _CalculatorMode.probability => 'Probability',
                              _CalculatorMode.physics => 'Physics',
                              _CalculatorMode.drawing => 'Draw',
                            }),
                            selected: _mode == mode,
                            onSelected: (_) {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _mode = mode;
                                _showVisualization = false;
                                _error = null;
                                _result = null;
                                _answerShown = false;
                                if (mode != _CalculatorMode.drawing) {
                                  _drawingSolveSuggested = false;
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
                  _mode != _CalculatorMode.discreteMath &&
                  _mode != _CalculatorMode.statistics &&
                  _mode != _CalculatorMode.probability &&
                  _mode != _CalculatorMode.physics &&
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
                    _buildCalculusControls(),
                    const SizedBox(height: 5),
                  ],
                  if (_usesDataMathMode) ...[
                    Text(
                      _mode == _CalculatorMode.statistics
                          ? 'Enter values in a function, for example mean(2, 4, 6).'
                          : _mode == _CalculatorMode.probability
                          ? 'Use probability(favorable, total), binomial(n, k, p), or complement(p).'
                          : 'Uniform motion: distance(12, 4) = 48; velocity(120, 4) = 30. Keep units consistent.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
    _CalculatorMode.algebra when !_isScalarVisualization =>
      'Algebra: equations and systems',
    _CalculatorMode.calculus => 'Calculus: function and area',
    _ when _isScalarVisualization => 'Scalar value',
    _ => 'Function graph',
  };

  int _signedDegrees(double radians) {
    final degrees = (radians * 180 / math.pi).round();
    return ((degrees + 180) % 360 + 360) % 360 - 180;
  }

  bool get _isScalarVisualization =>
      (_mode == _CalculatorMode.basic ||
          _mode == _CalculatorMode.scientific ||
          _mode == _CalculatorMode.graphing ||
          _mode == _CalculatorMode.algebra) &&
      _input.text.trim().isNotEmpty &&
      PlotFormula(_input.text).isScalar;

  bool get _isParametricPlot =>
      _mode == _CalculatorMode.graphing &&
      PlotFormula(_input.text).isParametricSurface;

  String get _visualizationSemanticsLabel {
    final finiteDifference = CentralDifferenceFormula.tryParse(_input.text);
    if (finiteDifference != null) {
      final dimension = _visualIs3D ? '3D' : '2D';
      return '$dimension plot of f of x equals x squared, with a secant at '
          'x equals ${finiteDifference.center} and step ${finiteDifference.step}. '
          'The approximate derivative is ${finiteDifference.approximateDerivative}. '
          'The x and y axes cross at zero and have numbered ticks. '
          '${_visualIs3D ? 'The z axis also has numbered ticks.' : ''} '
          'This is a curve and has no surface area.';
    }
    if (_isScalarVisualization) {
      final view = _mode == _CalculatorMode.graphing
          ? (_visualIs3D
                ? 'a shaded constant plane'
                : 'a horizontal constant function')
          : 'a scalar point';
      return '${_visualIs3D ? '3D' : '2D'} value ${_input.text.trim()}, shown as $view on numbered axes.';
    }
    if (_visualIs3D && _mode == _CalculatorMode.graphing) {
      final formula = PlotFormula(_input.text);
      if (!formula.isParametricSurface &&
          !formula.hasXYZ &&
          !formula.isExplicitY) {
        final source = formula.isExplicitZ
            ? formula.functionExpression
            : _input.text.trim().isEmpty
            ? '($_graphSlope)*x+($_graphIntercept)'
            : _input.text.trim();
        final ranges = _surfaceAxisRangesFor(source);
        return '3D function graph. ${ranges.description}. '
            'The x, y, and z axes stay fixed while the surface moves.';
      }
    }
    return '$_visualizationTitle, ${_visualIs3D ? '3D' : '2D'} view. '
        'The x and y axes cross at zero and show numbered ticks. '
        '${_visualIs3D ? 'Axis ranges follow the sampled object, and the x, y, and z axes stay fixed while it moves.' : ''}';
  }

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
        if (_calculusFamily == 'Derivatives') {
          final variable = _calculusOperation == 'Partial derivative'
              ? _partialVariable
              : 'x';
          final order = _calculusOperation == 'Second derivative' ? 2 : 1;
          var derivative = expression;
          for (var i = 0; i < order; i++) {
            derivative = _engine.differentiate(derivative, variable: variable);
          }
          return _engine.evaluateAt(derivative, _graphX, variable: variable);
        }
        if (_calculusFamily == 'Limits') {
          final side = switch (_calculusOperation) {
            'Left-hand limit' => LimitSide.left,
            'Right-hand limit' => LimitSide.right,
            'Limit at infinity' =>
              _limitAtPositiveInfinity
                  ? LimitSide.positiveInfinity
                  : LimitSide.negativeInfinity,
            _ => LimitSide.twoSided,
          };
          return _engine.calculateLimit(
            expression,
            variable: 'x',
            point: double.tryParse(_limitApproachInput.text) ?? 0,
            side: side,
          );
        }
        if (_calculusOperation == 'Indefinite integral') {
          final antiderivative = _engine
              .integrateIndefinite(expression, variable: _integrationVariable)
              .replaceFirst(RegExp(r'\s*\+\s*C$'), '');
          return _engine.evaluateAt(
            antiderivative,
            _graphX,
            variable: _integrationVariable,
          );
        }
        final bounds = _calculusBoundControllers
            .take(6)
            .map((c) => double.tryParse(c.text) ?? 0)
            .toList();
        if (_calculusOperation == 'Definite integral') {
          return _engine
              .integrateDefinite(
                expression,
                lower: bounds[0],
                upper: bounds[1],
                variable: _integrationVariable,
              )
              .value!;
        }
        if (_calculusOperation == 'Double integral') {
          return _engine
              .integrateDouble(
                expression,
                lowerX: bounds[0],
                upperX: bounds[1],
                lowerY: bounds[2],
                upperY: bounds[3],
              )
              .value!;
        }
        return _engine
            .integrateTriple(
              expression,
              lowerX: bounds[0],
              upperX: bounds[1],
              lowerY: bounds[2],
              upperY: bounds[3],
              lowerZ: bounds[4],
              upperZ: bounds[5],
            )
            .value!;
      } on Object {
        return double.nan;
      }
    }
    if (_mode == _CalculatorMode.graphing && _input.text.trim().isNotEmpty) {
      try {
        final equation = RegExp(
          r'^\s*([yz])\s*=\s*(.+)$',
          dotAll: true,
        ).firstMatch(_input.text);
        if (equation != null) {
          return _engine.evaluateAtVariables(equation.group(2)!, {
            'x': _graphX,
            'y': 0,
          });
        }
        return _engine.evaluateAt(_input.text, _graphX);
      } on Object {
        return double.nan;
      }
    }
    if (_isScalarVisualization) {
      try {
        return _engine.calculate(_input.text).value ?? double.nan;
      } on Object {
        return double.nan;
      }
    }
    return _graphSlope * _graphX + _graphIntercept;
  }

  String get _visualizationFormula {
    if (_isScalarVisualization) return _input.text.trim();
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
      if (_calculusFamily == 'Derivatives') {
        return '$_calculusOperation of $expression';
      }
      if (_calculusFamily == 'Limits') {
        return '$_calculusOperation of $expression';
      }
      if (_calculusOperation == 'Indefinite integral') {
        return 'Antiderivative of $expression';
      }
      return '$_calculusOperation of $expression';
    }
    if (_mode == _CalculatorMode.graphing && _input.text.trim().isNotEmpty) {
      return _graphEquationLabel(_input.text) ?? 'f(x) = ${_input.text}';
    }
    return 'f(${_graphX.toStringAsFixed(1)}) = ${_graphSlope.toStringAsFixed(1)} * ${_graphX.toStringAsFixed(1)} + ${_graphIntercept.toStringAsFixed(1)}';
  }

  String get _visualizationFormulaTex {
    if (_mode == _CalculatorMode.calculus) {
      final body = _mathTexFromSource(
        _input.text.trim().isEmpty ? 'x^2' : _input.text,
      );
      if (_calculusFamily == 'Derivatives') {
        return '\\frac{d}{dx}\\left($body\\right)';
      }
      if (_calculusFamily == 'Limits') {
        return '\\lim_{x\\to a} $body';
      }
      return switch (_calculusOperation) {
        'Indefinite integral' => '\\int $body\\,dx',
        'Definite integral' =>
          '\\int_{${_numberForExpression(_integralLower)}}^{${_numberForExpression(_integralUpper)}} $body\\,dx',
        'Double integral' => '\\iint $body\\,dx\\,dy',
        _ => '\\iiint $body\\,dx\\,dy\\,dz',
      };
    }
    return _mathTexFromSource(_visualizationFormula);
  }

  void _openVisualization() {
    _showVisualizationDetails = false;
    _showExpressionPlot = false;
    _visualZoom = 1;
    _visualRotationX = 0;
    _visualRotationY = 0;
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
    } else if (_mode == _CalculatorMode.graphing) {
      _visualIs3D =
          _input.text.trimLeft().startsWith('z=') ||
          (_input.text.contains('x') && _input.text.contains('y'));
      final linear = RegExp(
        r'^y=([-+]?(?:\d+(?:\.\d*)?|\.\d+))\*?x(?:([-+](?:\d+(?:\.\d*)?|\.\d+)))?$',
      ).firstMatch(expression);
      if (linear != null) {
        _graphSlope = double.tryParse(linear.group(1)!) ?? _graphSlope;
        _graphIntercept = double.tryParse(linear.group(2) ?? '0') ?? 0;
      }
    } else if (_mode == _CalculatorMode.algebra) {
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
      final parsedLower = double.tryParse(_integralLowerInput.text);
      final parsedUpper = double.tryParse(_integralUpperInput.text);
      _integralLower = parsedLower != null && parsedLower.isFinite
          ? parsedLower
          : 0;
      _integralUpper = parsedUpper != null && parsedUpper.isFinite
          ? parsedUpper
          : 2;
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
    if (_mode == _CalculatorMode.graphing) {
      setState(() {
        _result = null;
        _answerShown = false;
        _showVisualization = false;
      });
      return;
    }
    if (_mode == _CalculatorMode.algebra) {
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
    final lower = _integralLower.isFinite ? _integralLower : 0.0;
    final upper = _integralUpper.isFinite ? _integralUpper : 2.0;
    final integralStart = math.min(lower, upper);
    final integralEnd = math.max(lower, upper);
    final integralRangeMin = math.min(-4.0, integralStart);
    final integralRangeMax = math.max(4.0, integralEnd);
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
            key: const Key('visualization-plot-frame'),
            height: (MediaQuery.sizeOf(context).height * .27)
                .clamp(190.0, 260.0)
                .toDouble(),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2230),
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedSwitcher(
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
                            : Semantics(
                                key: const Key('visualization-chart-semantics'),
                                label: _visualizationSemanticsLabel,
                                child: CustomPaint(
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
                      if (_visualIs3D && !_showVisualizationDetails)
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.center,
                            child: GestureDetector(
                              key: const Key('visualization-object-gesture'),
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragUpdate: (details) {
                                setState(() {
                                  const fullTurn = 2 * math.pi;
                                  _visualRotationY =
                                      (_visualRotationY +
                                          details.delta.dx * .008) %
                                      fullTurn;
                                });
                              },
                              onVerticalDragUpdate: (details) {
                                setState(() {
                                  const fullTurn = 2 * math.pi;
                                  _visualRotationX =
                                      (_visualRotationX +
                                          details.delta.dy * .008) %
                                      fullTurn;
                                });
                              },
                              child: const FractionallySizedBox(
                                widthFactor: .76,
                                heightFactor: .76,
                                child: SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                    ],
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
                    'Drag to rotate the 3D object. Axes stay fixed | yaw ${_signedDegrees(_visualRotationY)}\u00B0 | pitch ${_signedDegrees(_visualRotationX)}\u00B0',
                    key: const Key('visualization-orientation'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  key: const Key('visualization-reset-view'),
                  tooltip: 'Reset 3D view',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    _visualRotationX = 0;
                    _visualRotationY = 0;
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
          if (!_isParametricPlot)
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
                              onErrorFallback: (_) =>
                                  Text(_visualizationFormula),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _isScalarVisualization
                              ? 'Evaluated value'
                              : 'Adjusted result',
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
                    key: const Key('visualization-adjusted-value'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (_isParametricPlot) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Parametric surface. The plot reports its sampled surface area; use the fixed axes to compare its orientation and scale.',
              ),
            ),
          ] else if (isTriangle) ...[
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
              'Integration interval  [${integralStart.toStringAsFixed(1)}, ${integralEnd.toStringAsFixed(1)}]',
            ),
            RangeSlider(
              values: RangeValues(integralStart, integralEnd),
              min: integralRangeMin,
              max: integralRangeMax,
              divisions: 80,
              labels: RangeLabels(
                integralStart.toStringAsFixed(1),
                integralEnd.toStringAsFixed(1),
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
              _input.text.trim().isNotEmpty &&
              !_isScalarVisualization &&
              !_isParametricPlot) ...[
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
          ] else if (_isScalarVisualization) ...[
            Text(
              'This expression has no independent variable to adjust.',
              style: Theme.of(context).textTheme.bodySmall,
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
        key: ValueKey('visualization-slider-$label'),
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
        child: Material(
          type: MaterialType.transparency,
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
              if (_mode != _CalculatorMode.calculus)
                ExpansionTile(
                  key: const Key('calculation-steps-dropdown'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  title: const Text('Step-by-step calculation'),
                  leading: const Icon(Icons.expand_more_rounded),
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (index, step)
                                in _detailedSteps().indexed)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 26,
                                      child: Text('${index + 1}.'),
                                    ),
                                    Expanded(
                                      child: Math.tex(
                                        _mathTexFromSource(step),
                                        mathStyle: MathStyle.display,
                                        textStyle: const TextStyle(
                                          fontSize: 17,
                                        ),
                                        onErrorFallback: (_) => Text(step),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
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
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Expression'),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_selectedIntegralBound != null) {
                  setState(() => _selectedIntegralBound = null);
                }
              },
              child: _fractionBuilder
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
                  : SizedBox.expand(
                      child:
                          _input.text.trim().isEmpty &&
                              _mode != _CalculatorMode.geometry
                          ? const Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                'Use the calculator keys to enter an expression',
                                style: TextStyle(
                                  color: Colors.black45,
                                  fontSize: 16,
                                ),
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
                                      _rawExpressionFallback(),
                                ),
                              ),
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rawExpressionFallback() {
    final visible = _input.text
        .replaceAll('*', '×')
        .replaceAll('/', '÷')
        .replaceAll('pi', 'π');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          visible.isEmpty ? '□' : visible,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  List<String> _detailedSteps() {
    final expression = _input.text.trim();
    if (expression.isEmpty) {
      return [_expressionTex, '=${_result ?? ''}'];
    }
    if (_mode == _CalculatorMode.algebra) {
      try {
        if (expression.contains(';')) {
          return _engine.solveLinearSystem(expression).steps;
        }
        if (expression.contains('=')) {
          return _engine.solveEquation(expression).steps;
        }
      } on Object {
        // Continue with evaluated reductions for supported expressions.
      }
    }
    try {
      final steps = _engine.solutionSteps(expression);
      if (steps.isNotEmpty) return steps;
    } on Object {
      // The selected domain may use a different evaluator; show the entered
      // expression and verified result instead of inventing symbolic steps.
    }
    return [_prettyExpression(expression), _result ?? ''];
  }

  Widget _inlineFractionEditor() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 102,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Numerator', style: TextStyle(fontSize: 10)),
            SizedBox(height: 34, child: _fractionField(_numerator, false)),
            Container(height: 2, color: Theme.of(context).colorScheme.primary),
            SizedBox(height: 34, child: _fractionField(_denominator, true)),
            const Text('Denominator', style: TextStyle(fontSize: 10)),
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
        key: Key(
          denominator
              ? 'fraction-denominator-input'
              : 'fraction-numerator-input',
        ),
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

  Widget _buildCalculusControls() {
    final boundFields = switch (_calculusOperation) {
      'Definite integral' => <(TextEditingController, String, int)>[
        (_integralLowerInput, 'Lower bound', 0),
        (_integralUpperInput, 'Upper bound', 1),
      ],
      'Double integral' => <(TextEditingController, String, int)>[
        (_integralLowerInput, 'x lower', 0),
        (_integralUpperInput, 'x upper', 1),
        (_integralLowerYInput, 'y lower', 2),
        (_integralUpperYInput, 'y upper', 3),
      ],
      'Triple integral' => <(TextEditingController, String, int)>[
        (_integralLowerInput, 'x lower', 0),
        (_integralUpperInput, 'x upper', 1),
        (_integralLowerYInput, 'y lower', 2),
        (_integralUpperYInput, 'y upper', 3),
        (_integralLowerZInput, 'z lower', 4),
        (_integralUpperZInput, 'z upper', 5),
      ],
      'Two-sided limit' ||
      'Left-hand limit' ||
      'Right-hand limit' => <(TextEditingController, String, int)>[
        (_limitApproachInput, 'x approaches', 6),
      ],
      _ => <(TextEditingController, String, int)>[],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Selected calculus operation: $_calculusOperation',
          child: Text(
            _calculusOperationSymbol,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        if (boundFields.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final field in boundFields)
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: field.$1,
                    readOnly: true,
                    keyboardType: TextInputType.none,
                    onTap: () =>
                        setState(() => _selectedIntegralBound = field.$3),
                    decoration: InputDecoration(
                      labelText: field.$2,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  String get _calculusOperationSymbol => switch (_calculusOperation) {
    'First derivative' => _derivativeNotation == 'Lagrange' ? 'f′(x)' : 'dy/dx',
    'Second derivative' =>
      _derivativeNotation == 'Lagrange' ? 'f″(x)' : 'd²y/dx²',
    'Partial derivative' => '∂/∂$_partialVariable',
    'Indefinite integral' => '∫',
    'Definite integral' => '∫ₐᵇ',
    'Double integral' => '∬',
    'Triple integral' => '∭',
    'Two-sided limit' => 'limₓ→ₐ',
    'Left-hand limit' => 'limₓ→ₐ⁻',
    'Right-hand limit' => 'limₓ→ₐ⁺',
    _ => _limitAtPositiveInfinity ? 'limₓ→∞' : 'limₓ→−∞',
  };

  Widget _buildFunctionRow() {
    final List<(String, String)> functions = switch (_mode) {
      _CalculatorMode.algebra => [
        ('x', 'x'),
        ('y', 'y'),
        ('\u03C0', 'pi'),
        ('e', 'e'),
        ('=', '='),
        (';', ';'),
        ('xʸ', '^'),
        ('±', 'SIGN'),
        ('a/b', 'a/b'),
        ('[', '['),
        (']', ']'),
        ('(', '('),
        (')', ')'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _CalculatorMode.calculus => [
        ('dy/dx', 'CALC_LEIBNIZ_FIRST'),
        ('f′', 'CALC_LAGRANGE_FIRST'),
        ('d²y/dx²', 'CALC_LEIBNIZ_SECOND'),
        ('f″', 'CALC_LAGRANGE_SECOND'),
        ('∂/∂x', 'CALC_PARTIAL_X'),
        ('∂/∂y', 'CALC_PARTIAL_Y'),
        ('∂/∂z', 'CALC_PARTIAL_Z'),
        ('∫', 'CALC_INTEGRAL'),
        ('∫ₐᵇ', 'CALC_DEFINITE_INTEGRAL'),
        ('∬', 'CALC_DOUBLE_INTEGRAL'),
        ('∭', 'CALC_TRIPLE_INTEGRAL'),
        ('limₓ→ₐ', 'CALC_LIMIT_TWO'),
        ('limₓ→ₐ⁻', 'CALC_LIMIT_LEFT'),
        ('limₓ→ₐ⁺', 'CALC_LIMIT_RIGHT'),
        ('limₓ→∞', 'CALC_LIMIT_POS_INFINITY'),
        ('limₓ→−∞', 'CALC_LIMIT_NEG_INFINITY'),
        ('x', 'x'),
        ('y', 'y'),
        ('z', 'z'),
        ('f(x)', 'f(x)'),
        ('f(g(x))', 'f(g(x))'),
        ('f⁻¹(x)', 'f^(-1)'),
        ('|x|', 'abs('),
        ('exp', 'exp('),
        ('ln', 'ln('),
        ('log₁₀', 'log10('),
        ('log base', 'log('),
        ('x²', '^2'),
        ('x³', '^3'),
        ('xⁿ', '^'),
        ('x⁻¹', '^(-1)'),
        ('x^(m/n)', '^(1/2)'),
        ('√x', 'sqrt('),
        ('∛x', 'cbrt('),
        ('ⁿ√x', 'nrt('),
        ('sin', 'sin('),
        ('cos', 'cos('),
        ('tan', 'tan('),
        ('csc', 'csc('),
        ('sec', 'sec('),
        ('cot', 'cot('),
        ('arcsin', 'arcsin('),
        ('arccos', 'arccos('),
        ('arctan', 'arctan('),
        ('arccsc', 'arccsc('),
        ('arccot', 'arccot('),
        ('π', 'pi'),
        ('e', 'e'),
        ('τ', 'tau'),
        ('φ', 'phi'),
        ('i', 'i'),
        ('∞', 'infinity'),
        ('+ C', ' + C'),
        ('±', 'SIGN'),
        ('a/b', 'a/b'),
        (',', ','),
        ('(', '('),
        (')', ')'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _CalculatorMode.statistics => [
        ('xʸ', '^'),
        ('mean(', 'mean('),
        ('median(', 'median('),
        ('mode(', 'mode('),
        ('range(', 'range('),
        ('sum(', 'sum('),
        ('count(', 'count('),
        ('variance(', 'variance('),
        ('sampleVariance(', 'sampleVariance('),
        ('stdev(', 'stdev('),
        ('sampleStdev(', 'sampleStdev('),
        ('Q₁(', 'q1('),
        ('Q₃(', 'q3('),
        ('±', 'SIGN'),
        ('a/b', 'a/b'),
        (',', ','),
        ('[', '['),
        (']', ']'),
        ('(', '('),
        (')', ')'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _CalculatorMode.probability => [
        ('xʸ', '^'),
        ('P(', 'probability('),
        ('P̄(', 'complement('),
        ('odds(', 'odds('),
        ('binomial(', 'binomial('),
        ('nCr(', 'combination('),
        ('nPr(', 'permutation('),
        ('±', 'SIGN'),
        ('a/b', 'a/b'),
        (',', ','),
        ('(', '('),
        (')', ')'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _CalculatorMode.physics => [
        ('xʸ', '^'),
        ('d = v × t', 'distance('),
        ('v = d ÷ t', 'velocity('),
        ('t = d ÷ v', 'time('),
        ('±', 'SIGN'),
        ('a/b', 'a/b'),
        (',', ','),
        ('(', '('),
        (')', ')'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _CalculatorMode.graphing => [
        ('x', 'x'),
        ('y', 'y'),
        ('z', 'z'),
        ('r', 'r'),
        ('u', 'u'),
        ('v', 'v'),
        ('=', '='),
        (';', ';'),
        ('\u03C0', 'pi'),
        ('e', 'e'),
        ('xʸ', '^'),
        ('sin', 'sin('),
        ('cos', 'cos('),
        ('tan', 'tan('),
        ('sinh', 'sinh('),
        ('cosh', 'cosh('),
        ('tanh', 'tanh('),
        ('asinh', 'asinh('),
        ('acosh', 'acosh('),
        ('atanh', 'atanh('),
        ('sqrt', 'sqrt('),
        ('\u221B', 'cbrt('),
        ('log\u2081\u2080', 'log10('),
        ('floor', 'floor('),
        ('ceil', 'ceil('),
        ('abs', 'abs('),
        ('log', 'log('),
        ('root', 'nrt('),
        (',', ','),
        ('%', 'PERCENT'),
        ('±', 'SIGN'),
        ('a/b', 'a/b'),
        ('(', '('),
        (')', ')'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _CalculatorMode.discreteMath => [
        ('xʸ', 'pow('),
        ('gcd(', 'gcd('),
        ('lcm(', 'lcm('),
        ('prime?', 'isPrime('),
        ('factors(', 'factors('),
        ('mod(', 'mod('),
        ('modPow(', 'modPow('),
        ('modInverse(', 'modInverse('),
        ('nCr(', 'nCr('),
        ('nPr(', 'nPr('),
        ('ratio(', 'ratio('),
        ('percent(', 'percent('),
        ('\u222A', 'union('),
        ('\u2229', 'intersection('),
        ('\u2216', 'difference('),
        ('\u25B3', 'symmetricDifference('),
        ('truthTable(', 'truthTable('),
        ('tautology(', 'tautology('),
        ('satisfiable(', 'satisfiable('),
        ('contradiction(', 'contradiction('),
        (',', ','),
        ('{', '{'),
        ('}', '}'),
        ('!', '!'),
        ('\u2227', '&&'),
        ('\u2228', '||'),
        ('\u2295', '^'),
        ('\u2192', '->'),
        ('\u2194', '<->'),
        ('A', 'A'),
        ('B', 'B'),
        ('C', 'VAR_C'),
        ('D', 'D'),
        ('E', 'E'),
        ('F', 'F'),
        ('G', 'G'),
        ('H', 'H'),
        ('(', '('),
        (')', ')'),
        ('±', 'SIGN'),
        ('a/b', 'a/b'),
        ('DEL', 'DEL'),
        ('Clear', 'C'),
      ],
      _CalculatorMode.geometry || _CalculatorMode.trigonometry => [
        ('xʸ', '^'),
        ('\u03C0', 'pi'),
        ('e', 'e'),
        ('sin', 'sin('),
        ('cos', 'cos('),
        ('tan', 'tan('),
        ('asin', 'arcsin('),
        ('acos', 'arccos('),
        ('atan', 'arctan('),
        ('sinh', 'sinh('),
        ('cosh', 'cosh('),
        ('tanh', 'tanh('),
        ('asinh', 'asinh('),
        ('acosh', 'acosh('),
        ('atanh', 'atanh('),
        ('sec', 'sec('),
        ('csc', 'csc('),
        ('cot', 'cot('),
        ('sqrt', 'sqrt('),
        ('\u221B', 'cbrt('),
        ('log\u2081\u2080', 'log10('),
        ('ln', 'ln('),
        ('floor', 'floor('),
        ('ceil', 'ceil('),
        ('log', 'log('),
        ('root', 'nrt('),
        (',', ','),
        ('%', 'PERCENT'),
        ('\u00D7', '*'),
        ('a/b', 'a/b'),
        ('(', '('),
        (')', ')'),
        ('±', 'SIGN'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _CalculatorMode.scientific => [
        ('\u03C0', 'pi'),
        ('e', 'e'),
        ('sin', 'sin('),
        ('cos', 'cos('),
        ('tan', 'tan('),
        ('sinh', 'sinh('),
        ('cosh', 'cosh('),
        ('tanh', 'tanh('),
        ('asinh', 'asinh('),
        ('acosh', 'acosh('),
        ('atanh', 'atanh('),
        ('sec', 'sec('),
        ('csc', 'csc('),
        ('cot', 'cot('),
        ('asin', 'arcsin('),
        ('acos', 'arccos('),
        ('atan', 'arctan('),
        ('sqrt', 'sqrt('),
        ('\u221B', 'cbrt('),
        ('log\u2081\u2080', 'log10('),
        ('ln', 'ln('),
        ('floor', 'floor('),
        ('ceil', 'ceil('),
        ('log', 'log('),
        ('root', 'nrt('),
        (',', ','),
        ('%', 'PERCENT'),
        ('x^y', '^'),
        ('e^x', 'e^('),
        ('±', 'SIGN'),
        ('!', '!'),
        ('abs', 'abs('),
        ('(', '('),
        (')', ')'),
        ('a/b', 'a/b'),
        ('C', 'C'),
        ('DEL', 'DEL'),
      ],
      _ => [
        ('π', 'pi'),
        ('e', 'e'),
        ('(', '('),
        (')', ')'),
        ('xʸ', '^'),
        ('x²', '^2'),
        ('%', 'PERCENT'),
        ('sqrt', 'sqrt('),
        ('±', 'SIGN'),
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
    if (_mode == _CalculatorMode.physics) {
      final physicsTex = switch (label) {
        'd = v × t' => r'd=v\times t',
        'v = d ÷ t' => r'v=\frac{d}{t}',
        't = d ÷ v' => r't=\frac{d}{v}',
        _ => null,
      };
      if (physicsTex != null) {
        return Math.tex(
          physicsTex,
          mathStyle: MathStyle.text,
          textStyle: const TextStyle(fontSize: 12),
        );
      }
    }
    final tex = switch (key) {
      'pi' => r'\pi',
      'sqrt(' => r'\sqrt{\square}',
      'cbrt(' => r'\sqrt[3]{\square}',
      'a/b' => r'\frac{\square}{\square}',
      'pow(' => r'\square^{\square}',
      '^' when _mode == _CalculatorMode.discreteMath => r'\oplus',
      '^' => r'\square^{\square}',
      'e^(' => r'e^x',
      'pi' || '3.141592653589793' => r'\pi',
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
      'log10(' => r'\log_{10}(\square)',
      'log(' => r'\log_{\square}(\square)',
      'nrt(' => r'\sqrt[\square]{\square}',
      'union(' => r'\cup',
      'intersection(' => r'\cap',
      'difference(' => r'\setminus',
      'symmetricDifference(' => r'\triangle',
      'sinh(' => r'\sinh(\square)',
      'cosh(' => r'\cosh(\square)',
      'tanh(' => r'\tanh(\square)',
      'asinh(' => r'\operatorname{asinh}(\square)',
      'acosh(' => r'\operatorname{acosh}(\square)',
      'atanh(' => r'\operatorname{atanh}(\square)',
      'floor(' => r'\lfloor\square\rfloor',
      'ceil(' => r'\lceil\square\rceil',
      '*' => r'\times',
      '/' => r'\div',
      'CALC_DERIVATIVE' || 'CALC_LEIBNIZ_FIRST' => r'\frac{dy}{dx}',
      'CALC_LAGRANGE_FIRST' => r"f'(x)",
      'CALC_LEIBNIZ_SECOND' => r'\frac{d^2y}{dx^2}',
      'CALC_LAGRANGE_SECOND' => r"f''(x)",
      'CALC_PARTIAL_X' => r'\frac{\partial}{\partial x}',
      'CALC_PARTIAL_Y' => r'\frac{\partial}{\partial y}',
      'CALC_PARTIAL_Z' => r'\frac{\partial}{\partial z}',
      'CALC_INTEGRAL' => r'\int \square\,dx',
      'CALC_DEFINITE_INTEGRAL' => r'\int_{a}^{b}\square\,dx',
      'CALC_DOUBLE_INTEGRAL' => r'\iint \square\,dx\,dy',
      'CALC_TRIPLE_INTEGRAL' => r'\iiint \square\,dx\,dy\,dz',
      'CALC_LIMIT_TWO' => r'\lim_{x\to a}',
      'CALC_LIMIT_LEFT' => r'\lim_{x\to a^-}',
      'CALC_LIMIT_RIGHT' => r'\lim_{x\to a^+}',
      'CALC_LIMIT_POS_INFINITY' => r'\lim_{x\to\infty}',
      'CALC_LIMIT_NEG_INFINITY' => r'\lim_{x\to-\infty}',
      'mean(' => r'\operatorname{mean}(',
      'median(' => r'\operatorname{median}(',
      'mode(' => r'\operatorname{mode}(',
      'range(' => r'\operatorname{range}(',
      'variance(' => r'\operatorname{Var}(',
      'sampleVariance(' => r's^2(',
      'stdev(' => r'\sigma(',
      'sampleStdev(' => r's(',
      'probability(' => r'P(',
      'complement(' => r'P^c(',
      'binomial(' => r'P(X=k)=',
      'combination(' => r'\binom{n}{r}',
      'permutation(' => r'nP_r',
      'velocity(' => r'v(',
      'time(' => r't(',
      'distance(' => r'\operatorname{distance}(',
      '×' => r'\times',
      '÷' => r'\div',
      '&&' => r'\land',
      '||' => r'\lor',
      '->' => r'\to',
      '<->' => r'\leftrightarrow',
      _ => null,
    };
    if (tex == null) return Text(label);
    return Math.tex(
      tex,
      mathStyle: MathStyle.text,
      textStyle: const TextStyle(fontSize: 12),
      onErrorFallback: (_) => Text(label),
    );
  }

  Widget _buildResponsiveKeypad(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final keyHeight = (screen.height * .043).clamp(27.0, 36.0).toDouble();
    final gap = screen.width < 360 ? 4.0 : 6.0;
    final numberGridHeight = keyHeight * 4 + gap * 3;
    final keypadHeight = keyHeight * 6 + gap * 5;
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
                      _calculatorKey(
                        context,
                        key,
                        () => _insert(key),
                        key: ValueKey('basic-key-$key'),
                      ),
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
                      key: ValueKey(
                        'basic-key-${value == '*'
                            ? 'multiply'
                            : value == '/'
                            ? 'divide'
                            : value}',
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                ],
                SizedBox(
                  height: keyHeight,
                  width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: _calculatorKey(
                          context,
                          'C',
                          () => _pressFunction('C'),
                          key: const ValueKey('basic-key-C'),
                        ),
                      ),
                      SizedBox(width: gap),
                      Expanded(
                        child: _calculatorKey(
                          context,
                          'DEL',
                          () => _pressFunction('DEL'),
                          key: const ValueKey('basic-key-DEL'),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: gap),
                SizedBox(
                  height: keyHeight,
                  width: double.infinity,
                  child: _calculatorKey(
                    context,
                    '=',
                    _evaluate,
                    primary: true,
                    key: const ValueKey('basic-key-equals'),
                  ),
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
    Key? key,
  }) => SizedBox.expand(
    key: key,
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
    final inputDigitKeys = List.generate(
      _sourceBase,
      (digit) => digit.toRadixString(16).toUpperCase(),
    );
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
          if (!_answerShown) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final digit in inputDigitKeys)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: SizedBox(
                        width: 40,
                        height: 38,
                        child: _calculatorKey(
                          context,
                          digit,
                          () => _insertNumberSystemKey(digit),
                        ),
                      ),
                    ),
                  for (final key in const ['\u00B1', 'DEL', 'C'])
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: SizedBox(
                        width: 44,
                        height: 38,
                        child: _calculatorKey(
                          context,
                          key,
                          () => _insertNumberSystemKey(key),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
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
              onTap: () => setState(() => _numberBSelected = false),
              onChanged: (_) => _calculateNumberSystem(),
              keyboardType: TextInputType.none,
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
                    'pow',
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
                              'pow': 'xʸ',
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
                onTap: () => setState(() => _numberBSelected = true),
                onChanged: (_) => _calculateNumberSystem(),
                keyboardType: TextInputType.none,
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

  void _insertNumberSystemKey(String key) {
    final controller = !_conversionOnly && _numberBSelected
        ? _numberB
        : _numberA;
    if (key == 'C') {
      controller.clear();
    } else if (key == 'DEL') {
      final text = controller.text;
      final selection = controller.selection;
      final start = selection.isValid ? selection.start : text.length;
      final end = selection.isValid ? selection.end : text.length;
      final from = start == end && start > 0 ? start - 1 : start;
      controller.value = TextEditingValue(
        text: text.replaceRange(from, end, ''),
        selection: TextSelection.collapsed(offset: from),
      );
    } else if (key == '\u00B1') {
      final text = controller.text;
      controller.text = text.startsWith('-') ? text.substring(1) : '-$text';
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    } else {
      final selection = controller.selection;
      final start = selection.isValid
          ? selection.start
          : controller.text.length;
      final end = selection.isValid ? selection.end : controller.text.length;
      controller.value = TextEditingValue(
        text: controller.text.replaceRange(start, end, key),
        selection: TextSelection.collapsed(offset: start + key.length),
      );
    }
    _calculateNumberSystem();
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
    if (label == 'DEL') return const Icon(Icons.backspace_outlined, size: 16);
    final tex = switch (label) {
      '\u00D7' => r'\times',
      '\u00F7' => r'\div',
      '−' => '-',
      _ => null,
    };
    if (tex == null) return Text(label);
    return Math.tex(
      tex,
      mathStyle: MathStyle.text,
      textStyle: const TextStyle(fontSize: 15),
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
        (((MediaQuery.sizeOf(context).width - 24) / 4 / 3.9) * 6 + 20)
            .clamp(145.0, 154.0)
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
            mainAxisSpacing: 3,
            crossAxisSpacing: 3,
            childAspectRatio: 3.9,
            children: [
              for (final key in [
                '7',
                '8',
                '9',
                '+',
                '4',
                '5',
                '6',
                '-',
                '1',
                '2',
                '3',
                '×',
                'a/b',
                '0',
                '.',
                '÷',
                'DEL',
                '(',
                ')',
                'x\u02B8',
                'C',
                '√',
                'π',
                '±',
              ])
                OutlinedButton(
                  key: ValueKey('geometry-key-$key'),
                  onPressed: () {
                    if (key == 'a/b') {
                      _pressFunction('a/b');
                    } else if (key == 'x\u02B8') {
                      _pressFunction('^');
                    } else {
                      _pressGeometryDigit(key);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: key == 'x\u02B8'
                      ? _functionKeyVisual('x\u02B8', '^')
                      : Text(
                          key,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
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
            tooltip: 'Undo stroke',
            onPressed: _undoDrawingStroke,
            icon: const Icon(Icons.undo_rounded),
          ),
          IconButton(
            tooltip: 'Redo stroke',
            onPressed: _redoDrawingStrokes.isEmpty ? null : _redoDrawingStroke,
            icon: const Icon(Icons.redo_rounded),
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: _clearDrawing,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
          TextButton(
            onPressed: _recognizingDrawing
                ? null
                : () {
                    setState(() {
                      _buildingSymbolExpression = false;
                      _strokeSymbolCandidates = [];
                    });
                    _recognizeDrawing();
                  },
            child: const Text('Analyze'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _drawingStatus ??
                              'Write an expression or stack numbers on the page.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                  const SizedBox(height: 5),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final tool in _DrawingTool.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: IconButton.filledTonal(
                              tooltip: switch (tool) {
                                _DrawingTool.pen => 'Pen',
                                _DrawingTool.highlighter => 'Highlighter',
                                _DrawingTool.eraser => 'Stroke eraser',
                              },
                              isSelected: _drawingTool == tool,
                              onPressed: () =>
                                  setState(() => _drawingTool = tool),
                              icon: Icon(switch (tool) {
                                _DrawingTool.pen => Icons.edit_rounded,
                                _DrawingTool.highlighter => Icons.brush_rounded,
                                _DrawingTool.eraser =>
                                  Icons.auto_fix_normal_rounded,
                              }),
                            ),
                          ),
                        const SizedBox(width: 4),
                        for (final color in const [
                          Color(0xFF17233D),
                          Color(0xFF246BFD),
                          Color(0xFFE44758),
                          Color(0xFF169B79),
                        ])
                          IconButton(
                            tooltip: 'Ink color',
                            onPressed: () =>
                                setState(() => _drawingInk = color),
                            icon: Icon(
                              Icons.circle,
                              color: color,
                              size: _drawingInk == color ? 23 : 18,
                            ),
                          ),
                        const SizedBox(width: 6),
                        const Text('Width'),
                        SizedBox(
                          width: 74,
                          child: DropdownButton<double>(
                            value: _drawingInkWidth,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: const [2.0, 3.2, 5.0, 8.0]
                                .map(
                                  (width) => DropdownMenuItem(
                                    value: width,
                                    child: Text('${width.toInt()} px'),
                                  ),
                                )
                                .toList(),
                            onChanged: (width) {
                              if (width != null) {
                                setState(() => _drawingInkWidth = width);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _readingStrokeSymbol
                              ? null
                              : _recognizeOneStrokeSymbol,
                          icon: _readingStrokeSymbol
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.gesture_rounded),
                          label: const Text('Read one symbol'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<_DrawingResultMode>(
                      segments: const [
                        ButtonSegment(
                          value: _DrawingResultMode.automatic,
                          label: Text('Automatic'),
                        ),
                        ButtonSegment(
                          value: _DrawingResultMode.suggest,
                          label: Text('Suggest'),
                        ),
                        ButtonSegment(
                          value: _DrawingResultMode.off,
                          label: Text('Off'),
                        ),
                      ],
                      selected: {_drawingResultMode},
                      onSelectionChanged: (selection) {
                        setState(() => _drawingResultMode = selection.first);
                        if (_recognizedExpression != null &&
                            selection.first == _DrawingResultMode.automatic) {
                          _solveRecognizedDrawing();
                        } else if (_recognizedExpression != null &&
                            selection.first == _DrawingResultMode.suggest) {
                          setState(() => _drawingSolveSuggested = true);
                        } else if (selection.first == _DrawingResultMode.off) {
                          setState(() {
                            _result = null;
                            _answerShown = false;
                            _drawingSolveSuggested = false;
                            _drawingStatus = 'Math results are off.';
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Listener(
                  onPointerDown: (event) {
                    _drawingPressure = event.pressure.clamp(.6, 1.5);
                  },
                  onPointerMove: (event) {
                    _drawingPressure = event.pressure.clamp(.6, 1.5);
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanDown: (details) => setState(
                      () => _beginDrawingStroke(details.localPosition),
                    ),
                    onPanUpdate: (details) => setState(
                      () => _activeStroke = [
                        ..._activeStroke,
                        details.localPosition,
                      ],
                    ),
                    onPanEnd: (_) {
                      if (_activeStroke.length > 1) {
                        final eraser = _drawingTool == _DrawingTool.eraser;
                        final color = _drawingTool == _DrawingTool.highlighter
                            ? _drawingInk.withValues(alpha: .28)
                            : _drawingInk;
                        _drawingStrokes.add(
                          _InkStroke(
                            points: List.of(_activeStroke),
                            color: color,
                            width:
                                (_drawingTool == _DrawingTool.eraser
                                    ? _drawingInkWidth * 4
                                    : _drawingInkWidth) *
                                _drawingPressure,
                            isEraser: eraser,
                          ),
                        );
                        _redoDrawingStrokes.clear();
                      }
                      setState(() => _activeStroke = []);
                      if (_drawingTool != _DrawingTool.eraser &&
                          !_buildingSymbolExpression) {
                        _scheduleDrawingRecognition();
                      }
                    },
                    child: Container(
                      key: const Key('drawing-canvas'),
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
                            if (_activeStroke.isNotEmpty)
                              _InkStroke(
                                points: _activeStroke,
                                color: _drawingInk.withValues(
                                  alpha:
                                      _drawingTool == _DrawingTool.highlighter
                                      ? .28
                                      : 1,
                                ),
                                width: _drawingInkWidth * _drawingPressure,
                                isEraser: _drawingTool == _DrawingTool.eraser,
                              ),
                          ]),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_recognizedExpression != null || _drawingStrokes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('drawing-expression-review'),
                      controller: _drawingExpressionInput,
                      keyboardType: TextInputType.none,
                      decoration: InputDecoration(
                        labelText: _recognizedExpression == null
                            ? 'Type or correct the expression'
                            : 'Recognized math, tap to correct',
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: 'Solve corrected expression',
                          onPressed:
                              _drawingResultMode == _DrawingResultMode.off
                              ? null
                              : _solveRecognizedDrawing,
                          icon: const Icon(Icons.calculate_outlined),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _recognizedExpression = value;
                          _result = null;
                          _drawingSolveSuggested =
                              _drawingResultMode == _DrawingResultMode.suggest;
                        });
                      },
                      onSubmitted: (_) => _solveRecognizedDrawing(),
                    ),
                    if (_strokeSymbolCandidates.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Single-symbol suggestions',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final candidate in _strokeSymbolCandidates)
                            ActionChip(
                              key: Key('stroke-symbol-${candidate.token}'),
                              label: Text(
                                '${candidate.display}  ${(candidate.confidence * 100).round()}%',
                              ),
                              onPressed: () => _acceptStrokeSymbol(candidate),
                            ),
                        ],
                      ),
                    ],
                    if (_result != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$_result',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _accent,
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (_drawingSolveSuggested)
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _solveRecognizedDrawing,
                              icon: const Icon(Icons.calculate_rounded),
                              label: const Text('Solve'),
                            ),
                          ),
                        if (_drawingSolveSuggested) const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _input.text = _drawingExpressionInput.text.trim();
                              _answerShown = false;
                              _mode = _CalculatorMode.scientific;
                              _showVisualization = false;
                              _exitDrawingMode(
                                destination: _CalculatorMode.scientific,
                              );
                            },
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Use in calculator'),
                          ),
                        ),
                        if (RegExp(
                          r'\b[xy]\b|[xy]\s*=|=\s*[xy]',
                          caseSensitive: false,
                        ).hasMatch(_drawingExpressionInput.text)) ...[
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            tooltip: 'Open equation in Graphing',
                            onPressed: () {
                              _input.text = _drawingExpressionInput.text.trim();
                              _mode = _CalculatorMode.graphing;
                              _showVisualization = false;
                              _exitDrawingMode(
                                destination: _CalculatorMode.graphing,
                              );
                            },
                            icon: const Icon(Icons.show_chart_rounded),
                          ),
                        ],
                      ],
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
  final List<_InkStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final stroke in strokes) {
      final points = stroke.points;
      if (points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;
      if (points.length == 1) {
        canvas.drawCircle(
          points.first,
          stroke.width / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
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
