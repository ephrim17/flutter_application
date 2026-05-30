import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/models/bible_version_model.dart';
import 'package:flutter_application/church_app/providers/side_drawer/bible_versions_provider.dart';
import 'package:flutter_application/church_app/screens/side_drawer/bible_book_screen.dart';
import 'package:flutter_application/church_app/services/side_drawer/bible_download_repository.dart';
import 'package:flutter_application/church_app/widgets/app_bar_title_widget.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BibleLibraryScreen extends ConsumerStatefulWidget {
  const BibleLibraryScreen({super.key});

  @override
  ConsumerState<BibleLibraryScreen> createState() => _BibleLibraryScreenState();
}

class _BibleLibraryScreenState extends ConsumerState<BibleLibraryScreen> {
  final BibleDownloadRepository _repository = BibleDownloadRepository();
  Future<Map<String, _BibleVersionDownloadState>>? _stateFuture;
  late final Future<bool> _supportsLocalDownloadsFuture =
      _repository.supportsLocalDownloads();
  String? _stateVersionsKey;
  String? _downloadingVersionId;
  BibleDownloadProgress? _progress;

  Future<Map<String, _BibleVersionDownloadState>> _loadStates(
    List<BibleVersion> versions,
  ) async {
    final states = <String, _BibleVersionDownloadState>{};
    for (final version in versions) {
      final downloadedFiles = await _repository.downloadedFileCount(version);
      final localContentVersion =
          await _repository.downloadedContentVersion(version);
      states[version.id] = _BibleVersionDownloadState(
        downloadedFiles: downloadedFiles,
        totalFiles: version.bookFileNames.length,
        localContentVersion: localContentVersion,
        serverContentVersion: version.contentVersion,
      );
    }
    return states;
  }

  Future<Map<String, _BibleVersionDownloadState>> _statesFor(
    List<BibleVersion> versions,
  ) {
    final versionsKey = versions.map((version) => version.id).join('|');
    if (_stateFuture == null || _stateVersionsKey != versionsKey) {
      _stateVersionsKey = versionsKey;
      _stateFuture = _loadStates(versions);
    }
    return _stateFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(
          text:
              context.t('bible.available_title', fallback: 'Available Bibles'),
        ),
      ),
      body: ref.watch(bibleVersionsProvider).when(
            loading: () => const Center(child: AppLoadingIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${context.t('common.error_prefix', fallback: 'Error')}: $error',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (versions) => FutureBuilder<bool>(
              future: _supportsLocalDownloadsFuture,
              builder: (context, snapshot) {
                final supportsLocalDownloads = snapshot.data ?? false;

                if (versions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No Bible versions are available right now.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: AppLoadingIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '${context.t('common.error_prefix', fallback: 'Error')}: '
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!supportsLocalDownloads) {
                  return _BibleVersionList(
                    versions: versions,
                    states: const {},
                    supportsLocalDownloads: false,
                    downloadingVersionId: _downloadingVersionId,
                    progress: _progress,
                    onTap: (version, _) => _openBible(
                      version,
                      requireDownloaded: false,
                    ),
                  );
                }

                return FutureBuilder<Map<String, _BibleVersionDownloadState>>(
                  future: _statesFor(versions),
                  builder: (context, stateSnapshot) {
                    if (stateSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: AppLoadingIndicator());
                    }

                    if (stateSnapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '${context.t('common.error_prefix', fallback: 'Error')}: '
                            '${stateSnapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return _BibleVersionList(
                      versions: versions,
                      states: stateSnapshot.data ?? {},
                      supportsLocalDownloads: true,
                      downloadingVersionId: _downloadingVersionId,
                      progress: _progress,
                      onTap: _openOrDownload,
                    );
                  },
                );
              },
            ),
          ),
    );
  }

  Future<void> _openOrDownload(
    BibleVersion version,
    _BibleVersionDownloadState state,
  ) async {
    if (_downloadingVersionId != null) return;

    if (state.isReady) {
      await _openBible(version, requireDownloaded: true);
      return;
    }

    if (state.hasUpdate) {
      final shouldUpdate = await _confirmUpdate(version, state);
      if (shouldUpdate == null) return;

      if (!shouldUpdate) {
        await _openBible(version, requireDownloaded: true);
        return;
      }
    }

    await _downloadAndOpen(version, state);
  }

  Future<bool?> _confirmUpdate(
    BibleVersion version,
    _BibleVersionDownloadState state,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Bible?'),
          content: Text(
            '${version.title} has a newer version available. '
            'You can update all ${state.totalFiles} books now, or continue '
            'reading your downloaded version.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continue current'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Update now'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadAndOpen(
    BibleVersion version,
    _BibleVersionDownloadState state,
  ) async {
    setState(() {
      _downloadingVersionId = version.id;
      _progress = BibleDownloadProgress(
        completedFiles: state.downloadedFiles,
        totalFiles: state.totalFiles,
        currentFileName: '',
      );
    });

    try {
      await _repository.downloadVersion(
        version,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _downloadingVersionId = null;
        _progress = null;
        _stateFuture = null;
      });
      await _openBible(version, requireDownloaded: true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _downloadingVersionId = null;
        _progress = null;
        _stateFuture = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.t('common.error_prefix', fallback: 'Error')}: $error',
          ),
        ),
      );
    }
  }

  Future<void> _openBible(
    BibleVersion version, {
    required bool requireDownloaded,
  }) async {
    await _repository.setSelectedVersion(version);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BibleBookScreen(
          version: version,
          requireDownloaded: requireDownloaded,
        ),
      ),
    );
  }
}

class _BibleVersionList extends StatelessWidget {
  const _BibleVersionList({
    required this.versions,
    required this.states,
    required this.supportsLocalDownloads,
    required this.downloadingVersionId,
    required this.onTap,
    this.progress,
  });

  final List<BibleVersion> versions;
  final Map<String, _BibleVersionDownloadState> states;
  final bool supportsLocalDownloads;
  final String? downloadingVersionId;
  final BibleDownloadProgress? progress;
  final void Function(BibleVersion version, _BibleVersionDownloadState state)
      onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: versions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final version = versions[index];
        final state = states[version.id] ??
            _BibleVersionDownloadState(
              downloadedFiles: 0,
              totalFiles: version.bookFileNames.length,
              localContentVersion: null,
              serverContentVersion: version.contentVersion,
            );
        return _BibleVersionTile(
          version: version,
          state: state,
          supportsLocalDownloads: supportsLocalDownloads,
          isDownloading: downloadingVersionId == version.id,
          progress: downloadingVersionId == version.id ? progress : null,
          onTap: () => onTap(version, state),
        );
      },
    );
  }
}

class _BibleVersionTile extends StatelessWidget {
  const _BibleVersionTile({
    required this.version,
    required this.state,
    required this.supportsLocalDownloads,
    required this.isDownloading,
    required this.onTap,
    this.progress,
  });

  final BibleVersion version;
  final _BibleVersionDownloadState state;
  final bool supportsLocalDownloads;
  final bool isDownloading;
  final BibleDownloadProgress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDownloaded = state.isReady;
    final hasUpdate = state.hasUpdate;
    final progressValue = progress?.progress ?? state.progress;
    final statusText = !supportsLocalDownloads
        ? 'Open online'
        : isDownloading
            ? '${progress?.completedFiles ?? state.downloadedFiles}/'
                '${state.totalFiles} files'
            : hasUpdate
                ? 'Update available'
                : isDownloaded
                    ? 'Downloaded'
                    : '${state.downloadedFiles}/${state.totalFiles} files';

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      version.languageLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          version.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          version.subtitle,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          version.id,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.58),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          version.description,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _BibleVersionAction(
                    isDownloaded: isDownloaded,
                    hasUpdate: hasUpdate,
                    isDownloading: isDownloading,
                    supportsLocalDownloads: supportsLocalDownloads,
                  ),
                ],
              ),
              if (supportsLocalDownloads) ...[
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  minHeight: 5,
                  value: progressValue.clamp(0, 1),
                  backgroundColor: theme.dividerColor.withValues(alpha: 0.2),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                statusText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDownloaded
                      ? theme.colorScheme.primary
                      : hasUpdate
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BibleVersionAction extends StatelessWidget {
  const _BibleVersionAction({
    required this.isDownloaded,
    required this.hasUpdate,
    required this.isDownloading,
    required this.supportsLocalDownloads,
  });

  final bool isDownloaded;
  final bool hasUpdate;
  final bool isDownloading;
  final bool supportsLocalDownloads;

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    if (!supportsLocalDownloads) {
      return Icon(
        Icons.cloud_queue_rounded,
        size: 28,
        color: Theme.of(context).colorScheme.primary,
      );
    }

    return Icon(
      hasUpdate
          ? Icons.system_update_alt_rounded
          : isDownloaded
              ? Icons.arrow_forward_ios
              : Icons.download_rounded,
      size: isDownloaded ? 20 : 28,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}

class _BibleVersionDownloadState {
  const _BibleVersionDownloadState({
    required this.downloadedFiles,
    required this.totalFiles,
    required this.localContentVersion,
    required this.serverContentVersion,
  });

  final int downloadedFiles;
  final int totalFiles;
  final int? localContentVersion;
  final int serverContentVersion;

  bool get isFullyDownloaded => downloadedFiles == totalFiles && totalFiles > 0;

  bool get hasUpdate =>
      isFullyDownloaded &&
      localContentVersion != null &&
      localContentVersion! < serverContentVersion;

  bool get isReady =>
      isFullyDownloaded && localContentVersion == serverContentVersion;

  double get progress {
    if (totalFiles == 0) return 0;
    return downloadedFiles / totalFiles;
  }
}
