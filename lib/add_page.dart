// edit_add_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/services.dart' show rootBundle;

class AddEventPage extends StatefulWidget {
  const AddEventPage({Key? key}) : super(key: key);

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController eventNameController = TextEditingController();
  final TextEditingController startDateController = TextEditingController();
  final TextEditingController endDateController = TextEditingController();
  final TextEditingController startTimeController = TextEditingController();
  final TextEditingController endTimeController = TextEditingController();
  final TextEditingController venueController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController contactNameController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController eventDetailsController = TextEditingController();
  final TextEditingController tagsController = TextEditingController();
  final TextEditingController boardingPassController = TextEditingController();
  final TextEditingController imageController = TextEditingController();

  // Event type
  String eventType = 'national';

  // Submitting state
  bool _isSubmitting = false;

  // Cloudinary setup
  final CloudinaryPublic cloudinary =
      CloudinaryPublic('dzlhl3e6j', 'unsigned_preset', cache: false);

  // Image Picker
  final ImagePicker _picker = ImagePicker();

  // City data
  Map<String, List<String>> _stateCityMap = {};
  List<String> _allCitiesWithState = [];

  // For contact name/number suggestion
  List<Map<String, String>> _contactsList = [];
  List<String> _contactNames = [];

  @override
  void initState() {
    super.initState();
    // Default times
    startTimeController.text = '6:00 PM';
    endTimeController.text = '9:00 PM';

    _loadCityData();
    _fetchContacts();
  }

  @override
  void dispose() {
    eventNameController.dispose();
    startDateController.dispose();
    endDateController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    venueController.dispose();
    cityController.dispose();
    contactNameController.dispose();
    contactNumberController.dispose();
    eventDetailsController.dispose();
    tagsController.dispose();
    boardingPassController.dispose();
    imageController.dispose();
    super.dispose();
  }

  /// Load city data from `assets/city.json`.
  Future<void> _loadCityData() async {
    try {
      String data = await rootBundle.loadString('assets/city.json');
      final jsonResult = jsonDecode(data) as Map<String, dynamic>;
      _stateCityMap = {};
      _allCitiesWithState = [];

      jsonResult.forEach((state, cities) {
        _stateCityMap[state] = List<String>.from(cities);
        for (final city in cities) {
          _allCitiesWithState.add('$city, $state');
        }
      });
      if (mounted) setState(() {});
    } catch (e) {
      print("Error loading city data: $e");
    }
  }

  /// Fetch contact names/numbers from API
  Future<void> _fetchContacts() async {
    try {
      final response = await http.get(
        Uri.parse('https://demo.yelbee.com/events/get_contacts.php'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          _contactsList = data.map((item) {
            final map = item as Map<String, dynamic>;
            return <String, String>{
              "name": (map["name"] ?? "").toString(),
              "number": (map["number"] ?? "").toString(),
            };
          }).toList();
          _contactNames = _contactsList.map((c) => c['name']!).toList();
        }
      }
    } catch (e) {
      // Handle error if needed
    }
    if (mounted) setState(() {});
  }

  /// Pick image from gallery and upload to Cloudinary
  Future<void> _pickAndUploadImage(bool isBoardingPass) async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _isSubmitting = true;
        });
        CloudinaryResponse response = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(
            pickedFile.path,
            resourceType: CloudinaryResourceType.Image,
          ),
        );
        String uploadedUrl = response.secureUrl;
        setState(() {
          if (isBoardingPass) {
            boardingPassController.text = uploadedUrl;
          } else {
            imageController.text = uploadedUrl;
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
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _removeImage(bool isBoardingPass) {
    setState(() {
      if (isBoardingPass) {
        boardingPassController.text = '';
      } else {
        imageController.text = '';
      }
    });
  }

  /// Pick Start Date (dd-MM-yyyy format)
  Future<void> _pickStartDate() async {
    DateTime initialDate = DateTime.now();
    if (startDateController.text.isNotEmpty) {
      try {
        initialDate = _parseIndianDate(startDateController.text);
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
        startDateController.text = DateFormat('dd-MM-yyyy').format(pickedDate);
        endDateController.text = startDateController.text;
      });
    }
  }

  /// Pick End Date (dd-MM-yyyy format)
  Future<void> _pickEndDate() async {
    DateTime initialDate = DateTime.now();
    if (endDateController.text.isNotEmpty) {
      try {
        initialDate = _parseIndianDate(endDateController.text);
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
        endDateController.text = DateFormat('dd-MM-yyyy').format(pickedDate);
      });
    }
  }

  /// Increment End Date by 1 day
  void _incrementEndDate() {
    if (endDateController.text.isEmpty) return;
    try {
      final current = _parseIndianDate(endDateController.text);
      final next = current.add(const Duration(days: 1));
      setState(() {
        endDateController.text = DateFormat('dd-MM-yyyy').format(next);
      });
    } catch (_) {}
  }

  /// Pick Start Time
  Future<void> _pickStartTime() async {
    TimeOfDay initialTime = const TimeOfDay(hour: 18, minute: 0);
    if (startTimeController.text.isNotEmpty) {
      try {
        initialTime = _parseTimeOfDay(startTimeController.text);
      } catch (_) {}
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime != null) {
      setState(() {
        startTimeController.text = pickedTime.format(context);
      });
    }
  }

  /// Pick End Time
  Future<void> _pickEndTime() async {
    TimeOfDay initialTime = const TimeOfDay(hour: 21, minute: 0);
    if (endTimeController.text.isNotEmpty) {
      try {
        initialTime = _parseTimeOfDay(endTimeController.text);
      } catch (_) {}
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime != null) {
      setState(() {
        endTimeController.text = pickedTime.format(context);
      });
    }
  }

  /// Utility to check time
  bool _isEndTimeAfterStartTime(TimeOfDay start, TimeOfDay end) {
    return _timeOfDayToMinutes(end) > _timeOfDayToMinutes(start);
  }

  int _timeOfDayToMinutes(TimeOfDay tod) => tod.hour * 60 + tod.minute;

  /// Parse TimeOfDay from string (e.g. "6:00 PM")
  TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(' ');
    final timeParts = parts[0].split(':');
    int hour = int.parse(timeParts[0]);
    int minute = int.parse(timeParts[1]);
    String period = parts[1].toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Parse dd-MM-yyyy -> DateTime
  DateTime _parseIndianDate(String dateString) {
    final parts = dateString.split('-');
    if (parts.length != 3) {
      throw FormatException("Invalid date format");
    }
    final day = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final year = int.parse(parts[2]);
    return DateTime(year, month, day);
  }

  /// Convert dd-MM-yyyy -> yyyy-MM-dd (for DB storage)
  String _toDBDate(String dateString) {
    final dt = _parseIndianDate(dateString);
    final yyyy = dt.year;
    final mm = dt.month < 10 ? '0${dt.month}' : '${dt.month}';
    final dd = dt.day < 10 ? '0${dt.day}' : '${dt.day}';
    return '$yyyy-$mm-$dd';
  }

  /// Submit data to the server and go to home page after submission
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final String dbStartDate = startDateController.text.isNotEmpty
        ? _toDBDate(startDateController.text)
        : "";
    final String dbEndDate = endDateController.text.isNotEmpty
        ? _toDBDate(endDateController.text)
        : "";

    String combinedTime =
        "${startTimeController.text} - ${endTimeController.text}";

    // Convert comma separated tags to a JSON string array, e.g. ["Special","Meeting"]
    final List<String> tagsList = tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final String tagsJson = jsonEncode(tagsList);

    final eventData = {
      "event_name": eventNameController.text,
      "start_date": dbStartDate,
      "end_date": dbEndDate,
      "time": combinedTime,
      "venue": venueController.text,
      "city": cityController.text,
      "event_type": eventType,
      "contact_name": contactNameController.text,
      "contact_number": contactNumberController.text,
      "event_details": eventDetailsController.text,
      "tags": tagsJson,
      "boarding_pass": boardingPassController.text,
      "image": imageController.text,
      "status": "on",
      "created_date": DateTime.now().toIso8601String(),
      "modified_date": DateTime.now().toIso8601String(),
    };

    try {
      final response = await http.post(
        Uri.parse('https://demo.yelbee.com/events/add_event.php'),
        headers: {"Content-Type": "application/json"},
        body: json.encode(eventData),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 &&
          (responseData['message'] != null ||
              responseData['success'] == true)) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Thank You!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Your event has been added successfully.',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(color: const Color(0xFF0B1957)),
                ),
              ),
            ],
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Error',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Text(
              responseData['error'] ?? 'Failed to add event.',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Exception',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "An error occurred: $e",
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // ------- UI Helpers -------

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

  // FIXED: City Autocomplete without setState during build
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
        fieldViewBuilder:
            (context, textEditingController, focusNode, onSubmit) {
          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            onChanged: (value) {
              // Update cityController when text changes - this is safe
              cityController.text = value;
            },
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: "Select or type city",
              hintStyle: GoogleFonts.lato(color: Colors.grey),
              prefixIcon:
                  const Icon(Icons.location_city, color: Color(0xFF0B1957)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select or enter a city';
              }
              return null;
            },
          );
        },
        onSelected: (String selection) {
          final city = selection.split(',').first.trim();
          cityController.text = city;
        },
      ),
    );
  }

  // FIXED: Contact Name Autocomplete without setState during build
  Widget _buildContactNameAutocomplete() {
    return Container(
      decoration: _blueBorderDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return _contactNames;
          }
          return _contactNames.where((String name) {
            return name.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                );
          });
        },
        fieldViewBuilder:
            (context, textEditingController, focusNode, onSubmit) {
          return TextFormField(
            controller: textEditingController,
            focusNode: focusNode,
            onChanged: (value) {
              // Update contactNameController when text changes - this is safe
              contactNameController.text = value;
            },
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: "Type or select contact name",
              hintStyle: GoogleFonts.lato(color: Colors.grey),
              prefixIcon: const Icon(Icons.person, color: Color(0xFF0B1957)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter contact name';
              }
              return null;
            },
          );
        },
        onSelected: (String selection) {
          contactNameController.text = selection;
          final match = _contactsList.firstWhere(
            (c) => c['name'] == selection,
            orElse: () => {'name': '', 'number': ''},
          );
          if (match['number']?.isNotEmpty == true) {
            contactNumberController.text = match['number']!;
          }
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
                        color: const Color(0xFF0B1957),
                      ),
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
                        loadingBuilder: (BuildContext context, Widget child,
                            ImageChunkEvent? loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                        errorBuilder: (BuildContext context, Object exception,
                            StackTrace? stackTrace) {
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
                    image: NetworkImage(controller.text),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD1E8FF),
      appBar: AppBar(
        title: Text(
          'Add Event',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF0B1957),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
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
                  _buildLabeledField(
                    label: "Event Name",
                    child: _buildTextFormField(
                      controller: eventNameController,
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
                    label: "Start Date",
                    child: _buildTextFormField(
                      controller: startDateController,
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
                    label: "End Date",
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        _buildTextFormField(
                          controller: endDateController,
                          hint: "dd-MM-yyyy",
                          readOnly: true,
                          onTap: _pickEndDate,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select end date';
                            }
                            try {
                              final startDt =
                                  _parseIndianDate(startDateController.text);
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
                      controller: startTimeController,
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
                      controller: endTimeController,
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
                        if (startTimeController.text.isNotEmpty &&
                            endTimeController.text.isNotEmpty) {
                          final st = _parseTimeOfDay(startTimeController.text);
                          final et = _parseTimeOfDay(endTimeController.text);
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
                      controller: venueController,
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Contact Name",
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0B1957),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildContactNameAutocomplete(),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "Contact Number",
                    child: _buildTextFormField(
                      controller: contactNumberController,
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
                    label: "Event Details",
                    child: _buildTextFormField(
                      controller: eventDetailsController,
                      hint: "Describe the event...",
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter event details';
                        }
                        return null;
                      },
                      prefixIcon:
                          const Icon(Icons.info, color: Color(0xFF0B1957)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabeledField(
                    label: "Tags (comma separated)",
                    child: _buildTextFormField(
                      controller: tagsController,
                      hint: "E.g. Special, Meeting",
                      prefixIcon:
                          const Icon(Icons.label, color: Color(0xFF0B1957)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildImagePickSection(
                    label: "Boarding Pass Image (Optional)",
                    controller: boardingPassController,
                    isBoardingPass: true,
                    hint: "Upload boarding pass image",
                  ),
                  const SizedBox(height: 16),
                  _buildImagePickSection(
                    label: "Event Image (Optional)",
                    controller: imageController,
                    isBoardingPass: false,
                    hint: "Upload event image",
                  ),
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
                              'Add Event',
                              style: GoogleFonts.lato(
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
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
