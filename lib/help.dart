import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo at the top
            Image.asset(
              'assets/icons/playstore.png', // Replace with your actual asset path
              height: 100,
            ),
            const SizedBox(height: 20),

            // Centered help text
            const Text(
              'Welcome to Klator!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Here are some basic instructions to help you use the app:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text(
              '• Use the buttons to perform calculations.\n'
              '• Adjust settings for precision, theme, and feedback.\n'
              '• Toggle between radians and degrees.\n'
              '• Enable sound and haptic feedback as needed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'For further assistance, contact support via email.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),

            // Back button
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
