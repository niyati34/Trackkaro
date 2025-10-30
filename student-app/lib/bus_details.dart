import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; // Add this import

void main() {
  runApp(MaterialApp(
    home: BusDetailsPage(),
  ));
}

class BusDetailsPage extends StatefulWidget {
  @override
  _BusDetailsPageState createState() => _BusDetailsPageState();
}

class _BusDetailsPageState extends State<BusDetailsPage> {
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTimeFilter = 'All';
  String _selectedRouteFilter = 'All';

  List<BusData> allBuses = [
    BusData(
      busNumber: "101",
      route: "College → City Center",
      departureTime: "08:00",
      arrivalTime: "08:45",
      driverName: "John Doe",
      contact: "+91 9876543210",
      isEvening: false,
    ),
    BusData(
      busNumber: "303",
      route: "Hostel → Library",
      departureTime: "09:00",
      arrivalTime: "09:30",
      driverName: "David Johnson",
      contact: "+91 9876512345",
      isEvening: false,
    ),
    BusData(
      busNumber: "505",
      route: "Main Gate → Auditorium",
      departureTime: "07:30",
      arrivalTime: "07:50",
      driverName: "Chris Wilson",
      contact: "+91 9876534567",
      isEvening: false,
    ),
    BusData(
      busNumber: "202",
      route: "City Center → College",
      departureTime: "16:00",
      arrivalTime: "16:45",
      driverName: "Michael Smith",
      contact: "+91 9876501234",
      isEvening: true,
    ),
    BusData(
      busNumber: "404",
      route: "Library → Hostel",
      departureTime: "18:00",
      arrivalTime: "18:30",
      driverName: "Robert Brown",
      contact: "+91 9876523456",
      isEvening: true,
    ),
    BusData(
      busNumber: "606",
      route: "Auditorium → Main Gate",
      departureTime: "17:30",
      arrivalTime: "17:50",
      driverName: "James Anderson",
      contact: "+91 9876545678",
      isEvening: true,
    ),
  ];

  List<BusData> get filteredBuses {
    List<BusData> filtered = allBuses.where((bus) {
      // Search filter
      bool matchesSearch = _searchQuery.isEmpty ||
          bus.busNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          bus.route.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          bus.driverName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          bus.departureTime.contains(_searchQuery) ||
          bus.arrivalTime.contains(_searchQuery);

      // Time filter
      bool matchesTime = _selectedTimeFilter == 'All' ||
          (_selectedTimeFilter == 'Morning' && !bus.isEvening) ||
          (_selectedTimeFilter == 'Evening' && bus.isEvening);

      // Route filter
      bool matchesRoute = _selectedRouteFilter == 'All' ||
          bus.route.toLowerCase().contains(_selectedRouteFilter.toLowerCase());

      return matchesSearch && matchesTime && matchesRoute;
    }).toList();

    return filtered;
  }

  List<String> get availableRoutes {
    Set<String> routes = {'All'};
    for (var bus in allBuses) {
      String cleanRoute = bus.route.replaceAll('→', '').trim();
      List<String> routeParts = cleanRoute.split(' ');
      routes.addAll(routeParts.where((part) => part.isNotEmpty));
    }
    return routes.toList();
  }

  @override
  Widget build(BuildContext context) {
    List<BusData> displayBuses = filteredBuses;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Bus Schedule',
          style: GoogleFonts.inter(
            textStyle: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search by bus number, route, driver, or time...',
                      hintStyle: GoogleFonts.inter(
                        textStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[500]),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),

                SizedBox(height: 12),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Time Filter
                      _buildFilterChip(
                        'All Time',
                        _selectedTimeFilter == 'All',
                            () => setState(() => _selectedTimeFilter = 'All'),
                        Icons.access_time,
                      ),
                      SizedBox(width: 8),
                      _buildFilterChip(
                        'Morning',
                        _selectedTimeFilter == 'Morning',
                            () => setState(() => _selectedTimeFilter = 'Morning'),
                        Icons.wb_sunny_outlined,
                      ),
                      SizedBox(width: 8),
                      _buildFilterChip(
                        'Evening',
                        _selectedTimeFilter == 'Evening',
                            () => setState(() => _selectedTimeFilter = 'Evening'),
                        Icons.nightlight_outlined,
                      ),
                      SizedBox(width: 16),

                      // // Quick Route Filters
                      // _buildFilterChip(
                      //   'College',
                      //   _selectedRouteFilter == 'College',
                      //       () => setState(() => _selectedRouteFilter = _selectedRouteFilter == 'College' ? 'All' : 'College'),
                      //   Icons.school,
                      // ),
                      // SizedBox(width: 8),
                      // _buildFilterChip(
                      //   'Hostel',
                      //   _selectedRouteFilter == 'Hostel',
                      //       () => setState(() => _selectedRouteFilter = _selectedRouteFilter == 'Hostel' ? 'All' : 'Hostel'),
                      //   Icons.home,
                      // ),
                      // SizedBox(width: 8),
                      // _buildFilterChip(
                      //   'Library',
                      //   _selectedRouteFilter == 'Library',
                      //       () => setState(() => _selectedRouteFilter = _selectedRouteFilter == 'Library' ? 'All' : 'Library'),
                      //   Icons.library_books,
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Results Summary
          if (_searchQuery.isNotEmpty || _selectedTimeFilter != 'All' || _selectedRouteFilter != 'All')
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Color(0xFFE5F7F8)
              ,
              child: Text(
                '${displayBuses.length} bus${displayBuses.length != 1 ? 'es' : ''} found',
                style: GoogleFonts.inter(
                  textStyle: TextStyle(
                    color: Color(0xFF03B0C1),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // Bus List
          Expanded(
            child: displayBuses.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: displayBuses.length,
              itemBuilder: (context, index) {
                return BusDetailCard(
                  busData: displayBuses[index],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, IconData icon) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF03B0C1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Color(0xFF03B0C1) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                textStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16),
          Text(
            'No buses found',
            style: GoogleFonts.inter(
              textStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: GoogleFonts.inter(
              textStyle: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _selectedTimeFilter = 'All';
                _selectedRouteFilter = 'All';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF002426),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Clear Filters',
              style: GoogleFonts.inter(
                textStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BusData {
  final String busNumber;
  final String route;
  final String departureTime;
  final String arrivalTime;
  final String driverName;
  final String contact;
  final bool isEvening;

  BusData({
    required this.busNumber,
    required this.route,
    required this.departureTime,
    required this.arrivalTime,
    required this.driverName,
    required this.contact,
    required this.isEvening,
  });
}

class BusDetailCard extends StatelessWidget {
  final BusData busData;

  BusDetailCard({required this.busData});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with bus number and route
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: busData.isEvening ? Colors.indigo[50] : Colors.amber[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: busData.isEvening ? Colors.indigo[200]! : Colors.amber[200]!,
                    width: 1,
                  ),
                ),
                child: Text(
                  "Bus ${busData.busNumber}",
                  style: GoogleFonts.inter(
                    textStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: busData.isEvening ? Colors.indigo[700] : Colors.amber[700],
                    ),
                  ),
                ),
              ),
              Spacer(),
              Icon(
                busData.isEvening ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
                color: busData.isEvening ? Colors.indigo[400] : Colors.amber[600],
                size: 20,
              ),
            ],
          ),

          SizedBox(height: 16),

          // Route information
          Row(
            children: [
              Expanded(
                child: Text(
                  busData.route,
                  style: GoogleFonts.inter(
                    textStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Time information
          Row(
            children: [
              Expanded(
                child: _buildTimeInfo("Departure", busData.departureTime, Icons.schedule),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[200],
                margin: EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: _buildTimeInfo("Arrival", busData.arrivalTime, Icons.access_time),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Driver information
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                  child: Icon(
                    Icons.person,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        busData.driverName,
                        style: GoogleFonts.inter(
                          textStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        busData.contact,
                        style: GoogleFonts.inter(
                          textStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    launch("tel://${busData.contact}");
                  },
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF03B0C1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.phone,
                      color: Color(0xFF03B0C1),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.grey[600],
          size: 20,
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            textStyle: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(height: 2),
        Text(
          time,
          style: GoogleFonts.inter(
            textStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}