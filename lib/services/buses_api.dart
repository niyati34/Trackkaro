import 'dart:convert';
import 'dart:io' show HttpClient, HttpClientResponse;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BusesApiService {
  final String baseUrl;
  final http.Client _client;
  BusesApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? (dotenv.env['BACKEND_API'] ?? ''),
        _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  dynamic _normalizeOrgId(dynamic org) {
    if (org == null) return org;
    if (org is int) return org;
    final parsed = int.tryParse(org.toString());
    return parsed ?? org;
  }

  Future<List<Map<String, dynamic>>> getAllBuses(String organizationId) async {
    final org = _normalizeOrgId(organizationId);
    final attempts = <({String label, Future<http.Response> Function() exec})>[
      (
        label: 'DESKTOP native GET with JSON body (Postman-style)',
        exec: () async {
          try {
            final client = HttpClient();
            final request = await client.getUrl(_uri('/get-all-bus'));
            request.headers.set('Content-Type', 'application/json');
            request.headers.set('Accept', 'application/json');
            final payload = utf8.encode(jsonEncode({'organization_id': org}));
            request.contentLength = payload.length;
            request.add(payload);
            final HttpClientResponse resp = await request.close();
            final body = await utf8.decodeStream(resp);
            final headerMap = <String, String>{};
            resp.headers.forEach((n, v) {
              if (v.isNotEmpty) headerMap[n] = v.join(',');
            });
            client.close(force: true);
            return http.Response(body, resp.statusCode, headers: headerMap);
          } catch (e) {
            throw Exception('Desktop GET-with-body failed: $e');
          }
        },
      ),
      (
        label: 'GET ?organization_id=… (standards-compliant)',
        exec: () async {
          final uri = _uri('/get-all-bus')
              .replace(queryParameters: {'organization_id': '$org'});
          return _client.get(uri, headers: {'Accept': 'application/json'});
        },
      ),
      (
        label: 'POST JSON body (fallback)',
        exec: () async => _client.post(
              _uri('/get-all-bus'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json'
              },
              body: jsonEncode({'organization_id': org}),
            ),
      ),
    ];

    final errors = <String>[];
    for (final a in attempts) {
      try {
        final res = await a.exec();
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded is List) {
            return decoded.cast<Map<String, dynamic>>();
          }
          if (decoded is Map && decoded['data'] is List) {
            return (decoded['data'] as List).cast<Map<String, dynamic>>();
          }
          return [];
        }
        errors.add('${a.label}: ${res.statusCode} ${_short(res.body)}');
      } catch (e) {
        errors.add('${a.label}: EXCEPTION $e');
      }
    }
    throw Exception(_composeDiagnostic('buses', errors));
  }

  Future<void> addBus(Map<String, dynamic> body) async {
    body['organization_id'] = _normalizeOrgId(body['organization_id']);
    final res = await _client.post(
      _uri('/add-bus'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to add bus: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> updateBus(Map<String, dynamic> body) async {
    body['organization_id'] = _normalizeOrgId(body['organization_id']);
    final res = await _client.put(
      _uri('/update-bus'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update bus: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> deleteBus(
      {required dynamic id, required dynamic organizationId}) async {
    final res = await _client.delete(
      _uri('/delete-bus'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'id': id, 'organization_id': _normalizeOrgId(organizationId)}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to delete bus: ${res.statusCode} ${res.body}');
    }
  }

  String _short(String body) {
    if (body.isEmpty) return '<empty>';
    final t = body.replaceAll('\n', ' ');
    return t.length > 140 ? t.substring(0, 140) + '…' : t;
  }

  String _composeDiagnostic(String entity, List<String> errors) {
    final b = StringBuffer();
    b.writeln('Failed to load $entity after ${errors.length} attempt(s).');
    for (final e in errors) {
      b.writeln('- $e');
    }
    b.writeln(
        'Backend fix: allow GET with query param and avoid unconditional request.get_json() for /get-all-bus');
    return b.toString();
  }
}
