import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/widgets/custom_toast.dart';
import 'package:http/http.dart' as http;

import '../../../../constants/color.dart';
import 'package:crm_app/screens/finance/view_models/deposit_instruction_controller.dart';
import '../../../../services/language_service.dart';
import '../../../../services/secure_storage_service.dart';
import '../../../../widgets/common_loading_widget.dart';
import '../../../../routes/app_pages.dart';
import 'package:crm_app/widgets/app_back_button.dart';

class DepositInstructionScreen extends StatefulWidget {
  final Map<String, dynamic> object;
  final String amountString;
  final String selectedMT5AccountID;
  final String? currency;
  final bool fromBonus;
  const DepositInstructionScreen({
    super.key,
    required this.object,
    required this.amountString,
    required this.selectedMT5AccountID,
    this.currency,
    this.fromBonus = false,
  });

  @override
  State<DepositInstructionScreen> createState() =>
      _DepositInstructionScreenState();
}

class _DepositInstructionScreenState extends State<DepositInstructionScreen> {
  late final String titleString;

  final DepositInstructionController controller = Get.put(
    DepositInstructionController(),
  );
  late final Map<String, dynamic>? bankDetail;
  late final LanguageService languageService;

  final TextEditingController transactionNumberController =
      TextEditingController();

  String _formatNetworkName(String key) {
    const names = {
      'trc20': 'TRC-20 (TRON)',
      'erc20': 'ERC-20 (Ethereum)',
      'bep20': 'BEP-20 (BSC)',
      'polygon': 'Polygon (MATIC)',
    };
    return names[key.toLowerCase()] ?? key.toUpperCase();
  }

  String _getNetworkCurrency(String key) {
    const currencies = {
      'trc20': 'USDT-TRC20',
      'erc20': 'USDT-ERC20',
      'bep20': 'USDT-BEP20',
      'polygon': 'USDT-POLYGON',
    };
    return currencies[key.toLowerCase()] ?? 'USDT';
  }

  // Get QR code path from payment gateway
  String? get qrCodePath {
    try {
      return widget.object['payment_gateway']?['qr_path']?.toString();
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    languageService = Get.find<LanguageService>();

    bankDetail = widget.object['payment_gateway'];
    if (widget.object['type'].toString().toLowerCase() == 'bank') {
      titleString = TranslationUtils.tr('deposit_instr_bank_transfer');
    } else if (widget.object['type'].toString().toLowerCase() == 'local') {
      titleString = TranslationUtils.tr('deposit_instr_local_transfer');
    } else if (widget.object['type'].toString().toLowerCase() == 'cregis') {
      titleString = widget.object['display_name']?.toString() ?? 'Cregis';
      _initCregisNetworks();
    } else if (widget.object['type'].toString().toLowerCase() == 'crypto') {
      titleString = widget.object['title']?.toString() ?? 'Crypto';
    } else {
      titleString = 'UPI';
    }
  }

  void _initCregisNetworks() {
    try {
      final networkMap =
          widget.object['payment_gateway']?['cregis_network_map'];
      if (networkMap != null && networkMap is Map) {
        controller.cregisNetworkMap = Map<String, dynamic>.from(networkMap);
        final keys = networkMap.keys.map((e) => e.toString()).toList();
        controller.cregisNetworks.assignAll(keys);

        final defaultChainId =
            widget.object['payment_gateway']?['deposit_chain_id']?.toString();
        if (defaultChainId != null && defaultChainId.isNotEmpty) {
          String? matchedNetwork;
          for (final entry in networkMap.entries) {
            final chainId =
                entry.value is Map ? entry.value['chain_id']?.toString() : null;
            if (chainId == defaultChainId) {
              matchedNetwork = entry.key.toString();
              break;
            }
          }
          controller.selectedCregisNetwork.value =
              matchedNetwork ?? (keys.isNotEmpty ? keys.first : '');
        } else if (keys.isNotEmpty) {
          controller.selectedCregisNetwork.value = keys.first;
        }
      }
    } catch (e) {
      print('Error initializing Cregis networks: $e');
    }
  }

  // Handle back navigation - go to Trading screen
  void _handleBackNavigation() {
    Get.offAllNamed(Routes.TRADING);
  }

  // Build QR code image widget with authentication
  Widget _buildQRCodeImage() {
    final qrPath = qrCodePath;
    if (qrPath == null || qrPath.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<Uint8List?>(
      future: _loadAuthenticatedImage(qrPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(Icons.error_outline, color: Colors.grey),
            ),
          );
        }

        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.whiteColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Image.memory(
            snapshot.data!,
            height: 200,
            width: 200,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(Icons.error_outline, color: Colors.grey),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Load image with authentication token
  Future<Uint8List?> _loadAuthenticatedImage(String url) async {
    try {
      final token = await SecureStorageService.getAuthToken();
      final request = http.Request('GET', Uri.parse(url));
      final headers = {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Accept': 'image/*',
      };
      request.headers.addAll(headers);

      // Log request
      final timestamp = DateTime.now().toIso8601String();
      print('═══════════════════════════════════════════════════════════');
      print('📤 DIRECT HTTP REQUEST [$timestamp]');
      print('═══════════════════════════════════════════════════════════');
      print('Method: GET');
      print('URL: $url');
      print('Headers: $headers');
      print('═══════════════════════════════════════════════════════════');

      final streamedResponse = await request.send();

      // Log response
      final statusEmoji =
          streamedResponse.statusCode >= 200 &&
                  streamedResponse.statusCode < 300
              ? '✅'
              : streamedResponse.statusCode >= 400
              ? '❌'
              : '⚠️';
      print('═══════════════════════════════════════════════════════════');
      print('$statusEmoji DIRECT HTTP RESPONSE [$timestamp]');
      print('═══════════════════════════════════════════════════════════');
      print('URL: $url');
      print('Status Code: ${streamedResponse.statusCode}');
      print('Headers: ${streamedResponse.headers}');
      print('═══════════════════════════════════════════════════════════');

      if (streamedResponse.statusCode == 200) {
        final bytes = await streamedResponse.stream.toBytes();
        print('Image loaded: ${bytes.length} bytes');
        return bytes;
      } else {
        print('Failed to load QR code image: ${streamedResponse.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      final timestamp = DateTime.now().toIso8601String();
      print('═══════════════════════════════════════════════════════════');
      print('❌ DIRECT HTTP ERROR [$timestamp]');
      print('═══════════════════════════════════════════════════════════');
      print('URL: $url');
      print('Error Type: ${e.runtimeType}');
      print('Error Message: $e');
      print('Stack Trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      return null;
    }
  }

  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.textPrimary),
                title: Text(
                  languageService.tr('deposit_instruction_take_photo'),
                  style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  controller.startCamera();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.textPrimary),
                title: Text(
                  languageService.tr('deposit_instruction_choose_from_gallery'),
                  style: AppTextStyles.bodyText.copyWith(color: AppColors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  controller.pickImageFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.object['type'].toString().toLowerCase();
    Widget body;
    if (type == 'bank') {
      body = _buildBankUI();
    } else if (type == 'crypto') {
      body = _buildCryptoUI();
    } else if (type == 'local') {
      body = _buildLocalUI();
    } else if (type == 'cregis') {
      body = _buildCregisUI();
    } else {
      body = _buildUPI();
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffold,
        appBar: AppBar(
          scrolledUnderElevation: 0,
          backgroundColor: AppColors.scaffold,
          elevation: 0,
          leading: const AppBackButton(),
          title: Text(titleString, style: AppTextStyles.screenTitle),
          shape: Border(
            bottom: BorderSide(color: AppColors.border, width: 1),
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            body,
            // Loading overlay
            Obx(
              () =>
                  controller.isLoading.value
                      ? Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.15),
                          alignment: Alignment.center,
                          child: const CommonLoadingWidget(isFullScreen: true),
                        ),
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankUI() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instruction Section
          Container(
            decoration: BoxDecoration(
              color: AppColors.isDarkMode
                  ? AppColors.backgroundDarkAlt
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ExpansionTile(
              iconColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              collapsedIconColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              textColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              collapsedTextColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              collapsedBackgroundColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              collapsedShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
              ),
              title: Text(
                languageService.tr('deposit_instruction_screen_instruction'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              childrenPadding: EdgeInsets.all(16),
              children: [
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_use_given_bank_details_to_make',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_you_need_to_take_a_screenshot',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_where_utr_transaction_number_is_clearly',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_upload_screenshot_in_given_upload_field',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_press_submit_button_to_submit_your',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_your_payment_will_be_credited_into',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_once_reflected_in_our_bank_account',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_transaction_limit_may_vary_as_per',
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // Bank Name
          if (bankDetail?['bank_name'] != null &&
              bankDetail!['bank_name'].toString().isNotEmpty) ...[
            _buildBankDetailRow(
              languageService.tr('kyc_bank_name'),
              bankDetail!['bank_name'],
            ),
            SizedBox(height: 16),
          ],

          // Bank Holder Name
          if (bankDetail?['holder_name'] != null &&
              bankDetail!['holder_name'].toString().isNotEmpty) ...[
            _buildBankDetailRow(
              languageService.tr(
                'deposit_instruction_screen_bank_holder_name',
              ),
              bankDetail!['holder_name'].toString(),
            ),
            SizedBox(height: 16),
          ],

          // Account Number
          if (bankDetail?['bank_account_no'] != null &&
              bankDetail!['bank_account_no'].toString().isNotEmpty) ...[
            _buildBankDetailRow(
              languageService.tr('wallet_account_number'),
              bankDetail!['bank_account_no'].toString(),
            ),
            SizedBox(height: 16),
          ],

          // IFSC Code
          if (bankDetail?['ifsc_iban'] != null &&
              bankDetail!['ifsc_iban'].toString().isNotEmpty) ...[
            _buildBankDetailRow(
              languageService.tr('deposit_instruction_screen_ifsc_code'),
              bankDetail!['ifsc_iban'].toString(),
            ),
            SizedBox(height: 24),
          ],

          _buildUTRField(),

          // File Upload Section
          // GestureDetector(
          //   onTap: () => _showImagePicker(context),
          //   child: Center(
          //     child: Container(
          //       width: double.infinity,
          //       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          //       decoration: BoxDecoration(
          //         color: Colors.grey[100],
          //         borderRadius: BorderRadius.circular(8),
          //         border: Border.all(
          //           color: Colors.grey,
          //           style: BorderStyle.solid,
          //         ),
          //       ),
          //       child: Obx(() {
          //         if (controller.selectedImage.value != null) {
          //           return Image.file(
          //             controller.selectedImage.value!,
          //             height: 120,
          //             fit: BoxFit.cover,
          //           );
          //         } else {
          //           return Column(
          //             children: [
          //               Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey[600]),
          //               SizedBox(height: 12),
          //               Text(
          //                 'Upload file',
          //                 style: AppTextStyles.bodyText.copyWith(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
          //               ),
          //             ],
          //           );
          //         }
          //       }),
          //     ),
          //   ),
          // ),
          GestureDetector(
            onTap: () => _showImagePicker(context),
            child: Center(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Obx(() {
                  if (controller.selectedImage.value != null) {
                    return Image.file(
                      controller.selectedImage.value!,
                      height: 120,
                      fit: BoxFit.cover,
                    );
                  } else {
                    return Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_upload_outlined,
                            size: 32,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          languageService.tr(
                            'deposit_instruction_screen_upload_file',
                          ),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }
                }),
              ),
            ),
          ),
          SizedBox(height: 32),

          // Submit Button
          _buildContinueButton(),
        ],
      ),
    );
  }

  Widget _buildUTRField() {
    final type = widget.object['type'].toString().toLowerCase();
    final requireUtr = widget.object['require_utr'] == true ||
        widget.object['require_utr'] == 1 ||
        widget.object['require_utr'].toString().toLowerCase() == 'true';

    // Show if type is bank (always show for bank) or if require_utr is true
    if (type != 'bank' && !requireUtr) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              TranslationUtils.tr(
                'deposit_instruction_screen_transaction_id_utr',
              ),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              ' *',
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        TextField(
          controller: transactionNumberController,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14.sp,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: TranslationUtils.tr(
              'deposit_instruction_screen_enter_utr_or_transaction_reference',
            ),
            hintStyle: AppTextStyles.bodyText.copyWith(
              fontSize: 14.sp,
              color: Colors.grey,
            ),
            filled: true,
            fillColor: AppColors.isDarkMode
                ? AppColors.backgroundDarkAlt
                : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          TranslationUtils.tr(
            'deposit_instruction_screen_transaction_id_is_filled_automatically_when',
          ),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 11.sp,
            color: Colors.grey,
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }

  // Helper for bank detail row
  Widget _buildBankDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Expanded(child: Text(value, style: AppTextStyles.label)),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                // Get.snackbar('Copied', '$label copied to clipboard');
                CustomToastService.showSuccess(
                message: TranslationUtils.trArgs(
                  'deposit_instruction_screen_label_copied_to_clipboard',
                  {'label': label},
                ),
                  title: languageService.tr('deposit_instruction_copied'),
                );
              },
              child: Container(
                padding: EdgeInsets.all(4),
                child: SvgPicture.asset(
                  "assets/svg/more/copy.svg",
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCryptoUI() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instruction Card
          Container(
            decoration: BoxDecoration(
              color: AppColors.isDarkMode
                  ? AppColors.backgroundDarkAlt
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ExpansionTile(
              iconColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              collapsedIconColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              textColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              collapsedTextColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              collapsedBackgroundColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              collapsedShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
              ),
              title: Text(
                languageService.tr('deposit_instruction_screen_instruction'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              childrenPadding: EdgeInsets.all(16),
              children: [
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_use_below_give_qr_code_to',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_alternatively_enter_your_upi_id_to',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_enter_amount_that_you_want_to',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_press_submit_button_to_submit_your',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_your_payment_will_be_credited_into_once',
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // QR Code Section (if available)
          if (qrCodePath != null && qrCodePath!.isNotEmpty) ...[
            Text(
              languageService.tr('deposit_instruction_screen_qr_code'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Center(child: _buildQRCodeImage()),
            SizedBox(height: 24),
          ],

          // Address Section
          if (bankDetail?['crypto_address'] != null &&
              bankDetail!['crypto_address'].toString().isNotEmpty) ...[
            Text(
              languageService.tr('deposit_instruction_screen_deposit_address'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.whiteColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      bankDetail!['crypto_address'].toString(),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(
                          text: bankDetail!['crypto_address'].toString(),
                        ),
                      );
                      CustomToastService.showSuccess(
                message: languageService.tr(
                  'cregis_address_screen_address_copied_to_clipboard',
                ),
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(4),
                      child: SvgPicture.asset(
                        "assets/svg/more/copy.svg",
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
          ],

          _buildUTRField(),

          // File Upload Section
          GestureDetector(
            onTap: () => _showImagePicker(context),
            child: Center(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Obx(() {
                  if (controller.selectedImage.value != null) {
                    return Image.file(
                      controller.selectedImage.value!,
                      height: 120,
                      fit: BoxFit.cover,
                    );
                  } else {
                    return Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_upload_outlined,
                            size: 32,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          languageService.tr(
                            'deposit_instruction_screen_upload_file',
                          ),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }
                }),
              ),
            ),
          ),

          SizedBox(height: 32),

          // Submit Button
          _buildContinueButton(),
          //
          // Obx(
          //       () =>
          //   controller.isLoading.value
          //       ? Center(child: OverlayLoadingWidget())
          //       : SizedBox.shrink(),
          // ),
        ],
      ),
    );
  }

  Widget _buildUPI() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instruction Card
          Container(
            decoration: BoxDecoration(
              color: AppColors.isDarkMode
                  ? AppColors.backgroundDarkAlt
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ExpansionTile(
              iconColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              collapsedIconColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              textColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              collapsedTextColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              collapsedBackgroundColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              collapsedShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
              ),
              title: Text(
                languageService.tr('deposit_instruction_screen_instruction'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              childrenPadding: EdgeInsets.all(16),
              children: [
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_use_below_give_qr_code_to',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_alternatively_enter_your_upi_id_to',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_enter_amount_that_you_want_to',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_press_submit_button_to_submit_your',
                  ),
                ),
                SizedBox(height: 8),
                _buildInstructionItem(
                  languageService.tr(
                    'deposit_instruction_screen_your_payment_will_be_credited_into_once',
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24),

          // QR Code Section (if available)
          if (qrCodePath != null && qrCodePath!.isNotEmpty) ...[
            Text(
              languageService.tr('deposit_instruction_screen_qr_code'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Center(child: _buildQRCodeImage()),
            SizedBox(height: 24),
          ],

          // UPI ID Section
          if (bankDetail?['upi_address'] != null &&
              bankDetail!['upi_address'].toString().isNotEmpty) ...[
            _buildBankDetailRow(
              languageService.tr('deposit_instruction_screen_scan_upi'),
              bankDetail!['upi_address'].toString(),
            ),
            SizedBox(height: 16),
          ],

          _buildUTRField(),

          // File Upload Section
          GestureDetector(
            onTap: () => _showImagePicker(context),
            child: Center(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Obx(() {
                  if (controller.selectedImage.value != null) {
                    return Image.file(
                      controller.selectedImage.value!,
                      height: 120,
                      fit: BoxFit.cover,
                    );
                  } else {
                    return Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cloud_upload_outlined,
                            size: 32,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          languageService.tr(
                            'deposit_instruction_screen_upload_file',
                          ),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }
                }),
              ),
            ),
          ),
          SizedBox(height: 32),

          // Submit Button
          _buildContinueButton(),
        ],
      ),
    );
  }

  Widget _buildLocalUI() {
    // For now, use same as _buildCryptoUI
    return _buildCryptoUI();
  }

  Widget _buildContinueButton() {
    return Obx(
      () => SafeArea(
        child: ElevatedButton(
          onPressed:
              controller.isLoading.value
                  ? null
                  : () {
                    print(widget.object);
                    final type = widget.object['type'].toString().toLowerCase();
                    final requireUtr = widget.object['require_utr'] == true ||
                        widget.object['require_utr'] == 1 ||
                        widget.object['require_utr'].toString().toLowerCase() == 'true';

                    // Enforce UTR / Transaction ID check if required or if it's bank type
                    if ((type == 'bank' || requireUtr) &&
                        transactionNumberController.text.trim().isEmpty) {
                      CustomToastService.showError(
                        message: TranslationUtils.tr(
                          'deposit_instruction_screen_please_enter_transaction_number_utr',
                        ),
                      );
                      return;
                    }

                    final Map<String, dynamic> payload = {
                      "gateway_method_id": widget.object['deposit_slug'],
                      "amount": widget.amountString,
                      "mt5_account_id": widget.selectedMT5AccountID,
                      "currency": widget.currency ?? "USD",
                    };

                    if (transactionNumberController.text.trim().isNotEmpty) {
                      final utrValue = transactionNumberController.text.trim();
                      payload["utr_referce"] = utrValue;
                      payload["utr"] = utrValue;
                      payload["transaction_number"] = utrValue;
                      payload["transaction_id"] = utrValue;
                    }

                    if (widget.fromBonus) {
                      payload["is_bonus"] = 1;
                    }

                    controller.submitDepositInstruction(payload);
                  },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.whiteColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: EdgeInsets.zero,
          ),
          child:
              controller.isLoading.value
                  ? ButtonLoadingWidget(size: 20.0, color: AppColors.whiteColor)
                  : Text(
                    languageService.tr("deposit_confirm_deposit"),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      height: 1.71,
                      fontWeight: FontWeight.w600,
                      color: AppColors.whiteColor,
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildCregisUI() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ExpansionTile(
              iconColor: AppColors.isDarkMode ? Colors.white : AppColors.primary,
              collapsedIconColor: AppColors.isDarkMode ? Colors.white : AppColors.primary,
              textColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              collapsedTextColor: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
              collapsedBackgroundColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              collapsedShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
              ),
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
              ),
              title: Text(
              languageService.tr('deposit_instruction_screen_crypto_deposit'),
                style: AppTextStyles.bodyText.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.isDarkMode ? Colors.white : AppColors.textPrimary,
                ),
              ),
              childrenPadding: EdgeInsets.all(16),
              children: [
            _buildInstructionItem(
              languageService.tr(
                'deposit_instruction_screen_choose_a_network_and_amount',
              ),
            ),
                SizedBox(height: 8),
                _buildInstructionItem(
              languageService.tr(
                'deposit_instruction_screen_we_will_generate_a_unique_deposit',
              ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Text(
              languageService.tr('deposit_instruction_screen_network'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14,
              color: AppColors.textGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Obx(() {
            final networks = controller.cregisNetworks;
            if (networks.isEmpty) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                        languageService.tr(
                          'deposit_instruction_screen_loading_networks',
                        ),
                  style: AppTextStyles.bodyText.copyWith(color: AppColors.textGrey),
                ),
              );
            }
            return GestureDetector(
              onTap: () => _showCregisNetworkDropdown(context),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.whiteColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        controller.selectedCregisNetwork.value.isEmpty
                          ? languageService.tr('kyc_crypto_network_hint')
                            : _formatNetworkName(
                              controller.selectedCregisNetwork.value,
                            ),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 16,
                          color:
                              controller.selectedCregisNetwork.value.isEmpty
                                  ? AppColors.textGrey
                                  : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, color: AppColors.textGrey),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 24),
          Obx(() {
            if (controller.cregisDepositAddress.value.isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                    TranslationUtils.trArgs(
                      'deposit_instruction_screen_only_send_currency_on_network',
                      {
                        'currency': _getNetworkCurrency(
                          controller.selectedCregisNetwork.value,
                        ),
                        'network': _formatNetworkName(
                          controller.selectedCregisNetwork.value,
                        ),
                      },
                    ),
                      style: AppTextStyles.bodyText.copyWith(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          Obx(() {
            if (controller.cregisCheckoutUrl.value.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TranslationUtils.tr(
                            'deposit_instruction_screen_payment_page_ready',
                          ),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          TranslationUtils.tr(
                            'deposit_instruction_screen_tap_confirm_to_open_the_payment',
                          ),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 12,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              );
            }

            if (controller.cregisDepositAddress.value.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.cregisQrPath.value.isNotEmpty) ...[
                  Center(child: _buildQRCodeImage()),
                  SizedBox(height: 24),
                ],
                Text(
                languageService.tr(
                  'deposit_instruction_screen_deposit_address',
                ),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 14,
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.whiteColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          controller.cregisDepositAddress.value,
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(
                              text: controller.cregisDepositAddress.value,
                            ),
                          );
                          CustomToastService.showSuccess(
                message: languageService.tr(
                  'cregis_address_screen_address_copied_to_clipboard',
                ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(4),
                          child: SvgPicture.asset(
                            'assets/svg/more/copy.svg',
                            colorFilter: ColorFilter.mode(
                              AppColors.primary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],
            );
          }),
          Obx(() {
            final status = controller.cregisPollingStatus.value;
            if (status.isEmpty) return const SizedBox.shrink();
            if (status == 'timeout') {
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  TranslationUtils.tr(
                    'deposit_instruction_screen_payment_verification_timed_out_check_transaction',
                  ),
                  style: AppTextStyles.bodyText.copyWith(fontSize: 13, color: Colors.orange.shade800),
                ),
              );
            }
            if (status == 'pending') {
              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        TranslationUtils.tr(
                          'deposit_instruction_screen_waiting_for_payment_polling',
                        ),
                        style: AppTextStyles.bodyText.copyWith(
                          fontSize: 13,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          }),
          SizedBox(height: 32),
          _buildCregisContinueButton(),
        ],
      ),
    );
  }

  void _showCregisNetworkDropdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Obx(() {
          final networks = controller.cregisNetworks;
          return ListView.separated(
            shrinkWrap: true,
            itemCount: networks.length,
            separatorBuilder:
                (_, __) => Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final network = networks[index];
              final isSelected =
                  controller.selectedCregisNetwork.value == network;
              return InkWell(
                onTap: () {
                  controller.selectedCregisNetwork.value = network;
                  controller.cregisDepositAddress.value = '';
                  controller.cregisQrPath.value = '';
                  controller.cregisCheckoutUrl.value = '';
                  Navigator.pop(ctx);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _formatNetworkName(network),
                          style: AppTextStyles.bodyText.copyWith(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check, color: AppColors.primary, size: 20),
                    ],
                  ),
                ),
              );
            },
          );
        });
      },
    );
  }

  Widget _buildCregisContinueButton() {
    return Obx(() {
      final hasAddress = controller.cregisDepositAddress.value.isNotEmpty;
      final hasCheckoutUrl = controller.cregisCheckoutUrl.value.isNotEmpty;
      final isGenerating = controller.isAddressLoading.value;
      final isSubmitting = controller.isLoading.value;

      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed:
              isGenerating || isSubmitting
                  ? null
                  : () {
                    if (hasAddress || hasCheckoutUrl) {
                      controller.submitCregisDeposit(
                        gatewayMethodId: widget.object['deposit_slug'],
                        amount: widget.amountString,
                        mt5AccountId: widget.selectedMT5AccountID,
                      );
                    } else {
                      controller.createCregisDepositAddress(
                        gatewayMethodId: widget.object['deposit_slug'],
                        amount: widget.amountString,
                        mt5AccountId: widget.selectedMT5AccountID,
                      );
                    }
                  },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.whiteColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            padding: EdgeInsets.zero,
          ),
          child:
              isGenerating
                  ? ButtonLoadingWidget(size: 20.0, color: AppColors.whiteColor)
                  : isSubmitting
                  ? ButtonLoadingWidget(size: 20.0, color: AppColors.whiteColor)
                  : Text(
                    hasCheckoutUrl
                        ? languageService.tr(
                          'deposit_instruction_screen_open_link_to_payment',
                        )
                        : hasAddress
                        ? languageService.tr('deposit_confirm_deposit')
                        : languageService.tr(
                          'deposit_instruction_screen_generate_address',
                        ),
                    style: AppTextStyles.bodyText.copyWith(
                      fontSize: 14.sp,
                      height: 1.71,
                      fontWeight: FontWeight.w600,
                      color: AppColors.whiteColor,
                    ),
                  ),
        ),
      );
    });
  }

  Widget _buildInstructionItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsetsDirectional.only(top: 8, end: 8),
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
