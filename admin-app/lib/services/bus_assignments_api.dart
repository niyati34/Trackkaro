import 'dart:convert';
import 'dart:io' show HttpClient, HttpClientResponse;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service to fetch bus assignments and merge with buses
class BusAssignmentsApiService {
  final String baseUrl;
  final http.Client _client;
  BusAssignmentsApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? (dotenv.env['BACKEND_API'] ?? ''),
        _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  dynamic _normalizeOrgId(dynamic org) {
    if (org == null) return org;
    if (org is int) return org;
    final parsed = int.tryParse(org.toString());
    return parsed ?? org;
  }

  Future<List<Map<String, dynamic>>> getAllAssignments(
      String organizationId) async {
    final org = _normalizeOrgId(organizationId);

    final attempts = <({String label, Future<http.Response> Function() exec})>[
      (
        label: 'DESKTOP native GET with JSON body (Postman-style)',
        exec: () async {
          try {
            final client = HttpClient();
            final request =
                await client.getUrl(_uri('/get-all-bus-assignments'));
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
          final uri = _uri('/get-all-bus-assignments')
              .replace(queryParameters: {'organization_id': '$org'});
          return _client.get(uri, headers: {'Accept': 'application/json'});
        },
      ),
      (
        label: 'POST JSON body (fallback)',
        exec: () async => _client.post(
              _uri('/get-all-bus-assignments'),
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
    throw Exception(_composeDiagnostic('bus-assignments', errors));
  }

  /// Merge bus list with assignments: attaches first matching assignment fields + all assignments array
  List<Map<String, dynamic>> mergeAssignments({
    required List<Map<String, dynamic>> buses,
    required List<Map<String, dynamic>> assignments,
  }) {
    final assignmentsByBus = <String, List<Map<String, dynamic>>>{};
    for (final a in assignments) {
      final bid = a['bus_id']?.toString();
      if (bid == null) continue;
      assignmentsByBus.putIfAbsent(bid, () => []).add(a);
    }

    for (final b in buses) {
      final id = (b['id'] ?? b['bus_id'])?.toString();
      if (id == null) continue;
      final list = assignmentsByBus[id];
      if (list != null && list.isNotEmpty) {
        // pick first assignment for top-level display
        final first = list.first;
        b['route_id'] = first['route_id'];
        b['shift'] = _normalizeShift(first['shift']);
        b['time'] = _normalizeTime(first['time']);
        b['assignments'] = list;
      }
    }
    return buses;
  }

  String _normalizeShift(dynamic raw) {
    final s = raw?.toString().trim().toLowerCase();
    if (s == null || s.isEmpty) return 'Shift 1';
    if (s.contains('1')) return 'Shift 1';
    if (s.contains('2')) return 'Shift 2';
    if (s.contains('3')) return 'Shift 3';
    return 'Shift 1';
  }

  String _normalizeTime(dynamic raw) {
    final s = raw?.toString().trim().toLowerCase();
    if (s == null || s.isEmpty) return 'Morning';
    if (s.startsWith('m')) return 'Morning';
    if (s.startsWith('e')) return 'Evening';
    if (s.startsWith('a')) return 'Afternoon';
    return 'Morning';
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
        'Backend fix: allow GET with query param and avoid unconditional request.get_json() for /get-all-bus-assignments');
    return b.toString();
  }
}
