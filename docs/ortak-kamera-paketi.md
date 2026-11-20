# Ortak kamera/analiz katmanı — arayüz sınırı (photoshape ↔ GymSpot)

> Bu bir özellik spec'i değildir. Plan aşamasında `/speckit.plan`'a bağlam olarak verilir. Amaç, photoshape'in GymSpot'a **bağımlı olmadan**, ileride ortak bir Swift paketine ayrılabilecek bir sınırla yazılmasıdır (Constitution VIII).

## Ortak zincir

```
Kare kaynağı → Kare analizi → Yönlendirme talimatı → Gösterim (ok + kısa cümle, dokunsal geri bildirim)
```

| Katman | photoshape | GymSpot (iOS, gelecekte) |
|---|---|---|
| Kare kaynağı | Arka kamera, fotoğraf odaklı | Ön/arka kamera, video akışı odaklı |
| Analiz | Sahne türü, kompozisyon puanı, ışık sinyali | Vücut pozu, eskiv ve form kuralları |
| Talimat | "biraz geri çekil", "telefonu düz tut" | "kameradan uzaklaş", "tam boy görün", "sol omzunu indir" |
| Gösterim | Ok + kısa cümle | Ok + kısa cümle + muhtemelen ses |

## Sınırda tanımlanacak üç kavram (yalnızca arayüz)

1. **FrameSource:** Zaman damgalı kare, yönelim, isteğe bağlı derinlik ve cihaz hareket bilgisi üreten bir kaynak. Testlerde kayıtlı kare dizisiyle beslenebilir. Somut AVFoundation uygulaması uygulamanın kendisinde kalır.
2. **FrameAnalysis:** Bir kareden ya da kare penceresinden çıkan, uygulamaya özgü sonuç. Ortak olan yalnızca zarf kısmıdır: zaman damgası, güven değeri, kararlılık bilgisi.
3. **GuidanceInstruction:** Tür (kodlanmış ve genişletilebilir), yön, öncelik, cümle anahtarı (yerelleştirme için) ve görünme/kaybolma kuralları (en az süre, ısrar etmeme, aynı anda tek talimat).

İki uygulamada da en çok ortak olan kısım **talimatın kararlı gösterimi**dir: yanıp sönmeme, tek talimat, ısrar etmeme. Spec 04'teki FR-008 ve SC-004 bu davranışı tanımlar.

## GymSpot web ile kavramsal uyum

GymSpot'un web sürümünde egzersiz kuralları JSON veri, kural motoru ise saf TypeScript. photoshape spec 04 FR-004 aynı yaklaşımı izler: kompozisyon şablonları ve kurallar veri olarak tutulur, değerlendirme saf mantıktır.

Şu an kural **formatını** paylaşmak hedeflenmez; alanlar çok farklıdır. Ama "kural veri, motor saf mantık" ilkesi iki projede de aynı tutulursa, iOS GymSpot'ta ortak paket çıkarmak kolaylaşır.

## Kurallar

- photoshape bu üç kavramı kendi deposunda, kendi modülünde tanımlar.
- Bu modül photoshape'e özgü hiçbir şeye (tarif, görünüm, Instagram) bağımlı olmaz. Böylece ileride olduğu gibi ayrı bir pakete taşınabilir.
- Ortak paket, GymSpot iOS'un spec'leri yazılıp aynı ihtiyaç somutlaşınca çıkarılır. O zaman da photoshape paketi sürüm sabitlenmiş bir bağımlılık olarak kullanır. GymSpot'taki bir değişiklik photoshape'in derlenmesini bozamaz.

## Açık sorular

1. GymSpot iOS'ta hareket analizi büyük olasılıkla sürekli video akışı (30–60 kare/sn) gerektirecek; photoshape'te analiz daha seyrek yapılabilir. `FrameSource` her iki ritmi de karşılamalı mı, yoksa ritim uygulamanın kararı mı?
2. Sesli yönlendirme GymSpot'ta gerekecek (antrenman sırasında ekrana bakılmaz). photoshape'te gerekir mi? Gerekirse `GuidanceInstruction` baştan sesli gösterime uygun tasarlanmalı.
