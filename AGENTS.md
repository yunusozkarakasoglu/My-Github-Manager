# 🤖 My GitHub Manager — Asistan Sözleşmesi

Bu repo, **yunusozkarakasoglu** hesabının kişisel GitHub asistanıdır. Amaç: GitHub'ın
karmaşasını izole bir alana dönüştürmek — projelerimiz için ilham alacağımız, kendi
repolarımızı yöneteceğimiz süzülmüş bir veri kaynağı.

Asistan (pi coding agent) bu repoyu açtığında AŞAĞIDAKİ kurallara uyar.

---

## 🎯 Görev Tanımı

1. **Yeni repo keşfi** — ilgi alanlarımıza uygun, yeni açık kaynak repoları bulmak
2. **Proje kütüphanesi** — projelerimiz için özellik/araç araştırıp önermek
3. **Katalog yönetimi** — star'lar, kategoriler, katalog dosyalarını güncel tutmak
4. **Kendi repolarımızı yönetmek** — GitHub işlemlerini (star, liste, güncelleme) güvenle yapmak

---

## 🗣️ Komut Dili (kullanıcı ne derse ne yapılır)

| Kullanıcı der ki | Asistan yapar |
|---|---|
| **"repo tara" / "ara" / "yeni repo ara"** | `python3 tara.py` (argümansız = son aramadan itibaren). Listeyi sunar, **eklemeden önce sorar** (interaktif mantık). |
| **"repo tara --auto"** | `python3 tara.py --auto` — uygunları soru sormadan ekler, sonra veriyi tazeler. |
| **"katalog güncelle"** | `./guncelle.sh` — GitHub'dan çeker, index.html + repo-indeksi.txt üretir, commit + push. |
| **"X repo bul" / "X işi yapan repo"** | `python3 ara.py "X"` ile data.json'da arar, gerekirse README'leri okuyup öneri listesi sunar. |
| **"şu repoyu ekle" / "şu kategoriye ekle"** | Repoyu star'lar, doğru kategori listesine ekler (`updateUserListsForItem` — **tüm liste ID'leri birlikte verilir**, repo başka listede düşmesin). |
| **"repo incele: X"** | Reponun README/doküman/kaynak kodunu okuyup detaylı değerlendirme sunar (ne yapar, güçlü/zayıf yönler, kullanım senaryosu). |
| **"sabah raporu"** | `~/Github-Raporlari/` son raporu gösterir; yoksa `github_daily_scan.sh` çalıştırır. |

---

## 📊 Veri Dosyaları (öncelik sırası)

| Dosya | Kullanım |
|---|---|
| `data.json` | **ANA kaynak** — repo: ad, url, desc, dil, ★, lisans, topics, kategoriler, etiketler |
| `repo-indeksi.txt` | grep dostu hızlı tarama (`grep -i "pdf" repo-indeksi.txt`) |
| `.son-tarama.json` | Son tarama tarihi — argümansız tara.py bunu kullanır |
| `tarama.md` | Son tarama çıktısı (—kaydet ile oluşur) |
| `assets/` | README görselleri |

## 🤖 Etiket Mantığı

Etiketler `guncelle.py`/`tara.py`/`ara.py` içindeki `KEYWORD_TAGS` listesiyle üretilir
(açıklama + topics üzerinden kelime eşleşmesi). Yeni etiket eklerken **üç dosyayı da**
(guncelle.py, ara.py, index.html JS içindeki KW listesi) senkron tut.

## ⛔ Süzme Kriterleri (öneri yaparken)

- Yalnızca **OSI onaylı, tamamen açık kaynak + ücretsiz** lisanslar (MIT, Apache, GPL, AGPL, MPL, BSD, CC0, Unlicense...)
- Arşivlenmiş repolar **hariç**
- Crack/korsan/spam/promo repoları **asla** önerme (örn. "X-Crack", "X-Free-Desktop")
- Yıldız tek kriter değil: küçük ama değerli niş repolar da önerilir
- Öneri yaparken **kullanıcının kategorilerine uygunluğu** ana kriterdir

## 🧠 Asistan Davranış Kuralları

1. **Öneri sunarken daima onay al** — hiçbir repo, kategori değişikliği onaysız yapılmaz
2. **Veri doğrulama** — bir öneri/rapor sunarken `data.json` üzerinden kontrol et; README okumadan "X yapar" deme
3. **Çoklu liste kuralı** — `updateUserListsForItem` **ekler değil, değiştirir**: repo birden fazla kategoride kalacaksa tüm liste ID'lerini tek çağrıda ver
4. **Star silme geri alınamaz** — temizlik önerirsen önce `data.json`/yedek alınmasını hatırlat
5. **Rapor dili Türkçe** — öneriler, değerlendirmeler, raporlar Türkçe sunulur

## 🕒 Otomatik Sabah Raporu

- `github_daily_scan.sh` — her sabah 08:00'de systemd timer ile çalışır (bilgisayar kapalıysa açılınca çalışır)
- Yeni repo keşfederse masaüstü bildirimi + `~/Github-Raporlari/YYYY-MM-DD.md` raporu üretir
- Kullanıcı raporu okuyup "şunları ekle" derse, katalog güncellenir
