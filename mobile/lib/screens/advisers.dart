import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../ui.dart';

/// Pang-student na wala pang adviser: maghanap, mag-apply, at tingnan ang status ng application.
class AdvisersScreen extends StatefulWidget {
  final Map<String, dynamic> status;
  final Future<void> Function() onChanged;
  const AdvisersScreen(
      {super.key, required this.status, required this.onChanged});
  @override
  State<AdvisersScreen> createState() => _AdvisersScreenState();
}

class _AdvisersScreenState extends State<AdvisersScreen> {
  final _q = TextEditingController();
  List<dynamic> _list = [];
  String _error = '';
  String? _selectedDepartment;

  Map<String, dynamic>? get _app =>
      widget.status['application'] as Map<String, dynamic>?;
  bool get _pending => _app != null && _app!['status'] == 'pending';
  bool get _canApply => Api.user?['student_group_role'] != 'member';

  String _departmentOf(Map<String, dynamic> adviser) {
    final department = adviser['department'] as String?;
    if (department != null && department.trim().isNotEmpty) return department;
    final tags = adviser['tags'] as List<dynamic>? ?? const [];
    for (final tag in tags) {
      final value = '$tag';
      if (value.toLowerCase().startsWith('department:')) {
        return value.substring(value.indexOf(':') + 1).trim();
      }
    }
    return 'Other departments';
  }

  List<String> get _departments => _list
      .map((raw) => _departmentOf(Map<String, dynamic>.from(raw as Map)))
      .toSet()
      .toList()
    ..sort();

  List<dynamic> get _visibleAdvisers => _selectedDepartment == null
      ? _list
      : _list
          .where((raw) =>
              _departmentOf(Map<String, dynamic>.from(raw as Map)) ==
              _selectedDepartment)
          .toList();

  @override
  void initState() {
    super.initState();
    if (!_pending) _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.advisers(_q.text.trim());
      if (mounted)
        setState(() {
          _list = r;
          _error = '';
          if (_q.text.trim().isNotEmpty) _selectedDepartment = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _apply(Map<String, dynamic> a) async {
    final brief = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceElevated,
        title: Text('Apply to ${a['name']}',
            style: TextStyle(color: context.textColor)),
        content: TextField(
          controller: brief,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'Briefly describe your thesis/capstone topic',
            labelStyle: TextStyle(color: context.textMuted),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child:
                  Text('Cancel', style: TextStyle(color: context.textMuted))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send')),
        ],
      ),
    );
    if (ok != true) return;
    if (brief.text.trim().length < 10) {
      if (mounted) {
        snack(context,
            'Describe your thesis or capstone topic in at least 10 characters.',
            error: true);
      }
      return;
    }
    try {
      await Api.apply(a['adviser_id'] as int, brief.text.trim());
      if (mounted) snack(context, 'Application sent.');
      await widget.onChanged();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _withdraw() async {
    try {
      await Api.withdraw(_app!['application_id'] as int);
      if (mounted) snack(context, 'Application withdrawn.');
      await widget.onChanged();
      _load();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pending) return _pendingView();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Find your adviser',
            style: context.text3xl.copyWith(
                fontWeight: DesignTokens.weightExtrabold,
                color: context.textColor)),
        Text('Search by topic, skill, or name.',
            style: context.textBase.copyWith(color: context.textMuted)),
        const SizedBox(height: 12),
        if (!_canApply)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
                'Only student group leaders can apply. Use Find a group in More to join a project.',
                style: TextStyle(color: context.textMuted)),
          ),
        Row(children: [
          Expanded(
              child: TextField(
            controller: _q,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'e.g. web development, Flutter',
              hintStyle: TextStyle(color: context.textMuted),
            ),
          )),
          const SizedBox(width: 8),
          FilledButton(onPressed: _load, child: const Text('Search')),
        ]),
        if (_app != null && _app!['status'] == 'declined')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${_app!['adviser_name']} declined your application. You can choose another adviser.',
              style: TextStyle(color: context.errorColor()),
            ),
          ),
        if (_error.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child:
                  Text(_error, style: TextStyle(color: context.errorColor()))),
        if (_q.text.trim().isEmpty && _list.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Browse by department',
              style: context.textLg.copyWith(
                  color: context.textColor, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final department in _departments)
                ChoiceChip(
                  label: Text(department),
                  selected: _selectedDepartment == department,
                  onSelected: (_) => setState(() {
                    _selectedDepartment =
                        _selectedDepartment == department ? null : department;
                  }),
                ),
            ],
          ),
        ],
        if (_visibleAdvisers.isEmpty && _error.isEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text('No advisers matched. Try a different keyword.',
                  style: TextStyle(color: context.textMuted))),
        for (final raw in _visibleAdvisers)
          _card(Map<String, dynamic>.from(raw as Map)),
      ],
    );
  }

  Widget _pendingView() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Your application',
              style: context.text3xl.copyWith(
                  fontWeight: DesignTokens.weightExtrabold,
                  color: context.textColor)),
          Text('Waiting for your adviser to reply.',
              style: context.textBase.copyWith(color: context.textMuted)),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${_app!['adviser_name']}',
                        style: context.textXl.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.textColor),
                      ),
                    ),
                    StatusPill(
                        label: 'Pending', tone: 'warning', showDot: true),
                  ],
                ),
                const SizedBox(height: 8),
                Text('${_app!['topic_brief']}',
                    style: context.textBase.copyWith(color: context.textColor)),
                const SizedBox(height: 8),
                Text(
                  'Messaging with your adviser will be available after your application is approved.',
                  style: context.textSm.copyWith(color: context.textMuted),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                      onPressed: _withdraw,
                      child: const Text('Withdraw application')),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _card(Map<String, dynamic> a) {
    final left = a['slots_left'] as int;
    final tags = (a['tags'] as List<dynamic>).cast<String>();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${a['name']}',
                style: context.textXl.copyWith(
                    fontWeight: FontWeight.w800, color: context.textColor)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (a['match'] != null)
                AppBadge(
                  label:
                      '${a['match']}% match${a['best_match'] == true ? ' · best' : ''}',
                  variant: BadgeVariant.defaultBadge,
                  customColor: Colors.white,
                  customBg: DesignTokens.brandPrimary,
                ),
              for (final t in tags)
                AppBadge(label: t, variant: BadgeVariant.secondary),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                a['avg_rating'] != null
                    ? '★ ${a['avg_rating']} (${a['rating_count']})'
                    : 'No ratings yet',
                style: context.textSm.copyWith(
                    fontWeight: FontWeight.w700, color: context.textColor),
              ),
            ),
            if ((a['certifications'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '🎓 ${a['certifications']}',
                  style: context.textSm.copyWith(color: context.textMuted),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                left == 0
                    ? 'Full: no open slots'
                    : '$left of ${a['max_capacity']} advisee slots open',
                style: context.textSm.copyWith(
                  color: left == 0 ? context.errorColor() : context.textColor,
                  fontWeight: left == 0 ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: left == 0
                    ? 'Full'
                    : _canApply
                        ? 'Apply'
                        : 'Leader accounts only',
                onPressed: left > 0 && _canApply ? () => _apply(a) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
