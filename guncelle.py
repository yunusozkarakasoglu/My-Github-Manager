#!/usr/bin/env python3
# ⭐ Star Katalog Güncelleyici
# Kullanım: python3 guncelle.py  → GitHub'dan star'ları + kategorileri çeker, index.html üretir
import json, subprocess, datetime, sys, os

def fetch_data():
    """GitHub API'den star'lı repoları + liste üyeliklerini çeker."""
    # 1) Star'lı repolar
    r = subprocess.run(['gh','api','user/starred','--paginate','-q',
      '.[] | {name: .full_name, url: .html_url, desc: (.description // ""), lang: (.language // ""), stars: .stargazers_count, license: (.license.spdx_id // ""), topics: (.topics // []), pushed: (.pushed_at // "")[:10]}'],
      capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(f"Star verisi çekilemedi: {r.stderr[:200]}")
    repos = {}
    for line in r.stdout.split('\n'):
        if line.strip():
            try:
                d = json.loads(line)
                repos[d['name']] = d
            except: pass

    # 2) Liste üyelikleri
    r2 = subprocess.run(['gh','api','graphql','-f',
      'query={ viewer { lists(first: 100) { nodes { name items(first: 100) { nodes { ... on Repository { nameWithOwner } } } } } } }'],
      capture_output=True, text=True)
    if r2.returncode != 0 or '"errors"' in r2.stdout:
        raise SystemExit(f"Liste verisi çekilemedi: {r2.stderr[:200]}")
    lists = json.loads(r2.stdout)['data']['viewer']['lists']['nodes']
    cat_of, list_names = {}, []
    for l in lists:
        if l is None: continue
        list_names.append(l['name'])
        for it in l['items']['nodes']:
            cat_of.setdefault(it['nameWithOwner'], []).append(l['name'])

    final = []
    for name, d in repos.items():
        final.append({'name': name, 'url': d['url'], 'desc': d['desc'], 'lang': d['lang'],
                      'stars': d['stars'], 'license': d['license'], 'topics': d['topics'],
                      'pushed': d['pushed'], 'cats': cat_of.get(name, [])})
    final.sort(key=lambda x: -x['stars'])
    return {'updated': datetime.date.today().isoformat(), 'lists': list_names, 'repos': final}

# ── Veri (yerel önbellek varsa onu kullan, yoksa çek) ──
DATA_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'data.json')
if os.path.exists(DATA_PATH) and '--fetch' not in sys.argv:
    data = json.load(open(DATA_PATH, encoding='utf-8'))
else:
    data = fetch_data()
    json.dump(data, open(DATA_PATH, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

repos, list_names = data['repos'], data['lists']

# ── Etiket üretimi ──
KEYWORD_TAGS = [
    ('ai', 'AI'), ('llm', 'LLM'), ('mcp', 'MCP'), ('agent', 'Ajan'), ('rag', 'RAG'),
    ('docker', 'Docker'), ('self-host', 'Self-host'), ('selfhost', 'Self-host'),
    ('open source', 'Açık Kaynak'), ('open-source', 'Açık Kaynak'),
    ('privacy', 'Gizlilik'), ('dashboard', 'Dashboard'), ('automation', 'Otomasyon'),
    ('cms', 'CMS'), ('erp', 'ERP'), ('crm', 'CRM'), ('ecommerce', 'E-Ticaret'),
    ('pdf', 'PDF'), ('label', 'Etiket'), ('print', 'Baskı'), ('thermal', 'Termal'),
    ('kanban', 'Kanban'), ('note', 'Not'), ('memory', 'Bellek'), ('codebase', 'Codebase'),
    ('graph', 'Graf'), ('react', 'React'), ('typescript', 'TypeScript'), ('python', 'Python'),
    ('rust', 'Rust'), ('go', 'Go'), ('vue', 'Vue'), ('neovim', 'Neovim'), ('vscode', 'VS Code'),
    ('terminal', 'Terminal'), ('cli', 'CLI'), ('tui', 'TUI'), ('extension', 'Eklenti'),
    ('skill', 'Skill'), ('plugin', 'Eklenti'), ('api', 'API'), ('search', 'Arama'),
    ('rss', 'RSS'), ('media', 'Medya'), ('music', 'Müzik'), ('video', 'Video'),
    ('camera', 'Kamera'), ('security', 'Güvenlik'), ('vpn', 'VPN'), ('network', 'Ağ'),
    ('password', 'Şifre'), ('email', 'E-posta'), ('finance', 'Finans'), ('budget', 'Bütçe'),
    ('invoice', 'Fatura'), ('crm', 'CRM'), ('hr', 'İK'), ('invoice', 'Fatura'),
    ('website builder', 'Site Kurucu'), ('webflow', 'Site Kurucu'), ('static site', 'Statik Site'),
    ('headless', 'Headless'), ('database', 'Veritabanı'), ('no-code', 'No-Code'),
    ('low-code', 'Low-Code'), ('workflow', 'İş Akışı'), ('webhook', 'Webhook'),
    ('speedtest', 'Hız Testi'), ('whiteboard', 'Beyaz Tahta'), ('form', 'Form'),
    ('helpdesk', 'Helpdesk'), ('smart home', 'Akıllı Ev'), ('iot', 'IoT'),
]

def gen_tags(repo):
    tags = set()
    blob = (repo['desc'] + ' ' + ' '.join(repo['topics'])).lower()
    for kw, tag in KEYWORD_TAGS:
        if kw in blob:
            tags.add(tag)
    # dil etiketi
    if repo['lang']:
        tags.add(repo['lang'])
    # kategori etiketleri (ayrı tutulacak)
    return sorted(tags)

def gen_features(repo):
    feats = []
    if repo['lang']: feats.append({'t': repo['lang'], 'c': 'lang'})
    feats.append({'t': f"★{repo['stars']:,}", 'c': 'star'})
    if repo['license']: feats.append({'t': repo['license'], 'c': 'lic'})
    for t in repo['topics'][:3]:
        feats.append({'t': t, 'c': 'topic'})
    return feats

# ── HTML ──
def esc(s):
    return (s or '').replace('&','&amp;').replace('<','&lt;').replace('>','&gt;').replace('"','&quot;')

repos_json = json.dumps(repos, ensure_ascii=False).replace('</', '<\\/')

HTML = f"""<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>⭐ Star Kataloğu — yunusozkarakasoglu</title>
<style>
:root {{
  --bg:#0d1117; --panel:#161b22; --panel2:#1c2330; --border:#30363d;
  --text:#e6edf3; --muted:#8b949e; --accent:#58a6ff; --accent2:#3fb950;
  --hover:#21262d; --tag:#1f6feb33; --tagb:#1f6feb;
}}
* {{ box-sizing:border-box; margin:0; padding:0; }}
body {{ background:var(--bg); color:var(--text); font-family:'Segoe UI',system-ui,-apple-system,sans-serif; }}
/* ── Global Header ── */
header {{
  position:sticky; top:0; z-index:50; display:flex; align-items:center; gap:14px;
  padding:12px 20px; background:linear-gradient(135deg,#161b22,#1c2330);
  border-bottom:1px solid var(--border); backdrop-filter:blur(8px);
}}
#menuBtn {{ background:none; border:1px solid var(--border); color:var(--text); font-size:18px;
  width:38px; height:38px; border-radius:8px; cursor:pointer; }}
#menuBtn:hover {{ background:var(--hover); }}
header h1 {{ font-size:19px; font-weight:700; white-space:nowrap; }}
header h1 span {{ color:var(--accent); }}
#headerStats {{ margin-left:auto; font-size:13px; color:var(--muted); text-align:right; }}
#headerStats b {{ color:var(--accent2); font-size:15px; }}

/* ── Layout ── */
#layout {{ display:flex; min-height:calc(100vh - 63px); }}

/* ── Side Panel (sol) ── */
aside {{
  width:280px; min-width:280px; background:var(--panel); border-right:1px solid var(--border);
  overflow-y:auto; max-height:calc(100vh - 63px); position:sticky; top:63px;
  transition:margin .25s ease; padding:12px 0;
}}
aside.closed {{ margin-left:-280px; }}
#sideTitle {{ padding:6px 16px 10px; font-size:12px; text-transform:uppercase; letter-spacing:1px; color:var(--muted); }}
#catList {{ list-style:none; }}
#catList li {{ padding:8px 16px; cursor:pointer; display:flex; justify-content:space-between; align-items:center;
  border-left:3px solid transparent; font-size:14px; }}
#catList li:hover {{ background:var(--hover); }}
#catList li.active {{ background:var(--hover); border-left-color:var(--accent); color:var(--accent); }}
#catList .cnt {{ background:#21262d; color:var(--muted); border-radius:10px; padding:1px 9px; font-size:11px; }}
#catList li.active .cnt {{ background:var(--accent); color:#0d1117; }}

/* ── İçerik ── */
main {{ flex:1; padding:20px; min-width:0; }}
/* Page Header: arama + filtre */
#toolbar {{
  display:flex; flex-wrap:wrap; gap:10px; align-items:center; margin-bottom:16px;
  background:var(--panel); border:1px solid var(--border); border-radius:12px; padding:14px;
}}
#search {{ flex:1 1 260px; background:var(--bg); border:1px solid var(--border); color:var(--text);
  padding:10px 14px; border-radius:8px; font-size:14px; outline:none; }}
#search:focus {{ border-color:var(--accent); }}
select, #minStars {{ background:var(--bg); border:1px solid var(--border); color:var(--text);
  padding:9px 10px; border-radius:8px; font-size:13px; outline:none; }}
#tagFilter {{ min-width:170px; }}
#pageInfo {{ width:100%; font-size:13px; color:var(--muted); }}
#pageInfo b {{ color:var(--accent2); }}
#clearBtn {{ background:none; border:1px solid var(--border); color:var(--accent); border-radius:8px;
  padding:9px 14px; cursor:pointer; font-size:13px; }}
#clearBtn:hover {{ background:var(--hover); }}

/* ── Tablo ── */
.tableWrap {{ overflow-x:auto; border:1px solid var(--border); border-radius:12px; background:var(--panel); }}
table {{ width:100%; border-collapse:collapse; min-width:820px; }}
thead th {{ position:sticky; top:0; background:var(--panel2); text-align:left; font-size:12px;
  text-transform:uppercase; letter-spacing:.6px; color:var(--muted); padding:12px 14px;
  border-bottom:1px solid var(--border); cursor:pointer; user-select:none; }}
thead th:hover {{ color:var(--text); }}
tbody tr {{ border-bottom:1px solid #21262d; transition:background .12s; }}
tbody tr:hover {{ background:var(--hover); }}
td {{ padding:12px 14px; vertical-align:top; font-size:13.5px; }}
td.repo {{ min-width:210px; }}
td.repo a {{ color:var(--accent); font-weight:600; text-decoration:none; font-size:14px; }}
td.repo a:hover {{ text-decoration:underline; }}
td.repo .owner {{ color:var(--muted); font-size:12px; display:block; margin-top:2px; }}
td.repo .push {{ color:var(--muted); font-size:11px; margin-top:4px; }}
td.stars {{ min-width:110px; white-space:nowrap; }}
.starNum {{ font-weight:700; color:#7ee787; font-size:14px; }}
.starBar {{ width:100px; height:4px; background:#21262d; border-radius:2px; margin-top:5px; overflow:hidden; }}
.starFill {{ height:100%; background:linear-gradient(90deg,#1f6feb,#3fb950); border-radius:2px; }}
.th-stars {{ width:110px; }}
td.desc {{ color:#c9d1d9; min-width:240px; max-width:380px; }}
.badges {{ display:flex; flex-wrap:wrap; gap:5px; }}
.badge {{ font-size:11px; padding:2px 8px; border-radius:10px; white-space:nowrap; }}
.badge.lang {{ background:#1f6feb22; color:#79c0ff; border:1px solid #1f6feb55; }}
.badge.star {{ background:#3fb95022; color:#7ee787; border:1px solid #3fb95055; }}
.badge.lic {{ background:#d2992222; color:#e3b341; border:1px solid #d2992255; }}
.badge.topic {{ background:#21262d; color:var(--muted); }}
.tag {{ font-size:11px; padding:2px 8px; border-radius:10px; background:var(--tag); color:#79c0ff;
  border:1px solid var(--tagb); white-space:nowrap; }}
td.tags {{ min-width:170px; }}
.empty {{ padding:40px; text-align:center; color:var(--muted); }}
#updated {{ color:var(--muted); font-size:12px; }}
@media (max-width:900px) {{ aside {{ position:fixed; z-index:60; top:63px; height:calc(100vh - 63px); }} }}
</style>
</head>
<body>
<header>
  <button id="menuBtn" title="Menü">☰</button>
  <h1>⭐ Star <span>Kataloğu</span></h1>
  <div id="headerStats"><b id="totalRepos">{len(repos)}</b> repo · <b id="totalStars">{sum(r['stars'] for r in repos):,}</b> ★<br><span id="updated">{data['updated']}</span></div>
</header>

<div id="layout">
  <aside id="sidebar">
    <div id="sideTitle">Kategoriler</div>
    <ul id="catList"></ul>
  </aside>

  <main>
    <div id="toolbar">
      <input id="search" type="text" placeholder="🔍 Ara: repo adı, açıklama, etiket...">
      <select id="catFilter" style="display:none"></select>
      <select id="langFilter"><option value="">Dil: Tümü</option></select>
      <select id="tagFilter"><option value="">Etiket: Tümü</option></select>
      <select id="sortSel">
        <option value="stars">Sırala: ★ Yıldız</option>
        <option value="name">Sırala: Ad (A-Z)</option>
        <option value="pushed">Sırala: Son Güncelleme</option>
      </select>
      <input id="minStars" type="number" placeholder="Min ★" min="0" style="width:90px">
      <button id="clearBtn">Temizle</button>
      <div id="pageInfo"><b id="shownCount">0</b> / {len(repos)} repo gösteriliyor</div>
    </div>

    <div class="tableWrap">
      <table>
        <thead><tr>
          <th data-sort="name">Repo Adı</th>
          <th data-sort="stars" class="th-stars">★ Yıldız</th>
          <th>Kısa Açıklama</th>
          <th>Özellikler</th>
          <th>Etiketler</th>
        </tr></thead>
        <tbody id="rows"></tbody>
      </table>
    </div>
  </main>
</div>

<script>
const REPOS = {repos_json};
const LISTS = {json.dumps(list_names, ensure_ascii=False)};

// ── State ──
let state = {{ activeCat: 'Tümü', q: '', lang: '', tag: '', sort: 'stars', minStars: 0 }};

// ── Kategori listesi ──
function buildSidebar() {{
  const counts = {{}};
  REPOS.forEach(r => r.cats.forEach(c => counts[c] = (counts[c]||0) + 1));
  const ul = document.getElementById('catList');
  ul.innerHTML = '';
  const add = (name, cnt) => {{
    const li = document.createElement('li');
    li.textContent = name;
    li.dataset.cat = name;
    const span = document.createElement('span');
    span.className = 'cnt'; span.textContent = cnt;
    li.appendChild(span);
    li.onclick = () => setCategory(name);
    ul.appendChild(li);
  }};
  add('Tümü', REPOS.length);
  LISTS.filter(l => l !== 'Hobi & Diğer' || counts[l]).forEach(l => add(l, counts[l]||0));
}}

// ── Filtreler ──
function buildFilters() {{
  const langs = new Set(REPOS.map(r => r.lang).filter(Boolean));
  const tags = new Set();
  REPOS.forEach(r => genTags(r).forEach(t => tags.add(t)));
  const lf = document.getElementById('langFilter');
  [...langs].sort().forEach(l => {{
    const o = document.createElement('option'); o.value = l; o.textContent = l; lf.appendChild(o);
  }});
  const tf = document.getElementById('tagFilter');
  [...tags].sort().forEach(t => {{
    const o = document.createElement('option'); o.value = t; o.textContent = t; tf.appendChild(o);
  }});
}}

// ── Etiket/özellik üretimi (Python'dakiyle aynı mantık) ──
const KW = [
  ['ai','AI'],['llm','LLM'],['mcp','MCP'],['agent','Ajan'],['rag','RAG'],['docker','Docker'],
  ['self-host','Self-host'],['selfhost','Self-host'],['open source','Açık Kaynak'],['open-source','Açık Kaynak'],
  ['privacy','Gizlilik'],['dashboard','Dashboard'],['automation','Otomasyon'],['cms','CMS'],
  ['erp','ERP'],['crm','CRM'],['ecommerce','E-Ticaret'],['pdf','PDF'],['label','Etiket'],
  ['print','Baskı'],['thermal','Termal'],['kanban','Kanban'],['note','Not'],['memory','Bellek'],
  ['codebase','Codebase'],['graph','Graf'],['react','React'],['typescript','TypeScript'],
  ['python','Python'],['rust','Rust'],['go','Go'],['vue','Vue'],['neovim','Neovim'],
  ['vscode','VS Code'],['terminal','Terminal'],['cli','CLI'],['tui','TUI'],['extension','Eklenti'],
  ['skill','Skill'],['plugin','Eklenti'],['api','API'],['search','Arama'],['rss','RSS'],
  ['media','Medya'],['music','Müzik'],['video','Video'],['camera','Kamera'],['security','Güvenlik'],
  ['vpn','VPN'],['network','Ağ'],['password','Şifre'],['email','E-posta'],['finance','Finans'],
  ['budget','Bütçe'],['invoice','Fatura'],['hr','İK'],['website builder','Site Kurucu'],
  ['webflow','Site Kurucu'],['static site','Statik Site'],['headless','Headless'],
  ['database','Veritabanı'],['no-code','No-Code'],['low-code','Low-Code'],['workflow','İş Akışı'],
  ['webhook','Webhook'],['speedtest','Hız Testi'],['whiteboard','Beyaz Tahta'],['form','Form'],
  ['helpdesk','Helpdesk'],['smart home','Akıllı Ev'],['iot','IoT'],
];
function genTags(r) {{
  const blob = (r.desc + ' ' + (r.topics||[]).join(' ')).toLowerCase();
  const tags = new Set();
  KW.forEach(([k,t]) => {{ if (blob.includes(k)) tags.add(t); }});
  if (r.lang) tags.add(r.lang);
  return [...tags];
}}

// ── Filtrele ──
function matches(r) {{
  if (state.activeCat !== 'Tümü' && !r.cats.includes(state.activeCat)) return false;
  if (state.lang && r.lang !== state.lang) return false;
  if (state.minStars && r.stars < state.minStars) return false;
  if (state.tag && !genTags(r).includes(state.tag) && !r.cats.includes(state.tag)) return false;
  if (state.q) {{
    const hay = (r.name + ' ' + r.desc + ' ' + r.lang + ' ' + (r.topics||[]).join(' ') +
      ' ' + genTags(r).join(' ') + ' ' + (r.cats||[]).join(' ')).toLowerCase();
    if (!hay.includes(state.q.toLowerCase())) return false;
  }}
  return true;
}}

function render() {{
  let rows = REPOS.filter(matches);
  const sorters = {{
    stars: (a,b) => b.stars - a.stars,
    name: (a,b) => a.name.localeCompare(b.name),
    pushed: (a,b) => (b.pushed||'').localeCompare(a.pushed||''),
  }};
  rows.sort(sorters[state.sort]);
  const tbody = document.getElementById('rows');
  tbody.innerHTML = '';
  rows.forEach(r => {{
    const feats = [];
    if (r.lang) feats.push(`<span class="badge lang">${{r.lang}}</span>`);
    if (r.license) feats.push(`<span class="badge lic">${{r.license}}</span>`);
    (r.topics||[]).slice(0,3).forEach(t => feats.push(`<span class="badge topic">${{esc(t)}}</span>`));
    const tags = [...genTags(r), ...(r.cats||[])].filter((v,i,a) => a.indexOf(v) === i).slice(0,8);
    const maxStars = Math.max(...REPOS.map(x => x.stars));
    const starW = Math.max(4, Math.round(r.stars / maxStars * 100));
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td class="repo"><a href="${{r.url}}" target="_blank" rel="noopener">${{esc(r.name.split('/')[1])}}</a>
        <span class="owner">${{esc(r.name)}}</span>
        <span class="push">🕒 ${{r.pushed||'—'}}</span></td>
      <td class="stars">
        <div class="starNum">★ ${{r.stars.toLocaleString('tr-TR')}}</div>
        <div class="starBar"><div class="starFill" style="width:${{starW}}%"></div></div>
      </td>
      <td class="desc">${{esc(r.desc)||'—'}}</td>
      <td><div class="badges">${{feats.join('')}}</div></td>
      <td class="tags"><div class="badges">${{tags.map(t=>`<span class="tag">${{esc(t)}}</span>`).join('')||'—'}}</div></td>`;
    tbody.appendChild(tr);
  }});
  if (!rows.length) tbody.innerHTML = '<tr><td colspan="5" class="empty">Sonuç bulunamadı 🔍</td></tr>';
  document.getElementById('shownCount').textContent = rows.length;
}}

function setCategory(cat) {{
  state.activeCat = cat;
  document.querySelectorAll('#catList li').forEach(li => li.classList.toggle('active', li.dataset.cat === cat));
  render();
  if (window.innerWidth < 900) document.getElementById('sidebar').classList.add('closed');
}}

function esc(s) {{ return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }}

// ── Olaylar ──
document.getElementById('menuBtn').onclick = () => document.getElementById('sidebar').classList.toggle('closed');
document.getElementById('search').oninput = e => {{ state.q = e.target.value; render(); }};
document.getElementById('langFilter').onchange = e => {{ state.lang = e.target.value; render(); }};
document.getElementById('tagFilter').onchange = e => {{ state.tag = e.target.value; render(); }};
document.getElementById('sortSel').onchange = e => {{ state.sort = e.target.value; render(); }};
document.getElementById('minStars').oninput = e => {{ state.minStars = +e.target.value || 0; render(); }};
document.getElementById('clearBtn').onclick = () => {{
  state = {{ activeCat: 'Tümü', q: '', lang: '', tag: '', sort: 'stars', minStars: 0 }};
  document.getElementById('search').value = ''; document.getElementById('langFilter').value = '';
  document.getElementById('tagFilter').value = ''; document.getElementById('sortSel').value = 'stars';
  document.getElementById('minStars').value = '';
  setCategory('Tümü');
}};

// ── Başlat ──
buildSidebar(); buildFilters(); setCategory('Tümü');
</script>
</body>
</html>"""

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'index.html')
open(out, 'w', encoding='utf-8').write(HTML)
print(f"✅ index.html üretildi: {os.path.getsize(out):,} bytes ({len(repos)} repo)")
# İndeks dosyalarını da tazele
import subprocess as _sp
_sp.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ara.py'), '--indeks'], check=False)
