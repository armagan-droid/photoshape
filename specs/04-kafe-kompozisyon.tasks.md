# Görevler — Spec 04 (örneğe göre kompozisyon, poz, ışık)

## 1. dilim: taslak + kadraj + poz (2026-11-21)
- [x] T1 FrameKit: `GuidanceInstruction` ve `GuidanceStabilizer` (tek talimat, ≥ 1 sn, yanıp sönmeme, ısrar etmeme); SC-004/SC-K2 benzetilmiş akışla test
- [x] T2 CompositionKit: `Subject`, `BodyPose` (kollar kadraj kutusuna girmez), örneğin 4:5 çerçeveye yerleşimi
- [x] T3 CompositionKit: `CompositionGuide` — öncelik: kişiyi/konuyu kareye al → mesafe → konum → poz (kollar); SC-K1 sentetik iskeletlerle
- [x] T4 CompositionKit: `SubjectDetector` (Vision: kişi ve iskelet, yoksa en belirgin nesne). macOS'ta nesne bulma testi geçiyor; **simülatörde Vision modelleri çalışmıyor**, cihazda denenecek
- [x] T5 Örnek eklenince konu, oran ve taslak çizgileri (≤ 720 px, yalnızca kenarlar) saklanır
- [x] T6 Canlı yönlendirme döngüsü (saniyede 4), taslak, tek cümle + ok, deklanşörde yeşil "hazır" halkası ve titreşim
- [x] T7 UI testi: örnek seçiliyken taslak görünür

## Sonraki
- [ ] Baş eğimi, gövde ve bacaklar için poz ipuçları
- [ ] Işık tavsiyesi: ters ışık / loş (spec 02 sinyali) ve örneğin ışık yönü
- [ ] Telefon eğimi (tepeden çekim) — CoreMotion
- [ ] Test setine kişili kareler (spec 00) ve SC-K4 kullanıcı denemesi

## Elle (iPhone 17)
- [ ] Kişili bir örnekle: iskelet taslağı, "yaklaş/geri çekil", "sol/sağ kolunu kaldır/indir", hazır halkası
- [ ] Yemek/fincan örneğiyle: kenar taslağı ve kadraj ipuçları
- [ ] Yönlendirme açıkken akıcılık (SC-K3)
