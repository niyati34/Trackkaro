import 'dart:convert';
import 'dart:io';

/// Simple test script to verify the API works exactly like in Postman
/// Run this with: dart test_api.dart
void main() async {
  const String baseUrl = 'https://new-track-karo-backend.onrender.com';
  const String organizationId = '1';

  print('🧪 Testing API exactly like Postman...');
  print('URL: $baseUrl/get-all-routes');
  print('Method: GET with JSON body');
  print('Headers: Content-Type: application/json');
  print('Body: {"organization_id": "$organizationId"}');
  print('');

  try {
    // Use the exact method that works in Postman
    final client = HttpClient();
    final request = await client.getUrl(Uri.parse('$baseUrl/get-all-routes'));

    // Set Content-Type header - backend expects it for JSON body
    request.headers.set('Content-Type', 'application/json');
    final payload =
        utf8.encode(jsonEncode({'organization_id': organizationId}));
    request.contentLength = payload.length;
    request.add(payload);

    print('📤 Sending request...');
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    client.close(force: true);

    print('');
    print('📥 Response:');
    print('Status Code: ${response.statusCode}');
    print('Response Body:');
    print(body);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(body);
      if (decoded is List) {
        print('');
        print('✅ SUCCESS! Found ${decoded.length} routes');
        for (int i = 0; i < decoded.length && i < 3; i++) {
          final route = decoded[i];
          print(
              '  Route ${i + 1}: ${route['route_name'] ?? 'Unknown'} (${route['route_number'] ?? 'No number'})');
        }
        if (decoded.length > 3) {
          print('  ... and ${decoded.length - 3} more routes');
        }
      } else {
        print('✅ SUCCESS! Response received but not a list');
      }
    } else {
      print('❌ FAILED! Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ ERROR: $e');
  }
}
