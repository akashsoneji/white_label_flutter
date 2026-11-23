import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';

/// Tile for attaching the payment proof file.
///
/// Empty, it invites the user to pick a file through [onPick]. Once
/// [fileName] is set it shows the file (with an image thumbnail when
/// [filePath] points to an image) and a remove button when [onRemove] is
/// given.
class ProofUploadTile extends StatelessWidget {
  final String? fileName;
  final String? filePath;
  final bool isRequired;
  final bool isUploading;
  final String? errorText;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  const ProofUploadTile({
    super.key,
    this.fileName,
    this.filePath,
    this.isRequired = false,
    this.isUploading = false,
    this.errorText,
    required this.onPick,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = this.fileName;
    final errorText = this.errorText;
    final hasFile = fileName != null && fileName.isNotEmpty;
    final hasError = errorText != null && errorText.isNotEmpty;
    final radius = BorderRadius.circular(14.r);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: hasError ? AppColors.error : AppColors.border,
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: isUploading ? null : onPick,
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: hasFile
                  ? _FilledContent(
                      fileName: fileName,
                      filePath: filePath,
                      isUploading: isUploading,
                      onRemove: onRemove,
                    )
                  : _EmptyContent(
                      isRequired: isRequired,
                      isUploading: isUploading,
                    ),
            ),
          ),
        ),
        if (hasError) ...[
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

class _EmptyContent extends StatelessWidget {
  final bool isRequired;
  final bool isUploading;

  const _EmptyContent({required this.isRequired, required this.isUploading});

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTextStyles.bodyText.copyWith(
      color: AppColors.textPrimary,
      fontSize: 14.sp,
      fontWeight: FontWeight.w700,
    );

    return Row(
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: AppColors.iconBgPrimary,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: isUploading
              ? Padding(
                  padding: EdgeInsets.all(9.w),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Icon(
                  Icons.upload_file_rounded,
                  color: AppColors.primary,
                  size: 20.sp,
                ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  text: TranslationUtils.tr(
                    'deposit_instruction_screen_upload_file',
                  ),
                  children: [
                    if (isRequired)
                      TextSpan(
                        text: ' *',
                        style: titleStyle.copyWith(color: AppColors.error),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
              SizedBox(height: 4.h),
              Text(
                TranslationUtils.tr('fv2_proof_helper'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyText.copyWith(
                  color: AppColors.textGrey,
                  fontSize: 11.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilledContent extends StatelessWidget {
  final String fileName;
  final String? filePath;
  final bool isUploading;
  final VoidCallback? onRemove;

  const _FilledContent({
    required this.fileName,
    required this.filePath,
    required this.isUploading,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final filePath = this.filePath;
    final fileIcon = Icon(
      Icons.insert_drive_file_outlined,
      color: AppColors.primary,
      size: 20.sp,
    );

    return Row(
      children: [
        Container(
          width: 44.w,
          height: 44.w,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.iconBgPrimary,
            borderRadius: BorderRadius.circular(12.r),
          ),
          // Non-image files (PDF) fail to decode and fall back to the icon.
          child: filePath == null || filePath.isEmpty
              ? fileIcon
              : Image.file(
                  File(filePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fileIcon,
                ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            fileName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        if (isUploading)
          SizedBox(
            width: 18.w,
            height: 18.w,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          )
        else if (onRemove != null)
          SizedBox(
            width: 40.w,
            height: 40.w,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: TranslationUtils.tr('general_remove'),
              onPressed: onRemove,
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.error,
                size: 18.sp,
              ),
            ),
          ),
      ],
    );
  }
}
