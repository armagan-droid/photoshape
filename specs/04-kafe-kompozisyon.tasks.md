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
- [ ] Parlaklık hedefi neredeyse sürekli +1,5 EV sınırında (cihaz çıktısı): parlak alan koruması ve daha dar sınır (spec 02 FR-002)
- [x] Geliştirici derlemesinde canlı konu mavi iskelet/kutu ile çizilir ve her saniye teşhis satırı yazılır
- [ ] Baş eğimi, gövde ve bacaklar için poz ipuçları
- [ ] Işık tavsiyesi: ters ışık / loş (spec 02 sinyali) ve örneğin ışık yönü
- [ ] Telefon eğimi (tepeden çekim) — CoreMotion
- [ ] Test setine kişili kareler (spec 00) ve SC-K4 kullanıcı denemesi

## Elle (iPhone 17)
- [x] Kişili bir örnekle (2026-11-21, kısa kabloyla): örnekte kişi ve 17 eklem bulundu; canlıda kişi 144 ölçümün 39'unda (17–19 eklem). Üretilen talimatlar sayılarla tutarlı: boy %65 → yaklaş, %108 → geri çekil, merkez 0,36 → sola çevir, ardından kol talimatları. Sol/sağın kişinin kendi tarafı olduğu henüz gözle doğrulanmadı.
- [ ] Sol/sağ kol talimatlarının doğru tarafı gösterdiği (kişinin kendi sol/sağı)
- [ ] Hazır halkasının çıktığı tam eşleşme
- [ ] Yemek/fincan örneğiyle: kenar taslağı ve kadraj ipuçları
- [ ] Yönlendirme açıkken akıcılık (SC-K3)
