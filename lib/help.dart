import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Instructions')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        children: [
          // Logo Section
          Center(
            child: Image.asset(
              'assets/icons/app_icon.png',
              height: 80,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.calculate, size: 80, color: Colors.blue),
            ),
          ),
          const SizedBox(height: 24),
          
          const Text(
            'Welcome to Klator',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'A powerful multi-line scientific calculator.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const Divider(height: 40),

          _buildHelpStep(
            icon: Icons.keyboard_command_key,
            title: 'Multicells',
            description: 'Use the command ⌘ key to create a new solution cell.',
          ),
          _buildHelpStep(
            icon: Icons.iso,
            title: 'Structural Math',
            description: 'Insert fractions with "/" and exponents with "^". Tap any part of the expression to move your cursor.',
          ),
          _buildHelpStep(
            icon: Icons.restore,
            title: 'Undo & Redo',
            description: 'Easily fix mistakes using the history buttons: Tap ⎌ to Undo your last change, or ⎏ to Redo an action you moved back from.',
          ),
          _buildHelpStep(
            icon: Icons.settings_backup_restore,
            title: 'Recall Results',
            description: 'Every calculation is assigned an orange cell number on the left. To use a result in a new equation, press "ans" followed by that cell’s number (e.g., ans0).',
          ),
          _buildHelpStep(
            icon: Icons.functions,
            title: 'Equation Solver',
            description: 'Solves Linear, Quadratic, and Simultaneous equations. Simply type the equation as you see it; Klator handles up to 3 unknown variables (x, y, z).',
          ),
          _buildHelpStep(
            icon: Icons.keyboard_command_key,
            title: 'Multiline Equations',
            description: 'For simultaneous equations, use ⌘ to start a new line for each equation. The solver automatically detects the number of variables which then determines the number of lines needed.',
          ),
          _buildHelpStep(
            icon: Icons.settings,
            title: 'Customization',
            description: 'Tap the gear icon to adjust decimal precision, themes, and haptic feedback.',
          ),

          const SizedBox(height: 32),
          
          const Text(
            'Documentation & Feedback',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'For technical details and updates, visit our GitHub page:',
            style: TextStyle(fontSize: 14),
          ),
          const SelectableText(
            'https://github.com/Dark-Elektron/klator',
            style: TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic),
          ),
          
          const SizedBox(height: 40),
          
          // ElevatedButton(
          //   onPressed: () => Navigator.pop(context),
          //   style: ElevatedButton.styleFrom(
          //     padding: const EdgeInsets.symmetric(vertical: 16),
          //   ),
          //   child: const Text('Return to Calculator'),
          // ),
          // const SizedBox(height: 20),
        ],
      ),
    );
  }

Widget _buildHelpStep({
  required IconData icon, 
  required String title, 
  required String description,
  Color iconColor = Colors.blueGrey, // Default color if none provided
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28, color: iconColor), // Custom color applied here
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title, 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 4),
              Text(
                description, 
                style: TextStyle(fontSize: 15, height: 1.4)
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

}