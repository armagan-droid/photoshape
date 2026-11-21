# photoshape Constitution

> Kod adı: **photoshape**. Ürün adı henüz belirlenmedi.
> Bu belge Spec Kit akışında `.specify/memory/constitution.md` olarak kullanılır. Bütün spec, plan, görev ve uygulama adımları bu ilkelere uymak zorundadır. Bir ilkeyle çelişen plan ya da görev, ilke değiştirilmeden kabul edilmez.

## Ürün vaadi

"Beğendiğin fotoğrafı göster, ona benzeyen fotoğrafı birlikte çekelim."

Fotoğraftan anlamayan, Instagram için güzel fotoğraf çekmek isteyen insanlar için bir kamera. Kullanıcı ne istediğini seçer ve deklanşöre basar. Gerisini uygulama düşünür.

## Temel İlkeler

### I. Her şey telefonda, fotoğraflar telefondan çıkmaz (DEĞİŞTİRİLEMEZ)

- Kullanıcıya ait hiçbir veri cihazdan çıkmaz: fotoğraf, referans görüntü, tarif, kullanım bilgisi, cihaz tanımlayıcısı.
- Kullanıcı verisini işleyen bir sunucu yoktur. Bulut tabanlı yapay zekâ kullanılmaz.
- Uygulama içi analitik, reklam SDK'sı ya da veri toplayan üçüncü taraf kod yoktur. Ölçüm için yalnızca App Store Connect istatistikleri ve Apple'ın kendi kilitlenme raporları kullanılır.
- İzin verilen tek ağ trafiği:
  - (a) StoreKit üzerinden Apple ile yapılan satın alma işlemleri,
  - (b) statik görünüm paketlerinin indirilmesi. Bu istekte kullanıcıya ait hiçbir bilgi gönderilmez; içerik herkes için aynıdır. Barındırma yöntemi plan aşamasında seçilir.
- Fotoğraf kütüphanesine erişim mümkün olan en dar izinle yapılır: kaydetmek için yalnızca ekleme izni, referans seçmek için sistem seçicisi (tam kütüphane izni istenmez).
- Kaydedilen fotoğraflara konum bilgisi eklenmez. Bunu açan bir ayar yoktur.

**Gerekçe:** Pazarlama vaadi ("abonelik zorunlu değil, fotoğrafların telefonundan çıkmıyor") ve sunucu maliyetinin sıfır olması, ömür boyu lisansı sürdürülebilir kılar.

### II. Kullanıcı hiçbir teknik ayar görmez

- Arayüzün hiçbir yerinde teknik sayı, birim ya da fotoğrafçılık terimi gösterilmez: ISO, enstantane, EV, Kelvin, f/, "pozlama", "beyaz dengesi", "histogram" gibi. Fiyat ve tarih gibi teknik olmayan bilgiler bu kuralın dışındadır.
- Arayüz öğeleri iki gruptadır. Ayrım ekrana göre değil, öğenin etkisine göre yapılır:
  - **Çekim kontrolleri (kapalı liste):** Fotoğrafın nasıl çekildiğini, nasıl göründüğünü ya da kamera ekranının nasıl davrandığını değiştiren her kontrol ve kalıcı ayar bu gruptadır, hangi ekranda olursa olsun. Tam liste:
    - lens düğmeleri ("geniş / normal / yakın"),
    - dokunarak netleme,
    - tek bir "görünüm gücü" kaydırıcısı,
    - görünüm seçimi ("Doğal" dahil),
    - deklanşör.
    Ayrı bir parlaklık kaydırıcısı yoktur. Bu listeye ekleme yapmak constitution değişikliği gerektirir. Örneğin "yönlendirmeleri kapat" ya da "konumu ekle" gibi bir ayar eklemek de değişiklik gerektirir.
  - **Eylem ve gezinme öğeleri (açık grup):** Çekilmiş bir sonucu kullanan ya da uygulamada dolaşmayı sağlayan öğeler. Örnekler: son çekim önizlemesi, Paylaş, Instagram'a gönder, "diğer kareler"den kare seçimi, "kendi fotoğrafını ekle", görünümü yeniden adlandırma ve silme, ödeme ekranı, satın alımları geri yükleme, izin ve Ayarlar yönlendirmeleri. Bu öğelerin listede olması gerekmez, ama her biri bir spec'te tanımlanmış olmalıdır.
  - Ayrım ölçütü: Öğe, sonraki çekimlerin sonucunu ya da kamera ekranının davranışını değiştiriyorsa çekim kontrolüdür. Var olan bir sonucu kullanıyor ya da yalnızca bir yere götürüyorsa eylem öğesidir.
- Yönlendirmeler ok ve kısa cümleyle verilir: "biraz geri çekil", "telefonu düz tut", "pencereye yaklaş".
- Uygulamanın teknik bir kararı yapamadığı durumlarda (örneğin derinlik verisi yoksa bulanıklığın atlanması) kullanıcıya hata gösterilmez. Uygulama sessizce en iyi alternatifi uygular.
- Geliştirici ekranları bu ilkeden muaftır, ancak yalnızca geliştirici derlemelerinde bulunur, App Store sürümüne girmez.

### III. Görünüm tarifi mimarinin çekirdeğidir

- Ekranda ve kaydedilen fotoğrafta görülen her "görünüm" bir **görünüm tarifinden** (`LookRecipe`) üretilir. Tarif üç bölümden oluşur:
  - renk ve ton ayarları,
  - sahne türü,
  - kompozisyon şablonu (isteğe bağlı).
  Tarife ayrıca ışık tavsiyeleri eşlik edebilir.
- Hazır görünümler önceden hazırlanmış tariflerdir. Kullanıcı referansları çalışma anında tarife çevrilir. Kamera, renk işleme ve yönlendirme katmanları tarifin nereden geldiğini bilmez ve bilmemelidir.
- Tarif sürümlü ve serileştirilebilir bir veridir. Aynı tarif aynı girdiye uygulandığında her zaman aynı çıktıyı verir (deterministik).
- Aktarım kuralları:
  - Renk ve ton havası her sahneye aktarılır.
  - Tarif bir kompozisyon şablonu taşıyorsa şablon yalnızca sahne türleri uyuşuyorsa aktarılır. Uyuşmuyorsa kompozisyon ipuçları kapanır; sahnenin varsayılan şablonuna geçilmez.
  - Tarif kompozisyon şablonu taşımıyorsa aktarılacak bir kompozisyon yoktur. Bu durumda yönlendirme sahnenin kendi varsayılan şablonuyla yapılır. Şablonsuz tarif, "kompozisyon konusunda söz söylemiyor" demektir. Bu nedenle bu durum kuralın istisnası değil, kuralın ikinci koludur.
  - Işık tavsiyesi kompozisyondan bağımsızdır. Kompozisyon ipuçları kapalıyken de gösterilebilir.
  - Işık değiştirilemez, yalnızca tavsiye edilir.

### IV. Beyin gövdeden ayrıdır ve test edilerek yazılır

- Uygulama iki kısımdan oluşur:
  - **Beyin:** tarif çıkarma, pozlama ve beyaz dengesi kararı, renk işleme, sahne sınıflandırma, kompozisyon puanlama, en iyi kare seçimi. Bunlar saf mantık olarak ayrı Swift paket(ler)inde yazılır.
  - **Gövde:** kamera bağlantısı, arayüz, kaydetme, paylaşma, satın alma.
- Beyin modülleri AVFoundation oturumuna, UIKit'e, SwiftUI'ye ya da cihaza bağımlı değildir. Vision ve Core Image kullanabilir, ama testleri macOS üzerinde, cihaz ve simülatör olmadan `swift test` ile çalışmalıdır. Böylece Claude Code beyni kendi başına test edebilir.
- Beyin girdisini somut bir kamera nesnesinden değil, değer tipi olarak alır: görüntü, derinlik haritası, çekim meta verisi, cihaz yönelimi.
- Test önce yazılır. Her beyin davranışı, kullanıcının çektiği etiketli **test seti** (spec 00) üzerinde ölçülebilir bir kabul kriteriyle doğrulanır. Bir spec'in kabul kriteri test setiyle ölçülemiyorsa, spec'te nasıl ölçüleceği ayrıca yazılır.
- Telefonda elle test edilen kısım yalnızca şunlardır: kamera bağlantısı, performans ve kullanım hissi. Her spec bu kısım için kısa bir elle test listesi içerir.

### V. Önce Apple'ın yerli çerçeveleri

- Arayüz SwiftUI, kamera AVFoundation, görüntü analizi Vision, renk işleme Core Image ile yapılır. Satın alma StoreKit 2, fotoğraf kütüphanesi PhotoKit ile yönetilir.
- Üçüncü taraf kütüphane (özellikle ML) ancak şu koşullar sağlanırsa eklenir:
  - (a) yerli çerçevenin karşılamadığı boşluk ilgili spec'te belgelenmiştir,
  - (b) lisansı ticari kullanıma uygundur,
  - (c) ağ erişimi yapmaz ve veri toplamaz,
  - (d) uygulama boyutuna etkisi planda yazılmıştır.
- Bilinen aday: MediaPipe çok sınıflı bölütleme (saç, cilt, kıyafet, arka plan). Kullanıcının yüklediği referans görüntüde cilt bölgesini ayırmak için gerekir, çünkü Apple'ın çekim sırasındaki semantik bölütleme katmanları yüklenen görüntüde çalışmaz. Gerekçesi spec 05'te belgelenir. Kendi kameramızla çekilen karelerde Apple'ın katmanları kullanılır.

### VI. Baştan iki dil

- Kullanıcıya görünen her metin baştan Türkçe ve İngilizce hazırlanır. Kodda sabit yazılmış metin bulunmaz; tüm metinler String Catalog üzerinden gelir.
- Spec'ler Türkçe yazılır. Kod, tip ve dosya isimleri ile teknik terimler İngilizcedir.
- Yönlendirme cümleleri her iki dilde de kısa olmalıdır: en fazla 4 kelime hedeflenir, en fazla 6 kelimeye izin verilir.

### VII. Ücretli sınır baştan tasarlanır

- Her görünüm ve her kısıtlı yetenek (örneğin referans yükleme kotası) baştan bir **erişim seviyesi** taşır: ücretsiz ya da premium.
- Bir özelliğin kullanılabilir olup olmadığı tek bir **erişim hakkı** soyutlaması üzerinden sorulur. MVP'de bu soyutlama "her şey açık" yanıtını verir. Ödeme eklendiğinde (spec 07) yalnızca soyutlamanın arkasındaki uygulama değişir, çağıran kod değişmez.
- Ücretli sınır hiçbir zaman kamerayı, çekimi, kaydetmeyi ya da kullanıcının mevcut fotoğraflarına erişimi engellemez.

### VIII. Küçük, sakin, sürdürülebilir

- Uygulamayı tek bir kişi geliştirip sürdürecek. Hedef, aylık birkaç yüz dolar gelir getiren ve insanların hayatına dokunan kullanışlı bir uygulamadır.
- Her sürüm küçük tutulur. Kapsam büyütmek yerine mevcut deneyim iyileştirilir.
- Erken soyutlama yapılmaz. İzin verilen iki istisna vardır: erişim hakkı sınırı (VII) ve GymSpot ile paylaşılabilecek kamera/analiz katmanının arayüz sınırı (aşağıda).
- Bu uygulama başka bir uygulamanın paketine bağımlı olamaz.

## Ek Kısıtlar

- **Platform:** iOS 18 ve üstü; iPhone 12 ve sonrası. Türkiye'de eski iOS sürümleri yaygın olduğu için iOS 18 desteği bir gerekliliktir, sonradan kaldırılamaz. Daha yeni iOS özellikleri yalnızca iOS 18'de çalışan bir alternatifle birlikte kullanılabilir.
- **Arayüz:** yalnızca dikey kullanım; iPhone (iPad desteği yok).
- **Çekim formatı:** HEIC ve mümkünse derinlik verisi. RAW/ProRAW yok. Video yok.
- **Kaydetme:** Düzenlenmiş hal (görünüm ve 4:5 kırpma) iOS'un düzenleme kaydıyla (adjustment data) kaydedilir. Kullanıcı Fotoğraflar uygulamasında orijinale geri dönebilir.
- **Varsayılan çıktı:** 4:5 dikey.
- **Performans bütçeleri:** iPhone 12'de ölçülür; her spec kendi değerlerini koyar. Genel tavan: görünüm uygulanmış canlı önizleme 30 kare/sn'nin altına düşmez.
- **İçerik lisansı:** Uygulamaya giren her örnek fotoğrafın lisans kaydı vardır (kaynak, lisans türü, atıf yükümlülüğü, tarih). Lisans kaydı olmayan görsel derlemeye giremez.
- **Kapsam dışı:** video, Android, web, bulut tabanlı yapay zekâ, hesap ve giriş sistemi, sosyal özellikler.

## Paylaşılabilir katman (GymSpot)

Geliştirici, aynı anda GymSpot (Muay Thai için kamerayla eskiv ve form koçluğu) adında bir uygulama da yapıyor. İki uygulamada da "kamera → kare analizi → kullanıcıyı doğru konuma yönlendirme" zinciri ortak.

- Bu zincirin **yalnızca arayüz sınırı** tanımlanır: kare kaynağı, analiz sonucu ve yönlendirme talimatı. Ayrıntısı için bkz. `docs/ortak-kamera-paketi.md`.
- photoshape bu sınırı kendi içinde, kendi paketinde uygular. Ortak bir pakete ancak GymSpot iOS'ta da aynı ihtiyaç somutlaşınca çıkarılır. O zaman bile photoshape'in derlenmesi GymSpot'a bağlı olmaz.

## Geliştirme Akışı

1. Spec Kit akışı izlenir: constitution → specify → clarify → plan → tasks → implement.
2. Spec'ler "ne" ve "neden"i anlatır. "Nasıl" plan aşamasına aittir.
3. Spec'teki `[NEEDS CLARIFICATION]` işaretleri ve "Açık sorular" bölümü, plan aşamasından önce `/speckit.clarify` ile kapatılır ya da bilerek ertelendiği yazılır.
4. Her özellik kendi dalında geliştirilir. Birleştirmeden önce şunlar sağlanmalıdır:
   - beyin testleri macOS'ta geçer,
   - spec'in kabul kriterleri test setinde ölçülmüştür,
   - elle test listesi gerçek bir iPhone 12'de (ya da en düşük desteklenen cihazda) işaretlenmiştir.
5. Kabul kriterlerindeki sayısal eşikler, test seti büyüdükçe yalnızca yükseltilebilir. Düşürmek için gerekçe yazılır.

## Yönetim

- Bu constitution diğer bütün belgelerden önce gelir.
- Değişiklikler gerekçesiyle yazılır ve sürüm numarası artırılır:
  - **MAJOR:** ilke kaldırma ya da ilkeyi tersine çevirme,
  - **MINOR:** yeni ilke ya da kısıt,
  - **PATCH:** dil düzeltmesi.
- Plan ve görev incelemelerinde her ilkeye uyum kontrol edilir. İhlal gerekiyorsa plan belgesinde "karmaşıklık gerekçesi" olarak yazılır.

## Değişiklik geçmişi

- **1.1.0 (2026-11-20):**
  - II: Arayüz öğeleri "çekim kontrolleri (kapalı liste)" ve "eylem ve gezinme öğeleri" olarak ikiye ayrıldı; ayrım ölçütü yazıldı. Teknik sayı yasağına fiyat/tarih istisnası eklendi.
  - III: Şablonlu ve şablonsuz tarif için kompozisyon aktarım kuralı netleştirildi; ışık tavsiyesinin kompozisyondan bağımsız olduğu yazıldı.
- **1.1.1 (2026-11-21):**
  - I: Konum açık sorusu kapatıldı. Konum eklenmez ve "konumu ekle" ayarı sunulmaz. Kural değişmedi, yalnızca kesinleşti.
- **1.1.2 (2026-11-21):**
  - II: "Görünüm gücü" kaydırıcısının değeri görünüm başına hatırlanır (spec 03 karar 3). Kontrol listesi değişmedi.

**Version**: 1.1.2 | **Ratified**: 2026-11-19 | **Last Amended**: 2026-11-21

## Açık sorular

1. Statik paket indirmede bile bir IP adresi kaçınılmaz olarak sunucuya ulaşır. Gizlilik metninde bu nasıl ifade edilecek? (Apple'ın barındırması seçilirse soru büyük ölçüde ortadan kalkar.)
2. Uygulama boyutu için bir üst sınır koymak istiyor musun? Türkiye'de hücresel indirmede boyut önemli olabilir. Öneri: ilk sürüm 50 MB altında.
