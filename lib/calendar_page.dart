// calendar_page.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'event_detail_page.dart';
import 'add_note_page.dart'; // <--- MAKE SURE YOU CREATE THIS FILE

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _currentMonth;
  late List<DateTime> _daysInMonth;
  DateTime? _selectedDate;

  // For showing grouped events above the tiles if user taps on a grouped event
  // We'll store them in _groupEvents if user clicks on a grouped event.
  List<Event> _groupEvents = [];

  Map<String, List<Event>> _events = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDate = null;
    _daysInMonth = _generateDaysInMonth(_currentMonth);
    _fetchEvents();
  }

  List<DateTime> _generateDaysInMonth(DateTime month) {
    DateTime firstDayOfMonth = DateTime(month.year, month.month, 1);
    int weekday = firstDayOfMonth.weekday;
    DateTime firstDisplayDay =
        firstDayOfMonth.subtract(Duration(days: (weekday % 7)));
    return List.generate(42, (index) {
      return firstDisplayDay.add(Duration(days: index));
    });
  }

  Future<void> _fetchEvents() async {
    final url = Uri.parse('https://demo.yelbee.com/events/get_events.php');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Map<String, List<Event>> events = {};
        if (data is Map<String, dynamic>) {
          data.forEach((key, value) {
            if (value is List) {
              events[key] = value.map((e) => Event.fromJson(e)).toList();
            }
          });
        }
        setState(() {
          _events = events;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load events. Status code: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "An error occurred: $e";
        _isLoading = false;
      });
    }
  }

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _daysInMonth = _generateDaysInMonth(_currentMonth);
      _selectedDate = null;
      _groupEvents.clear();
    });
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _daysInMonth = _generateDaysInMonth(_currentMonth);
      _selectedDate = null;
      _groupEvents.clear();
    });
  }

  /// Show a full date picker to choose year, month and day.
  Future<void> _selectFullDate() async {
    final initialDate = _selectedDate ?? _currentMonth;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(_currentMonth.year - 50, 1, 1),
      lastDate: DateTime(_currentMonth.year + 50, 12, 31),
    );
    if (picked != null) {
      setState(() {
        // Update the current month based on the selected date
        _currentMonth = DateTime(picked.year, picked.month);
        _selectedDate = picked;
        _daysInMonth = _generateDaysInMonth(_currentMonth);
        _groupEvents.clear();
      });
    }
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Information"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Calendar View',
          style: TextStyle(
            color: Color(0xFF0B1957),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFD1E8FF),
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFD1E8FF),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Calendar container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Month and navigation with tappable text to choose full date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _goToPreviousMonth,
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Color(0xFF0B1957)),
                        ),
                        GestureDetector(
                          onTap: _selectFullDate,
                          child: Text(
                            "${_monthName(_currentMonth.month)} ${_currentMonth.year}",
                            style: GoogleFonts.lato(
                              textStyle: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0B1957),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _goToNextMonth,
                          icon: const Icon(Icons.arrow_forward_ios,
                              color: Color(0xFF0B1957)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Weekday headers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _WeekdayHeader(label: 'Sun'),
                        _WeekdayHeader(label: 'Mon'),
                        _WeekdayHeader(label: 'Tue'),
                        _WeekdayHeader(label: 'Wed'),
                        _WeekdayHeader(label: 'Thu'),
                        _WeekdayHeader(label: 'Fri'),
                        _WeekdayHeader(label: 'Sat'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Calendar grid or loading/error
                    _buildCalendarGrid(today),
                    const SizedBox(height: 16),
                    // Legend
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildLegendItem(Colors.green, "Available"),
                          _buildLegendItem(Colors.red, "Booked"),
                          _buildLegendItem(Colors.orange, "Group"),
                          _buildLegendItem(Colors.grey.shade400, "Canceled"),
                          _buildLegendItem(
                              Colors.lightBlue.shade200, "Expired"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // If user tapped a grouped event, show them above the selected date events
              if (_groupEvents.isNotEmpty) _buildGroupEventsSection(),
              // Events for selected date
              _selectedDate == null
                  ? const SizedBox.shrink()
                  : _buildEventList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(DateTime today) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    } else {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1,
        ),
        itemCount: _daysInMonth.length,
        itemBuilder: (context, index) {
          final date = _daysInMonth[index];
          final isToday = _isSameDate(date, today);
          final isSelected =
              _selectedDate != null && _isSameDate(date, _selectedDate!);
          final isCurrentMonth = date.month == _currentMonth.month;

          final formattedKey = _formatDateKey(date);
          final eventsForDay = _events[formattedKey] ?? [];

          // If date < today => expired if no events, else see if any event status
          bool isPast =
              date.isBefore(DateTime(today.year, today.month, today.day));
          bool hasOffEvent = eventsForDay.any((ev) => ev.status == 'off');
          bool hasGroupEvent =
              eventsForDay.any((ev) => ev.isGroup && ev.status != 'off');
          bool hasBookedEvent =
              eventsForDay.any((ev) => !ev.isGroup && ev.status != 'off');

          Color bgColor = Colors.green.shade300; // default "available"

          if (!isCurrentMonth) {
            bgColor = Colors.grey.shade200; // outside current month
          } else if (eventsForDay.isEmpty) {
            // No events
            if (isPast) {
              bgColor = Colors.lightBlue.shade200; // expired
            } else {
              bgColor = Colors.green.shade300; // available
            }
          } else {
            // Has events
            if (hasOffEvent) {
              // treat as canceled => grey
              bgColor = Colors.grey.shade400;
            } else {
              // check group/booked
              if (hasGroupEvent) {
                bgColor = Colors.orange.shade300; // group
              } else if (hasBookedEvent) {
                bgColor = Colors.red.shade300; // booked
              }
            }
          }

          return GestureDetector(
            onTap: () {
              if (eventsForDay.isNotEmpty) {
                setState(() {
                  _selectedDate = date;
                  // If user taps a grouped event, find all grouped events in that day.
                  final anyGroup = eventsForDay
                      .any((ev) => ev.isGroup && ev.status != 'off');
                  if (anyGroup) {
                    _groupEvents = eventsForDay
                        .where((ev) => ev.isGroup && ev.status != 'off')
                        .toList();
                  } else {
                    _groupEvents.clear();
                  }
                });
              } else if (isPast) {
                _showMessage("The date is over; you can't book anything.");
              } else {
                _showMessage("Booking is open on this page.");
              }
            },
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.shade100 : bgColor,
                borderRadius: BorderRadius.circular(12),
                border:
                    isToday ? Border.all(color: Colors.blue, width: 2) : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      "${date.day}",
                      style: GoogleFonts.lato(
                        textStyle: TextStyle(
                          color: isCurrentMonth ? Colors.black : Colors.grey,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  if (eventsForDay
                      .any((ev) => ev.isGroup && ev.status != 'off'))
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.group,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0B1957),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupEventsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Grouped Events",
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B1957),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ..._groupEvents.map((ev) => _buildGroupEventTile(ev)).toList(),
        ],
      ),
    );
  }

  Widget _buildGroupEventTile(Event event) {
    final DateTime displayDate = _selectedDate ?? event.startDate;
    final day = displayDate.day;
    final month = _shortMonthName(displayDate.month);
    final year = displayDate.year;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailPage(
                    event: event.toMap(),
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.orange.shade300, width: 2),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        event.time,
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0B1957),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusLabel(
                              isOff: event.status == 'off',
                              isGroup: event.isGroup),
                          const SizedBox(height: 8),
                          Text(
                            event.title,
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0B1957),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            event.venue,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.contact_number,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (event.tags.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: event.tags.map<Widget>((tag) {
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
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1957),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: GoogleFonts.lato(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            month,
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '$year',
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
        Positioned(
          right: 24,
          bottom: 16,
          child: GestureDetector(
            onTap: () {
              final eventId = event.id;
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

  Widget _buildEventList() {
    final selectedDate = _selectedDate!;
    final formattedKey = _formatDateKey(selectedDate);
    final eventsForDay = _events[formattedKey] ?? [];

    // Exclude grouped events
    final nonGroupedEvents =
        eventsForDay.where((event) => !event.isGroup).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Events on ${_formattedDate(selectedDate)}",
            style: GoogleFonts.lato(
              textStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B1957),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...nonGroupedEvents.map((event) => _buildEventTile(event)).toList(),
        ],
      ),
    );
  }

  Widget _buildEventTile(Event event, {bool highlightGroup = false}) {
    final day = event.startDate.day;
    final month = _shortMonthName(event.startDate.month);
    final year = event.startDate.year;

    final isOff = event.status == 'off';

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailPage(
                    event: event.toMap(),
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: highlightGroup
                    ? Border.all(color: Colors.orange.shade300, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Time
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        event.time,
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0B1957),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusLabel(
                              isOff: isOff, isGroup: event.isGroup),
                          const SizedBox(height: 8),
                          Text(
                            event.title,
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0B1957),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            event.venue,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.contact_number,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (event.tags.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: event.tags.map<Widget>((tag) {
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
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1957),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: GoogleFonts.lato(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            month,
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '$year',
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
        Positioned(
          right: 24,
          bottom: 16,
          child: GestureDetector(
            onTap: () {
              final eventId = event.id;
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

  Widget _buildStatusLabel({required bool isOff, required bool isGroup}) {
    // off => "CANCELED"
    // group => "GROUP"
    // else => "BOOKED"
    String labelText = "BOOKED";
    Color dotColor = Colors.red;
    Color labelBgColor = Colors.red.shade100;
    Color labelTextColor = Colors.red.shade800;

    if (isOff) {
      labelText = "CANCELED";
      dotColor = Colors.grey.shade700;
      labelBgColor = Colors.grey.shade300;
      labelTextColor = Colors.grey.shade800;
    } else if (isGroup) {
      labelText = "GROUP";
      dotColor = Colors.orange;
      labelBgColor = Colors.orange.shade100;
      labelTextColor = Colors.orange.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    );
  }

  String _formatDateKey(DateTime date) {
    return "${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}";
  }

  String _formattedDate(DateTime date) {
    return "${_monthName(date.month)} ${date.day}, ${date.year}";
  }

  String _monthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month];
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

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _twoDigits(int n) => n < 10 ? "0$n" : "$n";
}

class _WeekdayHeader extends StatelessWidget {
  final String label;
  const _WeekdayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B1957),
            ),
          ),
        ),
      ),
    );
  }
}

class Event {
  final String id;
  final String title;
  final String description;
  final String status; // "on" or "off"
  final bool isGroup;
  final String time;
  final String venue;
  final String contact_number;
  final String event_type;
  final List<String> tags;
  final DateTime startDate;
  final String image;
  final String boardingPass;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.isGroup,
    required this.time,
    required this.venue,
    required this.contact_number,
    required this.event_type,
    required this.tags,
    required this.startDate,
    required this.image,
    required this.boardingPass,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: (json['id'] ?? '').toString(),
      title: json['event_name'] ?? 'No Title',
      description: json['event_details'] ?? '',
      status: json['status'] ?? 'on',
      isGroup: json['is_group'] ?? false,
      time: json['time'] ?? '',
      venue: json['venue'] ?? '',
      contact_number: json['contact_number'] ?? '',
      event_type: json['event_type'] ?? 'national',
      tags: _parseTags(json['tags'] ?? []),
      startDate: DateTime.parse(json['start_date']),
      image: json['image'] ?? '',
      boardingPass: json['boarding_pass'] ?? '',
    );
  }

  static List<String> _parseTags(dynamic rawTags) {
    if (rawTags is List) {
      return rawTags.map((e) => e.toString()).toList();
    } else if (rawTags is String) {
      try {
        final decoded = json.decode(rawTags);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        return rawTags.split(',').map((s) => s.trim()).toList();
      }
    }
    return [];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_name': title,
      'event_details': description,
      'status': status,
      'is_group': isGroup,
      'time': time,
      'venue': venue,
      'contact_number': contact_number,
      'event_type': event_type,
      'tags': tags,
      'start_date':
          "${startDate.year}-${_twoDigits(startDate.month)}-${_twoDigits(startDate.day)}",
      'image': image,
      'boarding_pass': boardingPass,
    };
  }

  String _twoDigits(int n) => n < 10 ? "0$n" : "$n";
}
