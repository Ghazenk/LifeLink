import 'package:flutter/material.dart';

/// A bottom sheet on compact screens and a bounded dialog on workstations.
/// Callers keep using the returned value to distinguish confirm from cancel.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  final compact = MediaQuery.sizeOf(context).width < 600;
  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: builder(sheetContext),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: dismissible,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: builder(dialogContext),
      ),
    ),
  );
}

class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.content,
    this.actions = const [],
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * (compact ? .88 : .82);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(compact ? 24 : 20),
        bottom: Radius.circular(compact ? 0 : 20),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 28,
            compact ? 10 : 28,
            compact ? 20 : 28,
            compact ? 20 + MediaQuery.paddingOf(context).bottom : 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact) ...[
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
              ],
              Semantics(
                header: true,
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.titleLarge,
                  child: title,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: content)),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var index = actions.length - 1;
                        index >= 0;
                        index--
                      ) ...[
                        SizedBox(width: double.infinity, child: actions[index]),
                        if (index > 0) const SizedBox(height: 8),
                      ],
                    ],
                  )
                else
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
