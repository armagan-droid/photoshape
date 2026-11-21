# Spec 04 — Kafe/yemek kategorisi için kompozisyon ve ışık yönlendirmesi

> `/speckit.specify` girdisi. Sürüm: **MVP (v1)**. Bağımlılık: 00, 01, 02 (ışık sinyali), 03 (tarifin kompozisyon şablonu alanı), 05 (örnekten çekim hedefleri).
>
> **2026-11-21:** Yönlendirmenin asıl kaynağı seçilen örnektir: örneğin çekim açısı, konunun boyutu ve yeri şablonu belirler (spec 05 FR-009). Sahne türleri uyuşmazsa Constitution III'teki kural geçerlidir: kompozisyon ipuçları kapanır, ışık tavsiyesi sürer.

## Ne ve neden

Güzel bir kafe fotoğrafını ayardan çok açı ve çerçeve belirler: tepeden dümdüz çekilmiş bir masa, yakından ve hafif açıyla çekilmiş bir latte, kenarları dağınık olmayan bir kadraj. Fotoğraftan anlamayan kullanıcı bunu bilmez, ama söylenirse yapar.

Bu spec, kullanıcıyı teknik terim olmadan, **ok ve kısa cümleyle** doğru konuma yönlendirir: "biraz geri çekil", "telefonu düz tut". Ayrıca değiştirilemeyecek olan ışık için tavsiye verir: "pencereye yaklaş", "ışığı yanına al".

Kafe/yemek ilk kategori olarak seçildi, çünkü en az değişkenli kategori: konu hareketsizdir, insan yoktur, birkaç tekrar eden sahne türü vardır.

Kompozisyon ipuçları yalnızca sahne türü uyuşuyorsa verilir (Constitution III). Kullanıcının sahnesi tarifin şablonuna uymuyorsa ipuçları kapanır. Uygulama kullanıcıyı zorla bir şablona sokmaya çalışmaz.

## Sahne türleri ve şablonlar (MVP)

| Sahne türü | Tanım | Şablonun özü |
|---|---|---|
| `food_top_down` | Tepeden, masaya dik | Telefon yere paralel; ana tabak çerçeveye yerleşik; kenarlarda kesik nesne yok |
| `food_angled` | Yaklaşık oturan göz hizası, yemeğe eğik | Konu alt üçte birde; arka plan sade; hafif yakın |
| `drink_closeup` | Fincan/bardak yakın çekim | Konu çerçeveyi doldurur; üst kenar düz; köpük deseni görünür |
| `table_spread` | Birden fazla tabak, masa düzeni | Tepeden ya da geniş açı; nesneler dengeli; ufuk/masa kenarı düz |
| `cafe_interior` | Mekân, atmosfer | Dikey çizgiler düz; çerçeve dengeli |
| `other` | Tanınmayan | İpucu verilmez |

## Kullanıcı senaryoları

### Hikâye 1 — Tepeden çekimde telefonu düzleştirme (P1)

**Kabul senaryoları**
1. **Verilen:** sahne `food_top_down` olarak tanınmış ve telefon yere paralel değil. **Olduğunda:** canlı görüntü açık. **O zaman:** ekranda düzleşme yönünü gösteren bir işaret ve "telefonu düz tut" cümlesi görünür.
2. **Verilen:** telefon yeterince düzleşmiş. **O zaman:** işaret kısa bir onayla (görsel + hafif titreşim) kaybolur.

### Hikâye 2 — Mesafe ve çerçeve (P1)

**Kabul senaryoları**
1. **Verilen:** konu çerçeveden taşıyor ya da kenarlardan kesiliyor. **O zaman:** "biraz geri çekil" ve yön oku gösterilir.
2. **Verilen:** konu çerçevede çok küçük. **O zaman:** "biraz yaklaş" gösterilir.
3. **Verilen:** konu yanlış yönde kaymış. **O zaman:** konuyu yerleştirmek için telefonun kaydırılacağı yönü gösteren bir ok çıkar.

### Hikâye 3 — Işık tavsiyesi (P1)

**Kabul senaryoları**
1. **Verilen:** spec 02 `dim` sinyali veriyor. **O zaman:** "pencereye yaklaş" gibi bir tavsiye gösterilir. Tavsiye çekimi engellemez.
2. **Verilen:** `backlit` sinyali. **O zaman:** "ışığı yanına al" gösterilir.
3. **Verilen:** aynı tavsiye gösterilmiş ve kullanıcı aynı yerde kalmaya devam etmiş. **O zaman:** tavsiye bir süre sonra kaybolur ve aynı oturumda tekrar ısrar etmez.

### Hikâye 4 — Sahne uyuşmazlığında ipuçları kapanır (P1)

**Kabul senaryoları**
1. **Verilen:** seçili tarifin şablonu `drink_closeup` ve sahne `food_top_down`. **O zaman:** kompozisyon ipuçları tamamen kapanır; sahnenin varsayılan şablonuna geçilmez. Renk görünümü ve ışık tavsiyesi yine uygulanır (Constitution III).
2. **Verilen:** seçili tarifin kompozisyon şablonu yok (örneğin şablonsuz hazır görünümler ve "Doğal"). **O zaman:** yönlendirme sahnenin kendi varsayılan şablonuyla yapılır.
3. **Verilen:** sahne `other`. **O zaman:** hiçbir kompozisyon ipucu gösterilmez. Işık tavsiyesi yine gösterilebilir.

### Hikâye 5 — Kullanıcı ipuçlarını rahatsız edici bulmaz (P1)

**Kabul senaryoları**
1. Aynı anda en fazla **bir** kompozisyon ipucu ve **bir** ışık tavsiyesi görünür.
2. Bir ipucu en az 1 saniye ekranda kalır. Sahne sınır değerde dalgalansa bile ipucu yanıp sönmez.
3. Çerçeve "iyi" duruma geldiğinde ipuçları kaybolur ve deklanşör çevresinde ince bir "hazır" işareti görünür.
4. Kullanıcı ipuçlarına uymadan da her an çekebilir.

## Uç durumlar

- Telefon hareket halindeyken (kullanıcı yürürken) ipuçları gösterilmez. Sahne durulunca başlar.
- Sahne türü hızlı değişiyorsa (masada telefon gezdiriliyorsa) sınıflandırma kararlı hale gelene kadar ipucu verilmez.
- "Geniş" lensle çok yakın çekimde bozulma oluyorsa "normal" lense geçmek bir ipucu olarak önerilebilir. [NEEDS CLARIFICATION: açık soru 3]
- Masadaki insan elleri `people_visible = hands` olabilir; bu kompozisyonu engellemez.
- Hareket sensörü verisi alınamazsa düzleştirme ipucu gösterilmez.

## Fonksiyonel gereksinimler

- **FR-001:** Sahne türü sınıflandırması beyin modülünde yapılır: girdi kare (ve isteğe bağlı cihaz eğimi), çıktı sahne türü + güven değeri. macOS'ta test setiyle test edilebilir.
- **FR-002:** Kompozisyon puanlaması beyin modülünde yapılır: girdi kare, sahne türü, şablon ve cihaz eğimi; çıktı puan ve en önemli tek düzeltme önerisi (yön + tür).
- **FR-003:** Öneriler bir **yönlendirme talimatı** olarak üretilir: tür (yaklaş, uzaklaş, sola kaydır, düzleştir, eğ, ışığa yaklaş vb.), yön, öncelik. Kullanıcıya gösterilecek cümle, talimattan iki dilde üretilir. Bu talimat yapısı, GymSpot ile paylaşılabilecek ortak katmanın arayüz sınırıdır (bkz. `docs/ortak-kamera-paketi.md`).
- **FR-004:** Şablonlar ve kurallar kodda değil, veri olarak tanımlanır. Yeni sahne türü ya da kategori eklemek kural verisi eklemekle başlar. Kod değişikliği istisna olmalıdır.
- **FR-005:** Tarif bir kompozisyon şablonu taşıyorsa ipuçları yalnızca sahne türü şablonla uyuşuyorsa verilir; uyuşmuyorsa kompozisyon ipuçları kapanır. Tarif şablon taşımıyorsa sahnenin kendi varsayılan şablonu kullanılır (Constitution III, v1.1.0).
- **FR-006:** Işık tavsiyesi spec 02'nin ışık sinyalinden üretilir. Işığı değiştirmeye çalışan bir işlem yapılmaz.
- **FR-007:** Yönlendirme cümleleri en fazla 6 kelimedir, iki dildedir ve teknik terim içermez (Constitution II ve VI).
- **FR-008:** İpuçlarının görünme ve kaybolma kuralları (en az süre, tek ipucu, ısrar etmeme) davranış olarak test edilebilir. Zaman ve kare akışı benzetilebilir olmalıdır.
- **FR-009:** Yönlendirme sırasında canlı önizleme 30 kare/sn'nin altına düşmez.

## Temel varlıklar

- **SceneType:** yukarıdaki liste.
- **CompositionTemplate:** sahne türü + kurallar (veri).
- **CompositionScore:** puan + öneri.
- **GuidanceInstruction:** tür, yön, öncelik, cümle anahtarı.
- **LightingAdvice:** spec 02 sinyalinden üretilen tavsiye.

## Başarı kriterleri

macOS'ta, test setinde ölçülenler:
- **SC-001:** Sahne türü sınıflandırması, `other` dışındaki etiketli karelerde ≥ %85 doğruluk sağlar.
- **SC-002:** Kompozisyon puanı, `pair_id` ile eşlenmiş iyi/kötü çiftlerde iyi kareye ≥ %80 oranında daha yüksek puan verir.
- **SC-003:** `composition = bad` karelerde üretilen tek öneri, etiketteki `composition_issue` ile ≥ %70 oranında eşleşir.
- **SC-004:** Benzetilmiş kare akışında, sınır değerde dalgalanan sahnede ipucu 1 saniyeden kısa sürede yanıp sönmez (0 ihlal).

iPhone 12'de ölçülenler:
- **SC-005:** Düzleştirme ipucu, telefon yere paralelden ±2° içindeyken "hazır" durumuna geçer.
- **SC-006:** Yönlendirme açıkken canlı önizleme ≥ 30 kare/sn.

Kullanıcıyla ölçülenler:
- **SC-007:** 5 test kullanıcısının en az 4'ü, ipuçlarıyla çektiği tepeden yemek fotoğrafını ipuçsuz ilk denemesinden daha iyi bulur.
- **SC-008:** Test kullanıcılarının çoğunluğu ipuçlarını "rahatsız edici" olarak nitelendirmez (5'li ölçekte ortalama ≤ 2).

## Elle test listesi

- [ ] Tepeden masa çekiminde düzleştirme
- [ ] Fincanı yakın çekerken mesafe ipucu
- [ ] Loş masada "pencereye yaklaş"
- [ ] Sahne uyuşmazlığında ipuçlarının kapanması
- [ ] Ellerle tutulan bardak

## Açık sorular

1. **Uyuşmazlık davranışı — karar verildi (2026-11-20):** Şablonlu tarifte sahne uyuşmazsa ipuçları kapanır (seçenek a). Şablonsuz tarifte sahnenin varsayılan şablonu kullanılır. Kural Constitution III'e (v1.1.0) yazıldı. MVP hazır görünümlerinin şablon taşıyıp taşımayacağına tarifler ayarlanırken karar verilecek. Şablon taşırlarsa, uyuşmayan sahnelerde kompozisyon ipucu vermezler.
2. **Kullanıcının ipuçlarını kapatması:** İpuçlarını tamamen kapatmak için bir seçenek olsun mu? Kamera ekranının davranışını değiştiren kalıcı bir ayar olduğu için çekim kontrolleri grubuna girer; eklenirse constitution değişikliği gerekir (Constitution II, v1.1.0).
3. **Lens önerisi:** Uygulama kullanıcıya lens değiştirmesini önermeli mi ("normal'e geç"), yoksa lensi kendisi mi değiştirmeli? Kendisi değiştirmesi kafa karıştırıcı olabilir.
4. **Sınıflandırıcı kaynağı:** Vision'ın hazır görüntü sınıflandırması `drink_closeup` / `food_angled` ayrımını yapmaya yetmeyebilir. Yerli bir çözümle (Create ML ile eğitilmiş küçük bir model) mi gidilecek? Eğitim verisi test setinden ayrı olmalı. Bu, ikinci bir fotoğraf seti gerektirir mi?
