import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/expense_model.dart';
import '../models/log_entry_model.dart';
import '../models/task_model.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

// ── Public intent enum (used by the radial mic menu) ─────────────────────────
enum VoiceIntent { schedule, log, expense }

// ── Internal phase enum ───────────────────────────────────────────────────────
enum _Phase { initialising, listening, processing, result, error }

class _Parsed {
  final VoiceIntent intent;
  final String? scheduleTitle;
  final DateTime? scheduleStart;
  final DateTime? scheduleEnd;
  final String? logActivity;
  final double? expenseAmount;
  final String? expenseTitle;

  const _Parsed({
    required this.intent,
    this.scheduleTitle,
    this.scheduleStart,
    this.scheduleEnd,
    this.logActivity,
    this.expenseAmount,
    this.expenseTitle,
  });
}

// ── Sheet ─────────────────────────────────────────────────────────────────────
class VoiceAssistantSheet extends StatefulWidget {
  /// When set, skips intent detection and uses a focused prompt.
  final VoiceIntent fixedIntent;

  const VoiceAssistantSheet({super.key, required this.fixedIntent});

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ringCtrl;
  final SpeechToText _speech = SpeechToText();
  bool _processingLock = false;

  _Phase _phase = _Phase.initialising;
  String _transcript = '';
  _Parsed? _parsed;
  String _errorMsg = '';
  bool _showConfirmed = false;

  static const _voiceColor = Color(0xFF3E7054);

  // Intent-specific accent colours
  Color get _accentColor => switch (widget.fixedIntent) {
    VoiceIntent.schedule => AppTheme.accentPrimary,
    VoiceIntent.log      => AppTheme.accentGold,
    VoiceIntent.expense  => const Color(0xFF50E3A4),
  };

  IconData get _accentIcon => switch (widget.fixedIntent) {
    VoiceIntent.schedule => Icons.calendar_today_rounded,
    VoiceIntent.log      => Icons.edit_note_rounded,
    VoiceIntent.expense  => Icons.account_balance_wallet_rounded,
  };

  String get _modeLabel => switch (widget.fixedIntent) {
    VoiceIntent.schedule => 'SCHEDULE',
    VoiceIntent.log      => 'LOG NOW',
    VoiceIntent.expense  => 'EXPENSE',
  };

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initSpeech());
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  // ── Speech ──────────────────────────────────────────────────────────────────

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.error;
          _errorMsg = 'Mic error: ${e.errorMsg}';
        });
      },
    );
    if (!mounted) return;
    if (ok) {
      _startListening();
    } else {
      setState(() {
        _phase = _Phase.error;
        _errorMsg = 'Speech recognition unavailable on this device.';
      });
    }
  }

  void _startListening() {
    _processingLock = false;
    if (!mounted) return;
    setState(() {
      _transcript = '';
      _parsed = null;
      _phase = _Phase.listening;
    });
    _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _transcript = r.recognizedWords);
      },
      // Keep capture open; user explicitly decides when to stop and process.
      pauseFor: const Duration(minutes: 5),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: false,
      ),
    );
  }

  Future<void> _tapDone() async {
    if (_phase != _Phase.listening) return;
    await _speech.stop();
    if (!mounted) return;
    if (_transcript.isNotEmpty && !_processingLock) {
      _runGemma();
    } else {
      setState(() {
        _phase = _Phase.error;
        _errorMsg = 'No speech captured yet. Speak, then tap Stop & Process.';
      });
    }
  }

  // ── Gemma ───────────────────────────────────────────────────────────────────

  static const _parseAttempts = 3;

  String _llmResponseText(dynamic response) {
    if (response is TextResponse) return response.token.trim();
    return response.toString().trim();
  }

  /// Prefer outermost `{ ... }` — the old non-greedy regex often truncated JSON.
  String? _extractJsonObject(String raw) {
    var s = raw
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return s.substring(start, end + 1);
  }

  String _voicePromptForAttempt(
    String dateStr,
    String timeStr,
    int attempt,
  ) {
    final strict = attempt > 1
        ? '\n\nCRITICAL: Output exactly one JSON object only. '
            'No markdown fences, no text before or after the `{`.'
        : '';
    return switch (widget.fixedIntent) {
      VoiceIntent.schedule =>
        'Extract schedule info from the voice command.\n'
        'Today: $dateStr  Current time: $timeStr\n'
        'Return ONLY valid JSON (single line or compact is fine): '
        '{"title":"...","date":"YYYY-MM-DD","time":"HH:mm","duration_minutes":30}\n'
        'Resolve relative days (today/tomorrow). Default 30 min if not mentioned.\n'
        'Voice transcript: "$_transcript"$strict',

      VoiceIntent.log =>
        'Extract the activity name from the voice command.\n'
        'Return ONLY valid JSON: {"activity":"..."}\n'
        'Voice transcript: "$_transcript"$strict',

      VoiceIntent.expense =>
        'Extract expense details from the voice command.\n'
        'Return ONLY valid JSON: {"amount":0.0,"title":"..."} — amount is a number.\n'
        'Voice transcript: "$_transcript"$strict',
    };
  }

  _Parsed _parsedFromJsonMap(Map<String, dynamic> d, String dateStr, DateTime now) {
    switch (widget.fixedIntent) {
      case VoiceIntent.schedule:
        final title = (d['title'] ?? _transcript).toString().trim();
        final rawDate = (d['date'] ?? dateStr).toString();
        final rawTime = (d['time'] ?? '09:00').toString();
        final dur = (d['duration_minutes'] is num
                ? (d['duration_minutes'] as num).toInt()
                : 30)
            .clamp(5, 480);
        final day = DateTime.tryParse(rawDate) ?? now;
        final parts = rawTime.split(':');
        final h = int.tryParse(parts.first) ?? 9;
        final min = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
        final start = DateTime(day.year, day.month, day.day, h, min);
        return _Parsed(
          intent: VoiceIntent.schedule,
          scheduleTitle: title,
          scheduleStart: start,
          scheduleEnd: start.add(Duration(minutes: dur)),
        );

      case VoiceIntent.log:
        return _Parsed(
          intent: VoiceIntent.log,
          logActivity: (d['activity'] ?? _transcript).toString().trim(),
        );

      case VoiceIntent.expense:
        return _Parsed(
          intent: VoiceIntent.expense,
          expenseAmount: d['amount'] is num
              ? (d['amount'] as num).toDouble()
              : double.tryParse('${d['amount']}') ?? 0.0,
          expenseTitle: (d['title'] ?? _transcript).toString().trim(),
        );
    }
  }

  bool _voiceParsedIsUsable(_Parsed p) {
    switch (p.intent) {
      case VoiceIntent.schedule:
        if (p.scheduleTitle == null || p.scheduleTitle!.isEmpty) return false;
        if (p.scheduleStart == null || p.scheduleEnd == null) return false;
        return !p.scheduleEnd!.isBefore(p.scheduleStart!);
      case VoiceIntent.log:
        return p.logActivity != null && p.logActivity!.trim().isNotEmpty;
      case VoiceIntent.expense:
        return p.expenseTitle != null && p.expenseTitle!.trim().isNotEmpty;
    }
  }

  Future<void> _runGemma() async {
    if (_processingLock) return;
    _processingLock = true;
    await _speech.stop();
    if (!mounted) {
      _processingLock = false;
      return;
    }
    setState(() => _phase = _Phase.processing);

    final provider = Provider.of<AppProvider>(context, listen: false);
    if (!provider.isAiReady) {
      if (!mounted) {
        _processingLock = false;
        return;
      }
      setState(() {
        _phase = _Phase.error;
        _errorMsg = 'Import an AI model in Settings first.';
      });
      _processingLock = false;
      return;
    }

    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm').format(now);

    try {
      var ok = false;
      for (var attempt = 1; attempt <= _parseAttempts; attempt++) {
        if (!mounted) break;
        try {
          final prompt = _voicePromptForAttempt(dateStr, timeStr, attempt);
          final model = await FlutterGemma.getActiveModel(
            maxTokens: attempt == 1 ? 256 : 384,
          );
          final chat = await model.createChat();
          await chat.addQuery(Message(text: prompt, isUser: true));
          final response = await chat.generateChatResponse();
          if (!mounted) break;

          final raw = _llmResponseText(response);
          if (raw.isEmpty) throw Exception('empty response');

          final jsonStr = _extractJsonObject(raw);
          if (jsonStr == null || jsonStr.isEmpty) {
            throw Exception('no JSON object');
          }

          final decoded = jsonDecode(jsonStr);
          if (decoded is! Map) {
            throw Exception('JSON not an object');
          }
          final d = Map<String, dynamic>.from(decoded);

          final result = _parsedFromJsonMap(d, dateStr, now);
          if (!_voiceParsedIsUsable(result)) {
            throw Exception('parsed fields unusable');
          }

          setState(() {
            _parsed = result;
            _phase = _Phase.result;
          });
          ok = true;
          break;
        } catch (_) {
          if (attempt < _parseAttempts) {
            await Future<void>.delayed(const Duration(milliseconds: 400));
          }
        }
      }

      if (!ok && mounted) {
        setState(() {
          _phase = _Phase.error;
          _errorMsg = 'Could not parse. Please try again.';
        });
      }
    } finally {
      _processingLock = false;
    }
  }

  // ── Confirm ─────────────────────────────────────────────────────────────────

  Future<void> _confirm() async {
    final p = _parsed!;
    final provider = Provider.of<AppProvider>(context, listen: false);
    final now = DateTime.now();

    switch (p.intent) {
      case VoiceIntent.schedule:
        await provider.addTask(TaskModel(
          id: now.millisecondsSinceEpoch.toString(),
          title: p.scheduleTitle!,
          startTime: p.scheduleStart!,
          endTime: p.scheduleEnd!,
        ));
      case VoiceIntent.log:
        await provider.addLog(LogEntry(
          id: now.millisecondsSinceEpoch.toString(),
          timestamp: now,
          text: p.logActivity!,
        ));
      case VoiceIntent.expense:
        await provider.addExpense(ExpenseModel(
          title: p.expenseTitle!,
          amount: p.expenseAmount!,
          timestamp: now,
          category: 'Other',
        ));
    }

    if (!mounted) return;
    setState(() => _showConfirmed = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _showConfirmed = false);
    _startListening();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.76,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: _accentColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Title bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentColor.withValues(alpha: 0.12),
                  ),
                  child: Icon(_accentIcon, color: _accentColor, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  _modeLabel,
                  style: TextStyle(
                    color: _accentColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                // Phase indicator
                if (_phase != _Phase.error)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _voiceColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _phaseLabel,
                      style: const TextStyle(
                        color: _voiceColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: c.muted, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: _showConfirmed
                  ? _buildDone(c, key: const ValueKey('done'))
                  : _buildPhase(c),
            ),
          ),
        ],
      ),
    );
  }

  String get _phaseLabel => switch (_phase) {
    _Phase.initialising => '● STARTING',
    _Phase.listening    => '● LISTENING',
    _Phase.processing   => '◎ THINKING',
    _Phase.result       => '✓ READY',
    _Phase.error        => '✕ ERROR',
  };

  Widget _buildPhase(AppColors c) => switch (_phase) {
    _Phase.initialising ||
    _Phase.listening => _buildListening(c, key: ValueKey(_phase)),
    _Phase.processing => _buildProcessing(c, key: const ValueKey('proc')),
    _Phase.result => _buildResult(c, key: const ValueKey('result')),
    _Phase.error => _buildError(c, key: const ValueKey('err')),
  };

  // ── Listening UI ────────────────────────────────────────────────────────────
  Widget _buildListening(AppColors c, {required Key key}) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    child: Column(
      children: [
        const Spacer(),
        // Animated rings + mic button
        _RingMic(
          ctrl: _ringCtrl,
          color: _accentColor,
          active: _phase == _Phase.listening,
          onTap: _tapDone,
        ),
        const SizedBox(height: 28),
        // Transcript
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _transcript.isEmpty
              ? Text(
                  _phase == _Phase.initialising
                      ? 'Starting microphone…'
                      : 'Speak now…',
                  key: const ValueKey('hint'),
                  style: TextStyle(
                    color: c.muted,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Container(
                  key: const ValueKey('tx'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    '"$_transcript"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
        ),
        const Spacer(),
        // Tip chips
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: _tips.map((t) => _Chip(c: c, text: t)).toList(),
        ),
        const SizedBox(height: 14),
        // Done button
        AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 250),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _tapDone,
              icon: const Icon(Icons.stop_rounded, size: 18),
              label: const Text('Stop & Process'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );

  List<String> get _tips => switch (widget.fixedIntent) {
    VoiceIntent.schedule => ['"Meeting at 9am"', '"Gym tomorrow 6am"', '"Call at 3pm for 1hr"'],
    VoiceIntent.log      => ['"I am coding"', '"Taking a break"', '"In a meeting"'],
    VoiceIntent.expense  => ['"200 on food"', '"Paid 500 for cab"', '"Bought coffee for 80"'],
  };

  // ── Processing UI ───────────────────────────────────────────────────────────
  Widget _buildProcessing(AppColors c, {required Key key}) => Center(
    key: key,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          margin: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: c.surfaceMid,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '"$_transcript"',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.text,
              fontSize: 15,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 36),
        AnimatedBuilder(
          animation: _ringCtrl,
          builder: (ctx, child) => Transform.rotate(
            angle: _ringCtrl.value * math.pi * 2,
            child: child,
          ),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  _accentColor.withValues(alpha: 0),
                  _accentColor,
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surface,
                ),
                child:
                    Icon(Icons.auto_awesome_rounded, size: 20, color: _accentColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Gemma is thinking…',
          style: TextStyle(
            color: _accentColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  // ── Result UI ───────────────────────────────────────────────────────────────
  Widget _buildResult(AppColors c, {required Key key}) {
    final p = _parsed!;
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: c.surfaceMid,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '"$_transcript"',
              style: TextStyle(
                color: c.muted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ResultCard(parsed: p, c: c),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(
                switch (p.intent) {
                  VoiceIntent.schedule => 'Schedule it',
                  VoiceIntent.log      => 'Log it now',
                  VoiceIntent.expense  => 'Add expense',
                },
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _startListening,
              icon: const Icon(Icons.mic_rounded, size: 17),
              label: const Text('Speak again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.muted,
                side: BorderSide(color: c.sep),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Error UI ─────────────────────────────────────────────────────────────────
  Widget _buildError(AppColors c, {required Key key}) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.mic_off_rounded, size: 52, color: c.muted),
        const SizedBox(height: 14),
        Text(
          _errorMsg,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            setState(() => _phase = _Phase.initialising);
            _initSpeech();
          },
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('Try again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _voiceColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    ),
  );

  // ── Done flash ───────────────────────────────────────────────────────────────
  Widget _buildDone(AppColors c, {required Key key}) => Center(
    key: key,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _accentColor,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 14),
        Text(
          'Done!',
          style: TextStyle(
            color: c.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text('Listening again…', style: TextStyle(color: c.muted, fontSize: 13)),
      ],
    ),
  );
}

// ── Animated ring + mic button ────────────────────────────────────────────────
class _RingMic extends StatelessWidget {
  final AnimationController ctrl;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _RingMic({
    required this.ctrl,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (ctx, child) {
        const base = 80.0;
        const maxExtra = 90.0;
        const rings = 3;
        return SizedBox(
          width: base + maxExtra,
          height: base + maxExtra,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Three staggered expanding rings
              for (int i = 0; i < rings; i++) ...[
                Builder(builder: (_) {
                  final phase = (ctrl.value + i / rings) % 1.0;
                  final size = base + phase * maxExtra;
                  final opacity = active
                      ? ((1.0 - phase) * 0.45).clamp(0.0, 1.0)
                      : 0.0;
                  final ringColor = i == 0
                      ? color
                      : i == 1
                          ? Color.lerp(color, Colors.white, 0.4)!
                          : Color.lerp(color, const Color(0xFF50E3A4), 0.5)!;
                  return Opacity(
                    opacity: opacity,
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ringColor, width: 1.5),
                      ),
                    ),
                  );
                }),
              ],

              // Tap target
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: base,
                  height: base,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.lerp(color, Colors.white, 0.3)!,
                        color,
                      ],
                      center: const Alignment(-0.3, -0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final _Parsed parsed;
  final AppColors c;
  const _ResultCard({required this.parsed, required this.c});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color, body) = _content();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 6),
                body,
              ],
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color, Widget) _content() {
    switch (parsed.intent) {
      case VoiceIntent.schedule:
        final fmt = DateFormat('EEE, d MMM · HH:mm');
        final dur =
            parsed.scheduleEnd!.difference(parsed.scheduleStart!).inMinutes;
        return (
          Icons.calendar_today_rounded,
          'SCHEDULE',
          AppTheme.accentPrimary,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(parsed.scheduleTitle!,
                style: TextStyle(
                    color: c.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('${fmt.format(parsed.scheduleStart!)}  ·  ${dur}min',
                style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
        );

      case VoiceIntent.log:
        return (
          Icons.edit_note_rounded,
          'LOG NOW',
          AppTheme.accentGold,
          Text(parsed.logActivity!,
              style: TextStyle(
                  color: c.text, fontSize: 15, fontWeight: FontWeight.w700)),
        );

      case VoiceIntent.expense:
        final fmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
        return (
          Icons.account_balance_wallet_rounded,
          'EXPENSE',
          const Color(0xFF50E3A4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt.format(parsed.expenseAmount),
                style: TextStyle(
                    color: c.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(parsed.expenseTitle!,
                  style: TextStyle(color: c.muted, fontSize: 13)),
            ),
          ]),
        );
    }
  }
}

// ── Tip chip ──────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final AppColors c;
  final String text;
  const _Chip({required this.c, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: c.surfaceMid,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: TextStyle(color: c.muted, fontSize: 11)),
  );
}
