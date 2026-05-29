// lib/screens/settings_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../data/turkey_locations.dart';
import 'log_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _nameController;
  bool _savingName = false;
  bool _nameChanged = false;

  String? _selectedCity;
  String? _selectedDistrict;
  bool _savingLocation = false;
  bool _locationChanged = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _nameController = TextEditingController(text: auth.displayName ?? '');
    _nameController.addListener(() {
      final current = Provider.of<AuthService>(context, listen: false).displayName ?? '';
      setState(() => _nameChanged = _nameController.text.trim() != current);
    });
    _selectedCity = auth.preferredCity;
    _selectedDistrict = auth.preferredDistrict;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    setState(() => _savingName = true);
    await Provider.of<AuthService>(context, listen: false)
        .updateDisplayName(_nameController.text.trim());
    setState(() { _savingName = false; _nameChanged = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('İsim güncellendi!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _saveLocation() async {
    setState(() => _savingLocation = true);
    await Provider.of<AuthService>(context, listen: false)
        .updateLocation(_selectedCity, _selectedDistrict);
    setState(() { _savingLocation = false; _locationChanged = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Konum tercihi kaydedildi!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<String?> _pickFromSheet(List<String> items, String title, String? selected) async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SearchableSheet(items: items, title: title, selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final email = auth.user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        toolbarHeight: 48,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profil ──────────────────────────────────────────────────────
          _SectionHeader(title: 'Profil'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person, color: Colors.deepPurple, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.displayName?.isNotEmpty == true
                                ? auth.displayName!
                                : 'İsim belirlenmedi',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(email,
                              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text('Adınız',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                        color: Colors.deepPurple)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Adınızı girin',
                    prefixIcon: const Icon(Icons.edit_outlined,
                        color: Colors.deepPurple, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: (_savingName || !_nameChanged) ? null : _saveName,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      disabledBackgroundColor: Colors.grey[200],
                    ),
                    child: _savingName
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Kaydet', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Konum Tercihi ────────────────────────────────────────────────
          _SectionHeader(title: 'Varsayılan Konum'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Takas eklerken otomatik seçilir',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Şehir
                const Text('Şehir', style: TextStyle(fontWeight: FontWeight.w600,
                    fontSize: 13, color: Colors.deepPurple)),
                const SizedBox(height: 8),
                _LocationTile(
                  label: _selectedCity ?? 'Şehir seçin',
                  icon: Icons.location_city,
                  hasValue: _selectedCity != null,
                  onTap: () async {
                    final r = await _pickFromSheet(
                        turkeyProvinces, 'Şehir seçin', _selectedCity);
                    if (r != null) {
                      setState(() {
                        _selectedCity = r;
                        _selectedDistrict = null;
                        _locationChanged = true;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                // İlçe
                const Text('İlçe', style: TextStyle(fontWeight: FontWeight.w600,
                    fontSize: 13, color: Colors.deepPurple)),
                const SizedBox(height: 8),
                _LocationTile(
                  label: _selectedDistrict ??
                      (_selectedCity == null ? 'Önce şehir seçin' : 'İlçe seçin'),
                  icon: Icons.location_on,
                  hasValue: _selectedDistrict != null,
                  enabled: _selectedCity != null,
                  onTap: _selectedCity == null
                      ? null
                      : () async {
                          final r = await _pickFromSheet(
                              districtsOf(_selectedCity!),
                              'İlçe seçin',
                              _selectedDistrict);
                          if (r != null) {
                            setState(() {
                              _selectedDistrict = r;
                              _locationChanged = true;
                            });
                          }
                        },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_selectedCity != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() {
                            _selectedCity = null;
                            _selectedDistrict = null;
                            _locationChanged = true;
                          }),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey,
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Temizle'),
                        ),
                      ),
                    if (_selectedCity != null) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: (_savingLocation || !_locationChanged)
                            ? null
                            : _saveLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          disabledBackgroundColor: Colors.grey[200],
                        ),
                        child: _savingLocation
                            ? const SizedBox(height: 20, width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Kaydet', style: TextStyle(fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Hesap ────────────────────────────────────────────────────────
          _SectionHeader(title: 'Hesap'),
          const SizedBox(height: 8),
          Container(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.history,
                  iconColor: Colors.deepPurple,
                  title: 'Aktivite Geçmişi',
                  subtitle: 'Tüm işlem loglarını görüntüle',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LogPage()),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.email_outlined,
                  iconColor: Colors.blue,
                  title: 'E-posta',
                  subtitle: email,
                  showArrow: false,
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.logout,
                  iconColor: Colors.red,
                  title: 'Çıkış Yap',
                  titleColor: Colors.red,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Çıkış Yap'),
                        content: const Text(
                            'Hesabından çıkış yapmak istiyor musun?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Vazgeç')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Çıkış Yap'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      await auth.logout();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
        blurRadius: 6, offset: const Offset(0, 2))],
  );
}

class _LocationTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool hasValue;
  final bool enabled;
  final VoidCallback? onTap;

  const _LocationTile({
    required this.label, required this.icon,
    this.hasValue = false, this.enabled = true, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          border: Border.all(
              color: hasValue ? Colors.deepPurple : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
          color: enabled ? Colors.white : Colors.grey[50],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon,
                color: hasValue ? Colors.deepPurple : Colors.grey[400],
                size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: hasValue ? Colors.black87 : Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: enabled ? Colors.grey : Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
            color: Colors.grey[500], letterSpacing: 1.2),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showArrow;

  const _SettingsTile({
    required this.icon, required this.iconColor, required this.title,
    this.titleColor, this.subtitle, this.onTap, this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: TextStyle(fontSize: 14,
          fontWeight: FontWeight.w500, color: titleColor)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey[400]))
          : null,
      trailing: showArrow
          ? const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// ── Aranabilir seçici ─────────────────────────────────────────────────────────

class _SearchableSheet extends StatefulWidget {
  final List<String> items;
  final String title;
  final String? selected;

  const _SearchableSheet({required this.items, required this.title, this.selected});

  @override
  State<_SearchableSheet> createState() => _SearchableSheetState();
}

class _SearchableSheetState extends State<_SearchableSheet> {
  final TextEditingController _ctrl = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _ctrl.addListener(() {
      final q = _ctrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? widget.items
            : widget.items.where((i) => i.toLowerCase().contains(q)).toList();
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, i) {
                final item = _filtered[i];
                final selected = item == widget.selected;
                return ListTile(
                  title: Text(item),
                  trailing: selected
                      ? const Icon(Icons.check, color: Colors.deepPurple)
                      : null,
                  selected: selected,
                  selectedColor: Colors.deepPurple,
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}