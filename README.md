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
| `data.json` | Son veri önbelleği (repo + kategori üyelikleri) |

## 🔄 Güncelleme

```bash
./guncelle.sh
```

Ya da asistanına **"kataloğu güncelle"** de — bu scripti çalıştırır.

## 🖥️ Görüntüleme

1. **Yerel:** `index.html`'i tarayıcıda aç (çift tık)
2. **GitHub Pages:** repo ayarlarından Pages'i etkinleştir → `https://yunusozkarakasoglu.github.io/star-katalog/`

_Veri kaynağı: GitHub REST + GraphQL API (star listesi + Lists üyelikleri)._
