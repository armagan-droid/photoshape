# Görevler — Spec 00

- [x] T1 Paket iskeleti, `scripts/test.sh`, `.gitignore`, `.gitattributes`
- [x] T2 Şema testleri (geçerli, eksik, geçersiz değer, bilinmeyen anahtar, koşullu alan, otomatik alan, id uyuşmazlığı) → `LabelSchema` + `FrameLabels`
- [x] T3 Dosya meta verisi testleri (derinlikli/derinliksiz HEIC fikstürü) → `FileMetadata` (ImageIO)
- [x] T4 Yükleyici testleri (etiketsiz kare, sahipsiz etiket, tekrar eden id, sıralama, filtre) → `TestSet`
- [x] T5 Kapsam testleri (dağılım, kotalar, çift kotası) → `CoverageReport`
- [x] T6 CLI: `validate [--strict] [--json]`, `schema`, `init-labels`
- [x] T7 SC-001: 50 karelik sentetik sette doğrulama < 10 sn
- [x] T8 `TestSet/README.md`: çekim ve etiketleme rehberi
