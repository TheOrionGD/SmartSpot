import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reminder.dart';
import '../models/reminder_condition.dart';
import '../models/favorite_location.dart';
import '../providers/reminder_provider.dart';
import '../providers/favorites_provider.dart';
import '../utils/permission_helper.dart';
import '../utils/app_theme.dart';
import '../widgets/multi_condition_builder.dart';
import '../widgets/voice_input_sheet.dart';
import '../utils/app_motion.dart';
import 'map_screen.dart';
import 'favorites_screen.dart';

class AddReminderScreen extends StatefulWidget {
  /// Pass an existing reminder to edit it; leave null to create a new one.
  final Reminder? reminder;

  const AddReminderScreen({super.key, this.reminder});

  bool get isEditing => reminder != null;

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController titleController;
  late final TextEditingController descriptionController;

  ReminderCategory category = ReminderCategory.shopping;
  ReminderPriority priority = ReminderPriority.medium;
  bool notifyOnEnter = true;
  bool notifyOnExit = false;
  bool routeAware = false;
  bool weatherAware = false;
  double radius = 200;
  DateTime? dueDate;
  bool _saveAsFavorite = false;
  ReminderRepeatType repeatType = ReminderRepeatType.once;
  Set<int> repeatDays = {};

  // Intelligent-engine fields
  List<ReminderCondition> conditions = [];
  bool adaptiveRadius = false;
  ReminderPriority? _suggestedPriority;

  double? _latitude;
  double? _longitude;
  String? _locationName;

  bool _isSaving = false;
  bool _shakeForm = false;

  @override
  void initState() {
    super.initState();
    final r = widget.reminder;
    titleController = TextEditingController(text: r?.title ?? '');
    descriptionController = TextEditingController(text: r?.description ?? '');
    if (r != null) {
      category = r.category;
      priority = r.priority;
      notifyOnEnter = r.notifyOnEnter;
      notifyOnExit = r.notifyOnExit;
      routeAware = r.routeAware;
      weatherAware = r.weatherAware;
      repeatType = r.repeatType;
      repeatDays = Set<int>.from(r.repeatDays);
      radius = r.radius;
      dueDate = r.dueDate;
      _latitude = r.latitude;
      _longitude = r.longitude;
      _locationName = r.locationName;
      conditions = List<ReminderCondition>.from(r.conditions);
      adaptiveRadius = r.adaptiveRadius;
    }
    titleController.addListener(_updateSuggestedPriority);
  }

  // Feature 7 — Intelligent Reminder Priority: recompute a suggestion as
  // the user types, without overriding a priority they've picked manually.
  void _updateSuggestedPriority() {
    if (titleController.text.trim().isEmpty) {
      setState(() => _suggestedPriority = null);
      return;
    }
    final suggestion = context.read<ReminderProvider>().suggestPriority(
          titleController.text,
          description: descriptionController.text,
          dueDate: dueDate,
        );
    if (suggestion != _suggestedPriority) {
      setState(() => _suggestedPriority = suggestion);
    }
  }

  Future<void> _openVoiceInput() async {
    final parsed = await VoiceInputSheet.show(context);
    if (parsed == null) return;
    setState(() {
      titleController.text = parsed.title;
      if (parsed.dueDate != null) dueDate = parsed.dueDate;
      if (parsed.category != null) category = parsed.category!;
      if (parsed.locationHint != null && _locationName == null) {
        // Just a hint for the user to search for on the map — voice
        // parsing can't resolve free-text place names to coordinates
        // offline, so it doesn't silently guess a location.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.grey[900],
            content: Text('Now pick "${parsed.locationHint}" on the map below'),
          ),
        );
      }
    });
    _updateSuggestedPriority();
  }

  @override
  void dispose() {
    titleController.removeListener(_updateSuggestedPriority);
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _locationName = result.address;
      });
    }
  }

  Future<void> _pickFromFavorites() async {
    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );

    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _locationName = result.address;
        _saveAsFavorite = false; // already a favorite
      });
    }
  }

  Future<void> _onNotifyToggleChanged(bool value, {required bool isEnter}) async {
    if (value) {
      final granted = await PermissionHelper.requestNotificationPermission(context);
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              content: const Text(
                'Notification permission is needed for this reminder to alert you',
              ),
            ),
          );
        }
        return; // leave the toggle off
      }
    }
    setState(() {
      if (isEnter) {
        notifyOnEnter = value;
      } else {
        notifyOnExit = value;
      }
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => dueDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _shakeForm = true);
      return;
    }

    if (_latitude == null || _longitude == null) {
      setState(() => _shakeForm = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: const Text('Please select a location for this reminder'),
        ),
      );
      return;
    }

    if ((repeatType == ReminderRepeatType.weekly ||
            repeatType == ReminderRepeatType.custom) &&
        repeatDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: const Text('Please pick at least one day for this repeat schedule'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<ReminderProvider>();
    final favoritesProvider = context.read<FavoritesProvider>();

    try {
      if (widget.isEditing) {
        final updated = widget.reminder!.copyWith(
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          latitude: _latitude,
          longitude: _longitude,
          locationName: _locationName,
          radius: radius,
          category: category,
          priority: priority,
          notifyOnEnter: notifyOnEnter,
          notifyOnExit: notifyOnExit,
          routeAware: routeAware,
          weatherAware: weatherAware,
          conditions: conditions,
          adaptiveRadius: adaptiveRadius,
          repeatType: repeatType,
          repeatDays: repeatDays,
          dueDate: dueDate,
        );
        await provider.updateReminder(updated);
      } else {
        final newReminder = Reminder(
          id: '',
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          latitude: _latitude!,
          longitude: _longitude!,
          locationName: _locationName,
          radius: radius,
          category: category,
          priority: priority,
          createdAt: DateTime.now(),
          dueDate: dueDate,
          notifyOnEnter: notifyOnEnter,
          notifyOnExit: notifyOnExit,
          routeAware: routeAware,
          weatherAware: weatherAware,
          conditions: conditions,
          adaptiveRadius: adaptiveRadius,
          repeatType: repeatType,
          repeatDays: repeatDays,
        );
        await provider.addReminder(newReminder);
      }

      if (_saveAsFavorite && _latitude != null && _longitude != null) {
        favoritesProvider.addFavorite(
          FavoriteLocation(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            label: titleController.text.trim(),
            latitude: _latitude!,
            longitude: _longitude!,
            address: _locationName,
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Text(widget.isEditing ? 'Reminder updated' : 'Reminder created'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            content: Text('Something went wrong: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _categoryLabel(ReminderCategory c) {
    final name = c.toString().split('.').last;
    return name[0].toUpperCase() + name.substring(1);
  }

  String _categoryEmoji(ReminderCategory c) {
    return Reminder(
      id: '',
      title: '',
      latitude: 0,
      longitude: 0,
      category: c,
      createdAt: DateTime.now(),
    ).categoryEmoji;
  }

  Color _priorityColor(ReminderPriority p) {
    switch (p) {
      case ReminderPriority.low:
        return AppColors.info;
      case ReminderPriority.medium:
        return AppColors.warning;
      case ReminderPriority.high:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Reminder' : 'Add Reminder'),
        actions: [
          if (widget.isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Text(
                    'Editing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ErrorShakeWidget(
        shake: _shakeForm,
        onShakeComplete: () => setState(() => _shakeForm = false),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _sectionHeader(context, icon: Icons.edit_note_rounded, title: 'Details'),
                  ),
                  _goldOutlineButton(
                    icon: Icons.mic_rounded,
                    label: 'Voice / Quick Add',
                    onPressed: _openVoiceInput,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _premiumCard(
                isDark,
                child: Column(
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Reminder Title',
                        prefixIcon: Icon(Icons.title_rounded, color: AppColors.primary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 3,
                      onChanged: (_) => _updateSuggestedPriority(),
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.notes_rounded, color: AppColors.primary),
                        ),
                      ),
                    ),
                    if (_suggestedPriority != null && _suggestedPriority != priority) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ActionChip(
                          avatar: const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.primary),
                          label: Text(
                            'Suggested: ${_suggestedPriority.toString().split('.').last} priority',
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                          onPressed: () => setState(() => priority = _suggestedPriority!),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _sectionHeader(context, icon: Icons.tune_rounded, title: 'Category & Priority'),
              const SizedBox(height: 12),
              _premiumCard(
                isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<ReminderCategory>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                      ),
                      items: ReminderCategory.values
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text('${_categoryEmoji(c)}  ${_categoryLabel(c)}'),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => category = value!),
                    ),
                    const SizedBox(height: 20),
                    Text('Priority', style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 10),
                    Row(
                      children: ReminderPriority.values.map((p) {
                        final selected = priority == p;
                        final color = _priorityColor(p);
                        final label = p.toString().split('.').last;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => priority = p),
                            child: Container(
                              margin: EdgeInsets.only(
                                right: p != ReminderPriority.values.last ? 8 : 0,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                gradient: selected ? AppColors.softGradient(color) : null,
                                color: selected ? null : color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected ? color : color.withValues(alpha: 0.3),
                                  width: selected ? 0 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label[0].toUpperCase() + label.substring(1),
                                style: TextStyle(
                                  color: selected ? Colors.white : color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              _sectionHeader(context, icon: Icons.event_rounded, title: 'Due Date'),
              const SizedBox(height: 12),
              _premiumCard(
                isDark,
                padding: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _pickDueDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        _goldIconBadge(Icons.calendar_today_rounded),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            dueDate == null
                                ? 'No due date set'
                                : '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionHeader(context, icon: Icons.location_on_rounded, title: 'Location'),
                  TextButton.icon(
                    onPressed: _pickFromFavorites,
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    icon: const Icon(Icons.star_rounded, size: 18),
                    label: const Text('From Favorites'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _premiumCard(
                isDark,
                child: Row(
                  children: [
                    _goldIconBadge(Icons.location_on_rounded),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _locationName ?? 'No location selected',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                          ),
                          if (_latitude != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _goldOutlineButton(
                      icon: Icons.map_rounded,
                      label: 'Select',
                      onPressed: _pickLocation,
                    ),
                  ],
                ),
              ),
              if (_locationName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primary,
                    title: const Text('Save this place as a favorite'),
                    value: _saveAsFavorite,
                    onChanged: (value) => setState(() => _saveAsFavorite = value ?? false),
                  ),
                ),

              const SizedBox(height: 20),
              _sectionHeader(context, icon: Icons.radar_rounded, title: 'Geofence Radius'),
              const SizedBox(height: 12),
              _premiumCard(
                isDark,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Trigger distance',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Text(
                            '${radius.toInt()} m',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        thumbColor: AppColors.primary,
                        overlayColor: AppColors.primary.withValues(alpha: 0.15),
                        inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: radius,
                        min: 50,
                        max: 1000,
                        divisions: 19,
                        label: '${radius.toInt()} m',
                        onChanged: adaptiveRadius ? null : (value) => setState(() => radius = value),
                      ),
                    ),
                    const Divider(height: 24),
                    _premiumSwitch(
                      icon: Icons.speed_rounded,
                      color: AppColors.info,
                      title: 'Adaptive radius',
                      subtitle: 'Auto-widen the trigger distance based on how fast you\'re moving (walking/cycling/driving)',
                      value: adaptiveRadius,
                      onChanged: (value) => setState(() => adaptiveRadius = value),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _sectionHeader(context, icon: Icons.notifications_active_rounded, title: 'Notifications'),
              const SizedBox(height: 12),
              _premiumCard(
                isDark,
                child: Column(
                  children: [
                    _premiumSwitch(
                      icon: Icons.login_rounded,
                      color: AppColors.success,
                      title: 'Notify when I arrive',
                      value: notifyOnEnter,
                      onChanged: (value) => _onNotifyToggleChanged(value, isEnter: true),
                    ),
                    const Divider(height: 24),
                    _premiumSwitch(
                      icon: Icons.logout_rounded,
                      color: AppColors.error,
                      title: 'Notify when I leave',
                      value: notifyOnExit,
                      onChanged: (value) => _onNotifyToggleChanged(value, isEnter: false),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _sectionHeader(context, icon: Icons.repeat_rounded, title: 'Repeat'),
              const SizedBox(height: 12),
              _premiumCard(
                isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ReminderRepeatType.values.map((type) {
                        final selected = repeatType == type;
                        return ChoiceChip(
                          label: Text(_repeatTypeLabel(type)),
                          selected: selected,
                          showCheckmark: false,
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: selected
                                ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                                : (isDark ? Colors.grey[200] : const Color(0xFF2D3142)),
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                          onSelected: (_) => setState(() {
                            repeatType = type;
                            // A day selection only makes sense for
                            // weekly/custom — clear it for the other types
                            // so a stale selection can't linger unseen.
                            if (type != ReminderRepeatType.weekly &&
                                type != ReminderRepeatType.custom) {
                              repeatDays = {};
                            }
                          }),
                        );
                      }).toList(),
                    ),
                    if (repeatType == ReminderRepeatType.weekly ||
                        repeatType == ReminderRepeatType.custom) ...[
                      const SizedBox(height: 14),
                      Text(
                        repeatType == ReminderRepeatType.weekly
                            ? 'Pick a day'
                            : 'Pick one or more days',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(7, (i) {
                          final day = i + 1; // Monday = 1 ... Sunday = 7
                          final selected = repeatDays.contains(day);
                          return FilterChip(
                            label: Text(_dayShortName(day)),
                            selected: selected,
                            showCheckmark: false,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: selected
                                  ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                                  : (isDark ? Colors.grey[200] : const Color(0xFF2D3142)),
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                            onSelected: (isSelected) => setState(() {
                              if (repeatType == ReminderRepeatType.weekly) {
                                // Weekly means exactly one day — selecting
                                // a new one replaces the old selection.
                                repeatDays = isSelected ? {day} : {};
                              } else if (isSelected) {
                                repeatDays.add(day);
                              } else {
                                repeatDays.remove(day);
                              }
                            }),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _sectionHeader(context, icon: Icons.auto_awesome_rounded, title: 'Smart Reminder Options'),
              const SizedBox(height: 12),
              _premiumCard(
                isDark,
                child: Column(
                  children: [
                    _premiumSwitch(
                      icon: Icons.alt_route_rounded,
                      color: AppColors.info,
                      title: 'Route-aware',
                      subtitle: "Only notify if you're heading toward this place",
                      value: routeAware,
                      onChanged: (value) => setState(() => routeAware = value),
                    ),
                    const Divider(height: 24),
                    _premiumSwitch(
                      icon: Icons.cloud_rounded,
                      color: AppColors.infoAlt,
                      title: 'Weather-aware',
                      subtitle: 'Skip or delay outdoor reminders in bad weather',
                      value: weatherAware,
                      onChanged: (value) => setState(() => weatherAware = value),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              _sectionHeader(context, icon: Icons.link_rounded, title: 'Multi-Condition Rules'),
              const SizedBox(height: 4),
              Text(
                'Only notify when ALL of these are also true (in addition to the geofence)',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),
              _premiumCard(
                isDark,
                child: MultiConditionBuilder(
                  conditions: conditions,
                  onChanged: (updated) => setState(() => conditions = updated),
                ),
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _isSaving ? null : AppColors.primaryGradient,
                    color: _isSaving ? Colors.grey[300] : null,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: _isSaving
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _isSaving ? null : _save,
                      child: Center(
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.isEditing ? 'Update Reminder' : 'Save Reminder',
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
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
}

  // ---- Reusable premium UI helpers ----

  String _repeatTypeLabel(ReminderRepeatType type) {
    switch (type) {
      case ReminderRepeatType.once:
        return 'Once';
      case ReminderRepeatType.daily:
        return 'Daily';
      case ReminderRepeatType.weekdays:
        return 'Weekdays';
      case ReminderRepeatType.weekends:
        return 'Weekends';
      case ReminderRepeatType.weekly:
        return 'Weekly';
      case ReminderRepeatType.custom:
        return 'Custom';
    }
  }

  String _dayShortName(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1) % 7];
  }

  Widget _sectionHeader(BuildContext context, {required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 15),
        ),
      ],
    );
  }

  Widget _premiumCard(bool isDark, {required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _goldIconBadge(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _goldOutlineButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }

  Widget _premiumSwitch({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          activeTrackColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
