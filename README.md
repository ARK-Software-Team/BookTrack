# 📚 BookTrack

Kişisel okuma takip ve kitap takas mobil uygulaması.

Flutter + Firebase ile geliştirilmiştir.

---

## Özellikler

- **Kütüphane Yönetimi** — Okudum / Okuyorum / Okunacak kategorileriyle kitap takibi, yıldız puanı ve kişisel not
- **Kitap Arama** — Open Library API üzerinden milyonlarca kitaba erişim; bulunamayanlar için manuel ekleme
- **Kitap Detay** — Sayfa takibi, ilerleme çubuğu, puan/yorum, takasa ekleme
- **Okuma Hedefleri** — Günlük / haftalık / aylık / yıllık kitap veya sayfa hedefi belirleme
- **İstatistikler** — Haftalık (çubuk) / aylık (çizgi) / yıllık (çubuk) grafikler, takas istatistikleri
- **Takas Sistemi** — Şehir/ilçe bazlı ilan oluşturma, teklif gönderme/alma, sohbet ve çift taraflı onay mekanizması
- **Aktivite Logu** — 15 farklı log tipiyle tüm kullanıcı eylemlerinin zaman damgalı kaydı
- **Ayarlar** — Profil güncelleme, varsayılan konum tercihi

---

## Teknolojiler

| Katman | Teknoloji |
|---|---|
| Mobil | Flutter 3.x (Dart) |
| Kimlik Doğrulama | Firebase Authentication |
| Veritabanı | Cloud Firestore |
| Durum Yönetimi | Provider |
| Harici API | Open Library API |
| Görüntü Önbellekleme | cached_network_image |
| Mimari | Service Layer + Provider (MVVM benzeri) |

---

## Kurulum

> Firebase yapılandırma dosyaları (`.gitignore` gereği) repoya dahil edilmemiştir.
> Kendi Firebase projenizi oluşturup aşağıdaki adımları izleyin.

### Gereksinimler

- Flutter SDK 3.x
- Dart SDK
- Android Studio veya VS Code
- Firebase projesi (Authentication + Firestore etkin)

### Adımlar

```bash
# 1. Repoyu klonla
git clone https://github.com/BatuhanARK/BookTrack.git
cd BookTrack

# 2. Bağımlılıkları yükle
flutter pub get

# 3. Firebase yapılandırmasını ekle
# firebase_options.dart → lib/
# google-services.json → android/app/

# 4. Çalıştır
flutter run
```

### Firebase Kurulumu

1. [Firebase Console](https://console.firebase.google.com)'da yeni proje oluşturun
2. Authentication → E-posta/Şifre oturum açmayı etkinleştirin
3. Cloud Firestore veritabanı oluşturun
4. `flutterfire configure` komutuyla `firebase_options.dart` dosyasını oluşturun
5. `google-services.json` dosyasını `android/app/` dizinine kopyalayın

---

## Proje Yapısı

```
lib/
├── main.dart
├── auth_service.dart
├── home_page.dart
├── login_page.dart
├── register_page.dart
├── data/
│   └── turkey_locations.dart       # 81 il, 972 ilçe
├── models/
│   ├── book_model.dart
│   ├── reading_goal_model.dart
│   └── user_book_model.dart
├── services/
│   ├── firestore_service.dart
│   ├── log_service.dart
│   ├── open_library_service.dart
│   └── trade_service.dart
└── screens/
    ├── add_book_manual_page.dart
    ├── book_detail_page.dart
    ├── goals_page.dart
    ├── library_page.dart
    ├── log_page.dart
    ├── search_page.dart
    ├── settings_page.dart
    ├── stats_page.dart
    ├── trade_chat_page.dart
    ├── trade_page.dart
    └── trade_search_page.dart
```

---

## Lisans

Bu proje [MIT Lisansı](LICENSE) ile lisanslanmıştır.