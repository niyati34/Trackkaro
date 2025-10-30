import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/route_models.dart';

class RoutesApiService {
  final String baseUrl;

  RoutesApiService({String? baseUrl})
      : baseUrl = baseUrl ?? (dotenv.env['BACKEND_API'] ?? '');

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<List<SchoolRoute>> getAllRoutes(String organizationId) async {
    print('Fetching routes for organization: $organizationId');

    // Retry logic to handle intermittent database SSL issues
    int maxRetries = 3;
    int retryDelay = 1000; // milliseconds

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Attempt $attempt of $maxRetries...');

        final client = HttpClient();
        final request =
            await client.getUrl(Uri.parse('$baseUrl/get-all-routes'));

        request.headers.set('Content-Type', 'application/json');
        final payload =
            utf8.encode(jsonEncode({'organization_id': organizationId}));
        request.contentLength = payload.length;
        request.add(payload);

        print('Making GET request with JSON body to: $baseUrl/get-all-routes');
        print('Request body: {"organization_id": "$organizationId"}');

        final resp = await request.close();
        final body = await utf8.decodeStream(resp);
        client.close(force: true);

        print('Response status: ${resp.statusCode}');

        if (resp.statusCode == 200) {
          final decoded = jsonDecode(body);
          final list = decoded is List
              ? decoded
              : (decoded['routes'] as List<dynamic>? ??
                  decoded['data'] as List<dynamic>? ??
                  []);

          print(
              '✅ Successfully parsed ${list.length} routes on attempt $attempt');
          return list
              .map((e) => SchoolRoute.fromJson(e as Map<String, dynamic>))
              .toList();
        } else if (resp.statusCode == 500 && attempt < maxRetries) {
          // Database connection issue - retry
          if (body.contains('psycopg2.OperationalError') &&
              body.contains('SSL')) {
            print(
                '⚠️  Database SSL error on attempt $attempt, retrying in ${retryDelay}ms...');
            await Future.delayed(Duration(milliseconds: retryDelay));
            retryDelay *= 2; // Exponential backoff
            continue; // Retry
          }
        }

        // Non-retryable error or last attempt failed
        print('Response body: $body');
        if (resp.statusCode == 500) {
          if (body.contains('psycopg2.OperationalError') &&
              body.contains('SSL')) {
            throw Exception(
                'Database connection error: The backend database has an SSL configuration issue.\n'
                'This is a server-side problem that needs to be fixed by the backend developer.\n\n'
                'The backend needs to add:\n'
                '  pool_pre_ping=True\n'
                '  pool_recycle=300\n'
                'to the SQLAlchemy engine configuration.\n\n'
                'Attempted $attempt times. Error: $body');
          } else {
            throw Exception('Server error (500): $body');
          }
        } else {
          throw Exception(
              'API request failed with status ${resp.statusCode}: $body');
        }
      } catch (e) {
        if (attempt == maxRetries) {
          print('❌ Failed to fetch routes after $maxRetries attempts: $e');
          throw Exception('Failed to load routes from $baseUrl/get-all-routes\n'
              'Error: $e\n\n'
              'Please check:\n'
              '1. Backend server is running\n'
              '2. Network connectivity\n'
              '3. Organization ID is valid: $organizationId\n'
              '4. Backend database connection pooling configuration');
        } else {
          print('⚠️  Attempt $attempt failed: $e. Retrying...');
          await Future.delayed(Duration(milliseconds: retryDelay));
          retryDelay *= 2;
        }
      }
    }

    throw Exception('Failed after $maxRetries attempts');
  }

  // Mock fallback removed: now failures throw so caller can show real error.

  Future<void> addRoute(CreateRouteRequest request) async {
    final res = await http.post(
      _uri('/add-route'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to add route: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> updateRoute(UpdateRouteRequest request) async {
    final res = await http.put(
      _uri('/update-route'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update route: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> deleteRoute(
      {required String id, required String organizationId}) async {
    final res = await http.delete(
      _uri('/delete-route'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': id, 'organization_id': organizationId}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to delete route: ${res.statusCode} ${res.body}');
    }
  }
}
