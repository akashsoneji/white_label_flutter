import 'dart:async';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crm_app/screens/ibm/data/ibm_api_provider.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

Map<String, dynamic>? _exportOf(dynamic body) {
  if (body is! Map || body['data'] is! Map) return null;
  final export = (body['data'] as Map)['export'];
  return export is Map ? Map<String, dynamic>.from(export) : null;
}

/// Starts a CSV export, polls `GET exports/{id}` until it is ready, then
/// downloads and opens it. Returns once the file is opened or it gives up.
Future<void> runIbmExport({
  required String kind,
  Map<String, dynamic> filters = const {},
}) async {
  final api = IbmApiProvider();
  final startRes = await api.startExport(kind: kind, filters: filters);
  final started = _exportOf(startRes.data);
  if (!startRes.success || started == null) {
    CustomToastService.showError(
      message: startRes.message ?? TranslationUtils.tr('ibm_export_failed'),
    );
    return;
  }
  CustomToastService.showSuccess(
    message: startRes.message ?? TranslationUtils.tr('ibm_export_preparing'),
  );

  final id = started['id'] is num ? (started['id'] as num).toInt() : 0;
  var export = started;
  // Exports are built by a queue worker; ~1 minute covers normal reports.
  for (var attempt = 0; attempt < 30; attempt++) {
    if (export['is_downloadable'] == true) break;
    final status = export['status']?.toString();
    if (status == 'failed' || export['error'] != null) {
      CustomToastService.showError(
        message:
            export['error']?.toString() ?? TranslationUtils.tr('ibm_export_failed'),
      );
      return;
    }
    await Future.delayed(const Duration(seconds: 2));
    final res = await api.getExportStatus(id);
    final polled = _exportOf(res.data);
    if (!res.success || polled == null) {
      CustomToastService.showError(
        message: res.message ?? TranslationUtils.tr('ibm_export_failed'),
      );
      return;
    }
    export = polled;
  }

  if (export['is_downloadable'] != true) {
    CustomToastService.showError(
      message: TranslationUtils.tr('ibm_export_still_preparing'),
    );
    return;
  }
  await downloadIbmExport(export);
}

/// Downloads a ready export to the documents directory and opens it.
Future<void> downloadIbmExport(Map<String, dynamic> export) async {
  final id = export['id'] is num ? (export['id'] as num).toInt() : 0;
  List<int>? bytes;
  try {
    bytes = await IbmApiProvider().downloadExport(id);
  } catch (_) {
    bytes = null;
  }
  if (bytes == null) {
    CustomToastService.showError(
      message: TranslationUtils.tr('ibm_export_download_failed'),
    );
    return;
  }
  final name = export['download_name']?.toString() ?? 'ib_export_$id.csv';
  await saveAndOpenIbmFile(name, bytes);
}

/// Writes [bytes] to the documents directory as [fileName] and opens it.
Future<void> saveAndOpenIbmFile(String fileName, List<int> bytes) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    CustomToastService.showSuccess(
      message: TranslationUtils.tr('ibm_export_downloaded'),
    );
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      CustomToastService.showError(message: result.message);
    }
  } catch (_) {
    CustomToastService.showError(
      message: TranslationUtils.tr('ibm_export_download_failed'),
    );
  }
}

