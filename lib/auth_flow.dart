import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_api.dart';

/// Onboarding and account gate backed by the MathVerse cloud API.
class AuthFlow extends StatefulWidget {
  const AuthFlow({
    super.key,
    required this.authApi,
    required this.onAuthenticated,
    this.startAtWelcome = false,
  });

  final AuthApi authApi;
  final Future<void> Function(CloudAuthSession session) onAuthenticated;
  final bool startAtWelcome;

  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

enum _AuthPage {
  getStarted,
  welcome,
  benefits,
  signup,
  verifyEmail,
  login,
  forgotPassword,
  verifyResetCode,
  resetPassword,
}

class _AuthFlowState extends State<AuthFlow> {
  _AuthPage _page = _AuthPage.getStarted;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _verificationCode = TextEditingController();
  final _codeDigits = List.generate(6, (_) => TextEditingController());
  final _codeFocusNodes = List.generate(6, (_) => FocusNode());
  final _confirmPassword = TextEditingController();
  final Map<_AuthPage, GlobalKey<FormState>> _formKeys = {};
  bool _busy = false;
  bool _obscurePassword = true;
  bool _acceptedPolicies = false;
  bool _policyRequiredError = false;
  String? _resetToken;
  String? _error;
  String? _notice;

  GlobalKey<FormState> get _formKey =>
      _formKeys.putIfAbsent(_page, GlobalKey<FormState>.new);

  @override
  void initState() {
    super.initState();
    if (widget.startAtWelcome) _page = _AuthPage.welcome;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _verificationCode.dispose();
    for (final controller in _codeDigits) {
      controller.dispose();
    }
    for (final node in _codeFocusNodes) {
      node.dispose();
    }
    _confirmPassword.dispose();
    super.dispose();
  }

  void _go(_AuthPage page) => setState(() {
    _page = page;
    _error = null;
    _notice = null;
    _policyRequiredError = false;
  });

  void _back() {
    final page = switch (_page) {
      _AuthPage.verifyEmail => _AuthPage.signup,
      _AuthPage.forgotPassword => _AuthPage.login,
      _AuthPage.verifyResetCode => _AuthPage.forgotPassword,
      _AuthPage.resetPassword => _AuthPage.login,
      _AuthPage.signup || _AuthPage.login => _AuthPage.benefits,
      _ => _AuthPage.welcome,
    };
    _go(page);
  }

  void _showPolicy(String title, String text) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(text, style: const TextStyle(height: 1.45)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() => _showPolicy(
    'Privacy Policy',
    'MathVerse uses your name and email to create and secure your account. '
        'Your password is stored as a one-way hash. Email verification and '
        'password-reset codes are stored as hashes and expire. Account and '
        'session records are kept in the MathVerse cloud service. Calculation '
        'history and learning progress are stored on this device. The current '
        'community screens do not publish your calculations. You can use the '
        'local calculator without creating an account. Contact the developer '
        'if you need help with an account or its data.',
  );

  void _showTerms() => _showPolicy(
    'Terms of Use',
    'Use MathVerse for personal learning and calculation. Keep your account '
        'credentials private and do not misuse the service or attempt to access '
        'another person’s account. MathVerse provides mathematical tools and '
        'learning aids; check important results independently, especially '
        'before using them in coursework or other consequential work. Features '
        'may change as the app is maintained. By creating an account, you agree '
        'to these terms and the Privacy Policy.',
  );

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedPolicies) {
      setState(() => _policyRequiredError = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authApi.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      _password.clear();
      _clearVerificationCode();
      if (mounted) {
        setState(() {
          _page = _AuthPage.verifyEmail;
          _notice =
              'We sent a six-digit verification code to ${_email.text.trim()}.';
        });
      }
    } on AuthApiException catch (error) {
      setState(() {
        if (error.statusCode == 409) {
          _email.text = _email.text.trim().toLowerCase();
          _password.clear();
          _page = _AuthPage.login;
        }
        _error = error.message;
      });
    } catch (_) {
      setState(() => _error = 'Could not create your account. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifySignupCode() async {
    if (!_hasValidCode()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await widget.authApi.verifyEmail(
        email: _email.text.trim(),
        code: _verificationCode.text.trim(),
      );
      _clearVerificationCode();
      await widget.onAuthenticated(session);
    } on AuthApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Could not verify the code. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendSignupCode() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.authApi.resendSignupCode(email: _email.text.trim());
      _clearVerificationCode();
      setState(() => _notice = 'A new verification code has been sent.');
    } on AuthApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Could not resend the code. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestPasswordReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.authApi.requestPasswordReset(email: _email.text.trim());
      _clearVerificationCode();
      setState(() {
        _page = _AuthPage.verifyResetCode;
        _notice = 'If the account exists, a reset code has been sent.';
      });
    } on AuthApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Could not request a reset code. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyResetCode() async {
    if (!_hasValidCode()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _resetToken = await widget.authApi.verifyPasswordReset(
        email: _email.text.trim(),
        code: _verificationCode.text.trim(),
      );
      _password.clear();
      _confirmPassword.clear();
      setState(() {
        _page = _AuthPage.resetPassword;
        _notice = null;
      });
    } on AuthApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Could not verify the code. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _hasValidCode() {
    _verificationCode.text = _codeDigits.map((digit) => digit.text).join();
    if (RegExp(r'^\d{6}$').hasMatch(_verificationCode.text)) return true;
    setState(() => _error = 'Enter all six digits from the email.');
    return false;
  }

  void _clearVerificationCode() {
    for (final controller in _codeDigits) {
      controller.clear();
    }
    _verificationCode.clear();
    _codeFocusNodes.first.requestFocus();
  }

  void _handleCodeDigitChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      for (
        var offset = 0;
        offset < digits.length && index + offset < 6;
        offset++
      ) {
        _codeDigits[index + offset].text = digits[offset];
      }
      final next = (index + digits.length).clamp(0, 5).toInt();
      _codeFocusNodes[next].requestFocus();
    } else if (digits.isEmpty) {
      _codeDigits[index].clear();
      if (index > 0) _codeFocusNodes[index - 1].requestFocus();
    } else {
      _codeDigits[index].text = digits;
      if (index < 5) {
        _codeFocusNodes[index + 1].requestFocus();
      } else {
        _codeFocusNodes[index].unfocus();
      }
    }
    _verificationCode.text = _codeDigits.map((digit) => digit.text).join();
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _completePasswordReset() async {
    if (!_formKey.currentState!.validate()) return;
    final token = _resetToken;
    if (token == null) {
      setState(() => _error = 'Verify your email code first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authApi.completePasswordReset(
        email: _email.text.trim(),
        resetToken: token,
        newPassword: _password.text,
      );
      _password.clear();
      _confirmPassword.clear();
      _resetToken = null;
      setState(() {
        _page = _AuthPage.login;
        _notice =
            'Your password has been reset. Log in with your new password.';
      });
    } on AuthApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Could not reset your password. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await widget.authApi.logIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      _password.clear();
      await widget.onAuthenticated(session);
    } on AuthApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(
        () =>
            _error = 'Could not sign in. Check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignup = _page == _AuthPage.signup;
    final isIntro =
        _page == _AuthPage.getStarted ||
        _page == _AuthPage.welcome ||
        _page == _AuthPage.benefits;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: const Color(0xFF4F7F86),
          secondary: const Color(0xFF4F7F86),
        ),
      ),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: max(0, constraints.maxHeight - 30),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isIntro)
                            _brandHeader()
                          else
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                tooltip: 'Back',
                                onPressed: _back,
                                padding: EdgeInsets.zero,
                                alignment: Alignment.centerLeft,
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Color(0xFF273638),
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          Expanded(child: _content(context, isSignup)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandHeader() => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F2F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.functions_rounded,
          color: Color(0xFF4F7F86),
          size: 23,
        ),
      ),
      const SizedBox(width: 10),
      const Text(
        'MathVerse',
        style: TextStyle(
          color: Color(0xFF293638),
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    ],
  );

  Widget _content(BuildContext context, bool isSignup) {
    switch (_page) {
      case _AuthPage.getStarted:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: Image.asset(
                'assets/brand/mathverse_mascot.png',
                height: min(MediaQuery.sizeOf(context).height * .39, 310),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Welcome to MathVerse!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF343B3B),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Solve, explore, and understand mathematics at your own pace.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8A9292),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _progressDots(0),
            const Spacer(),
            _primaryButton('Get Started', () => _go(_AuthPage.welcome)),
          ],
        );
      case _AuthPage.welcome:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: Image.asset(
                'assets/brand/mathverse_mascot.png',
                height: min(MediaQuery.sizeOf(context).height * .31, 245),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Welcome to MathVerse',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: Color(0xFF343B3B),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'A workspace to solve, see, and understand mathematics.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A9292), height: 1.45),
            ),
            const SizedBox(height: 20),
            _featureRow(
              Icons.calculate_outlined,
              'Solve with purpose',
              'Use core and advanced tools to work through math problems.',
            ),
            const SizedBox(height: 12),
            _featureRow(
              Icons.auto_graph_rounded,
              'See how math behaves',
              'Explore graphs, geometry, and interactive visualizations.',
            ),
            const SizedBox(height: 20),
            _progressDots(1),
            const Spacer(),
            _primaryButton('Continue', () => _go(_AuthPage.benefits)),
          ],
        );
      case _AuthPage.benefits:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Text(
              'What you?ll get',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF343B3B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tools for practice, discovery, and progress.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A9292)),
            ),
            const SizedBox(height: 24),
            _featureRow(
              Icons.functions_rounded,
              'Calculate and visualize',
              'Explore selected math modes, graphs, geometry, and interactive visualizations.',
            ),
            const SizedBox(height: 12),
            _featureRow(
              Icons.menu_book_outlined,
              'Learn and build a habit',
              'Resume lessons and track progress, streaks, and XP.',
            ),
            const SizedBox(height: 12),
            _featureRow(
              Icons.history_rounded,
              'Review your work',
              'Return to recent calculations and saved history.',
            ),
            const SizedBox(height: 18),
            _progressDots(2),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have an account?',
                  style: TextStyle(color: Color(0xFF8A9292), fontSize: 12),
                ),
                TextButton(
                  onPressed: () => _go(_AuthPage.login),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Log in'),
                ),
              ],
            ),
            _primaryButton('Create your account', () => _go(_AuthPage.signup)),
          ],
        );
      case _AuthPage.signup:
      case _AuthPage.login:
        return Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _eyebrow(isSignup ? 'ACCOUNT SETUP' : 'ACCOUNT ACCESS'),
              const SizedBox(height: 8),
              Text(
                isSignup ? 'Create your account' : 'Welcome back',
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B2422),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isSignup
                    ? 'Save your progress and pick up where you left off.'
                    : 'Sign in to continue learning and calculating.',
                textAlign: TextAlign.left,
                style: const TextStyle(fontSize: 13, color: Color(0xFF77817F)),
              ),
              const SizedBox(height: 18),
              if (isSignup) ...[
                _label('Name'),
                _input(
                  _name,
                  hint: 'Your name',
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter your name'
                      : null,
                ),
              ],
              _label('Email address'),
              _input(
                _email,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null ||
                      !RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(value.trim())) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              _label('Password'),
              _input(
                _password,
                hint: 'At least 8 characters',
                obscureText: _obscurePassword,
                suffix: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                ),
                validator: (value) => (value == null || value.length < 8)
                    ? 'Use at least 8 characters'
                    : null,
              ),
              if (isSignup) _policyConsentRow(),
              const Spacer(),
              if (!isSignup)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _go(_AuthPage.forgotPassword),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),
              if (!isSignup) const SizedBox(height: 4),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  key: const Key('auth-error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              if (_notice != null) ...[
                const SizedBox(height: 4),
                Text(
                  _notice!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF28764C),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _primaryButton(
                isSignup ? 'Create account' : 'Sign in',
                isSignup ? _createAccount : _login,
                busy: _busy,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isSignup ? 'Already have an account?' : 'New to MathVerse?',
                    style: const TextStyle(
                      color: Color(0xFF77817F),
                      fontSize: 12,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _password.clear();
                      _go(isSignup ? _AuthPage.login : _AuthPage.signup);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(isSignup ? 'Log in' : 'Create account'),
                  ),
                ],
              ),
            ],
          ),
        );
      case _AuthPage.verifyEmail:
        return _verificationForm(
          title: 'Verify your email',
          description:
              'Enter the six-digit code sent to ${_email.text.trim()}.',
          onSubmit: _verifySignupCode,
          showResend: true,
        );
      case _AuthPage.forgotPassword:
        return _emailResetForm();
      case _AuthPage.verifyResetCode:
        return _verificationForm(
          title: 'Verify reset code',
          description:
              'Enter the six-digit code sent to ${_email.text.trim()}.',
          onSubmit: _verifyResetCode,
        );
      case _AuthPage.resetPassword:
        return _newPasswordForm();
    }
  }

  Widget _featureRow(IconData icon, String title, String description) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF2F2),
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: const Color(0xFF4F7F86), size: 19),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF17233D),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF77817F),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _eyebrow(String label) => Text(
    label,
    style: const TextStyle(
      color: Color(0xFF69717D),
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );

  Widget _progressDots(int active) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3, (index) {
      final selected = index == active;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: selected ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4F7F86) : const Color(0xFFE2E8E8),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }),
  );

  Widget _policyConsentRow() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            height: 36,
            child: Checkbox(
              key: const Key('policy-checkbox'),
              value: _acceptedPolicies,
              visualDensity: VisualDensity.compact,
              onChanged: (accepted) => setState(() {
                _acceptedPolicies = accepted ?? false;
                if (_acceptedPolicies) _policyRequiredError = false;
              }),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'I agree to the ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF39465B)),
                  ),
                  InkWell(
                    key: const Key('privacy-policy-link'),
                    onTap: _showPrivacyPolicy,
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4F7F86),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Text(
                    ' and ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF39465B)),
                  ),
                  InkWell(
                    key: const Key('terms-of-use-link'),
                    onTap: _showTerms,
                    child: const Text(
                      'Terms of Use',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4F7F86),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      if (_policyRequiredError)
        const Padding(
          padding: EdgeInsets.only(left: 38, top: 1),
          child: Text(
            'Please accept both documents to create an account.',
            key: Key('policy-required-error'),
            style: TextStyle(color: Color(0xFFD84B4B), fontSize: 11),
          ),
        ),
    ],
  );

  Widget _verificationForm({
    required String title,
    required String description,
    required Future<void> Function() onSubmit,
    bool showResend = false,
  }) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B2422),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(color: Color(0xFF77817F), fontSize: 13),
        ),
        const SizedBox(height: 22),
        Row(
          children: List.generate(6, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 5 ? 0 : 8),
                child: SizedBox(
                  height: 58,
                  child: TextField(
                    key: Key('verification-digit-$index'),
                    controller: _codeDigits[index],
                    focusNode: _codeFocusNodes[index],
                    autofocus: index == 0,
                    keyboardType: TextInputType.number,
                    autofillHints: index == 0
                        ? const [AutofillHints.oneTimeCode]
                        : null,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF17233D),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => _handleCodeDigitChanged(index, value),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: const Color(0xFFF3F6FA),
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE1E7EF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF4F7F86),
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        const Text(
          'The code expires in 10 minutes.',
          style: TextStyle(color: Color(0xFF77817F), fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (_notice != null) _noticeText(_notice!),
        if (_error != null) _errorText(_error!),
        const Spacer(),
        const SizedBox(height: 8),
        _primaryButton(
          showResend ? 'Verify email' : 'Verify code',
          onSubmit,
          busy: _busy,
        ),
        if (showResend)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Didn’t get the email?',
                style: TextStyle(color: Color(0xFF77817F), fontSize: 12),
              ),
              TextButton(
                onPressed: _busy ? null : _resendSignupCode,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Resend code'),
              ),
            ],
          ),
        TextButton(
          onPressed: () =>
              _go(showResend ? _AuthPage.signup : _AuthPage.forgotPassword),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            showResend ? 'Back to sign up' : 'Back to reset password',
          ),
        ),
      ],
    ),
  );

  Widget _emailResetForm() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _eyebrow('ACCOUNT RECOVERY'),
        const SizedBox(height: 8),
        const Text(
          'Reset password',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B2422),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'We’ll email a six-digit code to your account.',
          style: TextStyle(color: Color(0xFF77817F), fontSize: 12),
        ),
        const SizedBox(height: 8),
        _label('Email address'),
        _input(
          _email,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          validator: _validateEmail,
        ),
        const Spacer(),
        const SizedBox(height: 4),
        if (_error != null) _errorText(_error!),
        const SizedBox(height: 6),
        _primaryButton('Send reset code', _requestPasswordReset, busy: _busy),
      ],
    ),
  );

  Widget _newPasswordForm() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _eyebrow('ACCOUNT RECOVERY'),
        const SizedBox(height: 8),
        const Text(
          'Choose a new password',
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1B2422),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Verified for ${_email.text.trim()}',
          textAlign: TextAlign.left,
          style: const TextStyle(color: Color(0xFF77817F), fontSize: 12),
        ),
        const SizedBox(height: 16),
        _label('NEW PASSWORD'),
        _input(
          _password,
          hint: 'At least 8 characters',
          obscureText: _obscurePassword,
          validator: (value) => value == null || value.length < 8
              ? 'Use at least 8 characters'
              : null,
        ),
        _label('CONFIRM PASSWORD'),
        _input(
          _confirmPassword,
          hint: 'Enter the password again',
          obscureText: _obscurePassword,
          validator: (value) =>
              value != _password.text ? 'Passwords do not match' : null,
        ),
        const Spacer(),
        const SizedBox(height: 10),
        if (_error != null) _errorText(_error!),
        _primaryButton('Update password', _completePasswordReset, busy: _busy),
      ],
    ),
  );

  String? _validateEmail(String? value) =>
      value == null ||
          !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())
      ? 'Enter a valid email'
      : null;

  Widget _noticeText(String message) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFF28764C), fontSize: 12),
    ),
  );

  Widget _errorText(String message) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      message,
      key: const Key('auth-error'),
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.red, fontSize: 12),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 2, top: 11, bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF596566),
      ),
    ),
  );

  Widget _input(
    TextEditingController controller, {
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
  }) => TextFormField(
    controller: controller,
    validator: validator,
    keyboardType: keyboardType,
    obscureText: obscureText,
    style: const TextStyle(fontSize: 15, color: Color(0xFF293638)),
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8F9F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFEEF0F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF4F7F86), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFD84B4B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFD84B4B), width: 1.6),
      ),
      errorStyle: const TextStyle(fontSize: 10),
    ),
  );

  Widget _primaryButton(
    String label,
    VoidCallback onPressed, {
    bool busy = false,
  }) => SizedBox(
    width: double.infinity,
    height: 56,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF4F7F86),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
    ),
  );
}
