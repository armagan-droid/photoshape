# Plan — Spec 01: Temel kamera

> Bağlam: `constitution.md` v1.1.1, `docs/ortak-kamera-paketi.md`. Açık sorular spec'teki "Kararlar" bölümünde kapatıldı (2026-11-21).

## Yapı

```
Packages/FrameKit/       Ortak katman sınırı (FR-010): Frame, FrameSource. photoshape'e özgü hiçbir şeye bağlı değil.
Packages/CaptureKit/     Gövdenin saf mantığı, macOS'ta test edilir: 4:5 kırpma geometrisi, lens kataloğu,
                         deklanşör kapısı, düzenleme kaydı (EditRecord), 4:5 çıktının üretimi.
App/photoshape.xcodeproj iOS uygulaması (SwiftUI). Klasörle eşlenen gruplar kullanılır: yeni dosya eklemek proje
                         dosyasını değiştirmeyi gerektirmez.
App/photoshape/          Uygulama: kamera (AVFoundation), önizleme, kaydetme (PhotoKit), paylaşım, izinler, metinler.
App/photoshapeUITests/   Simülatörde çalışan akış testleri (benzetilmiş kamerayla).
```

Paketler uygulamaya yerel SPM bağımlılığı olarak girer. TestSetKit uygulamaya girmez.

## Teknik kararlar

| Konu | Karar | Gerekçe |
|---|---|---|
| Lens geçişi | Mümkünse sanal cihaz (`builtInTripleCamera` → `builtInDualWideCamera` → `builtInDualCamera` → `builtInWideAngleCamera`). Lens değişimi `videoZoomFactor` ile yapılır; cihazın kendi geçiş noktaları (`virtualDeviceSwitchOverVideoZoomFactors`) kullanılır. | Oturum yeniden kurulmaz ve görüntü donmaz (SC-003). |
| Lens eşlemesi | `LensCatalog`: geniş = ultra geniş (yoksa düğme gösterilmez), normal = geniş açı, yakın = telefoto (yoksa normalin 2 katı). Saf fonksiyon, testli. | FR-007, karar 2. |
| 4:5 kırpma | `CropGeometry`: sensörün dikey karesinin (3:4) tam genişliği alınır ve 4:5 yükseklik ortalanır. Önizlemedeki çerçeve ile kaydedilen kırpma **aynı fonksiyondan** hesaplanır. | FR-002. |
| Önizleme | `AVCaptureVideoPreviewLayer`, `resizeAspect` ile 3:4. 4:5 dışı soluk katman. Spec 03 bunu kendi işlenmiş önizlemesiyle değiştirecek. | En sade doğru çözüm. |
| Kare kaynağı | `AVCaptureVideoDataOutput` → `CameraFrameSource: FrameSource`. Spec 01'de tüketicisi yok; arayüz hazır. | FR-010. |
| Çekim | HEVC/HEIC, en yüksek desteklenen boyut, `photoQualityPrioritization = .balanced`, destekleniyorsa derinlik (`embedsDepthDataInPhoto`). Konum hiç eklenmez. | FR-003, FR-006, SC-002. |
| Kaydetme | `PHPhotoLibrary` `.addOnly` izni, ilk kaydetmede istenir. `PHAssetCreationRequest`: orijinal `.photo` kaynağı + `PHContentEditingOutput(placeholderForCreatedAsset:)` (4:5 HEIC, `renderedContentURL(for:)`, `PHAdjustmentData`). HEIC kodlanamazsa (simülatör) düzenleme JPEG olur; fotoğraf hiçbir zaman kaybolmaz. | FR-004: Fotoğraflar'da "Geri Al" orijinali getirir. Belgelenmiş yol. |
| Düzenleme kaydı | `EditRecord` (JSON): biçim sürümü, uygulama sürümü, kırpma dikdörtgeni; ileride tarif kimliği, sürümü ve gücü (spec 03 FR-005). `formatIdentifier` = bundle kimliği. | FR-005. |
| Deklanşör | `ShutterGate`: çekim sürerken basışlar yok sayılır, kuyruk yok. Görsel ve dokunsal geri bildirim basışta hemen verilir. | Uç durum "art arda basma", SC-002. |
| Dokunarak netleme | Netlik ve parlaklık noktası dokunulan yere ayarlanır; `isSubjectAreaChangeMonitoringEnabled` ile sahne değişince sürekli otomatiğe dönülür. | Hikâye 3. |
| Kesinti/ısınma | `wasInterrupted` / `interruptionEnded` gözlenir; uygulama arka plana gidince oturum durur, dönünce başlar. Isınma `.serious` ve üstündeyse önizleme kare hızı düşürülür, çekim sürer. | Uç durumlar. |
| Kaydetme başarısız | Kare oturum boyunca bellekte tutulur ve paylaşılabilir. Kullanıcıya tek cümle gösterilir. | Hikâye 5.4, uç durum "depolama dolu". |
| Paylaşım | `ShareLink`/`UIActivityViewController`, 4:5 JPEG (uyumluluk için; Instagram ve WhatsApp HEIC'i her zaman düzgün işlemiyor). | Hikâye 4. |
| Metinler | `Localizable.xcstrings` ve `InfoPlist.xcstrings`, TR ve EN. Kodda sabit metin yok; anahtarlar kullanılır. | Constitution VI, FR-009. |
| Simülatör | Simülatörde kamera yok. `#if targetEnvironment(simulator)` altında **benzetilmiş kamera** üretilmiş bir kare verir. Kırpma, kaydetme, paylaşma ve geri alma akışı simülatörde uçtan uca çalışır. App Store derlemesine girmez. | Akışın UI testleriyle doğrulanabilmesi. |
| Proje | Elle yazılmış `.xcodeproj` (Xcode 16+ klasör eşlemesi). Üçüncü taraf araç (XcodeGen vb.) yok. | Constitution V. |
| Hedef | iOS 18.0, yalnızca iPhone, yalnızca dikey. Bundle kimliği `App/Config/Base.xcconfig` içinde (`app.photoshape.ios`, yer tutucu). | Ek kısıtlar. |

## Riskler

- **Derinlik + sanal cihaz:** Bazı yakınlaştırma noktalarında derinlik verisi gelmez. Spec gereği çekim yine çalışır (uç durum "derinlik verisi").
- **iOS 18 çalışma ortamı:** Bu makinede yalnızca iOS 27.2 simülatörü var. iOS 18 davranışı gerçek cihazda ya da `xcodebuild -downloadPlatform iOS -buildVersion 18.x` ile doğrulanır.
- **Fotoğraflar'da geri alma** (SC-005) simülatörde UI testiyle doğrulanamaz (Fotoğraflar uygulamasını sürmek gerekir). Kayıtta düzenleme bilgisinin bulunduğu simülatörde doğrulanır, geri alma elle test listesinde kalır.

## Constitution kontrolü

I ✅ konum yok, yalnızca ekleme izni, ağ yok · II ✅ yalnızca lens, dokunarak netleme, deklanşör; sayı yok · III n/a (spec 03) · IV ✅ saf mantık paketlerde, macOS'ta test · V ✅ yalnızca Apple çerçeveleri · VI ✅ String Catalog TR/EN · VII n/a · VIII ✅ FrameKit, docs/ortak-kamera-paketi.md'deki izin verilen sınırdır; başka soyutlama yok
