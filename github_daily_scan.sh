#!/usr/bin/env bash
# ⭐ My GitHub Manager — Sabah Raporu
# systemd timer ile her sabah 08:00'de çalışır (bilgisayar kapalıysa açılınca çalışır).
# Yeni repoları son aramadan itibaren tarar, rapor üretir, masaüstü bildirimi gönderir.
# Manuel çalıştırma: ./sabah-raporu.sh
set -uo pipefail

REPO_DIR="$HOME/Github-My-Katalog"
RAPOR_DIR="$HOME/Github-Raporlari"
LOGFILE="$RAPOR_DIR/.son-tarama-log.txt"
mkdir -p "$RAPOR_DIR"

TARIH=$(date '+%Y-%m-%d')
SAAT=$(date '+%H:%M')

# ── 1) Tara (son aramadan itibaren; ekleme YAPILMAZ, sadece keşif) ──
cd "$REPO_DIR" || { notify-send "⭐ My GitHub Manager" "Repo dizini bulunamadı: $REPO_DIR" 2>/dev/null || true; exit 1; }
python3 -u tara.py --no-add --max 8 > "$LOGFILE" 2>&1
RC=$?

# ── 2) Özet çıkar ──
TOPLAM=$(grep -oP 'TOPLAM:\s*\K[0-9]+' "$LOGFILE" | tail -1)
TOPLAM=${TOPLAM:-0}
ARALIK=$(grep -m1 'Tarama aralığı' "$LOGFILE" | sed 's/.*aralığı: //; s/ | lisans.*//')
LISANS_IZI=$(grep -ic "rate limit" "$LOGFILE")

# ── 3) Rapor dosyası üret ──
RAPOR="$RAPOR_DIR/$TARIH.md"
{
  echo "# ⭐ My GitHub Manager — Sabah Raporu ($TARIH $SAAT)"
  echo
  echo "**Tarama aralığı:** ${ARALIK:-bilinmiyor}"
  echo
  if [ "$TOPLAM" -gt 0 ]; then
    echo "## 🆕 $TOPLAM yeni repo keşfedildi"
    echo
    grep -E '^\| \[' "$LOGFILE" | head -12
    echo
    echo "> ➕ Eklemek için: \`cd ~/Github-My-Katalog && python3 tara.py\` (listeyi sunar, onayınla ekler)"
  elif [ "$LISANS_IZI" -gt 0 ]; then
    echo "## ⚠️ Tarama sorunlu olabilir"
    echo
    echo "Çıktıda hata/limit işareti görüldü. Ayrıntı: \`cat ~/Github-Raporlari/.son-tarama-log.txt\`"
    echo
    tail -20 "$LOGFILE"
  else
    echo "## ✅ Yeni repo yok"
    echo
    echo "Son aramadan bu yana ilgi alanlarına uygun yeni repo bulunamadı. Katalog güncel."
  fi
  echo
  echo "---"
  echo "_Otomatik tarama · çıkış kodu: ${RC}_"
} > "$RAPOR"

# ── 4) Masaüstü bildirimi ──
if [ "$TOPLAM" -gt 0 ]; then
  MSG="$TOPLAM yeni repo keşfedildi 🎉 — rapor: ~/Github-Raporlari/$TARIH.md"
else
  MSG="Yeni repo yok — katalog güncel. Rapor: ~/Github-Raporlari/$TARIH.md"
fi
notify-send "⭐ My GitHub Manager" "$MSG" 2>/dev/null || true

echo "📄 Rapor: $RAPOR"
echo "$MSG"
