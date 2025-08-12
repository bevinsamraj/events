// main.dart
import 'package:events/manage_events.dart';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'calendar_page.dart';
import 'add_page.dart';
import 'reports_page.dart';
import 'find_contact_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Curved Nav & Calendar Demo',
      debugShowCheckedModeBanner: false,
      home: const CurvedNavScreen(),
      routes: {
        '/reports': (context) => const ReportsPage(),
        '/find_contact': (context) => const FindContactPage(),
        '/ManageEventsPage': (context) => const ManageEventsPage(),
      },
      theme: ThemeData(
        // Set global AppBar theme with white icon (back arrow) color.
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B1957),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
    );
  }
}

class CurvedNavScreen extends StatefulWidget {
  const CurvedNavScreen({super.key});

  @override
  State<CurvedNavScreen> createState() => _CurvedNavScreenState();
}

class _CurvedNavScreenState extends State<CurvedNavScreen> {
  int _selectedIndex = 0;

  final _pages = [
    const HomePage(),
    const CalendarPage(),
    const AddEventPage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Background color set to 0xFFD1E8FF only
      color: const Color(0xFFD1E8FF),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Removed the drawer code.
        body: _pages[_selectedIndex],
        bottomNavigationBar: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF0B1957),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // The highlight circle (behind taps)
              Positioned(
                left: _circlePosition(context, _selectedIndex),
                top: -15,
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9ECCFA),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9ECCFA).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _selectedIndex == 0
                          ? Icons.home
                          : _selectedIndex == 1
                              ? Icons.calendar_month
                              : Icons.add,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              // Nav items (above the highlight circle)
              Row(
                children: [
                  Expanded(child: _buildNavItem(0, Icons.home, "Home")),
                  Expanded(
                      child:
                          _buildNavItem(1, Icons.calendar_month, "Calendar")),
                  Expanded(child: _buildNavItem(2, Icons.add, "Add")),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isActive = (_selectedIndex == index);
    return InkWell(
      onTap: () => _onItemTapped(index),
      child: Container(
        color: Colors.transparent, // Ensures entire area is tappable
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? const Color(0xFF9ECCFA) : Colors.white70,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? const Color(0xFF9ECCFA) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _circlePosition(BuildContext context, int index) {
    final totalWidth = MediaQuery.of(context).size.width - 32;
    final sectionWidth = totalWidth / 3;
    // Circle is 56 wide, so subtract half (28) to center
    return (sectionWidth * index) + (sectionWidth / 2) - 28;
  }
}
