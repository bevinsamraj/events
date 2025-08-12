// home_page.dart
import 'dart:convert';
import 'package:events/manage_events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'reports_page.dart';
import 'find_contact_page.dart';
import 'event_detail_page.dart';
import 'add_note_page.dart'; // Ensure this file exists
import 'manage_notes_page.dart'; // Import the Manage Notes Page

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _advancedDrawerController = AdvancedDrawerController();
  late Future<List<Map<String, dynamic>>> _futureEvents;
  late List<DateTime> _dates;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Generate 7 consecutive days starting today
    _dates =
        List.generate(7, (i) => DateTime(now.year, now.month, now.day + i));
    _futureEvents = _fetchEvents();
  }

  Future<List<Map<String, dynamic>>> _fetchEvents() async {
    final url = Uri.parse('https://demo.yelbee.com/events/events.php');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List) {
        return data
            .map((dynamic item) {
              final map = item as Map<String, dynamic>;
              // Convert tags from JSON string if needed
              if (map['tags'] is String) {
                try {
                  map['tags'] = json.decode(map['tags']) as List;
                } catch (_) {
                  map['tags'] = <String>[];
                }
              }
              return map;
            })
            .where((map) => map['status'] != 'off')
            .toList();
      }
    }
    return [];
  }

  /// Confirm Delete from HomePage
  Future<bool> _handleDeleteEvent(
      BuildContext context, Map<String, dynamic> event) async {
    final eventId = event['id']?.toString() ?? '';
    final eventName = event['event_name'] ?? 'Unknown';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Do you want to set status=off for "$eventName"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes')),
        ],
      ),
    );

    if (confirmed == true) {
      final deleteUrl = Uri.parse(
        'https://demo.yelbee.com/events/manage_events.php?action=delete&id=$eventId',
      );
      try {
        final response = await http.delete(deleteUrl);
        if (response.statusCode == 200) {
          final body = json.decode(response.body);
          if (body['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Event "$eventName" set to off.')),
              );
            }
            return true; // remove the tile from UI
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(body['error'] ?? 'Failed to delete.')),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('HTTP ${response.statusCode} - delete failed.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
    return false; // Not confirmed or failed => keep tile
  }

  /// Confirm Edit from HomePage
  Future<void> _handleEditEvent(
      BuildContext context, Map<String, dynamic> event) async {
    final eventName = event['event_name'] ?? 'Unknown';
    final id = event['id']?.toString() ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Event'),
        content: Text('Do you want to edit "$eventName"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes')),
        ],
      ),
    );

    if (confirmed == true) {
      // Navigate to ManageEventsPage with an optional parameter: the ID
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ManageEventsPage(
                  initialEditId: id,
                )),
      );
    }
  }

  void _handleMenuButtonPressed() {
    _advancedDrawerController.showDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _dates[_selectedIndex];
    return AdvancedDrawer(
      controller: _advancedDrawerController,
      animationCurve: Curves.easeInOut,
      animationDuration: const Duration(milliseconds: 300),
      drawer: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 50, color: Color(0xFF0B1957)),
              ),
              const SizedBox(height: 20),
              Text(
                "Welcome!",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0B1957),
                ),
              ),
              const SizedBox(height: 40),
              ListTile(
                leading: const Icon(Icons.report, color: Color(0xFF0B1957)),
                title: const Text('Reports'),
                onTap: () {
                  _advancedDrawerController.hideDrawer();
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ReportsPage()));
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.contact_phone, color: Color(0xFF0B1957)),
                title: const Text('Find Contact'),
                onTap: () {
                  _advancedDrawerController.hideDrawer();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FindContactPage()));
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.construction, color: Color(0xFF0B1957)),
                title: const Text('Manage Events'),
                onTap: () {
                  _advancedDrawerController.hideDrawer();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ManageEventsPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.note, color: Color(0xFF0B1957)),
                title: const Text('Manage Notes'),
                onTap: () {
                  _advancedDrawerController.hideDrawer();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ManageNotesPage()),
                  );
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFF0B1957)),
                title: const Text('Logout'),
                onTap: () {
                  _advancedDrawerController.hideDrawer();
                  // Implement your logout functionality here
                },
              ),
            ],
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFD1E8FF),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu,
                            size: 30, color: Colors.black),
                        onPressed: _handleMenuButtonPressed,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "SCHEDULE",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Events",
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0B1957),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Horizontal day selector
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dates.length,
                    itemBuilder: (context, index) {
                      final date = _dates[index];
                      final isSelected = index == _selectedIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIndex = index),
                        child: Container(
                          width: 70,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0B1957)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${date.day}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF0B1957),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _shortWeekDayName(date),
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: isSelected
                                        ? Colors.white70
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Selected Day Title
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Text(
                        "${_longWeekDayName(_dates[_selectedIndex])}, ${_dates[_selectedIndex].day}",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0B1957),
                        ),
                      ),
                    ],
                  ),
                ),

                // Display events
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _futureEvents,
                  builder: (context, snapshot) {
                    final selectedDate = _dates[_selectedIndex];
                    final events = snapshot.data ?? [];

                    // Filter events for the selected day
                    final selectedEvents = events.where((e) {
                      final startDateStr = e['start_date'] ?? '';
                      final endDateStr = e['end_date'] ?? '';
                      if (startDateStr.isEmpty || endDateStr.isEmpty)
                        return false;
                      try {
                        final startDate = DateTime.parse(startDateStr);
                        final endDate = DateTime.parse(endDateStr);
                        return (selectedDate.compareTo(startDate) >= 0 &&
                            selectedDate.compareTo(endDate) <= 0);
                      } catch (_) {
                        return false;
                      }
                    }).toList();

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      );
                    } else if (selectedEvents.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Text(
                          "No events for ${_formatDateDisplay(selectedDate)}.",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      );
                    } else {
                      return ListView.builder(
                        itemCount: selectedEvents.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, i) {
                          final e = selectedEvents[i];
                          return _buildDismissibleEventTile(e);
                        },
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissibleEventTile(Map<String, dynamic> e) {
    final id = e['id']?.toString() ?? '${e.hashCode}';
    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.horizontal,
      background: _swipeBackground(
        color: Colors.green,
        icon: Icons.edit,
        alignment: Alignment.centerLeft,
        text: "Edit",
      ),
      secondaryBackground: _swipeBackground(
        color: Colors.red,
        icon: Icons.delete,
        alignment: Alignment.centerRight,
        text: "Delete",
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Edit => navigate to ManageEventsPage with the ID
          await _handleEditEvent(context, e);
          return false; // do not remove the tile
        } else {
          // Delete => call manage_events.php to set status=off
          final result = await _handleDeleteEvent(context, e);
          return result; // true => remove tile, false => keep tile
        }
      },
      child: _buildEventTile(e),
    );
  }

  Widget _swipeBackground({
    required Color color,
    required IconData icon,
    required Alignment alignment,
    required String text,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> e) {
    final time = e['time'] ?? '';
    final title = e['event_name'] ?? '';
    final place = e['venue'] ?? '';
    final contact = e['contact_number'] ?? '';
    final type = (e['event_type'] ?? 'national').toLowerCase();
    final tags = (e['tags'] is List) ? e['tags'] as List : <String>[];

    final bool isNational = (type == 'national');
    final dotColor = isNational ? Colors.green : Colors.orange;
    final labelText = isNational ? "NATIONAL" : "INTERNATIONAL";
    final labelBgColor =
        isNational ? Colors.green.shade100 : Colors.orange.shade100;
    final labelTextColor =
        isNational ? Colors.green.shade800 : Colors.orange.shade800;

    final startDateStr = e['start_date'] ?? '';
    DateTime? startDate;
    if (startDateStr.isNotEmpty) {
      try {
        startDate = DateTime.parse(startDateStr);
      } catch (_) {}
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GestureDetector(
            onTap: () {
              // Show detail page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EventDetailPage(event: e)),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Time (rotated)
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        time,
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0B1957),
                        ),
                      ),
                    ),
                  ),
                  // Body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Label
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: labelBgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  labelText,
                                  style: GoogleFonts.lato(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: labelTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0B1957),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            place,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            contact,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (tags.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: tags.map<Widget>((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "#$tag",
                                    style: GoogleFonts.lato(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0B1957),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Show the event start date on the right
                  if (startDate != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        width: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1957),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${startDate.day}',
                              style: GoogleFonts.lato(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _shortMonthName(startDate.month),
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${startDate.year}',
                              style: GoogleFonts.lato(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // Positioned add button overlapping at the bottom right
        if (startDate != null)
          Positioned(
            right: 24,
            bottom: 16,
            child: GestureDetector(
              onTap: () {
                final eventId = e['id']?.toString() ?? '';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddNotePage(
                      eventId: eventId,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1957),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDateDisplay(DateTime date) {
    final dd = date.day < 10 ? '0${date.day}' : '${date.day}';
    final mm = date.month < 10 ? '0${date.month}' : '${date.month}';
    final yyyy = date.year;
    return "$dd-$mm-$yyyy";
  }

  String _shortWeekDayName(DateTime date) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[date.weekday - 1];
  }

  String _longWeekDayName(DateTime date) {
    const fullNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return fullNames[date.weekday - 1];
  }

  String _shortMonthName(int month) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return monthNames[month - 1];
  }
}
