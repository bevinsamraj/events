// find_contact_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class FindContactPage extends StatefulWidget {
  const FindContactPage({Key? key}) : super(key: key);

  @override
  State<FindContactPage> createState() => _FindContactPageState();
}

class _FindContactPageState extends State<FindContactPage> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    const String url = 'https://demo.yelbee.com/events/events.php';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Contact> contacts =
            data.map((item) => Contact.fromJson(item)).toList();
        setState(() {
          _contacts = contacts;
          _filteredContacts = contacts;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('Failed to load contacts.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('An error occurred: $e');
    }
  }

  void _filterContacts(String query) {
    List<Contact> filtered = _contacts.where((contact) {
      return contact.contactName.toLowerCase().contains(query.toLowerCase()) ||
          contact.contactNumber.contains(query) ||
          (contact.eventName != null &&
              contact.eventName!.toLowerCase().contains(query.toLowerCase()));
    }).toList();
    setState(() {
      _filteredContacts = filtered;
      _searchQuery = query;
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showErrorDialog('Could not launch phone dialer.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Find Contact',
          style: GoogleFonts.lato(
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF0B1957),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: _filterContacts,
                    decoration: InputDecoration(
                      hintText: 'Search Contacts',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredContacts.isEmpty
                      ? Center(
                          child: Text(
                            'No contacts found.',
                            style: GoogleFonts.lato(
                              textStyle: const TextStyle(
                                fontSize: 18,
                                color: Color(0xFF0B1957),
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredContacts.length,
                          itemBuilder: (context, index) {
                            final contact = _filteredContacts[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 4,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF0B1957),
                                  child: Text(
                                    contact.contactName.isNotEmpty
                                        ? contact.contactName[0].toUpperCase()
                                        : 'C',
                                    style: GoogleFonts.lato(
                                      textStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  contact.contactName,
                                  style: GoogleFonts.lato(
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0B1957),
                                    ),
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      contact.contactNumber,
                                      style: GoogleFonts.lato(
                                        textStyle: const TextStyle(
                                          color: Color(0xFF0B1957),
                                        ),
                                      ),
                                    ),
                                    if (contact.eventName != null)
                                      Text(
                                        contact.eventName!,
                                        style: GoogleFonts.lato(
                                          textStyle: const TextStyle(
                                            color: Color(0xFF0B1957),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.phone,
                                    color: Color(0xFF0B1957),
                                  ),
                                  onPressed: () {
                                    _makePhoneCall(contact.contactNumber);
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class Contact {
  final String contactName;
  final String contactNumber;
  final String? eventName;

  Contact({
    required this.contactName,
    required this.contactNumber,
    this.eventName,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      contactName: json['contact_name'] ?? '',
      contactNumber: json['contact_number'] ?? '',
      eventName: json['event_name'],
    );
  }
}
