import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../theme.dart';
import '../ui.dart';
import '../util.dart';
import 'home.dart';

void goHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()), (r) => false);
}

/// Branded welcome screen with direct registration and login actions.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _pages = PageController(viewportFraction: 0.88);
  int _index = 0;

  static const _slides = <_WelcomeSlide>[
    _WelcomeSlide(
        Icons.search,
        'Find the right adviser',
        'Search by topic, skill, or name and find the right match for your research.',
        [
          'Search by research topic',
          'Compare specializations',
          'Check open advisee slots'
        ]),
    _WelcomeSlide(
        Icons.how_to_reg,
        'Apply and get approved',
        'Send your proposal to an adviser and follow its status from your account.',
        [
          'Submit a project brief',
          'Track pending requests',
          'See approval updates'
        ]),
    _WelcomeSlide(
        Icons.event_available,
        'Book in a few taps',
        'Choose an available consultation time and keep the details in one place.',
        [
          'Browse open times',
          'Avoid double bookings',
          'Get meeting reminders'
        ]),
    _WelcomeSlide(
        Icons.checklist,
        'Track every task',
        'Organize research work by stage and keep adviser feedback alongside it.',
        ['Plan next steps', 'Share project files', 'Review adviser comments']),
    _WelcomeSlide(
        Icons.insights,
        'See your progress',
        'Keep milestones, consultation history, and project progress visible.',
        [
          'Follow thesis milestones',
          'Review consultation history',
          'See progress at a glance'
        ]),
  ];

  Future<void> _editServer(BuildContext context) async {
    final c = TextEditingController(text: Api.baseUrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: buildLight(),
        child: AlertDialog(
          backgroundColor: context.surfaceElevated,
          title: const Text('Server address'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
                'Current API: ${Api.baseUrl}\nFor a real phone, use your computer LAN IP instead of localhost.',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            TextField(controller: c, keyboardType: TextInputType.url),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await Api.setBaseUrl(c.text);
      if (context.mounted) snack(context, 'Server saved.');
    }
  }

  void _goToPage(int page) => _pages.animateToPage(
        page.clamp(0, _slides.length),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );

  Widget _welcomePage() => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _WelcomePanel(
                  title: 'Welcome to AdviserLink',
                  subtitle:
                      'Hi there! Find an adviser, schedule consultations, and move your research forward.',
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Create account',
                  iconRight: Icons.arrow_forward,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const RegisterScreen())),
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  label: 'Log in',
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen())),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _featurePage(int page) {
    final slide = _slides[page - 1];
    final active = _index == page;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, active ? -4 : 0, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.brandPrimary.withValues(alpha: 0.16),
            context.surfaceElevated
          ],
        ),
        borderRadius: BorderRadius.circular(context.radius3xl),
        border: Border.all(color: context.borderColor.withValues(alpha: 0.7)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: context.brandPrimary,
                      borderRadius: BorderRadius.circular(16)),
                  child: Icon(slide.icon, color: Colors.white, size: 27),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.brandPrimary.withValues(alpha: 0.12),
                    border: Border.all(
                        color: context.brandPrimary.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('STEP $page',
                      style: context.textXs.copyWith(
                          color: context.brandPrimary,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 24),
              Text(slide.title,
                  style: context.text2xl.copyWith(
                      color: context.textColor,
                      fontWeight: FontWeight.w800,
                      height: 1.15)),
              const SizedBox(height: 10),
              Text(slide.description,
                  style: context.textSm
                      .copyWith(color: context.textMuted, height: 1.45)),
              const SizedBox(height: 24),
              for (var itemIndex = 0;
                  itemIndex < slide.examples.length;
                  itemIndex++) ...[
                if (itemIndex > 0) const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.surfaceElevated.withValues(alpha: 0.72),
                    border: Border.all(
                        color: context.borderColor.withValues(alpha: 0.55)),
                    borderRadius: BorderRadius.circular(context.radiusXl),
                  ),
                  child: Row(children: [
                    Icon(Icons.check_circle_outline,
                        color: context.brandPrimary, size: 19),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(slide.examples[itemIndex],
                            style: context.textSm.copyWith(
                                color: context.textColor,
                                fontWeight: FontWeight.w600))),
                    Text('0${itemIndex + 1}',
                        style:
                            context.textXs.copyWith(color: context.textMuted)),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: BentoBackground(
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/adviserlink-logo.png',
                          width: 36, height: 36)),
                  const SizedBox(width: 9),
                  Text('adviserlink',
                      style: context.textXl.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.textColor)),
                  const Spacer(),
                  IconButton2(
                      onPressed: () => _editServer(context),
                      icon: Icons.settings_ethernet,
                      tooltip: 'Server settings'),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen())),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6)),
                    child: Text('Log in',
                        style: TextStyle(
                            color: context.brandPrimary,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _slides.length + 1,
                  onPageChanged: (page) => setState(() => _index = page),
                  itemBuilder: (_, page) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: page == 0 ? _welcomePage() : _featurePage(page),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(children: [
                  Row(children: [
                    IconButton2(
                        onPressed:
                            _index == 0 ? null : () => _goToPage(_index - 1),
                        icon: Icons.arrow_back),
                    Expanded(
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var page = 0; page <= _slides.length; page++)
                              GestureDetector(
                                onTap: () => _goToPage(page),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  width: page == _index ? 20 : 8,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: page == _index
                                        ? context.brandPrimary
                                        : context.brandPrimary
                                            .withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                          ]),
                    ),
                    IconButton2(
                        onPressed: _index == _slides.length
                            ? null
                            : () => _goToPage(_index + 1),
                        icon: Icons.arrow_forward),
                  ]),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'Get started',
                    iconRight: Icons.arrow_forward,
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen())),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _WelcomeSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<String> examples;

  const _WelcomeSlide(this.icon, this.title, this.description, this.examples);
}

class _WelcomePanel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _WelcomePanel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.brandPrimary.withValues(alpha: 0.18),
              context.surfaceElevated
            ],
          ),
          borderRadius: BorderRadius.circular(context.radius3xl),
          border: Border.all(color: context.borderColor.withValues(alpha: 0.7)),
        ),
        child: Column(children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset('assets/adviserlink-logo.png',
                  width: 76, height: 76)),
          const SizedBox(height: 18),
          Text('ADVISERLINK',
              style: context.textXs.copyWith(
                  color: context.brandPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(title,
              textAlign: TextAlign.center,
              style: context.text3xl.copyWith(
                  color: context.textColor,
                  fontWeight: FontWeight.w800,
                  height: 1.12)),
          const SizedBox(height: 10),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: context.textSm
                  .copyWith(color: context.textMuted, height: 1.45)),
        ]),
      );
}

class _AuthFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool isRegister;

  const _AuthFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.isRegister,
  });

  Widget _tab(BuildContext context, String label, bool active, bool register) =>
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (active) return;
            Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) =>
                  register ? const RegisterScreen() : const LoginScreen(),
            ));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFF1E2F4) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    active ? const Color(0xFF6D286F) : const Color(0xFF77707B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: BentoBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text('Home'),
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                          const Spacer(),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.asset('assets/adviserlink-logo.png',
                                width: 32, height: 32),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'adviserlink',
                            style: context.textLg.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _AuthShowcase(),
                      const SizedBox(height: 14),
                      Theme(
                        data: buildLight(),
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.72)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x400D0017),
                                blurRadius: 36,
                                offset: Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  _tab(context, 'Sign up', isRegister, true),
                                  const SizedBox(width: 6),
                                  _tab(context, 'Log in', !isRegister, false),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                isRegister ? 'A FRESH START' : 'WELCOME BACK',
                                style: const TextStyle(
                                  color: Color(0xFF8D348E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                title,
                                style: const TextStyle(
                                  color: Color(0xFF35143C),
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  height: 1.12,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: Color(0xFF665A6C),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 20),
                              child,
                              const SizedBox(height: 16),
                              const Text(
                                'AdviserLink · ISU Echague',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF8B7D91),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
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

class _AuthShowcase extends StatelessWidget {
  const _AuthShowcase();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.23)),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0x49FFFFFF),
              Color(0x20FFFFFF),
              Color(0x3320002C),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44080017),
              blurRadius: 30,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: Color(0xFFFFB5E5), size: 15),
                const SizedBox(width: 7),
                Text(
                  'A WORLD OF PROGRESS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Big goals feel lighter together.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w800,
                height: 1.08,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Find your people, make a plan, and watch your research take shape.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/adviserlink-research-team.png',
                width: double.infinity,
                height: 156,
                fit: BoxFit.cover,
                semanticLabel:
                    'Students and advisers collaborating on a research project',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: const [
                  _JourneyStep(number: '✓', label: 'Find your people'),
                  _JourneyStep(number: '02', label: 'Plan a session'),
                  _JourneyStep(number: '03', label: 'Make your next move'),
                ],
              ),
            ),
          ],
        ),
      );
}

class _JourneyStep extends StatelessWidget {
  final String number;
  final String label;

  const _JourneyStep({required this.number, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Row(
          children: [
            Container(
              width: 21,
              height: 21,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class LoginScreen extends StatefulWidget {
  final String? notice;
  final String? initialEmail;

  const LoginScreen({super.key, this.notice, this.initialEmail});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _error = '';
  String _notice = '';
  bool _busy = false;
  bool _credentialError = false;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail ?? '';
    _notice = widget.notice ?? '';
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  void _clearLoginError(String _) {
    if (!_credentialError && _error.isEmpty) return;
    setState(() {
      _error = '';
      _credentialError = false;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _error = '';
      _credentialError = false;
      _busy = true;
    });
    try {
      await Api.login(_email.text.trim(), _password.text);
      if (mounted) goHome(context);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      setState(() {
        _credentialError =
            message.toLowerCase().contains('incorrect email or password');
        _error = message;
        _busy = false;
      });
    }
  }

  Future<void> _resendVerification() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    try {
      await Api.resendVerification(email);
      if (mounted) snack(context, 'If the account exists, a link was sent.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
        title: 'Welcome back',
        subtitle: 'Log in to continue to AdviserLink.',
        isRegister: false,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_notice.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_notice,
                    style: TextStyle(color: context.brandPrimary)),
              ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child:
                    Text(_error, style: TextStyle(color: context.errorColor())),
              ),
            AppInput(
              controller: _email,
              label: 'Email',
              hint: 'Enter email',
              keyboardType: TextInputType.emailAddress,
              required: true,
              invalid: _credentialError,
              onChanged: _clearLoginError,
              validator: _validateEmail,
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: _password,
              label: 'Password',
              hint: 'Enter password',
              obscureText: true,
              suffixIcon: Icons.visibility_outlined,
              required: true,
              invalid: _credentialError,
              onChanged: _clearLoginError,
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your password.'
                  : null,
              onSubmitted: (_) => _submit(),
            ),
            if (_error.toLowerCase().contains('verify'))
              TextButton(
                onPressed: _resendVerification,
                child: const Text('Resend verification email'),
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              onPressed: _busy ? null : _submit,
              label: _busy ? 'Logging in…' : 'Log in',
            ),
          ]),
        ),
      );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _departments = [
    'Information Technology',
    'Computer Science',
    'Information Systems',
    'Data Science and Analytics',
    'Library and Information Science',
  ];
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String _error = '';
  String _role = 'student';
  String _department = '';
  String _studentGroupRole = 'leader';
  Uint8List? _profilePhotoBytes;
  String? _profilePhotoDataUrl;
  String _photoError = '';
  bool _busy = false;

  Future<void> _pickProfilePhoto() async {
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
        setState(() => _photoError = 'Profile photos must be 2 MB or smaller.');
        return;
      }
      final mimeType = imageMimeType(bytes);
      if (mimeType == null) {
        setState(() => _photoError = 'Choose a PNG, JPEG, or WebP image.');
        return;
      }
      setState(() {
        _profilePhotoBytes = bytes;
        _profilePhotoDataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
        _photoError = '';
      });
    } catch (e) {
      if (mounted)
        setState(() =>
            _photoError = 'Could not load that image. Please try another one.');
    }
  }

  Future<void> _submit() async {
    setState(() => _error = '');
    if (_password.text != _confirm.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
    if (_role == 'adviser' && _department.isEmpty) {
      setState(() => _error = 'Choose your department.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await Api.register(
        _name.text.trim(),
        _email.text.trim(),
        _password.text,
        _confirm.text,
        role: _role,
        studentGroupRole: _studentGroupRole,
        department: _role == 'adviser' ? _department : null,
        profilePhoto: _profilePhotoDataUrl,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => LoginScreen(
            notice: '${result['message'] ?? 'Account created.'}',
            initialEmail: _email.text.trim(),
          ),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
        title: 'Create your account',
        subtitle: 'Start your thesis or capstone journey with AdviserLink.',
        isRegister: true,
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Register as',
              style: context.textSm.copyWith(color: context.textMuted)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'student',
                  label: Text('Student'),
                  icon: Icon(Icons.school_outlined)),
              ButtonSegment(
                  value: 'adviser',
                  label: Text('Adviser'),
                  icon: Icon(Icons.menu_book_outlined)),
            ],
            selected: {_role},
            onSelectionChanged: _busy
                ? null
                : (selection) => setState(() {
                      _role = selection.first;
                      _error = '';
                    }),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 14),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child:
                  Text(_error, style: TextStyle(color: context.errorColor())),
            ),
          Row(children: [
            ClipOval(
              child: _profilePhotoBytes == null
                  ? Container(
                      width: 64,
                      height: 64,
                      color: context.surfaceElevated,
                      child: Icon(Icons.person_outline,
                          color: context.textMuted, size: 30),
                    )
                  : Image.memory(_profilePhotoBytes!,
                      width: 64, height: 64, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pickProfilePhoto,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: Text(_profilePhotoBytes == null
                          ? 'Add profile photo'
                          : 'Change photo'),
                    ),
                    if (_profilePhotoBytes != null)
                      TextButton(
                          onPressed: () => setState(() {
                                _profilePhotoBytes = null;
                                _profilePhotoDataUrl = null;
                              }),
                          child: const Text('Remove photo')),
                    Text(
                        _photoError.isEmpty
                            ? 'Optional · PNG, JPG, or WebP · max 2 MB'
                            : _photoError,
                        style: context.textXs.copyWith(
                            color: _photoError.isEmpty
                                ? context.textMuted
                                : context.errorColor())),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          if (_role == 'student')
            InputDecorator(
              decoration:
                  const InputDecoration(labelText: 'Student group role'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _studentGroupRole,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                        value: 'leader', child: Text('Group leader')),
                    DropdownMenuItem(
                        value: 'member', child: Text('Group member')),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null)
                            setState(() => _studentGroupRole = value);
                        },
                ),
              ),
            ),
          if (_role == 'adviser') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _department.isEmpty ? null : _department,
              decoration: const InputDecoration(labelText: 'Department *'),
              items: _departments
                  .map((department) => DropdownMenuItem(
                      value: department, child: Text(department)))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _department = value ?? ''),
            ),
            const SizedBox(height: 12),
            Text('New adviser accounts need Admin approval before login.',
                style: context.textSm.copyWith(color: context.textMuted)),
          ],
          if (_role == 'student') const SizedBox(height: 12),
          AppInput(
              controller: _name, label: 'Full name', hint: 'Enter full name'),
          const SizedBox(height: 12),
          AppInput(
            controller: _email,
            label: 'Email',
            hint: 'Enter email',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          AppInput(
            controller: _password,
            label: 'Password',
            hint: 'At least 8 characters',
            obscureText: true,
            suffixIcon: Icons.visibility_outlined,
          ),
          const SizedBox(height: 12),
          AppInput(
            controller: _confirm,
            label: 'Confirm password',
            hint: 'Re-enter password',
            obscureText: true,
            suffixIcon: Icons.visibility_outlined,
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            onPressed: _busy ? null : _submit,
            label: _busy ? 'Creating…' : 'Get started',
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LoginScreen())),
              child: Text('Already have an account? Log in',
                  style: TextStyle(
                      color: context.brandPrimary,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      );
}

class EmailVerificationScreen extends StatefulWidget {
  final String? email;
  final String? token;

  const EmailVerificationScreen({super.key, this.email, this.token});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late final TextEditingController _email;
  late final TextEditingController _token;
  bool _busy = false;
  bool _verified = false;
  String _error = '';
  String? _devLink;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.email ?? '');
    _token = TextEditingController(text: widget.token ?? '');
    if (_token.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    super.dispose();
  }

  String _tokenValue(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    return uri?.queryParameters['token'] ?? trimmed;
  }

  Future<void> _verify() async {
    final token = _tokenValue(_token.text);
    if (token.isEmpty) {
      setState(() => _error = 'Paste the token from your verification link.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      await Api.verifyEmail(token);
      if (mounted) setState(() => _verified = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
      _devLink = null;
    });
    try {
      await Api.resendVerification(email);
      if (mounted) snack(context, 'If the account exists, a link was sent.');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _getDevLink() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
      _devLink = null;
    });
    try {
      final result = await Api.getDevToken(email, 'verify-email');
      if (mounted) setState(() => _devLink = '${result['url'] ?? ''}');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthFrame(
        title: 'Verify your email',
        subtitle: 'Use the token from your email verification link.',
        isRegister: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_verified) ...[
              const Icon(Icons.check_circle_outline,
                  size: 48, color: Colors.green),
              const SizedBox(height: 8),
              const Text('Email verified. You can now log in.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Go to log in',
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => route.isFirst,
                ),
              ),
            ] else ...[
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_error,
                      style: TextStyle(color: context.errorColor())),
                ),
              AppInput(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              AppInput(
                controller: _token,
                label: 'Verification token or full link',
                hint: 'Paste the token or link from your email',
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                onPressed: _busy ? null : _verify,
                label: _busy ? 'Verifying…' : 'Verify email',
              ),
              TextButton(
                onPressed: _busy ? null : _resend,
                child: const Text('Resend verification email'),
              ),
              TextButton(
                onPressed: _busy ? null : _getDevLink,
                child: const Text('Get verification link (dev mode)'),
              ),
              if (_devLink != null && _devLink!.isNotEmpty) ...[
                SelectableText(_devLink!),
                TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _devLink!));
                    if (mounted) snack(context, 'Link copied.');
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy link'),
                ),
              ],
            ],
          ],
        ),
      );
}
