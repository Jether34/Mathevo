import 'dart:math';

import 'package:flutter/material.dart';

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

enum _AuthPage { getStarted, welcome, benefits, signup, login }

class _AuthFlowState extends State<AuthFlow> {
  _AuthPage _page = _AuthPage.getStarted;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

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
    super.dispose();
  }

  void _go(_AuthPage page) => setState(() {
    _page = page;
    _error = null;
  });

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await widget.authApi.signUp(
        name: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
      );
      _password.clear();
      await widget.onAuthenticated(session);
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
    final isForm = _page == _AuthPage.signup || _page == _AuthPage.login;
    final isSignup = _page == _AuthPage.signup;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenHeight = constraints.maxHeight;
            final cardHeight = isSignup
                ? min(screenHeight * .75, 580.0)
                : isForm
                ? min(screenHeight * .60, 470.0)
                : min(screenHeight * .48, 390.0);
            return Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _CirclePatternPainter()),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: screenHeight - cardHeight + 42,
                  child: Column(
                    children: [
                      if (_page != _AuthPage.getStarted &&
                          _page != _AuthPage.welcome)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: () => _go(
                              isForm ? _AuthPage.benefits : _AuthPage.welcome,
                            ),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 18),
                      const Spacer(),
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          size: 54,
                          color: Color(0xFF171C1B),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: cardHeight,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(48),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, cardConstraints) =>
                          SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: max(
                                  0,
                                  cardConstraints.maxHeight - 32,
                                ),
                              ),
                              child: IntrinsicHeight(
                                child: _content(context, isSignup),
                              ),
                            ),
                          ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, bool isSignup) {
    switch (_page) {
      case _AuthPage.getStarted:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MathVerse',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2422),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Calculate · Learn · Grow',
                  style: TextStyle(color: Color(0xFF77817F)),
                ),
              ],
            ),
            _primaryButton('GET STARTED', () => _go(_AuthPage.welcome)),
          ],
        );
      case _AuthPage.welcome:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome to MathVerse',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2422),
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'A place to solve, understand, and enjoy mathematics.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF77817F)),
                ),
              ],
            ),
            _primaryButton('CONTINUE', () => _go(_AuthPage.benefits)),
          ],
        );
      case _AuthPage.benefits:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'What you’ll get',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2422),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Explore practical math tools, keep your learning progress, and build confidence with a personal mathematics workspace.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF77817F),
                  ),
                ),
              ],
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _go(_AuthPage.login),
                  child: const Text('Already have an account? Log in'),
                ),
                _primaryButton(
                  'CREATE YOUR ACCOUNT',
                  () => _go(_AuthPage.signup),
                ),
              ],
            ),
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
              Text(
                isSignup ? 'Create new Account' : 'Login',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSignup ? 24 : 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1B2422),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                isSignup
                    ? 'Create your MathVerse cloud account.'
                    : 'Sign in to continue.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF858B89)),
              ),
              const SizedBox(height: 18),
              if (isSignup) ...[
                _label('NAME'),
                _input(
                  _name,
                  hint: 'Your name',
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter your name'
                      : null,
                ),
              ],
              _label('EMAIL'),
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
              _label('PASSWORD'),
              _input(
                _password,
                hint: 'At least 6 characters',
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
              const Spacer(),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const Key('auth-error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              TextButton(
                onPressed: () {
                  _password.clear();
                  _go(isSignup ? _AuthPage.login : _AuthPage.signup);
                },
                child: Text(
                  isSignup ? 'Already registered? Log in' : 'Sign up',
                ),
              ),
              if (!isSignup)
                const Text(
                  'Password recovery is not available yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF929896), fontSize: 11),
                ),
              const SizedBox(height: 6),
              _primaryButton(
                isSignup ? 'CREATE ACCOUNT' : 'LOG IN',
                isSignup ? _createAccount : _login,
                busy: _busy,
              ),
            ],
          ),
        );
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 3, top: 9, bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 1.2,
        color: Color(0xFF858B89),
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
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFD8D8D8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      suffixIcon: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
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
    height: 46,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1B2422),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
    ),
  );
}

class _CirclePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF1B2220), BlendMode.src);
    final paint = Paint()..color = const Color(0xFF283750);
    const radius = 20.0;
    for (var row = -1; row < 8; row++) {
      for (var col = -1; col < 9; col++) {
        final x = col * 54.0 + (row.isOdd ? 26 : 0) + 8;
        final y = row * 55.0 + 16;
        canvas.drawCircle(Offset(x, y), radius, paint);
        final shadow = Paint()..color = const Color(0xFF1B2220);
        canvas.drawCircle(Offset(x - 10, y - 3), radius * .67, shadow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
