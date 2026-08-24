# ⭐ Star Kataloğu

**yunusozkarakasoglu** hesabının star'ladığı tüm repoların **tek dosyalık, aranabilir** HTML kataloğu.

## 🚀 Özellikler

- 🔍 **Arama** — repo adı, açıklama, etiket, kategori üzerinde canlı arama
- 📂 **Sol panel** — açılır/kapanır kategori menüsü (Tümü + 30 kategori)
- 🎯 **Filtreler** — dil, etiket, minimum ★, sıralama (★ / A-Z / son güncelleme)
- 📋 **Tablo** — Repo Adı | Kısa Açıklama | Özellikler (dil, ★, lisans, topic) | Etiketler
- 🏷️ **Etiketler** — her repoya otomatik etiket (AI, MCP, Self-host, Docker, React...)
- 📱 **Responsive** — mobilde çalışır, sidebar otomatik kapanır

## 🗂️ Dosyalar

| Dosya | Açıklama |
|---|---|
| `index.html` | Katalog (tek dosya — aç ve kullan, sunucu gerekmez) |
| `guncelle.py` | Veriyi GitHub API'den çeker, HTML'i üretir |
| `guncelle.sh` | Tek komutla güncelleme (çek → üret → commit → push) |
| `tara.py` | 🔍 Yeni repo tarama — tarih aralığına göre ilgili yeni repoları bulur |
| `data.json` | Son veri önbelleği (repo + kategori üyelikleri) |

## 🔄 Güncelleme

```bash
./guncelle.sh
```

Ya da asistanına **"kataloğu güncelle"** de — bu scripti çalıştırır.

## 🔍 Yeni Repo Tarama

Son günlerde oluşturulan, kategorilerine uygun **yeni açık kaynak repoları** bulur.

```bash
python3 tara.py --gun 30                      # son 30 günde oluşturulanlar
python3 tara.py --since 2026-08-01           # belirli tarihten beri
python3 tara.py --since X --until Y          # tarih aralığı
python3 tara.py --gun 14 --kategori "AI"     # yalnızca belirli kategori
python3 tara.py --gun 30 --kaydet            # sonucu tarama.md olarak kaydet
```

**Çıktı sütunları:** Repo Adı | URL | Tarih | Özellikler (ne yapar) | ★ | Lisans | Kategori

**Kriterler:**
- ✅ Lisans kesinlikle tamamen açık kaynak + ücretsiz (OSI onaylı: MIT, Apache, GPL, AGPL...)
- ✅ Arşivlenmemiş, aktif repolar
- ✅ Zaten star'lı olanlar hariç tutulur
- ⛔ Min ★ kriteri yok — küçük ama değerli repolar da yakalanır

Asistanına **"repo tara"** de — senin için çalıştırır ve sonucu listeler.

## 🖥️ Görüntüleme

1. **Yerel:** `index.html`'i tarayıcıda aç (çift tık)
2. **GitHub Pages:** repo ayarlarından Pages'i etkinleştir → `https://yunusozkarakasoglu.github.io/star-katalog/`

_Veri kaynağı: GitHub REST + GraphQL API (star listesi + Lists üyelikleri)._
