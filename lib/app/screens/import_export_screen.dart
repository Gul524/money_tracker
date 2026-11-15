import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:transaction_io/transaction_io.dart';

import '../app_services.dart';
import '../app_sizes.dart';
import '../app_theme.dart';
import '../controllers/import_export_controller.dart';
import '../date_range.dart';
import '../widgets/app_widgets.dart';

const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Saving and choosing files. Replaceable in tests.
abstract interface class ExcelFiles {
  /// Saves [bytes]; returns a description of where, or null if cancelled.
  Future<String?> save(String fileName, Uint8List bytes);

  /// Lets the user choose an .xlsx file; null if cancelled.
  Future<Uint8List?> pick();
}

class _PlatformExcelFiles implements ExcelFiles {
  const _PlatformExcelFiles();

  @override
  Future<String?> save(String fileName, Uint8List bytes) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: _xlsxMime,
      dialogTitle: 'Save Excel file',
    );
    if (uri == null) return null;
    return uri.scheme == 'file' ? uri.toFilePath() : fileName;
  }

  @override
  Future<Uint8List?> pick() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Choose an Excel file',
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    return files.isEmpty ? null : files.first.readAsBytes();
  }
}

const _periodLabels = {
  ReportPeriod.month: 'Month',
  ReportPeriod.sixMonths: '6 months',
  ReportPeriod.year: 'Year',
  ReportPeriod.custom: 'Custom',
};

/// Settings › Import and export: Excel files in the shared column format.
class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key, required this.services, this.files});
  final AppServices services;
  final ExcelFiles? files;

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  late final ImportExportController controller;
  late final ExcelFiles files;
  String? _working;

  @override
  void initState() {
    super.initState();
    controller = ImportExportController(widget.services);
    files = widget.files ?? const _PlatformExcelFiles();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _busy(String label, Future<void> Function() task) async {
    setState(() => _working = label);
    try {
      await task();
    } catch (e) {
      if (mounted) showMessage(context, 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: controller.range.start,
        end: controller.range.lastDay,
      ),
      helpText: 'Export entries between',
      saveText: 'Done',
    );
    if (picked != null) {
      controller.setCustomRange(DateRange.days(picked.start, picked.end));
    }
  }

  Future<void> _export() => _busy('Preparing Excel file…', () async {
    final result = await controller.export();
    if (result == null || !mounted) return;
    final where = await files.save(result.fileName, result.bytes);
    if (where != null && mounted) {
      showMessage(
        context,
        'Exported ${result.rowCount} '
        '${result.rowCount == 1 ? 'entry' : 'entries'} to $where',
      );
    }
  });

  Future<void> _template() => _busy('Preparing template…', () async {
    final bytes = await controller.template();
    if (bytes == null) return;
    final where = await files.save('transactions_template.xlsx', bytes);
    if (where != null && mounted) showMessage(context, 'Template saved');
  });

  Future<void> _import() async {
    final bytes = await files.pick();
    if (bytes == null) return;
    await _busy('Importing…', () async {
      final summary = await controller.import(bytes);
      if (summary != null && mounted) {
        showMessage(
          context,
          'Imported ${summary.imported}, skipped ${summary.duplicates} '
          'duplicate${summary.duplicates == 1 ? '' : 's'}',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final working = _working != null;
      final count = controller.entryCount;
      return Scaffold(
        appBar: AppBar(title: const Text('Import and export')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            SpaceSize.gutter,
            0,
            SpaceSize.gutter,
            SpaceSize.huge,
          ),
          children: [
            if (working)
              Padding(
                padding: const EdgeInsets.only(top: SpaceSize.small),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: SpaceSize.medium),
                    Text(_working!, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ErrorBanner(controller.error),
            const SectionHeader('Export to Excel'),
            SegmentedButton<ReportPeriod>(
              showSelectedIcon: false,
              segments: [
                for (final e in _periodLabels.entries)
                  ButtonSegment(value: e.key, label: Text(e.value)),
              ],
              selected: {controller.period},
              onSelectionChanged: (v) => v.first == ReportPeriod.custom
                  ? _pickCustomRange()
                  : controller.setPeriod(v.first),
            ),
            const SizedBox(height: SpaceSize.medium),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpaceSize.extraSmall,
                  SpaceSize.small,
                  SpaceSize.extraSmall,
                  SpaceSize.large,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (controller.canStep)
                          IconButton(
                            tooltip: 'Previous period',
                            onPressed: controller.previous,
                            icon: const Icon(Icons.chevron_left_rounded),
                          )
                        else
                          const SizedBox(width: SpaceSize.large),
                        Expanded(
                          child: Text(
                            controller.range.label,
                            textAlign: controller.canStep
                                ? TextAlign.center
                                : TextAlign.start,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (controller.canStep)
                          IconButton(
                            tooltip: 'Next period',
                            onPressed: controller.canGoNext
                                ? controller.next
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                          )
                        else
                          TextButton(
                            onPressed: _pickCustomRange,
                            child: const Text('Change'),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpaceSize.medium,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            count == null
                                ? ' '
                                : count == 1
                                ? '1 entry in this period'
                                : '$count entries in this period',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: SpaceSize.medium),
                          FilledButton.icon(
                            onPressed: working || count == 0 ? null : _export,
                            icon: const Icon(Icons.file_download_outlined),
                            label: const Text('Export to Excel'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const InfoNote(
              'Columns: Sr, Type, Category, Amount, Date, Account, Note, '
              'Owed person, Due date, Owed completed, Owed status, Tax paid. '
              'Dates include the time of day. '
              'Transfers show the account as From → To.',
            ),
            const SectionHeader('Import from Excel'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(CardSize.padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Use a file exported from this app, or the template. '
                      'Missing wallets and categories are created. Entries '
                      'that already exist (same type, account, amount and '
                      'date) are skipped.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SpaceSize.large),
                    FilledButton.tonalIcon(
                      onPressed: working ? null : _import,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('Choose Excel file'),
                    ),
                    const SizedBox(height: SpaceSize.small),
                    TextButton(
                      onPressed: working ? null : _template,
                      child: const Text('Save a blank template'),
                    ),
                  ],
                ),
              ),
            ),
            if (controller.lastImport case final summary?)
              _ImportResult(summary: summary),
          ],
        ),
      );
    },
  );
}

class _ImportResult extends StatelessWidget {
  const _ImportResult({required this.summary});
  final ImportSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    Widget stat(String label, int value, Color color, IconData icon) => AppTile(
      leading: IconBadge(
        icon,
        color: color,
        background: color.withValues(alpha: .12),
      ),
      title: label,
      trailing: Text(
        '$value',
        style: theme.textTheme.titleMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    const shown = 30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Last import'),
        GroupedCard(
          children: [
            stat(
              'Imported',
              summary.imported,
              colors.income,
              Icons.check_circle_outline_rounded,
            ),
            stat(
              'Skipped as duplicates',
              summary.duplicates,
              theme.colorScheme.onSurfaceVariant,
              Icons.content_copy_outlined,
            ),
            stat(
              'Problems',
              summary.issues.length,
              summary.issues.isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : colors.expense,
              Icons.error_outline_rounded,
            ),
          ],
        ),
        if (summary.issues.isNotEmpty) ...[
          const SizedBox(height: SpaceSize.medium),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(CardSize.padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final issue in summary.issues.take(shown))
                    Padding(
                      padding: const EdgeInsets.only(bottom: SpaceSize.small),
                      child: Text(
                        issue.toString(),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  if (summary.issues.length > shown)
                    Text(
                      '…and ${summary.issues.length - shown} more',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
