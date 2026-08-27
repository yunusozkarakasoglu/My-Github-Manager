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

# ── 4) HTML rapor üret (Masaüstü + arşiv) ──
MASAUSTU="$HOME/Masaüstü"
[ -d "$MASAUSTU" ] || MASAUSTU="$HOME/Desktop"
HTML_DESK="$MASAUSTU/Github-Raporu.html"
HTML_ARSIV="$RAPOR_DIR/$TARIH.html"
python3 - "$RAPOR" "$HTML_DESK" "$HTML_ARSIV" <<'PYEOF'
import sys, re, html as H
md_path, desk_out, arsiv_out = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(md_path, encoding='utf-8').read()
rows = []
for line in src.splitlines():
    line = line.rstrip()
    if line.startswith('# '):
        rows.append(f'<h1>{H.escape(line[2:])}</h1>')
    elif line.startswith('## '):
        rows.append(f'<h2>{H.escape(line[3:])}</h2>')
    elif line.startswith('|') and line.endswith('|'):
        cells = [c.strip() for c in line.strip('|').split('|')]
        if all(re.fullmatch(r':?-{3,}:?', c) for c in cells):
            continue  # tablo ayraç satırı
        out = []
        for c in cells:
            c = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2" target="_blank" rel="noopener">\1</a>', c)
            out.append(f'<td>{c}</td>')
        rows.append('<tr>' + ''.join(out) + '</tr>')
    elif line.startswith('> '):
        rows.append(f'<blockquote>{H.escape(line[2:])}</blockquote>')
    elif line.startswith('---'):
        rows.append('<hr>')
    elif line.startswith('_') and line.endswith('_'):
        rows.append(f'<p class="foot">{H.escape(line[1:-1])}</p>')
    elif line.strip():
        rows.append(f'<p>{H.escape(line)}</p>')
body = '\n'.join(rows)
page = f'''<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>⭐ My GitHub Manager — Günlük Rapor</title>
<style>
  body {{ background:#0d1117; color:#e6edf3; font-family:'Segoe UI',system-ui,sans-serif; margin:0; padding:32px 20px; }}
  .wrap {{ max-width:860px; margin:0 auto; }}
  h1 {{ font-size:22px; }}
  h2 {{ color:#58a6ff; margin-top:28px; border-bottom:1px solid #30363d; padding-bottom:8px; }}
  table {{ width:100%; border-collapse:collapse; margin:12px 0; font-size:13.5px; }}
  th {{ text-align:left; background:#161b22; color:#8b949e; padding:8px 10px; border-bottom:2px solid #30363d; }}
  td {{ padding:8px 10px; border-bottom:1px solid #21262d; }}
  tr:hover td {{ background:#161b22; }}
  a {{ color:#58a6ff; text-decoration:none; font-weight:600; }}
  a:hover {{ text-decoration:underline; }}
  blockquote {{ border-left:3px solid #3fb950; background:#161b22; padding:10px 14px; border-radius:6px; color:#c9d1d9; }}
  hr {{ border:none; border-top:1px solid #30363d; margin:24px 0; }}
  .foot {{ color:#8b949e; font-size:12px; }}
</style>
</head>
<body><div class="wrap">
{body}
</div></body></html>'''
open(desk_out, 'w', encoding='utf-8').write(page)
open(arsiv_out, 'w', encoding='utf-8').write(page)
print(f"🌐 HTML rapor: {desk_out}")
PYEOF

# ── 5) Masaüstü bildirimi ──
if [ "$TOPLAM" -gt 0 ]; then
  MSG="$TOPLAM yeni repo keşfedildi 🎉 — Rapor: ~/Masaüstü/Github-Raporu.html"
else
  MSG="Yeni repo yok — katalog güncel. Rapor: ~/Masaüstü/Github-Raporu.html"
fi
notify-send "⭐ My GitHub Manager" "$MSG" 2>/dev/null || true

echo "📄 Rapor: $RAPOR"
echo "$MSG"
