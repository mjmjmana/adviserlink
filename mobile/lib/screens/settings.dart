import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../audio.dart';
import '../api.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../ui.dart';
import '../util.dart';
import 'auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _thesisTitle;
  late final TextEditingController _researchInterests;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  AppThemeMode _themeMode = AppThemeMode.system;
  bool _soundEnabled = AppAudio.enabled;
  bool _photoBusy = false;
  bool _passwordBusy = false;

  bool get _isStudent => Api.user?['role'] == 'student';

  String get _accountTypeLabel {
    final role = Api.user?['role'] as String?;
    if (role == 'student') {
      final groupRole = Api.user?['student_group_role'] as String?;
      if (groupRole == 'leader') return 'Student · Group Leader';
      if (groupRole == 'member') return 'Student · Group Member';
      return 'Student';
    }
    if (role == 'adviser') return 'Adviser';
    if (role == 'admin') return 'Admin';
    return 'Unknown role';
  }

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: Api.user?['name'] as String? ?? '');
    _contact = TextEditingController(
        text: Api.user?['contact_number'] as String? ?? '');
    _thesisTitle =
        TextEditingController(text: Api.user?['thesis_title'] as String? ?? '');
    _researchInterests = TextEditingController(
        text: Api.user?['research_interests'] as String? ?? '');
    _loadThemeMode();
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _thesisTitle.dispose();
    _researchInterests.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _loadThemeMode() async {
    final mode = await loadThemeMode();
    if (mounted) setState(() => _themeMode = mode);
  }

  Future<void> _save() async {
    if (_isStudent && _thesisTitle.text.trim().length < 10) {
      snack(context,
          'Enter at least 10 characters for your thesis or capstone title.',
          error: true);
      return;
    }
    try {
      await Api.updateMe(
        _name.text.trim(),
        _contact.text.trim(),
        thesisTitle: _isStudent ? _thesisTitle.text.trim() : null,
        researchInterests: _isStudent ? _researchInterests.text.trim() : null,
      );
      if (mounted) snack(context, 'Account saved.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _changePhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        snack(context, 'Profile photos must be 2 MB or smaller.', error: true);
        return;
      }
      final mimeType = imageMimeType(bytes);
      if (mimeType == null) {
        snack(context, 'Choose a PNG, JPEG, or WebP image.', error: true);
        return;
      }
      setState(() => _photoBusy = true);
      await Api.updatePhoto('data:$mimeType;base64,${base64Encode(bytes)}');
      if (mounted) snack(context, 'Profile photo updated.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _photoBusy = true);
    try {
      await Api.deletePhoto();
      if (mounted) snack(context, 'Profile photo removed.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _changePassword() async {
    if (_newPassword.text.length < 8) {
      snack(context, 'Your new password needs at least 8 characters.',
          error: true);
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      snack(context, 'The two new passwords do not match.', error: true);
      return;
    }
    setState(() => _passwordBusy = true);
    try {
      await Api.changePassword(
        _currentPassword.text,
        _newPassword.text,
        _confirmPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      if (mounted) snack(context, 'Password changed.');
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _passwordBusy = false);
    }
  }

  Future<void> _changeTheme(AppThemeMode mode) async {
    setState(() => _themeMode = mode);
    await saveThemeMode(mode);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.setMode(mode);
  }

  Future<void> _changeSound(bool enabled) async {
    try {
      await AppAudio.setEnabled(enabled);
      if (!mounted) return;
      setState(() => _soundEnabled = enabled);
      if (enabled) await _testSound();
    } catch (e) {
      if (mounted) snack(context, e.toString(), error: true);
    }
  }

  Future<void> _testSound() async {
    try {
      await AppAudio.playNotification();
      if (mounted) snack(context, 'Test sound played.');
    } catch (e) {
      if (mounted) snack(context, 'Could not play sound: $e', error: true);
    }
  }

  Future<void> _logout() async {
    await Api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LandingScreen()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final photo = Api.user?['profile_photo'] as String?;
    final photoUrl = photo == null || photo.isEmpty
        ? null
        : photo.startsWith('http')
            ? photo
            : '${Api.baseUrl}${photo.startsWith('/') ? '' : '/'}$photo';
    return ListView(
      padding: EdgeInsets.all(DesignTokens.space4),
      children: [
        Text('Your settings',
            style: context.text3xl.copyWith(
                fontWeight: DesignTokens.weightExtrabold,
                color: context.textColor)),
        Text('View or edit your account.',
            style: context.textBase.copyWith(color: context.textMuted)),
        SizedBox(height: DesignTokens.space4),
        GlassCard(
          padding: EdgeInsets.all(DesignTokens.space6),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Account',
                style: context.textXl.copyWith(
                    fontWeight: DesignTokens.weightBold,
                    color: context.textColor)),
            SizedBox(height: DesignTokens.space4),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: context.brandPrimary.withValues(alpha: 0.15),
                  backgroundImage:
                      photoUrl == null ? null : NetworkImage(photoUrl),
                  child: photoUrl == null
                      ? Icon(Icons.person_outline,
                          color: context.brandPrimary, size: 30)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _photoBusy ? null : _changePhoto,
                        icon: Icon(_photoBusy
                            ? Icons.hourglass_top
                            : Icons.add_a_photo_outlined),
                        label: Text(
                            photoUrl == null ? 'Add photo' : 'Change photo'),
                      ),
                      if (photoUrl != null)
                        TextButton(
                          onPressed: _photoBusy ? null : _removePhoto,
                          child: const Text('Remove'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: DesignTokens.space4),
            AppInput(
              controller: _name,
              label: 'Full name',
              prefixIcon: Icons.person_outline,
            ),
            SizedBox(height: DesignTokens.space3),
            AppInput(
              controller: TextEditingController(
                  text: Api.user?['email'] as String? ?? ''),
              label: 'Email',
              enabled: false,
              prefixIcon: Icons.email_outlined,
            ),
            SizedBox(height: DesignTokens.space3),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Account type',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              child: Text(
                _accountTypeLabel,
                style: TextStyle(color: context.textColor),
              ),
            ),
            SizedBox(height: DesignTokens.space3),
            AppInput(
              controller: _contact,
              label: 'Contact number',
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
            ),
            if (_isStudent) ...[
              SizedBox(height: DesignTokens.space3),
              TextField(
                controller: _thesisTitle,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Complete thesis / capstone title',
                  alignLabelWithHint: true,
                ),
              ),
              TextField(
                controller: _researchInterests,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Research interests (optional)',
                  hintText: 'e.g. sustainable agriculture, machine learning',
                ),
              ),
            ],
            SizedBox(height: DesignTokens.space4),
            PrimaryButton(label: 'Save account', onPressed: _save),
          ]),
        ),
        SizedBox(height: DesignTokens.space3),
        GlassCard(
          padding: EdgeInsets.all(DesignTokens.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change password',
                  style: context.textXl.copyWith(
                      fontWeight: DesignTokens.weightBold,
                      color: context.textColor)),
              Text('Use at least 8 characters.',
                  style: context.textSm.copyWith(color: context.textMuted)),
              SizedBox(height: DesignTokens.space3),
              TextField(
                controller: _currentPassword,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration:
                    const InputDecoration(labelText: 'Current password'),
              ),
              SizedBox(height: DesignTokens.space3),
              TextField(
                controller: _newPassword,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(labelText: 'New password'),
              ),
              SizedBox(height: DesignTokens.space3),
              TextField(
                controller: _confirmPassword,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration:
                    const InputDecoration(labelText: 'Confirm new password'),
              ),
              SizedBox(height: DesignTokens.space3),
              PrimaryButton(
                label: _passwordBusy ? 'Saving…' : 'Update password',
                onPressed: _passwordBusy ? null : _changePassword,
              ),
            ],
          ),
        ),
        SizedBox(height: DesignTokens.space3),
        GlassCard(
          padding: EdgeInsets.all(DesignTokens.space6),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Theme',
                style: context.textXl.copyWith(
                    fontWeight: DesignTokens.weightBold,
                    color: context.textColor)),
            SizedBox(height: DesignTokens.space3),
            SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                    value: AppThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode)),
                ButtonSegment(
                    value: AppThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode)),
                ButtonSegment(
                    value: AppThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.settings_system_daydream)),
              ],
              selected: {_themeMode},
              onSelectionChanged: (s) => _changeTheme(s.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected))
                    return context.brandPrimary;
                  return context.surfaceHover;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected))
                    return Colors.white;
                  return context.textColor;
                }),
                side: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected))
                    return BorderSide.none;
                  return BorderSide(color: context.borderColor);
                }),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DesignTokens.radius2xl))),
              ),
            ),
          ]),
        ),
        SizedBox(height: DesignTokens.space3),
        GlassCard(
          padding: EdgeInsets.all(DesignTokens.space6),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Notifications',
                style: context.textXl.copyWith(
                    fontWeight: DesignTokens.weightBold,
                    color: context.textColor)),
            SizedBox(height: DesignTokens.space2),
            Text(
              'A short chime plays for new notifications. The booking alarm repeats for an upcoming consultation while the app is open.',
              style: context.textSm.copyWith(color: context.textMuted),
            ),
            SizedBox(height: DesignTokens.space2),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Play sounds'),
              subtitle: const Text('Notification chime and booking alarm'),
              value: _soundEnabled,
              onChanged: _changeSound,
            ),
            TextButton.icon(
              onPressed: _soundEnabled ? _testSound : null,
              icon: const Icon(Icons.volume_up_outlined),
              label: const Text('Test sound'),
            ),
          ]),
        ),
        SizedBox(height: DesignTokens.space4),
        SecondaryButton(
          label: 'Log out',
          onPressed: _logout,
          iconLeft: Icons.logout,
        ),
      ],
    );
  }
}
