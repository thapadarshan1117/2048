/// Localisation keys and their English values.
///
/// The game is localisation-ready: every user-visible string is looked up by
/// key here, never hardcoded at a call site. Adding a language means adding a
/// map and a branch in [AppStrings.lookup] - no widget changes.
///
/// The Flame layer contains no strings at all: it renders numbers, colours and
/// shapes only.
library;

class AppStrings {
  const AppStrings._();

  static const Map<String, String> english = <String, String>{
    // App / navigation
    'app_name': 'MERGE DROP',
    'nav_home': 'Home',
    'nav_levels': 'Levels',
    'nav_daily': 'Daily',
    'nav_profile': 'Profile',
    'nav_settings': 'Settings',
    'nav_shop': 'Shop',
    'nav_stats': 'Statistics',

    // Home
    'home_play': 'Play',
    'home_continue': 'Continue',
    'home_levels': 'Levels',
    'home_daily': 'Daily Challenge',
    'home_infinite': 'Endless',
    'home_shop': 'Shop',
    'home_settings': 'Settings',
    'home_subtitle': 'Drop. Merge. Grow.',
    'home_level_label': 'Level',
    'home_stars_label': 'Stars',
    'home_daily_done': "Today's challenge is complete",

    // Level map
    'levels_title': 'Select Level',
    'levels_chapter': 'Chapter',
    'levels_locked': 'Complete the previous level to unlock',

    // Objectives
    'objective_reach_score': 'Reach {target} points',
    'objective_create_number': 'Create {target} blocks',
    'objective_merge_count': 'Merge {target} times',
    'objective_reach_number': 'Create a {target} block',
    'objective_complete_within_moves': 'Finish within {target} moves',
    'objective_combo_count': 'Make a {target}x chain',
    'objective_progress': '{current} / {target}',
    'objective_in_progress': 'Objective',

    // HUD
    'hud_score': 'Score',
    'hud_moves': 'Moves',
    'hud_best': 'Best',
    'hud_next': 'Next',
    'hud_pause': 'Pause',
    'hud_resume': 'Resume',
    'hud_restart': 'Restart',
    'hud_quit': 'Quit',
    'hud_quit_confirm': 'Leave this level? Your progress on it will be lost.',

    // Boosters
    'booster_undo_name': 'Undo',
    'booster_undo_description': 'Take back your last drop',
    'booster_hammer_name': 'Hammer',
    'booster_hammer_description': 'Remove any single block',
    'booster_shuffle_name': 'Shuffle',
    'booster_shuffle_description': 'Rearrange every block on the board',
    'booster_wildcard_name': 'Wildcard',
    'booster_wildcard_description': 'Turn a block into any value you like',
    'booster_upgrade_name': 'Upgrade',
    'booster_upgrade_description': 'Double the value of one block',
    'booster_use': 'Use',
    'booster_buy': 'Buy',
    'booster_select_block': 'Tap a block to target',
    'booster_reject_none_left': 'You have none left',
    'booster_reject_no_target': 'Nothing to target',
    'booster_reject_not_allowed': 'Not allowed in this level',
    'booster_reject_no_undo': 'Nothing to undo',
    'booster_reject_too_few_blocks': 'Not enough blocks on the board',

    // Drop errors
    'drop_error_none': '',
    'drop_error_invalid_column': 'Pick a column',
    'drop_error_column_full': 'That column is full',
    'drop_error_board_full': 'The board is full',
    'drop_error_session_over': 'This round is over',

    // Result
    'result_level_complete': 'Level Complete',
    'result_level_failed': 'Out of Moves',
    'result_no_moves': 'No Moves Left',
    'result_board_full': 'Board Full',
    'result_score': 'Score',
    'result_best': 'Best',
    'result_next': 'Next Level',
    'result_retry': 'Retry',
    'result_menu': 'Menu',
    'result_continue_ad': 'Continue with an ad',
    'result_double_coins': 'Double coins with an ad',
    'result_coins_earned': '+{count} coins',

    // Daily
    'daily_title': 'Daily Challenge',
    'daily_today': "Today's puzzle",
    'daily_streak': 'Day {day} streak',
    'daily_reward': 'Daily reward',
    'daily_reward_ready': 'Claim {count} coins',
    'daily_reward_claimed': 'Come back tomorrow',
    'daily_play': 'Play daily',
    'daily_completed': 'Completed today',

    // Shop
    'shop_title': 'Shop',
    'shop_coins': 'Coins',
    'shop_remove_ads': 'Remove Ads',
    'shop_remove_ads_desc': 'No interstitials, ever. Rewarded ads stay optional.',
    'shop_remove_ads_owned': 'Purchased',
    'shop_restore': 'Restore purchases',
    'shop_buy': 'Buy',
    'shop_owned': 'Owned',
    'shop_not_enough_coins': 'Not enough coins',
    'shop_pack_small': '500 coins',
    'shop_pack_medium': '1500 coins',
    'shop_pack_large': '5000 coins',
    'shop_coin_packs': 'Coin packs',
    'shop_coin_packs_soon': 'Coin packs are available once purchases are enabled.',
    'shop_reject_not_enough_coins': 'Not enough coins',

    // Settings
    'settings_title': 'Settings',
    'settings_sound': 'Sound effects',
    'settings_music': 'Music',
    'settings_vibration': 'Vibration',
    'settings_notifications': 'Notifications',
    'settings_language': 'Language',
    'settings_privacy': 'Privacy policy',
    'settings_terms': 'Terms of service',
    'settings_restore': 'Restore purchases',
    'settings_remove_ads': 'Remove ads',
    'settings_credits': 'Made with Flutter and Flame',

    // Profile / stats
    'profile_title': 'Profile',
    'profile_levels_completed': 'Levels completed',
    'profile_stars_earned': 'Stars earned',
    'profile_total_score': 'Best score',
    'profile_highest_block': 'Highest block',
    'profile_best_infinite': 'Endless best',
    'profile_daily_done': 'Daily challenges',
    'profile_total_merges': 'Total merges',
    'profile_milestones': 'Achievements',

    // Milestones
    'milestone_first_merge': 'First merge',
    'milestone_reach_128': 'Reach 128',
    'milestone_reach_512': 'Reach 512',
    'milestone_reach_2048': 'Reach 2048',
    'milestone_reach_4096': 'Reach 4096',
    'milestone_complete_10_levels': 'Finish 10 levels',
    'milestone_complete_50_levels': 'Finish 50 levels',
    'milestone_complete_100_levels': 'Finish 100 levels',
    'milestone_earn_100_stars': 'Earn 100 stars',
    'milestone_earn_500_stars': 'Earn 500 stars',
    'milestone_infinite_10000': 'Score 10,000 in endless',
    'milestone_daily_7': 'Finish 7 daily challenges',

    // Chapters
    'chapter_1': 'First Steps',
    'chapter_2': 'Warm Up',
    'chapter_3': 'Pairs',
    'chapter_4': 'Chains',
    'chapter_5': 'Balance',
    'chapter_6': 'Height',
    'chapter_7': 'Pressure',
    'chapter_8': 'Rhythm',
    'chapter_9': 'Narrow',
    'chapter_10': 'Precision',
    'chapter_11': 'Speed',
    'chapter_12': 'Endurance',
    'chapter_13': 'Mastery',
    'chapter_14': 'Summit',
    'chapter_15': 'Beyond',
    'chapter_16': 'Infinity',
    'chapter_17': 'Ascend',
    'chapter_18': 'Apex',
    'chapter_19': 'Legend',
    'chapter_20': 'Finale',

    // Tutorial hints
    'tut_drop': 'Tap a column to drop your first block',
    'tut_merge': 'Drop two equal blocks next to each other to merge them',
    'tut_merge_again': 'Merge again to double the value',
    'tut_chain': 'Chains resolve automatically - keep dropping',
    'tut_boosters': 'Boosters are available when you are stuck',

    // Debug
    'debug_title': 'Debug Tools',
    'debug_simulate': 'Run level simulator',
    'debug_validate': 'Validate levels',
    'debug_regenerate': 'Regenerate catalogue',
    'debug_grant_coins': 'Grant 1000 coins',
    'debug_unlock_all': 'Unlock all levels',
    'debug_clear_save': 'Clear save',
  };

  /// English is the only shipped language in the MVP.
  static Map<String, String> get strings => english;

  /// Looks up [key], substituting `{name}` placeholders from [params].
  ///
  /// An unknown key returns the key itself, which makes missing translations
  /// obvious in development instead of rendering an empty label.
  static String tr(String key, [Map<String, Object?> params = const {}]) {
    var value = strings[key] ?? key;
    if (params.isEmpty) return value;
    params.forEach((name, replacement) {
      value = value.replaceAll('{$name}', '${replacement ?? ''}');
    });
    return value;
  }

  /// True when [key] has a translation.
  static bool exists(String key) => strings.containsKey(key);
}
