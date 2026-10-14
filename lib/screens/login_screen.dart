import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  String? _photoPath;
  bool _busy = false;
  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (x != null && mounted) setState(() => _photoPath = x.path);
  }
  Future<void> _continue() async {
    final name = _name.text.trim();
    if (name.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب اسمك أولًا'))); return; }
    setState(() => _busy = true);
    final p = await SharedPreferences.getInstance();
    await p.setString('profileName', name);
    if (_photoPath != null) await p.setString('profilePhotoPath', _photoPath!);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }
  @override void dispose() { _name.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.forum, size: 76, color: Color(0xFF075E54)), const SizedBox(height: 12),
      const Text('مرحبًا بك', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const Text('أنشئ ملفك المحلي للبدء بالمحادثة عبر البلوتوث'), const SizedBox(height: 24),
      GestureDetector(onTap: _pickPhoto, child: CircleAvatar(radius: 42, backgroundColor: const Color(0xFFD7E8E4), child: _photoPath == null ? const Icon(Icons.add_a_photo, size: 32, color: Color(0xFF075E54)) : const Icon(Icons.check_circle, size: 40, color: Color(0xFF075E54)))),
      const SizedBox(height: 18), TextField(controller: _name, maxLength: 30, decoration: const InputDecoration(labelText: 'اسمك', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
      const SizedBox(height: 12), SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _continue, child: Text(_busy ? 'جارٍ الحفظ...' : 'متابعة'))),
      const SizedBox(height: 8), const Text('هذا ملف محلي على الهاتف وليس حسابًا موثقًا.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
    ])))));
}