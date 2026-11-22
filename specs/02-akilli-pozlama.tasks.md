# Görevler — Spec 02 (akıllı pozlama)

## 1. dilim (2026-11-22, cihaz geri bildirimi: "ayarlıyor gibi hissetmedim")
- [x] T1 `ExposureDecider` (CompositionKit): konuya göre ölçüm, konudaki parlak yerleri koruma, örneğin parlaklık tercihi; benzetilmiş kamera döngüsüyle testler (ters ışık, iyi pozlanmış, parlak konu, parlak nokta sınırı, salınmadan yakınsama, örnek tercihi)
- [x] T2 Sahne analizi döngüsü (saniyede 4, örnek olmasa da): Vision ile konu + parlaklık ızgarası → pozlama hedefi ve ölçüm noktası
- [x] T3 Dokunarak netleme 5 sn öncelikli (FR-009)
- [x] T4 Titreme için enstantane üst sınırı 1/30 sn (FR-012)
- [x] T5 Durum cümlesi (FR-010): ışık kişiye/konuya göre, parlak konu dengelendi, parlak yerler korunuyor, renkler örneğe benzetildi; 10 sn'de bir, yönlendirmeyle aynı anda değil
- [x] T6 Basılı tutunca ayarsız görüntü (FR-011, Constitution 1.3.0)
- [x] T7 Renk eşleştirmesi artık parlaklığa dokunmuyor; örneğin parlaklık farkı pozlamaya tercih olarak gidiyor

## Sonraki
- [ ] Beyaz dengesi kararı (FR-003, SC-003): şu an iOS'un otomatik beyaz dengesi + renk eşleştirmesi
- [ ] Test setinde SC-001…SC-005 ölçümü (spec 00 kareleri gerekli)
- [ ] Ters ışık / loş cihaz denemeleri (SC-004, SC-007), kör karşılaştırma (SC-008)
