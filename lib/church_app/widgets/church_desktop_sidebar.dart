import 'package:flutter/material.dart';
import 'package:flutter_application/church_app/screens/church_side_drawer.dart';
import 'package:flutter_application/church_app/widgets/app_bottom_tab_bar.dart';

/// Past this width the shell stops being a phone layout and becomes a
/// desktop one: the tabs move from the bottom of the screen to a permanent
/// sidebar, the drawer stops hiding behind a hamburger, and the top app bar
/// goes away because everything that was in it now lives in the sidebar.
///
/// Chosen to sit above a tablet in landscape rather than at it. An iPad in
/// landscape is about 1180–1194 points and its touch layout is the phone
/// one, which is right: a bottom tab bar is easy to reach with a thumb and a
/// sidebar is not. A 12.9" iPad (1366) does cross this line, which is a
/// judgement call — at that size it is being used like a laptop.
const double desktopShellBreakpoint = 1280.0;

/// Whether [width] should get the desktop shell.
///
/// A function rather than a bare comparison so the rule has one home and can
/// be tested without building the shell, which needs most of the app's
/// providers to stand up.
bool useDesktopShell(double width) => width >= desktopShellBreakpoint;

/// How wide the sidebar itself is. Wide enough for the longest destination
/// label plus its icon without the labels wrapping, narrow enough to leave
/// the content the majority of a 1280 window.
const double desktopSidebarWidth = 268.0;

/// The permanent left-hand navigation for a desktop window.
///
/// This is the same material as the phone layout, rearranged rather than
/// reinvented: the primary destinations are the identical
/// [AppBottomTabItem] list the bottom bar renders, and below them is the
/// very same [AppDrawer], embedded instead of sliding over the page. Keeping
/// one source for both means a tab added for the phone cannot go missing on
/// desktop.
class ChurchDesktopSidebar extends StatelessWidget {
  const ChurchDesktopSidebar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.onSelectedMenu,
    required this.header,
  });

  final List<AppBottomTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final void Function(String menu) onSelectedMenu;

  /// Brand and church switcher — what the top app bar carries on a phone.
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: desktopSidebarWidth,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: header,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  for (var index = 0; index < items.length; index++)
                    _SidebarDestination(
                      item: items[index],
                      selected: index == currentIndex,
                      onTap: () => onSelect(index),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.15),
            ),
            // The drawer's own list scrolls; it is the long part, and the
            // destinations above must stay put while it does.
            Expanded(
              child: AppDrawer(
                onSelectedMenu: onSelectedMenu,
                embedded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  const _SidebarDestination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                // The label is the same string the bottom bar shows, where
                // it has a whole tab's width. Here it shares a row with an
                // icon, so it has to be able to give way rather than
                // overflow the sidebar.
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected ? colors.onPrimary : colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
