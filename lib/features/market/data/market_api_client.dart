import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/market_failure.dart';

typedef MarketRequest = Future<MarketHttpResponse> Function(Uri uri);
typedef MarketPostRequest = Future<MarketHttpResponse> Function(
  Uri uri,
  String body,
);

class MarketHttpResponse {
  const MarketHttpResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

class MarketApiClient {
  MarketApiClient({
    required this.baseUrl,
    MarketRequest? request,
    MarketPostRequest? post,
    this.requestTimeout = const Duration(seconds: 10),
  }) : _request = request ?? _ioRequest,
       _post = post ?? _ioPost;

  final String baseUrl;
  final Duration requestTimeout;
  final MarketRequest _request;
  final MarketPostRequest _post;

  Future<Map<String, dynamic>> getQuoteJson({
    required String symbol,
    required String assetType,
    String currency = 'IDR',
  }) async {
    final normalizedSymbol = symbol.trim().toUpperCase();
    if (normalizedSymbol.isEmpty) {
      throw const MarketInvalidResponse('Symbol market tidak boleh kosong.');
    }
    final uri = _quoteUri(normalizedSymbol, assetType, currency);
    late final MarketHttpResponse response;
    try {
      response = await _request(uri).timeout(requestTimeout);
    } on TimeoutException {
      throw const MarketTimeout('Permintaan harga pasar melewati batas waktu.');
    } on SocketException {
      throw const MarketNetworkUnavailable('Market API tidak tersedia.');
    } on MarketFailure {
      rethrow;
    } catch (_) {
      throw const MarketNetworkUnavailable('Market API tidak tersedia.');
    }

    if (response.statusCode == 404) {
      throw const MarketNotFound('Harga aset tidak ditemukan.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MarketServerError(
        'Market API mengalami gangguan.',
        response.statusCode,
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      return decoded.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
    } on MarketFailure {
      rethrow;
    } catch (_) {
      throw const MarketInvalidResponse('Respons Market API tidak valid.');
    }
  }

  Future<Map<String, dynamic>> getBatchQuotesJson({
    required List<MarketQuoteRequestPayload> assets,
    String currency = 'IDR',
  }) async {
    if (assets.isEmpty) return const {'quotes': <dynamic>[]};
    final uri = _batchUri();
    late final MarketHttpResponse response;
    try {
      response = await _post(
        uri,
        jsonEncode({
          'assets': [
            for (final asset in assets)
              {'symbol': asset.symbol, 'type': asset.assetType},
          ],
          'currency': currency.trim().toUpperCase(),
        }),
      ).timeout(requestTimeout);
    } on TimeoutException {
      throw const MarketTimeout('Permintaan harga pasar melewati batas waktu.');
    } on SocketException {
      throw const MarketNetworkUnavailable('Market API tidak tersedia.');
    } on MarketFailure {
      rethrow;
    } catch (_) {
      throw const MarketNetworkUnavailable('Market API tidak tersedia.');
    }
    if (response.statusCode == 404) {
      throw const MarketNotFound('Endpoint harga pasar tidak ditemukan.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MarketServerError(
        'Market API mengalami gangguan.',
        response.statusCode,
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      return decoded.map<String, dynamic>(
        (key, value) => MapEntry(key.toString(), value),
      );
    } catch (error) {
      if (error is MarketFailure) rethrow;
      throw const MarketInvalidResponse('Respons Market API tidak valid.');
    }
  }

  Uri _quoteUri(String symbol, String assetType, String currency) {
    final base = Uri.tryParse(baseUrl);
    if (base == null || base.host.isEmpty) {
      throw const MarketConfigurationFailure(
        'Base URL Market API tidak valid.',
      );
    }
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    return base.replace(
      path: '${basePath}api/v1/assets/${Uri.encodeComponent(symbol)}',
      queryParameters: {
        'type': assetType,
        'currency': currency.trim().toUpperCase(),
      },
    );
  }

  Uri _batchUri() {
    final base = Uri.tryParse(baseUrl);
    if (base == null || base.host.isEmpty) {
      throw const MarketConfigurationFailure(
        'Base URL Market API tidak valid.',
      );
    }
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    return base.replace(path: '${basePath}api/v1/market/quotes');
  }

  static Future<MarketHttpResponse> _ioRequest(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      return MarketHttpResponse(
        response.statusCode,
        await response.transform(utf8.decoder).join(),
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<MarketHttpResponse> _ioPost(Uri uri, String body) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..contentType = ContentType.json;
      request.write(body);
      final response = await request.close();
      return MarketHttpResponse(
        response.statusCode,
        await response.transform(utf8.decoder).join(),
      );
    } finally {
      client.close(force: true);
    }
  }
}

class MarketQuoteRequestPayload {
  const MarketQuoteRequestPayload({
    required this.symbol,
    required this.assetType,
  });

  final String symbol;
  final String assetType;
}
