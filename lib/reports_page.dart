// reports_page.dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';

class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final WebViewController controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
   
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${error.description}')),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse("https://demo.yelbee.com/eventz/"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Reports"),
        backgroundColor: const Color(0xFF0B1957),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
