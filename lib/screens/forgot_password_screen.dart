import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _answerController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _securityQuestion;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _answerController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_securityQuestion == null) {
        final question = await AuthService.instance.getSecurityQuestion(_emailController.text);
        if (mounted) setState(() => _securityQuestion = question);
      } else {
        await AuthService.instance.resetPassword(
          email: _emailController.text,
          securityAnswer: _answerController.text,
          newPassword: _newPasswordController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully. You can now sign in.')),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _buildFormState(context),
        ),
      ),
    );
  }

  Widget _buildFormState(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_reset_rounded, size: 34, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text(
            'Forgot your password?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your email, answer your security question, and choose a new password.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          if (_securityQuestion != null) ...[
            const SizedBox(height: 16),
            Text(_securityQuestion!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _answerController,
              decoration: const InputDecoration(
                labelText: 'Your Answer',
                prefixIcon: Icon(Icons.question_answer_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Please enter your answer'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) => value == null || value.length < 6
                  ? 'Password must be at least 6 characters'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) => value != _newPasswordController.text
                  ? 'Passwords do not match'
                  : null,
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _isLoading ? null : _sendResetLink,
                  child: Center(
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                      _securityQuestion == null ? 'Find Security Question' : 'Reset Password',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
