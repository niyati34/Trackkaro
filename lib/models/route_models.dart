class RouteLocation {
  final String locationName;
  final String locationLat;
  final String locationLng;

  RouteLocation({
    required this.locationName,
    required this.locationLat,
    required this.locationLng,
  });

  Map<String, dynamic> toJson() => {
        'location_name': locationName,
        'location_lat': locationLat,
        'location_lng': locationLng,
      };

  factory RouteLocation.fromJson(Map<String, dynamic> json) => RouteLocation(
        locationName: (json['location_name'] ?? '').toString(),
        locationLat: (json['location_lat'] ?? '').toString(),
        locationLng: (json['location_lng'] ?? '').toString(),
      );

  // Handle both Map and null values safely
  static RouteLocation fromJsonSafe(dynamic json) {
    if (json == null) {
      return RouteLocation(locationName: '', locationLat: '', locationLng: '');
    }
    if (json is Map<String, dynamic>) {
      return RouteLocation.fromJson(json);
    }
    // If it's a string or other type, return empty
    return RouteLocation(locationName: '', locationLat: '', locationLng: '');
  }
}

class SchoolRoute {
  final String id; // server id as string
  final String routeNumber;
  final String routeName;
  final RouteLocation source;
  final RouteLocation destination;
  final List<RouteLocation> stops;

  SchoolRoute({
    required this.id,
    required this.routeNumber,
    required this.routeName,
    required this.source,
    required this.destination,
    required this.stops,
  });

  factory SchoolRoute.fromJson(Map<String, dynamic> json) => SchoolRoute(
        id: (json['id'] ?? '').toString(),
        routeNumber: (json['route_number'] ?? '').toString(),
        routeName: (json['route_name'] ?? '').toString(),
        source: RouteLocation.fromJsonSafe(json['source']),
        destination: RouteLocation.fromJsonSafe(json['destination']),
        stops: (json['stops'] as List<dynamic>? ?? [])
            .map((e) => RouteLocation.fromJsonSafe(e))
            .toList(),
      );
}

class CreateRouteRequest {
  final String routeNumber;
  final String routeName;
  final RouteLocation source;
  final RouteLocation destination;
  final List<RouteLocation> stops;
  final String organizationId;

  CreateRouteRequest({
    required this.routeNumber,
    required this.routeName,
    required this.source,
    required this.destination,
    required this.stops,
    required this.organizationId,
  });

  Map<String, dynamic> toJson() => {
        'route_number': routeNumber,
        'route_name': routeName,
        'source': source.toJson(),
        'destination': destination.toJson(),
        'stops': stops.map((s) => s.toJson()).toList(),
        'organization_id': organizationId,
      };
}

class UpdateRouteRequest {
  final String id;
  final String organizationId;
  final String? routeNumber;
  final String? routeName;
  final RouteLocation? source;
  final RouteLocation? destination;

  UpdateRouteRequest({
    required this.id,
    required this.organizationId,
    this.routeNumber,
    this.routeName,
    this.source,
    this.destination,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'organization_id': organizationId,
    };
    if (routeNumber != null) map['route_number'] = routeNumber;
    if (routeName != null) map['route_name'] = routeName;
    if (source != null) map['source'] = source!.toJson();
    if (destination != null) map['destination'] = destination!.toJson();
    return map;
  }
}
