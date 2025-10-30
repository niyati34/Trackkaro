import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import all page classes for navigation
import '../home_page.dart';
import '../busdetail_page.dart';
import '../manage_driver_page.dart';
import '../student_detail_page.dart';
import '../live_tracking_page.dart';
import '../live_camera.dart';
import '../notification.dart';
import '../update_details_page.dart';
import '../set_route_page.dart';

/// Centralized colors used across the dashboard.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF03B0C1);
  static const Color primaryDark = Color(0xFF0891B2);
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFEAB308);
  static const Color background = Color(0xFFF5F7FA);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);
  static const Color text = Color(0xFF1E293B);
  static const Color textLight = Color(0xFF64748B);
  static const Color sidebar = Color(0xFF0F172A);
}

/// Spacing scale (8pt grid based)
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Typography helpers
class AppText {
  AppText._();

  static TextStyle get _base => GoogleFonts.dmSans(letterSpacing: 0.2);

  static TextStyle get h1 => _base.copyWith(
      fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.text);
  static TextStyle get h2 => _base.copyWith(
      fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text);
  static TextStyle get h3 => _base.copyWith(
      fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text);
  static TextStyle get title => _base.copyWith(
      fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text);
  static TextStyle get body => _base.copyWith(
      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text);
  static TextStyle get bodyLight =>
      body.copyWith(color: AppColors.textLight, fontWeight: FontWeight.w400);
  static TextStyle get caption => _base.copyWith(
      fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textLight);
  static TextStyle get mono =>
      const TextStyle(fontFamily: 'RobotoMono', fontSize: 12);
}

/// Reusable elevated dashboard card
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: card,
      );
    }
    return card;
  }
}

/// Wrapper for page content that provides instant, smooth transitions
/// Use this to wrap the main content area (excluding sidebar) for better UX
class SmoothPageTransition extends StatefulWidget {
  final Widget child;
  final String pageKey; // Unique key for each page to trigger animation

  const SmoothPageTransition({
    super.key,
    required this.child,
    required this.pageKey,
  });

  @override
  State<SmoothPageTransition> createState() => _SmoothPageTransitionState();
}

class _SmoothPageTransitionState extends State<SmoothPageTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150), // Very fast, subtle
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(SmoothPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageKey != widget.pageKey) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: widget.child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.lg),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.h3),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppText.bodyLight),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.expand = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
      label: Text(label,
          style: AppText.title.copyWith(color: Colors.white, fontSize: 14)),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    if (expand) return SizedBox(width: double.infinity, child: btn);
    return btn;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.expand = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
      label: Text(label,
          style:
              AppText.title.copyWith(fontSize: 14, color: AppColors.primary)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    if (expand) return SizedBox(width: double.infinity, child: child);
    return child;
  }
}

/// Page scaffold that injects a unified background + optional sidebar region.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.body,
    this.sidebar,
    this.appBar,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    this.maxContentWidth = 1600,
  });

  final Widget body;
  final Widget? sidebar;
  final PreferredSizeWidget? appBar;
  final EdgeInsetsGeometry padding;
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: Padding(
          padding: padding,
          child: body,
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: appBar,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sidebar != null) sidebar!,
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// Modern sidebar navigation component
class ModernSidebar extends StatelessWidget {
  const ModernSidebar({
    super.key,
    required this.currentRoute,
  });

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Color(0xFF000000),
      ),
      child: Column(
        children: [
          // Header - Fixed
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Color(0xFF000000),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primaryDark,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Text(
                  'TrackKaro',
                  style: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: Text(
                      'MAIN MENU',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  _buildSidebarLink(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard,
                    label: 'Dashboard',
                    route: '/home',
                    context: context,
                  ),
                  _buildSidebarLink(
                    icon: Icons.directions_bus_outlined,
                    activeIcon: Icons.directions_bus,
                    label: 'Manage Buses',
                    route: '/buses',
                    context: context,
                  ),
                  _buildSidebarLink(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Manage Drivers',
                    route: '/drivers',
                    context: context,
                  ),
                  _buildSidebarLink(
                    icon: Icons.school_outlined,
                    activeIcon: Icons.school,
                    label: 'Student Details',
                    route: '/students',
                    context: context,
                  ),
                  _buildSidebarLink(
                    icon: Icons.location_on_outlined,
                    activeIcon: Icons.location_on,
                    label: 'Live Tracking',
                    route: '/tracking',
                    context: context,
                  ),
                  _buildSidebarLink(
                    icon: Icons.route_outlined,
                    activeIcon: Icons.alt_route,
                    label: 'Set Route',
                    route: '/set-route',
                    context: context,
                  ),
                  _buildSidebarLink(
                    icon: Icons.videocam_outlined,
                    activeIcon: Icons.videocam,
                    label: 'Live Camera',
                    route: '/camera',
                    context: context,
                  ),
                  SizedBox(height: 24),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      'TOOLS & SETTINGS',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  _buildSidebarLink(
                    icon: Icons.notifications_outlined,
                    activeIcon: Icons.notifications,
                    label: 'Notifications',
                    route: '/notifications',
                    context: context,
                  ),
                  _buildSidebarLink(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    label: 'Settings',
                    route: '/settings',
                    context: context,
                  ),
                  _buildSidebarLink(
                    icon: Icons.help_outline,
                    activeIcon: Icons.help,
                    label: 'Help',
                    route: '/help',
                    context: context,
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarLink({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String route,
    required BuildContext context,
  }) {
    bool isActive = currentRoute == route;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handleNavigation(route, context),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primaryDark,
                      ],
                    )
                  : null,
              color: isActive ? null : (Colors.white.withOpacity(0.05)),
              borderRadius: BorderRadius.circular(12),
              border: isActive
                  ? null
                  : Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color:
                      isActive ? Colors.white : Colors.white.withOpacity(0.8),
                  size: 22,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.9),
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNavigation(String route, BuildContext context) {
    // Instant navigation without animations for smooth tab-like experience
    switch (route) {
      case '/home':
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => HomePage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      case '/buses':
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                BusDetailPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      case '/drivers':
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ManageDriverPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      case '/students':
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                StudentDetailPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      case '/tracking':
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                LiveTrackingPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      case '/set-route':
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                SetRoutePage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      case '/camera':
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                LiveCameraPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      case '/notifications':
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                NotificationPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      case '/updates':
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                UpdateDetailsPage(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        break;
      default:
        // Do nothing for unimplemented routes
        break;
    }
  }
}
