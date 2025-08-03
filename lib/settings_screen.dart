import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart'; // Don't forget this!

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Settings & Privacy")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: themeProvider.isDarkMode,
            onChanged: (value) => themeProvider.toggleTheme(value),
          ),
          ListTile(
            title: const Text("Change Email"),
            onTap: _changeEmail,
          ),
          ListTile(
            title: const Text("Change Password"),
            onTap: () {
              FirebaseAuth.instance.sendPasswordResetEmail(
                email: FirebaseAuth.instance.currentUser?.email ?? '',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Reset link sent to your email")),
              );
            },
          ),
          ListTile(
            title: const Text("Delete My Account"),
            textColor: Colors.red,
            onTap: () async {
              try {
                await FirebaseAuth.instance.currentUser?.delete();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: ${e.toString()}")),
                );
              }
            },
          ),
          ListTile(
            title: const Text("Terms of Use"),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Terms of Use"),
                  content: const SingleChildScrollView(
                    child: Text(
                      "By using CHOMI, you agree to:\n\n"
                      "• Be respectful to others\n"
                      "• Not post harmful or illegal content\n"
                      "• Only withdraw money you've earned fairly (no bots or fake activity) \n"
                      "• Let admins review withdrawals\n"
                      "• Follow all local laws while using the app\n\n"
                      "Violation of these rules may result in account suspension.\n\n"
                      "We may update these terms at any time",
                    ),
                  ),
                ),
              );
            },
          ),
          ListTile(
            title: const Text("Privacy Policy"),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Privacy Policy"),
                  content: const SingleChildScrollView(
                    child: Text(
                      "We value your privacy. CHOMI collects the following:\n\n"
                      "• Your name, email, and profile data\n"
                      "• Posts, likes, views and interactions\n"
                      "• Device & app usage info\n\n"
                      "Your data is stored securely via Firebase.\n"
                      "We use this to improve your experience. We do not sell your data. Your data is securely stored on Firebase servers.\n\n"
                      "Need help? Email: chomisocial56@gmail.com",
                    ),
                  ),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text("Logout"),
            leading: const Icon(Icons.logout),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmail() async {
    TextEditingController emailController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Email"),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: "New email address"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Update"),
            onPressed: () async {
              final newEmail = emailController.text.trim();
              if (newEmail.isNotEmpty) {
                try {
                  await user?.updateEmail(newEmail);
                  await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Email updated. Please verify it.")),
                    );
                  }
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}

