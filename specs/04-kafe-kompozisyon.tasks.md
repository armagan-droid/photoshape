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
- [x] Baş eğimi, gövde ve bacaklar için poz ipuçları (2026-11-24): baş eğimi omuz çizgisine göre (telefonu biraz yamuk tutmak sayılmaz) ≥ 12°, gövde eğimi ≥ 12°, bacak açıklığı gövde boyunun ≥ 0,35'i; her uzuv kendi eşiğine göre puanlanır, en çok aşan söylenir; kişinin kendi sol/sağı; eklem yoksa ipucu yok. Yönlendirme cümleleri için iki dil + ≤ 6 kelime testi
- [x] Işık tavsiyesi (FR-L1…L4): ters ışık, loş (kameranın hassasiyetinden), örneğe göre ışık yönü; tek kanal sırası; testler
- [x] Parlaklık koruması: parlak uçlar beyaza yakınsa kamera daha fazla açılmaz; üst sınır +1,0 EV
- [x] Telefon eğimi (tepeden çekim) — CoreMotion (2026-11-24): `PhoneTilt` yerçekimi vektöründen telefonun aşağı bakma açısını okur; örnek tepedense < 60° → "Telefonu tepeden, yere paralel tut", eğikse < 15° / > 80°, göz hizasıysa > 40° → ipucu. Örneğin açısı yalnızca güvenle okunduysa kullanılır. Açı ipucu sıranın en başında (yanlış yükseklikten kadraj zaten uymaz). Simülatörde hareket sensörü yok; `-UITestPhoneDownward` ile sabit açı verilebilir
- [ ] Test setine kişili kareler (spec 00) ve SC-K4 kullanıcı denemesi

## Elle (iPhone 17)
- [ ] Işık: pencere önünde (ters ışık) "Işığı yanına al"; yan ışıklı örnekte "Işık soldan/sağdan gelsin"; loş odada "Daha aydınlık yere geç"
- [x] Kişili bir örnekle (2026-11-21, kısa kabloyla): örnekte kişi ve 17 eklem bulundu; canlıda kişi 144 ölçümün 39'unda (17–19 eklem). Üretilen talimatlar sayılarla tutarlı: boy %65 → yaklaş, %108 → geri çekil, merkez 0,36 → sola çevir, ardından kol talimatları. Sol/sağın kişinin kendi tarafı olduğu henüz gözle doğrulanmadı.
- [x] Sol/sağ kol talimatlarının doğru tarafı gösterdiği (aynayla denendi: kişinin kendi kolu gösterildi)
- [x] Mavi canlı iskelet kişiye oturuyor; görüntü aşırı parlak değil (+1,5 EV sınırına rağmen)
- [ ] Hazır halkasının çıktığı tam eşleşme
- [ ] Yemek/fincan örneğiyle: kenar taslağı ve kadraj ipuçları
- [ ] Yönlendirme açıkken akıcılık (SC-K3)
- [ ] Baş/gövde/bacak ipuçları gerçek kişide: eşikler gürültülü mü (özellikle baş eğimi 12°); gövde eğimi telefonun dik tutulduğunu varsayar
- [ ] Tepeden fincan örneğinde telefonu dik tutunca "Telefonu tepeden, yere paralel tut", yatırınca kayboluyor mu
