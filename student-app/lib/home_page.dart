import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notification_page.dart';
import 'track_bus_page.dart';
import 'history_page.dart';
import 'contact_page.dart';
import 'bus_details.dart';
import 'login_page.dart'; // Replace with your actual login page file

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          titleTextStyle: GoogleFonts.montserratAlternates(
            textStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Color(0xFF03B0C1),
            ),
          ),
        ),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int selectedTabIndex = 0; // 0 for Morning, 1 for Evening
  AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  // Morning bus details
  Map<String, String> morningBusDetails = {
    'Bus No': '42A',
    'Estimated Arrival': '8:00 AM',
    'Pickup Time': '7:30 AM',
    'Drop-off Time': '9:30 AM',
    'Route': 'Home to XYZ Institute'
  };

  // Evening bus details
  Map<String, String> eveningBusDetails = {
    'Bus No': '42B',
    'Estimated Arrival': '4:30 PM',
    'Pickup Time': '4:00 PM',
    'Drop-off Time': '6:00 PM',
    'Route': 'XYZ Institute to Home'
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    super.dispose();
  }

  void _performLogout() async {
    if (_fadeController != null) {
      // Start fade out animation
      await _fadeController!.forward();
    }

    // Navigate to login page and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LoginPage(),
        transitionDuration: Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
          (Route<dynamic> route) => false, // Remove all previous routes
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat.yMMMMd().format(DateTime.now());

    // Get current bus details based on selected tab
    Map<String, String> currentBusDetails = selectedTabIndex == 0 ? morningBusDetails : eveningBusDetails;

    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: _fadeAnimation ?? AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation?.value ?? 1.0,
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TrackKaro',
                        style: GoogleFonts.montserratAlternates(
                          textStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: screenHeight * 0.031,
                            color: Color(0xFF03B0C1),
                          ),
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: screenHeight * 0.017,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              automaticallyImplyLeading: false,
              actions: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => NotificationPage()),
                    );
                  },
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: screenHeight * 0.0097),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF03B0C1).withOpacity(0.5),
                          spreadRadius: 1,
                          blurRadius: 7,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/notification_bell.png',
                      width: screenHeight * 0.055,
                      height: screenHeight * 0.055,
                    ),
                  ),
                ),
              ],
            ),
            drawer: Container(
              width: screenWidth * 0.8,
              child: Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      height: screenHeight * 0.25,
                      color: Color(0xFF03B0C1),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenHeight * 0.02),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.only(top: screenHeight * 0.025),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/p1.png',
                                  width: screenHeight * 0.15,
                                  height: screenHeight * 0.15,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'John Doe',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenHeight * 0.0225,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Student',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenHeight * 0.0175,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(screenHeight * 0.02),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal Details',
                            style: TextStyle(
                              fontSize: screenHeight * 0.0225,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: screenHeight * 0.01),
                          _buildPersonalDetail('Institute Name', 'XYZ Institute', screenHeight),
                          SizedBox(height: screenHeight * 0.01),
                          _buildPersonalDetail('GR No', '123456789', screenHeight),
                          SizedBox(height: screenHeight * 0.01),
                          _buildPersonalDetail('Email', 'johndoe@example.com', screenHeight),
                          SizedBox(height: screenHeight * 0.01),
                          _buildPersonalDetail('Phone', '+1234567890', screenHeight),
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    _buildLogoutButton(context, screenHeight),
                  ],
                ),
              ),
            ),
            body: SafeArea(
              child: Builder(
                builder: (context) => Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: screenHeight * 0.02),
                    Padding(
                      padding: EdgeInsets.only(left: screenHeight * 0.02),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Scaffold.of(context).openDrawer();
                            },
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: screenHeight * 0.01),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF03B0C1).withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/p1.png',
                                  width: screenHeight * 0.1,
                                  height: screenHeight * 0.1,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenHeight * 0.01),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'John Doe',
                                style: TextStyle(
                                  fontSize: screenHeight * 0.0225,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.004),
                              Text(
                                'Student',
                                style: TextStyle(
                                  fontSize: screenHeight * 0.0175,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.0193),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: screenHeight * 0.0193),
                      child: _buildBusDetailsBox(currentBusDetails, screenHeight), // Bus details box with tabs
                    ),
                    SizedBox(height: screenHeight * 0.0193),
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.only(top: screenHeight * 0.029),
                        decoration: BoxDecoration(
                          color: Color(0xFF03B0C1),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(screenHeight * 0.072),
                            topRight: Radius.circular(screenHeight * 0.072),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: screenHeight * 0.0193),
                              Padding(
                                padding: EdgeInsets.only(bottom: screenHeight * 0.0193),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildMenuItem(context, 'assets/images/track_bus_icon.png', 'Track Bus', TrackBusPage(), screenHeight),
                                    _buildMenuItem(context, 'assets/images/history_icon.png', 'History', HistoryPage(), screenHeight),
                                  ],
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.0193),
                              Padding(
                                padding: EdgeInsets.only(bottom: screenHeight * 0.0193),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildMenuItem(context, 'assets/images/contact_icon.png', 'Contact', ContactPage(), screenHeight),
                                    _buildMenuItem(context, 'assets/images/busdetails.png', 'Bus Details', BusDetailsPage(), screenHeight),
                                  ],
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.0193),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBusDetailsBox(Map<String, String?> busDetails, double screenHeight) {
    String busNo = busDetails['Bus No'] ?? 'N/A';
    String estimatedArrival = busDetails['Estimated Arrival'] ?? 'N/A';
    String pickupTime = busDetails['Pickup Time'] ?? 'N/A';
    String dropoffTime = busDetails['Drop-off Time'] ?? 'N/A';
    String route = busDetails['Route'] ?? 'N/A';

    return Container(
      padding: EdgeInsets.all(screenHeight * 0.012),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenHeight * 0.0193),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab switcher
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(screenHeight * 0.01),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTabIndex = 0;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                      decoration: BoxDecoration(
                        color: selectedTabIndex == 0 ? Color(0xFF03B0C1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(screenHeight * 0.01),
                      ),
                      child: Center(
                        child: Text(
                          'Morning',
                          style: TextStyle(
                            fontSize: screenHeight * 0.018,
                            fontWeight: FontWeight.w600,
                            color: selectedTabIndex == 0 ? Colors.white : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedTabIndex = 1;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                      decoration: BoxDecoration(
                        color: selectedTabIndex == 1 ? Color(0xFF03B0C1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(screenHeight * 0.01),
                      ),
                      child: Center(
                        child: Text(
                          'Evening',
                          style: TextStyle(
                            fontSize: screenHeight * 0.018,
                            fontWeight: FontWeight.w600,
                            color: selectedTabIndex == 1 ? Colors.white : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.015),
          // Bus details
          _buildBusDetailRow('Bus No', busNo, screenHeight),
          Divider(color: Colors.grey[300]),
          _buildBusDetailRow('Estimated Arrival', estimatedArrival, screenHeight),
          Divider(color: Colors.grey[300]),
          _buildBusDetailRow('Pickup Time', pickupTime, screenHeight),
          Divider(color: Colors.grey[300]),
          _buildBusDetailRow('Drop-off Time', dropoffTime, screenHeight),
          Divider(color: Colors.grey[300]),
          _buildBusDetailRow('Route', route, screenHeight),
        ],
      ),
    );
  }

  Widget _buildBusDetailRow(String label, String value, double screenHeight) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenHeight * 0.0012),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: screenHeight * 0.019,
              fontWeight: FontWeight.w600,
              color: Colors.teal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: screenHeight * 0.019,
              color: Colors.black87,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetail(String label, String detail, double screenHeight) {
    Color lightBlue = Color(0xFF03B0C1).withOpacity(0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01, horizontal: screenHeight * 0.0193),
          width: double.infinity,
          decoration: BoxDecoration(
            color: lightBlue,
            borderRadius: BorderRadius.circular(screenHeight * 0.01),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.figtree(
              fontSize: screenHeight * 0.0225,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: screenHeight * 0.005),
        Container(
          padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01, horizontal: screenHeight * 0.02),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(screenHeight * 0.0193),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            detail,
            style: GoogleFonts.figtree(
              fontSize: screenHeight * 0.0225,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, String imagePath, String label, Widget page, double screenHeight) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(screenHeight * 0.0193),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 4,
                  blurRadius: 12,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(screenHeight * 0.0193),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(screenHeight * 0.0193),
                child: Image.asset(
                  imagePath,
                  width: screenHeight * 0.1,
                  height: screenHeight * 0.1,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.raleway(
              textStyle: TextStyle(
                color: Colors.white,
                fontSize: screenHeight * 0.0185,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context, double screenHeight) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(screenHeight * 0.0193),
          ),
          child: Container(
            padding: EdgeInsets.all(screenHeight * 0.0193),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(screenHeight * 0.0193),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: screenHeight * 0.015),
                Text(
                  'Logout',
                  style: GoogleFonts.montserrat(
                    textStyle: TextStyle(
                      fontSize: screenHeight * 0.03,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF03B0C1),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.0193),
                Text(
                  'Are you sure you want to log out?',
                  style: GoogleFonts.raleway(
                    textStyle: TextStyle(
                      fontSize: screenHeight * 0.0225,
                      color: Colors.black87,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenHeight * 0.03),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: screenHeight * 0.025, vertical: screenHeight * 0.012),
                        textStyle: TextStyle(
                          fontSize: screenHeight * 0.0193,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(screenHeight * 0.01),
                        ),
                        elevation: 2,
                      ),
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        _performLogout(); // Perform logout with smooth transition
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF03B0C1),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: screenHeight * 0.025, vertical: screenHeight * 0.012),
                        textStyle: TextStyle(
                          fontSize: screenHeight * 0.0193,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(screenHeight * 0.01),
                        ),
                        elevation: 2,
                      ),
                      child: Text('Logout'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoutButton(BuildContext context, double screenHeight) {
    return Container(

      child: ListTile(
        onTap: () {
          _showLogoutConfirmationDialog(context, screenHeight);
        },
        leading: Container(
          padding: EdgeInsets.all(screenHeight * 0.008),
          decoration: BoxDecoration(
            color: Color(0xFF03B0C1).withOpacity(0.1),
            borderRadius: BorderRadius.circular(screenHeight * 0.008),
          ),
          child: Icon(
            Icons.exit_to_app,
            size: screenHeight * 0.025,
            color: Color(0xFF03B0C1),
          ),
        ),
        title: Text(
          'Logout',
          style: TextStyle(
            fontSize: screenHeight * 0.0225,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: screenHeight * 0.02,
          color: Colors.grey[400],
        ),
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(screenHeight * 0.01),
        ),
      ),
    );
  }
}