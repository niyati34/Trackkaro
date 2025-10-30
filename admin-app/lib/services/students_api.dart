import 'dart:convert';
import 'dart:io'
    show HttpClient, HttpClientResponse; // desktop GET-with-body workaround
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/student.dart';

/// Service encapsulating resilient retrieval of student records with
/// multi-attempt strategy + diagnostics mirroring routes_api pattern.
class StudentsApiService {
  final http.Client _client;
  StudentsApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Attempt order rationale:
  /// 1. GET with query param (spec-compliant, SHOULD be what backend fixes to)
  /// 2. POST with JSON body (current backend anti-pattern requiring body)
  /// If both fail: return mock data and throw aggregated diagnostic for logging/UI.
  Future<List<StudentRecord>> getAllStudentsWithFallback(
      String organizationId) async {
    final normalizedOrg = _normalizeOrgId(organizationId);
    final base = dotenv.env['BACKEND_API'];
    final attempts = <_AttemptSpec>[
      _AttemptSpec(
        label: 'DESKTOP native GET with JSON body',
        method: 'GET_NATIVE_BODY',
        uri: Uri.parse('$base/get-all-students'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        bodyJson: {'organization_id': normalizedOrg},
      ),
      _AttemptSpec(
        label: 'GET?organization_id',
        method: 'GET',
        uri: Uri.parse('$base/get-all-students')
            .replace(queryParameters: {'organization_id': '$normalizedOrg'}),
        headers: {'Accept': 'application/json'},
      ),
      _AttemptSpec(
        label: 'POST body',
        method: 'POST',
        uri: Uri.parse('$base/get-all-students'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        bodyJson: {'organization_id': normalizedOrg},
      ),
    ];

    final perAttempt = <_AttemptResult>[];
    for (final spec in attempts) {
      try {
        final resp = await _send(spec);
        perAttempt.add(_AttemptResult(
            spec: spec,
            statusCode: resp.statusCode,
            bodySnippet: _short(resp.body)));
        if (resp.statusCode == 200) {
          final decoded = jsonDecode(resp.body) as List<dynamic>;
          return decoded
              .map((e) => StudentRecord.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        perAttempt.add(_AttemptResult(
            spec: spec, statusCode: null, bodySnippet: 'ERROR: $e'));
      }
    }

    final diagnostic = _composeDiagnostic(perAttempt, '$normalizedOrg');
    debugPrint(diagnostic);
    // No mock data: surface failure so caller can show proper error state.
    throw Exception(diagnostic);
  }

  Future<http.Response> _send(_AttemptSpec spec) async {
    switch (spec.method) {
      case 'GET':
        return _client.get(spec.uri, headers: spec.headers);
      case 'POST':
        return _client.post(spec.uri,
            headers: spec.headers, body: jsonEncode(spec.bodyJson));
      case 'GET_NATIVE_BODY':
        try {
          final client = HttpClient();
          final request = await client.getUrl(spec.uri);
          spec.headers.forEach(request.headers.set);
          final payload = utf8.encode(jsonEncode(spec.bodyJson));
          request.contentLength = payload.length;
          request.add(payload);
          final HttpClientResponse resp = await request.close();
          final body = await utf8.decodeStream(resp);
          final headerMap = <String, String>{};
          resp.headers.forEach((name, values) {
            if (values.isNotEmpty) headerMap[name] = values.join(',');
          });
          client.close(force: true);
          return http.Response(body, resp.statusCode, headers: headerMap);
        } catch (e) {
          throw Exception('Desktop GET-with-body failed: $e');
        }
      default:
        throw UnsupportedError('Unsupported method ${spec.method}');
    }
  }

  dynamic _normalizeOrgId(String org) {
    final asInt = int.tryParse(org.trim());
    return asInt ?? org; // send numeric if possible else original string
  }

  String _short(String body) {
    if (body.isEmpty) return '<empty>';
    final trimmed = body.replaceAll(RegExp(r'\s+'), ' ');
    return trimmed.length > 140 ? '${trimmed.substring(0, 140)}…' : trimmed;
  }

  String _composeDiagnostic(List<_AttemptResult> results, String orgId) {
    final b = StringBuffer();
    b.writeln('Students fetch diagnostic (org=$orgId)');
    for (final r in results) {
      b.writeln(
          '- ${r.spec.label}: status=${r.statusCode ?? 'EXCEPTION'} body=${r.bodySnippet}');
    }
    b.writeln(
        'Remediation: Ensure backend defines @app.route("/get-all-students", methods=["GET"])');
    b.writeln(
        'Inside handler use organization_id = request.args.get("organization_id") (NOT request.get_json()) for GET.');
    b.writeln(
        'If body parsing required keep POST variant but mark both in methods list.');
    return b.toString();
  }

  // Mock removal: intentionally no fallback list now.
}

class _AttemptSpec {
  final String label;
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final Map<String, dynamic>? bodyJson;
  _AttemptSpec(
      {required this.label,
      required this.method,
      required this.uri,
      required this.headers,
      this.bodyJson});
}

class _AttemptResult {
  final _AttemptSpec spec;
  final int? statusCode;
  final String bodySnippet;
  _AttemptResult(
      {required this.spec,
      required this.statusCode,
      required this.bodySnippet});
}

void debugPrint(String msg) {
  // Lightweight shim (avoid importing Flutter foundation if not needed elsewhere)
  // Replace with `import 'package:flutter/foundation.dart';` and call real debugPrint if preferred.
  // ignore: avoid_print
  print(msg);
}
