# ⭐ Star Kataloğu

**yunusozkarakasoglu** hesabının star'ladığı tüm repoların **tek dosyalık, aranabilir** HTML kataloğu.
GitHub star'larını ve kategori (Lists) üyeliklerini otomatik çeker, tarayıcıda kullanılabilir bir kataloğa dönüştürür.

---

## ✅ Gereksinimler

| Araç | Neden gerekli |
|---|---|
| **Python 3.8+** | Scriptleri çalıştırmak için (`python3 --version` ile kontrol et) |
| **GitHub CLI (`gh`)** | GitHub API erişimi için — kurulu ve giriş yapılmış olmalı |
| **Git** | Güncellemeleri push etmek için |

`gh` kurulumu ve giriş:
```bash
sudo apt install gh        # Debian/Ubuntu
gh auth login              # github.com hesabına giriş
```

> ⚠️ Listeleri okuyabilmek için `gh` token'ında **`user`** scope'u olmalı:
> ```bash
> gh auth refresh -s user
> ```

---

## 🚀 Hızlı Başlangıç (İlk Kurulum)

```bash
# 1) Repoyu kopyala
git clone https://github.com/yunusozkarakasoglu/star-katalog.git
cd star-katalog

# 2) Kataloğu aç (index.html'i tarayıcıda çift tıkla — sunucu gerekmez)
```

---

## 🖥️ Katalog Özellikleri (`index.html`)

- 🔍 **Arama** — repo adı, açıklama, etiket, kategori üzerinde canlı arama
- 📂 **Sol panel** — açılır/kapanır kategori menüsü (☰ butonu; "Tümü" + 30 kategori)
- 🎯 **Filtreler** — dil, etiket, minimum ★, sıralama (★ / A-Z / son güncelleme)
- 📋 **Tablo sütunları:**
  | Sütun | Açıklama |
  |---|---|
  | **Repo Adı** | Repo linki + sahip + son güncelleme tarihi |
  | **★ Yıldız** | Yıldız sayısı + orantılı renk çubuğu |
  | **Kısa Açıklama** | Reponun ne yaptığı |
  | **Özellikler** | Dil, lisans, topic rozetleri |
  | **Etiketler** | Otomatik etiketler (AI, MCP, Self-host, Docker...) |
- 🏷️ **Otomatik etiketler** — her repo için anahtar kelime analiziyle üretilir
- 📱 **Responsive** — mobilde çalışır, dar ekranda sidebar otomatik kapanır

---

## 🔄 Güncelleme (yeni star / kategori değişince)

### Tek komut:
```bash
./guncelle.sh
```
Bu script sırayla:
1. GitHub'dan **star listesini** ve **kategori üyeliklerini** çeker
2. `index.html`'i yeniden üretir
3. Değişiklikleri commit + push eder
4. GitHub Pages otomatik yeniden derlenir (2-3 dk)

### Elle:
```bash
python3 guncelle.py --fetch   # veriyi GitHub'dan çek + index.html üret
```

> 💡 **Asistana söyle:** *"kataloğu güncelle"* → `./guncelle.sh` çalıştırılır.

---

## 🔍 Yeni Repo Tarama (`tara.py`)

Son günlerde oluşturulan, kategorilerine uygun **yeni açık kaynak repoları** bulur.

### Kullanım:
```bash
python3 tara.py --gun 30                      # son 30 günde oluşturulanlar
python3 tara.py --since 2026-08-01           # belirli tarihten beri
python3 tara.py --since X --until Y          # tarih aralığı
python3 tara.py --gun 14 --kategori "AI"     # yalnızca belirli kategori
python3 tara.py --gun 30 --kaydet            # sonucu tarama.md olarak kaydeder
python3 tara.py --gun 7 --max 5              # kategori başına sonuç sayısı (varsayılan 8)
python3 tara.py --gun 30 --min-stars 100     # isteğe bağlı min ★ (varsayılan: kriter yok)
```

### Çıktı sütunları:
| Repo Adı | URL | Tarih | Özellikler (ne yapar) | ★ | Lisans | Kategori |

### Kriterler (otomatik uygulanır):
- ✅ **Lisans kesinlikle tamamen açık kaynak + ücretsiz** (OSI onaylı: MIT, Apache, GPL, AGPL, MPL, BSD, CC0...)
- ✅ Arşivlenmemiş, aktif repolar
- ✅ Zaten star'lı olanlar hariç tutulur
- ⛔ Min ★ kriteri yok (istemezsen) — küçük ama değerli repolar da yakalanır
- 🗂️ Her sonuç için **önerilen kategori** otomatik eşleştirilir (TR+EN anahtar kelimelerle)

> 💡 **Asistana söyle:** *"repo tara"* → senin için çalıştırır, listeyi sunar, onayınla star + kategoriye ekler.

---

## 🗂️ Dosya Yapısı

| Dosya | Açıklama |
|---|---|
| `index.html` | Katalog (tek dosya — tarayıcıda aç, sunucu gerekmez) |
| `guncelle.py` | Veriyi GitHub API'den çeker, `index.html`'i üretir |
| `guncelle.sh` | Tek komutla güncelleme (çek → üret → commit → push) |
| `tara.py` | 🔍 Yeni repo tarama aracı |
| `data.json` | Son veri önbelleği (repo + kategori üyelikleri) |
| `tarama.md` | Son tarama çıktısı (—kaydet ile oluşur) |

---

## 🖥️ Görüntüleme Seçenekleri

1. **Yerel:** `index.html`'i tarayıcıda aç (çift tık — internet gerekmez)
2. **GitHub Pages (canlı):** https://yunusozkarakasoglu.github.io/star-katalog/
   - Pages açıksa, her `git push` sonrası otomatik güncellenir
   - `.nojekyll` dosyası sayesinde Jekyll işleme kapalıdır (sorunsuz statik servis)

---

## 🧠 Veri Kaynağı

- **Star listesi:** GitHub REST API (`GET /user/starred`)
- **Kategori üyelikleri:** GitHub GraphQL (`viewer.lists`)
- Tüm işlemler ücretsiz GitHub API limitleri içinde çalışır (token başına 5000 istek/saat)
