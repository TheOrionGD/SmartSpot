import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'main_navigation_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _securityQuestionController = TextEditingController();
  final _securityAnswerController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _securityQuestionController.dispose();
    _securityAnswerController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        securityQuestion: _securityQuestionController.text,
        securityAnswer: _securityAnswerController.text,
      );
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join SmartSpot',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create an account to start setting location-based reminders',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _securityQuestionController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Security Question',
                    prefixIcon: Icon(Icons.help_outline),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a security question'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _securityAnswerController,
                  decoration: const InputDecoration(
                    labelText: 'Security Answer',
                    prefixIcon: Icon(Icons.question_answer_outlined),
                  ),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Please enter your security answer'
                      : null,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _isLoading ? null : AppColors.primaryGradient,
                      color: _isLoading ? Colors.grey[300] : null,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: _isLoading
                          ? []
                          : [
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
                        onTap: _isLoading ? null : _register,
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Create Account',
                                  style: TextStyle(
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
