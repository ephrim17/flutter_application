import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/constants.dart';
import 'package:flutter_application/church_app/models/church_model.dart';
import 'package:flutter_application/church_app/models/learning_module_models.dart';
import 'package:flutter_application/church_app/screens/super_admin/learning_modules_admin_screen.dart';
import 'package:flutter_application/church_app/services/learning_module_repository.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_popup_menu.dart';

class ChurchLearningSetupScreen extends StatelessWidget {
  const ChurchLearningSetupScreen({
    super.key,
    required this.church,
    required this.repository,
  });

  final Church church;
  final LearningModuleRepository repository;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.t('learning.setup_title'))),
        body: StreamBuilder<ChurchLearningConfig>(
          stream: repository.watchChurchConfig(church.id),
          builder: (context, configSnapshot) {
            if (!configSnapshot.hasData) {
              return const Center(child: AppLoadingIndicator());
            }
            return StreamBuilder<List<LearningModule>>(
              stream: repository.watchAllModules(),
              builder: (context, globalSnapshot) {
                if (!globalSnapshot.hasData) {
                  return const Center(child: AppLoadingIndicator());
                }
                return StreamBuilder<List<LearningModule>>(
                  stream: repository.watchChurchModules(church.id),
                  builder: (context, churchSnapshot) {
                    if (!churchSnapshot.hasData) {
                      return const Center(child: AppLoadingIndicator());
                    }
                    return _SetupBody(
                      church: church,
                      repository: repository,
                      config: configSnapshot.data!,
                      globalModules: globalSnapshot.data!,
                      churchModules: churchSnapshot.data!,
                    );
                  },
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LearningModuleEditorScreen(
                repository: repository,
                churchId: church.id,
              ),
            ),
          ),
          icon: const Icon(Icons.add_rounded),
          label: Text(context.t('learning.add_church_module')),
        ),
      );
}

class _SetupBody extends StatelessWidget {
  const _SetupBody({
    required this.church,
    required this.repository,
    required this.config,
    required this.globalModules,
    required this.churchModules,
  });

  final Church church;
  final LearningModuleRepository repository;
  final ChurchLearningConfig config;
  final List<LearningModule> globalModules;
  final List<LearningModule> churchModules;

  @override
  Widget build(BuildContext context) {
    final customBySource = <String, LearningModule>{
      for (final module in churchModules)
        if (module.sourceModuleId.isNotEmpty) module.sourceModuleId: module,
    };
    final churchOnly = churchModules
        .where((module) => module.sourceModuleId.isEmpty)
        .toList(growable: false);
    final resolved = resolveChurchLearningModules(
      config: config,
      globalModules: globalModules,
      churchModules: churchModules,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Text(
          church.name,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(context.t('learning.setup_subtitle')),
        const SizedBox(height: 18),
        Container(
          decoration: carouselBoxDecoration(context),
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: Text(context.t('learning.enable_for_church')),
                subtitle: Text(context.t('learning.enable_for_church_hint')),
                value: config.enabled,
                onChanged: (value) => _saveConfig(
                  context,
                  ChurchLearningConfig(
                    enabled: value,
                    inheritGlobalModules: config.inheritGlobalModules,
                    hiddenGlobalModuleIds: config.hiddenGlobalModuleIds,
                    moduleOrder: config.moduleOrder,
                  ),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                title: Text(context.t('learning.include_global_modules')),
                subtitle:
                    Text(context.t('learning.include_global_modules_hint')),
                value: config.inheritGlobalModules,
                onChanged: config.enabled
                    ? (value) => _saveConfig(
                          context,
                          ChurchLearningConfig(
                            enabled: config.enabled,
                            inheritGlobalModules: value,
                            hiddenGlobalModuleIds: config.hiddenGlobalModuleIds,
                            moduleOrder: config.moduleOrder,
                          ),
                        )
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _SectionTitle(
          title: context.t('learning.global_catalogue'),
          subtitle: context.t('learning.global_catalogue_hint'),
        ),
        const SizedBox(height: 10),
        if (globalModules.isEmpty)
          _EmptyCard(text: context.t('learning.global_catalogue_empty'))
        else
          for (final global in globalModules) ...[
            _GlobalModuleTile(
              global: global,
              customized: customBySource[global.id],
              visible: config.inheritGlobalModules &&
                  !config.hiddenGlobalModuleIds.contains(global.id),
              controlsEnabled: config.enabled && config.inheritGlobalModules,
              onVisibilityChanged: (visible) =>
                  _setGlobalVisibility(context, global.id, visible),
              onCustomize: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LearningModuleEditorScreen(
                    repository: repository,
                    churchId: church.id,
                    module: customBySource[global.id] ?? global,
                    sourceModuleId: global.id,
                  ),
                ),
              ),
              onRevert: customBySource[global.id] == null
                  ? null
                  : () => _confirmRevert(
                        context,
                        customBySource[global.id]!,
                      ),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 22),
        _SectionTitle(
          title: context.t('learning.church_only_modules'),
          subtitle: context.t('learning.church_only_modules_hint'),
        ),
        const SizedBox(height: 10),
        if (churchOnly.isEmpty)
          _EmptyCard(text: context.t('learning.church_only_empty'))
        else
          for (final module in churchOnly) ...[
            _ChurchModuleTile(
              module: module,
              onEdit: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LearningModuleEditorScreen(
                    repository: repository,
                    churchId: church.id,
                    module: module,
                  ),
                ),
              ),
              onDelete: () => _confirmDelete(context, module),
            ),
            const SizedBox(height: 10),
          ],
        if (resolved.length > 1) ...[
          const SizedBox(height: 22),
          _SectionTitle(
            title: context.t('learning.church_module_order'),
            subtitle: context.t('learning.church_module_order_hint'),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < resolved.length; index++) ...[
            _OrderTile(
              index: index,
              module: resolved[index],
              onMoveUp:
                  index == 0 ? null : () => _move(context, resolved, index, -1),
              onMoveDown: index == resolved.length - 1
                  ? null
                  : () => _move(context, resolved, index, 1),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Future<void> _saveConfig(
    BuildContext context,
    ChurchLearningConfig next,
  ) async {
    try {
      await repository.saveChurchConfig(churchId: church.id, config: next);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('learning.setup_save_failed'))),
      );
    }
  }

  Future<void> _setGlobalVisibility(
    BuildContext context,
    String moduleId,
    bool visible,
  ) {
    final hidden = {...config.hiddenGlobalModuleIds};
    visible ? hidden.remove(moduleId) : hidden.add(moduleId);
    return _saveConfig(
      context,
      ChurchLearningConfig(
        enabled: config.enabled,
        inheritGlobalModules: config.inheritGlobalModules,
        hiddenGlobalModuleIds: hidden,
        moduleOrder: config.moduleOrder,
      ),
    );
  }

  Future<void> _move(
    BuildContext context,
    List<LearningModule> modules,
    int index,
    int direction,
  ) {
    final ids = modules.map((module) => module.id).toList();
    final moved = ids.removeAt(index);
    ids.insert(index + direction, moved);
    return _saveConfig(
      context,
      ChurchLearningConfig(
        enabled: config.enabled,
        inheritGlobalModules: config.inheritGlobalModules,
        hiddenGlobalModuleIds: config.hiddenGlobalModuleIds,
        moduleOrder: ids,
      ),
    );
  }

  Future<void> _confirmRevert(
    BuildContext context,
    LearningModule module,
  ) async {
    final confirmed = await _confirm(
      context,
      title: context.t('learning.revert_title'),
      message: context.t('learning.revert_message'),
      action: context.t('learning.revert_action'),
    );
    if (confirmed != true) return;
    try {
      await repository.deleteChurchModule(churchId: church.id, module: module);
      if (module.sourceModuleId.isNotEmpty) {
        final hidden = {...config.hiddenGlobalModuleIds}
          ..remove(module.sourceModuleId);
        await repository.saveChurchConfig(
          churchId: church.id,
          config: ChurchLearningConfig(
            enabled: config.enabled,
            inheritGlobalModules: config.inheritGlobalModules,
            hiddenGlobalModuleIds: hidden,
            moduleOrder: config.moduleOrder,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('learning.setup_save_failed'))),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    LearningModule module,
  ) async {
    final confirmed = await _confirm(
      context,
      title: context.t('learning.delete_module_title'),
      message: context.t('learning.delete_church_module_message'),
      action: context.t('common.delete'),
    );
    if (confirmed != true) return;
    try {
      await repository.deleteChurchModule(churchId: church.id, module: module);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('learning.delete_failed'))),
      );
    }
  }
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) =>
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );

class _GlobalModuleTile extends StatelessWidget {
  const _GlobalModuleTile({
    required this.global,
    required this.customized,
    required this.visible,
    required this.controlsEnabled,
    required this.onVisibilityChanged,
    required this.onCustomize,
    required this.onRevert,
  });

  final LearningModule global;
  final LearningModule? customized;
  final bool visible;
  final bool controlsEnabled;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onCustomize;
  final VoidCallback? onRevert;

  @override
  Widget build(BuildContext context) {
    final shownModule = customized ?? global;
    return Container(
      decoration: carouselBoxDecoration(context),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        leading: const CircleAvatar(child: Icon(Icons.public_rounded)),
        title: Text(shownModule.title),
        subtitle: Text(
          context.t(
            customized == null
                ? 'learning.module_global_label'
                : 'learning.module_customized_label',
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch.adaptive(
              value: visible,
              onChanged: controlsEnabled ? onVisibilityChanged : null,
            ),
            AppPopupMenu<String>(
              actions: [
                AppPopupMenuAction(
                  value: 'customize',
                  icon: Icons.tune_rounded,
                  label: context.t(
                    customized == null
                        ? 'learning.customize_action'
                        : 'common.edit',
                  ),
                ),
                if (onRevert != null)
                  AppPopupMenuAction(
                    value: 'revert',
                    icon: Icons.restore_rounded,
                    label: context.t('learning.revert_action'),
                  ),
              ],
              onSelected: (value) =>
                  value == 'revert' ? onRevert?.call() : onCustomize(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChurchModuleTile extends StatelessWidget {
  const _ChurchModuleTile({
    required this.module,
    required this.onEdit,
    required this.onDelete,
  });

  final LearningModule module;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        decoration: carouselBoxDecoration(context),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          leading: const CircleAvatar(child: Icon(Icons.church_outlined)),
          title: Text(module.title),
          subtitle: Text(context.t('learning.module_church_only_label')),
          trailing: AppPopupMenu<String>(
            actions: [
              AppPopupMenuAction(
                value: 'edit',
                icon: Icons.edit_outlined,
                label: context.t('common.edit'),
              ),
              AppPopupMenuAction(
                value: 'delete',
                icon: Icons.delete_outline,
                label: context.t('common.delete'),
                color: Theme.of(context).colorScheme.error,
              ),
            ],
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
          ),
        ),
      );
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.index,
    required this.module,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final LearningModule module;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) => Container(
        decoration: carouselBoxDecoration(context),
        child: ListTile(
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text(module.title),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: context.t('common.move_up'),
                onPressed: onMoveUp,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                tooltip: context.t('common.move_down'),
                onPressed: onMoveDown,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(subtitle),
        ],
      );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        decoration: carouselBoxDecoration(context),
        padding: const EdgeInsets.all(18),
        child: Text(text, textAlign: TextAlign.center),
      );
}
