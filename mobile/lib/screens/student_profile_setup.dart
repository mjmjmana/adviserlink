import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../ui.dart';

bool needsStudentTitleSetup(Map<String, dynamic>? user) {
  if (user?['role'] != 'student') return false;
  final title = user?['thesis_title'];
  return title is! String || title.trim().length < 10;
}

class StudentProfileSetupScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const StudentProfileSetupScreen({super.key, required this.onComplete});

  @override
  State<StudentProfileSetupScreen> createState() =>
      _StudentProfileSetupScreenState();
}

class _StudentProfileSetupScreenState extends State<StudentProfileSetupScreen> {
  late final TextEditingController _title;
  String _error = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
        text: Api.user?['thesis_title'] as String? ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.length < 10) {
      setState(() => _error = 'Enter at least 10 characters for your title.');
      return;
    }

    final user = Api.user;
    if (user == null) {
      setState(() => _error = 'Your session expired. Please log in again.');
      return;
    }

    setState(() {
      _error = '';
      _saving = true;
    });
    try {
      await Api.updateMe(
        user['name'] as String? ?? '',
        user['contact_number'] as String? ?? '',
        thesisTitle: title,
      );
      widget.onComplete();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: BentoBackground(
          child: SafeArea(
            child: BentoContainer(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Text(
                        'Complete your student profile',
                        style: context.text2xl.copyWith(
                          color: context.textColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your thesis or capstone title before using group and adviser features. You can update it later in Settings.',
                        style: context.textBase.copyWith(
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        key: const Key('student-title'),
                        controller: _title,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Complete thesis / capstone title',
                          hintText: 'Enter your complete working title',
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => setState(() => _error = ''),
                      ),
                      const SizedBox(height: 4),
                      if (_error.isNotEmpty) ...[
                        Text(
                          _error,
                          style: TextStyle(color: context.errorColor()),
                        ),
                        const SizedBox(height: 12),
                      ],
                      PrimaryButton(
                        label: _saving ? 'Saving profile…' : 'Save title and continue',
                        loading: _saving,
                        onPressed: !_saving && _title.text.trim().length >= 10
                            ? _save
                            : null,
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
