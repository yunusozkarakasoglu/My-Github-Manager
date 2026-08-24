#!/usr/bin/env python3
# ⭐ Yeni Repo Tarama
# Kullanım:
#   python3 tara.py --gun 30                  # son 30 günde oluşturulan ilgili repolar
#   python3 tara.py --since 2026-08-01        # belirli tarihten itibaren
#   python3 tara.py --since X --until Y       # tarih aralığı
#   python3 tara.py --gun 14 --min-stars 50   # yıldız eşiği ile
#   python3 tara.py --gun 30 --kategori "AI"  # yalnızca belirli kategori
#   python3 tara.py --gun 30 --kaydet         # sonucu tarama.md olarak kaydet
#
# Çıktı sütunları: Repo Adı | URL | Tarih (eklenme) | Özellikler (ne yapar)

import argparse, json, subprocess, datetime, sys, os, urllib.parse

# ── Kategori → arama anahtar kelimeleri (TR + EN) ──
QUERIES = {
  "🧩 Pi Coding Agent Ekosistemi": ["pi coding agent extension","pi coding agent skill","pi coding agent plugin","pi agent","pi extension"],
  "🤖 AI Ajanları & Kodlama Asistan": ["ai coding agent","coding assistant","ai agent framework","yapay zeka kodlama"],
  "🧠 AI Bellek & Bağlam Motorları": ["llm memory","ai agent memory","context compression","rag memory"],
  "🤖 AI IDE Arayüz": ["ai ide","coding agent ui","ai chat interface self hosted"],
  "🔍 Kod İstihbaratı & Knowledge G": ["code knowledge graph","codebase analysis","code search engine","kod analizi"],
  "🖥️ Geliştirici Altyapısı & Back": ["self hosted backend","developer tools","api server open source"],
  "📝 Doküman, Ofis & PDF": ["pdf toolkit open source","office editor self hosted","document generator"],
  "📊 Proje Yönetimi & Çalışma Alan": ["project management self hosted","kanban open source","proje yönetimi"],
  "🏢 ERP & İşletme Yazılımları": ["erp open source","accounting erp","muhasebe programı"],
  "🎨 UI Kütüphaneleri & Tasarım": ["react component library","ui kit open source","arayüz kütüphanesi"],
  "🖨️ Etiket & Baskı Sistemleri": ["label printer","thermal printer","barcode label","etiket yazıcı"],
  "📚 Kaynak & Awesome Listeler": ["awesome self hosted","awesome developer tools","kaynak liste"],
  "🗂️ Dosya & Belge Yönetimi": ["document management system","ocr documents","belge arşiv"],
  "💰 Finans & Bütçe": ["personal finance self hosted","budget app open source","expense tracker","bütçe takip"],
  "📝 Not Alma & Bilgi Yönetimi": ["note taking self hosted","knowledge base open source","not alma"],
  "🗄️ Veritabanı & CMS": ["headless cms","no code database","cms self hosted","veritabanı"],
  "🌐 Web Sitesi Oluşturucu": ["website builder","static site cms","webflow alternative","web site oluşturucu"],
  "📧 İletişim & E-posta": ["self hosted email","helpdesk open source","e posta sunucu"],
  "🎬 Medya & Eğlence": ["media server","music server self hosted","e-book server","medya sunucusu"],
  "🏠 Akıllı Ev & IoT": ["home automation","smart home open source","iot dashboard","akıllı ev"],
  "🔒 Güvenlik & Ağ": ["password manager self hosted","network monitoring","vpn self hosted","ağ izleme"],
  "🤖 Otomasyon & Geliştirme": ["workflow automation","cron job manager","webhook","otomasyon"],
  "🛒 E-Ticaret": ["ecommerce open source","shop platform self hosted","e ticaret"],
  "📋 Proje & Görev Yönetimi": ["task management self hosted","habit tracker open source","görev yönetimi"],
  "🧑‍💼 İK & CRM": ["crm open source","hr management open source","recruiting","insan kaynakları"],
  "🔍 Arama & RSS": ["metasearch engine","rss reader self hosted","arama motoru"],
  "📹 Güvenlik Kamerası": ["camera nvr open source","ip camera detection","güvenlik kamerası"],
  "🧪 Diğer Araçlar": ["whiteboard collaborative","form builder open source","speedtest self hosted","beyaz tahta"],
  "🔌 Ücretsiz API'ler & Kütüphaneler": ["free api","public apis","free api collection","ücretsiz api"],
}

GOOD_LICENSES = {'MIT','Apache-2.0','GPL-3.0','GPL-2.0','AGPL-3.0','LGPL-3.0','LGPL-2.1','MPL-2.0','BSD-3-Clause','BSD-2-Clause','ISC','EPL-2.0','EPL-1.0','Unlicense','0BSD','CC0-1.0','Zlib','BSL-1.0'}

def gh_api(path, retries=3):
    for attempt in range(retries):
        try:
            r = subprocess.run(['gh','api',path], capture_output=True, text=True, timeout=60)
        except subprocess.TimeoutExpired:
            if attempt < retries - 1:
                import time; time.sleep(4); continue
            return None
        if r.returncode == 0:
            try: return json.loads(r.stdout)
            except: return None
        # 403 rate-limit → bekle ve tekrar dene
        if '403' in r.stderr or 'rate limit' in (r.stdout + r.stderr).lower():
            if attempt < retries - 1:
                import time; time.sleep(10); continue
        return None
    return None

def starred_set():
    r = subprocess.run(['gh','api','user/starred','--paginate','-q','.[].full_name'], capture_output=True, text=True)
    return set(r.stdout.split())

def search(q, created_q, per_page=12):
    # URL-encode: boşluk, >=, : karakterleri düzgün kodlanmalı (yoksa gh api asılı kalır)
    query = f'{q} created:{created_q}'
    encoded = urllib.parse.quote(query, safe='')
    url = f'search/repositories?q={encoded}&sort=stars&order=desc&per_page={per_page}'
    d = gh_api(url)
    return d.get('items', []) if d else []

def main():
    p = argparse.ArgumentParser(description='⭐ Yeni repo tarama')
    p.add_argument('--gun', type=int, help='Son N günde oluşturulanlar')
    p.add_argument('--since', help='Başlangıç tarihi (YYYY-MM-DD)')
    p.add_argument('--until', help='Bitiş tarihi (YYYY-MM-DD)')
    p.add_argument('--kategori', help='Yalnızca bu kategoriyi tara (isim parçası)')
    p.add_argument('--min-stars', type=int, default=0, help='İsteğe bağlı min yıldız (varsayılan: kriter yok)', dest='min_stars')
    p.add_argument('--max', type=int, default=8, help='Kategori başına maksimum sonuç (varsayılan 8)')
    p.add_argument('--kaydet', action='store_true', help='Sonucu tarama.md olarak kaydet')
    args = p.parse_args()

    # Tarih aralığı
    today = datetime.date.today()
    if args.gun:
        since = today - datetime.timedelta(days=args.gun)
        created_q = f">={since.isoformat()}"
    elif args.since:
        since_d = datetime.date.fromisoformat(args.since)
        if args.until:
            created_q = f"{args.since}..{args.until}"
        else:
            created_q = f">={args.since}"
    else:
        since = today - datetime.timedelta(days=30)
        created_q = f">={since.isoformat()}"

    print(f"🔍 Tarama başladı: {created_q.replace('>=','sonrası ')} | min ★{args.min_stars}\n")

    cats = QUERIES
    if args.kategori:
        cats = {k: v for k, v in QUERIES.items() if args.kategori.lower() in k.lower()}
        if not cats:
            print(f"❌ Kategori bulunamadı: {args.kategori}")
            sys.exit(1)

    already = starred_set()
    found = []          # (kategori, repo)
    seen = set()
    for cat, kws in cats.items():
        for kw in kws:
            items = search(kw, created_q, per_page=args.max)
            for it in items:
                full = it['full_name']
                if full in seen or full in already: continue
                lic = (it.get('license') or {}).get('spdx_id') or ''
                # ⛔ LİSANS: kesinlikle tamamen açık kaynak + ücretsiz (OSI onaylı)
                if lic not in GOOD_LICENSES:
                    continue
                if it.get('archived'): continue
                # min ★ kriteri yalnızca --min-stars > 0 verilirse uygulanır
                if args.min_stars and it['stargazers_count'] < args.min_stars: continue
                seen.add(full)
                found.append((cat, {
                    'name': full, 'url': it['html_url'],
                    'created': (it.get('created_at') or '')[:10],
                    'desc': (it.get('description') or '').strip(),
                    'stars': it['stargazers_count'], 'lic': lic,
                    'lang': it.get('language') or '',
                }))
            # arama limiti koruması
            import time; time.sleep(2.0)
        if len(found) < 500: pass

    # ── Çıktı ──
    md = [f"# 🔍 Yeni Repo Tarama ({datetime.date.today().isoformat()})", "",
          f"**Aralık:** `{created_q}` · **Sonuç:** {len(found)} · _lisans: kesinlikle açık kaynak + ücretsiz_", "",
          "| Repo Adı | URL | Tarih | Özellikler (ne yapar) | ★ | Lisans | Kategori |",
          "|---|---|---|---|---|---|---|"]
    for cat, r in sorted(found, key=lambda x: -x[1]['stars']):
        desc = (r['desc'] or '—').replace('|','\\|')[:90]
        md.append(f"| [{r['name']}]({r['url']}) | {r['url']} | {r['created']} | {desc} | ★{r['stars']} | {r['lic']} | {cat} |")

    out = "\n".join(md)
    print(out)
    print(f"\n{'─'*60}\n📊 TOPLAM: {len(found)} yeni repo bulundu")

    # kategori bazlı özet
    print()
    print('📂 KATEGORİ DAĞILIMI:')
    from collections import Counter
    for c, n in Counter(c for c, _ in found).most_common():
        print(f'   {c}: {n} repo')
    print()

    if args.kaydet:
        fn = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tarama.md')
        open(fn, 'w', encoding='utf-8').write(out)
        print(f"💾 Kaydedildi: {fn}")

if __name__ == '__main__':
    main()
