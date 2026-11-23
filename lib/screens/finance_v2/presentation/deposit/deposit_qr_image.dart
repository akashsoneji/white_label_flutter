import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import 'package:crm_app/constants/api_const.dart';
import 'package:crm_app/constants/color.dart';
import 'package:crm_app/services/secure_storage_service.dart';

const Duration _downloadTimeout = Duration(seconds: 15);

/// The pay-to QR code of a deposit method.
///
/// The image is protected: it is downloaded with the bearer token instead of
/// being handed to `Image.network`. It always sits on a white plate so it
/// scans in dark mode too. Tapping it opens a larger copy.
class DepositQrImage extends StatefulWidget {
  /// `qr_path` as the server sent it: a full URL or a path on the API host.
  final String qrPath;

  const DepositQrImage({super.key, required this.qrPath});

  @override
  State<DepositQrImage> createState() => _DepositQrImageState();
}

class _DepositQrImageState extends State<DepositQrImage> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _download();
  }

  @override
  void didUpdateWidget(DepositQrImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qrPath != widget.qrPath) _bytes = _download();
  }

  Uri _resolveUri() {
    final raw = widget.qrPath.trim();
    final parsed = Uri.parse(raw);
    if (parsed.hasScheme) return parsed;

    final base = ApiConstants.baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final path = raw.replaceFirst(RegExp(r'^/+'), '');
    return Uri.parse('$base/$path');
  }

  /// The token only goes to the API's own host over https; a QR code hosted
  /// anywhere else is fetched without it.
  bool _isApiHost(Uri uri) {
    final apiHost = Uri.tryParse(ApiConstants.baseUrl)?.host ?? '';
    return uri.scheme == 'https' &&
        apiHost.isNotEmpty &&
        uri.host.toLowerCase() == apiHost.toLowerCase();
  }

  Future<Uint8List> _download() async {
    final uri = _resolveUri();
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw http.ClientException('QR code is not a web address', uri);
    }
    final token = _isApiHost(uri)
        ? await SecureStorageService.getAuthToken()
        : null;
    // A timeout ends in the retry state instead of an endless spinner.
    final response = await http.get(
      uri,
      headers: <String, String>{
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ).timeout(_downloadTimeout);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw http.ClientException('QR code answered ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  void _retry() {
    setState(() {
      _bytes = _download();
    });
  }

  void _enlarge(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.pureWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: InkWell(
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final side = 160.w;

    return Center(
      child: Container(
        width: side,
        height: side,
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.border),
        ),
        child: FutureBuilder<Uint8List>(
          future: _bytes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              );
            }
            final bytes = snapshot.data;
            if (snapshot.hasError || bytes == null) {
              return IconButton(
                onPressed: _retry,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: AppColors.error,
                  size: 28.sp,
                ),
              );
            }
            return InkWell(
              onTap: () => _enlarge(bytes),
              child: Image.memory(bytes, fit: BoxFit.contain),
            );
          },
        ),
      ),
    );
  }
}
