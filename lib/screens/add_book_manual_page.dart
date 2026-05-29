// lib/screens/add_book_manual_page.dart
// Değişiklik: Durum sırası → Okudum / Okuyorum / Okunacak

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book_model.dart';
import '../services/firestore_service.dart';
import '../auth_service.dart';

class AddBookManualPage extends StatefulWidget {
  const AddBookManualPage({super.key});

  @override
  State<AddBookManualPage> createState() => _AddBookManualPageState();
}

class _AddBookManualPageState extends State<AddBookManualPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _pageCountController = TextEditingController();
  final _publisherController = TextEditingController();
  final _publishYearController = TextEditingController();
  final _descriptionController = TextEditingController();

  ReadingStatus _selectedStatus = ReadingStatus.read;
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _pageCountController.dispose();
    _publisherController.dispose();
    _publishYearController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final userId = Provider.of<AuthService>(context, listen: false).user?.uid;
    if (userId == null) { setState(() => _loading = false); return; }

    final book = BookModel(
      id: '',
      title: _titleController.text.trim(),
      author: _authorController.text.trim(),
      isbn: _isbnController.text.trim().isEmpty ? null : _isbnController.text.trim(),
      pageCount: int.tryParse(_pageCountController.text.trim()),
      publisher: _publisherController.text.trim().isEmpty ? null : _publisherController.text.trim(),
      publishYear: int.tryParse(_publishYearController.text.trim()),
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      isManuallyAdded: true,
    );

    try {
      await FirestoreService().addBookToLibrary(userId: userId, book: book, status: _selectedStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${book.title}" kütüphaneye eklendi!'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kitap eklenirken hata oluştu.'),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manuel Kitap Ekle'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Zorunlu Bilgiler'),
              const SizedBox(height: 8),
              _buildTextField(controller: _titleController, label: 'Kitap Adı', icon: Icons.book,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Kitap adı zorunludur' : null),
              const SizedBox(height: 12),
              _buildTextField(controller: _authorController, label: 'Yazar', icon: Icons.person,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Yazar adı zorunludur' : null),
              const SizedBox(height: 20),
              _sectionTitle('Ek Bilgiler (İsteğe Bağlı)'),
              const SizedBox(height: 8),
              _buildTextField(controller: _pageCountController, label: 'Sayfa Sayısı',
                  icon: Icons.format_list_numbered, keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (int.tryParse(v.trim()) == null) return 'Geçerli bir sayı girin';
                    return null;
                  }),
              const SizedBox(height: 12),
              _buildTextField(controller: _isbnController, label: 'ISBN', icon: Icons.tag,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _buildTextField(controller: _publisherController, label: 'Yayınevi', icon: Icons.business),
              const SizedBox(height: 12),
              _buildTextField(controller: _publishYearController, label: 'Yayın Yılı',
                  icon: Icons.calendar_today, keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final year = int.tryParse(v.trim());
                    if (year == null || year < 1000 || year > DateTime.now().year) return 'Geçerli bir yıl girin';
                    return null;
                  }),
              const SizedBox(height: 12),
              _buildTextField(controller: _descriptionController, label: 'Açıklama / Not',
                  icon: Icons.notes, maxLines: 3),
              const SizedBox(height: 20),
              _sectionTitle('Okuma Durumu'),
              const SizedBox(height: 8),
              _buildStatusSelector(),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(height: 22, width: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Kütüphaneye Ekle', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
          color: Colors.deepPurple, letterSpacing: 0.5));

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.deepPurple),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _buildStatusSelector() {
    // Sıra: Okudum → Okuyorum → Okunacak
    final statuses = [
      (ReadingStatus.read, 'Okudum', Icons.check_circle_outline, Colors.green),
      (ReadingStatus.reading, 'Okuyorum', Icons.menu_book, Colors.orange),
      (ReadingStatus.wantToRead, 'Okunacak', Icons.bookmark_outline, Colors.blue),
    ];
    return Row(
      children: statuses.map((item) {
        final (status, label, icon, color) = item;
        final selected = _selectedStatus == status;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedStatus = status),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.15) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? color : Colors.grey[300]!,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(icon, color: selected ? color : Colors.grey, size: 22),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? color : Colors.grey,
                  )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}