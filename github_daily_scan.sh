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

# ── 4) HTML rapor üret (Masaüstü + arşiv) — örnek tasarım + Benim Seçimlerim sekmesi ──
MASAUSTU="$HOME/Masaüstü"
[ -d "$MASAUSTU" ] || MASAUSTU="$HOME/Desktop"
HTML_DESK="$MASAUSTU/Github-Raporu.html"
HTML_ARSIV="$RAPOR_DIR/$TARIH.html"
python3 - "$LOGFILE" "$HTML_DESK" "$HTML_ARSIV" <<'PYEOF'
import sys, re, json, datetime, os, subprocess
log_path, desk_out, arsiv_out = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(log_path, encoding='utf-8').read()

# ── Tarama aralığı ──
aralik = ''
m = re.search(r'Tarama aralığı: ([^|\n]+)', src)
if m:
    aralik = m.group(1).strip()

# ── Asistan seçim profili: kural → "neden seçildi" (sadece YÜKSEK değer kurallar) ──
# Genel/gevşek kuralar (pdf, memory, network...) seçim üretmez — "öne çıkan" seçkin olmalı.
PICK_RULES = [
    ('mcp', 'MCP tabanlı — AI araç ekosistemiyle doğrudan entegre olur'),
    ('pi coding', 'Pi ekosistemi — kendi araç zincirimizle örtüşüyor'),
    (' pi ', 'Pi ekosistemi — kendi araç zincirimizle örtüşüyor'),
    ('ocr', 'Belge işleme — offline/gizlilik değeri yüksek'),
    ('scanned', 'Belge işleme — offline/gizlilik değeri yüksek'),
    ('codebase', 'Kod istihbaratı — proje analizimizde kullanılabilir'),
    ('knowledge graph', 'Kod istihbaratı — proje analizimizde kullanılabilir'),
    ('indexer', 'Kod istihbaratı — proje analizimizde kullanılabilir'),
    ('kanban', 'Proje yönetimi — iş akışımıza uygun'),
    ('task board', 'Proje yönetimi — iş akışımıza uygun'),
    ('ui/ux', 'Tasarım kalitesi — profesyonel bakış'),
    ('design skill', 'Tasarım kalitesi — profesyonel bakış'),
    ('component library', 'UI kütüphanesi — tasarım sistemimize katkı'),
    ('harness', 'Agent altyapısı — profesyonel kurulum felsefesi'),
]
MAX_PICKS = 10  # "öne çıkan" seçkisi — tarama başına en fazla bu kadar

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
    # Asistan seçimi: kural eşleşmesi → picked + reason (sınırlı)
    picked, reason = False, ''
    blob = (desc + ' ' + repo + ' ' + owner).lower()
    for kw, why in PICK_RULES:
        if kw in blob:
            picked, reason = True, why
            break
    repos.append({'id': f'r{len(repos)+1}', 'owner': owner, 'repo': repo,
                  'url': mm.group(2), 'date': parts[2], 'desc': desc,
                  'stars': stars, 'license': parts[5], 'cat': parts[6],
                  'picked': picked, 'reason': reason})

# ── Yerel çeviri (NLLB via CTranslate2): Türkçe açıklama + İngilizce orijinal ──
_desc_list = list(dict.fromkeys(r['desc'] for r in repos if r['desc']))
_ceviriler = {}
if _desc_list:
    _g = os.path.expanduser('~/Github-Raporlari/.ceviri-giris.json')
    _c = os.path.expanduser('~/Github-Raporlari/.ceviri-cikti.json')
    json.dump({'metinler': _desc_list}, open(_g, 'w', encoding='utf-8'), ensure_ascii=False)
    _rr = subprocess.run([os.path.expanduser('~/.ct2-env/bin/python'),
                          '/home/yunus/Github-My-Katalog/ceviri.py', _g, _c],
                         capture_output=True, text=True, timeout=1800)
    try:
        _ceviriler = json.load(open(_c, encoding='utf-8'))['ceviriler']
    except Exception:
        _ceviriler = {}
for _r2 in repos:
    _tr = _ceviriler.get(_r2['desc'])
    if _tr and _tr != _r2['desc']:
        _r2['desc_tr'] = _tr
        _r2['desc_en'] = _r2['desc']
    else:
        _r2['desc_tr'] = _r2['desc']
        _r2['desc_en'] = ''

# ── Asistan seçimi: en fazla MAX_PICKS (yüksek ★ öncelikli) ──
_plist = [r for r in repos if r['picked']]
if len(_plist) > MAX_PICKS:
    for r in sorted(_plist, key=lambda x: -x['stars'])[MAX_PICKS:]:
        r['picked'], r['reason'] = False, ''

# ── Kategori anahtarları (filtre için) ──
cats_seen = {}
for r in repos:
    if r['cat'] not in cats_seen:
        cats_seen[r['cat']] = f'k{len(cats_seen)}'
    r['key'] = cats_seen[r['cat']]

# ── İstatistikler ──
total = len(repos)
n_cats = len(cats_seen)
n_picks = sum(1 for r in repos if r['picked'])
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

# ── 📈 Trend: katalogdaki yıldız artışı (data.json vs önceki yedek) ──
trend = []
_data_yeni = '/home/yunus/Github-My-Katalog/data.json'
_data_eski = os.path.expanduser('~/Github-Raporlari/.data-onceki.json')
if os.path.exists(_data_yeni) and os.path.exists(_data_eski):
    try:
        _y = {r['name']: r for r in json.load(open(_data_yeni, encoding='utf-8'))['repos']}
        _e = {r['name']: r['stars'] for r in json.load(open(_data_eski, encoding='utf-8'))['repos']}
        for _n, _r in _y.items():
            if _n in _e:
                _f = _r['stars'] - _e[_n]
                if _f >= 50:
                    trend.append({'name': _n, 'url': _r['url'], 'eski': _e[_n], 'yeni': _r['stars'], 'fark': _f})
        trend.sort(key=lambda x: -x['fark'])
        trend = trend[:8]
    except Exception:
        trend = []
trend_js = json.dumps(trend, ensure_ascii=False).replace('</', '<\\/')

# ── Ticker mesajları ──
ticks = [f"{total} YENİ REPO KEŞFEDİLDİ"]
if max_repo:
    ticks.append(f"EN ÇOK YILDIZ: {max_repo['repo'].upper()} ★{max_repo['stars']}")
ticks.append(f"{n_cats} KATEGORİ AKTİF")
ticks.append(f"{n_picks} ASİSTAN SEÇİMİ")
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
  /* ── TABLAR ── */
  .tabs{display:flex;padding:20px 40px 0;gap:2px;border-bottom:1px solid var(--line);}
  .tab{font-family:var(--serif);font-size:15px;padding:10px 20px 12px;cursor:pointer;color:var(--ink-soft);border-bottom:3px solid transparent;display:flex;align-items:center;gap:8px;}
  .tab.on{color:var(--ink);border-bottom-color:var(--moss);}
  .tab .tab-count{font-family:var(--mono);font-size:10px;background:var(--moss-soft);color:var(--moss);padding:2px 7px;border-radius:10px;}
  .tab.on .tab-count{background:var(--moss);color:#fff;}
  /* ── SEÇİM BUTONU ── */
  .pick-btn{border:1px solid var(--line);background:var(--paper);color:var(--ink-soft);font-family:var(--mono);font-size:11px;padding:5px 10px;border-radius:3px;cursor:pointer;align-self:flex-end;}
  .pick-btn::before{content:"☆ ";}
  .pick-btn.picked{background:var(--amber);border-color:var(--amber);color:#fff;}
  .pick-btn.picked::before{content:"★ ";}
  /* ── NEDEN SEÇİLDİ ── */
  .repo-reason{margin-top:10px;padding:10px 12px;background:var(--moss-soft);border-left:3px solid var(--moss);border-radius:0 3px 3px 0;font-size:12.5px;color:var(--ink);line-height:1.5;}
  .repo-reason .reason-tag{display:block;font-family:var(--mono);font-size:9.5px;text-transform:uppercase;letter-spacing:0.06em;color:var(--moss);margin-bottom:4px;}
  /* ── BOŞ SEÇİM ── */
  .empty-picks{padding:60px 40px;text-align:center;color:var(--ink-soft);}
  .empty-picks .big{font-family:var(--serif);font-size:20px;color:var(--ink);margin-bottom:8px;}
  .empty-picks .small{font-family:var(--sans);font-size:13px;}
  /* ── FİLTRELER ── */
  .filters{display:flex;flex-wrap:wrap;gap:8px;padding:24px 40px 4px;}
  .filters.hidden{display:none;}
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
  .repo-num{font-family:var(--mono);font-size:10px;color:var(--moss);border:1px solid var(--line);background:var(--paper-deep);border-radius:3px;padding:1px 6px;margin-right:6px;letter-spacing:0;}
  .repo-main .repo-desc{font-size:13.5px;color:var(--ink-soft);line-height:1.55;max-width:56ch;}
  .repo-desc-en{margin-top:4px;font-size:11px;font-style:italic;color:var(--ink-soft);opacity:.75;line-height:1.4;max-width:56ch;}
  .repo-meta{text-align:right;display:flex;flex-direction:column;align-items:flex-end;gap:8px;padding-top:2px;}
  .starbar{display:flex;align-items:center;gap:6px;font-family:var(--mono);font-size:12px;}
  .starbar .track{width:60px;height:5px;background:var(--moss-soft);border-radius:3px;overflow:hidden;}
  .starbar .fill{height:100%;background:var(--amber);}
  .license-tag{font-family:var(--mono);font-size:10px;color:var(--ink-soft);border:1px solid var(--line);border-radius:3px;padding:2px 6px;}
  .date-tag{font-family:var(--mono);font-size:10px;color:var(--ink-soft);}
  .trend-item{display:flex;align-items:baseline;gap:10px;padding:10px 0;border-bottom:1px solid var(--line);font-size:13px;flex-wrap:wrap;}
  .trend-item:last-child{border-bottom:none;}
  .trend-item a{color:var(--ink);text-decoration:none;border-bottom:1px solid var(--ink);font-family:var(--serif);font-size:15px;}
  .trend-item a:hover{color:var(--moss);border-color:var(--moss);}
  .trend-old{font-family:var(--mono);font-size:11px;color:var(--ink-soft);}
  .trend-arrow{color:var(--amber);}
  .trend-new{font-family:var(--mono);font-size:12px;font-weight:bold;}
  .trend-up{font-family:var(--mono);font-size:11px;color:var(--moss);background:var(--moss-soft);padding:1px 8px;border-radius:10px;}
  .cmdblock{margin:36px 40px 0;background:var(--ink);color:var(--paper);border-radius:4px;padding:20px 24px;}
  .cmdblock .cmdlabel{font-family:var(--mono);font-size:10px;text-transform:uppercase;letter-spacing:0.08em;color:var(--amber);margin-bottom:10px;}
  .cmdblock code{font-family:var(--mono);font-size:13px;display:block;}
  .cmdblock .cmdnote{font-family:var(--sans);font-size:12px;color:#c9c4b6;margin-top:10px;}
  @media (max-width:640px){
    .masthead h1{font-size:32px;}
    .section,.filters,.masthead,.tabs{padding-left:20px;padding-right:20px;}
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
    <div class="stat"><div class="num">__PICKS__</div><div class="lab">Asistan Seçimi</div></div>
    <div class="stat"><div class="num">__LICPCT__</div><div class="lab">__LICLAB__</div></div>
  </div>

  <div class="tabs" id="tabs">
    <div class="tab on" data-tab="all">Tüm Repolar <span class="tab-count" id="countAll">__TOTAL__</span></div>
    <div class="tab" data-tab="picks">Benim Seçimlerim <span class="tab-count" id="countPicks">__PICKS__</span></div>
  </div>

  <div class="trend" id="trendBox" style="display:none">
    <div class="section" style="padding-top:20px">
      <div class="section-head"><h2>🔥 Bu Hafta Patlayanlar</h2><span class="count">★ artışı (katalogdaki repolar)</span></div>
      <div id="trendList"></div>
    </div>
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
const trendData = __TREND__;
if(trendData.length){
  document.getElementById('trendBox').style.display = '';
  document.getElementById('trendList').innerHTML = trendData.map(t=>`
    <div class="trend-item">
      <a href="${t.url}" target="_blank" rel="noopener">${esc(t.name)}</a>
      <span class="trend-old">★${t.eski.toLocaleString('tr-TR')}</span>
      <span class="trend-arrow">→</span>
      <span class="trend-new">★${t.yeni.toLocaleString('tr-TR')}</span>
      <span class="trend-up">+${t.fark.toLocaleString('tr-TR')} ★</span>
    </div>`).join('');
}
const maxStars = Math.max(...data.map(d=>d.stars), 1);
const picks = new Set(data.filter(d=>d.picked).map(d=>d.id));
const reasons = {};
data.forEach(d=>{ if(d.reason) reasons[d.id]=d.reason; });

function esc(s){return String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}

function repoRow(d, showReason){
  const pct = Math.max(6, Math.round((d.stars/maxStars)*100));
  const isPicked = picks.has(d.id);
  const num = String(parseInt((d.id||'').slice(1))||0).padStart(2,'0');
  const reasonHtml = (showReason && reasons[d.id]) ? `<div class="repo-reason"><span class="reason-tag">Neden seçildi</span>${esc(reasons[d.id])}</div>` : '';
  const descHtml = d.desc_en
    ? `<div class="repo-desc">${esc(d.desc_tr)}</div><div class="repo-desc-en">${esc(d.desc_en)}</div>`
    : `<div class="repo-desc">${esc(d.desc_tr)}</div>`;
  return `
  <div class="repo" data-cat="${d.key}">
    <div class="repo-main">
      <div class="repo-owner"><span class="repo-num">${num}</span>${esc(d.owner)}</div>
      <div class="repo-name"><a href="${d.url}" target="_blank" rel="noopener">${esc(d.repo)}</a></div>
      ${descHtml}
      ${reasonHtml}
    </div>
    <div class="repo-meta">
      <div class="starbar"><span>★ ${d.stars}</span>
        <div class="track"><div class="fill" style="width:${pct}%"></div></div>
      </div>
      <div class="license-tag">${esc(d.license)}</div>
      <div class="date-tag">${esc(d.date)}</div>
      <button class="pick-btn${isPicked?' picked':''}" data-id="${d.id}">${isPicked?'Seçildi':'Seç'}</button>
    </div>
  </div>`;
}

let activeTab = 'all';
let activeCat = 'all';

function updateCounts(){
  document.getElementById('countAll').textContent = data.length;
  document.getElementById('countPicks').textContent = picks.size;
}

function render(){
  const container = document.getElementById('sections');
  updateCounts();

  if(activeTab === 'picks'){
    const items = data.filter(d=>picks.has(d.id));
    if(items.length===0){
      container.innerHTML = `
      <div class="empty-picks">
        <div class="big">Henüz seçim yapılmadı</div>
        <div class="small">Bir repoyu seçmek için "Tüm Repolar" sekmesinde ☆ Seç butonuna basın, ya da asistanın seçimlerini bekleyin.</div>
      </div>`;
      return;
    }
    container.innerHTML = `
    <div class="section">
      <div class="section-head"><h2>Benim Seçimlerim</h2><span class="count">${items.length} repo</span></div>
      ${items.map(d=>repoRow(d,true)).join('')}
    </div>`;
    return;
  }

  const cats = [...new Set(data.map(d=>d.key))];
  if(!data.length){ container.innerHTML = '<div class="empty-picks"><div class="big">Yeni repo bulunamadı</div><div class="small">Katalog güncel — tarama aralığında ilgi alanlarına uygun repo yok. 🍃</div></div>'; return; }
  container.innerHTML = cats.map(key=>{
    const items = data.filter(d=>d.key===key);
    if(activeCat!=='all' && activeCat!==key) return '';
    const label = items[0].cat;
    return `
    <div class="section">
      <div class="section-head"><h2>${esc(label)}</h2><span class="count">${items.length} repo</span></div>
      ${items.map(d=>repoRow(d,false)).join('')}
    </div>`;
  }).join('');
}

render();

document.getElementById('tabs').addEventListener('click',(e)=>{
  const tab = e.target.closest('.tab');
  if(!tab) return;
  document.querySelectorAll('.tab').forEach(t=>t.classList.remove('on'));
  tab.classList.add('on');
  activeTab = tab.dataset.tab;
  document.getElementById('filters').classList.toggle('hidden', activeTab==='picks');
  render();
});

document.getElementById('filters').addEventListener('click',(e)=>{
  const chip = e.target.closest('.chip');
  if(!chip) return;
  document.querySelectorAll('.chip').forEach(c=>c.classList.remove('on'));
  chip.classList.add('on');
  activeCat = chip.dataset.cat;
  render();
});

document.getElementById('sections').addEventListener('click',(e)=>{
  const btn = e.target.closest('.pick-btn');
  if(!btn) return;
  const id = btn.dataset.id;
  if(picks.has(id)) picks.delete(id); else picks.add(id);
  render();
});
</script>
</body>
</html>'''

page = (TEMPLATE
    .replace('__TARIH__', tarih_str).replace('__SAAT__', saat_str)
    .replace('__ARALIK__', aralik).replace('__TICKER__', ticker)
    .replace('__TOTAL__', str(total)).replace('__NCATS__', str(n_cats))
    .replace('__PICKS__', str(n_picks))
    .replace('__LICPCT__', f'%{lic_pct}').replace('__LICLAB__', f'{top_lic.upper()} Lisans')
    .replace('__CHIPS__', chips_html).replace('__DATA__', data_js).replace('__TREND__', trend_js))
open(desk_out, 'w', encoding='utf-8').write(page)
open(arsiv_out, 'w', encoding='utf-8').write(page)
print(f"🌐 HTML rapor: {desk_out} ({total} repo, {n_picks} asistan seçimi)")
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
