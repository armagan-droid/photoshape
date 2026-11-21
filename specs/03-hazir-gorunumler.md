# Spec 03 — Görünüm tarifi, hazır görünümler, canlı önizleme ve çekim sonrası renk işleme

> `/speckit.specify` girdisi. Sürüm: **MVP (v1)**. Bağımlılık: 00, 01, 02. Bu spec uygulamanın çekirdeğini tanımlar (Constitution III).
>
> **Yön değişikliği (2026-11-21):** Cihaz denemesinden sonra hazır görünüm şeridi ve görünüm gücü kaydırıcısı **kullanıcıya gösterilmez** (README). Bu spec'ten MVP'de kalanlar: tarif formatı (FR-001), renk işleme (FR-002, FR-003), canlı önizleme ve kayıtta aynı işleme, düzenleme kaydı (FR-005), erişim hakkı soyutlaması (FR-008), lisans kontrolü (FR-009), geliştirici ekranı (Hikâye 4), bulanıklık (Hikâye 3). Hikâye 1, 2 ve 5'in şerit ve kaydırıcıya ait kısımları askıya alındı; tarif artık seçilen örnekten gelir (spec 05). Beş hazır tarif, spec 05'in doğrulamasında referans olarak kalır (spec 05 FR-008).

## Ne ve neden

Kullanıcı fotoğrafçılık bilmez, ama ne istediğini görünce tanır. Bu yüzden akış "nasıl bir fotoğraf istiyorsun?" sorusuyla başlar. Kullanıcı hazır görünümler arasında kaydırır ve her görünümü **kendi canlı kamera görüntüsünde**, kendi sahnesinde görür. Örnek fotoğraf yalnızca küçük bir ikon olarak kalır. Seçtiği görünümle çeker. Kaydedilen fotoğraf, ekranda gördüğünün aynısıdır.

Rakiplerden (otomatik ayar ve kompozisyon koçları) fark burada başlar: görünüm bir filtre değil, bir **tariftir**. Aynı tarif bugün elle hazırlanmış bir hazır seçenekten, yarın kullanıcının yüklediği bir ekran görüntüsünden (spec 05) gelir. Kamera ikisini ayırt etmez.

Bu spec şunları kapsar:
- tarifin içeriği,
- MVP'deki kafe/yemek görünümleri (4–5 adet),
- görünüm seçim akışı,
- canlı önizleme,
- görünüm gücü kaydırıcısı,
- derinlik verisiyle arka plan bulanıklığı,
- çekim sonrası işleme,
- tarifleri ayarlamak için geliştirici ekranı,
- ücretsiz/premium sınırının yapısı.

**Kapsam dışı:** Cilt tonu koruma portre kategorisine (v4) taşındı. Kafe/yemekte eller görünebilir; bu sürümde özel işlem görmez.

## Kullanıcı senaryoları

### Hikâye 1 — Görünümü kendi sahnesinde seçer (P1)

Uygulama açılır. Kullanıcı canlı kamera görüntüsünün üzerinde "nasıl bir fotoğraf istiyorsun?" sorusunu ve bir görünüm şeridini görür. Sağa sola kaydırdıkça canlı görüntü o görünümle değişir.

**Kabul senaryoları**
1. **Verilen:** canlı görüntü açık. **Olduğunda:** kullanıcı bir sonraki görünüme kaydırır. **O zaman:** canlı görüntü o görünümle gösterilir. Seçili görünümün adı ve küçük örnek fotoğraf ikonu görünür.
2. **Verilen:** görünüm şeridi. **Olduğunda:** kullanıcı en başa gelir. **O zaman:** "Doğal" seçeneği bulunur: görünüm uygulanmaz, yalnızca spec 02'nin temeli kullanılır.
3. **Verilen:** bir görünüm seçilmiş. **Olduğunda:** kullanıcı deklanşöre basar. **O zaman:** kaydedilen fotoğraf, ekranda gördüğüyle aynı görünümü taşır (SC-003).
4. **Verilen:** kullanıcı bir önceki oturumda bir görünüm seçmiş. **Olduğunda:** uygulama yeniden açılır. **O zaman:** son seçilen görünüm hazır gelir.

### Hikâye 2 — Görünüm gücünü ayarlar (P1)

**Kabul senaryoları**
1. **Verilen:** seçili bir görünüm. **Olduğunda:** kullanıcı görünüm gücü kaydırıcısını hareket ettirir. **O zaman:** görünüm "hiç"ten "tam"a kadar kademesiz değişir. Kaydırıcıda sayı ya da yüzde yoktur.
2. **Verilen:** görünüm gücü ayarlanmış. **Olduğunda:** çekim yapılır. **O zaman:** kaydedilen fotoğraf aynı gücü taşır.

### Hikâye 3 — Arka plan bulanıklığı (P2)

**Kabul senaryoları**
1. **Verilen:** tarif bulanıklık istiyor ve kare derinlik verisiyle çekilmiş. **Olduğunda:** fotoğraf işlenir. **O zaman:** konu net kalır ve arka plan tarifin istediği ölçüde bulanıklaşır. Konunun kenarlarında belirgin bir "kesik" görünmez.
2. **Verilen:** derinlik verisi yok (lens, mesafe ya da ışık nedeniyle). **Olduğunda:** fotoğraf işlenir. **O zaman:** bulanıklık sessizce atlanır. Görünümün geri kalanı uygulanır ve kullanıcı hata görmez.
3. **Verilen:** tarif bulanıklık istiyor ve canlı derinlik verisi var. **O zaman:** canlı önizlemede bulanıklık yaklaşık olarak gösterilir (karar 2). Derinlik yoksa önizlemede de kayıtta da bulanıklık sessizce atlanır.

### Hikâye 4 — Geliştirici tarif ayarlar ve dışa aktarır (P1, yalnızca geliştirici derlemesi)

Geliştirici, MVP tariflerini elle hazırlamak için canlı önizleme üzerinde tarifin her parametresini değiştirebileceği bir ekran açar.

**Kabul senaryoları**
1. **Verilen:** geliştirici derlemesi. **Olduğunda:** geliştirici ekranı açılır. **O zaman:** tarifin tüm renk/ton parametreleri adlı ve sayılı kontrollerle düzenlenebilir. Değişiklik canlı önizlemede anında görünür.
2. **Verilen:** ayarlanmış bir tarif. **Olduğunda:** "dışa aktar"a basılır. **O zaman:** tarif, uygulamanın okuduğu formatta bir dosya olarak paylaşım menüsüyle dışa aktarılır (örneğin AirDrop ile Mac'e).
3. **Verilen:** mevcut bir tarif dosyası. **Olduğunda:** geliştirici ekranında açılır. **O zaman:** düzenlenip tekrar dışa aktarılabilir.
4. **Verilen:** geliştirici ekranındayken. **Olduğunda:** çekim yapılır ya da galeriden bir test karesi açılır. **O zaman:** tarif hareketsiz bir kare üzerinde de ayarlanabilir. Böylece aynı kare üzerinde karşılaştırma yapılabilir.
5. **Verilen:** App Store derlemesi. **O zaman:** geliştirici ekranı derlemede bulunmaz (Constitution II).

### Hikâye 5 — Kilitli görünümler (P3, yapı MVP'de)

**Kabul senaryoları**
1. **Verilen:** MVP derlemesi. **O zaman:** tüm görünümler açıktır, çünkü erişim hakkı soyutlaması her şeye "açık" yanıtını verir.
2. **Verilen:** erişim hakkı soyutlaması bir görünüm için "kilitli" yanıtı verecek şekilde test derlemesinde değiştirilmiş. **O zaman:** görünüm şeritte görünür ve kullanıcı onu kendi sahnesinde deneyebilir. Ancak deklanşörde kilit işareti çıkar. (Ödeme ekranının kendisi spec 07'dedir.) Bu davranış MVP'de test edilir, ama App Store'a kapalı çıkar.

## Görünüm tarifi (LookRecipe) — içerik

Tarif bir veridir; nasıl uygulanacağı plan aşamasında belirlenir. Tarifin taşıması gerekenler:

- **Kimlik:** benzersiz kimlik, format sürümü, tarif sürümü.
- **Ad ve açıklama:** Türkçe ve İngilizce kısa ad ("Sabah Işığı", "Morning Light").
- **Kategori ve sahne türü:** hangi kategori için tasarlandığı; uygun olduğu sahne türleri (spec 04 listesi).
- **Renk ve ton ayarları:**
  - genel parlaklık ve kontrast eğrisi,
  - parlak ve gölge bölgelerinin ayrı tonlanması,
  - genel sıcaklık ve renk tonu kayması,
  - genel doygunluk,
  - renk aralığına göre (kırmızılar, sarılar, yeşiller gibi) ton/doygunluk/parlaklık ayarı,
  - soluk siyahlar,
  - gren,
  - vinyet.
- **Bulanıklık isteği:** yok / hafif / belirgin.
- **Pozlama önyargısı** (isteğe bağlı, spec 02 FR-004).
- **Kompozisyon şablonu** (isteğe bağlı, spec 04'e referans).
- **Işık tavsiyeleri** (isteğe bağlı, spec 04'e referans).
- **Örnek görsel:** ikon olarak gösterilen örnek fotoğrafın kimliği ve **lisans kaydı** (kaynak, lisans türü, atıf metni).
- **Erişim seviyesi:** `free` | `premium`.
- **Kaynak:** `bundled` | `pack` | `userReference`. Kamera ve işleme bu alanı kullanmaz (Constitution III). Yalnızca arayüz ve erişim hakkı kullanır.

## Uç durumlar

- **Görünüm gücü = 0:** fotoğraf "Doğal" ile aynıdır.
- **Uç değerler:** Çok aşırı bir tarif bile görüntüde bantlanma (renk geçişlerinde basamak) ya da renk kırılması üretmemelidir.
- **Bozuk tarif:** Okunamayan ya da sürümü desteklenmeyen tarif şeritte görünmez ve uygulama çökmez.
- **Isınma:** Cihaz ısınıp canlı önizleme performansı düşerse, önizlemede görünüm basitleştirilebilir. Kaydedilen fotoğraf yine tam tarifle işlenir.
- **Hızlı kaydırma:** Kaydırma sırasında ara görünümler atlanabilir, ama son durulan görünüm doğru gösterilir.
- **Eşzamanlılık:** Çekimden hemen sonra görünüm değiştirilirse, kaydedilen fotoğraf deklanşöre basıldığı andaki görünümü taşır.

## Fonksiyonel gereksinimler

- **FR-001:** Tarif formatı bu spec'te tanımlanır ve sürümlenir. Sonraki bütün kaynaklar (paketler, spec 05) aynı formatı üretir.
- **FR-002:** Renk işleme, kameradan bağımsız bir beyin modülünde yapılır: girdi görüntü + tarif + güç, çıktı görüntü. Aynı modül hem canlı önizlemede hem çekim sonrasında kullanılır. macOS'ta test edilebilir.
- **FR-003:** İşleme deterministiktir: aynı kare + aynı tarif + aynı güç her zaman aynı sonucu verir.
- **FR-004:** MVP, kafe/yemek kategorisi için 4–5 hazır görünümle ve bir "Doğal" seçeneğiyle çıkar. Görünümler uygulamayla birlikte gelir; ağ gerekmez.
- **FR-005:** Kaydedilen fotoğrafın düzenleme kaydı; tarif kimliğini, tarif sürümünü, görünüm gücünü ve kırpma bilgisini içerir. Fotoğraflar'da "Geri Al" orijinali getirir (spec 01 FR-004).
- **FR-006:** Görünüm seçim ekranı ile kamera aynı ekrandır. Kullanıcı ayrı bir "filtre ekranı"na gitmez.
- **FR-007:** Görünüm adları ve açıklamaları iki dildedir. Teknik terim içermez.
- **FR-008:** Bir görünümün kullanılabilir olup olmadığı yalnızca erişim hakkı soyutlamasına sorulur (Constitution VII). MVP uygulaması "her şey açık" yanıtını verir.
- **FR-009:** Lisans kaydı olmayan bir örnek görsel derlemeye giremez. Derleme sırasında bu kontrol edilir.
- **FR-010:** Geliştirici ekranı yalnızca geliştirici derlemesinde bulunur. Dışa aktarılan dosya, uygulamaya eklenen tarif dosyasıyla aynı formattadır.
- **FR-011:** Bulanıklık yalnızca derinlik verisi varsa uygulanır. Yoksa sessizce atlanır.

## Temel varlıklar

- **LookRecipe** (yukarıda tanımlı).
- **LookStrength:** 0–1 arası değer. Kullanıcıya sayı olarak gösterilmez.
- **LookCatalog:** kullanılabilir tariflerin sıralı listesi (paketlerle genişler).
- **Entitlement:** erişim hakkı soyutlaması.
- **AssetLicense:** örnek görselin lisans kaydı.

## Başarı kriterleri

macOS'ta, test setinde ölçülenler:
- **SC-001:** Renk işleme modülü test setindeki her kare ve her MVP tarifi için çıktı üretir. Hiçbir çıktıda bantlanma eşiğini aşan basamak bulunmaz; eşik planda tanımlanır.
- **SC-002:** Görünüm gücü 0'da çıktı, girdiyle piksel düzeyinde aynıdır (tolerans planda).
- **SC-003:** Canlı önizleme yolunun çıktısı ile çekim sonrası yolun çıktısı, aynı karede ve aynı çözünürlüğe indirildiğinde ortalama ΔE2000 ≤ 2 farkla eşleşir.

iPhone 12'de ölçülenler:
- **SC-004:** Görünüm uygulanmış canlı önizleme ≥ 30 kare/sn.
- **SC-005:** Kaydırmayla görünüm değişiminin ekrana yansıması ≤ 100 ms.
- **SC-006:** Görünümlü bir fotoğrafın deklanşörden galeriye ulaşması ≤ 3 sn (bulanıklık dahil).

Kullanıcıyla ölçülenler:
- **SC-007:** 5 test kullanıcısının en az 4'ü, yardım almadan görünüm değiştirip çeker ve gördüğü ile kaydedilenin "aynı" olduğunu söyler.
- **SC-008:** Kör karşılaştırmada, aynı kafe sahnesinin "Doğal" ve "görünümlü" çekimlerinden görünümlü olan çoğunluk tarafından ≥ %70 oranında "Instagram'a koyarım" olarak seçilir.

## Elle test listesi

- [ ] Görünümler arası hızlı kaydırma, akıcılık
- [ ] Görünüm gücü kaydırıcısının his kalitesi
- [ ] Derinlik verisi olan ve olmayan çekimde bulanıklık
- [ ] Fotoğraflar'da geri alma; görünüm ve kırpmanın birlikte geri alınması
- [ ] Geliştirici ekranından AirDrop ile tarif dışa aktarma ve tekrar içe alma
- [ ] Isınma altında 10 dakika kullanım

## Kararlar (clarify, 2026-11-21)

1. **Örnek görsel lisansı:** (a) Fotoğrafçıdan satın alınır. Sözleşme tamamlanana kadar lisans kaydı olan yer tutucu görseller kullanılır ("kendi üretimimiz" lisansıyla). Yer tutucularla App Store'a çıkılmaz.
2. **Canlı önizlemede bulanıklık:** Derinlik verisi varsa önizlemede yaklaşık olarak gösterilir, böylece "gördüğün = çektiğin" korunur. Performans bütçesi (SC-004, ≥ 30 kare/sn) bozulursa önce önizlemedeki bulanıklığın çözünürlüğü düşürülür. Önizlemede bulanıklık hiç gösterilemiyorsa, bulanıklık isteyen görünümler MVP'den çıkarılır; kayıtta tek başına bulanıklık yapılmaz.
3. **Görünüm gücünün hatırlanması:** Görünüm başına hatırlanır. Constitution açık soru 1 bu kararla kapandı (1.1.2).
4. **"Doğal" seçeneğinin konumu:** Şeridin başında (Hikâye 1.2).
5. **Uygulama içinde yeniden düzenleme:** Kapsam dışı. Gerekçe spec 01 FR-012 ile aynıdır: tam kütüphane izni gerektirir.
6. **MVP görünüm listesi:** Beş görünüm: aydınlık-havadar, sıcak-kahve tonlu, kontrastlı-koyu, soluk film, canlı. Adlar ve son ayarlar tarifler hazırlanırken belirlenir.
