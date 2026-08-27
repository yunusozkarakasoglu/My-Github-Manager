# 🗺️ My GitHub Manager — Yol Haritası

> Bu repo kişisel GitHub asistanımız. Aşağıdaki özellikler sırayla eklenir.
> Kullanıcı yeni bir fikir verdiğinde buraya eklenir; tamamlananlar ✅ ile işaretlenir.

## 🚦 Durum
- [x] **Son tarama tarihi hatırlama** — `.son-tarama.json` ile zincirleme tarama (kaçıran repo yok)
- [x] **Repo yeniden adlandırma** — star-katalog → My-Github-Manager
- [x] **AGENTS.md asistan sözleşmesi** — komut dili + davranış kuralları
- [x] **Sabah otomatik raporu** — `github_daily_scan.sh` + systemd timer (her sabah 08:00, masaüstü bildirimi)
- [x] **README vizyon bölümü** + Bağımlılıklar tablosu

## 🔭 Planlanan

### 1. 🕒 Sabah Raporu (yakında)
- `github_daily_scan.sh`: her sabah son aramadan itibaren tara → özet üret → masaüstü bildirimi
- Rapor: `~/Masaüstü/Github-Raporu.html` (tıklanabilir linkler) + arşiv `~/Github-Raporlari/YYYY-MM-DD.md`
- systemd user timer: 08:00, `Persistent=true` (bilgisayar kapalıysa açılınca çalışır)

### 2. 📈 Trend & İzleme
- Yüksek büyüme hızındaki repoları tespit (son 14 günde ★ artışı)
- Yeni repo keşfinde `created` yerine `pushed`/yıldız hızı analizi
- Katalogda "son günlerde popülerleşen" rozeti

### 3. 🛠️ Bakım Uyarıları (kendi repolarımız için)
- Arşivlenmiş / uzun süredir güncellenmeyen / yıldızı düşen repoları tespit
- Star listesinde artık gereksiz olanları önerme (yedekli, onaylı temizlik)

### 4. 🎯 Proje Bazlı Öneri Motoru
- "Şu projem için X kategorisinden Y özellikli repo öner" senaryosu
- Proje ihtiyaç profili → katalog eşleşmesi (etiket + kategori + açıklama skorlama)

### 5. 🤝 Çoklu Hesap / Paylaşım
- Birden fazla GitHub hesabı / takım listesi desteği
- Kategori listelerini `.md` olarak dışa aktarma (paylaşılabilir)

### 6. 🧪 Kalite Katmanı
- `tara.py` sonuçlarında spam/crack filtresini güçlendirme (sürekli yeni desenler)
- Duplicate/çok benzer repo tespiti (aynı işi yapan iki repoyu karşılaştırmalı öner)

## 💡 Fikir Kutusu (henüz sıralanmadı)
- GitHub API rate limit takibi ve akıllı bekleme (zaten kısmen var)
- Kategoriler için emoji tabanlı görsel etiketleme (mevcut — geliştirilebilir)
- index.html'e "karşılaştır" görünümü (iki repoyu yan yana)
- Push bildirimleri (Telegram/ntfy) — masaüstü bildirimi dışına taşıma
