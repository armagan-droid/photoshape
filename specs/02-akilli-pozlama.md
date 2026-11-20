# Spec 02 — Akıllı otomatik pozlama ve beyaz dengesi

> `/speckit.specify` girdisi. Sürüm: **MVP (v1)**. Bağımlılık: 00 (test seti), 01 (temel kamera).

## Ne ve neden

"Instagram görünümü"nün çoğu çekimden sonraki renk işlemeden gelir (spec 03). Ama renk işleme ancak iyi bir ham kare üzerinde iyi çalışır. Patlamış bir beyaz tabak geri getirilemez. Sarı lambayla turuncuya dönmüş bir latte de her filtrede kötü görünür.

Bu spec, çekimin kendisinin işlemeye en uygun "temeli" atmasını sağlar:
- parlak alanlar korunur,
- gölgeler okunur kalır,
- renkler doğal ve tarafsız olur,
- kare titreme bulanıklığı olmadan net çekilir.

Bunu kullanıcı hiçbir ayara dokunmadan alır. Kafede ve yemek masasında iPhone'un varsayılan otomatiğinin zorlandığı durumlar öncelikli hedeftir: pencere önünde ters ışık, loş ortam, sarı iç mekân ışığı ve karışık ışık.

**Sınır:** Bu spec "doğru ve işlenebilir" kareyi hedefler, "güzel" kareyi değil. Sıcaklık, kontrast ya da soluk ton gibi estetik kararlar görünüm tarifine (spec 03) aittir. Beyaz dengesi kararı tarafsıza yakın bir temel arar. Tarif sıcak bir hava istiyorsa bu sıcaklığı çekimden sonra ekler.

## Kullanıcı senaryoları

### Hikâye 1 — Pencere önündeki fincan (ters ışık) (P1)

Kullanıcı arkası pencereye dönük bir kahveyi çeker.

**Kabul senaryoları**
1. **Verilen:** konu ters ışıkta. **Olduğunda:** çekim yapılır. **O zaman:** konu karanlık bir siluete dönüşmez. Pencere tamamen beyaza patlayabilir, ama konunun üzerindeki ayrıntı (köpük deseni, fincan kenarı) okunur.

### Hikâye 2 — Loş kafe (P1)

**Kabul senaryoları**
1. **Verilen:** loş ortam ve elde tutulan telefon. **Olduğunda:** çekim yapılır. **O zaman:** kare titreme bulanıklığı içermez. Gerekirse biraz gren kabul edilir, ama bulanıklık kabul edilmez.
2. **Verilen:** loş ortam. **Olduğunda:** çekim yapılır. **O zaman:** kare gerçek ortamdan belirgin şekilde aydınlık ya da "gece modu" gibi yapay görünmez.

### Hikâye 3 — Sarı iç mekân ışığı ve karışık ışık (P1)

**Kabul senaryoları**
1. **Verilen:** sarı lamba altında beyaz tabak. **Olduğunda:** çekim yapılır. **O zaman:** tabak turuncu değil, hafif sıcak bir beyaz görünür. Ortamın sıcak havası tamamen silinmez.
2. **Verilen:** bir yandan pencere, bir yandan sarı lamba. **Olduğunda:** çekim yapılır. **O zaman:** beyaz dengesi konuya (yemek ya da içecek) göre kurulur. Arka plandaki renk farkı kabul edilir.

### Hikâye 4 — Beyaz tabak ve parlak yüzeyler (P1)

**Kabul senaryoları**
1. **Verilen:** çerçevenin büyük kısmını kaplayan beyaz tabak ya da masa örtüsü. **Olduğunda:** çekim yapılır. **O zaman:** beyazlar patlamaz (tabak dokusu görünür) ve kare griye de kaçmaz.

### Hikâye 5 — Kullanıcının dokunuşu kararı yönlendirir (P2)

**Kabul senaryoları**
1. **Verilen:** kullanıcı bir noktaya dokunmuş (spec 01). **Olduğunda:** pozlama kararı verilir. **O zaman:** dokunulan bölge "konu" kabul edilir ve öncelik ona verilir.

### Hikâye 6 — Işık tavsiyesi için sinyal (P2)

**Kabul senaryoları**
1. **Verilen:** sahne çok loş ya da konu ters ışıkta ve pozlama kararı bunu tam düzeltemiyor. **Olduğunda:** karar verilir. **O zaman:** beyin "ışık zayıf" ya da "konu ters ışıkta" gibi bir sinyal üretir. Bu sinyali kullanıcıya tavsiye olarak gösterme işi spec 04'e aittir ("pencereye yaklaş", "ışığı yanına al").

## Uç durumlar

- Konu tespit edilemiyorsa (örneğin boş duvar) karar tüm sahneye göre verilir.
- Hızlı ışık değişiminde (birisi lambayı açarsa) canlı görüntü yumuşak geçer ve titremez.
- Titreyen yapay ışık (bazı LED'ler) çizgilenmeye yol açabiliyorsa, çekim bunu önleyen bir karar tercih eder.
- Kararın hesaplanamadığı her durumda iOS'un kendi otomatiği kullanılır. Kullanıcı hiçbir zaman hata görmez.
- Lens değişiminde karar yeni lens için yeniden kurulur.

## Fonksiyonel gereksinimler

- **FR-001:** Pozlama ve beyaz dengesi kararı, kamera bağlantısından ayrı bir beyin modülünde verilir. Girdileri: kare görüntüsü, kamera meta verisi (o anki ışık ölçümü, cihaz yeteneklerinin sınırları), isteğe bağlı konu bölgesi ve cihaz hareket bilgisi. Çıktısı, kameraya uygulanacak hedef değerlerdir. Bu modül macOS'ta test setiyle test edilebilir (Constitution IV).
- **FR-002:** Kararın öncelik sırası:
  1. titreme bulanıklığından kaçınmak,
  2. konudaki parlak alanları korumak,
  3. konuyu okunur parlaklıkta tutmak,
  4. renkleri tarafsıza yakın tutmak.
- **FR-003:** Beyaz dengesi sıcak ışıkta tamamen nötrlemez; ortamın sıcaklığından bir miktar bırakır. Bırakılacak miktar planda ayarlanabilir bir değerdir.
- **FR-004:** Karar, sahne türüne (spec 04'teki sınıflandırma) ve aktif görünüm tarifine göre önyargı alabilir. Örneğin "aydınlık, havadar" bir tarif hafif daha aydınlık bir temel isteyebilir. Bu önyargı, tarifteki isteğe bağlı bir alanla ifade edilir.
- **FR-005:** Canlı görüntüdeki değerler ile çekilen karenin değerleri aynı karardan türetilir. Kullanıcının ekranda gördüğü, çektiğiyle tutarlıdır.
- **FR-006:** Kararı uygulayan kamera katmanı, cihazın desteklemediği değerleri sessizce en yakın desteklenen değere sıkıştırır.
- **FR-007:** Beyin, spec 04'ün kullanacağı ışık durumu sinyalini üretir: `ok`, `dim`, `backlit`, `mixed`.
- **FR-008:** Bu özelliğin hiçbir kontrolü kullanıcıya gösterilmez (Constitution II).

## Temel varlıklar

- **ExposureInput:** kare, ölçüm meta verisi, cihaz sınırları, konu bölgesi, hareket bilgisi.
- **ExposureDecision:** hedef parlaklık, enstantane üst sınırı, ISO aralığı, beyaz dengesi hedefi, güven değeri.
- **LightingSignal:** `ok | dim | backlit | mixed`.

## Başarı kriterleri

Beyin kriterleri macOS'ta test setinde ölçülür:
- **SC-001:** `exposure = under` ve `exposure = over` etiketli karelerin ≥ %90'ında karar doğru yönde düzeltme önerir.
- **SC-002:** `exposure = good` etiketli karelerin ≥ %85'inde önerilen düzeltme "değişiklik gerekmez" bandında kalır. Bant planda tanımlanır.
- **SC-003:** `warm_indoor` ve `mixed` etiketli karelerde, kararla düzeltilmiş görüntünün `neutral_region` etiketiyle (spec 00) işaretli bölgesindeki renk kayması, düzeltilmemiş haline göre en az %50 azalır. Tamamen sıfırlanmaz (FR-003).
- **SC-004:** `backlit` etiketli karelerde `subject_region` etiketiyle (spec 00) işaretli konu bölgesinin ortalama parlaklığı, iOS otomatiğinin verdiği sonuca göre artar ve konuda patlamış alan oluşmaz.
- **SC-005:** Işık sinyali (`dim`, `backlit`, `mixed`), etiketli kareler üzerinde ≥ %80 doğrulukla doğru durumu bulur.

Telefonda (iPhone 12) ölçülenler:
- **SC-006:** Kararın hesaplanması canlı görüntüyü 30 kare/sn'nin altına düşürmez.
- **SC-007:** Loş ortamda (`dim`) elde çekilen 20 karenin ≥ 18'i net çıkar (`sharpness = sharp`).
- **SC-008:** Kör karşılaştırmada, aynı sahneyi iOS Kamera uygulaması ve photoshape ile çekilmiş 10 zor durum çiftinde, değerlendiricilerin çoğunluğu en az 6 çiftte photoshape'i "daha iyi temel" olarak seçer.

## Elle test listesi

- [ ] Pencere önünde fincan (ters ışık)
- [ ] Akşam loş kafe, elde
- [ ] Sarı lamba altında beyaz tabak
- [ ] Pencere + lamba karışık ışık
- [ ] Lamba açılıp kapanırken canlı görüntünün davranışı

## Açık sorular

1. **Beyaz dengesinde bırakılacak sıcaklık:** Başlangıç için "yarısını düzelt" yaklaşımı uygun mu? Bunu test setinde ayarlamak, plan aşamasında bir görev olabilir.
2. **Gece modu:** Loş ortamda iOS'un kendi gece modu üçüncü taraf uygulamalara açık değil. Birden fazla kareyi birleştirerek gürültü azaltmak MVP kapsamında mı, yoksa spec 06 (seri çekim) ile mi gelmeli? Öneri: spec 06.
3. **Tarifin pozlamaya etkisi (FR-004):** MVP'de gerekli mi, yoksa tüm tarifler aynı temeli mi kullanmalı? Öneri: alan tanımlansın ama MVP tariflerinde boş kalsın.
4. **SC-008 değerlendiricileri:** Kim olacak? Yakın çevreden 5 kişi yeterli mi?
