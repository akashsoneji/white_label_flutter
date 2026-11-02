import 'dart:typed_data';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/screens/finance/view_models/transaction_history_controller.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/app_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

enum _ProofStatus { loading, image, unsupported, notFound, error }

/// Full-screen, zoomable preview of the deposit proof a client uploaded.
class ProofViewerScreen extends StatefulWidget {
  const ProofViewerScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  State<ProofViewerScreen> createState() => _ProofViewerScreenState();
}

class _ProofViewerScreenState extends State<ProofViewerScreen> {
  final _controller = Get.find<TransactionHistoryController>();
  final _languageService = Get.find<LanguageService>();

  _ProofStatus _status = _ProofStatus.loading;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadProof();
  }

  Future<void> _loadProof() async {
    setState(() => _status = _ProofStatus.loading);
    try {
      final response = await _controller.fetchProof(widget.transactionId);
      if (!mounted) return;

      if (response.statusCode == 404) {
        setState(() => _status = _ProofStatus.notFound);
        return;
      }
      if (response.statusCode != 200) {
        setState(() => _status = _ProofStatus.error);
        return;
      }

      // PDFs can't be rendered inline; anything else is tried as an image.
      final isPdf = (response.headers['content-type'] ?? '').contains('pdf');
      setState(() {
        _bytes = response.bodyBytes;
        _status = isPdf ? _ProofStatus.unsupported : _ProofStatus.image;
      });
    } catch (_) {
      if (mounted) setState(() => _status = _ProofStatus.error);
    }
  }

  void _download() => _controller.viewReceipt(widget.transactionId);

  @override
  Widget build(BuildContext context) {
    final canDownload =
        _status == _ProofStatus.image || _status == _ProofStatus.unsupported;

    return Scaffold(
      appBar: AppBar(
          leading: Padding(
        padding: EdgeInsetsDirectional.only(start: 8.w),
        child: AppBackButton(
          // onPressed: _handleBack,
        ),
      ),
        title: Text(
          _languageService.tr('transaction_history_proof_title'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (canDownload)
            IconButton(
              tooltip: _languageService.tr('common_download'),
              onPressed: _download,
              icon: Icon(Icons.download_rounded, color: AppColors.primary),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _ProofStatus.loading:
        return Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      case _ProofStatus.notFound:
        return _ProofMessage(
          icon: Icons.image_not_supported_outlined,
          message: _languageService.tr(
            'transaction_history_controller_proof_not_available',
          ),
        );
      case _ProofStatus.error:
        return _ProofMessage(
          icon: Icons.error_outline_rounded,
          message: _languageService.tr('transaction_history_proof_load_failed'),
          actionLabel: _languageService.tr('transaction_history_proof_retry'),
          onAction: _loadProof,
        );
      case _ProofStatus.unsupported:
        return _unsupportedMessage();
      case _ProofStatus.image:
        return InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: SizedBox.expand(
            child: Image.memory(
              _bytes!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _unsupportedMessage(),
            ),
          ),
        );
    }
  }

  Widget _unsupportedMessage() {
    return _ProofMessage(
      icon: Icons.insert_drive_file_outlined,
      message: _languageService.tr(
        'transaction_history_proof_preview_unavailable',
      ),
      actionLabel: _languageService.tr('common_download'),
      onAction: _download,
    );
  }
}

class _ProofMessage extends StatelessWidget {
  const _ProofMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56.sp, color: AppColors.textSecondary),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 16.h),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
