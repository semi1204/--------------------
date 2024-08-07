import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class ImageUrlCache {
  static final Map<String, String> _cache = {};

  static Future<String> getUrl(
      String key, Future<String> Function() fetcher) async {
    if (_cache.containsKey(key)) return _cache[key]!;
    final url = await fetcher();
    _cache[key] = url;
    return url;
  }
}

class NetworkImageWithLoader extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Logger logger;

  const NetworkImageWithLoader({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit,
    required this.logger,
  });

  @override
  _NetworkImageWithLoaderState createState() => _NetworkImageWithLoaderState();
}

class _NetworkImageWithLoaderState extends State<NetworkImageWithLoader> {
  late Future<String> _imageFuture;
  static const int maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _imageFuture = _getImageUrlWithRetry();
  }

  Future<String> _getImageUrlWithRetry() async {
    return ImageUrlCache.getUrl(widget.imageUrl, () async {
      for (int i = 0; i < maxRetries; i++) {
        try {
          return await _getImageUrl();
        } catch (e) {
          widget.logger.w('Retry ${i + 1} failed: $e');
          if (i == maxRetries - 1) rethrow;
          await Future.delayed(Duration(seconds: 1 * (i + 1)));
        }
      }
      throw Exception('Failed to load image after $maxRetries attempts');
    });
  }

  Future<String> _getImageUrl() async {
    widget.logger.d('Getting image URL for: ${widget.imageUrl}');
    try {
      if (widget.imageUrl.startsWith('gs://')) {
        final ref = FirebaseStorage.instance.refFromURL(widget.imageUrl);
        return await ref.getDownloadURL();
      } else if (widget.imageUrl.startsWith('http')) {
        // Firebase Storage URL 인코딩 처리
        final regex = RegExp(
            r'(https://firebasestorage\.googleapis\.com/v0/b/[^/]+/o/)([^?]+)(\?.*)?');
        final match = regex.firstMatch(widget.imageUrl);
        if (match != null) {
          final baseUrl = match.group(1)!;
          final filePath = match.group(2)!;
          final query = match.group(3) ?? '';
          final encodedFilePath = Uri.encodeComponent(filePath);
          final encodedUrl = '$baseUrl$encodedFilePath$query';
          widget.logger.d('Encoded URL: $encodedUrl');
          return encodedUrl;
        }
        widget.logger.d('URL is not a Firebase Storage URL, using as-is');
        return widget.imageUrl;
      } else {
        final ref = FirebaseStorage.instance.ref(widget.imageUrl);
        return await ref.getDownloadURL();
      }
    } catch (e) {
      widget.logger.e('Error getting image URL: $e');
      rethrow;
    }
  }

  Future<bool> _checkImageValidity(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      widget.logger.e('Error checking image validity: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          widget.logger.e('Error loading image: ${snapshot.error}');
          return _buildErrorWidget(context, snapshot.error.toString());
        } else if (snapshot.hasData) {
          return FutureBuilder<bool>(
            future: _checkImageValidity(snapshot.data!),
            builder: (context, validitySnapshot) {
              if (validitySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (validitySnapshot.data == true) {
                return CachedNetworkImage(
                  imageUrl: snapshot.data!,
                  width: widget.width,
                  height: widget.height,
                  fit: widget.fit ?? BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) {
                    widget.logger.e('Error loading image: $error');
                    return _buildErrorWidget(context, error.toString());
                  },
                );
              } else {
                return _buildErrorWidget(context, 'Invalid image URL');
              }
            },
          );
        } else {
          return _buildErrorWidget(context, 'Unknown error');
        }
      },
    );
  }

  Widget _buildErrorWidget(BuildContext context, String errorMessage) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(height: 8),
          Text('Image load failed',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(errorMessage,
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
              textAlign: TextAlign.center),
          ElevatedButton(
            onPressed: () {
              widget.logger.d('Retrying image load');
              setState(() {
                _imageFuture = _getImageUrlWithRetry();
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
