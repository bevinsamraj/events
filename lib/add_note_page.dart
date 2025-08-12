import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:audioplayers/audioplayers.dart';

class AddNotePage extends StatefulWidget {
  final String eventId;
  const AddNotePage({super.key, required this.eventId});

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _startTimeCtrl = TextEditingController();
  final TextEditingController _endTimeCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  bool _isSubmitting = false;
  late Future<List<Map<String, dynamic>>> _futureNotes;

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

  // Audio player
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _futureNotes = _fetchNotes();
    _speech = stt.SpeechToText();
    _initPermissions();
    _initializeRecorder();
  }

  @override
  void dispose() {
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _audioRecorder.closeRecorder();
    _audioPlayer.dispose();
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

  Future<List<Map<String, dynamic>>> _fetchNotes() async {
    final url = Uri.parse(
      'https://demo.yelbee.com/events/notes.php?event_id=${widget.eventId}',
    );
    try {
      final response = await http.get(url);
      if (!mounted) return [];
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          return data.map((e) => e as Map<String, dynamic>).toList();
        } else if (data is Map<String, dynamic> && data.containsKey('error')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'])),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return [];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    return [];
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final initialTime = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        controller.text = picked.format(context);
      });
    }
  }

  Future<void> _submitNote({required bool popAfter}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_startTimeCtrl.text.isEmpty || _endTimeCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select both start and end times.')),
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
        if (!mounted) return;
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

      if (!mounted) return;
      if (response.body.isEmpty) {
        throw Exception('Empty response from server.');
      }
      final responseData = json.decode(response.body);
      if (response.statusCode == 200 && responseData["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added successfully!')),
        );
        if (popAfter) {
          Navigator.pop(context, true);
        } else {
          _futureNotes = _fetchNotes();
          setState(() {});
          _startTimeCtrl.clear();
          _endTimeCtrl.clear();
          _titleCtrl.clear();
          _notesCtrl.clear();
          if (_audioPath != null) {
            File(_audioPath!).delete();
            _audioPath = null;
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData["error"] ?? 'Failed to add note.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  BoxDecoration _blueBorderDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF0B1957), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(12),
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
          style: GoogleFonts.lato(
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

  Widget _buildNotesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _futureNotes,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allNotes = snapshot.data ?? [];
        final notes = allNotes.where((n) => n['status'] != 'off').toList();
        if (notes.isEmpty) {
          return Center(
            child: Text(
              "No notes found for this event.",
              style: GoogleFonts.lato(fontSize: 16, color: Colors.grey[600]),
            ),
          );
        }
        return ListView.separated(
          itemCount: notes.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final n = notes[i];
            final session = n['session_time'] ?? '';
            final t = n['title'] ?? '';
            final noteText = n['notes'] ?? '';
            final audioUrl = n['audio'];
            return Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(
                  color: Color(0xFF0B1957),
                  width: 1,
                ),
              ),
              elevation: 3,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t,
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
                    const Divider(height: 20, thickness: 1),
                    Text(
                      noteText,
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (audioUrl != null && audioUrl.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.audiotrack,
                                size: 16, color: Color(0xFF0B1957)),
                            const SizedBox(width: 4),
                            Text(
                              'Play Audio',
                              style: GoogleFonts.lato(
                                fontSize: 15,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.play_arrow,
                                  color: Colors.blue),
                              onPressed: () async {
                                try {
                                  await _audioPlayer.play(UrlSource(audioUrl));
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Failed to play audio: $e')),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.stop, color: Colors.blue),
                              onPressed: () async {
                                await _audioPlayer.stop();
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
                style: GoogleFonts.lato(
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
    bool isSpeech = false,
  }) {
    return _buildLabeledField(
      label: label,
      child: Container(
        decoration: _blueBorderDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                maxLines: maxLines,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: GoogleFonts.lato(color: Colors.grey),
                ),
                validator: (value) {
                  if (requiredField && (value == null || value.isEmpty)) {
                    return 'Please enter $label';
                  }
                  return null;
                },
              ),
            ),
            if (isSpeech)
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
              style: GoogleFonts.lato(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0B1957),
              ),
            ),
            // Integrated radio buttons in the same row as the label.
            Transform.scale(
              scale: 0.8,
              child: Row(
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
                    style: GoogleFonts.lato(
                      fontSize: 20,
                      color: const Color(0xFF0B1957),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                    style: GoogleFonts.lato(
                      fontSize: 20,
                      color: const Color(0xFF0B1957),
                    ),
                  ),
                ],
              ),
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
                    hintStyle: GoogleFonts.lato(color: Colors.grey),
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

  Future<void> _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
            }
          }
        },
        onError: (val) {
          if (mounted) {
            setState(() => _isListening = false);
          }
        },
      );
      if (available) {
        if (mounted) {
          setState(() => _isListening = true);
        }
        String localeId = _selectedLanguage == 'Tamil' ? 'ta_IN' : 'en_US';
        _speech.listen(
          onResult: (val) {
            if (mounted && val.finalResult) {
              _notesCtrl.text =
                  (_notesCtrl.text + " " + val.recognizedWords).trim();
            }
          },
          localeId: localeId,
        );
      }
    } else {
      if (mounted) {
        setState(() => _isListening = false);
      }
      _speech.stop();
    }
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
                    style: GoogleFonts.lato(
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
                    style: GoogleFonts.lato(
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
                            if (!mounted) return;
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
                            if (mounted) {
                              setState(() {
                                _audioPath = null;
                              });
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Audio deleted')),
                            );
                          } catch (e) {
                            if (!mounted) return;
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
                  icon: Icon(_isRecordingAudio ? Icons.stop : Icons.mic_none,
                      color: Colors.white),
                  label: Text(
                    _isRecordingAudio ? "Stop Recording" : "Start Recording",
                    style: GoogleFonts.lato(color: Colors.white),
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
                      style: GoogleFonts.lato(color: Colors.white),
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
      if (!mounted) return;
      setState(() {
        _isRecordingAudio = true;
        _audioPath = filePath;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }

  Future<void> _stopAudioRecording() async {
    try {
      String? path = await _audioRecorder.stopRecorder();
      if (path != null && mounted) {
        setState(() {
          _isRecordingAudio = false;
          _audioPath = path;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio recorded successfully')),
        );
      }
    } catch (e) {
      if (!mounted) return;
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
      if (mounted) {
        setState(() {
          _isRecordingAudio = false;
          _audioPath = null;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording canceled')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel recording: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD1E8FF),
      appBar: AppBar(
        title: Text(
          'Add Notes (Event #${widget.eventId})',
          style: GoogleFonts.lato(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0B1957),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              // Existing Notes Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(12),
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
              ),
              const SizedBox(height: 20),
              // Add New Note Form Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(12),
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
                        "Add a New Note",
                        style: GoogleFonts.lato(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0B1957),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Start Time Picker
                      _buildTimePickerField(
                        controller: _startTimeCtrl,
                        label: "Start Time",
                      ),
                      const SizedBox(height: 16),
                      // End Time Picker
                      _buildTimePickerField(
                        controller: _endTimeCtrl,
                        label: "End Time",
                      ),
                      const SizedBox(height: 16),
                      // Title TextField
                      _buildTextField(
                        controller: _titleCtrl,
                        label: "Title",
                        hint: "e.g. Morning Session",
                      ),
                      const SizedBox(height: 16),
                      // Notes Field with integrated radio buttons
                      _buildNotesField(),
                      const SizedBox(height: 16),
                      // Audio Recorder
                      _buildAudioRecorder(),
                      const SizedBox(height: 24),
                      // Submit Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _submitNote(popAfter: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0B1957),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Add Note',
                                      style: GoogleFonts.lato(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _submitNote(popAfter: false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Add Another',
                                      style: GoogleFonts.lato(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
