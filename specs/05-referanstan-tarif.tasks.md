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
- [ ] 2. adım: ekran görüntüsünde uygulama arayüzünü ayıklama (FR-003, SC-003)
- [ ] 3. adım: örneğe göre açı, mesafe ve ışık yönlendirmesi (spec 04; test seti gerekli)
- [ ] Parlak alan korunarak parlaklık hedefi (spec 02 FR-002 öncelik sırası)
- [ ] Cilt ayırma (FR-004)

## Elle (iPhone 17)
- [ ] Gerçek bir örnek fotoğrafla: canlı görüntü örneğe yaklaşıyor mu, titreme var mı, kayıt ekranla aynı mı
