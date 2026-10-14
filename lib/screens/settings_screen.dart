import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  String _name = '';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); if (mounted) setState(() => _name = p.getString('profileName') ?? ''); }
  Future<void> _setTheme(bool dark) async { appThemeMode.value = dark ? ThemeMode.dark : ThemeMode.light; final p = await SharedPreferences.getInstance(); await p.setString('themeMode', dark ? 'dark' : 'light'); }
  Future<void> _setColor(Color color) async { appSeedColor.value = color; final p = await SharedPreferences.getInstance(); await p.setInt('seedColor', color.value); }
  Future<void> _contact() async { final uri = Uri.parse('https://wsend.co/967737414884'); if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح رابط واتساب'))); } }
  Future<void> _editName() async { final c = TextEditingController(text: _name); final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('تعديل الاسم'), content: TextField(controller: c, autofocus: true, maxLength: 30, decoration: const InputDecoration(labelText: 'الاسم')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('حفظ'))])); c.dispose(); if (result == null || result.isEmpty) return; final p = await SharedPreferences.getInstance(); await p.setString('profileName', result); if (mounted) setState(() => _name = result); }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('الإعدادات')), body: ListView(padding: const EdgeInsets.all(12), children: [
    ListTile(leading: const Icon(Icons.person), title: const Text('الملف الشخصي'), subtitle: Text(_name.isEmpty ? 'لم يحدد الاسم' : _name), trailing: const Icon(Icons.edit), onTap: _editName),
    ValueListenableBuilder<ThemeMode>(valueListenable: appThemeMode, builder: (_, mode, __) => SwitchListTile(secondary: const Icon(Icons.dark_mode), title: const Text('الوضع الداكن'), value: mode == ThemeMode.dark, onChanged: _setTheme)),
    const ListTile(leading: Icon(Icons.palette), title: Text('اللون الأساسي')),
    Wrap(spacing: 12, children: [0xFF075E54, 0xFF1565C0, 0xFF6A1B9A, 0xFFAD1457, 0xFFEF6C00].map((v) => InkWell(onTap: () => _setColor(Color(v)), child: CircleAvatar(backgroundColor: Color(v), child: ValueListenableBuilder<Color>(valueListenable: appSeedColor, builder: (_, c, __) => c.value == v ? const Icon(Icons.check, color: Colors.white) : const SizedBox.shrink())))).toList()),
    const Divider(height: 28), ListTile(leading: const Icon(Icons.wallpaper), title: const Text('خلفية المحادثة'), subtitle: const Text('إعداد الخلفية سيضاف في التحديث التالي'), onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختيار الخلفيات لم يُفعّل في هذه الحزمة بعد.')))),
    ListTile(leading: const Icon(Icons.notifications), title: const Text('الإشعارات'), subtitle: const Text('إشعارات النظام تخضع لإعدادات الهاتف')),
    ListTile(leading: const Icon(Icons.support_agent), title: const Text('التواصل مع المطوّر'), subtitle: const Text('فتح واتساب'), onTap: _contact),
    const ListTile(leading: Icon(Icons.info_outline), title: Text('حول التطبيق'), subtitle: Text('واتساب بلوتوث — محادثات محلية عبر Bluetooth Classic')),
  ]));
}