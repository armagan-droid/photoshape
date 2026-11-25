# Spec 05 — Referans ekran görüntüsünden görünüm tarifi çıkarma

> `/speckit.specify` girdisi. Sürüm: **v1 (MVP), ana akış** (2026-11-21 yön değişikliğiyle v2'den taşındı). Bağımlılık: 00, 01, 03 (tarif formatı ve renk motoru), 04 (sahne türleri).
>
> **Yön değişikliği (2026-11-21):** Uygulama örnek fotoğrafla açılır (README). Bu spec artık ürünün çekirdeğidir. Değişiklikler:
> - Hikâye 0 eklendi: açılış akışı.
> - Örnekten yalnızca renk değil, **çekim hedefleri** de çıkarılır (FR-009): parlaklık, sıcaklık, sahne türü, çekim açısı, konunun boyutu ve yeri, ışık. Bunlar spec 02'nin ayarlarına ve spec 04'ün yönlendirmelerine girdi olur.
> - Renk havası kullanıcıya filtre olarak sunulmaz; kaydırıcı ya da şerit yoktur. Eşleştirme otomatiktir (FR-010).
> - MVP tamamen ücretsizdir. Kota (Hikâye 5, FR-006) v2'de spec 07 ile birlikte gelir; erişim hakkı soyutlaması MVP'de "açık" yanıtını verir.
> - FR-007 değişti: hazır görünüm şeridi yoktur; kullanıcının örnekleri "Örneklerim" listesinde durur.
>
> **2026-11-23, örneğin tarifi kartı (Constitution 2.0.0):** Uygulama örnekten çıkardıklarını kullanıcıya göstermiyordu; cihaz denemesinde ayarlar hissedilmedi (spec 02, 2026-11-22). Hikâye 7, FR-011..FR-017 ve SC-007..SC-013 eklendi. FR-009'daki çekim açısı ve ışığın karakteri bu kapsamda yazılıyor. Hikâye 0.2 güncellendi: ikona dokunmak kartı açar.
>
> **2026-11-23, örneğin ayarları (Hikâye 8):** Kullanıcı seçtiği fotoğrafın ışık ve pozlama ayarlarını sayılarla görmek istiyor (Constitution 2.0.0 buna izin verir). Açık soru 8 bu hikâyeyle kapsama alındı. FR-018..FR-023, SC-014..SC-017 eklendi.
>
> **2026-11-25, yerleşim:** Kartta asıl işe yarayan "Böyle çek" maddeleri ve "Çekime başla" kaydırmadan görünmüyordu; örnek kamera ekranında yalnızca yazılı bir kapsüldü. "Yerleşim" bölümü eklendi; Hikâye 0.2 Örneklerim düğmesiyle güncellendi.
>
> **2026-11-24, cihazdaki dil modeliyle özet (Hikâye 9):** Açık soru 7 kapsama alındı. Test cihazı iPhone 17 (Apple Intelligence destekli). Kart, destekleyen cihazlarda en üstte örneği 2–3 cümleyle anlatan bir özet gösterir. Özet yalnızca uygulamanın ölçtüklerini anlatır; satırlar ve "Böyle çek" maddeleri bugünkü gibi kural tabanlı kalır. FR-024..FR-031, SC-018..SC-022 eklendi. Constitution 2.1.0 ile onaylandı (2026-11-24).

## Ne ve neden

Vaadin ikinci yarısı: "Beğendiğin fotoğrafı göster." Kullanıcı Instagram'da beğendiği bir gönderinin ekran görüntüsünü alır ve uygulamaya verir. Uygulama bu görüntüden, hazır görünümlerle **aynı formatta** bir tarif çıkarır (spec 03). Kullanıcı bu tarifi kendi sahnesinde, canlı görüntü üzerinde görerek çeker.

Rekabetteki asıl fark budur. "Yapay zekâ fotoğraf koçu" uygulamaları ayar ve kompozisyon öğretir; filtre uygulamaları hazır görünüm satar. Kullanıcının kendi seçtiği referanstan canlı önizlemeli bir tarif çıkaran uygulama az. Premium'a geçişin en güçlü gerekçesi de bu özellik; bu yüzden ödeme ekranıyla (spec 07) aynı sürümde gelir.

**Aktarım kuralları (Constitution III):**
- Renk ve ton havası her sahneye aktarılır.
- Kompozisyon yalnızca referansın sahne türü kullanıcının sahnesiyle uyuşuyorsa aktarılır; uyuşmuyorsa kompozisyon ipuçları kapanır.
- Işık aktarılmaz. Referanstaki ışık tahmin edilip tavsiyeye çevrilir ("bu fotoğraf pencere ışığıyla çekilmiş, pencereye yaklaş").

## Kullanıcı senaryoları

### Hikâye 0 — Örnekle başlar (P1, 2026-11-21)

**Kabul senaryoları**
1. **Verilen:** uygulama ilk kez açılır. **O zaman:** "Nasıl bir fotoğraf çekmek istiyorsun? Beğendiğin bir fotoğrafı seç." sorusu ve "Fotoğraf seç" düğmesi görünür. Örneksiz çekmek için kameraya geçmek de mümkündür.
2. **Verilen:** daha önce örnek seçilmiş. **Olduğunda:** uygulama açılır. **O zaman:** kamera son örnekle hazır gelir; örnek köşede küçük bir ikon olarak görünür. İkona dokunmak örneğin tarifi kartını açar (Hikâye 7); örneği değiştirmek ya da kaldırmak karttan ya da deklanşörün yanındaki Örneklerim düğmesinden yapılır (2026-11-25).
3. **Verilen:** örnek seçilmiş ve kamera açık. **O zaman:** kamera ayarları örneğe göre yapılır (spec 02), açı/mesafe ve ışık yönlendirmeleri örneğe göre verilir (spec 04) ve canlı görüntü örneğin renk havasıyla gösterilir. Kullanıcı hiçbir ayara dokunmaz.

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

### Hikâye 7 — Örneğin tarifi kartı (P1, 2026-11-23)

Kullanıcı örneği seçtiğinde "bu fotoğraf nasıl çekilmiş?" sorusunun cevabını sade bir dille görür. Kart beş okuma satırından ve 2–3 maddelik "Böyle çek" bölümünden oluşur:

| Satır | Söyleyebileceği (örnek cümleler) |
|---|---|
| Işık | nereden geliyor: soldan / sağdan / önden / arkadan / tepeden; karakteri: yumuşak / sert. "Işık soldan, yumuşak geliyor." |
| Aydınlık | aydınlık / karanlık; gölgeler yumuşak / derin. "Aydınlık, gölgeler yumuşak." |
| Renk | sıcak / soğuk / doğal; canlı / soluk; siyah-beyaz. "Sıcak ve canlı renkler." |
| Açı | tepeden / eğik / göz hizası. "Tepeden çekilmiş." |
| Konu | kadrajın ne kadarını kapladığı ve nerede durduğu. "Konu kareyi dolduruyor, ortada." |

**Kabul senaryoları**
1. **Verilen:** kullanıcı bir örnek seçti: yeni bir fotoğraf ya da Örneklerim'den başka bir örnek. **Olduğunda:** örneğin okunması bitti. **O zaman:** kart kendiliğinden açılır. Kartı kapatınca kamera örnekle hazırdır. Uygulama son örnekle açıldığında kart kendiliğinden açılmaz (Hikâye 0.2).
2. **Verilen:** kamera ekranı açık ve örnek seçili. **Olduğunda:** kullanıcı örnek ikonuna dokunur. **O zaman:** aynı kart yeniden açılır. Kartta örneği değiştirmeye ve kaldırmaya götüren düğmeler vardır.
3. **Verilen:** uygulama bir alanı güvenle okuyamadı (örneğin açı belirsiz ya da örnekte konu yok). **O zaman:** o satır gösterilmez. Hata, "bilinmiyor" ya da boş satır görünmez. Hiçbir satır okunamadıysa kart yine açılır ve yalnızca "Böyle çek" bölümünü ve örneğin ikonunu gösterir.
4. **Verilen:** okumalar var. **O zaman:** "Böyle çek" bölümünde en fazla 3 madde yazar ("Işığı soluna al", "Telefonu hafif eğ", "Biraz yaklaş"). Maddeler örneği en çok belirleyen şeyden başlar: önce açı ve konunun yeri, sonra ışık, en son renk (README "Öncelik").
5. **Verilen:** kart açık. **O zaman:** kamera ekranındaki yönlendirme ve durum cümleleri (spec 04, spec 02 FR-010) görünmez. Kart kapanınca normal kuralla geri gelirler.
6. **Verilen:** örnek siyah-beyaz. **O zaman:** renk satırı "Siyah-beyaz." der; sıcak/soğuk yazmaz.

### Yerleşim (2026-11-25)

**Kamera ekranı**
1. Örnek, önizlemenin sol üst köşesinde küçük bir resim olarak durur (eskiden ekranın tepesinde yazılı bir kapsüldü). Dokunmak kartı açar (Hikâye 7.2). Basılı tutmak örneği, bırakılana kadar büyütülmüş gösterir; bu bir bilgi öğesidir, çekimi değiştirmez. Örnek yoksa aynı köşede "örnek seç" simgesi durur ve Örneklerim'i açar.
2. Deklanşörün sağında Örneklerim düğmesi durur: örneği tek dokunuşla değiştirmek ya da kaldırmak için. Bu yeni bir kontrol değildir; kapalı listedeki "örnek fotoğraf seçimi"ne giden ikinci yoldur (Constitution II).
3. Geliştirici derlemelerinde tarif düzenleyici önizlemenin sağ üst köşesine taşınır.

**Kart**
4. Sıra: başlık ve örneğin resmi → özet (Hikâye 9, varsa) → "Böyle çek" maddeleri → "Ayrıntılar".
5. "Ayrıntılar" kapalı başlar ve dokununca açılır. İçinde örneğin ayarları (Hikâye 8) durur. Özet gösteriliyorsa okuma satırları da (Hikâye 7) Ayrıntılar'ın içindedir, çünkü özet onları zaten anlatır. Özet yoksa satırlar "Böyle çek"in altında açık durur.
6. "Çekime başla" düğmesi ile "Örneği değiştir" ve "Örneksiz çek" kartın altında sabittir; kaydırmadan görünür.
7. Hikâye 7'nin kuralları değişmez: okunamayan satır yine görünmez, kart açıkken kamera cümleleri görünmez.

### Hikâye 8 — Örneğin ayarları (P1, 2026-11-23)

Kullanıcı, seçtiği fotoğrafın nasıl bir ışık ve pozlama ayarıyla çekildiğini sayılarla görür. İki tür değer vardır ve kart hangisinin hangisi olduğunu açıkça söyler:

| Tür | Ne zaman | Değerler |
|---|---|---|
| **Çekim değerleri** (gerçek) | Fotoğrafın içinde kamera bilgisi (EXIF) varsa: kendi çektiğin ya da bir fotoğrafçının gönderdiği orijinal dosya | Enstantane (1/125 sn), diyafram (f/1.8), ISO, odak uzaklığı (35 mm karşılığı ve hangi lense denk geldiği), pozlama telafisi (EV), flaş, çeken cihaz |
| **Görüntüden okunanlar** (yaklaşık) | Her örnekte, ekran görüntüsünde de | Parlaklık (orta griye göre ± EV), kontrast (en aydınlık ile en koyu arası, kademe), patlamış ve kararmış alan oranı, renk sıcaklığı (yaklaşık Kelvin) ve yeşil/mor kayma, ışığın yönü ve karakteri (Hikâye 7) |

Instagram ve benzeri uygulamaların ekran görüntülerinde ve indirilen kopyalarında kamera bilgisi bulunmaz; bu örneklerde yalnızca "görüntüden okunanlar" görünür (netleştirme 5).

**Kabul senaryoları**
1. **Verilen:** iPhone ile çekilmiş orijinal bir fotoğraf örnek seçildi. **O zaman:** kartın "Ayarlar" bölümünde enstantane, diyafram, ISO, odak uzaklığı ve pozlama telafisi fotoğrafın kendi bilgisinden okunup gösterilir.
2. **Verilen:** bir Instagram ekran görüntüsü seçildi. **O zaman:** çekim değerleri satırları görünmez; yaklaşık değerler "görüntüden okundu" notuyla görünür. Uydurma bir ISO ya da enstantane gösterilmez.
3. **Verilen:** fotoğraf bilgisinde bir alan eksik (ör. flaş yok). **O zaman:** yalnızca o satır gizlenir (Hikâye 7.3 ile aynı kural).
4. **Verilen:** örnek seçili. **O zaman:** her ayar satırının yanında bu değerin fotoğrafa etkisini anlatan kısa bir açıklama vardır ("1/1000 sn: hareket donmuş", "f/1.8: arka plan bulanık"; netleştirme 6).
5. **Verilen:** örnek seçili ve kamera açık. **O zaman:** kart, uygulamanın bu örnek için kameraya uyguladığı ayarları ve kameranın şu anki değerlerini örnekle yan yana gösterir: uygulamanın parlaklık ayarı (EV), kameranın enstantanesi, ISO'su, diyaframı, lensi ve beyaz dengesi (yaklaşık K). Değerler kart açıkken canlı güncellenir. Kamera ekranına değer şeridi eklenmez (netleştirme 7).
6. Kullanıcı bu değerleri değiştiremez; çekim kontrolleri listesi değişmez (Constitution II, 2.0.0).

### Hikâye 9 — Cihazdaki dil modeliyle örneğin özeti (P2, 2026-11-24)

Kart bugün kısa ve kalıp cümleler kuruyor ("Işık soldan, yumuşak geliyor."). Satırlar doğru ama birbirine bağlanmıyor: kullanıcı fotoğrafın neden böyle göründüğünü tek bir anlatı olarak duymuyor. Apple'ın cihazdaki dil modeli (Foundation Models), uygulamanın zaten ölçtüğü değerleri 2–3 cümlelik doğal bir anlatıya çevirebilir:

> "Işık soldaki pencereden, yumuşak geliyor; bu yüzden gölgeler hafif. Tepeden çekilmiş ve fincan kareyi dolduruyor. Renkler sıcak ama doğal."

Model **yeni bilgi üretmez, yalnızca anlatır.** Girdisi uygulamanın okuması ve ölçümleridir; görüntünün kendisi modele verilmez (netleştirme 8). Model olmayan cihazda kart bugünkü haliyle eksiksizdir.

**Kabul senaryoları**
1. **Verilen:** cihazda dil modeli kullanılabilir ve uygulamanın dilini destekliyor. **Olduğunda:** bir örnek eklenir. **O zaman:** okuma bittikten sonra arka planda özet üretilir ve örnekle birlikte saklanır. Kart, özet hazırsa en üstte gösterir. Özet hazır değilse kart beklemeden açılır; özet hazır olunca yerine oturur (yükleniyor göstergesi yok).
2. **Verilen:** iOS 18–25, Apple Intelligence'ı desteklemeyen bir cihaz, Apple Intelligence kapalı, model henüz indirilmemiş ya da dil desteklenmiyor. **O zaman:** özet bölümü hiç görünmez. Hata, uyarı ya da "Apple Intelligence'ı aç" mesajı gösterilmez. Kart Hikâye 7 ve 8'deki gibidir.
3. **Verilen:** üretilen özet denetimden (FR-027) geçmedi. **O zaman:** bir kez yeniden denenir; yine geçmezse özet gösterilmez. Kullanıcı farkı görmez.
4. **Verilen:** özet gösteriliyor. **O zaman:** özette yazan her şey kartın satırlarıyla aynıdır: satır "ışık soldan" diyorsa özet "sağdan" diyemez; satır gizlenmişse (Hikâye 7.3) özet o konu hakkında bir şey söylemez.
5. **Verilen:** kullanıcı uygulamanın dilini değiştirdi. **Olduğunda:** kart açılır. **O zaman:** eski dildeki özet gösterilmez; yeni dilde bir kez üretilir (1. senaryodaki gibi).
6. Özet bir yönlendirme değildir: "Böyle çek" maddeleri ve canlı yönlendirme özetten etkilenmez.

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
  Yerli alternatif SC-004'ü sağlıyorsa üçüncü taraf kütüphane eklenmez. **2026-11-24:** Önce yerli alternatif uygulandı: Vision kişi maskesi ∩ ten rengi. Sentetik SC-004 geçiyor; gerçek portrelerle ölçüm bekleniyor. MediaPipe eklenmedi (a–c belgelenmedi, gerek kalmadı).
- **FR-005:** Referans görüntü ve çıkarılan tarif cihazdan çıkmaz (Constitution I).
- **FR-006:** Kota, erişim hakkı soyutlaması üzerinden sorulur (Constitution VII). Sayaç Keychain'de tutulur.
- **FR-007:** Kullanıcının örnekleri "Örneklerim" listesinde durur (küçük ikon). Hazır görünüm şeridi yoktur (2026-11-21). Kamera ve işleme açısından örnekten çıkan tarif ile diğer tarifler arasında fark yoktur.
- **FR-008:** Hazır görünümlerin tarifleri, bu modülün doğrulanmasında referans olarak kullanılır (bkz. SC-002). Kullanıcıya gösterilmezler.
- **FR-009:** Çıkarma, tarifin yanında **çekim hedefleri** üretir: hedef parlaklık (tarifin `exposureBias` alanı, spec 02 FR-004), sıcak/soğuk eğilimi, sahne türü, çekim açısı (tepeden / eğik / göz hizası), konunun kareye oranı ve konumu, ışığın türü ve yönü (pencere, ters ışık, loş). Bunlar spec 02 ve spec 04'e girdi olur.
- **FR-010:** Renk havası, kullanıcı hiçbir şey seçmeden canlı önizlemede ve kayıtta uygulanır. Güç kaydırıcısı yoktur; eşleştirmenin ölçüsü tarifin kendisindedir.
- **FR-011 (2026-11-23):** Kartın içeriği tek bir değer tipinden üretilir (`ExampleReading`). Bu tip bir beyin modülündedir: girdi örneğin istatistikleri, konusu ve ışık okuması; çıktı her satır için ya bir okuma ya da "yok", ve sıralı "Böyle çek" maddeleri. macOS'ta test edilir. Arayüz yalnızca bu tipi gösterir; kendi başına karar vermez (Constitution IV).
- **FR-012 (2026-11-23):** **Çekim açısı** (FR-009) örnekten tahmin edilir: tepeden / eğik / göz hizası. Tahmin bir güven değeri taşır; eşiğin altında satır gösterilmez. Kişili örneklerde de aynı üç değer kullanılır ("alttan" yoktur); çizgiler ve ufuk net bir şey söylemiyorsa satır gizlenir. Yöntem planda seçilir. Adaylar: yuvarlak nesnelerin (fincan, tabak) elipsleşme oranı, Vision'ın ufuk ve çizgi/kontur algılaması, kişili örneklerde iskeletin oranları.
- **FR-013 (2026-11-23):** **Işığın karakteri** (spec 04 FR-L1'in genişlemesi): ışık okuması sol/sağ ve ters ışığa ek olarak konunun üst/alt dengesini (tepeden ışık), gölge kenarlarının keskinliğini ve gölge ile ışıklı yer arasındaki farkı ölçer. Bunlardan yön (soldan / sağdan / önden / arkadan / tepeden) ve karakter (yumuşak / sert) çıkarılır. Yön, fotoğrafı çekenin gözünden verilir; bu spec 04 FR-L3'teki "ışık soldan gelsin" yönlendirmesiyle aynı kuraldır. Kart ile canlı yönlendirme aynı okumayı kullanır, bu yüzden birbirleriyle çelişmez.
- **FR-014 (2026-11-23):** Aydınlık ve renk satırları örneğin renk istatistiğinden (`ReferenceProfile`) üretilir. Siyah-beyaz örnekte sıcak/soğuk ve canlı/soluk söylenmez.
- **FR-015 (2026-11-23):** "Böyle çek" maddeleri yönlendirme cümlesidir: en fazla 6 kelime, 4 kelime hedef (Constitution VI). Okuma satırları da kısadır: en fazla 6 kelime. Sayı ve terim yasağı 2.0.0'da kalktı; kart yine de önce fotoğraftan anlamayan birinin anlayacağı cümleyle yazılır. Tüm cümleler String Catalog'da Türkçe ve İngilizcedir. Sol/sağ, telefonu tutan kişinin sol/sağıdır. Kişinin uzuvlarına dair poz maddesi kartta yazılmaz; poz, canlı yönlendirmenin işidir (spec 04 K2, kişinin kendi sol/sağı).
- **FR-016 (2026-11-23):** Işık maddeleri tavsiyedir (Constitution III: ışık değiştirilemez). Kartın yazdığı ışık maddesi, canlı ışık yönlendirmesinin söyleyeceğiyle aynı yöndedir. Örnek ters ışıklıysa kart "ışığı yanına al" yazmaz (spec 04 FR-L3 ile aynı kural).
- **FR-018 (2026-11-23):** Fotoğraf bilgisi (EXIF/TIFF) bir beyin modülünde okunur: girdi görüntünün özellik sözlüğü, çıktı `ExampleSettings` (her alan isteğe bağlı). macOS'ta yazılmış bilgili ve bilgisiz test dosyalarıyla test edilir.
- **FR-019 (2026-11-23):** Yalnızca gösterilecek alanlar saklanır. Konum, tarih ve seri numarası gibi alanlar okunmaz ve saklanmaz (Constitution I; veri zaten cihazdan çıkmaz, ama gerekmeyen kişisel bilgi tutulmaz).
- **FR-020 (2026-11-23):** Görüntüden okunan değerler: parlaklık (ortalama parlaklığın orta griden farkı, EV), kontrast (parlak ve koyu uçlar arası, kademe), patlamış (%) ve kararmış (%) alan, renk sıcaklığı (griye yakın yüzeylerden, yaklaşık K) ve yeşil/mor kayma. Hesap deterministiktir ve `ExampleReading` ile aynı ölçümleri kullanır; kartın cümleleri ile sayıları birbiriyle çelişmez (ör. "Sıcak renkler" yazıyorsa renk sıcaklığı nötrün sıcak tarafındadır).
- **FR-021 (2026-11-23):** Sayılar kullanıcının dil ve bölge biçimiyle yazılır (Türkçede ondalık virgül). Birimler: "sn", "EV", "K", "mm", "%". Yaklaşık değerler yuvarlanır (EV 1/3 kademe, K 100'lük); sahte bir kesinlik gösterilmez.
- **FR-022 (2026-11-23):** Gerçek değerler ve görüntüden okunan değerler ayrı başlıklar altında durur; kullanıcı hangisinin fotoğrafın kendi bilgisi, hangisinin uygulamanın tahmini olduğunu her zaman görür.
- **FR-023 (2026-11-23):** Bu özellikten önce eklenmiş örneklerde fotoğraf bilgisi yoktur (görüntü saklanmadığı için yeniden okunamaz); yalnızca saklanan istatistiklerden hesaplanabilenler gösterilir.
- **FR-017 (2026-11-23):** Okuma örnek eklenirken bir kez yapılır ve örnekle birlikte saklanır; tam boyutlu görüntü yine saklanmaz (Hikâye 6.2). Bu özellikten önce eklenmiş örneklerde okunamayan satırlar gösterilmez (Hikâye 7.3).

- **FR-024 (2026-11-24, Hikâye 9):** Özet yalnızca cihazdaki model (`SystemLanguageModel`) ile üretilir. Apple'ın bulutta çalışan modeli (`PrivateCloudComputeLanguageModel`) ve başka bir bulut hizmeti kullanılmaz (Constitution I). Kullanılabilirlik, model ve dil desteği her üretimden önce sorulur; iOS 26 öncesinde kod yolu hiç çalışmaz.
- **FR-025 (2026-11-24):** Modelin girdisi deterministik bir "özet girdisi"dir: kartın gösterdiği satırların konuları ve değerleri (`ExampleReading`). Gizlenmiş satırlar girdiye girmez. Sayılar (çekim değerleri, yaklaşık değerler) girdiye girmez; onlar kartın "Ayarlar" bölümündedir (Hikâye 8). Girdi bir beyin modülünde kurulur ve macOS'ta test edilir (Constitution IV). Görüntü, örneğin adı ya da kullanıcıya ait başka bir bilgi girdiye girmez.
- **FR-026 (2026-11-24):** Özet en fazla 3 cümle ve 45 kelimedir; uygulamanın dilindedir; fotoğraftan anlamayan birinin anlayacağı dille yazılır. Sayı içermez (FR-025). Kullanıcıya hitap eden emir cümlesi kurmaz (o "Böyle çek"in işi).
- **FR-027 (2026-11-24):** Üretilen her özet gösterilmeden önce deterministik bir denetimden geçer (beyin modülü, macOS'ta test edilir): uzunluk sınırı; dil; rakam yok; konunun ne olduğu (fincan, yemek, kişi) girdide yoksa söylenmez; ışık yönü, sıcak/soğuk, aydınlık/karanlık ve açı sözcükleri girdideki değerlerle çelişmiyor; girdide olmayan konu yok. Denetimden geçemeyen özet gösterilmez (Hikâye 9.3).
- **FR-028 (2026-11-24):** Özet örnek eklenirken bir kez, dil başına üretilir ve örnekle saklanır (FR-017 ile aynı kural). Kartın açılması özeti beklemez. Bu özellikten önce eklenmiş örneklerde özet, kart ilk açıldığında saklanan okumadan üretilir.
- **FR-029 (2026-11-24):** Üretim canlı kamerayı yavaşlatmaz: canlı analiz döngüsünde çalışmaz, düşük öncelikle ve tek seferde bir örnek için çalışır. Kamera açıkken önizleme 30 kare/sn'nin altına düşmez (Ek Kısıtlar).
- **FR-030 (2026-11-24):** Özet, bölüm başlığında modelle yazıldığını belli eden kısa bir ifadeyle gösterilir (ör. "Kısaca"). Kesin ifade netleştirmede seçilir (açık soru 12).
- **FR-031 (2026-11-24):** Modelin talimatı (sistem metni) uygulamaya gömülüdür ve String Catalog dışındadır; kullanıcıya görünmez. Kullanıcıya görünen her sabit metin (başlık vb.) String Catalog'dadır (Constitution VI).
## Temel varlıklar

- **ReferenceImage:** kullanıcının seçtiği görüntü (yalnızca işlem süresince tam boyutlu).
- **ExtractedRegion:** ayıklanmış fotoğraf bölgesi.
- **LookRecipe** (`source = userReference`).
- **ReferenceQuota:** son 7 günün sayacı.
- **ExampleReading:** kartın içeriği: ışık (yön, karakter), aydınlık, renk, açı, konu (boyut, yer) satırları; her biri isteğe bağlı. Sıralı "Böyle çek" maddeleri. Her öğe bir cümle anahtarıdır, metin değildir.
- **ExampleSettings (2026-11-23):** fotoğraf bilgisinden okunan çekim değerleri: enstantane, diyafram, ISO, odak uzaklığı (ve 35 mm karşılığı), pozlama telafisi, flaş, cihaz modeli; hepsi isteğe bağlı.
- **ExampleMeasurements (2026-11-23):** görüntüden okunan yaklaşık değerler: parlaklık farkı (EV), kontrast (kademe), patlamış/kararmış oran, renk sıcaklığı (K), yeşil/mor kayma.
- **ExampleSummaryInput (2026-11-24):** modele giden deterministik girdi: konu → değer listesi, yaklaşık değerler, çekim değerleri, hedef dil.
- **ExampleSummary (2026-11-24):** üretilmiş özet metni, dili, üretildiği model sürümü; örnekle saklanır.
- **ShotAngle:** `topDown`, `angled`, `eyeLevel` + güven.

## Başarı kriterleri

macOS'ta ölçülenler:
- **SC-001:** iPhone 12'ye denk bir yükte, tek referansın tarife çevrilmesi ≤ 2 sn. (Telefonda da doğrulanır.)
- **SC-002:** Hazır görünümlerin her biri için, o görünümün uygulandığı test karelerinden çıkarılan tarif, test setindeki nötr karelere uygulandığında, elle ayarlanmış asıl tarifin çıktısıyla ortalama ΔE2000 ≤ 5 farkla eşleşir.
- **SC-003:** Instagram ekran görüntüsü test setinde (açık ve koyu tema, tekli ve atlıkarınca gönderi; en az 20 görüntü) fotoğraf bölgesi ≥ %95 oranında doğru ayıklanır. Ayıklanan bölge gerçek fotoğrafla ≥ %95 örtüşür.
- **SC-004:** Ten ağırlıklı referanslardan çıkarılan tarifler, nötr bir kafe karesine uygulandığında, aynı referansın cilt ayırma kapalıyken çıkan tarifine göre belirgin şekilde daha az turuncu kayma üretir (eşik planda).

- **SC-007 (2026-11-23, açı):** Açı etiketli (`camera_angle`, spec 00) test karelerinde, kartın gösterdiği açı satırlarının ≥ %85'i etiketle aynıdır ve açı satırı karelerin ≥ %70'inde gösterilir. (İkinci sınır, satırı hep gizleyerek birincinin sağlanmasını önler.) Sentetik görüntülerde (dik ve eğik çizilmiş daireler, ufuk çizgisi) tahmin %100 doğrudur.
- **SC-008 (2026-11-23, ışık yönü):** Işık yönü etiketli (`light_direction`) test karelerinde, gösterilen yön satırlarının ≥ %80'i doğru, satır karelerin ≥ %60'ında gösterilir. Sentetik aydınlatılmış sahnelerde (soldan, sağdan, tepeden, arkadan) %100 doğrudur.
- **SC-009 (2026-11-23, ışığın karakteri):** Yumuşak/sert etiketli (`light_quality`) karelerde gösterilen karakter satırlarının ≥ %80'i doğrudur. Sentetik keskin ve yumuşak gölgelerde %100 doğrudur.
- **SC-010 (2026-11-23, renk ve aydınlık):** Hazır görünümlerin (spec 03) her biri nötr test sahnesine uygulandığında renk ve aydınlık satırları görünümün tanımıyla tutarlıdır (sıcak görünüm "sıcak", siyah-beyaz görünüm "siyah-beyaz", koyu görünüm "karanlık"): 5/5. Test setinde `white_balance = warm_cast` karelerin ≥ %80'inde renk satırı "sıcak" der.
- **SC-011 (2026-11-23, metinler):** Otomatik test: kartın tüm cümle anahtarları String Catalog'da Türkçe ve İngilizce dolu; "Böyle çek" maddeleri her iki dilde ≤ 6 kelime; okuma satırları ≤ 6 kelime.
- **SC-012 (2026-11-23, süre ve kararlılık):** Okuma deterministiktir (aynı örnek → aynı kart). Okuma eklense de tek bir örneğin işlenmesi SC-001'in ≤ 2 sn sınırında kalır.

- **SC-014 (2026-11-23, fotoğraf bilgisi):** Bilinen değerlerle yazılmış test dosyalarında (JPEG ve HEIC) her alan doğru okunur (%100); bilgisi olmayan dosyalarda çekim değerleri boş döner (%100). Test setindeki iPhone karelerinin ≥ %95'inde enstantane, diyafram ve ISO okunur.
- **SC-015 (2026-11-23, parlaklık):** Test setinde `exposure = over` karelerin ≥ %80'inde okunan parlaklık farkı > +0,3 EV, `exposure = under` karelerin ≥ %80'inde < −0,3 EV. `pair_id` ile eşlenmiş pozlama çiftlerinde parlak çekilen kare her zaman daha yüksek değer alır (%100).
- **SC-016 (2026-11-23, renk sıcaklığı):** Sentetik sahnede ısıtma/soğutma arttıkça okunan sıcaklık tek yönde değişir. Test setinde `warm_indoor` ışıklı karelerin ≥ %80'inde okunan sıcaklık `window_daylight` karelerinin ortancasından düşüktür (sarı ışık = düşük K).
- **SC-017 (2026-11-23, tutarlılık):** Kartın cümleleri ile sayıları çelişmez: "aydınlık" yazan örneklerde parlaklık farkı ≥ 0, "karanlık" yazanlarda ≤ 0; "sıcak" yazanlarda sıcaklık nötrün sıcak tarafında (%100, sentetik ve test seti).

- **SC-018 (2026-11-24, girdi):** Özet girdisi deterministiktir (aynı okuma → aynı girdi, %100); gizlenmiş satırların konusu girdide hiç yer almaz (%100).
- **SC-019 (2026-11-24, denetim):** Elle yazılmış en az 30 özet örneğiyle (doğru, çelişen yön/sıcaklık/açı, uydurma sayı, fazla uzun, yanlış dil) denetim doğru olanların hepsini geçirir, hatalıların hepsini reddeder (%100). macOS'ta modelsiz çalışır.
- **SC-020 (2026-11-24, modelsiz):** Model kullanılamadığında kart Hikâye 7–8 testlerinden aynen geçer; mevcut UI testleri değişmeden geçer.

Telefonda (iPhone 17) ölçülenler:
- **SC-021 (2026-11-24):** 20 farklı örnekte, her iki dilde: özetlerin ≥ %90'ı ilk ya da ikinci denemede denetimden geçer. Geçen özetlerde elle okumada kartla çelişen ya da girdide olmayan bilgi içeren özet sayısı 0.
- **SC-022 (2026-11-24):** Örnek eklendikten sonra özetin hazır olması ≤ 5 sn; kartın açılması özet yüzünden gecikmez; üretim sırasında önizleme 30 kare/sn'nin altına düşmez.
Kullanıcıyla ölçülenler:
- **SC-013 (2026-11-23):** 5 test kullanıcısının en az 4'ü kartı okuduktan sonra, sorulduğunda örneğin nasıl çekildiğini kendi sözleriyle doğru anlatır (en az ışık ya da açıdan biri) ve en az bir "Böyle çek" maddesini uygular.
- **SC-005:** Kör değerlendirmede, referans + kullanıcının o tarifle çektiği fotoğraf çiftlerinin ≥ %70'inde değerlendiriciler "havası benziyor" der.
- **SC-006:** 5 test kullanıcısının en az 4'ü, yardım almadan bir ekran görüntüsünden görünüm oluşturup çeker.

## Netleştirmeler (2026-11-23, `/speckit.clarify`)

1. **İkon ne açar?** Kart. Örneği değiştirme ve kaldırma kartın içindedir (Hikâye 0.2, 7.2).
2. **Kart ne zaman kendiliğinden açılır?** Her örnek seçiminde: yeni fotoğraf ya da Örneklerim'den başka bir örnek. Uygulama açılışında açılmaz (Hikâye 7.1).
3. **Doğrulama verisi:** Spec 00'a üç isteğe bağlı etiket eklendi: `camera_angle`, `light_direction`, `light_quality`. Test seti çekilene kadar SC-007..SC-010 sentetik görüntülerle ölçülür. Test setindeki ölçüm birleştirmeden önce yapılır (Geliştirme Akışı 4).
4. **Kişili örneklerde açı:** Aynı üç değer; emin değilse satır gizlenir. "Alttan" eklenmedi.
5. **Kamera bilgisi olmayan örnekler (Hikâye 8):** Yalnızca görüntüden okunan yaklaşık değerler, "yaklaşık" etiketiyle. ISO ve enstantane tahmin edilip gösterilmez.
6. **Açıklamalar (Hikâye 8.4):** Her değerin yanında etkisini anlatan kısa bir açıklama olur.
7. **Kameranın kendi değerleri (Hikâye 8.5):** Kartta örnekle yan yana gösterilir. Kamera ekranında sürekli bir değer şeridi yoktur.
8. **Modele görüntü verilmez (Hikâye 9, 2026-11-24):** iOS 27'de model görüntü alabiliyor, ama görüntüye bakan model kendi okumasını yapar; bu okuma uygulamanın ölçümüyle çelişebilir ve test seti dışında doğrulanamaz. Özet yalnızca ölçülenleri anlatır. Görüntü girdisi ayrı bir hikâyede ve test setiyle ölçülerek düşünülebilir.

## Elle test listesi

- [ ] Açık ve koyu temada Instagram ekran görüntüsü
- [ ] Atlıkarınca gönderi
- [ ] Portre referansı ile kafe sahnesi
- [ ] Kota dolumu ve ödeme ekranına geçiş
- [ ] Uygulamayı silip yeniden kurduktan sonra kotanın korunması
- [ ] Örneğin tarifi kartı (iPhone 12, iOS 18): yeni örnekte kart kendiliğinden açılıyor; ikona dokununca yeniden açılıyor; metin taşmıyor (Türkçe ve İngilizce, büyük yazı boyutu); okunamayan satır boş görünmüyor; kart açıkken kamera cümleleri görünmüyor
- [ ] Örneğin ayarları (iPhone 12): kendi çektiğin bir fotoğrafta enstantane/diyafram/ISO, Fotoğraflar uygulamasının bilgi (ⓘ) ekranındakiyle aynı; ekran görüntüsünde çekim değerleri görünmüyor, yaklaşık değerler görünüyor; Türkçede ondalık virgül
- [ ] Kartın yazdığı ışık maddesi, aynı örnekle kamerada çıkan ışık yönlendirmesiyle çelişmiyor
- [ ] Özet (iPhone 17, Hikâye 9): Türkçe ve İngilizce özet üretiliyor mu (Türkçe desteği `supportsLocale` ile kontrol); Apple Intelligence kapalıyken kart özetsiz, hatasız açılıyor; uçak modunda özet yine üretiliyor (yalnızca cihazda çalıştığının kanıtı); büyük yazı boyutunda özet taşmıyor

## Açık sorular

1. **Ekran görüntüsü test seti ve telif:** Ayıklamayı test etmek için başkalarının Instagram gönderilerinin ekran görüntüleri gerekir. Bunlar repoda tutulabilir mi? Öneri: yalnızca kendi hesabının ya da izin alınmış hesapların gönderileri.
2. **Kullanıcıya ne söylenmeli?** Kullanıcının başkasının fotoğrafından görünüm çıkarması yasal açıdan sorun değil: fotoğraf kopyalanmıyor, yalnızca renk havası çıkarılıyor ve cihazdan çıkmıyor. Ama App Store incelemesinde ve pazarlama metninde "başkasının fotoğrafını taklit et" gibi bir dil kullanılmamalı. Pazarlama dili nasıl olacak?
3. **Instagram dışı kaynaklar:** Pinterest/TikTok ekran görüntüleri v2 kapsamında mı?
4. **Kota birimi:** "Haftada 3" takvim haftası mı (pazartesi sıfırlanır), yoksa kayan 7 gün mü? Öneri: kayan 7 gün, kullanıcıya "3 gün sonra yeni hakkın açılır" diye gösterilir.
5. **Silme ve kota:** Silinen görünüm kotayı iade etmeli mi? Öneri: hayır, kötüye kullanımı önler.
6. **Paylaşım:** Kullanıcı kendi çıkardığı tarifi bir arkadaşıyla paylaşabilmeli mi (dosya olarak, sunucusuz)? Bu sosyal bir özellik (kapsam dışı), ama tarif formatı buna hazır.
7. **Cihazdaki dil modeliyle daha zengin anlatım (2026-11-23, bilerek ertelendi):** Apple'ın cihazdaki modeli (Foundation Models; iOS 26 ve sonrası, Apple Intelligence destekli cihazlar, iPhone 15 Pro ve sonrası) ışığı ve sahneyi daha zengin cümlelerle anlatabilir. Cihazda çalıştığı için Constitution I ile uyumludur. Ancak iOS 18 ve iPhone 12 desteği (Ek Kısıtlar) nedeniyle yalnızca kural tabanlı kartın **üzerine** isteğe bağlı bir katman olabilir; kart onsuz eksiksiz çalışmalıdır. Serbest metnin kısa ve doğru kalmasının nasıl garanti edileceği ayrıca konuşulacak. **2026-11-24:** Hikâye 9 taslağıyla kapsama alındı: model yalnızca ölçülenleri anlatır (FR-025), her özet deterministik denetimden geçer (FR-027).
8. **"Ayrıntılar" bölümü:** Hikâye 8 ile kapsama alındı (2026-11-23).
9–11. Kapatıldı: bkz. Netleştirmeler 5–7 (2026-11-23).
12. **Özetin başlığı (Hikâye 9, FR-030):** Varsayılan (2026-11-24): başlık "Kısaca" / "In short", altında küçük "Apple Intelligence ile yazıldı" / "Written with Apple Intelligence" notu. Geliştirici değiştirebilir.
13. **Türkçe desteği:** Varsayılan (2026-11-24): özet yalnızca modelin desteklediği dillerde görünür (`supportsLocale`); desteklenmeyen dilde kart özetsizdir. iPhone 17'de Türkçe sonucu kontrol edilecek.
14. **Ücretli sınır (Constitution VII):** Varsayılan (2026-11-24): ücretsiz; yine de erişim hakkı soyutlamasından (`exampleSummary`) sorulur.

## Constitution değişikliği

2.1.0 (2026-11-24) olarak işlendi: I (cihazdaki model serbest, Private Cloud Compute yasak), IV (model karar vermez, girdisi ve denetimi beyinde), V (Foundation Models).
