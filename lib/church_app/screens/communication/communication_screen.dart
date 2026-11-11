import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/church_app/helpers/app_text.dart';
import 'package:flutter_application/church_app/helpers/church_group_definitions.dart';
import 'package:flutter_application/church_app/helpers/contact_launcher.dart';
import 'package:flutter_application/church_app/helpers/message_composer.dart';
import 'package:flutter_application/church_app/models/church_membership_model.dart';
import 'package:flutter_application/church_app/models/communication_models.dart';
import 'package:flutter_application/church_app/providers/authentication/firebaseAuth_provider.dart';
import 'package:flutter_application/church_app/providers/members_provider.dart';
import 'package:flutter_application/church_app/providers/select_church_provider.dart';
import 'package:flutter_application/church_app/providers/side_drawer/communication_providers.dart';
import 'package:flutter_application/church_app/widgets/app_loading_indicator.dart';
import 'package:flutter_application/church_app/widgets/app_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

String communicationChannelLabel(BuildContext context, MessageChannel c) =>
    context.t('communication.channel.${c.key}', fallback: c.key);

String communicationCategoryLabel(BuildContext context, String key) =>
    context.t('communication.category.$key', fallback: key);

/// Church staff reaching the congregation by WhatsApp, SMS, email or a call
/// list.
///
/// The app never sends: it opens the messaging app with the text already
/// written, and records what the church says went out. That is the point of
/// the design, not a limitation of it — the message arrives from the number
/// members already know, and nothing leaves without a person pressing send
/// in the app that owns the conversation.
class CommunicationScreen extends ConsumerStatefulWidget {
  const CommunicationScreen({super.key});

  @override
  ConsumerState<CommunicationScreen> createState() =>
      _CommunicationScreenState();
}

class _CommunicationScreenState extends ConsumerState<CommunicationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final logAsync = ref.watch(messageLogProvider);

    return Column(
      children: [
        _CommunicationHeader(
          members: membersAsync.asData?.value ?? const [],
          log: logAsync.asData?.value ?? const [],
        ),
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: context.t('communication.tab_compose')),
            Tab(text: context.t('communication.tab_history')),
            Tab(text: context.t('communication.tab_templates')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: const [
              _ComposeTab(),
              _HistoryTab(),
              _TemplatesTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunicationHeader extends StatelessWidget {
  const _CommunicationHeader({required this.members, required this.log});

  final List<ChurchMembership> members;
  final List<SentMessage> log;

  @override
  Widget build(BuildContext context) {
    final stats = communicationStats(members: members, log: log);

    // No screen title here. The tab the reader just pressed is called
    // Messages and the segmented control below says which part they are in,
    // so a heading and a one-line description of the feature only pushed the
    // compose form further down every time they opened it.
    //
    // The four numbers used to be boxes two deep on a phone — roughly 140dp
    // of standing furniture above a form people came here to type in. They
    // are reference, not the task, so they are now one wrapping line of
    // pills: the same four facts in about a quarter of the height, with
    // nothing scrolled out of reach.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatPill(
            value: '${stats.messagesThisMonth}',
            label: context.t('communication.stat_messages_short'),
          ),
          _StatPill(
            value: '${stats.peopleReachedThisMonth}',
            label: context.t('communication.stat_reached_short'),
          ),
          _StatPill(
            value: '${stats.withPhone}',
            label: context.t('communication.stat_with_phone_short'),
          ),
          _StatPill(
            value: '${stats.withoutPhone}',
            label: context.t('communication.stat_without_phone_short'),
            // Not an error, but the number a church should want to see
            // shrink: these people cannot be reached this way.
            attention: stats.withoutPhone > 0,
          ),
        ],
      ),
    );
  }
}

/// One figure on the Messages strip — the number and what it counts, on a
/// single line.
///
/// Sized to its own content rather than an equal share of the row, so the
/// four of them wrap like words instead of each being squeezed to a quarter
/// of a 320dp phone, which is what broke "Messages this month" mid-word.
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.value,
    required this.label,
    this.attention = false,
  });

  final String value;
  final String label;
  final bool attention;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: attention
            ? colors.errorContainer.withValues(alpha: 0.45)
            : colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: attention ? colors.onErrorContainer : colors.onSurface,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ComposeTab extends ConsumerStatefulWidget {
  const _ComposeTab();

  @override
  ConsumerState<_ComposeTab> createState() => _ComposeTabState();
}

class _ComposeTabState extends ConsumerState<_ComposeTab> {
  final _body = TextEditingController();
  MessageChannel _channel = MessageChannel.whatsapp;
  String _category = messageCategoryKeys.first;
  String? _groupId;
  final Set<String> _excluded = <String>{};

  /// Batches already handed off, so a long run can be resumed rather than
  /// restarted — the one thing a church cannot recover from is sending the
  /// same notice to the same people twice.
  final Set<int> _doneBatches = <int>{};

  /// Recipients whose chat has already been opened. WhatsApp takes one
  /// person per link, so a 10-person send is ten hand-offs and the sender
  /// needs to see where they got to.
  final Set<String> _opened = <String>{};
  bool _isLogging = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  List<ChurchMembership> _recipients(List<ChurchMembership> members) {
    final approved = members.where((member) => member.approved);
    final inGroup = membersInGroup(approved, _groupId);
    return reachableMembers(inGroup, _channel)
        .where((member) => !_excluded.contains(member.docId))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final templates = ref.watch(messageTemplatesProvider).asData?.value ??
        const <MessageTemplate>[];
    final churchName = ref.watch(selectedChurchProvider)?.name.trim() ?? '';

    return membersAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (_, __) => Center(
        child: Text(context.t('communication.members_failed')),
      ),
      data: (members) {
        final recipients = _recipients(members);
        final approved = members.where((member) => member.approved).toList();
        final inGroup = membersInGroup(approved, _groupId);
        final unreachable =
            inGroup.length - reachableMembers(inGroup, _channel).length;
        final hasPerPerson = messageHasPerPersonPlaceholder(_body.text);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            AppDropdownField<String?>(
              labelText: context.t('communication.group_label'),
              initialValue: _groupId,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(context.t('communication.group_everyone')),
                ),
                for (final group in churchGroupDefinitions)
                  DropdownMenuItem<String?>(
                    value: group.id,
                    child: Text(
                      context.t(group.labelKey, fallback: group.id),
                    ),
                  ),
              ],
              onChanged: (value) => setState(() {
                _groupId = value;
                _doneBatches.clear();
                _opened.clear();
              }),
            ),
            const SizedBox(height: 14),
            AppDropdownField<MessageChannel>(
              labelText: context.t('communication.channel_label'),
              initialValue: _channel,
              items: [
                for (final channel in MessageChannel.values)
                  DropdownMenuItem<MessageChannel>(
                    value: channel,
                    child: Text(communicationChannelLabel(context, channel)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _channel = value;
                  _excluded.clear();
                  _doneBatches.clear();
                  _opened.clear();
                });
              },
            ),
            const SizedBox(height: 14),
            AppDropdownField<String>(
              labelText: context.t('communication.category_label'),
              initialValue: _category,
              items: [
                for (final key in messageCategoryKeys)
                  DropdownMenuItem<String>(
                    value: key,
                    child: Text(communicationCategoryLabel(context, key)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _category = value);
              },
            ),
            const SizedBox(height: 14),
            if (templates.isNotEmpty) ...[
              AppDropdownField<String>(
                labelText: context.t('communication.template_label'),
                hintText: context.t('communication.template_hint'),
                initialValue: null,
                items: [
                  for (final template in templates)
                    DropdownMenuItem<String>(
                      value: template.id,
                      child: Text(template.name),
                    ),
                ],
                onChanged: (value) {
                  final picked = templates.firstWhere(
                    (template) => template.id == value,
                    orElse: () => templates.first,
                  );
                  setState(() {
                    _body.text = picked.body;
                    _category = picked.category;
                  });
                },
              ),
              const SizedBox(height: 14),
            ],
            AppTextField(
              controller: _body,
              label: context.t('communication.message_label'),
              hintText: context.t('communication.message_hint'),
              maxLines: 6,
              minLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              context.t('communication.placeholder_hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (hasPerPerson) ...[
              const SizedBox(height: 10),
              _PerPersonWarning(
                onStrip: () => setState(
                  () => _body.text = stripPerPersonPlaceholders(_body.text),
                ),
              ),
            ],
            const SizedBox(height: 18),
            _RecipientSummary(
              reachable: recipients.length,
              unreachable: unreachable,
              channel: _channel,
            ),
            const SizedBox(height: 14),
            if (_channel == MessageChannel.whatsapp)
              _WhatsAppGroupsSection(
                body: resolveMessageBody(
                  _body.text,
                  churchName: churchName,
                ),
                hasPerPerson: hasPerPerson,
              ),
            if (needsBatching(recipients.length, _channel) &&
                _channel != MessageChannel.whatsapp &&
                !hasPerPerson)
              _BatchStepper(
                channel: _channel,
                recipients: recipients,
                body: resolveMessageBody(
                  _body.text,
                  churchName: churchName,
                ),
                churchName: churchName,
                emailSubject: _emailSubject(context, churchName),
                done: _doneBatches,
                onBatchDone: (index) => setState(() => _doneBatches.add(index)),
              ),
            _ComposeActions(
              channel: _channel,
              recipients: recipients,
              body: _body.text,
              churchName: churchName,
              emailSubject: _emailSubject(context, churchName),
              hasPerPerson: hasPerPerson,
              isLogging: _isLogging,
              opened: _opened,
              onOpened: (id) => setState(() => _opened.add(id)),
              onLogged: () => _logSent(recipients.length, churchName),
            ),
            const SizedBox(height: 18),
            _FieldLabel(text: context.t('communication.recipients_label')),
            const SizedBox(height: 6),
            for (final member in recipients)
              _RecipientRow(
                member: member,
                channel: _channel,
                body: _body.text,
                churchName: churchName,
                emailSubject: _emailSubject(context, churchName),
                opened: _opened.contains(member.docId),
                onOpened: () => setState(() => _opened.add(member.docId)),
                excluded: _excluded.contains(member.docId),
                onToggle: () => setState(() {
                  if (!_excluded.remove(member.docId)) {
                    _excluded.add(member.docId);
                  }
                }),
              ),
            // Someone deselected is still listed, so putting them back does
            // not mean rebuilding the whole selection.
            for (final member in reachableMembers(approved, _channel)
                .where((m) => _excluded.contains(m.docId)))
              _RecipientRow(
                member: member,
                channel: _channel,
                body: _body.text,
                churchName: churchName,
                emailSubject: _emailSubject(context, churchName),
                opened: _opened.contains(member.docId),
                onOpened: () => setState(() => _opened.add(member.docId)),
                excluded: true,
                onToggle: () => setState(() => _excluded.remove(member.docId)),
              ),
          ],
        );
      },
    );
  }

  /// "Grace Church — Event reminder". The subject field is a choice, not
  /// free text, so this is the whole of it.
  String _emailSubject(BuildContext context, String churchName) {
    final subject = communicationCategoryLabel(context, _category);
    return churchName.trim().isEmpty
        ? subject
        : '${churchName.trim()} — $subject';
  }

  Future<void> _logSent(int recipientCount, String churchName) async {
    if (_body.text.trim().isEmpty || recipientCount == 0) return;
    setState(() => _isLogging = true);
    final messenger = ScaffoldMessenger.of(context);
    final logged = context.t('communication.logged');
    final failed = context.t('communication.log_failed');

    try {
      await ref.read(communicationRepositoryProvider).logSent(
            SentMessage(
              id: '',
              body: _body.text.trim(),
              channel: _channel,
              category: _category,
              recipientCount: recipientCount,
              audienceLabel: context.t(
                'communication.audience_reachable',
                parameters: {'count': recipientCount},
              ),
              sentBy: ref.read(firebaseAuthProvider).currentUser?.uid ?? '',
            ),
          );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(logged)));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }
}

class _PerPersonWarning extends StatelessWidget {
  const _PerPersonWarning({required this.onStrip});

  final VoidCallback onStrip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.t('communication.per_person_warning'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: onStrip,
            child: Text(context.t('communication.remove_placeholders')),
          ),
        ],
      ),
    );
  }
}

class _RecipientSummary extends StatelessWidget {
  const _RecipientSummary({
    required this.reachable,
    required this.unreachable,
    required this.channel,
  });

  final int reachable;
  final int unreachable;
  final MessageChannel channel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.group_outlined, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              unreachable == 0
                  ? context.t(
                      'communication.recipients_all',
                      parameters: {'count': reachable},
                    )
                  : context.t(
                      'communication.recipients_some',
                      parameters: {
                        'count': reachable,
                        'missing': unreachable,
                      },
                    ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeActions extends StatelessWidget {
  const _ComposeActions({
    required this.channel,
    required this.recipients,
    required this.body,
    required this.churchName,
    required this.emailSubject,
    required this.hasPerPerson,
    required this.isLogging,
    required this.opened,
    required this.onOpened,
    required this.onLogged,
  });

  final MessageChannel channel;
  final List<ChurchMembership> recipients;
  final String body;
  final String churchName;

  /// What lands in the mail app's subject line — the church plus the
  /// chosen subject, so a member sees who it is from and what it is about
  /// before opening it.
  final String emailSubject;
  final bool hasPerPerson;
  final bool isLogging;

  /// Document ids whose chat has already been opened this sitting.
  final Set<String> opened;
  final ValueChanged<String> onOpened;

  final VoidCallback onLogged;

  @override
  Widget build(BuildContext context) {
    final ready = body.trim().isNotEmpty && recipients.isNotEmpty;
    final groupBody = resolveMessageBody(
      body,
      churchName: churchName,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (channel == MessageChannel.sms &&
            !needsBatching(recipients.length, channel))
          FilledButton.icon(
            onPressed: ready && !hasPerPerson
                ? () => _openGroupSms(context, groupBody)
                : null,
            icon: const Icon(Icons.sms_outlined, size: 18),
            label: Text(context.t('communication.open_sms_all')),
          ),
        if (channel == MessageChannel.email &&
            !needsBatching(recipients.length, channel))
          FilledButton.icon(
            onPressed: ready && !hasPerPerson
                ? () => _openGroupEmail(context, groupBody)
                : null,
            icon: const Icon(Icons.mail_outline_rounded, size: 18),
            label: Text(context.t('communication.open_email_all')),
          ),
        // WhatsApp has no link that reaches a group of people, so a send to
        // ten is ten hand-offs. Without a primary action the selection
        // above just sits there and the only way through is tapping each
        // row, which does not read as "now send it". This walks the list
        // in order and says how far it has got.
        if (channel == MessageChannel.whatsapp) _whatsAppNextButton(context),
        // Disabled for the same reason as the group sends above. Copy hands
        // back one body for pasting somewhere else, and with `{name}` still
        // in it that paste reads "Dear {name}, …" — the placeholder is only
        // ever filled when the app opens one person's chat. Copying it
        // looked like it had worked, which is the confusing part.
        OutlinedButton.icon(
          onPressed: body.trim().isEmpty || hasPerPerson
              ? null
              : () => _copy(context, groupBody,
                  context.t('communication.message_copied')),
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: Text(context.t('communication.copy_message')),
        ),
        OutlinedButton.icon(
          onPressed: ready && !isLogging ? onLogged : null,
          icon: isLogging
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: Text(context.t('communication.log_as_sent')),
        ),
      ],
    );
  }

  /// "Open next chat (3 of 8)" — the one button that moves a WhatsApp send
  /// forward. Each press opens the next person who has not been opened
  /// yet, so the sender never has to remember where they were.
  Widget _whatsAppNextButton(BuildContext context) {
    final remaining = recipients
        .where((member) => !opened.contains(member.docId))
        .toList(growable: false);
    final done = recipients.length - remaining.length;
    final ready = body.trim().isNotEmpty && recipients.isNotEmpty;

    if (ready && remaining.isEmpty) {
      return FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check_circle_rounded, size: 18),
        label: Text(
          context.t(
            'communication.wa_all_opened',
            parameters: {'count': recipients.length},
          ),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: ready ? () => _openOne(context, remaining.first) : null,
      icon: const Icon(Icons.chat_rounded, size: 18),
      label: Text(
        context.t(
          'communication.wa_open_next',
          parameters: {'done': done + 1, 'count': recipients.length},
        ),
      ),
    );
  }

  Future<void> _openOne(BuildContext context, ChurchMembership member) async {
    final uri = whatsAppUri(
      member.displayPhone,
      resolveMessageBody(body, member: member, churchName: churchName),
    );
    if (uri == null) return;
    final launched = await launchExternalUri(context, uri);
    if (launched) onOpened(member.docId);
  }

  Future<void> _openGroupSms(BuildContext context, String text) async {
    final uri = smsUri(
      recipients.map((m) => m.displayPhone).toList(growable: false),
      text,
    );
    if (uri == null) return;
    await launchExternalUri(context, uri);
  }

  Future<void> _openGroupEmail(BuildContext context, String text) async {
    final uri = emailUri(
      recipients.map((m) => m.displayEmail).toList(growable: false),
      emailSubject,
      text,
    );
    if (uri == null) return;
    await launchExternalUri(context, uri);
  }

  Future<void> _copy(
    BuildContext context,
    String text,
    String confirmation,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(confirmation)));
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.member,
    required this.channel,
    required this.body,
    required this.churchName,
    required this.emailSubject,
    required this.opened,
    required this.onOpened,
    required this.excluded,
    required this.onToggle,
  });

  final ChurchMembership member;
  final MessageChannel channel;
  final String body;
  final String churchName;
  final String emailSubject;

  /// Whether this person's chat has already been opened this sitting.
  final bool opened;
  final VoidCallback onOpened;

  final bool excluded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final personal = resolveMessageBody(
      body,
      member: member,
      churchName: churchName,
    );

    return Opacity(
      opacity: excluded ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Checkbox(
              value: !excluded,
              onChanged: (_) => onToggle(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.displayName.trim().isEmpty
                        ? context.t('communication.member_fallback')
                        : member.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    channel == MessageChannel.email
                        ? member.displayEmail
                        : member.displayPhone,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            // One person at a time is how WhatsApp actually works, and the
            // only way a {name} placeholder can be filled in.
            if (!excluded && body.trim().isNotEmpty)
              IconButton(
                tooltip: opened
                    ? context.t('communication.opened_already')
                    : context.t('communication.send_to_one'),
                icon: Icon(
                  opened
                      ? Icons.check_circle_rounded
                      : switch (channel) {
                          MessageChannel.whatsapp => Icons.chat_outlined,
                          MessageChannel.sms => Icons.sms_outlined,
                          MessageChannel.email => Icons.mail_outline_rounded,
                        },
                  size: 20,
                  color: opened ? colors.primary : null,
                ),
                onPressed: () => _openForOne(context, personal),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForOne(BuildContext context, String text) async {
    final Uri? uri = switch (channel) {
      MessageChannel.whatsapp => whatsAppUri(member.displayPhone, text),
      MessageChannel.sms => smsUri([member.displayPhone], text),
      MessageChannel.email =>
        emailUri([member.displayEmail], emailSubject, text),
    };
    if (uri == null) return;
    final launched = await launchExternalUri(context, uri);
    if (launched) onOpened();
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(messageLogProvider);
    final dateFormat = DateFormat('d MMM yyyy, h:mm a');

    return logAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (_, __) =>
          Center(child: Text(context.t('communication.load_failed'))),
      data: (log) {
        if (log.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                context.t('communication.history_empty'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: log.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final message = log[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          communicationChannelLabel(context, message.channel),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          communicationCategoryLabel(context, message.category),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      Text(
                        message.sentAt == null
                            ? ''
                            : dateFormat.format(message.sentAt!),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(message.body),
                  const SizedBox(height: 8),
                  Text(
                    context.t(
                      'communication.history_recipients',
                      parameters: {'count': message.recipientCount},
                    ),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TemplatesTab extends ConsumerWidget {
  const _TemplatesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(messageTemplatesProvider);

    return Scaffold(
      body: templatesAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (_, __) =>
            Center(child: Text(context.t('communication.load_failed'))),
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.t('communication.templates_empty'),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final template = templates[index];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.7),
                  ),
                ),
                title: Text(template.name),
                subtitle: Text(
                  template.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: context.t('communication.delete_template'),
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => ref
                      .read(communicationRepositoryProvider)
                      .deleteTemplate(template.id),
                ),
                onTap: () => _editTemplate(context, ref, template),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editTemplate(context, ref, null),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.t('communication.new_template')),
      ),
    );
  }

  Future<void> _editTemplate(
    BuildContext context,
    WidgetRef ref,
    MessageTemplate? existing,
  ) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final bodyController = TextEditingController(text: existing?.body ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          existing == null
              ? dialogContext.t('communication.new_template')
              : dialogContext.t('communication.edit_template'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: nameController,
              label: dialogContext.t('communication.template_name'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: bodyController,
              label: dialogContext.t('communication.message_label'),
              maxLines: 5,
              minLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.t('common.save')),
          ),
        ],
      ),
    );

    if (saved == true && nameController.text.trim().isNotEmpty) {
      await ref.read(communicationRepositoryProvider).saveTemplate(
            MessageTemplate(
              id: existing?.id ?? '',
              name: nameController.text.trim(),
              body: bodyController.text,
              category: existing?.category ?? messageCategoryKeys.first,
            ),
          );
    }
    nameController.dispose();
    bodyController.dispose();
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

/// Works a long recipient list through in chunks.
///
/// A church with 200 members cannot rely on one hand-off reaching everyone:
/// WhatsApp opens a single chat, a `mailto:` with 200 addresses runs past
/// the length mail apps accept, and an SMS app or carrier may cap
/// recipients without saying so. This splits the list, keeps the same
/// people in the same batch every time, and remembers which batches have
/// been handed off so a run can be picked up where it stopped instead of
/// starting again — sending the same notice twice is the one mistake that
/// cannot be taken back.
class _BatchStepper extends StatelessWidget {
  const _BatchStepper({
    required this.channel,
    required this.recipients,
    required this.body,
    required this.churchName,
    required this.emailSubject,
    required this.done,
    required this.onBatchDone,
  });

  final MessageChannel channel;
  final List<ChurchMembership> recipients;
  final String body;
  final String churchName;
  final String emailSubject;
  final Set<int> done;
  final ValueChanged<int> onBatchDone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final batches =
        messageBatches(recipients, communicationBatchLimit(channel));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(
              'communication.batch_title',
              parameters: {
                'count': recipients.length,
                'batches': batches.length,
              },
            ),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            context.t('communication.batch_hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < batches.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    done.contains(index)
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: done.contains(index)
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.t(
                        'communication.batch_row',
                        parameters: {
                          'index': index + 1,
                          'count': batches[index].length,
                        },
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: body.trim().isEmpty
                        ? null
                        : () => _openBatch(context, batches[index], index),
                    child: Text(
                      done.contains(index)
                          ? context.t('communication.batch_again')
                          : context.t('communication.batch_open'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openBatch(
    BuildContext context,
    List<ChurchMembership> batch,
    int index,
  ) async {
    final Uri? uri = switch (channel) {
      MessageChannel.sms => smsUri(
          batch.map((m) => m.displayPhone).toList(growable: false),
          body,
        ),
      MessageChannel.email => emailUri(
          batch.map((m) => m.displayEmail).toList(growable: false),
          emailSubject,
          body,
        ),
      // WhatsApp never reaches here: it is one chat per link, so the
      // per-recipient rows are its only path.
      MessageChannel.whatsapp => null,
    };
    if (uri == null) return;
    final launched = await launchExternalUri(context, uri);
    if (launched) onBatchDone(index);
  }
}

/// Reaching a WhatsApp group the church already has.
///
/// WhatsApp exposes no link that both names a group and carries a message,
/// so these are two different actions rather than one:
///
/// * **Share** opens WhatsApp with the message written and no recipient
///   chosen, so any chat or group can be picked in WhatsApp's own list.
///   This is the one that actually puts text into a group.
/// * **A saved group** opens that specific group by its invite link. The
///   message has to be pasted, so the button copies it on the way out.
class _WhatsAppGroupsSection extends ConsumerWidget {
  const _WhatsAppGroupsSection({
    required this.body,
    required this.hasPerPerson,
  });

  final String body;
  final bool hasPerPerson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(whatsAppGroupsProvider).asData?.value ??
        const <WhatsAppGroupLink>[];
    final colors = Theme.of(context).colorScheme;
    final ready = body.trim().isNotEmpty && !hasPerPerson;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.t('communication.wa_groups_title'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: () => _editGroup(context, ref, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.t('communication.wa_group_add')),
              ),
            ],
          ),
          Text(
            context.t('communication.wa_groups_hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: ready
                ? () => launchExternalUri(context, whatsAppShareUri(body))
                : null,
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(context.t('communication.wa_share')),
          ),
          if (groups.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final group in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.groups_2_outlined,
                        size: 20, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(group.label)),
                    TextButton(
                      onPressed: () => _openGroup(context, group),
                      child: Text(context.t('communication.wa_group_open')),
                    ),
                    IconButton(
                      tooltip: context.t('communication.wa_group_remove'),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => ref
                          .read(communicationRepositoryProvider)
                          .deleteWhatsAppGroup(group.id),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Copies the message before opening, because WhatsApp cannot be handed
  /// text for a named group — it has to be pasted on arrival.
  Future<void> _openGroup(
    BuildContext context,
    WhatsAppGroupLink group,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = context.t('communication.wa_group_copied');
    if (body.trim().isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: body));
      messenger.showSnackBar(SnackBar(content: Text(copied)));
    }
    if (!context.mounted) return;
    await launchExternalUri(context, Uri.parse(group.inviteUrl));
  }

  Future<void> _editGroup(
    BuildContext context,
    WidgetRef ref,
    WhatsAppGroupLink? existing,
  ) async {
    // A group's invite link cannot be derived from its name — the code in
    // it is a secret WhatsApp generates per group, with no public lookup.
    // What can be avoided is retyping it: whoever is adding a group has
    // just copied the link in WhatsApp, so it is already on the clipboard.
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final fromClipboard = normalizeWhatsAppGroupLink(clipboard?.text ?? '');

    final labelController = TextEditingController(text: existing?.label ?? '');
    final linkController = TextEditingController(
      text: existing?.inviteUrl ?? fromClipboard ?? '',
    );
    if (!context.mounted) return;

    String? error;
    String? notice = existing == null && fromClipboard != null
        ? context.t('communication.wa_group_link_pasted')
        : null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(dialogContext.t('communication.wa_group_add')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                controller: labelController,
                label: dialogContext.t('communication.wa_group_name'),
                // Pasting the link into the name box is the obvious slip,
                // since the clipboard holds the link. Move it rather than
                // failing validation on it later.
                onChanged: (value) {
                  final link = normalizeWhatsAppGroupLink(value);
                  if (link == null) return;
                  setDialogState(() {
                    linkController.text = link;
                    labelController.clear();
                    error = null;
                    notice =
                        dialogContext.t('communication.wa_group_link_moved');
                  });
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: linkController,
                label: dialogContext.t('communication.wa_group_link'),
                hintText:
                    dialogContext.t('communication.wa_group_link_example'),
                suffixIcon: IconButton(
                  tooltip: dialogContext.t('communication.wa_group_paste'),
                  icon: const Icon(Icons.content_paste_rounded, size: 20),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    final link = normalizeWhatsAppGroupLink(data?.text ?? '');
                    setDialogState(() {
                      if (link == null) {
                        error = dialogContext
                            .t('communication.wa_group_clipboard_empty');
                        return;
                      }
                      linkController.text = link;
                      error = null;
                      notice =
                          dialogContext.t('communication.wa_group_link_pasted');
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error ??
                    notice ??
                    dialogContext.t('communication.wa_group_link_hint'),
                style: TextStyle(
                  fontSize: 12,
                  color: error == null
                      ? Theme.of(dialogContext).colorScheme.onSurfaceVariant
                      : Theme.of(dialogContext).colorScheme.error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () {
                final link = normalizeWhatsAppGroupLink(linkController.text);
                if (link == null || labelController.text.trim().isEmpty) {
                  setDialogState(
                    () => error =
                        dialogContext.t('communication.wa_group_link_invalid'),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(dialogContext.t('common.save')),
            ),
          ],
        ),
      ),
    );

    if (saved == true) {
      final link = normalizeWhatsAppGroupLink(linkController.text);
      if (link != null) {
        await ref.read(communicationRepositoryProvider).saveWhatsAppGroup(
              WhatsAppGroupLink(
                id: existing?.id ?? '',
                label: labelController.text.trim(),
                inviteUrl: link,
              ),
            );
      }
    }
    labelController.dispose();
    linkController.dispose();
  }
}
