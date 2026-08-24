#!/usr/bin/env bash
# ⭐ Star Katalog — Tek komutla güncelleme
# Kullanım: ./guncelle.sh
set -euo pipefail
cd "$(dirname "$0")"

echo "⏳ GitHub'dan star'lar ve kategoriler çekiliyor..."
python3 guncelle.py --fetch

echo "⏳ Git'e ekleniyor..."
git add index.html data.json repo-indeksi.txt
git commit -m "katalog güncellendi: $(date '+%d.%m.%Y %H:%M')" --allow-empty
git push

echo "✅ Katalog güncellendi! Sayfayı yenile: $(gh repo view --json url -q .url)/"
