#!/usr/bin/env bash
# ⭐ My GitHub Manager — Sabah Raporu
# systemd timer ile her sabah 08:00'de çalışır (bilgisayar kapalıysa açılınca çalışır).
# Yeni repoları son aramadan itibaren tarar, rapor üretir, masaüstü bildirimi gönderir.
# Manuel çalıştırma: ./github_daily_scan.sh
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

# ── 3) Rapor dosyası üret (markdown) ──
RAPOR="$RAPOR_DIR/$TARIH.md"
{
  echo "# ⭐ My GitHub Manager — Sabah Raporu ($TARIH $SAAT)"
  echo
  echo "**Tarama aralığı:** ${ARALIK:-bilinmiyor}"
  echo
  if [ "$TOPLAM" -gt 0 ]; then
    echo "## 🆕 $TOPLAM yeni repo keşfedildi"
    echo
    echo "| Repo | URL | Tarih | Açıklama | ★ | Lisans | Kategori |"
    echo "|---|---|---|---|---|---|---|"
    grep -E '^\| \[' "$LOGFILE"
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

# ── 4) HTML rapor üret (Masaüstü + arşiv) — örnek tasarım, dinamik veri ──
MASAUSTU="$HOME/Masaüstü"
[ -d "$MASAUSTU" ] || MASAUSTU="$HOME/Desktop"
HTML_DESK="$MASAUSTU/Github-Raporu.html"
HTML_ARSIV="$RAPOR_DIR/$TARIH.html"
python3 - "$LOGFILE" "$HTML_DESK" "$HTML_ARSIV" <<'PYEOF'
import sys, re, json, datetime
log_path, desk_out, arsiv_out = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(log_path, encoding='utf-8').read()

# ── Tarama aralığı ──
aralik = ''
m = re.search(r'Tarama aralığı: ([^|\n]+)', src)
if m:
    aralik = m.group(1).strip()

# ── Repoları parse et (tara.py çıktısı) ──
repos = []
for line in src.splitlines():
    if not line.startswith('| ['):
        continue
    parts = [p.strip() for p in line.strip('|').split('|')]
    if len(parts) < 7:
        continue
    mm = re.match(r'\[([^\]]+)\]\(([^)]+)\)', parts[0])
    if not mm:
        continue
    full = mm.group(1)
    owner, _, repo = full.rpartition('/')
    desc = parts[3][:140]
    stars = int(re.sub(r'[^0-9]', '', parts[4]) or 0)
    repos.append({'owner': owner, 'repo': repo, 'url': mm.group(2),
                  'date': parts[2], 'desc': desc, 'stars': stars,
                  'license': parts[5], 'cat': parts[6]})

# ── Kategori anahtarları (filtre için) ──
cats_seen = {}
for r in repos:
    if r['cat'] not in cats_seen:
        cats_seen[r['cat']] = f'k{len(cats_seen)}'
    r['key'] = cats_seen[r['cat']]

# ── İstatistikler ──
total = len(repos)
n_cats = len(cats_seen)
max_repo = max(repos, key=lambda r: r['stars']) if repos else None
lic_counts = {}
for r in repos:
    lic_counts[r['license']] = lic_counts.get(r['license'], 0) + 1
top_lic = max(lic_counts.items(), key=lambda kv: kv[1])[0] if lic_counts else '—'
lic_pct = round(100 * lic_counts[top_lic] / total) if total else 0

# ── Tarih (Türkçe) ──
A = ['Ocak','Şubat','Mart','Nisan','Mayıs','Haziran','Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık']
G = ['Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar']
now = datetime.datetime.now()
tarih_str = f"{now.day} {A[now.month-1]} {now.year}, {G[now.weekday()]}"
saat_str = now.strftime('%H:%M')

data_js = json.dumps(repos, ensure_ascii=False).replace('</', '<\\/')

# ── Ticker mesajları ──
ticks = [f"{total} YENİ REPO KEŞFEDİLDİ"]
if max_repo:
    ticks.append(f"EN ÇOK YILDIZ: {max_repo['repo'].upper()} ★{max_repo['stars']}")
ticks.append(f"{n_cats} KATEGORİ AKTİF")
ticks.append(f"%{lic_pct} {top_lic.upper()} LİSANSLI")
ticker = ''.join(f'<span>{t}</span>' for _ in range(2) for t in ticks)

# ── Filtre chip'leri ──
chips = ['<div class="chip on" data-cat="all">Tümü</div>']
for cat, key in cats_seen.items():
    chips.append(f'<div class="chip" data-cat="{key}">{cat}</div>')
chips_html = ' '.join(chips)

TEMPLATE = r'''<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GitHub Sabah Raporu — __TARIH__</title>
<style>
  :root{
    --paper:#f6f3ec; --paper-deep:#efeade; --ink:#221f1a; --ink-soft:#5c574c;
    --line:#d8d1bf; --moss:#3c5943; --moss-soft:#e4e9df; --amber:#b9793a;
    --serif:'Iowan Old Style','Palatino Linotype','Georgia',serif;
    --mono:'SF Mono','Consolas','Menlo',monospace;
    --sans:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;
  }
  *{box-sizing:border-box;}
  body{margin:0;background:var(--paper-deep);color:var(--ink);font-family:var(--sans);}
  .sheet{max-width:900px;margin:0 auto;background:var(--paper);min-height:100vh;padding:0 0 80px;}
  .masthead{padding:36px 40px 20px;text-align:center;border-bottom:3px double var(--ink);}
  .masthead .kicker{font-family:var(--mono);font-size:11px;letter-spacing:0.15em;text-transform:uppercase;color:var(--amber);margin-bottom:10px;}
  .masthead h1{font-family:var(--serif);font-size:44px;margin:0;letter-spacing:0.01em;font-weight:normal;}
  .masthead h1 em{font-style:italic;color:var(--moss);}
  .masthead .dateline{font-family:var(--mono);font-size:12px;color:var(--ink-soft);margin-top:12px;display:flex;justify-content:center;gap:18px;flex-wrap:wrap;}
  .masthead .dateline span{border-right:1px solid var(--line);padding-right:18px;}
  .masthead .dateline span:last-child{border-right:none;padding-right:0;}
  .ticker{background:var(--ink);color:var(--paper);font-family:var(--mono);font-size:12px;padding:9px 0;overflow:hidden;white-space:nowrap;letter-spacing:0.02em;}
  .ticker-inner{display:inline-block;padding-left:100%;animation:scroll 38s linear infinite;}
  @keyframes scroll{0%{transform:translateX(0);}100%{transform:translateX(-100%);}}
  .ticker-inner span{margin-right:48px;color:var(--amber);}
  .ticker-inner span::before{content:"● ";color:var(--moss);}
  .stats{display:flex;border-bottom:1px solid var(--line);}
  .stat{flex:1;padding:20px 24px;text-align:center;border-right:1px solid var(--line);}
  .stat:last-child{border-right:none;}
  .stat .num{font-family:var(--serif);font-size:30px;color:var(--moss);}
  .stat .lab{font-family:var(--mono);font-size:10px;text-transform:uppercase;letter-spacing:0.08em;color:var(--ink-soft);margin-top:4px;}
  .filters{display:flex;flex-wrap:wrap;gap:8px;padding:24px 40px 4px;}
  .chip{font-family:var(--mono);font-size:11px;padding:6px 12px;border:1px solid var(--line);border-radius:20px;background:var(--paper);color:var(--ink-soft);cursor:pointer;user-select:none;}
  .chip.on{background:var(--moss);border-color:var(--moss);color:#fff;}
  .section{padding:28px 40px 8px;}
  .section-head{display:flex;align-items:baseline;gap:12px;margin-bottom:6px;border-bottom:2px solid var(--ink);padding-bottom:8px;}
  .section-head h2{font-family:var(--serif);font-size:21px;font-weight:normal;margin:0;}
  .section-head .count{font-family:var(--mono);font-size:11px;color:var(--ink-soft);}
  .repo{display:grid;grid-template-columns:1fr 150px;gap:20px;padding:20px 0;border-bottom:1px solid var(--line);}
  .repo:last-child{border-bottom:none;}
  .repo-main .repo-name{font-family:var(--serif);font-size:18px;margin:0 0 6px;}
  .repo-main .repo-name a{color:var(--ink);text-decoration:none;border-bottom:1px solid var(--ink);}
  .repo-main .repo-name a:hover{color:var(--moss);border-color:var(--moss);}
  .repo-main .repo-owner{font-family:var(--mono);font-size:10.5px;color:var(--amber);text-transform:uppercase;letter-spacing:0.04em;margin-bottom:8px;}
  .repo-main .repo-desc{font-size:13.5px;color:var(--ink-soft);line-height:1.55;max-width:56ch;}
  .repo-meta{text-align:right;display:flex;flex-direction:column;align-items:flex-end;gap:8px;padding-top:2px;}
  .starbar{display:flex;align-items:center;gap:6px;font-family:var(--mono);font-size:12px;}
  .starbar .track{width:60px;height:5px;background:var(--moss-soft);border-radius:3px;overflow:hidden;}
  .starbar .fill{height:100%;background:var(--amber);}
  .license-tag{font-family:var(--mono);font-size:10px;color:var(--ink-soft);border:1px solid var(--line);border-radius:3px;padding:2px 6px;}
  .date-tag{font-family:var(--mono);font-size:10px;color:var(--ink-soft);}
  .cmdblock{margin:36px 40px 0;background:var(--ink);color:var(--paper);border-radius:4px;padding:20px 24px;}
  .cmdblock .cmdlabel{font-family:var(--mono);font-size:10px;text-transform:uppercase;letter-spacing:0.08em;color:var(--amber);margin-bottom:10px;}
  .cmdblock code{font-family:var(--mono);font-size:13px;display:block;}
  .cmdblock .cmdnote{font-family:var(--sans);font-size:12px;color:#c9c4b6;margin-top:10px;}
  .empty{padding:40px;text-align:center;color:var(--ink-soft);font-family:var(--serif);font-size:18px;}
  @media (max-width:640px){
    .masthead h1{font-size:32px;}
    .section,.filters,.masthead{padding-left:20px;padding-right:20px;}
    .repo{grid-template-columns:1fr;}
    .repo-meta{flex-direction:row;align-items:center;justify-content:flex-start;gap:14px;}
    .stats{flex-wrap:wrap;}
    .stat{flex:1 1 50%;border-bottom:1px solid var(--line);}
  }
</style>
</head>
<body>
<div class="sheet">

  <div class="masthead">
    <div class="kicker">⭐ My GitHub Manager · Otomatik Tarama</div>
    <h1>Sabah <em>Raporu</em></h1>
    <div class="dateline">
      <span>__TARIH__</span>
      <span>__SAAT__</span>
      <span>Tarama aralığı: __ARALIK__</span>
    </div>
  </div>

  <div class="ticker"><div class="ticker-inner">__TICKER__</div></div>

  <div class="stats">
    <div class="stat"><div class="num">__TOTAL__</div><div class="lab">Yeni Repo</div></div>
    <div class="stat"><div class="num">__NCATS__</div><div class="lab">Kategori</div></div>
    <div class="stat"><div class="num">__TOTAL__</div><div class="lab">Listelenen</div></div>
    <div class="stat"><div class="num">__LICPCT__</div><div class="lab">__LICLAB__</div></div>
  </div>

  <div class="filters" id="filters">__CHIPS__</div>

  <div id="sections"></div>

  <div class="cmdblock">
    <div class="cmdlabel">Kataloğa eklemek için</div>
    <code>cd ~/Github-My-Katalog &amp;&amp; python3 tara.py</code>
    <div class="cmdnote">Komut listeyi sunar, onayınla ekler.</div>
  </div>

</div>

<script>
const data = __DATA__;
const maxStars = Math.max(...data.map(d=>d.stars), 1);

function esc(s){return String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}

function repoRow(d){
  const pct = Math.max(6, Math.round((d.stars/maxStars)*100));
  return `
  <div class="repo" data-cat="${d.key}">
    <div class="repo-main">
      <div class="repo-owner">${esc(d.owner)}</div>
      <div class="repo-name"><a href="${d.url}" target="_blank" rel="noopener">${esc(d.repo)}</a></div>
      <div class="repo-desc">${esc(d.desc)}</div>
    </div>
    <div class="repo-meta">
      <div class="starbar"><span>★ ${d.stars}</span>
        <div class="track"><div class="fill" style="width:${pct}%"></div></div>
      </div>
      <div class="license-tag">${esc(d.license)}</div>
      <div class="date-tag">${esc(d.date)}</div>
    </div>
  </div>`;
}

function render(filter){
  const cats = [...new Set(data.map(d=>d.key))];
  const container = document.getElementById('sections');
  if(!data.length){ container.innerHTML = '<div class="empty">Yeni repo bulunamadı — katalog güncel. 🍃</div>'; return; }
  container.innerHTML = cats.map(key=>{
    const items = data.filter(d=>d.key===key);
    if(filter!=='all' && filter!==key) return '';
    const label = items[0].cat;
    return `
    <div class="section">
      <div class="section-head"><h2>${esc(label)}</h2><span class="count">${items.length} repo</span></div>
      ${items.map(repoRow).join('')}
    </div>`;
  }).join('');
}

render('all');

document.getElementById('filters').addEventListener('click',(e)=>{
  const chip = e.target.closest('.chip');
  if(!chip) return;
  document.querySelectorAll('.chip').forEach(c=>c.classList.remove('on'));
  chip.classList.add('on');
  render(chip.dataset.cat);
});
</script>
</body>
</html>'''

page = (TEMPLATE
    .replace('__TARIH__', tarih_str).replace('__SAAT__', saat_str)
    .replace('__ARALIK__', aralik).replace('__TICKER__', ticker)
    .replace('__TOTAL__', str(total)).replace('__NCATS__', str(n_cats))
    .replace('__LICPCT__', f'%{lic_pct}').replace('__LICLAB__', f'{top_lic.upper()} Lisans')
    .replace('__CHIPS__', chips_html).replace('__DATA__', data_js))
open(desk_out, 'w', encoding='utf-8').write(page)
open(arsiv_out, 'w', encoding='utf-8').write(page)
print(f"🌐 HTML rapor: {desk_out} ({total} repo)")
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
