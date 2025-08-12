// event_detail_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class EventDetailPage extends StatefulWidget {
  final Map<String, dynamic> event;
  const EventDetailPage({super.key, required this.event});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  late Future<List<Map<String, dynamic>>> _futureNotes;

  @override
  void initState() {
    super.initState();
    _futureNotes = _fetchNotes();
  }

  Future<List<Map<String, dynamic>>> _fetchNotes() async {
    final eventId = widget.event['id']?.toString().trim() ?? '';
    if (eventId.isEmpty) {
      debugPrint('Error: event id is missing.');
      return [];
    }

    final uri = Uri.https(
      'demo.yelbee.com',
      '/events/notes.php',
      {'event_id': eventId},
    );

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .where((note) => note['status']?.toString().toLowerCase() == 'on')
              .toList();
        } else if (data is Map<String, dynamic> && data.containsKey('error')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['error'])),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unexpected response format.')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching notes: $e')),
        );
      }
    }
    return [];
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      bool launched = await launchUrl(launchUri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not launch phone dialer for $phoneNumber')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    }
  }

  Future<void> _searchVenueOnGoogle(BuildContext context, String venue) async {
    final Uri url = Uri.parse('https://www.google.com/search?q=$venue');
    try {
      bool launched =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not search for $venue on Google')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred while searching: $e')),
        );
      }
    }
  }

  Future<void> _searchVenueOnMaps(BuildContext context, String venue) async {
    final Uri url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$venue');
    try {
      bool launched =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Maps for $venue')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred while opening Maps: $e')),
        );
      }
    }
  }

  Future<void> _searchCityOnMaps(BuildContext context, String city) async {
    final Uri url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$city');
    try {
      bool launched =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open Maps for $city')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred while opening Maps: $e')),
        );
      }
    }
  }

  String _formatDateDisplay(String dateStr) {
    if (dateStr.isEmpty || !dateStr.contains('-')) return dateStr;
    final parts = dateStr.split('-');
    if (parts.length < 3) return dateStr;
    final yyyy = parts[0];
    final mm = parts[1];
    final dd = parts[2];
    return "$dd-$mm-$yyyy";
  }

  List<String> _parseTags(dynamic rawTags) {
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

  Widget _buildNotesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureNotes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error fetching notes.",
              style: GoogleFonts.lato(fontSize: 16, color: Colors.red),
            ),
          );
        }
        final notes = snapshot.data ?? [];
        if (notes.isEmpty) {
          return Center(
            child: Text(
              "No notes found for this event.",
              style: GoogleFonts.lato(fontSize: 16, color: Colors.grey[600]),
            ),
          );
        }
        return Column(
          children: notes.map((n) {
            final session = n['session_time'] ?? '';
            final title = n['title'] ?? '';
            final noteText = n['notes'] ?? '';
            final audioUrl = n['audio']?.toString().trim() ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0B1957), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0B1957),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 16, color: Color(0xFF0B1957)),
                        const SizedBox(width: 4),
                        Text(
                          session,
                          style: GoogleFonts.lato(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      noteText,
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (audioUrl.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.audiotrack,
                                size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                                child: AudioPlayerWidget(audioUrl: audioUrl)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildNotesContainer() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Existing Notes",
            style: GoogleFonts.lato(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0B1957),
            ),
          ),
          const SizedBox(height: 16),
          _buildNotesList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textStyleHeader = GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF0B1957),
    );
    final textStyleLabel = GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF0B1957),
    );
    final textStyleValue = GoogleFonts.poppins(
      fontSize: 14,
      color: Colors.black87,
    );

    final eventName = widget.event['event_name'] ?? 'Event Details';
    final startDate = widget.event['start_date'] ?? '';
    final endDate = widget.event['end_date'] ?? '';
    final venue = widget.event['venue'] ?? '';
    final city = widget.event['city'] ?? '';
    final contactName = widget.event['contact_name'] ?? '';
    final contactNumber = widget.event['contact_number'] ?? '';
    final details = widget.event['event_details'] ?? '';
    final boardingPass = widget.event['boarding_pass'] ?? '';
    final imageUrl = widget.event['image'] ?? '';
    final tags = _parseTags(widget.event['tags'] ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFD1E8FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1957),
        title: Text(
          eventName,
          style: GoogleFonts.poppins(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                if (imageUrl.isNotEmpty) const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.event, color: Color(0xFF0B1957)),
                    const SizedBox(width: 8),
                    Text("Event Name", style: textStyleLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Text(eventName, style: textStyleHeader),
                const Divider(thickness: 1, height: 24),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFF0B1957)),
                    const SizedBox(width: 8),
                    Text("Date", style: textStyleLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  (startDate == endDate || endDate.isEmpty)
                      ? _formatDateDisplay(startDate)
                      : "${_formatDateDisplay(startDate)} to ${_formatDateDisplay(endDate)}",
                  style: textStyleValue,
                ),
                const Divider(thickness: 1, height: 24),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF0B1957)),
                    const SizedBox(width: 8),
                    Text("Venue", style: textStyleLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: Text(venue, style: textStyleValue))
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _searchVenueOnGoogle(context, venue),
                      icon: const Icon(Icons.search, color: Colors.white),
                      label: Text(
                        "Google",
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B1957),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _searchVenueOnMaps(context, venue),
                      icon: const Icon(Icons.map, color: Colors.white),
                      label: Text(
                        "Maps",
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B1957),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const Divider(thickness: 1, height: 24),
                Row(
                  children: [
                    const Icon(Icons.location_city, color: Color(0xFF0B1957)),
                    const SizedBox(width: 8),
                    Text("City", style: textStyleLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: Text(city, style: textStyleValue))
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _searchCityOnMaps(context, city),
                  icon: const Icon(Icons.map, color: Colors.white),
                  label: Text(
                    "Open in Maps",
                    style: GoogleFonts.poppins(
                        color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B1957),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const Divider(thickness: 1, height: 24),
                Row(
                  children: [
                    const Icon(Icons.call, color: Color(0xFF0B1957)),
                    const SizedBox(width: 8),
                    Text("Contact Person", style: textStyleLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Text(contactName, style: textStyleValue),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(contactNumber, style: textStyleValue),
                    ElevatedButton.icon(
                      onPressed: () => _makePhoneCall(context, contactNumber),
                      icon: const Icon(Icons.call, color: Colors.white),
                      label: Text(
                        "Call",
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B1957),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const Divider(thickness: 1, height: 24),
                Row(
                  children: [
                    const Icon(Icons.info, color: Color(0xFF0B1957)),
                    const SizedBox(width: 8),
                    Text("Event Details", style: textStyleLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Text(details, style: textStyleValue),
                const Divider(thickness: 1, height: 24),
                Row(
                  children: [
                    const Icon(Icons.airplane_ticket, color: Color(0xFF0B1957)),
                    const SizedBox(width: 8),
                    Text("Boarding Pass", style: textStyleLabel),
                  ],
                ),
                const SizedBox(height: 4),
                if (boardingPass.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          child: InteractiveViewer(
                            child: Image.network(
                              boardingPass,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        boardingPass,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                if (boardingPass.isNotEmpty) const SizedBox(height: 16),
                if (boardingPass.isEmpty)
                  Text("No boarding pass image.", style: textStyleValue),
                const Divider(thickness: 1, height: 24),
                if (tags.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.label, color: Color(0xFF0B1957)),
                      const SizedBox(width: 8),
                      Text("Tags", style: textStyleLabel),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: tags.map<Widget>((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
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
                  const SizedBox(height: 16),
                ],
                _buildNotesContainer(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// AudioPlayerWidget shows a play/pause button for a Cloudinary audio file.
/// It displays a CircularProgressIndicator when loading.
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  const AudioPlayerWidget({Key? key, required this.audioUrl}) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
      await _audioPlayer.play(UrlSource(widget.audioUrl));
      setState(() {
        _isPlaying = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _togglePlayPause,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade50,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 28,
                  color: Colors.blue,
                ),
        ),
      ),
    );
  }
}
