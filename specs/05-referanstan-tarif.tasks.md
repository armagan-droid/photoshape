# Görevler — Spec 05

## 1. adım: "Örnekle çek" (2026-11-21)
- [x] T1 LookKit: `SceneSample`, `ColorStats`, `ReferenceProfile` (yalnızca istatistik; görüntü saklanmaz)
- [x] T2 LookKit: `LookMatcher` — sahneyi örneğe benzeten ayarlar; deterministik
- [x] T3 Testler: SC-002 (5 hazır tarifin hepsi ΔE2000 ≤ 5), kendisiyle eşleşme, sıcak sahneye daha az sıcaklık, siyah-beyaz örnek, parlaklık talebi, vinyet sabiti, süre (SC-001)
- [x] T4 Uygulama: örnek seçme ekranı (sistem seçicisi, izin yok), "Örneksiz çek"
- [x] T5 "Örneklerim": küçük ikon + profil, son örnekle açılış, seçme, silme, örneksiz çekme
- [x] T6 Eşleştirme döngüsü (≈ saniyede bir, yumuşatmalı), kameraya parlaklık hedefi (spec 02 FR-004)
- [x] T7 Filtre şeridi ve güç kaydırıcısı kaldırıldı
- [x] T8 Kayıtta örnek bilgisi (`EditRecord.look`, `reference:<id>`)
- [x] T9 UI testleri: açılış sorusu ve atlama, koyu örnek önizlemeyi koyulaştırır ve hatırlanır, Örneklerim'den örneksiz çekme, örnekle çekim

## Örneğin tarifi kartı (2026-11-23)
- [x] Hikâye 7: bkz. `05-ornegin-tarifi.plan.md` ve `05-ornegin-tarifi.tasks.md`

## Sonraki adımlar
- [x] 2. adım: ekran görüntüsünde uygulama arayüzünü ayıklama (FR-003) (2026-11-24): LookKit `ScreenshotCrop` — boy/en ≥ 1,7 ve kamera bilgisi yoksa; arayüz rengi üst/alt şeritten (açık ve koyu tema), saf arka plan satırlarıyla ayrılan ve çoğu satırı içerikle dolu en uzun bant fotoğraftır; profil satırı ve düğmeler banda katılmaz; kare / 4:5 / 1,91:1'e %6 içinde oturtulur. 11 çizilmiş ekran görüntüsünde örtüşme ≥ %95 (SC-003'ün sentetik kısmı); normal fotoğraf ve fotoğrafsız ekran olduğu gibi kalır. Örnek eklenirken istatistik, konu, açı, ışık, taslak ve ikon kırpılmış fotoğraftan yapılır
- [ ] SC-003 gerçek ekran görüntüleriyle (≥ 20; açık/koyu, tekli/atlıkarınca; açık soru 1: yalnızca kendi ya da izinli hesaplar). Bilinen risk: neredeyse tamamen siyah satırları olan karanlık fotoğraflar koyu temada bölünebilir
- [ ] 3. adım: örneğe göre açı, mesafe ve ışık yönlendirmesi (spec 04; test seti gerekli)
- [ ] Parlak alan korunarak parlaklık hedefi (spec 02 FR-002 öncelik sırası)
- [ ] Cilt ayırma (FR-004)

## Elle (iPhone 17)
- [ ] Gerçek bir örnek fotoğrafla: canlı görüntü örneğe yaklaşıyor mu, titreme var mı, kayıt ekranla aynı mı
