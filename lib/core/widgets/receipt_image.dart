import 'dart:convert';

import 'package:flutter/material.dart';

/// Shows a receipt from Cloudinary URL or legacy inline base64 data URI.
class ReceiptImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  const ReceiptImage({super.key, required this.source, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No receipt image available', style: TextStyle(color: Colors.grey)),
      );
    }
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        fit: fit,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        },
        errorBuilder: (_, __, ___) => const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Could not load receipt image', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    try {
      final b64 = source.contains(',') ? source.split(',').last : source;
      final bytes = base64Decode(b64);
      return Image.memory(bytes, fit: fit);
    } catch (_) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No receipt image available', style: TextStyle(color: Colors.grey)),
      );
    }
  }
}
