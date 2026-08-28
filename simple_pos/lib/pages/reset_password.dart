import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth/simple_auth_service.dart';
import '../styles/my_colors.dart';

/// Shown when the user opens a Supabase password-recovery link.
///
/// The `AuthGate` displays this page whenever
/// `SimpleAuthService.instance.isPasswordRecovery` is true. It lets the user
/// pick a new password, calls `supabase.auth.updateUser(...)`, signs out the
/// recovery session, and routes back to the Login page.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSuccess = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'أدخل كلمة المرور';
    }
    if (value.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) {
      return 'أكد كلمة المرور';
    }
    if (value != _passwordController.text) {
      return 'كلمتا المرور غير متطابقتين';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isSuccess) return;

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    // Defensive check: make sure Supabase actually has a recovery session
    // before we call updateUser (otherwise we'd be changing the wrong
    // account's password).
    if (Supabase.instance.client.auth.currentSession == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('انتهت صلاحية رابط الاسترداد')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await SimpleAuthService.instance.updatePassword(_passwordController.text);
      if (!mounted) return;

      setState(() {
        _isSuccess = true;
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
      );

      // Sign the recovery session out so the AuthGate returns to Login.
      await SimpleAuthService.instance.logout();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تغيير كلمة المرور: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        'إعادة تعيين كلمة المرور',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: MyColors.mainColor(context),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'أدخل كلمة المرور الجديدة ثم أكدها',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        obscureText: _obscurePassword,
                        enabled: !_isSubmitting && !_isSuccess,
                        validator: _validatePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور الجديدة',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: _isSubmitting || _isSuccess
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          // Re-validate the confirm field when the password
                          // changes so the mismatch check stays in sync.
                          if (_confirmController.text.isNotEmpty) {
                            _formKey.currentState?.validate();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: _obscureConfirm,
                        enabled: !_isSubmitting && !_isSuccess,
                        validator: _validateConfirm,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'تأكيد كلمة المرور',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: _isSubmitting || _isSuccess
                                ? null
                                : () {
                                    setState(() {
                                      _obscureConfirm = !_obscureConfirm;
                                    });
                                  },
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
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
                                  ? 'جاري الحفظ...'
                                  : _isSuccess
                                      ? 'تم بنجاح'
                                      : 'حفظ',
                            ),
                          ),
                        ),
                      ),
                      if (_isSuccess) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'يمكنك الآن تسجيل الدخول بكلمة المرور الجديدة',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
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
    if (msg.contains('expired') || msg.contains('otp')) {
      return 'انتهت صلاحية رابط الاسترداد، أعد المحاولة';
    }
    if (msg.contains('same password') || msg.contains('different')) {
      return 'يجب أن تكون كلمة المرور الجديدة مختلفة عن الحالية';
    }
    if (msg.contains('weak') || msg.contains('short')) {
      return 'كلمة المرور ضعيفة، اختر كلمة مرور أقوى';
    }
    return e.message.isNotEmpty ? e.message : 'فشل المصادقة';
  }
}
