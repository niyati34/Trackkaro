import 'dart:convert';
import 'dart:io';

/// Deep diagnostic test to understand the Postman vs Dart difference
/// This test will:
/// 1. Test with different HTTP clients
/// 2. Capture all headers and response
/// 3. Test connection pooling behavior
/// 4. Compare SSL/TLS handshake details
void main() async {
  const String baseUrl = 'https://new-track-karo-backend.onrender.com';
  const String organizationId = '1';

  print('═══════════════════════════════════════════════════════════════');
  print('🔬 DEEP API DIAGNOSTIC TEST');
  print('═══════════════════════════════════════════════════════════════');
  print('Target: $baseUrl/get-all-routes');
  print('Organization ID: $organizationId');
  print('');

  // Test 1: Using dart:io HttpClient (what Flutter uses internally)
  await testWithHttpClient(baseUrl, organizationId);

  print('\n' + '─' * 60 + '\n');

  // Test 2: Using package:http (alternative method)
  await testWithHttpPackage(baseUrl, organizationId);

  print('\n' + '─' * 60 + '\n');

  // Test 3: Multiple rapid requests (test connection pooling)
  await testConnectionPooling(baseUrl, organizationId);

  print('\n' + '─' * 60 + '\n');

  // Test 4: Check SSL certificate details
  await testSSLCertificate(baseUrl);

  print('\n═══════════════════════════════════════════════════════════════');
  print('🏁 DIAGNOSTIC TEST COMPLETE');
  print('═══════════════════════════════════════════════════════════════');
}

Future<void> testWithHttpClient(String baseUrl, String organizationId) async {
  print('📋 TEST 1: dart:io HttpClient (Native Dart/Flutter)');
  print('This is what the Flutter app uses');
  print('');

  try {
    final client = HttpClient();

    // Disable certificate verification temporarily to see if SSL is the issue
    // client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;

    final request = await client.getUrl(Uri.parse('$baseUrl/get-all-routes'));

    // Match Postman exactly
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json');
    request.headers.set('User-Agent', 'Dart/Flutter Test Client');

    final payload =
        utf8.encode(jsonEncode({'organization_id': organizationId}));
    request.contentLength = payload.length;
    request.add(payload);

    print('📤 Request Headers:');
    request.headers.forEach((name, values) {
      print('   $name: ${values.join(', ')}');
    });
    print('📤 Request Body: {"organization_id": "$organizationId"}');
    print('');

    final stopwatch = Stopwatch()..start();
    final response = await request.close();
    stopwatch.stop();

    print('📥 Response:');
    print('   Status: ${response.statusCode} ${response.reasonPhrase}');
    print('   Time: ${stopwatch.elapsedMilliseconds}ms');
    print('   Response Headers:');
    response.headers.forEach((name, values) {
      print('      $name: ${values.join(', ')}');
    });

    final body = await utf8.decodeStream(response);
    client.close(force: true);

    print('');
    print('📥 Response Body (first 500 chars):');
    print(body.length > 500 ? body.substring(0, 500) + '...' : body);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(body);
      final count = decoded is List ? decoded.length : 'N/A';
      print('');
      print('✅ SUCCESS! Routes count: $count');
    } else {
      print('');
      print('❌ FAILED! Status: ${response.statusCode}');
      _analyzeError(body);
    }
  } catch (e, stackTrace) {
    print('');
    print('❌ EXCEPTION: $e');
    print('Stack trace:');
    print(stackTrace.toString().split('\n').take(5).join('\n'));
  }
}

Future<void> testWithHttpPackage(String baseUrl, String organizationId) async {
  print('📋 TEST 2: package:http (Alternative HTTP client)');
  print('Testing if different HTTP client makes a difference');
  print('');

  // Note: This requires adding 'http' package to pubspec.yaml
  // For this test, we'll use HttpClient again but with different settings

  try {
    final client = HttpClient();
    client.connectionTimeout = Duration(seconds: 30);
    client.idleTimeout = Duration(seconds: 15);

    final request = await client.getUrl(Uri.parse('$baseUrl/get-all-routes'));
    request.headers.set('Content-Type', 'application/json');

    final payload =
        utf8.encode(jsonEncode({'organization_id': organizationId}));
    request.contentLength = payload.length;
    request.add(payload);

    print('📤 Sending with extended timeouts...');
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    client.close(force: true);

    print('📥 Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      print('✅ SUCCESS with extended timeouts!');
    } else {
      print('❌ FAILED: ${response.statusCode}');
      print('Body: ${body.substring(0, 200)}...');
    }
  } catch (e) {
    print('❌ EXCEPTION: $e');
  }
}

Future<void> testConnectionPooling(
    String baseUrl, String organizationId) async {
  print('📋 TEST 3: Connection Pooling Behavior');
  print('Testing multiple rapid requests to see if connection reuse matters');
  print('');

  final client = HttpClient();
  client.maxConnectionsPerHost = 1; // Force connection reuse

  for (int i = 1; i <= 3; i++) {
    try {
      print('Request #$i...');
      final request = await client.getUrl(Uri.parse('$baseUrl/get-all-routes'));
      request.headers.set('Content-Type', 'application/json');

      final payload =
          utf8.encode(jsonEncode({'organization_id': organizationId}));
      request.contentLength = payload.length;
      request.add(payload);

      final response = await request.close();
      await utf8.decodeStream(response); // Consume the response

      if (response.statusCode == 200) {
        print('   ✅ Request #$i: SUCCESS (${response.statusCode})');
      } else {
        print('   ❌ Request #$i: FAILED (${response.statusCode})');
        if (i == 1) {
          print('   First request failed - not a pooling issue');
        } else {
          print('   Subsequent request failed - pooling might be involved');
        }
      }

      // Small delay between requests
      await Future.delayed(Duration(milliseconds: 100));
    } catch (e) {
      print('   ❌ Request #$i: EXCEPTION - $e');
    }
  }

  client.close(force: true);
}

Future<void> testSSLCertificate(String baseUrl) async {
  print('📋 TEST 4: SSL/TLS Certificate Analysis');
  print('Checking SSL certificate validity and details');
  print('');

  try {
    final uri = Uri.parse(baseUrl);
    final socket = await SecureSocket.connect(
      uri.host,
      443,
      timeout: Duration(seconds: 10),
    );

    final cert = socket.peerCertificate;

    if (cert != null) {
      print('✅ SSL Connection Successful!');
      print('');
      print('Certificate Details:');
      print('   Subject: ${cert.subject}');
      print('   Issuer: ${cert.issuer}');
      print('   Valid from: ${cert.startValidity}');
      print('   Valid until: ${cert.endValidity}');

      final now = DateTime.now();
      if (now.isAfter(cert.startValidity) && now.isBefore(cert.endValidity)) {
        print('   ✅ Certificate is VALID');
      } else {
        print('   ⚠️  Certificate is EXPIRED or NOT YET VALID');
      }
    } else {
      print('⚠️  No certificate information available');
    }

    socket.close();
  } catch (e) {
    print('❌ SSL Connection Failed: $e');
    print('');
    print('This could explain the difference between Postman and Dart:');
    print('- Postman might be more lenient with SSL validation');
    print('- The server SSL configuration might be incompatible with Dart');
  }
}

void _analyzeError(String body) {
  print('');
  print('🔍 Error Analysis:');

  if (body.contains('psycopg2.OperationalError')) {
    print('   ⚠️  PostgreSQL connection error detected');

    if (body.contains('SSL')) {
      print('   ⚠️  SSL-related database error');
      print('   This is a BACKEND database issue, not a client issue');
      print('');
      print('   Why Postman might work:');
      print('   1. Timing: Database SSL tunnel was healthy when you tested');
      print('   2. Connection pooling: Postman reused a warm connection');
      print('   3. Render backend: SSL errors can be intermittent on Render');
      print('');
      print('   Backend Fix Required:');
      print('   Add to your DATABASE_URL: ?sslmode=require');
      print('   Or in SQLAlchemy: connect_args={"sslmode": "disable"}');
    }
  } else if (body.contains('415')) {
    print('   ⚠️  Unsupported Media Type');
    print('   Backend is not accepting the Content-Type header');
  } else if (body.contains('405')) {
    print('   ⚠️  Method Not Allowed');
    print('   Backend does not allow GET requests with body');
  }
}
