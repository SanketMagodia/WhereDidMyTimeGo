import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/journal_entry_model.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

const double _paperLineGap = 24;
const double _paperFontSize = 16;
const double _paperLineHeight = 1.5;

const _handwritingFallback = <String>[
  'Segoe Script',
  'Lucida Handwriting',
  'Comic Sans MS',
  'cursive',
];

String _preserveLineBreaksForMarkdown(String input) {
  // Markdown ignores single newlines by default; convert each typed newline
  // into an explicit markdown line break so diary text keeps exact line flow.
  return input.replaceAll('\n', '  \n');
}

class JournalDiaryScreen extends StatefulWidget {
  final DateTime? initialDate;
  const JournalDiaryScreen({super.key, this.initialDate});

  @override
  State<JournalDiaryScreen> createState() => _JournalDiaryScreenState();
}

class _JournalDiaryScreenState extends State<JournalDiaryScreen> {
  static final DateTime _anchorDate = DateTime(2020, 1, 1);
  static const int _anchorPage = 25000;
  late DateTime _selectedDate;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(d.year, d.month, d.day);
    _pageController = PageController(initialPage: _dateToPage(_selectedDate));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final provider = Provider.of<AppProvider>(context);
    final selected = provider.getJournalForDate(_selectedDate);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'My Diary',
          style: TextStyle(color: c.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          _DiaryDayBar(
            selectedDate: _selectedDate,
            onPrev: _goPrevDay,
            onNext: _goNextDay,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Flip pages to move day by day',
                    style: TextStyle(color: c.muted, fontSize: 12),
                  ),
                ),
                if (selected != null)
                  IconButton(
                    tooltip: 'Delete entry',
                    onPressed: () => _deleteEntry(selected),
                    icon: Icon(Icons.delete_outline_rounded, color: c.muted),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _openEditor(context, _selectedDate),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(selected == null ? 'Write' : 'Edit'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _DiaryFlipBook(
                controller: _pageController,
                selectedDate: _selectedDate,
                onChanged: (date) => setState(() => _selectedDate = date),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _dateToPage(DateTime d) =>
      _anchorPage + d.difference(_anchorDate).inDays;

  void _goPrevDay() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _goNextDay() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openEditor(BuildContext context, DateTime date) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JournalEditorSheet(date: date),
    );
  }

  Future<void> _deleteEntry(JournalEntryModel entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete journal entry?'),
        content: Text(
          'This will remove your ${DateFormat('d MMM yyyy').format(entry.date)} page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await Provider.of<AppProvider>(
        context,
        listen: false,
      ).deleteJournalById(entry.id);
    }
  }
}

class _DiaryDayBar extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _DiaryDayBar({
    required this.selectedDate,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: Icon(Icons.chevron_left_rounded, color: c.text),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  DateFormat('EEEE').format(selectedDate),
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                Text(
                  DateFormat('d MMMM yyyy').format(selectedDate),
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(Icons.chevron_right_rounded, color: c.text),
          ),
        ],
      ),
    );
  }
}

class _DiaryFlipBook extends StatelessWidget {
  final PageController controller;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  const _DiaryFlipBook({
    required this.controller,
    required this.selectedDate,
    required this.onChanged,
  });

  static final DateTime _anchorDate = DateTime(2020, 1, 1);
  static const int _anchorPage = 25000;

  DateTime _pageToDate(int page) =>
      _anchorDate.add(Duration(days: page - _anchorPage));

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    return PageView.builder(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (page) => onChanged(_pageToDate(page)),
      itemBuilder: (context, index) {
        final date = _pageToDate(index);
        final entry = provider.getJournalForDate(date);
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.96, end: 1),
          duration: const Duration(milliseconds: 220),
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: entry == null
              ? _EmptyDiaryPage(date: date)
              : _DiaryPaperPreview(content: entry.content),
        );
      },
    );
  }
}

class _EmptyDiaryPage extends StatelessWidget {
  final DateTime date;
  const _EmptyDiaryPage({required this.date});

  @override
  Widget build(BuildContext context) {
    return _DiaryPaperPreview(
      content:
          'No entry for ${DateFormat('d MMM yyyy').format(date)} yet.\n\nTap "Write" to start today\'s page.',
      placeholder: true,
    );
  }
}

class _DiaryPaperPreview extends StatelessWidget {
  final String content;
  final bool placeholder;
  const _DiaryPaperPreview({required this.content, this.placeholder = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6E7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAD9B9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _LinedPaperPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(36, 18, 18, 18),
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: _preserveLineBreaksForMarkdown(content),
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: placeholder ? c.muted : const Color(0xFF5D4632),
                    fontSize: _paperFontSize,
                    height: _paperLineHeight,
                    fontFamilyFallback: _handwritingFallback,
                  ),
                  strong: const TextStyle(fontWeight: FontWeight.w800),
                  em: const TextStyle(fontStyle: FontStyle.italic),
                  h1: const TextStyle(
                    color: Color(0xFF5D4632),
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                  h2: const TextStyle(
                    color: Color(0xFF5D4632),
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                  listBullet: TextStyle(
                    color: placeholder ? c.muted : const Color(0xFF5D4632),
                    fontSize: _paperFontSize,
                    height: _paperLineHeight,
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

class _JournalEditorSheet extends StatefulWidget {
  final DateTime date;
  const _JournalEditorSheet({required this.date});

  @override
  State<_JournalEditorSheet> createState() => _JournalEditorSheetState();
}

class _JournalEditorSheetState extends State<_JournalEditorSheet> {
  late final TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final entry = Provider.of<AppProvider>(
      context,
      listen: false,
    ).getJournalForDate(widget.date);
    _ctrl = TextEditingController(text: entry?.content ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.84,
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + bottom),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: c.muted.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEEE, d MMMM yyyy').format(widget.date),
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _FormatBar(
            onBold: () => _wrapSelection('**', '**'),
            onItalic: () => _wrapSelection('_', '_'),
            onBullet: () => _prefixSelection('- '),
            onTitle: () => _prefixSelection('# '),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFDF6E7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEAD9B9)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: _LinedPaperPainter(),
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      color: Color(0xFF5D4632),
                      fontSize: _paperFontSize,
                      height: _paperLineHeight,
                      fontFamilyFallback: _handwritingFallback,
                    ),
                    strutStyle: const StrutStyle(
                      fontSize: _paperFontSize,
                      height: _paperLineHeight,
                      forceStrutHeight: true,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(36, 8, 18, 18),
                      hintText: 'Write your day here...',
                      hintStyle: TextStyle(
                        color: Color(0xFF9B8A76),
                        fontFamilyFallback: _handwritingFallback,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: c.muted)),
              ),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  await Provider.of<AppProvider>(
                    context,
                    listen: false,
                  ).upsertJournal(date: widget.date, content: _ctrl.text.trim());
                  if (mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Page'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _wrapSelection(String left, String right) {
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    if (!sel.isValid) return;
    final start = sel.start;
    final end = sel.end;
    final selected = text.substring(start, end);
    final replaced = '$left$selected$right';
    _ctrl.value = _ctrl.value.copyWith(
      text: text.replaceRange(start, end, replaced),
      selection: TextSelection.collapsed(offset: start + replaced.length),
    );
    _focus.requestFocus();
  }

  void _prefixSelection(String prefix) {
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    if (!sel.isValid) return;
    final start = sel.start;
    final end = sel.end;
    final selected = text.substring(start, end);
    final lines = selected.isEmpty ? [''] : selected.split('\n');
    final replaced = lines.map((l) => '$prefix$l').join('\n');
    _ctrl.value = _ctrl.value.copyWith(
      text: text.replaceRange(start, end, replaced),
      selection: TextSelection.collapsed(offset: start + replaced.length),
    );
    _focus.requestFocus();
  }
}

class _FormatBar extends StatelessWidget {
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onBullet;
  final VoidCallback onTitle;

  const _FormatBar({
    required this.onBold,
    required this.onItalic,
    required this.onBullet,
    required this.onTitle,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Wrap(
      spacing: 8,
      children: [
        _FmtChip(label: 'B', onTap: onBold),
        _FmtChip(label: 'I', onTap: onItalic),
        _FmtChip(label: '• List', onTap: onBullet),
        _FmtChip(label: 'Title', onTap: onTitle),
        Text(
          'Formatting shortcuts',
          style: TextStyle(color: c.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _FmtChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FmtChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ActionChip(
      onPressed: onTap,
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: c.sep),
      ),
      label: Text(label, style: TextStyle(color: c.text)),
    );
  }
}

class _LinedPaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blueLine = Paint()
      ..color = const Color(0xFFCAE0F8)
      ..strokeWidth = 1;
    final redMargin = Paint()
      ..color = const Color(0xFFE7B0B0)
      ..strokeWidth = 1;

    for (double y = _paperLineGap; y < size.height; y += _paperLineGap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), blueLine);
    }
    canvas.drawLine(
      const Offset(28, 0),
      Offset(28, size.height),
      redMargin,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
