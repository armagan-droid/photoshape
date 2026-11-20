# Görevler — Spec 00

- [x] T1 Paket iskeleti, `scripts/test.sh`, `.gitignore`, `.gitattributes`
- [x] T2 Şema testleri (geçerli, eksik, geçersiz değer, bilinmeyen anahtar, koşullu alan, otomatik alan, id uyuşmazlığı) → `LabelSchema` + `FrameLabels`
- [x] T3 Dosya meta verisi testleri (derinlikli/derinliksiz HEIC fikstürü) → `FileMetadata` (ImageIO)
- [x] T4 Yükleyici testleri (etiketsiz kare, sahipsiz etiket, tekrar eden id, sıralama, filtre) → `TestSet`
- [x] T5 Kapsam testleri (dağılım, kotalar, çift kotası) → `CoverageReport`
- [x] T6 CLI: `validate [--strict] [--json]`, `schema`, `init-labels`
- [x] T7 SC-001: 50 karelik sentetik sette doğrulama < 10 sn
- [x] T8 `TestSet/README.md`: çekim ve etiketleme rehberi

## Bölge etiketleri (spec 00 güncellemesi, Constitution v1.1.0)

- [x] T9 Şemaya `subject_region` / `neutral_region` (FR-008): tür, sınır, alan, koşullu beklenti (eksiklik)
- [x] T10 `ValidationReport.gaps`; CLI'da raporlama, `--strict` kapısı, JSON çıktısı, dağılım
- [x] T11 Yönelim: görüntü, derinlik ve boyutlar Fotoğraflar'daki yönelimde (8 yönelim testi)
- [x] T12 `LabelFile`: diğer alanları koruyarak bölge yazma
- [x] T13 `testset-labeler` (FR-009)
- [x] T14 `TestSet/README.md` güncellemesi
- [ ] T15 Elle: `testset-labeler` ile gerçek bir Portre HEIC üzerinde konu ve nötr bölge işaretleme; yönelimin doğru göründüğünü kontrol etme
