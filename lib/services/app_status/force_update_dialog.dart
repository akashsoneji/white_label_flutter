import 'dart:io';
import 'package:crm_app/flavor_config.dart';
import 'package:crm_app/widgets/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/app_status/app_status_controller.dart';
import 'package:crm_app/services/app_status/in_app_update_service.dart';
import 'package:crm_app/screens/common/webview_screen.dart';
import 'package:crm_app/services/language_service.dart';

enum UpdateDialogState {
  idle,
  downloading,
  installing,
  openingStore,
  error,
}

class ForceUpdateDialog extends StatefulWidget {
  final bool isForceUpdate;

  const ForceUpdateDialog({super.key, required this.isForceUpdate});

  @override
  State<ForceUpdateDialog> createState() => _ForceUpdateDialogState();
}

class _ForceUpdateDialogState extends State<ForceUpdateDialog> {
  UpdateDialogState _state = UpdateDialogState.idle;
  double? _downloadProgress;
  String? _downloadError;
  String? _downloadedSizeLabel;

  Future<void> _handleUpdateTap() async {
    final controller = Get.find<AppStatusController>();
    final updateUrl = controller.statusData.value?.updateUrlAndroid;

    if (updateUrl == null || updateUrl.isEmpty) {
      setState(() {
        _state = UpdateDialogState.error;
        _downloadError = TranslationUtils.tr('update_no_url_found');
      });
      return;
    }

    final isApk = InAppUpdateService.instance.isApkUrl(updateUrl);

    // If NOT an APK URL, open in WebView
    if (!isApk) {
      Get.to(
        () => WebViewScreen(
          url: updateUrl,
          title: TranslationUtils.tr('general_update'),
        ),
      );
      return;
    }

    // APK URL — download and install
    setState(() {
      _state = UpdateDialogState.downloading;
      _downloadProgress = 0.0;
      _downloadError = null;
      _downloadedSizeLabel = TranslationUtils.tr('update_starting_download');
    });

    final result = await InAppUpdateService.instance.downloadAndInstall(
      updateUrl,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            final percent = (progress * 100).toStringAsFixed(0);
            _downloadedSizeLabel = TranslationUtils.trArgs(
              'update_percent_complete',
              {'percent': percent},
            );
          });
        }
      },
    );

    if (!mounted) return;

    switch (result) {
      case DownloadResult.success:
        setState(() {
          _state = UpdateDialogState.installing;
          _downloadProgress = 1.0;
          _downloadedSizeLabel = TranslationUtils.tr('update_ready_to_install');
        });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _state = UpdateDialogState.idle);
        break;
      case DownloadResult.error:
        setState(() {
          _state = UpdateDialogState.error;
          _downloadError = TranslationUtils.tr('update_download_failed_message');
        });
        break;
    }
  }

  void _retry() {
    setState(() {
      _state = UpdateDialogState.idle;
      _downloadError = null;
      _downloadProgress = null;
    });
  }

  Color get _accentColor {
    switch (_state) {
      case UpdateDialogState.downloading:
        return AppColors.brandPrimary;
      case UpdateDialogState.installing:
        return AppColors.success;
      case UpdateDialogState.openingStore:
        return AppColors.brandPrimary;
      case UpdateDialogState.error:
        return AppColors.error;
      case UpdateDialogState.idle:
        return AppColors.brandPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppStatusController>();
    final releaseNotes = controller.statusData.value?.releaseNotes;
    final latestVersion =
        controller.statusData.value?.appVersion ??
        controller.latestVersion.value;
    final androidUrl = controller.statusData.value?.updateUrlAndroid ?? '';
    final hasApkUrl = Platform.isAndroid &&
        androidUrl.isNotEmpty &&
        InAppUpdateService.instance.isApkUrl(androidUrl);

    final bool isDark = AppColors.isDarkMode;
    final Color cardColor = isDark
        ? AppColors.surfaceDark
        : AppColors.whiteColor;
    final Color titleColor = AppColors.textPrimary;
    final Color subtitleColor = AppColors.textSecondary;
    final Color cardBorder = isDark
        ? AppColors.surfaceDark.withValues(alpha: 0.5)
        : AppColors.surfaceLight;
    final Color cardSurface = isDark
        ? AppColors.surfaceDarkAlt
        : AppColors.surfaceNeutralLight;
    final Color shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.5)
        : Colors.black;

    return PopScope(
      canPop: !widget.isForceUpdate,
      child: Material(
        child: Container(
          color: isDark
              ? Colors.black.withValues(alpha: 0.7)
              : Colors.black.withValues(alpha: 0.45),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(28.r),
                      border: Border.all(
                        color: cardBorder,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: shadowColor.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: _accentColor.withValues(alpha: isDark ? 0.1 : 0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(28.w, 32.w, 28.w, 28.w),
                          child: Column(
                            children: [
                              _buildIcon(isDark),
                              SizedBox(height: 20.h),

                              Text(
                                _getTitle(),
                                style: AppTextStyles.heading.copyWith(
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8.h),

                              Text(
                                _getSubtitle(latestVersion),
                                style: AppTextStyles.bodyText.copyWith(
                                  fontSize: 14.sp,
                                  color: subtitleColor,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              if (_state != UpdateDialogState.idle &&
                                  _state != UpdateDialogState.error) ...[
                                SizedBox(height: 24.h),
                                _buildStateContent(isDark),
                              ],

                              if (releaseNotes != null && releaseNotes.isNotEmpty) ...[
                                SizedBox(height: 20.h),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(14.w),
                                  decoration: BoxDecoration(
                                    color: cardSurface,
                                    borderRadius: BorderRadius.circular(14.r),
                                    border: Border.all(
                                      color: cardBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.new_releases_outlined,
                                            size: 14.w,
                                            color: _accentColor,
                                          ),
                                          SizedBox(width: 6.w),
                                          Text(
                                            TranslationUtils.tr(
                                              'update_whats_new',
                                            ),
                                            style: AppTextStyles.bodyText.copyWith(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                              color: subtitleColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        releaseNotes,
                                        style: AppTextStyles.bodyText.copyWith(
                                          fontSize: 13.sp,
                                          color: titleColor.withValues(alpha: 0.8),
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              SizedBox(height: 28.h),

                              _buildActions(hasApkUrl, isDark),
                              if (!widget.isForceUpdate && _state == UpdateDialogState.idle) ...[
                                SizedBox(height: 16.h),
                                GestureDetector(
                                  onTap: () {
                                    controller.skipUpdateFor24Hours();
                                    Get.back(closeOverlays: true);
                                    controller.resetForceUpdateDialogFlag();
                                  },
                                  child: Text(
                                    TranslationUtils.tr('update_remind_me_later'),
                                    style: AppTextStyles.bodyText.copyWith(
                                      fontSize: 14.sp,
                                      color: subtitleColor.withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_state) {
      case UpdateDialogState.downloading:
        return TranslationUtils.tr('update_downloading_update');
      case UpdateDialogState.installing:
        return TranslationUtils.tr('update_ready_to_install_title');
      case UpdateDialogState.openingStore:
        return TranslationUtils.tr('update_opening_app_store');
      case UpdateDialogState.error:
        return TranslationUtils.tr('update_download_failed');
      case UpdateDialogState.idle:
        return TranslationUtils.tr('update_available');
    }
  }

  String _getSubtitle(String latestVersion) {
    switch (_state) {
      case UpdateDialogState.downloading:
        return _downloadedSizeLabel ?? TranslationUtils.tr('update_please_wait');
      case UpdateDialogState.installing:
        return TranslationUtils.tr('update_tap_install_system_prompt');
      case UpdateDialogState.openingStore:
        return TranslationUtils.tr('update_taking_you_to_store');
      case UpdateDialogState.error:
        return _downloadError ??
            TranslationUtils.tr('general_something_went_wrong');
      case UpdateDialogState.idle:
        return TranslationUtils.trArgs('update_version_ready_message', {
          'version': latestVersion,
        });
    }
  }


  Widget _buildIcon(bool isDark) {
    final bool isDownloading = _state == UpdateDialogState.downloading;

    return SizedBox(
      width: 96.w,
      height: 96.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 96.w,
            height: 96.w,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 4.w,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                _accentColor.withValues(alpha: isDownloading ? 0.2 : 0.15),
              ),
            ),
          ),
          if (isDownloading)
            SizedBox(
              width: 96.w,
              height: 96.w,
              child: CircularProgressIndicator(
                value: _downloadProgress ?? 0,
                strokeWidth: 4.w,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                strokeCap: StrokeCap.round,
              ),
            ),
          Container(
            width: 88.w,
            height: 88.w,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withValues(alpha: isDark ? 0.15 : 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: BrandLogo(
                source: FlavorConfig.effectiveLogo,
                height: 80.w,
                width: 100.w,
                isCircle: true,
              ),
            ),
          ),
          if (isDownloading)
            Positioned(
              bottom: 4.h,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: _accentColor,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  '${((_downloadProgress ?? 0) * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStateContent(bool isDark) {
    switch (_state) {
      case UpdateDialogState.downloading:
        return _buildDownloadingContent(isDark);
      case UpdateDialogState.installing:
        return _buildInstallingContent(isDark);
      case UpdateDialogState.openingStore:
        return _buildOpeningStoreContent(isDark);
      case UpdateDialogState.error:
      case UpdateDialogState.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDownloadingContent(bool isDark) {
    final Color trackColor = isDark
        ? AppColors.progressTrackDark
        : AppColors.surfaceLight;

    return Column(
      children: [
        Container(
          height: 8.h,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(4.h),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: constraints.maxWidth *
                        ((_downloadProgress ?? 0).clamp(0.0, 1.0)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _accentColor,
                          _accentColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4.h),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 12.w,
              color: AppColors.textGrey,
            ),
            SizedBox(width: 4.w),
            Text(
              TranslationUtils.tr('update_do_not_close_app'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 12.sp,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstallingContent(bool isDark) {
    final Color bgColor = isDark
        ? AppColors.success.withValues(alpha: 0.15)
        : AppColors.successBg;
    final Color borderColor = isDark
        ? AppColors.success.withValues(alpha: 0.3)
        : AppColors.successBorderLight;
    final Color textColor = isDark
        ? AppColors.success.withValues(alpha: 0.9)
        : AppColors.successTextLight;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              Icons.android_rounded,
              size: 20.w,
              color: _accentColor,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TranslationUtils.tr('update_tap_install_when_prompted'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  TranslationUtils.tr('update_allow_unknown_apps'),
                  style: AppTextStyles.bodyText.copyWith(
                    fontSize: 12.sp,
                    color: textColor.withValues(alpha: 0.85),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningStoreContent(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 20.w,
          height: 20.w,
          child: CircularProgressIndicator(
            strokeWidth: 2.5.w,
            valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          TranslationUtils.tr('update_redirecting_to_store'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 13.sp,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(bool hasApkUrl, bool isDark) {
    switch (_state) {
      case UpdateDialogState.downloading:
        return _buildDownloadingActions(hasApkUrl, isDark);
      case UpdateDialogState.installing:
        return _buildInstallingActions(isDark);
      case UpdateDialogState.openingStore:
        return _buildOpeningStoreActions(isDark);
      case UpdateDialogState.error:
        return _buildErrorActions(isDark);
      case UpdateDialogState.idle:
        return _buildIdleActions(hasApkUrl, isDark);
    }
  }

  Widget _buildIdleActions(bool hasApkUrl, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _handleUpdateTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          elevation: 0,
          shadowColor: _accentColor.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasApkUrl ? Icons.download_rounded : Icons.open_in_new_rounded,
              size: 20.w,
              color: AppColors.onColoredBackground,
            ),
            SizedBox(width: 10.w),
            Text(
              hasApkUrl
                  ? TranslationUtils.tr('update_download_and_install')
                  : TranslationUtils.tr('update_update_now'),
              style: AppTextStyles.bodyText.copyWith(
                color: AppColors.onColoredBackground,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadingActions(bool hasApkUrl, bool isDark) {
    final Color btnBg = isDark
        ? _accentColor.withValues(alpha: 0.15)
        : _accentColor.withValues(alpha: 0.08);
    final Color btnBorder = isDark
        ? _accentColor.withValues(alpha: 0.3)
        : _accentColor.withValues(alpha: 0.2);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          decoration: BoxDecoration(
            color: btnBg,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: btnBorder, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20.w,
                height: 20.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5.w,
                  valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                TranslationUtils.trArgs('update_downloading_percent', {
                  'percent': ((_downloadProgress ?? 0) * 100).toStringAsFixed(0),
                }),
                style: AppTextStyles.bodyText.copyWith(
                  color: _accentColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!widget.isForceUpdate) ...[
          SizedBox(height: 12.h),
          GestureDetector(
            onTap: null,
            child: Text(
              TranslationUtils.tr('update_remind_me_later'),
              style: AppTextStyles.bodyText.copyWith(
                fontSize: 13.sp,
                color: AppColors.textGrey,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInstallingActions(bool isDark) {
    final Color bgColor = isDark
        ? AppColors.success.withValues(alpha: 0.15)
        : AppColors.successBg;
    final Color borderColor = isDark
        ? AppColors.success.withValues(alpha: 0.3)
        : AppColors.successBorderLight;
    final Color textColor = isDark
        ? AppColors.success.withValues(alpha: 0.9)
        : AppColors.successTextLight;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 20.w,
                color: _accentColor,
              ),
              SizedBox(width: 10.w),
              Text(
                TranslationUtils.tr('update_download_complete'),
                style: AppTextStyles.bodyText.copyWith(
                  color: textColor,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          TranslationUtils.tr('update_system_installer_opened'),
          style: AppTextStyles.bodyText.copyWith(
            fontSize: 12.sp,
            color: AppColors.textGrey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildOpeningStoreActions(bool isDark) {
    final Color btnBg = isDark
        ? _accentColor.withValues(alpha: 0.15)
        : _accentColor.withValues(alpha: 0.08);
    final Color btnBorder = isDark
        ? _accentColor.withValues(alpha: 0.3)
        : _accentColor.withValues(alpha: 0.2);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: btnBg,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: btnBorder, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20.w,
            height: 20.w,
            child: CircularProgressIndicator(
              strokeWidth: 2.5.w,
              valueColor: AlwaysStoppedAnimation<Color>(_accentColor),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            TranslationUtils.tr('update_opening_app_store_progress'),
            style: AppTextStyles.bodyText.copyWith(
              color: _accentColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorActions(bool isDark) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _retry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 20.w,
                  color: AppColors.onColoredBackground,
                ),
                SizedBox(width: 10.w),
                Text(
                  TranslationUtils.tr('my_plans_tab_try_again'),
                  style: AppTextStyles.bodyText.copyWith(
                    color: AppColors.onColoredBackground,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10.h),
        GestureDetector(
          onTap: () {
            Get.back(closeOverlays: true);
            Get.find<AppStatusController>().resetForceUpdateDialogFlag();
          },
          child: Text(
            TranslationUtils.tr('update_skip_this_version'),
            style: AppTextStyles.bodyText.copyWith(
              fontSize: 13.sp,
              color: AppColors.textGrey,
            ),
          ),
        ),
      ],
    );
  }
}