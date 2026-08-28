#!/usr/bin/env python3
# ⭐ Yerel Çeviri Aracı (NLLB-200 via CTranslate2) — saf kütüphane, sunucu yok, docker yok.
# Kullanım: ceviri.py <giris.json> <cikti.json>
#   giris.json : {"metinler": ["...", ...]}
#   cikti.json : {"ceviriler": {"metin": "çeviri", ...}}
# Önbellek    : ~/Github-Raporlari/.ceviriler.json  (daha önce çevrilenler tekrar çevrilmez)
import json, os, sys, time

MODEL = os.path.expanduser('~/ct2-nllb')
CACHE = os.path.expanduser('~/Github-Raporlari/.ceviriler.json')

def main():
    giris, cikti = sys.argv[1], sys.argv[2]
    metinler = json.load(open(giris, encoding='utf-8'))['metinler']

    cache = {}
    if os.path.exists(CACHE):
        try:
            cache = json.load(open(CACHE, encoding='utf-8'))
        except Exception:
            cache = {}

    yeni = [m for m in metinler if m not in cache]
    if yeni:
        import ctranslate2, sentencepiece as spm
        t0 = time.time()
        model = ctranslate2.Translator(MODEL, device='cpu', compute_type='int8', inter_threads=4)
        sp = spm.SentencePieceProcessor(model_file=os.path.join(MODEL, 'sentencepiece.bpe.model'))
        # NLLB formatı: <s> eng_Latn metin </s>  →  hedef prefix tur_Latn
        for i in range(0, len(yeni), 32):
            batch = yeni[i:i + 32]
            srcs = [['<s>', 'eng_Latn'] + sp.encode(t, out_type=str) + ['</s>'] for t in batch]
            out = model.translate_batch(srcs, target_prefix=[['tur_Latn']] * len(batch), max_batch_size=32)
            for t, r in zip(batch, out):
                cache[t] = sp.decode(r.hypotheses[0][1:]).strip()
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        json.dump(cache, open(CACHE, 'w', encoding='utf-8'), ensure_ascii=False)
        print(f'✅ {len(yeni)} metin çevrildi ({time.time()-t0:.1f}s)', file=sys.stderr)
    else:
        print('ℹ️ Önbellekten okundu (yeni çeviri yok)', file=sys.stderr)

    json.dump({'ceviriler': {m: cache.get(m, m) for m in metinler}},
              open(cikti, 'w', encoding='utf-8'), ensure_ascii=False)

if __name__ == '__main__':
    main()
