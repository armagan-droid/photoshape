# Görevler — Spec 03

## LookKit (test önce, macOS)
- [x] T1 `LookRecipe` v1: JSON format, doğrulama, bozuk/desteklenmeyen sürüm reddi
- [x] T2 `ColorTransform`: noktasal dönüşüm; güç 0 = kimlik, güçle ölçekleme, sınırlar içinde kalma
- [x] T3 LUT üretimi ve `LookRenderer` (LUT + vinyet + gren); deterministiklik (FR-003)
- [x] T4 `ColorScience`: ΔE2000 (bilinen referans değerlerle)
- [x] T5 SC-001 bantlanma, SC-002 güç 0, SC-003 önizleme/kayıt yolu ΔE ≤ 2
- [x] T6 `LookCatalog` + 5 MVP tarifi + yer tutucu örnek görseller ve lisans kayıtları (FR-009 testi)

## Uygulama
- [x] T7 İşlenmiş canlı önizleme (Metal), spec 01 önizleme katmanının yerine
- [x] T8 Yeni ekran yerleşimi, görünüm şeridi, güç kaydırıcısı, soru metni
- [x] T9 Çekimde görünümün uygulanması; `EditRecord.look`; deklanşör anındaki görünüm (uç durum "eşzamanlılık")
- [x] T10 Son görünüm ve görünüm başına güç hatırlama
- [x] T11 Erişim hakkı soyutlaması; Debug'da kilitli görünüm ve deklanşörde kilit işareti
- [ ] T12 Geliştirici ekranı: parametreler, donmuş kare, dışa/içe aktarma
- [x] T13 Lisans kontrolü (FR-009, 2026-11-24): LookKit `LicenseCheck` — görünüm klasöründeki her görsel, lisans kaydı tam olan bir tarifin örneği olmalı; tarifin adını verdiği ama olmayan görsel de hata. `scripts/check-licenses.sh` (`look-tool check-licenses`); `--release` yer tutucu görselleri de reddeder (açık soru 1: yer tutucuyla App Store'a çıkılmaz) — arşivden önce çalıştırılır. Paket testi her `scripts/test.sh` çalışmasında klasörü denetler
- [ ] T14 Derinlikli bulanıklık: kayıtta, sonra önizlemede; performans ölçümü
- [x] T15 UI testleri: görünüm değiştirme, güç, hatırlama, kilit

## Notlar
- Paket testleri: CaptureKit 22, FrameKit 2, LookKit 19, TestSetKit 41. UI testleri: 9 (spec 01: 5, spec 03: 4).
- SC-001 eşiği: 1024 px rampalarda komşu pikseller arası en büyük adım ≤ 4/255. SC-003: önizleme/kayıt yolu ortalama ΔE2000 ≤ 2 (5 görünümün hepsinde geçiyor).
- Örnek görseller yer tutucu (`look-tool render-samples`, lisans `placeholder-generated`); fotoğrafçı görselleri gelince değiştirilecek.

## Elle (iPhone 17; iPhone 12 bulunursa tekrar)
- [ ] Spec 03 "Elle test listesi", SC-004…SC-006
