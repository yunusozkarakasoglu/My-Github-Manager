#!/usr/bin/env python3
# ⭐ Hızlı Repo Arama / İndeks Aracı
# Kullanım:
#   python3 ara.py --indeks                  # indeks dosyalarını (yeniden) üret
#   python3 ara.py "pdf"                     # anahtar kelime ara (ad, açıklama, etiket, kategori)
#   python3 ara.py "pdf üretim"              # çok kelimeli arama (hepsi eşleşmeli)
#   python3 ara.py "rag" --kategori "Bellek" # kategori filtresiyle
#   python3 ara.py "crm" --lang python       # dil filtresiyle
#   python3 ara.py "erp" --min 1000          # min ★ ile
#   python3 ara.py --liste                   # tüm kategorileri + sayıları listeler
#
# Veri kaynağı: data.json (guncelle.py üretir) + repo-indeksi.txt (grep dostu)

import json, os, sys, argparse, re

BASE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(BASE, 'data.json')

# ── Etiket/özellik anahtar kelimeleri (tara.py ile aynı mantık) ──
KEYWORD_TAGS = [
    ('ai','AI'),('llm','LLM'),('mcp','MCP'),('agent','Ajan'),('rag','RAG'),('docker','Docker'),
    ('self-host','Self-host'),('selfhost','Self-host'),('open source','Açık Kaynak'),('open-source','Açık Kaynak'),
    ('privacy','Gizlilik'),('dashboard','Dashboard'),('automation','Otomasyon'),('cms','CMS'),
    ('erp','ERP'),('crm','CRM'),('ecommerce','E-Ticaret'),('pdf','PDF'),('label','Etiket'),
    ('print','Baskı'),('thermal','Termal'),('kanban','Kanban'),('note','Not'),('memory','Bellek'),
    ('codebase','Codebase'),('graph','Graf'),('react','React'),('typescript','TypeScript'),
    ('python','Python'),('rust','Rust'),('go','Go'),('vue','Vue'),('neovim','Neovim'),
    ('vscode','VS Code'),('terminal','Terminal'),('cli','CLI'),('tui','TUI'),('extension','Eklenti'),
    ('skill','Skill'),('plugin','Eklenti'),('api','API'),('search','Arama'),('rss','RSS'),
    ('media','Medya'),('music','Müzik'),('video','Video'),('camera','Kamera'),('security','Güvenlik'),
    ('vpn','VPN'),('network','Ağ'),('password','Şifre'),('email','E-posta'),('finance','Finans'),
    ('budget','Bütçe'),('invoice','Fatura'),('hr','İK'),('website builder','Site Kurucu'),
    ('webflow','Site Kurucu'),('static site','Statik Site'),('headless','Headless'),
    ('database','Veritabanı'),('no-code','No-Code'),('low-code','Low-Code'),('workflow','İş Akışı'),
    ('webhook','Webhook'),('speedtest','Hız Testi'),('whiteboard','Beyaz Tahta'),('form','Form'),
    ('helpdesk','Helpdesk'),('smart home','Akıllı Ev'),('iot','IoT'),
    ('ocr','OCR'),('translation','Çeviri'),('e-book','E-Kitap'),('comic','Çizgi Roman'),
    ('voice','Ses'),('speech','Konuşma'),('image','Görsel'),('video','Video'),
    ('invoice','Fatura'),('accounting','Muhasebe'),('warehouse','Depo'),('pos','POS'),
    ('calendar','Takvim'),('mail','E-posta'),('chat','Sohbet'),('billing','Faturalama'),
]

def gen_tags(repo):
    tags = set()
    blob = ((repo.get('desc') or '') + ' ' + ' '.join(repo.get('topics') or [])).lower()
    for kw, tag in KEYWORD_TAGS:
        if kw in blob:
            tags.add(tag)
    if repo.get('lang'):
        tags.add(repo['lang'])
    return sorted(tags)

def load_data():
    if not os.path.exists(DATA):
        print("❌ data.json yok — önce çalıştır: python3 guncelle.py --fetch")
        sys.exit(1)
    return json.load(open(DATA, encoding='utf-8'))

def search(kw, kateg=None, lang=None, min_stars=0):
    data = load_data()
    terms = [t.lower() for t in kw.split() if t.strip()]
    out = []
    for r in data['repos']:
        if kateg and not any(kateg.lower() in c.lower() for c in (r.get('cats') or [])):
            continue
        if lang and r.get('lang','').lower() != lang.lower():
            continue
        if min_stars and r.get('stars',0) < min_stars:
            continue
        tags = r.get('tags') or gen_tags(r)
        hay = ' '.join([r['name'], r.get('desc',''), r.get('lang',''),
                        ' '.join(r.get('topics') or []), ' '.join(tags),
                        ' '.join(r.get('cats') or [])]).lower()
        if all(t in hay for t in terms):
            out.append((r, tags))
    out.sort(key=lambda x: -x[0]['stars'])
    return out

def main():
    p = argparse.ArgumentParser(description='⭐ Hızlı repo arama')
    p.add_argument('kelime', nargs='?', help='Aranacak anahtar kelime(ler)')
    p.add_argument('--kategori', help='Kategori filtresi')
    p.add_argument('--lang', help='Dil filtresi')
    p.add_argument('--min', type=int, default=0, help='Min ★')
    p.add_argument('--liste', action='store_true', help='Kategorileri listele')
    args = p.parse_args()

    if args.liste:
        data = load_data()
        counts = {}
        for r in data['repos']:
            for c in (r.get('cats') or []):
                counts[c] = counts.get(c, 0) + 1
        print(f"📂 {len(data['repos'])} repo · {len(counts)} kategori\n")
        for c, n in sorted(counts.items(), key=lambda x: -x[1]):
            print(f"  {c}: {n}")
        return

    if not args.kelime:
        print("Kullanım: python3 ara.py \"pdf\" | python3 ara.py --liste")
        sys.exit(1)

    res = search(args.kelime, args.kategori, args.lang, args.min)
    print(f"🔍 \"{args.kelime}\"{' · kategori: ' + args.kategori if args.kategori else ''}{' · dil: ' + args.lang if args.lang else ''}{' · min★' + str(args.min) if args.min else ''} → {len(res)} sonuç\n")
    for r, tags in res[:40]:
        cats = ';'.join(r.get('cats') or []) or '—'
        print(f"  ★{r['stars']:<8} {r['name']:<45} [{cats}]")
        print(f"      {(r.get('desc') or '—')[:100]}")
        print(f"      🏷️ {', '.join(tags[:8]) or '—'} · {r.get('url','')}\n")

if __name__ == '__main__':
    main()
