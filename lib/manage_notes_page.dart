import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart' hide PlayerState;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() {
  runApp(MaterialApp(
    home: ManageNotesPage(),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primaryColor: const Color(0xFF0B1957),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B1957),
        elevation: 4,
      ),
      scaffoldBackgroundColor: const Color(0xFFD1E8FF),
      textTheme: GoogleFonts.poppinsTextTheme(),
    ),
  ));
}

class ManageNotesPage extends StatefulWidget {
  @override
  _ManageNotesPageState createState() => _ManageNotesPageState();
}

class _ManageNotesPageState extends State<ManageNotesPage>
    with TickerProviderStateMixin {
  List<dynamic> notes = [];
  bool isLoading = true;
  String errorMsg = '';
  String searchQuery = '';
  final String notesApiUrl = 'https://demo.yelbee.com/events/manage_notes.php';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    fetchNotes();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> fetchNotes() async {
    setState(() {
      isLoading = true;
      errorMsg = '';
    });
    try {
      final response = await http.get(Uri.parse('$notesApiUrl?action=list'));
      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        if (decodedData is Map && decodedData['data'] is List) {
          setState(() {
            notes = decodedData['data'];
            isLoading = false;
          });
        } else if (decodedData is List) {
          setState(() {
            notes = decodedData;
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            errorMsg = "Notes data is either null or not a list";
          });
        }
      } else {
        setState(() {
          isLoading = false;
          errorMsg = "Failed to load data: ${response.statusCode}";
        });
      }
      _animationController.forward();
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMsg = "Error fetching data: $e";
      });
    }
  }

  Map<String, List<dynamic>> groupNotesByEvent() {
    Map<String, List<dynamic>> grouped = {};
    for (var note in notes) {
      final eventId = note['event_id'].toString();
      if (!grouped.containsKey(eventId)) {
        grouped[eventId] = [];
      }
      grouped[eventId]!.add(note);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupNotesByEvent();
    final filteredKeys = grouped.keys.where((key) {
      final eventName = grouped[key]!.first['event_name'] ?? 'Unnamed Event';
      return eventName.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFD1E8FF),
      appBar: AppBar(
        title: Text(
          'Manage Notes',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0B1957),
        elevation: 4,
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF0B1957)),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading notes...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFF0B1957),
                    ),
                  ),
                ],
              ),
            )
          : errorMsg.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMsg,
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: fetchNotes,
                          icon: const Icon(Icons.refresh),
                          label: Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B1957),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchNotes,
                  color: const Color(0xFF0B1957),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Search Section
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value;
                              });
                            },
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Search events...',
                              hintStyle: GoogleFonts.poppins(
                                color: Colors.grey[500],
                                fontSize: 16,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: const Color(0xFF0B1957),
                                size: 24,
                              ),
                              suffixIcon: searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: Colors.grey[600],
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                        ),

                        // Events List
                        Expanded(
                          child: filteredKeys.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          searchQuery.isNotEmpty
                                              ? Icons.search_off
                                              : Icons.note_alt_outlined,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          searchQuery.isNotEmpty
                                              ? 'No events found matching "$searchQuery"'
                                              : 'No notes available',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[600],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        if (searchQuery.isNotEmpty) ...[
                                          const SizedBox(height: 16),
                                          TextButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                searchQuery = '';
                                              });
                                            },
                                            icon: const Icon(Icons.clear_all),
                                            label: Text('Clear search'),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  const Color(0xFF0B1957),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: filteredKeys.length,
                                  itemBuilder: (context, index) {
                                    String eventId = filteredKeys[index];
                                    List<dynamic> eventNotes =
                                        grouped[eventId]!;
                                    String eventName =
                                        eventNotes.first['event_name'] ??
                                            'Unnamed Event';

                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: Duration(
                                          milliseconds: 300 + (index * 50)),
                                      builder: (context, value, child) {
                                        return Transform.translate(
                                          offset: Offset(0, 20 * (1 - value)),
                                          child: Opacity(
                                            opacity: value,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.08),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    NoteDetailsPage(
                                                  eventId: eventId,
                                                  eventName: eventName,
                                                  notes: eventNotes,
                                                  onNotesUpdated: () {
                                                    fetchNotes(); // Refresh the notes when updated
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                // Event Avatar
                                                Container(
                                                  width: 50,
                                                  height: 50,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFF0B1957),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      eventName
                                                          .substring(0, 1)
                                                          .toUpperCase(),
                                                      style:
                                                          GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 20,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),

                                                // Event Details
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        eventName,
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: const Color(
                                                              0xFF0B1957),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 8,
                                                          vertical: 2,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: const Color(
                                                                  0xFF0B1957)
                                                              .withOpacity(0.1),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        child: Text(
                                                          "${eventNotes.length} ${eventNotes.length == 1 ? 'Note' : 'Notes'}",
                                                          style: GoogleFonts
                                                              .poppins(
                                                            color: const Color(
                                                                0xFF0B1957),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // Arrow Icon
                                                Icon(
                                                  Icons.arrow_forward_ios,
                                                  color: Colors.grey[400],
                                                  size: 16,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class NoteDetailsPage extends StatefulWidget {
  final String eventId;
  final String eventName;
  final List<dynamic> notes;
  final VoidCallback? onNotesUpdated;

  NoteDetailsPage({
    required this.eventId,
    required this.eventName,
    required this.notes,
    this.onNotesUpdated,
  });

  @override
  _NoteDetailsPageState createState() => _NoteDetailsPageState();
}

class _NoteDetailsPageState extends State<NoteDetailsPage>
    with TickerProviderStateMixin {
  Map<String, dynamic> eventDetails = {};
  List<dynamic> notes = [];
  bool isLoading = true;
  final String eventsApiUrl =
      'https://demo.yelbee.com/events/manage_events.php';
  final String notesApiUrl = 'https://demo.yelbee.com/events/manage_notes.php';
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  // Add Note Form Controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _startTimeCtrl = TextEditingController();
  final TextEditingController _endTimeCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _showAddForm = false;

  // Speech to Text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _selectedLanguage = 'English';

  // Audio recording variables
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  bool _isRecordingAudio = false;
  String? _audioPath;

  // Cloudinary setup
  final CloudinaryPublic _cloudinary =
      CloudinaryPublic('dzlhl3e6j', 'unsigned_preset', cache: false);

  @override
  void initState() {
    super.initState();
    notes = List.from(widget.notes);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _speech = stt.SpeechToText();
    _initPermissions();
    _initializeRecorder();
    fetchEventDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _audioPlayer.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _audioRecorder.closeRecorder();
    super.dispose();
  }

  Future<void> _initializeRecorder() async {
    await _audioRecorder.openRecorder();
    _audioRecorder.setSubscriptionDuration(const Duration(milliseconds: 500));
  }

  Future<void> _initPermissions() async {
    if (await Permission.microphone.isDenied) {
      await Permission.microphone.request();
    }
    if (Platform.isIOS) {
      if (await Permission.photos.isDenied) {
        await Permission.photos.request();
      }
    }
  }

  Future<void> fetchEventDetails() async {
    try {
      final response = await http.get(Uri.parse(
          '$eventsApiUrl?action=get_event_details&event_id=${widget.eventId}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['event'] != null) {
          setState(() {
            eventDetails = data['event'];
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
            eventDetails = widget.notes.first;
          });
        }
      } else {
        setState(() {
          isLoading = false;
          eventDetails = widget.notes.first;
        });
      }
      _animationController.forward();
    } catch (e) {
      setState(() {
        isLoading = false;
        eventDetails = widget.notes.first;
      });
      _animationController.forward();
    }
  }

  Future<void> _refreshNotes() async {
    try {
      final response = await http.get(Uri.parse(
          'https://demo.yelbee.com/events/notes.php?event_id=${widget.eventId}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          setState(() {
            notes = data.where((n) => n['status'] != 'off').toList();
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _editNote(Map<String, dynamic> note) async {
    if (note['note_status'] == "off") return;
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditNotePage(note: note)),
    );
    if (updated == true) {
      await _refreshNotes();
      if (widget.onNotesUpdated != null) {
        widget.onNotesUpdated!();
      }
    }
  }

  Future<void> _deleteNote(Map<String, dynamic> note) async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Note',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0B1957),
            ),
          ),
          content: Text(
            'Are you sure you want to delete this note? This action cannot be undone.',
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
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true) return;

    setState(() {
      isLoading = true;
    });

    final noteId = note['note_id'].toString();
    try {
      final response =
          await http.delete(Uri.parse('$notesApiUrl?action=delete&id=$noteId'));
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        await _refreshNotes();
        if (widget.onNotesUpdated != null) {
          widget.onNotesUpdated!();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Failed to delete.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Add Note Functions
  Future<void> _pickTime(TextEditingController controller) async {
    final initialTime = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  Future<void> _submitNote() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startTimeCtrl.text.isEmpty || _endTimeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both start and end times.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final sessionTime = "${_startTimeCtrl.text} - ${_endTimeCtrl.text}";
    String? audioUrl;

    if (_audioPath != null) {
      try {
        CloudinaryResponse response = await _cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            _audioPath!,
            resourceType: CloudinaryResourceType.Auto,
          ),
        );
        audioUrl = response.secureUrl;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload audio: $e')),
        );
        setState(() => _isSubmitting = false);
        return;
      }
    }

    Map<String, dynamic> noteData = {
      "event_id": widget.eventId,
      "session_time": sessionTime,
      "title": _titleCtrl.text.trim(),
      "notes": _notesCtrl.text.trim(),
      "status": "on",
    };

    if (audioUrl != null) {
      noteData["audio"] = audioUrl;
    }

    final url = Uri.parse("https://demo.yelbee.com/events/notes.php");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(noteData),
      );

      if (response.body.isEmpty) {
        throw Exception('Empty response from server.');
      }
      final responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note added successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        // Clear form and refresh notes
        _startTimeCtrl.clear();
        _endTimeCtrl.clear();
        _titleCtrl.clear();
        _notesCtrl.clear();
        if (_audioPath != null) {
          File(_audioPath!).delete();
          _audioPath = null;
        }
        setState(() {
          _showAddForm = false;
        });
        await _refreshNotes();
        if (widget.onNotesUpdated != null) {
          widget.onNotesUpdated!();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData["error"] ?? 'Failed to add note.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          setState(() => _isListening = false);
        },
      );
      if (available) {
        setState(() => _isListening = true);
        String localeId = _selectedLanguage == 'Tamil' ? 'ta_IN' : 'en_US';
        _speech.listen(
          onResult: (val) {
            if (val.finalResult) {
              _notesCtrl.text =
                  (_notesCtrl.text + " " + val.recognizedWords).trim();
            }
          },
          localeId: localeId,
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _startAudioRecording() async {
    try {
      if (await Permission.microphone.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
        return;
      }
      Directory appDir = await getApplicationDocumentsDirectory();
      String filePath =
          '${appDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _audioRecorder.startRecorder(
        toFile: filePath,
        codec: Codec.aacADTS,
      );
      setState(() {
        _isRecordingAudio = true;
        _audioPath = filePath;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  Future<void> _stopAudioRecording() async {
    try {
      String? path = await _audioRecorder.stopRecorder();
      if (path != null) {
        setState(() {
          _isRecordingAudio = false;
          _audioPath = path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio recorded successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop recording: $e')),
      );
    }
  }

  Future<void> _cancelAudioRecording() async {
    try {
      await _audioRecorder.stopRecorder();
      if (_audioPath != null) {
        File(_audioPath!).delete();
      }
      setState(() {
        _isRecordingAudio = false;
        _audioPath = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording canceled')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel recording: $e')),
      );
    }
  }

  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd-MM-yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildEventDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF0B1957).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF0B1957), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF0B1957),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventDetailsCard() {
    final eventData =
        eventDetails.isNotEmpty ? eventDetails : widget.notes.first;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1957),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_note,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Event Details",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0B1957),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEventDetailRow(
            Icons.event,
            eventData['event_name'] ?? widget.eventName,
          ),
          _buildEventDetailRow(
            Icons.calendar_today,
            "Date: ${_formatDate(eventData['start_date'] ?? '')} - ${_formatDate(eventData['end_date'] ?? '')}",
          ),
          _buildEventDetailRow(
            Icons.location_on,
            "Venue: ${eventData['venue'] ?? 'N/A'}",
          ),
          _buildEventDetailRow(
            Icons.place,
            "City: ${eventData['city'] ?? 'N/A'}",
          ),
          _buildEventDetailRow(
            Icons.phone,
            "Contact: ${eventData['contact_name'] ?? 'N/A'} | ${eventData['contact_number'] ?? 'N/A'}",
          ),
          _buildEventDetailRow(
            Icons.info,
            "Type: ${eventData['event_type'] ?? 'N/A'}",
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note, int index) {
    final title = note['title'] ?? 'No Title';
    final sessionTime = note['session_time'] ?? 'No Session Time';
    final noteContent = note['notes'] ?? 'No Content';
    final audioUrl = note['audio'] ?? '';
    final createdDate = note['note_created_date'] ?? 'No Date';
    final isDeleted = (note['note_status'] ?? "on") == "off";

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(20 * (1 - value), 0),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDeleted ? Colors.grey.shade200 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDeleted
                  ? Colors.grey.withOpacity(0.2)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDeleted
                        ? Colors.grey.shade400
                        : const Color(0xFF0B1957),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.note,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDeleted
                          ? Colors.grey[600]
                          : const Color(0xFF0B1957),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDeleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Deleted",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Session Time
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDeleted
                    ? Colors.grey.shade100
                    : const Color(0xFF0B1957).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color:
                        isDeleted ? Colors.grey[600] : const Color(0xFF0B1957),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Session: $sessionTime",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDeleted
                          ? Colors.grey[600]
                          : const Color(0xFF0B1957),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Note Content
            Text(
              noteContent,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDeleted ? Colors.grey[600] : Colors.black87,
                height: 1.5,
              ),
              textAlign: TextAlign.justify,
            ),

            // Audio Section
            if (audioUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDeleted
                      ? Colors.grey.shade100
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.audiotrack,
                      color: isDeleted ? Colors.grey[600] : Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Audio Note:",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDeleted ? Colors.grey[600] : Colors.green,
                      ),
                    ),
                    const Spacer(),
                    AudioPlayerWidget(audioUrl: audioUrl),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Bottom Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Created: ${_formatDate(createdDate)}",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
                if (!isDeleted)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _editNote(note),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit,
                                  color: Colors.green,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Edit",
                                  style: GoogleFonts.poppins(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Delete Button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _deleteNote(note),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Delete",
                                  style: GoogleFonts.poppins(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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

  Widget _buildLabeledField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0B1957),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildTimePickerField({
    required TextEditingController controller,
    required String label,
  }) {
    return _buildLabeledField(
      label: label,
      child: GestureDetector(
        onTap: () => _pickTime(controller),
        child: Container(
          decoration: _blueBorderDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                controller.text.isEmpty ? "Select time" : controller.text,
                style: GoogleFonts.poppins(
                  color: controller.text.isEmpty ? Colors.grey : Colors.black,
                  fontSize: 16,
                ),
              ),
              const Icon(Icons.access_time, color: Color(0xFF0B1957)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    bool requiredField = true,
  }) {
    return _buildLabeledField(
      label: label,
      child: Container(
        decoration: _blueBorderDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey),
          ),
          validator: (value) {
            if (requiredField && (value == null || value.isEmpty)) {
              return 'Please enter $label';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Notes",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0B1957),
              ),
            ),
            // Language selection
            Row(
              children: [
                Radio<String>(
                  value: 'English',
                  groupValue: _selectedLanguage,
                  onChanged: (value) {
                    setState(() {
                      _selectedLanguage = value!;
                    });
                  },
                ),
                Text(
                  'Eng',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF0B1957),
                  ),
                ),
                Radio<String>(
                  value: 'Tamil',
                  groupValue: _selectedLanguage,
                  onChanged: (value) {
                    setState(() {
                      _selectedLanguage = value!;
                    });
                  },
                ),
                Text(
                  'த',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF0B1957),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: _blueBorderDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _notesCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Enter your notes here...",
                    hintStyle: GoogleFonts.poppins(color: Colors.grey),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter Notes';
                    }
                    return null;
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : Colors.grey,
                ),
                onPressed: _toggleListening,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioRecorder() {
    return _buildLabeledField(
      label: "Audio Note",
      child: Container(
        decoration: _blueBorderDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          children: [
            if (_isRecordingAudio)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mic, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    "Recording...",
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            if (!_isRecordingAudio && _audioPath != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Audio Recorded",
                    style: GoogleFonts.poppins(
                      color: Colors.green,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow, color: Colors.blue),
                        onPressed: () async {
                          try {
                            await _audioPlayer
                                .play(DeviceFileSource(_audioPath!));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Failed to play audio: $e')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          try {
                            await File(_audioPath!).delete();
                            setState(() {
                              _audioPath = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Audio deleted')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Failed to delete audio: $e')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isRecordingAudio
                      ? _stopAudioRecording
                      : _startAudioRecording,
                  icon: Icon(
                    _isRecordingAudio ? Icons.stop : Icons.mic_none,
                    color: Colors.white,
                  ),
                  label: Text(
                    _isRecordingAudio ? "Stop Recording" : "Start Recording",
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecordingAudio
                        ? Colors.red
                        : const Color(0xFF0B1957),
                  ),
                ),
                const SizedBox(width: 16),
                if (_audioPath != null)
                  ElevatedButton.icon(
                    onPressed: _cancelAudioRecording,
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: Text(
                      "Cancel",
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNoteForm() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: _showAddForm
          ? Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Add New Note",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0B1957),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _showAddForm = false;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTimePickerField(
                      controller: _startTimeCtrl,
                      label: "Start Time",
                    ),
                    const SizedBox(height: 16),
                    _buildTimePickerField(
                      controller: _endTimeCtrl,
                      label: "End Time",
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _titleCtrl,
                      label: "Title",
                      hint: "e.g. Morning Session",
                    ),
                    const SizedBox(height: 16),
                    _buildNotesField(),
                    const SizedBox(height: 16),
                    _buildAudioRecorder(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitNote,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B1957),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Add Note',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD1E8FF),
      appBar: AppBar(
        title: Text(
          widget.eventName,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0B1957),
        elevation: 4,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF0B1957)),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading event details...',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFF0B1957),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await fetchEventDetails();
                await _refreshNotes();
              },
              color: const Color(0xFF0B1957),
              child: FadeTransition(
                opacity: _slideAnimation,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEventDetailsCard(),

                      // Add Note Form
                      _buildAddNoteForm(),

                      // Notes Header with Add Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Notes (${notes.length})',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0B1957),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showAddForm = !_showAddForm;
                                });
                              },
                              icon: Icon(
                                _showAddForm ? Icons.close : Icons.add,
                                color: Colors.white,
                                size: 16,
                              ),
                              label: Text(
                                _showAddForm ? 'Cancel' : 'Add Note',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _showAddForm
                                    ? Colors.grey
                                    : const Color(0xFF0B1957),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Notes List
                      notes.isEmpty
                          ? Container(
                              height: 200,
                              margin: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.note_alt_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No notes available for this event',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Click "Add Note" to create your first note',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              children: List.generate(
                                notes.length,
                                (index) => _buildNoteCard(notes[index], index),
                              ),
                            ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// Audio Player Widget (same as before)
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  const AudioPlayerWidget({required this.audioUrl, Key? key}) : super(key: key);

  @override
  _AudioPlayerWidgetState createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  late AudioPlayer _player;
  bool isPlaying = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((state) {
      setState(() {
        isPlaying = (state == PlayerState.playing);
      });
    });
  }

  Future<void> _togglePlayPause() async {
    if (isPlaying) {
      await _player.pause();
      setState(() {
        isPlaying = false;
      });
    } else {
      setState(() {
        isLoading = true;
      });
      await _player.play(UrlSource(widget.audioUrl));
      setState(() {
        isLoading = false;
        isPlaying = true;
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: isLoading
            ? SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              )
            : Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.green,
                size: 18,
              ),
        onPressed: _togglePlayPause,
      ),
    );
  }
}

// Edit Note Page (same as before with app theme)
class EditNotePage extends StatefulWidget {
  final Map<String, dynamic> note;
  EditNotePage({required this.note});

  @override
  _EditNotePageState createState() => _EditNotePageState();
}

class _EditNotePageState extends State<EditNotePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController noteTitleCtrl;
  late TextEditingController startTimeCtrl;
  late TextEditingController endTimeCtrl;
  late TextEditingController noteContentCtrl;
  late TextEditingController audioCtrl;
  bool _isSubmitting = false;

  final CloudinaryPublic _cloudinary =
      CloudinaryPublic('dzlhl3e6j', 'unsigned_preset', cache: false);
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecordingAudio = false;
  String? _audioPath;

  @override
  void initState() {
    super.initState();
    noteTitleCtrl = TextEditingController(text: widget.note['title'] ?? '');
    String sessionTime = widget.note['session_time'] ?? "";
    List<String> times = sessionTime.split(" - ");
    startTimeCtrl =
        TextEditingController(text: times.isNotEmpty ? times[0] : '');
    endTimeCtrl = TextEditingController(text: times.length > 1 ? times[1] : '');
    noteContentCtrl = TextEditingController(text: widget.note['notes'] ?? '');
    audioCtrl = TextEditingController(text: widget.note['audio'] ?? '');
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _audioRecorder.openRecorder();
    await Permission.microphone.request();
  }

  @override
  void dispose() {
    noteTitleCtrl.dispose();
    startTimeCtrl.dispose();
    endTimeCtrl.dispose();
    noteContentCtrl.dispose();
    audioCtrl.dispose();
    _audioRecorder.closeRecorder();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startAudioRecording() async {
    try {
      setState(() {
        audioCtrl.text = "";
      });
      Directory appDir = await getApplicationDocumentsDirectory();
      String filePath =
          '${appDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _audioRecorder.startRecorder(
          toFile: filePath, codec: Codec.aacADTS);
      setState(() {
        _isRecordingAudio = true;
        _audioPath = filePath;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')));
    }
  }

  Future<void> _stopAudioRecording() async {
    try {
      String? path = await _audioRecorder.stopRecorder();
      setState(() {
        _isRecordingAudio = false;
        _audioPath = path;
      });
      await _uploadAudio();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording: $e')));
    }
  }

  Future<void> _uploadAudio() async {
    if (_audioPath != null) {
      try {
        final uploaded = await _cloudinary.uploadFile(
          CloudinaryFile.fromFile(_audioPath!,
              resourceType: CloudinaryResourceType.Auto),
        );
        setState(() {
          audioCtrl.text = uploaded.secureUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Audio uploaded successfully"),
            backgroundColor: Colors.green));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error uploading audio: $e"),
            backgroundColor: Colors.red));
      }
    }
  }

  void _deleteRecording() {
    setState(() {
      _audioPath = null;
      audioCtrl.text = "";
    });
  }

  Future<void> _submitForm() async {
    setState(() {
      _isSubmitting = true;
    });
    final Map<String, dynamic> body = {
      'id': widget.note['note_id'].toString(),
      'note_title': noteTitleCtrl.text,
      'start_time': startTimeCtrl.text,
      'end_time': endTimeCtrl.text,
      'note_content': noteContentCtrl.text,
      'audio': audioCtrl.text,
      'status': widget.note['note_status'],
    };
    try {
      final response = await http.post(
        Uri.parse(
            'https://demo.yelbee.com/events/manage_notes.php?action=update'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note updated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Failed to update note'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _pickTime(TextEditingController controller) async {
    TimeOfDay? picked =
        await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0B1957).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: const Color(0xFF0B1957),
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1957),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: GoogleFonts.poppins(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD1E8FF),
      appBar: AppBar(
        title: Text(
          "Edit Note",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0B1957),
        elevation: 4,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Editing Note",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0B1957),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Update your note details below",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: noteTitleCtrl,
                    label: "Note Title",
                    icon: Icons.title,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: startTimeCtrl,
                          label: "Start Time",
                          icon: Icons.access_time,
                          readOnly: true,
                          onTap: () => _pickTime(startTimeCtrl),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: endTimeCtrl,
                          label: "End Time",
                          icon: Icons.access_time_filled,
                          readOnly: true,
                          onTap: () => _pickTime(endTimeCtrl),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: noteContentCtrl,
                    label: "Note Content",
                    icon: Icons.note,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: audioCtrl,
                    label: "Audio Note URL",
                    icon: Icons.audiotrack,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),

                  // Audio Recording Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1957).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF0B1957).withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Audio Recording",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0B1957),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isRecordingAudio
                                    ? _stopAudioRecording
                                    : _startAudioRecording,
                                icon: Icon(
                                  _isRecordingAudio ? Icons.stop : Icons.mic,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                label: Text(
                                  _isRecordingAudio
                                      ? "Stop Recording"
                                      : "Record Audio",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isRecordingAudio
                                      ? Colors.red
                                      : const Color(0xFF0B1957),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                            if (_audioPath != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: "Play Recorded Audio",
                                icon:
                                    Icon(Icons.play_arrow, color: Colors.green),
                                onPressed: () async {
                                  await _audioPlayer
                                      .play(DeviceFileSource(_audioPath!));
                                },
                              ),
                              IconButton(
                                tooltip: "Delete Recorded Audio",
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: _deleteRecording,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B1957),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Saving...',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Save Changes',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
