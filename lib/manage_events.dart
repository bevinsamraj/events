import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

class ManageEventsPage extends StatefulWidget {
  final String? initialEditId;
  const ManageEventsPage({Key? key, this.initialEditId}) : super(key: key);

  @override
  State<ManageEventsPage> createState() => _ManageEventsPageState();
}

class _ManageEventsPageState extends State<ManageEventsPage> {
  final String _apiUrl = 'https://demo.yelbee.com/events/manage_events.php';
  bool _isLoading = true;
  String _errorMsg = '';
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _filteredEvents = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents().then((_) {
      _filteredEvents.sort((a, b) => int.parse(b['id'].toString())
          .compareTo(int.parse(a['id'].toString())));
      if (widget.initialEditId != null) {
        final e = _events.firstWhere(
          (x) => x['id']?.toString() == widget.initialEditId,
          orElse: () => {},
        );
        if (e.isNotEmpty) {
          _editEvent(e);
        }
      }
    });
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });
    try {
      final response = await http.get(Uri.parse("$_apiUrl?action=list"));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          List<Map<String, dynamic>> events =
              data.map((item) => item as Map<String, dynamic>).toList();
          events.sort((a, b) => int.parse(b['id'].toString())
              .compareTo(int.parse(a['id'].toString())));
          setState(() {
            _events = events;
            _filteredEvents = List.from(_events);
          });
        } else {
          setState(() {
            _errorMsg = 'Invalid data format';
          });
        }
      } else {
        setState(() {
          _errorMsg = 'Failed to load data: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEvent(String id, String eventName) async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Delete Event',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0B1957),
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$eventName"?\n\nThis action cannot be undone.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.delete(
        Uri.parse("$_apiUrl?action=delete&id=$id"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          await _fetchEvents();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Event "$eventName" deleted successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Failed to delete event'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting event: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _editEvent(Map<String, dynamic> event) async {
    if ((event['status'] ?? 'on') == 'off') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot edit events with status "OFF"'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EditEventPage(
          event: event,
          apiUrl: _apiUrl,
        ),
      ),
    );
    if (updated == true) {
      _fetchEvents();
    }
  }

  void _openSearch() {
    showSearch(
      context: context,
      delegate: EventSearchDelegate(
        events: _events,
        onEdit: (event) async {
          // Edit the event
          await _editEvent(event);
        },
        onDelete: (id, eventName) async {
          // Delete the event
          await _deleteEvent(id, eventName);
        },
      ),
    );
  }

  void _openFilter() async {
    DateTime? start;
    DateTime? end;
    await showDialog(
      context: context,
      builder: (ctx) {
        return _FilterDialog(
          onApply: (DateTime? s, DateTime? e) {
            start = s;
            end = e;
          },
        );
      },
    );
    if (start != null && end != null) {
      setState(() {
        _filteredEvents = _events.where((event) {
          try {
            final eventDate = DateTime.parse(event['start_date'].toString());
            return eventDate
                    .isAfter(start!.subtract(const Duration(days: 1))) &&
                eventDate.isBefore(end!.add(const Duration(days: 1)));
          } catch (_) {
            return false;
          }
        }).toList();
      });
    } else {
      setState(() {
        _filteredEvents = List.from(_events);
      });
    }
  }

  void _clearFilter() {
    setState(() {
      _filteredEvents = List.from(_events);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Filter cleared'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD1E8FF),
      appBar: AppBar(
        title: Text(
          'Manage Events (${_filteredEvents.length})',
          style: GoogleFonts.poppins(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0B1957),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _openSearch,
            tooltip: 'Search Events',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: _openFilter,
            tooltip: 'Filter Events',
          ),
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: _clearFilter,
            tooltip: 'Clear Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchEvents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        _errorMsg,
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchEvents,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _filteredEvents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No events found',
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters or search criteria',
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        if (_filteredEvents.length != _events.length)
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(8),
                            color: Colors.blue.shade50,
                            child: Text(
                              'Showing ${_filteredEvents.length} of ${_events.length} events',
                              style: GoogleFonts.poppins(
                                color: Colors.blue.shade700,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _fetchEvents,
                            child: ListView.builder(
                              itemCount: _filteredEvents.length,
                              itemBuilder: (context, index) {
                                final e = _filteredEvents[index];
                                final id = e['id']?.toString() ?? '';
                                final name = e['event_name'] ?? '';
                                final status = e['status'] ?? 'on';
                                final startDateRaw = e['start_date'] ?? '';
                                final endDateRaw = e['end_date'] ?? '';
                                final startDate = _formatDate(startDateRaw);
                                final endDate = _formatDate(endDateRaw);
                                final contact = e['contact_name'] ?? '';
                                final city = e['city'] ?? '';
                                final venue = e['venue'] ?? '';
                                final isOff = (status == 'off');

                                return Card(
                                  margin: const EdgeInsets.all(8),
                                  color: isOff
                                      ? Colors.grey.shade300
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: isOff ? 1 : 3,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title Row with Status Badge
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isOff
                                                      ? Colors.grey.shade700
                                                      : const Color(0xFF0B1957),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isOff
                                                    ? Colors.red.shade100
                                                    : Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isOff
                                                      ? Colors.red.shade700
                                                      : Colors.green.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Date Row
                                        Row(
                                          children: [
                                            const Icon(Icons.calendar_today,
                                                size: 16, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '$startDate to $endDate',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        // Location Row
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on,
                                                size: 16, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '$venue, $city',
                                                style: GoogleFonts.poppins(
                                                    fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),

                                        // Contact Row
                                        Row(
                                          children: [
                                            const Icon(Icons.person,
                                                size: 16, color: Colors.grey),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                contact,
                                                style: GoogleFonts.poppins(
                                                    fontSize: 14),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Action Buttons Row
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: isOff
                                                    ? Colors.grey.shade100
                                                    : Colors.green.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                icon: Icon(
                                                  Icons.edit,
                                                  color: isOff
                                                      ? Colors.grey
                                                      : Colors.green,
                                                  size: 20,
                                                ),
                                                onPressed: isOff
                                                    ? null
                                                    : () => _editEvent(e),
                                                tooltip: isOff
                                                    ? 'Cannot edit OFF events'
                                                    : 'Edit Event',
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.red,
                                                    size: 20),
                                                onPressed: () =>
                                                    _deleteEvent(id, name),
                                                tooltip: 'Delete Event',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final DateTime dt = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}

// Enhanced Search Delegate with Edit and Delete functionality
class EventSearchDelegate extends SearchDelegate<Map<String, dynamic>> {
  final List<Map<String, dynamic>> events;
  final Function(Map<String, dynamic>) onEdit;
  final Function(String, String) onDelete;

  EventSearchDelegate({
    required this.events,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, {}),
    );
  }

  List<Map<String, dynamic>> _filterEvents(String query) {
    if (query.isEmpty) return events;

    return events.where((event) {
      final eventName = event['event_name']?.toString().toLowerCase() ?? '';
      final city = event['city']?.toString().toLowerCase() ?? '';
      final venue = event['venue']?.toString().toLowerCase() ?? '';
      final contact = event['contact_name']?.toString().toLowerCase() ?? '';
      final eventDate = _formatDate(event['start_date']?.toString() ?? '');
      final queryLower = query.toLowerCase();

      return eventName.contains(queryLower) ||
          city.contains(queryLower) ||
          venue.contains(queryLower) ||
          contact.contains(queryLower) ||
          eventDate.contains(queryLower);
    }).toList();
  }

  String _formatDate(String dateStr) {
    try {
      final DateTime dt = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = _filterEvents(query);

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No results found for "$query"',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final event = results[index];
        final status = event['status']?.toString() ?? 'on';
        final isOff = status == 'off';
        final eventName = event['event_name'] ?? '';
        final eventId = event['id']?.toString() ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        eventName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isOff ? Colors.grey : const Color(0xFF0B1957),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color:
                            isOff ? Colors.red.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOff
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Event Details
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_formatDate(event['start_date']?.toString() ?? '')} - ${event['city'] ?? ''}',
                        style: GoogleFonts.poppins(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event['venue'] ?? '',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        event['contact_name'] ?? '',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: Colors.grey.shade600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Buttons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Edit Button
                    Container(
                      decoration: BoxDecoration(
                        color:
                            isOff ? Colors.grey.shade100 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.edit,
                          color: isOff ? Colors.grey : Colors.green,
                          size: 20,
                        ),
                        onPressed: isOff
                            ? null
                            : () {
                                close(context, {});
                                onEdit(event);
                              },
                        tooltip:
                            isOff ? 'Cannot edit OFF events' : 'Edit Event',
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Delete Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red, size: 20),
                        onPressed: () {
                          close(context, {});
                          onDelete(eventId, eventName);
                        },
                        tooltip: 'Delete Event',
                      ),
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

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = _filterEvents(query).take(10).toList();

    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search events',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching by event name, city, venue, or contact',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final event = suggestions[index];
        return ListTile(
          leading: Icon(Icons.event, color: Color(0xFF0B1957)),
          title: Text(
            event['event_name'] ?? '',
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${event['city'] ?? ''} - ${_formatDate(event['start_date']?.toString() ?? '')}',
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            query = event['event_name'] ?? '';
            showResults(context);
          },
        );
      },
    );
  }
}

// Filter Dialog
class _FilterDialog extends StatefulWidget {
  final Function(DateTime?, DateTime?) onApply;
  const _FilterDialog({Key? key, required this.onApply}) : super(key: key);

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        "Filter Events",
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text("Start Date"),
            subtitle: Text(_startDate != null
                ? DateFormat('dd-MM-yyyy').format(_startDate!)
                : "Not set"),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _pickStartDate,
            ),
          ),
          ListTile(
            title: const Text("End Date"),
            subtitle: Text(_endDate != null
                ? DateFormat('dd-MM-yyyy').format(_endDate!)
                : "Not set"),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _pickEndDate,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onApply(null, null);
            Navigator.pop(context);
          },
          child: const Text("Clear"),
        ),
        TextButton(
          onPressed: () {
            widget.onApply(_startDate, _endDate);
            Navigator.pop(context);
          },
          child: const Text("Apply"),
        ),
      ],
    );
  }
}

// Edit Event Page (keeping your original implementation)
class _EditEventPage extends StatefulWidget {
  final Map<String, dynamic> event;
  final String apiUrl;
  const _EditEventPage({
    Key? key,
    required this.event,
    required this.apiUrl,
  }) : super(key: key);

  @override
  State<_EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<_EditEventPage> {
  final _formKey = GlobalKey<FormState>();
  final CloudinaryPublic _cloudinary =
      CloudinaryPublic('dzlhl3e6j', 'unsigned_preset', cache: false);
  final ImagePicker _picker = ImagePicker();

  late TextEditingController eventNameCtrl;
  late TextEditingController startDateCtrl;
  late TextEditingController endDateCtrl;
  late TextEditingController startTimeCtrl;
  late TextEditingController endTimeCtrl;
  late TextEditingController venueCtrl;
  late TextEditingController cityCtrl;
  late TextEditingController contactNameCtrl;
  late TextEditingController contactNumberCtrl;
  late TextEditingController eventDetailsCtrl;
  late TextEditingController tagsCtrl;
  late TextEditingController boardingPassCtrl;
  late TextEditingController imageCtrl;

  String eventType = 'national';
  String status = 'on';
  bool _isSubmitting = false;

  Map<String, List<String>> _stateCityMap = {};
  List<String> _allCitiesWithState = [];

  @override
  void initState() {
    super.initState();
    eventNameCtrl =
        TextEditingController(text: widget.event['event_name'] ?? '');
    final timeVal = (widget.event['time'] ?? '').toString();
    final splittedTime = timeVal.split('-');
    startTimeCtrl = TextEditingController(
      text: splittedTime.isNotEmpty ? splittedTime[0].trim() : '6:00 PM',
    );
    endTimeCtrl = TextEditingController(
      text: splittedTime.length > 1 ? splittedTime[1].trim() : '9:00 PM',
    );
    final rawStart = widget.event['start_date']?.toString() ?? '';
    final rawEnd = widget.event['end_date']?.toString() ?? '';
    startDateCtrl = TextEditingController(
      text: rawStart.isNotEmpty ? _formatToDDMMYYYY(rawStart) : '',
    );
    endDateCtrl = TextEditingController(
      text: rawEnd.isNotEmpty ? _formatToDDMMYYYY(rawEnd) : '',
    );
    venueCtrl = TextEditingController(text: widget.event['venue'] ?? '');
    cityCtrl = TextEditingController(text: widget.event['city'] ?? '');
    contactNameCtrl =
        TextEditingController(text: widget.event['contact_name'] ?? '');
    contactNumberCtrl =
        TextEditingController(text: widget.event['contact_number'] ?? '');
    eventDetailsCtrl =
        TextEditingController(text: widget.event['event_details'] ?? '');
    boardingPassCtrl =
        TextEditingController(text: widget.event['boarding_pass'] ?? '');
    imageCtrl = TextEditingController(text: widget.event['image'] ?? '');
    tagsCtrl = TextEditingController();

    final rawTags = widget.event['tags'];
    if (rawTags is String) {
      try {
        final parsedTags = json.decode(rawTags);
        if (parsedTags is List) {
          tagsCtrl.text = parsedTags.join(', ');
        } else {
          tagsCtrl.text = rawTags;
        }
      } catch (_) {
        tagsCtrl.text = rawTags;
      }
    } else if (rawTags is List) {
      tagsCtrl.text = rawTags.join(', ');
    }
    status = (widget.event['status'] ?? 'on').toString();
    eventType = (widget.event['event_type'] ?? 'national').toString();
    _loadCityData();
  }

  @override
  void dispose() {
    eventNameCtrl.dispose();
    startDateCtrl.dispose();
    endDateCtrl.dispose();
    startTimeCtrl.dispose();
    endTimeCtrl.dispose();
    venueCtrl.dispose();
    cityCtrl.dispose();
    contactNameCtrl.dispose();
    contactNumberCtrl.dispose();
    eventDetailsCtrl.dispose();
    boardingPassCtrl.dispose();
    imageCtrl.dispose();
    tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCityData() async {
    try {
      final data = await rootBundle.loadString('assets/city.json');
      final Map<String, dynamic> jsonResult = json.decode(data);
      _stateCityMap = jsonResult.map((state, cityList) {
        final List<String> cities =
            (cityList as List).map((c) => c.toString()).toList();
        return MapEntry(state, cities);
      });
      _allCitiesWithState.clear();
      _stateCityMap.forEach((state, cities) {
        for (var city in cities) {
          _allCitiesWithState.add("$city, $state");
        }
      });
    } catch (_) {}
    setState(() {});
  }

  String _formatToDDMMYYYY(String yyyyMMdd) {
    try {
      final dt = DateFormat('yyyy-MM-dd').parse(yyyyMMdd);
      return DateFormat('dd-MM-yyyy').format(dt);
    } catch (_) {
      return yyyyMMdd;
    }
  }

  DateTime _parseIndianDate(String dateString) {
    final parts = dateString.split('-');
    final day = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final year = int.parse(parts[2]);
    return DateTime(year, month, day);
  }

  String _toDBDate(String dateString) {
    final dt = _parseIndianDate(dateString);
    final yyyy = dt.year;
    final mm = dt.month < 10 ? '0${dt.month}' : '${dt.month}';
    final dd = dt.day < 10 ? '0${dt.day}' : '${dt.day}';
    return '$yyyy-$mm-$dd';
  }

  BoxDecoration _blueBorderDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF0B1957), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.lato(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0B1957))),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hint,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: _blueBorderDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.lato(color: Colors.grey),
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
        ),
        validator: validator,
      ),
    );
  }

  Future<void> _pickStartDate() async {
    DateTime initialDate = DateTime.now();
    if (startDateCtrl.text.isNotEmpty) {
      try {
        initialDate = _parseIndianDate(startDateCtrl.text);
      } catch (_) {}
    }
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        startDateCtrl.text = DateFormat('dd-MM-yyyy').format(pickedDate);
        if (endDateCtrl.text.isEmpty) {
          endDateCtrl.text = startDateCtrl.text;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    DateTime initialDate = DateTime.now();
    if (endDateCtrl.text.isNotEmpty) {
      try {
        initialDate = _parseIndianDate(endDateCtrl.text);
      } catch (_) {}
    }
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        endDateCtrl.text = DateFormat('dd-MM-yyyy').format(pickedDate);
      });
    }
  }

  void _incrementEndDate() {
    if (endDateCtrl.text.isEmpty) return;
    try {
      final current = _parseIndianDate(endDateCtrl.text);
      final next = current.add(const Duration(days: 1));
      setState(() {
        endDateCtrl.text = DateFormat('dd-MM-yyyy').format(next);
      });
    } catch (_) {}
  }

  Future<void> _pickStartTime() async {
    TimeOfDay initialTime = const TimeOfDay(hour: 18, minute: 0);
    if (startTimeCtrl.text.isNotEmpty) {
      try {
        initialTime = _parseTimeOfDay(startTimeCtrl.text);
      } catch (_) {}
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime != null) {
      setState(() {
        startTimeCtrl.text = pickedTime.format(context);
      });
    }
  }

  Future<void> _pickEndTime() async {
    TimeOfDay initialTime = const TimeOfDay(hour: 21, minute: 0);
    if (endTimeCtrl.text.isNotEmpty) {
      try {
        initialTime = _parseTimeOfDay(endTimeCtrl.text);
      } catch (_) {}
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime != null) {
      setState(() {
        endTimeCtrl.text = pickedTime.format(context);
      });
    }
  }

  TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);
    final period = parts[1].toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _isEndTimeAfterStartTime(TimeOfDay start, TimeOfDay end) {
    return (end.hour * 60 + end.minute) > (start.hour * 60 + start.minute);
  }

  Widget _buildCityAutocomplete() {
    return Container(
      decoration: _blueBorderDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return _allCitiesWithState.take(5);
          }
          return _allCitiesWithState.where((cityState) => cityState
              .toLowerCase()
              .contains(textEditingValue.text.toLowerCase()));
        },
        fieldViewBuilder: (context, textController, focusNode, onSubmit) {
          textController.text = cityCtrl.text;
          textController.selection = TextSelection.fromPosition(
            TextPosition(offset: textController.text.length),
          );
          return TextFormField(
            controller: textController,
            focusNode: focusNode,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: "Select or type city",
              hintStyle: GoogleFonts.lato(color: Colors.grey),
              prefixIcon:
                  const Icon(Icons.location_city, color: Color(0xFF0B1957)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select or enter city';
              }
              return null;
            },
          );
        },
        onSelected: (String selection) {
          final parts = selection.split(",");
          cityCtrl.text = parts.isNotEmpty ? parts[0].trim() : selection;
        },
      ),
    );
  }

  Widget _buildEventTypeSelector() {
    return Container(
      decoration: _blueBorderDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => eventType = 'national'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: eventType == 'national'
                      ? const Color(0xFF0B1957)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'NATIONAL',
                    style: GoogleFonts.lato(
                      color: eventType == 'national'
                          ? Colors.white
                          : const Color(0xFF0B1957),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => eventType = 'international'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: eventType == 'international'
                      ? const Color(0xFF0B1957)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'INTERNATIONAL',
                    style: GoogleFonts.lato(
                      color: eventType == 'international'
                          ? Colors.white
                          : const Color(0xFF0B1957),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Container(
      decoration: _blueBorderDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => status = 'on'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: status == 'on'
                      ? const Color(0xFF0B1957)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'ON',
                    style: GoogleFonts.lato(
                      color: status == 'on'
                          ? Colors.white
                          : const Color(0xFF0B1957),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => status = 'off'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: status == 'off'
                      ? const Color(0xFF0B1957)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'OFF',
                    style: GoogleFonts.lato(
                      color: status == 'off'
                          ? Colors.white
                          : const Color(0xFF0B1957),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage(bool isBoardingPass) async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => _isSubmitting = true);
        final response = await _cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            pickedFile.path,
            resourceType: CloudinaryResourceType.Image,
          ),
        );
        final uploadedUrl = response.secureUrl;
        setState(() {
          if (isBoardingPass) {
            boardingPassCtrl.text = uploadedUrl;
          } else {
            imageCtrl.text = uploadedUrl;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBoardingPass
                ? 'Boarding Pass uploaded successfully'
                : 'Image uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _removeImage(bool isBoardingPass) {
    setState(() {
      if (isBoardingPass) {
        boardingPassCtrl.text = '';
      } else {
        imageCtrl.text = '';
      }
    });
  }

  Widget _buildImagePickSection({
    required String label,
    required TextEditingController controller,
    required bool isBoardingPass,
    required String hint,
  }) {
    return _buildLabeledField(
      label: label,
      child: Column(
        children: [
          Container(
            decoration: _blueBorderDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: TextFormField(
              controller: controller,
              readOnly: true,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: GoogleFonts.lato(color: Colors.grey),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                          isBoardingPass ? Icons.upload_file : Icons.image,
                          color: const Color(0xFF0B1957)),
                      onPressed: () => _pickAndUploadImage(isBoardingPass),
                    ),
                    if (controller.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeImage(isBoardingPass),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(
                      child: Image.network(
                        controller.text,
                        fit: BoxFit.contain,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                        errorBuilder: (ctx, e, stack) {
                          return const Center(child: Icon(Icons.error));
                        },
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                      image: NetworkImage(controller.text), fit: BoxFit.cover),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final id = widget.event['id']?.toString() ?? '';
    final combinedTime = "${startTimeCtrl.text} - ${endTimeCtrl.text}";
    final dbStartDate =
        startDateCtrl.text.isNotEmpty ? _toDBDate(startDateCtrl.text) : '';
    final dbEndDate =
        endDateCtrl.text.isNotEmpty ? _toDBDate(endDateCtrl.text) : '';

    final List<String> tagsList = tagsCtrl.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .map((tag) => tag[0].toUpperCase() + tag.substring(1).toLowerCase())
        .toList();

    final Map<String, dynamic> body = {
      'id': id,
      'event_name': eventNameCtrl.text,
      'start_date': dbStartDate,
      'end_date': dbEndDate,
      'time': combinedTime,
      'venue': venueCtrl.text,
      'city': cityCtrl.text,
      'event_type': eventType,
      'contact_name': contactNameCtrl.text,
      'contact_number': contactNumberCtrl.text,
      'event_details': eventDetailsCtrl.text,
      'boarding_pass': boardingPassCtrl.text,
      'image': imageCtrl.text,
      'status': status,
      'tags': tagsList,
    };

    try {
      final response = await http.post(
        Uri.parse('${widget.apiUrl}?action=update'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );
      final data = json.decode(response.body);
      if (data['success'] == true) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Event updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Failed to update'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventName = widget.event['event_name'] ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFD1E8FF),
      appBar: AppBar(
        title: Text(
          'Edit Event',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF0B1957),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Text(
                    'Editing: $eventName',
                    style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0B1957),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "Event Name",
                    child: _buildTextFormField(
                      controller: eventNameCtrl,
                      hint: "Enter event name",
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter event name';
                        }
                        return null;
                      },
                      prefixIcon:
                          const Icon(Icons.event, color: Color(0xFF0B1957)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "Start Date (dd-MM-yyyy)",
                    child: _buildTextFormField(
                      controller: startDateCtrl,
                      hint: "dd-MM-yyyy",
                      readOnly: true,
                      onTap: _pickStartDate,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select start date';
                        }
                        return null;
                      },
                      prefixIcon: const Icon(Icons.calendar_today,
                          color: Color(0xFF0B1957)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "End Date (dd-MM-yyyy)",
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        _buildTextFormField(
                          controller: endDateCtrl,
                          hint: "dd-MM-yyyy",
                          readOnly: true,
                          onTap: _pickEndDate,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select end date';
                            }
                            try {
                              final startDt =
                                  _parseIndianDate(startDateCtrl.text);
                              final endDt = _parseIndianDate(value);
                              if (endDt.isBefore(startDt)) {
                                return 'End date must be after start date';
                              }
                            } catch (_) {}
                            return null;
                          },
                          prefixIcon: const Icon(Icons.calendar_today,
                              color: Color(0xFF0B1957)),
                        ),
                        Positioned(
                          right: 8,
                          child: IconButton(
                            icon: const Icon(Icons.add_box,
                                color: Color(0xFF0B1957)),
                            onPressed: _incrementEndDate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "Start Time",
                    child: _buildTextFormField(
                      controller: startTimeCtrl,
                      hint: "e.g. 6:00 PM",
                      readOnly: true,
                      onTap: _pickStartTime,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFF0B1957)),
                        onPressed: _pickStartTime,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select start time';
                        }
                        return null;
                      },
                      prefixIcon: const Icon(Icons.access_time,
                          color: Color(0xFF0B1957)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "End Time",
                    child: _buildTextFormField(
                      controller: endTimeCtrl,
                      hint: "e.g. 9:00 PM",
                      readOnly: true,
                      onTap: _pickEndTime,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFF0B1957)),
                        onPressed: _pickEndTime,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select end time';
                        }
                        if (startTimeCtrl.text.isNotEmpty &&
                            endTimeCtrl.text.isNotEmpty) {
                          final st = _parseTimeOfDay(startTimeCtrl.text);
                          final et = _parseTimeOfDay(endTimeCtrl.text);
                          if (!_isEndTimeAfterStartTime(st, et)) {
                            return 'End time must be after start time';
                          }
                        }
                        return null;
                      },
                      prefixIcon: const Icon(Icons.access_time,
                          color: Color(0xFF0B1957)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "Venue",
                    child: _buildTextFormField(
                      controller: venueCtrl,
                      hint: "Enter venue",
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter venue';
                        }
                        return null;
                      },
                      prefixIcon: const Icon(Icons.location_on,
                          color: Color(0xFF0B1957)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "City",
                    child: _buildCityAutocomplete(),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Event Type",
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0B1957),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildEventTypeSelector(),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "Contact Name",
                    child: _buildTextFormField(
                      controller: contactNameCtrl,
                      hint: "Enter contact name",
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter contact name';
                        }
                        return null;
                      },
                      prefixIcon:
                          const Icon(Icons.person, color: Color(0xFF0B1957)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "Contact Number",
                    child: _buildTextFormField(
                      controller: contactNumberCtrl,
                      hint: "Enter contact number",
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter contact number';
                        }
                        return null;
                      },
                      prefixIcon:
                          const Icon(Icons.phone, color: Color(0xFF0B1957)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "Event Details (Optional)",
                    child: _buildTextFormField(
                      controller: eventDetailsCtrl,
                      hint: "Describe the event...",
                      maxLines: 3,
                      validator: (_) => null,
                      prefixIcon:
                          const Icon(Icons.info, color: Color(0xFF0B1957)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "Tags (comma separated)",
                    child: _buildTextFormField(
                      controller: tagsCtrl,
                      hint: "E.g. Special, Meeting",
                      prefixIcon:
                          const Icon(Icons.label, color: Color(0xFF0B1957)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildImagePickSection(
                    label: "Boarding Pass Image (Optional)",
                    controller: boardingPassCtrl,
                    isBoardingPass: true,
                    hint: "Upload boarding pass image",
                  ),
                  const SizedBox(height: 16),
                  _buildImagePickSection(
                    label: "Event Image (Optional)",
                    controller: imageCtrl,
                    isBoardingPass: false,
                    hint: "Upload event image",
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Status",
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0B1957),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildStatusSelector(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B1957),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : Text(
                              'Save Changes',
                              style: GoogleFonts.lato(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
