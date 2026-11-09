import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/api_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  String? _authToken;
  String? _activeTenantId;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  void setActiveTenantId(String? tenantId) {
    _activeTenantId = tenantId;
  }

  String? get activeTenantId => _activeTenantId;
  String? get authToken => _authToken;

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

