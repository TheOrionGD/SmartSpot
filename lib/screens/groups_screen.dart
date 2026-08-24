import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/family_group.dart';
import '../providers/family_group_provider.dart';
import '../utils/app_theme.dart';

/// Lets the user create local "family/shared" groups and add members by
/// name, so reminders can be tagged as shared with a group. There is no
/// real backend/sync yet (see FamilyGroupProvider) — this is a working
/// frontend for the feature, ready to wire to real auth + sync later.
class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  Future<void> _showCreateGroupDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.group_add_rounded, color: AppColors.primary, size: 32),
        title: const Text('New Group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Family, Roommates'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && context.mounted) {
      await context.read<FamilyGroupProvider>().createGroup(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family & Groups')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: () => _showCreateGroupDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
      ),
      body: Consumer<FamilyGroupProvider>(
        builder: (context, provider, child) {
          if (!provider.isLoaded) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (provider.groups.isEmpty) {
            return _emptyState(context);
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: provider.groups.length,
            itemBuilder: (context, index) => _GroupCard(group: provider.groups[index]),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.diversity_3_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'No groups yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a group to share location reminders with family or '
              'roommates — the first person to arrive marks it done for everyone.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final FamilyGroup group;
  const _GroupCard({required this.group});

  Future<void> _showAddMemberDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 32),
        title: const Text('Add Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter a name, or share the invite code below with them:',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    group.inviteCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: "Member's name"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty && context.mounted) {
      await context.read<FamilyGroupProvider>().addMember(group.id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: AppColors.cardShadow(AppColors.primary, alpha: 0.08),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.group_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '${group.memberNames.length} member(s) · Code: ${group.inviteCode}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600]),
                  onSelected: (value) {
                    if (value == 'delete') {
                      context.read<FamilyGroupProvider>().deleteGroup(group.id);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'delete', child: Text('Delete Group', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            if (group.memberNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.memberNames
                    .map((m) => Chip(
                          label: Text(
                            m,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[100] : const Color(0xFF10131C),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: isDark ? AppColors.surfaceDark : Colors.grey[200],
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                          deleteIconColor: isDark ? Colors.grey[400] : Colors.grey[700],
                          onDeleted: () =>
                              context.read<FamilyGroupProvider>().removeMember(group.id, m),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _showAddMemberDialog(context),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Add Member'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
