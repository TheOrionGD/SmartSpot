import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/reminder_provider.dart';
import '../utils/app_theme.dart';
import 'settings_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const List<Map<String, dynamic>> _avatarOptions = [
    {'id': 'person_rounded', 'icon': Icons.person_rounded, 'name': 'Default'},
    {'id': 'face_rounded', 'icon': Icons.face_rounded, 'name': 'Friendly'},
    {'id': 'school_rounded', 'icon': Icons.school_rounded, 'name': 'Student'},
    {'id': 'stars_rounded', 'icon': Icons.stars_rounded, 'name': 'Star'},
    {'id': 'badge_rounded', 'icon': Icons.badge_rounded, 'name': 'Pro'},
  ];

  static IconData _getAvatarIcon(String avatarUrl) {
    for (final option in _avatarOptions) {
      if (option['id'] == avatarUrl) {
        return option['icon'] as IconData;
      }
    }
    return Icons.person_rounded;
  }

  void _showEditProfileModal(BuildContext context, AuthProvider auth) {
    final nameController = TextEditingController(text: auth.name);
    final emailController = TextEditingController(text: auth.email);
    final phoneController = TextEditingController(text: auth.phone);
    final bioController = TextEditingController(text: auth.bio);
    final securityQuestionController = TextEditingController(text: auth.securityQuestion);
    final securityAnswerController = TextEditingController();

    String selectedAvatar = auth.avatarUrl.isNotEmpty ? auth.avatarUrl : 'person_rounded';
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Edit Profile',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        !auth.isLoggedIn
                            ? 'Update your local guest display details.'
                            : 'Update your account display name, email, contact info & security preferences.',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),

                      // Avatar Selection Row
                      Text(
                        'Choose Profile Avatar',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _avatarOptions.map((opt) {
                          final isSelected = selectedAvatar == opt['id'];
                          return InkWell(
                            onTap: () => setModalState(() => selectedAvatar = opt['id'] as String),
                            borderRadius: BorderRadius.circular(24),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.grey[300]!,
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              child: Icon(
                                opt['icon'] as IconData,
                                size: 28,
                                color: isSelected ? AppColors.primary : Colors.grey[600],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Full Name
                      TextFormField(
                        controller: nameController,
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

                      // Email Address
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an email address';
                          }
                          if (!value.contains('@') || !value.contains('.')) {
                            return 'Please enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Phone Number
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number (Optional)',
                          prefixIcon: Icon(Icons.phone_outlined),
                          hintText: '+1 555-0199',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bio / About
                      TextFormField(
                        controller: bioController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Bio / About You (Optional)',
                          prefixIcon: Icon(Icons.info_outline),
                          hintText: 'Share a quick note or status...',
                        ),
                      ),

                      if (auth.isLoggedIn) ...[
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          'Security & Account Recovery',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: securityQuestionController,
                          decoration: const InputDecoration(
                            labelText: 'Security Question',
                            prefixIcon: Icon(Icons.help_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: securityAnswerController,
                          decoration: const InputDecoration(
                            labelText: 'New Security Answer (Leave blank to keep existing)',
                            prefixIcon: Icon(Icons.question_answer_outlined),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setModalState(() => isSubmitting = true);
                                  final messenger = ScaffoldMessenger.of(context);
                                  final navigator = Navigator.of(context);
                                  try {
                                    await auth.updateProfile(
                                      name: nameController.text.trim(),
                                      email: emailController.text.trim(),
                                      phone: phoneController.text.trim(),
                                      bio: bioController.text.trim(),
                                      avatarUrl: selectedAvatar,
                                      securityQuestion: securityQuestionController.text.trim(),
                                      securityAnswer: securityAnswerController.text.trim().isNotEmpty
                                          ? securityAnswerController.text.trim()
                                          : null,
                                    );
                                    navigator.pop();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Profile updated successfully!'),
                                        backgroundColor: AppColors.sage,
                                      ),
                                    );
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to update profile: $e'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showChangePasswordModal(BuildContext context, AuthProvider auth) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Change Password',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enter your current password and a new secure password.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter current password' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(Icons.lock_reset),
                      ),
                      validator: (v) =>
                          v == null || v.length < 6 ? 'New password must be at least 6 characters' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: Icon(Icons.lock_reset),
                      ),
                      validator: (v) =>
                          v != newPasswordController.text ? 'Passwords do not match' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSubmitting = true);
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(context);
                                try {
                                  await auth.changePassword(
                                    currentPassword: currentPasswordController.text,
                                    newPassword: newPasswordController.text,
                                  );
                                  navigator.pop();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Password changed successfully!'),
                                      backgroundColor: AppColors.sage,
                                    ),
                                  );
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Failed: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Update Password'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final stats = context.watch<ReminderProvider>().statistics;
    final avatarIcon = _getAvatarIcon(auth.avatarUrl);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: auth.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(avatarIcon, size: 48, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        auth.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        auth.email,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      if (auth.phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              auth.phone,
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                      if (auth.bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '“${auth.bio}”',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: auth.isLoggedIn
                              ? AppColors.sage.withValues(alpha: 0.15)
                              : Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: auth.isLoggedIn
                                ? AppColors.sage.withValues(alpha: 0.4)
                                : Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              auth.isLoggedIn ? Icons.verified_user_rounded : Icons.person_outline,
                              size: 16,
                              color: auth.isLoggedIn ? AppColors.sage : Colors.amber[800],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              auth.isLoggedIn ? 'Registered Account' : 'Guest Mode (Offline)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: auth.isLoggedIn ? AppColors.sage : Colors.amber[900],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _miniStat(context, '${stats['total'] ?? 0}', 'Total'),
                    ),
                    Expanded(
                      child: _miniStat(context, '${stats['completed'] ?? 0}', 'Completed'),
                    ),
                    Expanded(
                      child: _miniStat(context, '${stats['pending'] ?? 0}', 'Pending'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                        title: const Text('Edit Profile'),
                        subtitle: const Text('Full profile info, contact & security'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showEditProfileModal(context, auth),
                      ),
                      if (auth.isLoggedIn) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lock_reset, color: AppColors.primary),
                          title: const Text('Change Password'),
                          subtitle: const Text('Update your account security password'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showChangePasswordModal(context, auth),
                        ),
                      ],
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.settings_outlined, color: AppColors.primary),
                        title: const Text('Settings'),
                        subtitle: const Text('Theme, quiet hours & notifications'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.help_outline, color: AppColors.primary),
                        title: const Text('Help & Support'),
                        subtitle: const Text('App guide and backend setup'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'SmartSpot',
                            applicationVersion: '1.0.0',
                            applicationLegalese: 'Location-Based Smart Reminder Application',
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: !auth.isLoggedIn
                      ? ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Sign In / Create Account'),
                        )
                      : OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            await auth.logout();
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Logout'),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _miniStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
