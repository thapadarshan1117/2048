import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_strings.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/widgets/gradient_scaffold.dart';
import '../cubit/levels_cubit.dart';
import '../widgets/level_node.dart';

/// Scrollable chapter-by-chapter level map.
class LevelsPage extends StatefulWidget {
  const LevelsPage({super.key});

  @override
  State<LevelsPage> createState() => _LevelsPageState();
}

class _LevelsPageState extends State<LevelsPage> {
  late final LevelsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = LevelsCubit(
      levelRepository: ServiceLocator.instance.levelRepository,
      progressRepository: ServiceLocator.instance.progressRepository,
    );
    _cubit.load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: AppBar(
        leading: IconActionButton(
          icon: Icons.arrow_back_rounded,
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.tr('levels_title')),
      ),
      child: StreamBuilder<LevelsState>(
        stream: _cubit.stream,
        initialData: _cubit.state,
        builder: (context, snapshot) {
          final state = snapshot.data ?? _cubit.state;
          if (state.chapters.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return _ChapterList(state: state, onLevelTap: _openLevel);
        },
      ),
    );
  }

  void _openLevel(int levelId) {
    context.push(AppRoutes.game, extra: <String, Object?>{
      'levelId': levelId,
      'mode': 'level',
    });
  }
}

class _ChapterList extends StatelessWidget {
  const _ChapterList({required this.state, required this.onLevelTap});

  final LevelsState state;
  final void Function(int levelId) onLevelTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      itemCount: state.chapters.length,
      itemBuilder: (context, index) {
        final chapter = state.chapters[index];
        return _ChapterCard(chapter: chapter, onLevelTap: onLevelTap);
      },
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter, required this.onLevelTap});

  final ChapterData chapter;
  final void Function(int levelId) onLevelTap;

  @override
  Widget build(BuildContext context) {
    final theme = AppColors.chapterTheme(chapter.id);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            theme.first.withValues(alpha: 0.18),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.first.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  AppStrings.tr('levels_chapter') +
                      ' ${chapter.id} - ' +
                      AppStrings.tr(chapter.nameKey),
                  style: AppTypography.title,
                ),
              ),
              Text(
                '${chapter.starsEarned}/${chapter.levels.length * 3}',
                style: AppTypography.label
                    .copyWith(color: AppColors.starFilled),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.md,
            children: chapter.levels
                .map((node) => LevelNode(
                      levelId: node.levelId,
                      progress: node.progress,
                      unlocked: node.unlocked,
                      isCurrent: node.isCurrent,
                      onTap: () => onLevelTap(node.levelId),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
