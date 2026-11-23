import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/custom_toast.dart';

import '../../data/finance_v2_repository.dart';
import '../../data/models/deposit_method_detail.dart';
import '../../data/models/deposit_submit_result.dart';
import '../widgets/copyable_info_row.dart';
import '../widgets/finance_v2_error_retry.dart';
import '../widgets/finance_v2_primary_button.dart';
import '../widgets/finance_v2_scaffold.dart';
import '../widgets/finance_v2_shimmer.dart';
import '../widgets/proof_upload_tile.dart';
import '../widgets/quote_changed_sheet.dart';
import 'deposit_details_controller.dart';
import 'deposit_flow_action.dart';
import 'deposit_labels.dart';
import 'deposit_navigation.dart';
import 'deposit_qr_image.dart';
import 'payment_wait_screen.dart';

/// Third deposit screen: where to pay and what the broker needs back (UTR,
/// proof, payer details).
///
/// Pops with `true` when the amount screen should load its cards again.
class DepositDetailsScreen extends StatefulWidget {
  final DepositDetailsArgs args;

  const DepositDetailsScreen({super.key, required this.args});

  @override
  State<DepositDetailsScreen> createState() => _DepositDetailsScreenState();
}

class _DepositDetailsScreenState extends State<DepositDetailsScreen> {
  late final String _tag = 'deposit_details_${identityHashCode(this)}';
  late final DepositDetailsController _controller;
  final Map<String, GlobalKey> _fieldKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      DepositDetailsController(
        repository: Get.find<FinanceV2Repository>(),
        args: widget.args,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<DepositDetailsController>(tag: _tag);
    super.dispose();
  }

  GlobalKey _keyFor(String fieldName) =>
      _fieldKeys.putIfAbsent(fieldName, GlobalKey.new);

  Future<void> _onBack() async {
    if (_controller.isAlreadySubmitted || !_controller.isDirty) {
      Get.back<bool>();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => const _DiscardDialog(),
    );
    if (discard == true) Get.back<bool>();
  }

  Future<void> _pickProof() async {
    final source = await showModalBottomSheet<_ProofSource>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (_) => const _ProofSourceSheet(),
    );
    if (source == null) return;

    try {
      final picked = switch (source) {
        _ProofSource.gallery => await FilePicker.pickFile(type: FileType.image),
        _ProofSource.file => await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: _proofFileExtensions,
          ),
      };
      final path = picked?.path;
      if (path == null) return;
      await _controller.setProof(File(path));
    } catch (_) {
      // The picker failed or the file cannot be read: same message as a
      // file that is not accepted.
      _controller.proofError.value = TranslationUtils.tr('fv2_proof_invalid');
    }
  }

  Future<void> _onSubmit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _handle(await _controller.submit());
  }

  void _scrollToFirstError() {
    final names = <String>[
      if (_controller.utrError != null) DepositDetailsController.utrField,
      if (_controller.proofError.value != null)
        DepositDetailsController.proofField,
      ..._controller.fieldErrors.keys,
    ];
    for (final name in names) {
      final fieldContext = _fieldKeys[name]?.currentContext;
      if (fieldContext == null) continue;
      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 250),
        alignment: 0.1,
      );
      return;
    }
  }

  Future<void> _handle(DepositFlowAction action) async {
    if (!mounted) return;
    switch (action) {
      case DepositFlowNone():
      case DepositFlowOpenDetails():
      case DepositFlowShowDetails():
        break;
      case DepositFlowFieldErrors():
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToFirstError(),
        );
      case DepositFlowRatesUpdated():
        CustomToastService.showInfo(
          message: TranslationUtils.tr('fv2_rates_updated'),
        );
      // The amount screen loads its cards again and shows the toast.
      case DepositFlowReloadChannels():
        Get.back<bool>(result: true);
      case DepositFlowRedirect(:final result):
        await Get.off<void>(
          () => PaymentWaitScreen(
            reference: result.referenceNumber,
            paymentUrl: result.paymentUrl,
          ),
        );
      case DepositFlowCreated(:final message):
        CustomToastService.showSuccess(
          message: message.isNotEmpty
              ? message
              : TranslationUtils.tr('fv2_deposit_submitted'),
        );
        openDepositTransactionHistory();
      case DepositFlowKyc():
        await openDepositKyc();
      case DepositFlowQuoteChanged(:final newQuote, :final oldYouGet):
        final confirmed = await showQuoteChangedSheet(
          context,
          newQuote: newQuote,
          oldYouGet: oldYouGet,
        );
        if (confirmed) {
          await _handle(await _controller.confirmNewQuote(newQuote));
        } else {
          Get.back<bool>(result: true);
        }
      case DepositFlowMessage(:final message):
        CustomToastService.showError(message: message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitted = widget.args.submitted;
    final channelName = widget.args.channel.name;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: FinanceV2Scaffold(
        title: channelName.isNotEmpty
            ? channelName
            : TranslationUtils.tr('deposit'),
        onBack: _onBack,
        bottomCta: submitted != null
            ? FinanceV2PrimaryButton(
                label: TranslationUtils.tr(
                  'cregis_address_screen_go_to_transaction_history',
                ),
                onPressed: openDepositTransactionHistory,
              )
            : Obx(
                () => FinanceV2PrimaryButton(
                  label: TranslationUtils.tr('common_submit'),
                  onPressed: _onSubmit,
                  isLoading: _controller.isSubmitting.value,
                  enabled: _controller.canSubmit,
                ),
              ),
        body: submitted != null
            ? _SubmittedBody(
                youPay: widget.args.quote.youPay,
                result: submitted,
              )
            : Obx(() {
                final detail = _controller.detail.value;
                final loadError = _controller.loadError.value;
                if (_controller.isLoading.value) {
                  return Padding(
                    padding: EdgeInsets.only(top: 12.h),
                    child: const Align(
                      alignment: Alignment.topCenter,
                      child: FinanceV2Shimmer.form(),
                    ),
                  );
                }
                if (detail == null) {
                  return FinanceV2ErrorRetry(
                    message: loadError ?? '',
                    onRetry: _controller.load,
                  );
                }
                return _DetailsForm(
                  controller: _controller,
                  detail: detail,
                  keyFor: _keyFor,
                  onPickProof: _pickProof,
                );
              }),
      ),
    );
  }
}

/// What the file browser offers; the proof validator has the final say.
const List<String> _proofFileExtensions = <String>['jpg', 'jpeg', 'png'];

enum _ProofSource { gallery, file }

/// Where the payment proof comes from.
class _ProofSourceSheet extends StatelessWidget {
  const _ProofSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 8.h),
          _ProofSourceTile(
            icon: Icons.photo_library_outlined,
            label: TranslationUtils.tr('deposit_instruction_choose_from_gallery'),
            source: _ProofSource.gallery,
          ),
          _ProofSourceTile(
            icon: Icons.insert_drive_file_outlined,
            label: TranslationUtils.tr('deposit_instruction_screen_upload_file'),
            source: _ProofSource.file,
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }
}

class _ProofSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final _ProofSource source;

  const _ProofSourceTile({
    required this.icon,
    required this.label,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: AppColors.textSecondary, size: 20.sp),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.bodyText.copyWith(
          color: AppColors.textPrimary,
          fontSize: 14.sp,
        ),
      ),
      onTap: () => Navigator.of(context).pop(source),
    );
  }
}

class _DiscardDialog extends StatelessWidget {
  const _DiscardDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      content: Text(
        TranslationUtils.tr('fv2_discard_deposit'),
        style: AppTextStyles.bodyText.copyWith(
          color: AppColors.textPrimary,
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            TranslationUtils.tr('general_cancel'),
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            TranslationUtils.tr('general_confirm'),
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.error,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// The amount to pay, as the server quoted it.
class _SummaryStrip extends StatelessWidget {
  final String youPay;

  const _SummaryStrip({required this.youPay});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            TranslationUtils.tr('fv2_you_pay'),
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textGrey,
              fontSize: 12.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              youPay,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the deposit already exists: where to pay and the reference.
class _SubmittedBody extends StatelessWidget {
  final String youPay;
  final DepositSubmitResult result;

  const _SubmittedBody({required this.youPay, required this.result});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      children: [
        _SummaryStrip(youPay: youPay),
        SizedBox(height: 8.h),
        if (result.referenceNumber.isNotEmpty)
          CopyableInfoRow(
            label: depositReferenceLabel(),
            value: result.referenceNumber,
          ),
        if (result.depositAddress.isNotEmpty)
          CopyableInfoRow(
            label: depositPayLineLabel('crypto_address'),
            value: result.depositAddress,
          ),
        if (result.accountNumber.isNotEmpty)
          CopyableInfoRow(
            label: depositPayLineLabel('account_number'),
            value: result.accountNumber,
          ),
      ],
    );
  }
}

class _DetailsForm extends StatelessWidget {
  final DepositDetailsController controller;
  final DepositMethodDetail detail;
  final GlobalKey Function(String fieldName) keyFor;
  final VoidCallback onPickProof;

  const _DetailsForm({
    required this.controller,
    required this.detail,
    required this.keyFor,
    required this.onPickProof,
  });

  @override
  Widget build(BuildContext context) => Obx(() => _buildForm());

  Widget _buildForm() {
    final proof = controller.proof.value;
    final gap = SizedBox(height: 12.h);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.symmetric(vertical: 12.h),
      children: [
        _SummaryStrip(youPay: controller.quote.value.youPay),
        if (detail.instructions.isNotEmpty) ...[
          SizedBox(height: 8.h),
          _InstructionCard(text: detail.instructions),
        ],
        if (detail.payLines.isNotEmpty) SizedBox(height: 8.h),
        for (final line in detail.payLines)
          CopyableInfoRow(
            label: depositPayLineLabel(line.key),
            value: line.value,
          ),
        if (detail.qrPath.isNotEmpty) ...[
          gap,
          _FieldLabel(text: TranslationUtils.tr('deposit_instruction_screen_qr_code')),
          SizedBox(height: 8.h),
          DepositQrImage(qrPath: detail.qrPath),
        ],
        if (detail.showUtr) ...[
          gap,
          _TextInput(
            key: keyFor(DepositDetailsController.utrField),
            label: TranslationUtils.tr(
              'deposit_instruction_screen_transaction_id_utr',
            ),
            hint: TranslationUtils.tr(
              'deposit_instruction_screen_enter_utr_or_transaction_reference',
            ),
            controller: controller.utrController,
            errorText: controller.utrError,
            forceLtr: true,
          ),
        ],
        if (detail.showProof) ...[
          gap,
          _FieldLabel(
            key: keyFor(DepositDetailsController.proofField),
            text: TranslationUtils.tr('deposit_instruction_screen_upload_file'),
          ),
          SizedBox(height: 4.h),
          ProofUploadTile(
            fileName: proof?.path.split(Platform.pathSeparator).last,
            filePath: proof?.path,
            isRequired: detail.requireProof,
            errorText: controller.proofError.value,
            onPick: onPickProof,
            onRemove: proof == null ? null : controller.removeProof,
          ),
          SizedBox(height: 4.h),
          Text(
            TranslationUtils.tr('fv2_proof_helper'),
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textGrey,
              fontSize: 11.sp,
            ),
          ),
        ],
        if (detail.clientNoteEnabled) ...[
          gap,
          _TextInput(
            key: keyFor(DepositDetailsController.noteField),
            label: TranslationUtils.tr('fv2_note_optional'),
            controller: controller.noteController,
            errorText: controller.errorFor(DepositDetailsController.noteField),
            maxLines: 3,
          ),
        ],
        for (final field in detail.payerFields) ...[
          gap,
          _PayerInput(
            key: keyFor(field.fieldName),
            field: field,
            controller: controller.payerControllers[field.key],
            errorText: controller.errorFor(field.fieldName),
            onOptionPicked: (value) =>
                controller.selectPayerValue(field, value),
          ),
        ],
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.bodyText.copyWith(
        color: AppColors.textSecondary,
        fontSize: 12.sp,
      ),
    );
  }
}

/// The broker's instructions, collapsed until the client opens them.
class _InstructionCard extends StatelessWidget {
  final String text;

  const _InstructionCard({required this.text});

  /// Instructions may come as rich text; tags are dropped, the wording stays.
  String get _plainText => text
      .replaceAll(RegExp(r'<br\s*/?>|</p>|</li>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .trim();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14.r);

    return Material(
      color: AppColors.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: AppColors.divider),
        child: ExpansionTile(
          dense: true,
          tilePadding: EdgeInsetsDirectional.symmetric(horizontal: 12.w),
          childrenPadding: EdgeInsetsDirectional.fromSTEB(12.w, 0, 12.w, 12.h),
          expandedAlignment: AlignmentDirectional.centerStart,
          iconColor: AppColors.textGrey,
          collapsedIconColor: AppColors.textGrey,
          title: Text(
            TranslationUtils.tr('deposit_instruction_screen_instruction'),
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [
            SelectableText(
              _plainText,
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final String? errorText;
  final int maxLines;
  final bool forceLtr;

  const _TextInput({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.maxLines = 1,
    this.forceLtr = false,
  });

  @override
  Widget build(BuildContext context) {
    final errorText = this.errorText;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: AppColors.border),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel(text: label),
        SizedBox(height: 4.h),
        TextField(
          controller: controller,
          maxLines: maxLines,
          textDirection: forceLtr ? TextDirection.ltr : null,
          style: AppTextStyles.bodyText.copyWith(
            color: AppColors.textPrimary,
            fontSize: 14.sp,
          ),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.textFieldBg,
            hintText: hint,
            hintStyle: AppTextStyles.bodyText.copyWith(
              color: AppColors.hint,
              fontSize: 13.sp,
            ),
            contentPadding: EdgeInsetsDirectional.symmetric(
              horizontal: 12.w,
              vertical: 12.h,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        if (errorText != null && errorText.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Text(
            errorText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.errorText,
              fontSize: 11.sp,
            ),
          ),
        ],
      ],
    );
  }
}

/// A `payer_<key>` field: free text, or a choice when the server sends
/// options.
class _PayerInput extends StatelessWidget {
  final PayerField field;
  final TextEditingController? controller;
  final String? errorText;

  /// Called with the value of the option that was picked. The field then
  /// shows that option's label.
  final ValueChanged<String> onOptionPicked;

  const _PayerInput({
    super.key,
    required this.field,
    required this.controller,
    required this.onOptionPicked,
    this.errorText,
  });

  Future<void> _pickOption(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(vertical: 8.h),
          children: [
            for (final option in field.options)
              ListTile(
                dense: true,
                title: Text(
                  option.label.isNotEmpty ? option.label : option.value,
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(option.value),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onOptionPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final label = field.label.isNotEmpty
        ? field.label
        : depositPayLineLabel(field.key);
    final input = _TextInput(
      label: label,
      controller: controller,
      errorText: errorText,
    );
    if (field.options.isEmpty) return input;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _pickOption(context),
      child: AbsorbPointer(child: input),
    );
  }
}
