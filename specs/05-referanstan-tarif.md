# Spec 05 — Referans ekran görüntüsünden görünüm tarifi çıkarma

> `/speckit.specify` girdisi. Sürüm: **v2 (ana özellik)**. Bağımlılık: 00, 03 (tarif formatı), 04 (sahne türleri), 07 (ücretsiz kota için erişim hakkı).

## Ne ve neden

Vaadin ikinci yarısı: "Beğendiğin fotoğrafı göster." Kullanıcı Instagram'da beğendiği bir gönderinin ekran görüntüsünü alır ve uygulamaya verir. Uygulama bu görüntüden, hazır görünümlerle **aynı formatta** bir tarif çıkarır (spec 03). Kullanıcı bu tarifi kendi sahnesinde, canlı görüntü üzerinde görerek çeker.

Rekabetteki asıl fark budur. "Yapay zekâ fotoğraf koçu" uygulamaları ayar ve kompozisyon öğretir; filtre uygulamaları hazır görünüm satar. Kullanıcının kendi seçtiği referanstan canlı önizlemeli bir tarif çıkaran uygulama az. Premium'a geçişin en güçlü gerekçesi de bu özellik; bu yüzden ödeme ekranıyla (spec 07) aynı sürümde gelir.

**Aktarım kuralları (Constitution III):**
- Renk ve ton havası her sahneye aktarılır.
- Kompozisyon yalnızca referansın sahne türü kullanıcının sahnesiyle uyuşuyorsa aktarılır; uyuşmuyorsa kompozisyon ipuçları kapanır.
- Işık aktarılmaz. Referanstaki ışık tahmin edilip tavsiyeye çevrilir ("bu fotoğraf pencere ışığıyla çekilmiş, pencereye yaklaş").

## Kullanıcı senaryoları

### Hikâye 1 — Ekran görüntüsünden görünüm (P1)

**Kabul senaryoları**
1. **Verilen:** görünüm şeridi. **Olduğunda:** kullanıcı "kendi fotoğrafını ekle"ye dokunur. **O zaman:** sistemin fotoğraf seçicisi açılır; tam kütüphane izni istenmez (Constitution I).
2. **Verilen:** bir Instagram ekran görüntüsü seçilmiş. **Olduğunda:** işlem başlar. **O zaman:** ekran görüntüsündeki uygulama arayüzü (üst çubuk, kullanıcı adı, beğeni düğmeleri, alt menü) ayıklanır ve yalnızca fotoğrafın kendisi kullanılır.
3. **Olduğunda:** tarif çıkarılır. **O zaman:** canlı görüntü yeni görünümle açılır ve referans küçük ikon olarak görünür. Süre ≤ 2 sn (SC-001).
4. **Verilen:** çıkarılmış tarif. **O zaman:** görünüm "Benim görünümlerim" bölümüne kaydedilir ve sonraki oturumlarda kullanılabilir.

### Hikâye 2 — Ekran görüntüsü olmayan referans (P2)

**Kabul senaryoları**
1. **Verilen:** kullanıcı ekran görüntüsü yerine doğrudan bir fotoğraf seçmiş. **O zaman:** arayüz ayıklama adımı atlanır ve fotoğrafın tamamı kullanılır.

### Hikâye 3 — Sahne uyuşmazlığı (P1)

**Kabul senaryoları**
1. **Verilen:** referans `food_top_down`, kullanıcının sahnesi `drink_closeup`. **O zaman:** renk ve ton havası uygulanır, kompozisyon ipuçları kapanır. Kullanıcıya bir hata ya da uyarı gösterilmez.
2. **Verilen:** referans kafe/yemek değil (örneğin bir manzara). **O zaman:** renk havası yine aktarılır. Referansın sahne türü `other` olur ve tarif kompozisyon şablonu taşımaz. Bu durumda yönlendirme, kullanıcının sahnesinin varsayılan şablonuyla yapılır (Constitution III, v1.1.0).

### Hikâye 4 — Referanstaki insanların cilt rengi tarifi bozmaz (P1)

**Kabul senaryoları**
1. **Verilen:** referansta büyük bir yüz ya da el var. **Olduğunda:** tarif çıkarılır. **O zaman:** cilt bölgeleri renk istatistiğinden ayrılır. Tarif, "ten rengini" kullanıcının sahnesine renk kayması olarak taşımaz. Örneğin sıcak tenli bir portre referansı, kullanıcının latte'sini turuncuya çevirmez.

### Hikâye 5 — Ücretsiz kota (P1)

**Kabul senaryoları**
1. **Verilen:** ücretsiz kullanıcı. **O zaman:** son 7 günde en fazla 3 referans eklenebilir. Sayaç Keychain'de tutulur ve yeniden kurulumda sıfırlanmaz. Kalan açık (cihaz sıfırlama gibi) kabul edilir.
2. **Verilen:** kota dolmuş. **Olduğunda:** kullanıcı dördüncü referansı eklemeye çalışır. **O zaman:** ödeme ekranı (spec 07) açılır. Daha önce eklenmiş görünümler kullanılmaya devam eder.
3. **Verilen:** premium kullanıcı. **O zaman:** kota yoktur.

### Hikâye 6 — Yönetim (P2)

**Kabul senaryoları**
1. Kullanıcı kendi görünümünü yeniden adlandırabilir ve silebilir. Silme, kotayı geri iade etmez.
2. Referans görüntünün kendisi yalnızca küçük bir ikon olarak saklanır. Tam boyutu saklanmaz (gizlilik ve depolama).

## Uç durumlar

- **Kötü kaynak:** Düşük çözünürlüklü ya da yoğun sıkıştırılmış ekran görüntüsünde, sıkıştırma bozulmaları tarife gren ya da renk bandı olarak aktarılmaz.
- **Metin ağırlıklı görsel:** Üzerinde büyük yazı bulunan görsellerde (reklam, alıntı) yazı bölgesi istatistikten ayrılır. Görüntünün çoğu yazıysa kullanıcıya "bu görselden görünüm çıkaramadım, başka bir fotoğraf dene" denir.
- **Atlıkarınca gönderi:** Birden fazla fotoğraflı gönderinin ekran görüntüsünde nokta göstergesi ayıklanır ve görünen tek fotoğraf kullanılır.
- **Siyah-beyaz referans:** Tarif siyah-beyaz bir görünüm üretir.
- **Aşırı düzenlenmiş referans:** Aşırı renkli ya da aşırı soluk bir referanstan çıkan tarif, bantlanma veya renk kırılması üretmeyecek şekilde sınırlanır.
- **Karanlık mod:** Instagram koyu ve açık temalarının her ikisinde de arayüz ayıklama çalışır.
- **Diğer uygulamalar:** Pinterest, TikTok ya da başka bir uygulamanın ekran görüntüsünde arayüz ayıklama "en iyi çaba" düzeyindedir. [NEEDS CLARIFICATION: açık soru 3]

## Fonksiyonel gereksinimler

- **FR-001:** Tarif çıkarma bir beyin modülüdür: girdi referans görüntü, çıktı `LookRecipe` (spec 03 formatı, `source = userReference`). macOS'ta test edilebilir.
- **FR-002:** Çıkarma; renk ve ton ayarlarını, sahne türünü (spec 04 listesi), varsa kompozisyon şablonunu ve ışık tavsiyesini üretir.
- **FR-003:** Ekran görüntüsünde uygulama arayüzünü ayıklayıp fotoğraf bölgesini bulan bir adım vardır.
- **FR-004:** Renk istatistiğinde cilt bölgeleri ayrı tutulur. **Yerli boşluk gerekçesi (Constitution V):** Apple'ın saç/cilt/diş gibi semantik bölütleme katmanları yalnızca kamera çekimi sırasında üretilir, kullanıcının yüklediği bir görüntüde kullanılamaz. Vision'ın kişi bölütlemesi kişiyi arka plandan ayırır, ama cildi kıyafetten ve saçtan ayırmaz. Bu yüzden aday çözüm MediaPipe'ın çok sınıflı bölütlemesidir (saç, yüz cildi, vücut cildi, kıyafet, arka plan). Plan aşamasında şunlar belgelenir:
  - (a) lisansın uygunluğu,
  - (b) ağ erişiminin olmaması,
  - (c) uygulama boyutuna etkisi,
  - (d) Vision ile yetinilen basit bir alternatifin (yüz ve el algılama + kişi maskesi) karşılaştırmalı sonucu.
  Yerli alternatif SC-004'ü sağlıyorsa üçüncü taraf kütüphane eklenmez.
- **FR-005:** Referans görüntü ve çıkarılan tarif cihazdan çıkmaz (Constitution I).
- **FR-006:** Kota, erişim hakkı soyutlaması üzerinden sorulur (Constitution VII). Sayaç Keychain'de tutulur.
- **FR-007:** Kullanıcı görünümleri, hazır görünümlerle aynı şeritte, ayrı bir bölümde gösterilir. Kamera ve işleme açısından aralarında fark yoktur.
- **FR-008:** Hazır görünümlerin tarifleri, bu modülün doğrulanmasında referans olarak kullanılır (bkz. SC-002).

## Temel varlıklar

- **ReferenceImage:** kullanıcının seçtiği görüntü (yalnızca işlem süresince tam boyutlu).
- **ExtractedRegion:** ayıklanmış fotoğraf bölgesi.
- **LookRecipe** (`source = userReference`).
- **ReferenceQuota:** son 7 günün sayacı.

## Başarı kriterleri

macOS'ta ölçülenler:
- **SC-001:** iPhone 12'ye denk bir yükte, tek referansın tarife çevrilmesi ≤ 2 sn. (Telefonda da doğrulanır.)
- **SC-002:** Hazır görünümlerin her biri için, o görünümün uygulandığı test karelerinden çıkarılan tarif, test setindeki nötr karelere uygulandığında, elle ayarlanmış asıl tarifin çıktısıyla ortalama ΔE2000 ≤ 5 farkla eşleşir.
- **SC-003:** Instagram ekran görüntüsü test setinde (açık ve koyu tema, tekli ve atlıkarınca gönderi; en az 20 görüntü) fotoğraf bölgesi ≥ %95 oranında doğru ayıklanır. Ayıklanan bölge gerçek fotoğrafla ≥ %95 örtüşür.
- **SC-004:** Ten ağırlıklı referanslardan çıkarılan tarifler, nötr bir kafe karesine uygulandığında, aynı referansın cilt ayırma kapalıyken çıkan tarifine göre belirgin şekilde daha az turuncu kayma üretir (eşik planda).

Kullanıcıyla ölçülenler:
- **SC-005:** Kör değerlendirmede, referans + kullanıcının o tarifle çektiği fotoğraf çiftlerinin ≥ %70'inde değerlendiriciler "havası benziyor" der.
- **SC-006:** 5 test kullanıcısının en az 4'ü, yardım almadan bir ekran görüntüsünden görünüm oluşturup çeker.

## Elle test listesi

- [ ] Açık ve koyu temada Instagram ekran görüntüsü
- [ ] Atlıkarınca gönderi
- [ ] Portre referansı ile kafe sahnesi
- [ ] Kota dolumu ve ödeme ekranına geçiş
- [ ] Uygulamayı silip yeniden kurduktan sonra kotanın korunması

## Açık sorular

1. **Ekran görüntüsü test seti ve telif:** Ayıklamayı test etmek için başkalarının Instagram gönderilerinin ekran görüntüleri gerekir. Bunlar repoda tutulabilir mi? Öneri: yalnızca kendi hesabının ya da izin alınmış hesapların gönderileri.
2. **Kullanıcıya ne söylenmeli?** Kullanıcının başkasının fotoğrafından görünüm çıkarması yasal açıdan sorun değil: fotoğraf kopyalanmıyor, yalnızca renk havası çıkarılıyor ve cihazdan çıkmıyor. Ama App Store incelemesinde ve pazarlama metninde "başkasının fotoğrafını taklit et" gibi bir dil kullanılmamalı. Pazarlama dili nasıl olacak?
3. **Instagram dışı kaynaklar:** Pinterest/TikTok ekran görüntüleri v2 kapsamında mı?
4. **Kota birimi:** "Haftada 3" takvim haftası mı (pazartesi sıfırlanır), yoksa kayan 7 gün mü? Öneri: kayan 7 gün, kullanıcıya "3 gün sonra yeni hakkın açılır" diye gösterilir.
5. **Silme ve kota:** Silinen görünüm kotayı iade etmeli mi? Öneri: hayır, kötüye kullanımı önler.
6. **Paylaşım:** Kullanıcı kendi çıkardığı tarifi bir arkadaşıyla paylaşabilmeli mi (dosya olarak, sunucusuz)? Bu sosyal bir özellik (kapsam dışı), ama tarif formatı buna hazır.
