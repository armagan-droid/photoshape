# Görevler — Spec 02 (akıllı pozlama)

## 1. dilim (2026-11-22, cihaz geri bildirimi: "ayarlıyor gibi hissetmedim")
- [x] T1 `ExposureDecider` (CompositionKit): konuya göre ölçüm, konudaki parlak yerleri koruma, örneğin parlaklık tercihi; benzetilmiş kamera döngüsüyle testler (ters ışık, iyi pozlanmış, parlak konu, parlak nokta sınırı, salınmadan yakınsama, örnek tercihi)
- [x] T2 Sahne analizi döngüsü (saniyede 4, örnek olmasa da): Vision ile konu + parlaklık ızgarası → pozlama hedefi ve ölçüm noktası
- [x] T3 Dokunarak netleme 5 sn öncelikli (FR-009)
- [x] T4 Titreme için enstantane üst sınırı 1/30 sn (FR-012)
- [x] T5 Durum cümlesi (FR-010): ışık kişiye/konuya göre, parlak konu dengelendi, parlak yerler korunuyor, renkler örneğe benzetildi; 10 sn'de bir, yönlendirmeyle aynı anda değil
- [x] T6 Basılı tutunca ayarsız görüntü (FR-011, Constitution 1.3.0)
- [x] T7 Renk eşleştirmesi artık parlaklığa dokunmuyor; örneğin parlaklık farkı pozlamaya tercih olarak gidiyor

## 2. dilim: beyaz dengesi (2026-11-24)
- [x] T8 `WhiteBalanceDecider` (CompositionKit): kameranın otomatik beyaz dengesinin düzelttiği ışık (K) → görünüme geri verilecek sıcaklık. Sıcak ışıkta mired cinsinden %15'i kalır (4000 K ışık 5950 K gibi görünür), 5000 K'den soğukta tamamen nötr, 4000–5000 K arası yumuşak geçiş, üst sınır 0.8 (≈ 3700 K altı lambalar); testler: gün ışığı/soğuk ışık nötr, sıcaklıkla artış, sınırda sıçrama yok, SC-003 sentetik kısmı (beyaz tabakta kayma en az yarıya iner, sıfırlanmaz)
- [x] T9 Uygulama: saniyede 4 kameranın beyaz dengesi okunur, sıcaklık yumuşak geçişle görünüme eklenir (önizleme ve kayıt aynı, FR-005); örnek seçiliyken eklenmez (renk eşleştirmesi örneğe göre kurar, FR-004); basılı tutunca kalkar (FR-011)

## Sonraki
- [ ] Beyaz dengesi cihazda: sarı lamba altında beyaz tabak "hafif sıcak beyaz" mı, lamba açılıp kapanınca önizleme sıçramadan geçiyor mu; `keptWarmth` değerini ayarla
- [x] T10 Karışık ışıkta konuya göre beyaz dengesi (Hikâye 3.2, 2026-11-24): `WhiteBalanceDecider.mixedLight` canlı karede (görünümden önce) konunun içindeki ve dışındaki parlak, griye yakın yüzeylerin b* farkını okur; > 8 ise karışık ışık. `gains(for:)` konunun gri yüzeylerindeki kaymanın %70'ini kaldıran kanal kazancını bulur (FR-003 gibi tamamen nötrlemez). Görünümün `temperature` ölçeği (±%10) güçlü lamba kaymasına yetmediği için LookKit'e tariften bağımsız `ChannelGains` aşaması eklendi (doğrusal ışıkta, parlaklık korunur); önizleme ve kayıt aynı kazancı kullanır (FR-005), basılı tutunca kalkar, örnek seçiliyken kullanılmaz; yumuşak geçiş. Testler: lamba altındaki tabak yarıdan fazla soğur ama nötr olmaz, tek ışıkta kazanç yok, pencere altındaki konu ısınır, renderer ile beynin tahmini ΔE < 1,5
- [ ] Karışık ışık cihazda: pencere + lamba masasında konu değişince geçiş yumuşak mı; turuncu yemek "gri yüzey" sayılıyor mu (a* sınırı 10)
- [ ] Test setinde SC-001…SC-005 ölçümü (spec 00 kareleri gerekli)
- [ ] Ters ışık / loş cihaz denemeleri (SC-004, SC-007), kör karşılaştırma (SC-008)
