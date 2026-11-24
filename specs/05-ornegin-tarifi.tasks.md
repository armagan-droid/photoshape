# Görevler — Spec 05 Hikâye 7: Örneğin tarifi kartı

- [x] T0 Constitution 2.0.0, spec 05 Hikâye 7 / FR-011..017 / SC-007..013, spec 00 üç etiket, netleştirmeler
- [x] T1 TestSetKit: `camera_angle`, `light_direction`, `light_quality` isteğe bağlı alanları (şema + `FrameLabels` + test)
- [x] T2 CompositionKit: elips oturtma ve açı sınıflandırma; sentetik testler (SC-007 sentetik kısmı)
- [x] T3 CompositionKit: ince ışık okuması (üst/alt, kontrast, keskinlik) ve yön/karakter kararı; sentetik testler (SC-008, SC-009 sentetik kısmı)
- [x] T4 CompositionKit: `ExampleReading` (satırlar + en fazla 3 madde, öncelik sırası, ters ışık kuralı); testler; hazır görünümlerle renk/aydınlık (SC-010 sentetik kısmı)
- [x] T5 Metin testi (SC-011): String Catalog'da TR+EN, kelime sınırları
- [x] T6 Test seti ölçüm testleri (SC-007..SC-010); set boşken atlanır
- [x] T7 Uygulama: `Reference`'a açı ve ince ışık okuması; seçimde kart; ikon kartı açar; kart açıkken durum cümlesi yok
- [x] T8 Kart arayüzü + TR/EN metinler
- [x] T9 UI testleri: kart seçimde açılır, ikonla yeniden açılır, karttan Örneklerim'e geçiş, mevcut testler kartı kapatır
- [ ] T10 Cihazda deneme (iPhone 17)

## Hikâye 8: Örneğin ayarları (2026-11-23)
- [x] T11 Spec 05 Hikâye 8, FR-018..FR-023, SC-014..SC-017, netleştirmeler 5–7
- [x] T12 LookKit `ColorStats`: griye yakın yüzeylerin yeşil/mor kayması, patlamış/kararmış oran (eski profillerde boş)
- [x] T13 CompositionKit `ExampleSettings` (EXIF/TIFF; konum ve tarih okunmaz) ve `ExampleMeasurements` (parlaklık EV, kontrast, kırpılma, renk sıcaklığı K, ton kayması); açıklama anahtarları
- [x] T14 Testler: JPEG/HEIC yaz-oku (SC-014), ekran görüntüsünde boş, sıcaklık tek yönlü (SC-016), cümle-sayı tutarlılığı (SC-017), eski profiller; test seti ölçümleri SC-014..SC-016 (set boşken rapor)
- [x] T15 Uygulama: örnek eklenirken kamera bilgisi okunup saklanır; kamera arka ucundan canlı enstantane/ISO/diyafram/beyaz dengesi; kartta "Ayarlar" bölümü, "Kameran" ve "Uygulama" değerleri yan yana; TR/EN metinler, bölgeye göre sayı biçimi
- [x] T16 UI testi: kamera bilgili örnekte "1/125 sn", "ISO 64"; bilgisiz örnekte uydurma değer yok, not ve yaklaşık değerler var
- [ ] T17 Cihazda: kendi çektiğin bir fotoğrafla değerler Fotoğraflar uygulamasının bilgi ekranıyla aynı mı; kart açıkken "Kameran" değerleri canlı değişiyor mu


## Notlar (2026-11-23)
- Paket testleri: 152 (CompositionKit 56, TestSetKit 42, LookKit 26, CaptureKit 22, FrameKit 6). UI testleri: 10.
- Sıcaklık tüm görüntünün ortalamasından değil, griye yakın yüzeylerden okunuyor (`ColorStats.neutralB`). Yoksa turuncu bir yemek fotoğrafı "sıcak" görünürdü.
- Gölge keskinliği konunun iç kısmından ölçülüyor; konunun dış çizgisi ışıktan bağımsız olarak hep keskin olduğu için.
- Test seti boş: SC-007..SC-010 ölçüm testleri şimdilik yalnızca rapor veriyor (en az 10 etiketli kare gerekiyor). Eşikler sentetik verilerle konuldu; gerçek karelerle ayarlanacak.
- Kartın simülatördeki örnekleri yer tutucu çizimler; okumaları gerçek fotoğrafı temsil etmez.

## Test setinde ölçülecek (birleştirmeden önce)
- [ ] SC-007 açı · [ ] SC-008 ışık yönü · [ ] SC-009 yumuşak/sert · [ ] SC-010 `warm_cast` → sıcak

## Elle (iPhone 12, iOS 18)
- [ ] Yeni örnekte kart kendiliğinden açılıyor; Örneklerim'den başka örnek seçince açılıyor; uygulama açılışında açılmıyor
- [ ] İkona dokununca kart açılıyor; "Örneği değiştir" ve "Örneksiz çek" çalışıyor
- [ ] Türkçe ve İngilizce, büyük yazı boyutunda metin taşmıyor; okunamayan satır boş görünmüyor
- [ ] Kart açıkken kamera cümleleri görünmüyor; kartın ışık maddesi kameradaki ışık yönlendirmesiyle çelişmiyor

## Hikâye 9: Cihazdaki dil modeliyle özet (2026-11-24)
- [x] T18 Constitution 2.1.0 (I, IV, V); spec 05 Hikâye 9, FR-024..FR-031, SC-018..SC-022, netleştirme 8, açık sorular 12–14 (varsayılanlarla)
- [x] T19 CompositionKit `ExampleSummaryInput`: kartın gösterdiği satırlardan girdi (gizli satır girmez, sayı yok), sabit talimat metni; testler (SC-018)
- [x] T20 CompositionKit `SummaryChecker`: uzunluk, cümle sayısı, dil (NaturalLanguage), rakam, desteksiz kelime (ışık yönü/yer ayrımı dahil), konunun adını koyma; 38 elle yazılmış özetle testler (SC-019)
- [x] T21 Uygulama: `ExampleSummaryWriter` (yalnızca `SystemLanguageModel`, iOS 26+, dil kontrolü, açgözlü + bir yeniden deneme), özet örnekle dil başına saklanır, kart açılınca eksikse yazılır; kartta "Kısaca" + "Apple Intelligence ile yazıldı"; erişim hakkı `exampleSummary`
- [x] T22 UI testi: denetimden geçen özet görünür, rakamlı özet görünmez; diğer testler modelsiz (`-DisableExampleSummary`) aynen geçer (SC-020)
- [ ] T23 iPhone 17'de: SC-021 (20 örnek, iki dil), SC-022 (≤ 5 sn, önizleme ≥ 30 kare/sn), uçak modunda üretim, büyük yazı

### Notlar (2026-11-24)
- Bu Mac'teki sistem modeli (macOS 27.2) Türkçeyi destekliyor (`supportsLocale`). Açık soru 13 için cihazda da bakılacak.
- Gerçek modelle ölçüm (Mac, 20 olgu kümesi × 2 dil, uygulamanın girdisi ve denetimi): 36/40 denetimden geçti (%90). Ortanca süre 0,5 sn, en uzun 1,4 sn. Reddedilenler gerçek hatalardı: girdide olmayan sol/sağ, 4 cümle.
- Ölçüm sırasında bulunan ve düzeltilen: önden ışığın talimat metni "fotoğrafçının arkasından" diyordu (model "behind" yazıyordu); "aşağıdan bakılarak" diye olmayan bir açı (artık her zaman reddediliyor); konunun yeri "sağda" iken "ışık sağdan" diyen özet kabul ediliyordu ("-dan/-den" halleri artık yalnızca ışık yönü).
- Paket testleri: 168 (CompositionKit 72, TestSetKit 42, LookKit 26, CaptureKit 22, FrameKit 6). UI testleri: 12.
