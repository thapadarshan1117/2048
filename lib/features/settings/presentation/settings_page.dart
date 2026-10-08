import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/localization/app_strings.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/services/purchase_service.dart';
import '../../../core/widgets/game_button.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../core/widgets/icon_action_button.dart';
import '../domain/app_settings.dart';

/// Settings screen.
///
/// Every toggle is persisted immediately; there is no "save" button to forget.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettings _settings;
  final ServiceLocator _locator = ServiceLocator.instance;

  @override
  void initState() {
    super.initState();
    _settings = _locator.settingsRepository.read();
  }

  void _update(AppSettings updated) {
    setState(() => _settings = updated);
    _locator.settingsRepository.write(updated);
    _locator.audio.setSoundEnabled(updated.soundEnabled);
    _locator.audio.setMusicEnabled(updated.musicEnabled);
    _locator.haptics.setEnabled(updated.vibrationEnabled);
    _locator.ads.setAdsRemoved(updated.removeAdsPurchased);
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        leading: IconActionButton(
          icon: Icons.arrow_back_rounded,
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.tr('settings_title')),
      ),
      child: ListView(
        children: <Widget>[
          _ToggleRow(
            label: AppStrings.tr('settings_sound'),
            icon: Icons.volume_up_rounded,
            value: _settings.soundEnabled,
            onChanged: (value) =>
                _update(_settings.copyWith(soundEnabled: value)),
          ),
          _ToggleRow(
            label: AppStrings.tr('settings_music'),
            icon: Icons.music_note_rounded,
            value: _settings.musicEnabled,
            onChanged: (value) =>
                _update(_settings.copyWith(musicEnabled: value)),
          ),
          _ToggleRow(
            label: AppStrings.tr('settings_vibration'),
            icon: Icons.vibration_rounded,
            value: _settings.vibrationEnabled,
            onChanged: (value) =>
                _update(_settings.copyWith(vibrationEnabled: value)),
          ),
          _ToggleRow(
            label: AppStrings.tr('settings_notifications'),
            icon: Icons.notifications_rounded,
            value: _settings.notificationsEnabled,
            onChanged: (value) =>
                _update(_settings.copyWith(notificationsEnabled: value)),
          ),
          _ToggleRow(
            label: AppStrings.tr('settings_remove_ads'),
            icon: Icons.block_rounded,
            value: _settings.removeAdsPurchased,
            onChanged: (value) =>
                _update(_settings.copyWith(removeAdsPurchased: value)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.tr('settings_language'), style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: AppLanguage.values
                .map((language) => _LanguageChip(
                      language: language,
                      selected: _settings.language == language,
                      onTap: () =>
                          _update(_settings.copyWith(language: language)),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          GameButton(
            label: AppStrings.tr('settings_privacy'),
            variant: GameButtonVariant.ghost,
            onPressed: () => _showPolicy('privacy'),
          ),
          const SizedBox(height: AppSpacing.sm),
          GameButton(
            label: AppStrings.tr('settings_terms'),
            variant: GameButtonVariant.ghost,
            onPressed: () => _showPolicy('terms'),
          ),
          const SizedBox(height: AppSpacing.sm),
          GameButton(
            label: AppStrings.tr('settings_restore'),
            variant: GameButtonVariant.ghost,
            onPressed: () => _locator.purchases.restorePurchases(),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              AppStrings.tr('settings_credits'),
              style: AppTypography.caption,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  void _showPolicy(String kind) {
    final title = kind == 'privacy'
        ? AppStrings.tr('settings_privacy')
        : AppStrings.tr('settings_terms');
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(title, style: AppTypography.title),
        content: Text(
          kind == 'privacy'
              ? 'MERGE DROP does not collect personal information. Gameplay '
                  'statistics are stored on your device only. Anonymous crash '
                  'reports and analytics are used to fix bugs, and can be '
                  'disabled by turning off notifications.'
              : 'MERGE DROP is provided as-is. All game content is original '
                  'work created for this game.',
          style: AppTypography.body,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTypography.bodyStrong)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceDim,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          language.label,
          style: AppTypography.label.copyWith(
            color: selected ? AppColors.textOnAccent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
