# Spec 07 — Instagram'a paylaşım, ödeme ekranı ve görünüm paketleri

> `/speckit.specify` girdisi. Sürüm: **v2** (spec 05 ile birlikte). Bağımlılık: 01, 03 (erişim hakkı soyutlaması), 05 (kota). Plan aşamasında bu spec ikiye bölünebilir: 07a paylaşım, 07b ödeme ve paketler.

## Ne ve neden

**Paylaşım:** Kullanıcının asıl hedefi Instagram'dır. MVP'deki standart paylaşım menüsü çalışıyor, ama birkaç dokunuş ve seçim gerektiriyor. Bu spec, 4:5 fotoğrafı tek dokunuşla Instagram Gönderi'ye ya da Hikâye'ye götüren akışı tanımlar.

**Ödeme:** Freemium model. Hedef, aylık birkaç yüz dolar ek gelir.
- **Ücretsiz:** kamera, akıllı otomatik ayarlar, kompozisyon yönlendirmesi, her kategoriden birkaç görünüm, haftada 3 kendi referansı.
- **Premium:** tüm görünümler, sınırsız referans, her ay yeni görünüm paketleri.
- **Ödeme seçenekleri:** yıllık abonelik ve ömür boyu lisans. Haftalık abonelik yok.

Sunucu maliyeti olmadığı için ömür boyu lisans sürdürülebilir. Pazarlama mesajı: "Abonelik zorunlu değil, fotoğrafların telefonundan çıkmıyor."

**Pazarlar:** İlk kullanıcılar Türkiye'den; gelir ağırlıklı olarak ABD, İngiltere, Kanada ve Avustralya'dan. Türkiye'de fiyat bölgesel ve düşük.

## Kullanıcı senaryoları

### Hikâye 1 — Tek dokunuşla Instagram (P1)

**Kabul senaryoları**
1. **Verilen:** son çekilen fotoğrafın büyük önizlemesi ve Instagram yüklü. **Olduğunda:** "Instagram'a gönder"e dokunulur. **O zaman:** "Gönderi" ve "Hikâye" seçenekleri sunulur.
2. **Olduğunda:** "Gönderi" seçilir. **O zaman:** Instagram, 4:5 fotoğrafla gönderi oluşturma ekranında açılır.
3. **Olduğunda:** "Hikâye" seçilir. **O zaman:** Instagram Hikâye ekranında açılır. 4:5 fotoğraf 9:16 Hikâye alanında yerleşik gösterilir; boşluklar fotoğrafla uyumlu bir arka planla doldurulur.
4. **Verilen:** Instagram yüklü değil. **O zaman:** Instagram düğmesi gösterilmez, yalnızca standart paylaşım menüsü kalır.
5. **Verilen:** Instagram'ın paylaşım yöntemi bir güncelleme sonrası çalışmıyor. **O zaman:** uygulama hata göstermek yerine standart paylaşım menüsüne düşer.

### Hikâye 2 — Kilitli görünüm ve ödeme ekranı (P1)

**Kabul senaryoları**
1. **Verilen:** ücretsiz kullanıcı ve premium bir görünüm. **Olduğunda:** kullanıcı görünümü şeritte seçer. **O zaman:** görünümü kendi canlı görüntüsünde tam olarak görebilir (deneme serbesttir). Deklanşörde kilit işareti vardır.
2. **Olduğunda:** kilitli görünümle deklanşöre basılır. **O zaman:** ödeme ekranı açılır. Kullanıcı ekranı kapatırsa "Doğal" ya da ücretsiz bir görünümle çekmeye devam edebilir. Kamera hiçbir zaman kilitlenmez (Constitution VII).
3. **Verilen:** referans kotası dolmuş (spec 05). **O zaman:** aynı ödeme ekranı açılır.

### Hikâye 3 — Satın alma (P1)

**Kabul senaryoları**
1. **Verilen:** ödeme ekranı. **O zaman:** iki seçenek görünür: yıllık ve ömür boyu. Her birinin yerel para birimindeki fiyatı ve ne içerdiği kısa ve açık şekilde yazılır. Yıllıkta varsa ücretsiz deneme süresi belirtilir. [NEEDS CLARIFICATION: açık soru 1]
2. **Olduğunda:** kullanıcı bir seçeneği seçip Apple'ın onay ekranını onaylar. **O zaman:** premium anında açılır ve kilit işaretleri kaybolur.
3. **Verilen:** satın alma sonrası. **Olduğunda:** uygulama internet yokken açılır. **O zaman:** premium açık kalır; erişim hakkı cihazda doğrulanır.
4. **Verilen:** yeni bir cihaz ya da yeniden kurulum. **Olduğunda:** "Satın alımları geri yükle"ye dokunulur. **O zaman:** önceki satın alma geri gelir.
5. **Verilen:** yıllık abonelik bitmiş. **O zaman:** premium görünümler tekrar kilitlenir. Bu görünümlerle daha önce çekilmiş fotoğraflar etkilenmez. Kullanıcının kendi referans görünümleri silinmez; kota yeniden uygulanır.

### Hikâye 4 — Aylık görünüm paketleri (P2)

**Kabul senaryoları**
1. **Verilen:** yeni bir görünüm paketi yayımlanmış. **Olduğunda:** uygulama açılır ve internet var. **O zaman:** paket arka planda indirilir ve şeritte "yeni" işaretiyle görünür. İndirme isteği kullanıcıya ait hiçbir bilgi taşımaz (Constitution I).
2. **Verilen:** ömür boyu lisans sahibi. **O zaman:** aylık paketler dahildir.
3. **Verilen:** ücretsiz kullanıcı. **O zaman:** yeni paketin görünümleri şeritte görünür ve denenebilir, ama premium olarak işaretlidir. Pakette ücretsiz görünüm bulunup bulunmayacağı paket tanımında belirtilir.
4. **Verilen:** indirme başarısız. **O zaman:** sessizce sonra tekrar denenir. Kullanıcı hata görmez.

### Hikâye 5 — Fotoğrafçı imzalı paketler (P3, yapı hazır, satış ileride)

**Kabul senaryoları**
1. Paket tanımı; fotoğrafçının adını, kısa tanıtımını ve ayrı bir satın alma ürününe bağlanmayı destekler. Bu paketler ömür boyu lisansa dahil değildir. Gelir paylaşımı App Store dışında, sözleşmeyle yürütülür. Uygulama yalnızca hangi paketin satıldığını StoreKit üzerinden bilir.

## Uç durumlar

- Aile Paylaşımı ile gelen erişim hakkı. [NEEDS CLARIFICATION: açık soru 3]
- İade edilen satın almada premium kapanır.
- Bekleyen satın alma (ebeveyn onayı gibi) "bekleniyor" olarak gösterilir.
- Hem yıllık aboneliği hem ömür boyu lisansı olan kullanıcı varsa, aboneliğini nasıl iptal edeceği gösterilir.
- Paket, uygulama sürümünün desteklemediği bir tarif formatı içeriyorsa o görünümler gizlenir.

## Fonksiyonel gereksinimler

- **FR-001:** Instagram'a paylaşım, Instagram'ın üçüncü taraf uygulamalara açtığı resmi paylaşım yolları üzerinden yapılır. Bu yollar çalışmazsa standart paylaşım menüsü kullanılır.
- **FR-002:** Satın almalar StoreKit 2 ile yapılır. Erişim hakkı Apple'ın imzalı işlem bilgisiyle cihazda doğrulanır; kendi sunucumuz yoktur (Constitution I).
- **FR-003:** Erişim hakkı soyutlamasının MVP'deki "her şey açık" uygulaması, StoreKit tabanlı uygulamayla değiştirilir. Soyutlamayı çağıran kodda değişiklik gerekmez (Constitution VII).
- **FR-004:** Ürünler: yıllık abonelik, ömür boyu lisans (tek seferlik), ileride fotoğrafçı paketleri (tek seferlik). Haftalık ya da aylık abonelik yoktur.
- **FR-005:** Fiyatlar App Store Connect'te bölgesel olarak tanımlanır; Türkiye için düşük bölgesel fiyat. Uygulama fiyatları sabit yazmaz, StoreKit'ten okur.
- **FR-006:** Ödeme ekranı; Apple'ın zorunlu tuttuğu bilgileri (yenileme koşulları, gizlilik politikası ve kullanım şartları bağlantıları, geri yükleme) iki dilde içerir.
- **FR-007:** Ödeme ekranında "abonelik zorunlu değil" mesajı ve ömür boyu seçeneği belirgindir.
- **FR-008:** Görünüm paketleri statik içerik olarak indirilir. Paket; tarif dosyaları, örnek görseller ve her görsel için lisans kaydı içerir. Barındırma yöntemi plan aşamasında seçilir.
- **FR-009:** Paket içeriği uygulama tarafından bütünlük açısından doğrulanır. Bozuk ya da imzasız paket yüklenmez.
- **FR-010:** Ücretli sınır hiçbir zaman şunları engellemez: kamera, çekim, kaydetme, ücretsiz görünümler, daha önce çekilmiş fotoğraflar.

## Temel varlıklar

- **Product:** yıllık, ömür boyu, fotoğrafçı paketi.
- **Entitlement:** `free` | `premium` (+ satın alınmış fotoğrafçı paketleri).
- **LookPack:** kimlik, sürüm, yayın tarihi, tarifler, görseller, lisans kayıtları, erişim kuralı, isteğe bağlı fotoğrafçı bilgisi.
- **ShareTarget:** `instagramFeed`, `instagramStory`, `systemShareSheet`.

## Başarı kriterleri

- **SC-001:** Önizlemeden Instagram Gönderi ekranına ≤ 2 dokunuş.
- **SC-002:** Ödeme ekranından satın almanın tamamlanmasına ≤ 3 dokunuş (Apple onayı hariç).
- **SC-003:** Satın alma sonrası premium ≤ 1 sn içinde açılır; internet yokken açık kalır (20/20 deneme).
- **SC-004:** Geri yükleme, StoreKit test ortamında 10/10 denemede başarılı olur.
- **SC-005:** Erişim hakkı mantığı (abonelik bitişi, iade, ömür boyu, paket sahipliği) StoreKit test yapılandırmasıyla otomatik testlerde doğrulanır. Tüm durumlar test edilmiş olmalıdır.
- **SC-006 (iş hedefi, sürüm sonrası):** Lansmandan sonraki 6 ay içinde ödeme ekranını gören kullanıcıların ≥ %3'ü satın alır. Ölçüm yalnızca App Store Connect verisiyle yapılır (uygulama içi analitik yok).

## Elle test listesi

- [ ] Instagram Gönderi ve Hikâye; Instagram yüklü ve yüklü değil
- [ ] Sandbox hesabıyla yıllık ve ömür boyu satın alma, geri yükleme
- [ ] Uçak modunda premium
- [ ] Türkçe ve İngilizce ödeme ekranı; TL ve USD fiyat gösterimi
- [ ] Yeni paketin indirilip şeritte görünmesi

## Açık sorular

1. **Ücretsiz deneme:** Yıllık abonelikte ücretsiz deneme olacak mı (örneğin 7 gün)? Deneme dönüşümü artırır, ama "dürüst fiyatlandırma" mesajıyla gerilim yaratabilir.
2. **Fiyatlar:** Yıllık ve ömür boyu için hedef fiyatlar ne? Öneri (ABD): yıllık 19,99 $, ömür boyu 39,99 $. Türkiye bölgesel fiyatı App Store'un önerdiği seviyenin altında mı olmalı?
3. **Aile Paylaşımı:** Ömür boyu ve yıllık ürünlerde açık olsun mu? Gelir azaltır, ama kullanıcı dostudur.
4. **Hikâye arka planı:** 9:16 Hikâye'de boşluk bulanık fotoğrafla mı, düz renkle mi doldurulmalı?
5. **İlk paketin zamanı:** "Her ay yeni paket" vaadi tek kişilik bir ekip için ağır olabilir. Vaat "her ay" mı, "düzenli olarak" mı yazılmalı?
6. **Ücretsiz görünüm sayısı:** Kategori başına 4–5 görünümün kaçı ücretsiz olmalı? Öneri: 2.
7. **Instagram adının kullanımı:** Uygulama adında ve App Store açıklamasında "Instagram" kelimesinin kullanımı Meta'nın marka kurallarına tabi. Açıklamada "Instagram için" gibi ifadelerin sınırı kontrol edilmeli.
