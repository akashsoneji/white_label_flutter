import 'dart:io';

/// Standard API envelope used across HTTP helpers and repositories.
class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;

  ApiResponse({required this.success, this.message, this.data});

  factory ApiResponse.success(T data) => ApiResponse(success: true, data: data);

  factory ApiResponse.error(String message, {T? data}) =>
      ApiResponse(success: false, message: message, data: data);
}

/// One file + metadata for multi-file uploads.
class FileUploadData {
  final File file;
  final String documentType;
  final String subdocumentType;

  FileUploadData({
    required this.file,
    required this.documentType,
    required this.subdocumentType,
  });
}
