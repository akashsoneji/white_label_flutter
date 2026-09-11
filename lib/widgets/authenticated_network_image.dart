import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/secure_storage_service.dart';
import '../services/language_service.dart';

/// Fetches an image with a Bearer auth token attached and renders the
/// returned bytes via [Image.memory]. Caches the result in-memory so
/// repeated builds (e.g. inside an Obx) don't re-download.
class AuthenticatedNetworkImage extends StatefulWidget {
  const AuthenticatedNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  State<AuthenticatedNetworkImage> createState() =>
      _AuthenticatedNetworkImageState();
}

class _AuthenticatedNetworkImageState
    extends State<AuthenticatedNetworkImage> {
  // Module-level cache keyed by URL so that re-renders re-use the bytes.
  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  Uint8List? _bytes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedNetworkImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.url.isEmpty) {
      setState(
        () =>
            _error = TranslationUtils.tr('authenticated_network_image_no_image'),
      );
      return;
    }
    final cached = _cache[widget.url];
    if (cached != null) {
      setState(() => _bytes = cached);
      return;
    }
    try {
      final token = await SecureStorageService.getAuthToken();
      final headers = <String, String>{
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      };
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(widget.url));
        headers.forEach((k, v) => request.headers.set(k, v));
        final streamed = await request.close().timeout(
              const Duration(seconds: 15),
            );
        final chunks = await streamed.fold<List<int>>(
          <int>[],
          (prev, chunk) => prev..addAll(chunk),
        );
        if (streamed.statusCode >= 200 &&
            streamed.statusCode < 300 &&
            chunks.isNotEmpty) {
          final bytes = Uint8List.fromList(chunks);
          _cache[widget.url] = bytes;
          if (!mounted) return;
          setState(() => _bytes = bytes);
          return;
        }
        if (!mounted) return;
        setState(() => _error = 'HTTP ${streamed.statusCode}');
      } finally {
        client.close(force: false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_bytes != null) {
      child = Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
      );
    } else if (_error != null) {
      child = Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image,
          color: Colors.grey.shade500,
        ),
      );
    } else {
      child = Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (widget.borderRadius != null) {
      child = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: child,
      );
    }
    return child;
  }
}
