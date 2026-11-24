import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:crm_app/constants/color.dart';
import 'package:crm_app/constants/text_styles.dart';
import 'package:crm_app/services/language_service.dart';
import 'package:crm_app/widgets/dashBorder.dart';

/// Tile for attaching the payment proof file.
///
/// Empty, it invites the user to pick a file through [onPick]. Once
/// [fileName] is set it shows the file (with an image thumbnail when
/// [filePath] points to an image) and a remove button when [onRemove] is
/// given.
class ProofUploadTile extends StatelessWidget {
  final String? fileName;
  final String? filePath;
  final bool isUploading;
  final String? errorText;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  const ProofUploadTile({
    super.key,
    this.fileName,
    this.filePath,
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
    final dashColor = hasError
        ? AppColors.error
        : AppColors.primary.withValues(alpha: 0.5);

    final content = InkWell(
      borderRadius: radius,
      onTap: isUploading ? null : onPick,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: hasFile ? 12.h : 16.h,
        ),
        child: hasFile
            ? _FilledContent(
                fileName: fileName,
                filePath: filePath,
                isUploading: isUploading,
                onRemove: onRemove,
              )
            : _EmptyContent(isUploading: isUploading),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: AppColors.cardBackground,
          // An attached file gets a solid border; the empty drop area is
          // dashed.
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: hasFile
                ? BorderSide(
                    color: hasError ? AppColors.error : AppColors.border,
                  )
                : BorderSide.none,
          ),
          child: hasFile
              ? content
              : DashedBorderBox(
                  color: dashColor,
                  radius: 14.r,
                  child: content,
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
  final bool isUploading;

  const _EmptyContent({required this.isUploading});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.iconBgPrimary,
              shape: BoxShape.circle,
            ),
            child: isUploading
                ? Padding(
                    padding: EdgeInsets.all(11.w),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.primary,
                    size: 22.sp,
                  ),
          ),
          SizedBox(height: 8.h),
          Text(
            TranslationUtils.tr('fv2_proof_helper'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText.copyWith(
              color: AppColors.textSecondary,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
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
