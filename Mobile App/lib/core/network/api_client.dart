import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  bool get invalidatesPageCache =>
      const {401, 403, 404, 410}.contains(statusCode);

  @override
  String toString() => message;
}

class ApiClient {
  String? _authToken;
  String? _activeTenantId;
  int _pageReadSequence = 0;
  final _lastPageResult = <String, int>{};
  final _pageRefreshers = <String, Future<void> Function()>{};
  final _pageRefreshVersions = <String, int>{};

  void setAuthToken(String? token) {
    if (_authToken != token) {
      _pageRefreshers.clear();
      _pageRefreshVersions.clear();
    }
    _authToken = token;
  }

  void setActiveTenantId(String? tenantId) {
    if (_activeTenantId != tenantId) {
      _pageRefreshers.clear();
      _pageRefreshVersions.clear();
    }
    _activeTenantId = tenantId;
  }

  String? get activeTenantId => _activeTenantId;
  String? get authToken => _authToken;

  // Use the authenticated subject and tenant to isolate stored page data.
  String? get accountCacheKey {
    try {
      final payload = _authToken?.split('.')[1];
      if (payload == null) return null;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(payload))),
      );
      final subject = claims is Map ? claims['sub'] : null;
      return subject is String && subject.isNotEmpty
          ? Uri.encodeComponent(subject)
          : null;
    } catch (_) {
      return null;
    }
  }

  String? _pageKey(String endpoint, bool accountWide) {
    final account = accountCacheKey;
    if (account == null) return null;
    final tenant = accountWide ? '' : _activeTenantId;
    if (tenant == null) return null;
    return 'cpms_page_v1/${Uri.encodeComponent(ApiConstants.baseUrl)}/$account'
        '/${Uri.encodeComponent(tenant)}/${Uri.encodeComponent(endpoint)}';
  }

  Future<void> storePage(
    String endpoint,
    Object data, {
    bool accountWide = false,
  }) async {
    final key = _pageKey(endpoint, accountWide);
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {
      // Local storage is optional.
    }
  }

  Future<void> refreshLoadedPages() =>
      Future.wait(_pageRefreshers.values.toList().map((refresh) => refresh()));

  /// Show the last successful read immediately, then apply fresh data in place.
  /// Mutation requests and their responses never use this cache.
  Future<void> loadPage(
    String endpoint, {
    required void Function(dynamic data) onData,
    bool accountWide = false,
    bool useCache = true,
    String? refreshGroup,
    bool onlyIfChanged = false,
    bool Function()? shouldApply,
    void Function(ApiException error)? onAccessLost,
  }) async {
    final token = _authToken;
    final tenant = _activeTenantId;
    final sequence = ++_pageReadSequence;
    if (refreshGroup != null) _pageRefreshVersions[refreshGroup] = sequence;
    bool isCurrent() =>
        token == _authToken &&
        (accountWide || tenant == _activeTenantId) &&
        (refreshGroup == null ||
            _pageRefreshVersions[refreshGroup] == sequence) &&
        (shouldApply?.call() ?? true);
    final key = _pageKey(endpoint, accountWide);
    if (key != null && refreshGroup != null) {
      _pageRefreshers[refreshGroup] = () async {
        if (!isCurrent()) return;
        try {
          await loadPage(
            endpoint,
            onData: (data) {
              if (isCurrent()) onData(data);
            },
            accountWide: accountWide,
            useCache: false,
            onlyIfChanged: true,
            shouldApply: isCurrent,
          );
        } on ApiException catch (error) {
          if (isCurrent() && error.invalidatesPageCache) {
            _pageRefreshers.remove(refreshGroup);
            onAccessLost?.call(error);
          }
        } catch (_) {
          // Retry during the next scheduled refresh.
        }
      };
    }
    SharedPreferences? prefs;
    String? cached;
    if (key != null) {
      try {
        prefs = await SharedPreferences.getInstance();
        cached = prefs.getString(key);
        if (useCache && cached != null && isCurrent()) {
          onData(jsonDecode(cached));
        }
      } catch (_) {
        cached = null;
      }
    }
    if (!isCurrent()) return;

    final dynamic fresh;
    try {
      fresh = await get(endpoint).timeout(const Duration(seconds: 12));
    } catch (error) {
      if (!isCurrent()) return;
      final status = error is ApiException ? error.statusCode : null;
      if (error is ApiException && error.invalidatesPageCache) {
        if (key != null && sequence >= (_lastPageResult[key] ?? 0)) {
          _lastPageResult[key] = sequence;
          try {
            await prefs?.remove(key);
          } catch (_) {
            // Surface the access error even if local storage is unavailable.
          }
        }
      } else if (cached != null &&
          (useCache || onlyIfChanged) &&
          (status == null || status >= 500)) {
        return;
      }
      rethrow;
    }
    if (!isCurrent()) return;
    if (key != null) {
      if (sequence < (_lastPageResult[key] ?? 0)) return;
      _lastPageResult[key] = sequence;
    }
    final encoded = key == null ? null : jsonEncode(fresh);
    if ((!useCache && !onlyIfChanged) || encoded == null || encoded != cached) {
      onData(fresh);
    }
    if (key != null && encoded != null && encoded != cached) {
      try {
        await prefs?.setString(key, encoded);
      } catch (_) {
        // The server response is still usable if local storage is unavailable.
      }
    }
  }

  Map<String, String> _buildHeaders({Map<String, String>? extraHeaders}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    if (_activeTenantId != null && _activeTenantId!.isNotEmpty) {
      headers['X-Tenant-ID'] = _activeTenantId!;
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? headers}) async {
    return _sendRequest(() => http.get(
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
          headers: _buildHeaders(extraHeaders: headers),
        ));
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    return _sendRequest(() => http.post(
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
          headers: _buildHeaders(extraHeaders: headers),
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    return _sendRequest(() => http.put(
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
          headers: _buildHeaders(extraHeaders: headers),
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    return _sendRequest(() => http.patch(
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
          headers: _buildHeaders(extraHeaders: headers),
          body: body != null ? jsonEncode(body) : null,
        ));
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? headers,
  }) async {
    return _sendRequest(() => http.delete(
          Uri.parse('${ApiConstants.baseUrl}$endpoint'),
          headers: _buildHeaders(extraHeaders: headers),
        ));
  }

  Future<dynamic> multipartPost(
    String endpoint, {
    required List<int> bytes,
    required String filename,
    String fileField = 'image',
    Map<String, String>? fields,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    final request = http.MultipartRequest('POST', uri);

    if (_authToken != null && _authToken!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_authToken';
    }
    if (_activeTenantId != null && _activeTenantId!.isNotEmpty) {
      request.headers['X-Tenant-ID'] = _activeTenantId!;
    }
    if (headers != null) {
      request.headers.addAll(headers);
    }

    if (fields != null) {
      request.fields.addAll(fields);
    }

    final ext = filename.split('.').last.toLowerCase();
    MediaType contentType;
    if (ext == 'png') {
      contentType = MediaType('image', 'png');
    } else if (ext == 'webp') {
      contentType = MediaType('image', 'webp');
    } else if (ext == 'gif') {
      contentType = MediaType('image', 'gif');
    } else if (ext == 'heic') {
      contentType = MediaType('image', 'heic');
    } else if (ext == 'heif') {
      contentType = MediaType('image', 'heif');
    } else {
      contentType = MediaType('image', 'jpeg');
    }

    final multipartFile = http.MultipartFile.fromBytes(
      fileField,
      bytes,
      filename: filename,
      contentType: contentType,
    );
    request.files.add(multipartFile);

    return _sendRequest(() async {
      final streamedResponse = await request.send();
      return http.Response.fromStream(streamedResponse);
    });
  }

  Future<dynamic> _sendRequest(Future<http.Response> Function() requestFn) async {
    try {
      final response = await requestFn();
      final bodyString = response.body;
      dynamic decodedData;

      if (bodyString.isNotEmpty) {
        try {
          decodedData = jsonDecode(bodyString);
        } catch (_) {
          decodedData = bodyString;
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Backend wraps responses in { statusCode: 200, data: ... }
        if (decodedData is Map<String, dynamic> && decodedData.containsKey('data')) {
          return decodedData['data'];
        }
        return decodedData;
      }

      // Handle NestJS error response structure
      String errorMessage = 'Request failed with status: ${response.statusCode}';
      if (decodedData is Map<String, dynamic>) {
        if (decodedData['message'] != null) {
          if (decodedData['message'] is List) {
            errorMessage = (decodedData['message'] as List).join(', ');
          } else {
            errorMessage = decodedData['message'].toString();
          }
        } else if (decodedData['error'] != null) {
          errorMessage = decodedData['error'].toString();
        }
      }

      throw ApiException(errorMessage, statusCode: response.statusCode);
    } on SocketException {
      // Architectural rule 5: "Offline barrier: Display 'No network found. Please check your internet connection'"
      throw ApiException(
        'No network found. Please check your internet connection.',
      );
    } on http.ClientException {
      throw ApiException(
        'Cannot connect to backend server. Ensure the server is running.',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(e.toString());
    }
  }
}

