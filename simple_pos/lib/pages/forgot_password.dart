import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth/simple_auth_service.dart';
import '../services/supabase/supabase_project_config.dart';
import '../styles/my_colors.dart';

/// Lets the user request a Supabase password-recovery email.
///
/// The email contains a link that redirects back to
/// `http://localhost:3000/#access_token=...&type=recovery`, which the
/// `AuthGate` picks up and turns into a navigation to
/// `ResetPasswordPage`.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'أدخل البريد الإلكتروني';
    }
    final email = value.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'بريد إلكتروني غير صالح';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isSuccess) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    // Surface a clear "not configured" message up-front instead of letting
    // the SDK throw a generic AuthException.
    if (!SupabaseProjectConfig.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Supabase غير مهيأ، تحقق من إعدادات التطبيق'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await SimpleAuthService.instance
          .sendRecoveryEmail(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال رابط الاسترداد إلى بريدك')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_describeAuthError(e))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      // Includes the StateError raised when Supabase is not configured at
      // all — surface a clear message instead of leaking internal copy.
      final msg = e is StateError
          ? 'Supabase غير مهيأ، تحقق من إعدادات التطبيق'
          : 'تعذر إرسال البريد: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نسيت كلمة المرور'),
        backgroundColor: MyColors.mainColor(context),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              MyColors.mainColor(context),
              MyColors.secondColor(context),
            ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'استرداد كلمة المرور',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: MyColors.mainColor(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'أدخل بريدك الإلكتروني وسنرسل لك رابطًا لإعادة تعيين كلمة المرور',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isSubmitting && !_isSuccess,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        validator: _validateEmail,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_isSubmitting || _isSuccess)
                              ? null
                              : _submit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              _isSubmitting
                                  ? 'جاري الإرسال...'
                                  : _isSuccess
                                      ? 'تم الإرسال'
                                      : 'إرسال رابط الاسترداد',
                            ),
                          ),
                        ),
                      ),
                      if (_isSuccess) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'افتح بريدك واتبع الرابط لإعادة تعيين كلمة المرور',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('العودة إلى تسجيل الدخول'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _describeAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'محاولات كثيرة، حاول لاحقًا';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'خطأ في الاتصال، تحقق من الإنترنت';
    }
    return e.message.isNotEmpty ? e.message : 'فشل إرسال البريد';
  }
}
