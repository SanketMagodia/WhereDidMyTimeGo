import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../theme/app_theme.dart';
import 'focus_view_screen.dart';
import 'daily_trail_screen.dart';
import 'todos_screen.dart';
import 'expenses_screen.dart';
import 'settings_screen.dart';
import 'voice_assistant_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  StreamSubscription<Uri?>? _widgetClickSub;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _deepLinkTabs = {
    'schedule': 1,
    'calendar': 1,
    'todos': 2,
    'expenses': 3,
  };

  static const _screens = <Widget>[
    FocusViewScreen(),
    DailyTrailScreen(),
    TodosScreen(),
    ExpensesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _handleInitialWidgetLink();
    _widgetClickSub = HomeWidget.widgetClicked.listen(_onWidgetLink);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _widgetClickSub?.cancel();
    super.dispose();
  }

  Future<void> _handleInitialWidgetLink() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (uri != null) _onWidgetLink(uri);
  }

  void _onWidgetLink(Uri? uri) {
    if (uri == null) return;
    final idx = _deepLinkTabs[uri.host];
    if (idx == null || !mounted) return;
    void apply() {
      if (!mounted) return;
      _goTo(idx);
    }

    if (_pageController.hasClients) {
      apply();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    }
  }

  void _goTo(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _openVoice(VoiceIntent intent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => VoiceAssistantSheet(fixedIntent: intent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      // Disable edge-drag to avoid conflict with PageView horizontal swipe.
      drawerEnableOpenDragGesture: false,
      drawer: const _SettingsSidebar(),
      floatingActionButton: _RadialMicButton(onSelect: _openVoice),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentIndex = i),
            children: _screens
                .map((s) => _KeepAlivePage(child: s))
                .toList(growable: false),
          ),
          // ── 3-dot drawer handle — top-left, alongside the header ─────
          Positioned(
            left: 0,
            top: MediaQuery.of(context).padding.top + 14,
            child: _DrawerHandle(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _NavBar(currentIndex: _currentIndex, onTap: _goTo),
    );
  }
}

// ── Bottom navigation bar with centre notch ───────────────────────────────────
class _NavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const _NavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: kBottomNavigationBarHeight,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
              c: c,
            ),
            _NavItem(
              icon: Icons.calendar_today_rounded,
              label: 'Schedule',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
              c: c,
            ),
            // Centre gap for the docked FAB (FAB=56dp + 2×notchMargin=16dp)
            const SizedBox(width: 72),
            _NavItem(
              icon: Icons.checklist_rounded,
              label: 'Checklists',
              selected: currentIndex == 2,
              onTap: () => onTap(2),
              c: c,
            ),
            _NavItem(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Finance',
              selected: currentIndex == 3,
              onTap: () => onTap(3),
              c: c,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColors c;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? c.primary : c.muted, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: selected ? c.primary : c.muted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Keep-alive wrapper ────────────────────────────────────────────────────────
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ── Settings sidebar drawer ───────────────────────────────────────────────────
class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Drawer(
      backgroundColor: c.bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.primary.withAlpha(22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: c.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: c.text,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: c.sep, height: 1),
            const Expanded(child: SettingsBody()),
          ],
        ),
      ),
    );
  }
}

// ── 3-dot handle on the left screen edge ─────────────────────────────────────
class _DrawerHandle extends StatelessWidget {
  final VoidCallback onTap;
  const _DrawerHandle({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 18,
        height: 64,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(36),
              blurRadius: 8,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(c),
            const SizedBox(height: 5),
            _dot(c),
            const SizedBox(height: 5),
            _dot(c),
          ],
        ),
      ),
    );
  }

  Widget _dot(AppColors c) => Container(
    width: 4,
    height: 4,
    decoration: BoxDecoration(color: c.muted, shape: BoxShape.circle),
  );
}

// ── Radial mic button ─────────────────────────────────────────────────────────
//
// Touch-and-hold → 3 intent dots arc upward.
// Drag finger to an option to highlight it.
// Release → opens VoiceAssistantSheet for that intent.
// Simple tap → same radial menu opens (auto-closes after 3 s if idle).
// ─────────────────────────────────────────────────────────────────────────────
class _RadialMicButton extends StatefulWidget {
  final void Function(VoiceIntent) onSelect;
  const _RadialMicButton({required this.onSelect});

  @override
  State<_RadialMicButton> createState() => _RadialMicButtonState();
}

class _RadialMicButtonState extends State<_RadialMicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  OverlayEntry? _overlay;
  int? _hovered;
  Timer? _autoCloseTimer;

  // Option data
  static const _opts = [
    (
      label: 'Log',
      icon: Icons.edit_note_rounded,
      color: Color(0xFFFFB74D),
      intent: VoiceIntent.log,
    ),
    (
      label: 'Schedule',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFFF7043),
      intent: VoiceIntent.schedule,
    ),
    (
      label: 'Expense',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF50E3A4),
      intent: VoiceIntent.expense,
    ),
  ];

  // Angles in degrees: left, top, right
  static const _angles = [150.0, 90.0, 30.0];
  static const _radius = 88.0;

  Offset _micGlobal = Offset.zero;

  List<Offset> get _arcOffsets => _angles.map((deg) {
    final rad = deg * math.pi / 180;
    return Offset(math.cos(rad) * _radius, -math.sin(rad) * _radius);
  }).toList();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _removeOverlay();
    _anim.dispose();
    super.dispose();
  }

  Offset _findMicCenter() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
  }

  void _openMenu() {
    _autoCloseTimer?.cancel();
    _micGlobal = _findMicCenter();
    _hovered = null;
    _anim.forward(from: 0);
    _overlay = OverlayEntry(builder: (_) => _overlayWidget());
    Overlay.of(context).insert(_overlay!);
    HapticFeedback.mediumImpact();

    // Auto-close after 4 s if no option selected
    _autoCloseTimer = Timer(const Duration(seconds: 4), () {
      if (_hovered == null) _closeMenu(selected: null);
    });
  }

  void _closeMenu({required int? selected}) {
    _autoCloseTimer?.cancel();
    _anim.reverse().then((_) {
      _removeOverlay();
      if (selected != null && mounted) {
        widget.onSelect(_opts[selected].intent);
      }
    });
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _updateHover(Offset globalPos) {
    final delta = globalPos - _micGlobal;
    int? next;
    double minDist = double.infinity;
    final offsets = _arcOffsets;
    for (int i = 0; i < offsets.length; i++) {
      final dist = (delta - offsets[i]).distance;
      if (dist < 65 && dist < minDist) {
        minDist = dist;
        next = i;
      }
    }
    if (next != _hovered) {
      _hovered = next;
      _overlay?.markNeedsBuild();
      if (next != null) HapticFeedback.selectionClick();
    }
  }

  Widget _overlayWidget() {
    return AnimatedBuilder(
      animation: _anim,
      builder: (ctx, _) {
        final t = _anim.value;
        final offsets = _arcOffsets;
        return Stack(
          children: [
            // Dim backdrop
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _closeMenu(selected: null),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.28 * t),
                ),
              ),
            ),

            // Glowing mic at center
            Positioned(
              left: _micGlobal.dx - 28,
              top: _micGlobal.dy - 28,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF62A07D), Color(0xFF3E7054)],
                    center: Alignment(-0.3, -0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF3E7054,
                      ).withValues(alpha: 0.65 * t),
                      blurRadius: 22,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),

            // Three option dots
            for (int i = 0; i < _opts.length; i++) ...[
              Builder(
                builder: (_) {
                  final opt = _opts[i];
                  final arc = offsets[i];
                  final isHov = _hovered == i;
                  final pos = _micGlobal + arc * t;
                  final size = isHov ? 58.0 : 48.0;
                  return Positioned(
                    left: pos.dx - size / 2,
                    top: pos.dy - size / 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: opt.color,
                            boxShadow: isHov
                                ? [
                                    BoxShadow(
                                      color: opt.color.withValues(alpha: 0.55),
                                      blurRadius: 16,
                                      spreadRadius: 3,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            opt.icon,
                            color: Colors.white,
                            size: isHov ? 28 : 22,
                          ),
                        ),
                        if (t > 0.75) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: opt.color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              opt.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openMenu,
      onLongPressStart: (_) => _openMenu(),
      onLongPressMoveUpdate: (d) => _updateHover(d.globalPosition),
      onLongPressEnd: (_) => _closeMenu(selected: _hovered),
      onLongPressCancel: () => _closeMenu(selected: null),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFF62A07D), Color(0xFF3E7054)],
            center: Alignment(-0.3, -0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3E7054).withValues(alpha: 0.5),
              blurRadius: 14,
              spreadRadius: 2,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}
