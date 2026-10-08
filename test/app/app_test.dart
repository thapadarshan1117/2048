import 'package:flutter_test/flutter_test.dart';
import 'package:merge_drop/app/localization/app_strings.dart';
import 'package:merge_drop/app/theme/app_colors.dart';
import 'package:merge_drop/app/theme/app_typography.dart';
import 'package:merge_drop/core/constants/app_config.dart';
import 'package:merge_drop/core/constants/game_constants.dart';
import 'package:merge_drop/core/widgets/debug_panel.dart';

void main() {
  group('AppStrings', () {
    test('every key used by the shipped code has an English value', () {
      const required = <String>[
        'app_name',
        'home_play',
        'home_continue',
        'home_levels',
        'home_daily',
        'home_infinite',
        'levels_title',
        'hud_score',
        'hud_moves',
        'hud_best',
        'hud_pause',
        'result_level_complete',
        'result_level_failed',
        'result_next',
        'result_retry',
        'result_menu',
        'shop_title',
        'settings_title',
        'profile_title',
        'daily_title',
        'booster_undo_name',
        'booster_hammer_name',
        'booster_shuffle_name',
        'objective_reach_score',
        'objective_reach_number',
        'objective_create_number',
        'objective_merge_count',
        'objective_combo_count',
        'objective_complete_within_moves',
        'debug_title',
      ];
      for (final key in required) {
        expect(AppStrings.exists(key), isTrue, reason: 'missing key $key');
        expect(AppStrings.tr(key), isNotEmpty, reason: 'empty value for $key');
      }
    });

    test('an unknown key returns the key itself', () {
      expect(AppStrings.tr('definitely_not_a_key'), 'definitely_not_a_key');
    });

    test('placeholders are substituted', () {
      expect(
        AppStrings.tr('objective_reach_score', <String, Object?>{'target': 500}),
        'Reach 500 points',
      );
      expect(
        AppStrings.tr('daily_reward_ready', <String, Object?>{'count': 20}),
        contains('20'),
      );
    });

    test('every chapter and milestone key exists', () {
      for (var chapter = 1; chapter <= 20; chapter++) {
        expect(AppStrings.exists('chapter_$chapter'), isTrue);
      }
      for (final key in <String>[
        'milestone_first_merge',
        'milestone_reach_128',
        'milestone_reach_2048',
        'milestone_complete_100_levels',
      ]) {
        expect(AppStrings.exists(key), isTrue);
      }
    });
  });

  group('design system', () {
    test('the block ramp covers every renderable value', () {
      for (var exponent = 1; exponent <= 13; exponent++) {
        final value = 1 << exponent;
        expect(AppColors.blockColor(value), isNotNull);
      }
      expect(AppColors.blockRamp.length, 13);
      expect(AppColors.chapterThemes.length, 20);
    });

    test('chapter themes are addressed by chapter id', () {
      expect(AppColors.chapterTheme(1), AppColors.chapterThemes.first);
      expect(AppColors.chapterTheme(21), AppColors.chapterThemes.first);
      expect(AppColors.chapterTheme(20), AppColors.chapterThemes.last);
    });

    test('typography exposes a complete scale', () {
      expect(AppTypography.displayLarge.fontSize, greaterThan(0));
      expect(
        AppTypography.body.fontSize,
        lessThan(AppTypography.displayLarge.fontSize!),
      );
      expect(AppTypography.number(20).fontSize, 20);
    });
  });

  group('AppConfig', () {
    test('debug tools are compiled out of release builds', () {
      // In a `flutter test` run assertions are enabled, so `isRelease` is false
      // and the debug panel is gated purely on the DEBUG_TOOLS dart-define,
      // which defaults to false.
      expect(AppConfig.debugTools, isFalse);
      expect(AppConfig.showDebugTools, isFalse);
      expect(DebugPanel.available, isFalse);
      expect(debugToolsCompiledOut, isTrue);
    });

    test('ad unit ids default to Google public test ids', () {
      expect(AppConfig.admobAppId, contains('3940256099942544'));
      expect(AppConfig.rewardedAdUnitId, contains('3940256099942544'));
      expect(AppConfig.interstitialAdUnitId, contains('3940256099942544'));
    });
  });

  group('GameConstants', () {
    test('board and progression constants match the design', () {
      expect(GameConstants.defaultRows, 12);
      expect(GameConstants.defaultColumns, 6);
      expect(GameConstants.levelsPerChapter, 25);
      expect(GameConstants.totalLevels, 500);
      expect(GameConstants.interstitialEveryNLevels, 4);
      expect(GameConstants.maxComboStep, 9);
    });

    test('starting boosters are the three shipped ones', () {
      expect(
        GameConstants.startingBoosters.keys.toSet(),
        <String>{'undo', 'hammer', 'shuffle'},
      );
      expect(
        GameConstants.boosterPrices.keys,
        containsAll(<String>['undo', 'hammer', 'shuffle']),
      );
    });
  });
}
