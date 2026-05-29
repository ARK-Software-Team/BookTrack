import 'dart:convert';
import 'package:http/http.dart' as http;

// Arama sonucu olarak dönen kitap verisi
class OpenLibraryBook {
  final String title;
  final String author;
  final String? isbn;
  final String? coverUrl;
  final int? pageCount;
  final int? publishYear;
  final String? publisher;
  final String openLibraryKey; // örn: "/works/OL12345W"

  OpenLibraryBook({
    required this.title,
    required this.author,
    this.isbn,
    this.coverUrl,
    this.pageCount,
    this.publishYear,
    this.publisher,
    required this.openLibraryKey,
  });

  factory OpenLibraryBook.fromJson(Map<String, dynamic> json) {
    // Yazar adı
    final authorList = json['author_name'] as List<dynamic>?;
    final author = authorList != null && authorList.isNotEmpty
        ? authorList.first.toString()
        : 'Bilinmiyor';

    // ISBN
    final isbnList = json['isbn'] as List<dynamic>?;
    final isbn = isbnList != null && isbnList.isNotEmpty
        ? isbnList.first.toString()
        : null;

    // Kapak görseli (Open Library cover ID'si varsa URL oluştur)
    final coverIdList = json['cover_i'];
    final coverUrl = coverIdList != null
        ? 'https://covers.openlibrary.org/b/id/$coverIdList-L.jpg'
        : null;

    // Yayın yılı
    final publishYearList = json['publish_year'] as List<dynamic>?;
    int? publishYear;
    if (publishYearList != null && publishYearList.isNotEmpty) {
      final years = publishYearList.map((e) => int.tryParse(e.toString()) ?? 0).toList();
      years.sort();
      publishYear = years.first; // en eski baskı yılı
    }

    // Yayınevi
    final publisherList = json['publisher'] as List<dynamic>?;
    final publisher = publisherList != null && publisherList.isNotEmpty
        ? publisherList.first.toString()
        : null;

    // Sayfa sayısı
    final pageCount = json['number_of_pages_median'] != null
        ? (json['number_of_pages_median'] as num).toInt()
        : null;

    return OpenLibraryBook(
      title: json['title']?.toString() ?? 'Başlıksız',
      author: author,
      isbn: isbn,
      coverUrl: coverUrl,
      pageCount: pageCount,
      publishYear: publishYear,
      publisher: publisher,
      openLibraryKey: json['key']?.toString() ?? '',
    );
  }
}

class OpenLibraryService {
  static const String _baseUrl = 'https://openlibrary.org';

  /// Kitap adı veya yazara göre arama yapar
  /// [query]: arama metni
  /// [limit]: max sonuç sayısı (varsayılan 10)
  Future<List<OpenLibraryBook>> searchBooks(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    final encodedQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse(
      '$_baseUrl/search.json?q=$encodedQuery&limit=$limit&fields=key,title,author_name,isbn,cover_i,publish_year,publisher,number_of_pages_median',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final docs = data['docs'] as List<dynamic>? ?? [];

      return docs
          .map((doc) => OpenLibraryBook.fromJson(doc as Map<String, dynamic>))
          .where((book) => book.title.isNotEmpty)
          .toList();
    } catch (e) {
      // Ağ hatası veya timeout — boş liste döndür
      return [];
    }
  }

  /// ISBN ile tek kitap arar
  Future<OpenLibraryBook?> searchByIsbn(String isbn) async {
    final results = await searchBooks('isbn:$isbn', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }
}