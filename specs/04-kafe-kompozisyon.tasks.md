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
- [x] Geliştirici derlemesinde canlı konu mavi iskelet/kutu ile çizilir ve her saniye teşhis satırı yazılır
- [ ] Baş eğimi, gövde ve bacaklar için poz ipuçları
- [x] Işık tavsiyesi (FR-L1…L4): ters ışık, loş (kameranın hassasiyetinden), örneğe göre ışık yönü; tek kanal sırası; testler
- [x] Parlaklık koruması: parlak uçlar beyaza yakınsa kamera daha fazla açılmaz; üst sınır +1,0 EV
- [ ] Telefon eğimi (tepeden çekim) — CoreMotion
- [ ] Test setine kişili kareler (spec 00) ve SC-K4 kullanıcı denemesi

## Elle (iPhone 17)
- [ ] Işık: pencere önünde (ters ışık) "Işığı yanına al"; yan ışıklı örnekte "Işık soldan/sağdan gelsin"; loş odada "Daha aydınlık yere geç"
- [x] Kişili bir örnekle (2026-11-21, kısa kabloyla): örnekte kişi ve 17 eklem bulundu; canlıda kişi 144 ölçümün 39'unda (17–19 eklem). Üretilen talimatlar sayılarla tutarlı: boy %65 → yaklaş, %108 → geri çekil, merkez 0,36 → sola çevir, ardından kol talimatları. Sol/sağın kişinin kendi tarafı olduğu henüz gözle doğrulanmadı.
- [x] Sol/sağ kol talimatlarının doğru tarafı gösterdiği (aynayla denendi: kişinin kendi kolu gösterildi)
- [x] Mavi canlı iskelet kişiye oturuyor; görüntü aşırı parlak değil (+1,5 EV sınırına rağmen)
- [ ] Hazır halkasının çıktığı tam eşleşme
- [ ] Yemek/fincan örneğiyle: kenar taslağı ve kadraj ipuçları
- [ ] Yönlendirme açıkken akıcılık (SC-K3)
