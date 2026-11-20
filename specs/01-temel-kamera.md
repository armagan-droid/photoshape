# Spec 01 — Temel kamera: çekim, lens seçimi, 4:5 kırpma, kaydetme, paylaşma

> `/speckit.specify` girdisi. Sürüm: **MVP (v1)**. Bağımlılık: yok.

## Ne ve neden

iOS, başka uygulamaların iPhone'un kendi Kamera uygulamasını yönetmesine izin vermiyor. Bu yüzden photoshape'in kendi kamerası olmalı. Bu spec, görünüm ya da akıllı ayar olmadan, sade ama güvenilir bir kamerayı tanımlar. Sonraki bütün özellikler bunun üzerine kurulur.

Kullanıcı için anlamı: uygulamayı açar, telefonu doğrultur, basar, ve Instagram'a hazır 4:5 fotoğraf galerisine düşer.

## Kullanıcı senaryoları

### Hikâye 1 — Açılır ve çeker (P1)

Kullanıcı uygulamayı açar ve canlı kamera görüntüsünü 4:5 çerçeve içinde görür. Deklanşöre basar, fotoğraf galeriye kaydedilir.

**Kabul senaryoları**
1. **Verilen:** kamera izni verilmiş. **Olduğunda:** uygulama açılır. **O zaman:** canlı görüntü 4:5 çerçeveyle gösterilir. Çerçeve dışında kalan alan soluk gösterilir ki kullanıcı neyin kırpılacağını görsün.
2. **Verilen:** canlı görüntü açık. **Olduğunda:** deklanşöre basılır. **O zaman:** kısa bir görsel ve dokunsal geri bildirim verilir. Fotoğraf 4:5 kırpılmış halde galeriye kaydedilir ve köşede küçük bir önizleme belirir.
3. **Verilen:** kaydedilmiş bir fotoğraf. **Olduğunda:** kullanıcı Fotoğraflar uygulamasında "Düzenle → Geri Al" yapar. **O zaman:** kırpılmamış orijinal kare geri gelir.

### Hikâye 2 — Lens seçer (P1)

Kullanıcı "geniş / normal / yakın" düğmelerinden birine dokunur.

**Kabul senaryoları**
1. **Verilen:** cihazda ultra geniş lens var. **Olduğunda:** "geniş"e dokunulur. **O zaman:** görüntü ultra geniş lense geçer. Geçiş sırasında görüntü donmaz ya da kararmaz; en fazla kısa bir yumuşak geçiş olur.
2. **Verilen:** cihazda telefoto lens yok (örneğin iPhone 12). **Olduğunda:** "yakın"a dokunulur. **O zaman:** ana kameradan yakınlaştırılmış görüntü kullanılır. Kullanıcıya fark hissettirilmez.
3. Düğmelerde sayı (0.5×, 2×) gösterilmez. Hangi seçeneğin aktif olduğu görsel olarak bellidir.

### Hikâye 3 — Dokunarak netler (P1)

**Kabul senaryoları**
1. **Verilen:** canlı görüntü. **Olduğunda:** kullanıcı ekranda bir noktaya dokunur. **O zaman:** netlik ve parlaklık o noktaya göre ayarlanır ve dokunulan yerde kısa bir işaret görünür.
2. **Verilen:** dokunarak netlenmiş görüntü. **Olduğunda:** sahne belirgin şekilde değişir (telefon başka yöne çevrilir). **O zaman:** otomatik netlemeye geri dönülür.
3. Netleme kilidini ya da parlaklığı elle ayarlamak için ayrı bir kontrol yoktur (Constitution II).

### Hikâye 4 — Paylaşır (P2)

**Kabul senaryoları**
1. **Verilen:** son çekilen fotoğrafın küçük önizlemesi. **Olduğunda:** kullanıcı önizlemeye dokunur. **O zaman:** fotoğraf büyük gösterilir ve bir "Paylaş" düğmesi sunulur.
2. **Olduğunda:** "Paylaş"a dokunulur. **O zaman:** iOS'un standart paylaşım menüsü açılır ve 4:5 düzenlenmiş fotoğraf paylaşılır. Instagram yüklüyse menüde görünür. Instagram'a özel akış bu spec'te değil, spec 07'dedir.

### Hikâye 5 — İzinler (P1)

**Kabul senaryoları**
1. **Verilen:** ilk açılış. **Olduğunda:** kamera izni istenir. **O zaman:** iznin neden gerektiği tek cümleyle, iki dilde açıklanır.
2. **Verilen:** kamera izni reddedilmiş. **Olduğunda:** uygulama açılır. **O zaman:** boş siyah ekran yerine kısa bir açıklama ve Ayarlar'a giden bir düğme gösterilir.
3. **Verilen:** ilk kaydetme. **Olduğunda:** fotoğraf kaydedilmek istenir. **O zaman:** yalnızca "galeriye ekleme" izni istenir; tam kütüphane izni istenmez.
4. **Verilen:** galeriye ekleme izni reddedilmiş. **Olduğunda:** çekim yapılır. **O zaman:** kullanıcıya fotoğrafın kaydedilemediği ve izni nereden açacağı söylenir. Çekilen kare, oturum boyunca paylaşım için tutulur.

## Uç durumlar

- **Kesintiler:** Telefon araması gelirse, başka bir uygulama kamerayı alırsa ya da Kontrol Merkezi açılırsa canlı görüntü duraklar. Uygulamaya dönüldüğünde kendiliğinden devam eder.
- **Isınma:** Cihaz ısındığında uygulama çökmez. Önizleme kalitesi düşebilir, ama çekim çalışmaya devam eder.
- **Depolama dolu:** Kaydetme başarısız olursa kullanıcıya tek cümleyle söylenir. Kare kaybolmaz; paylaşım için tutulur.
- **Art arda basma:** Deklanşöre hızlıca art arda basılırsa her basış ya bir fotoğraf üretir ya da (çekim devam ediyorsa) yok sayılır. Kuyruk birikip uygulama donmaz.
- **Yönelim:** Uygulama yalnızca dikey kullanılır. Telefon yan tutulsa bile çıktı 4:5 dikeydir. [NEEDS CLARIFICATION: bkz. açık soru 1]
- **Derinlik verisi:** Çekimde mümkünse derinlik verisi de alınır (spec 03'teki bulanıklık için). Derinlik alınamayan lens ya da durumda çekim yine çalışır.

## Fonksiyonel gereksinimler

- **FR-001:** Uygulama açıldığında doğrudan arka kameranın canlı görüntüsüyle başlar. MVP'de görünüm seçim ekranı spec 03 ile eklenir; bu spec'te kamera tek başına çalışır.
- **FR-002:** Canlı görüntü 4:5 çerçeveyi gösterir. Kaydedilen fotoğraf, çerçevede görülen alanla aynıdır.
- **FR-003:** Fotoğraf HEIC olarak, mümkünse derinlik verisiyle çekilir. RAW yoktur.
- **FR-004:** Kaydedilen fotoğraf orijinal kareyi korur. 4:5 kırpma iOS'un düzenleme kaydı olarak eklenir ve Fotoğraflar uygulamasında geri alınabilir.
- **FR-005:** Kaydedilen düzenleme kaydı, uygulamanın kendi tanımlayıcısını ve sürümünü taşır. Spec 03'teki görünüm bilgisi de ileride bu kayda eklenebilmelidir.
- **FR-006:** Kaydedilen fotoğrafa konum eklenmez (Constitution I).
- **FR-007:** Cihazda olmayan lensin düğmesi gösterilmez ya da en yakın karşılıkla çalışır. Kullanıcı hiçbir durumda "bu lens yok" hatası görmez.
- **FR-008:** Arayüzde hiçbir sayı, birim ya da teknik terim yoktur (Constitution II).
- **FR-009:** Tüm metinler Türkçe ve İngilizcedir. Dil, cihaz diline göre seçilir.
- **FR-010:** Kamera bağlantısı, Constitution'daki ortak katman sınırına uygun bir "kare kaynağı" arayüzü üzerinden diğer katmanlara kare verir. Beyin katmanı kameraya doğrudan bağlanmaz.
- **FR-011:** Ses: Deklanşör sesi iOS'un yerel kurallarına uyar. Bazı bölgelerde ses zorunludur; uygulama bunu atlatmaya çalışmaz.

## Temel varlıklar

- **CapturedPhoto:** orijinal kare, varsa derinlik verisi, çekim meta verisi, kırpma bilgisi.
- **LensOption:** `wide`, `normal`, `close`; cihazdaki gerçek karşılığı.
- **EditRecord:** Fotoğraflar uygulamasına yazılan, geri alınabilir düzenleme bilgisi.

## Başarı kriterleri (iPhone 12'de ölçülür)

- **SC-001:** Soğuk açılıştan canlı görüntünün belirmesine kadar geçen süre ≤ 1,5 sn (20 denemenin medyanı).
- **SC-002:** Deklanşöre basmaktan geri bildirime kadar geçen süre ≤ 150 ms. Basmaktan fotoğrafın galeride görünmesine kadar ≤ 2 sn.
- **SC-003:** Lens geçişinde canlı görüntünün kesintisi ≤ 500 ms.
- **SC-004:** 100 çekimlik art arda kullanımda sıfır çökme ve sıfır kayıp kare.
- **SC-005:** Kaydedilen her fotoğrafın en-boy oranı tam 4:5'tir ve Fotoğraflar'da "Geri Al" ile orijinal kare geri gelir (20/20 deneme).
- **SC-006:** Test kullanıcılarından en az 4/5'i, yardım almadan ilk fotoğrafını 30 saniye içinde çeker.

## Elle test listesi

- [ ] İlk açılışta izin akışı (kabul ve red), iki dilde
- [ ] Üç lens düğmesi; telefotolu ve telefotosuz cihazlarda
- [ ] Dokunarak netleme ve sahne değişince otomatiğe dönüş
- [ ] Arama gelmesi, uygulamadan çıkıp dönme
- [ ] Fotoğraflar'da geri alma
- [ ] Paylaşım menüsünden Instagram'a ve WhatsApp'a gönderme

## Açık sorular

1. **Yatay çekim:** Telefon yan tutulduğunda ne olmalı? Seçenekler:
   - (a) yatay tutuşu yok saymak ve dikey 4:5 çekmek (öneri, en basit),
   - (b) "telefonu dik tut" yönlendirmesi göstermek,
   - (c) yatay 1,91:1 çekmek (Instagram destekliyor ama kapsamı büyütür).
2. **"Yakın" kalitesi:** iPhone 12 / 13 / 14 / 15 / 16 standart modellerde telefoto lens yok. "Yakın" ana kameradan kırpma ile yapılırsa çözünürlük düşer. Bu modellerde "yakın" düğmesi gösterilmeli mi?
3. **Galeri ve albüm:** Fotoğraflar ayrı bir "photoshape" albümüne de eklenmeli mi? Bunun için ek izin gerekebilir.
4. **Uygulama içi galeri:** MVP'de yalnızca son çekilen fotoğrafın önizlemesi var. Uygulama içinde bir galeri istiyor muyuz? Öneri: hayır, Fotoğraflar uygulaması yeterli.
5. **Konum:** Constitution açık soru 1 ile aynı.
