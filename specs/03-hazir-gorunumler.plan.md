# Plan — Spec 03: Görünüm tarifi, hazır görünümler, canlı önizleme

> Bağlam: `constitution.md` v1.1.2. Açık sorular spec'teki "Kararlar" bölümünde kapatıldı (2026-11-21).

## Yapı

```
Packages/LookKit/        Beyin (Constitution III, IV). macOS'ta test edilir.
  LookRecipe             Tarif formatı v1 (JSON, sürümlü), doğrulama
  ColorTransform         Tarifin noktasal renk/ton dönüşümü (saf matematik) → 3B LUT
  LookRenderer           Core Image: LUT + vinyet + gren + (derinlik varsa) bulanıklık. Önizleme ve kayıt aynı fonksiyon.
  LookCatalog            Paketle gelen tarifler + "Doğal"; okunamayan tarif atlanır
  ColorScience           sRGB ↔ Lab, ΔE2000 (SC-003; spec 05 de kullanacak)
  Resources/Looks/       5 MVP tarifi (*.look.json) ve yer tutucu örnek görseller + lisans kayıtları
App/photoshape/
  Preview/               İşlenmiş canlı önizleme (Metal görünümü); AVCaptureVideoPreviewLayer'ın yerini alır
  Looks/                 Görünüm şeridi, güç kaydırıcısı, seçim ve gücün hatırlanması
  Access/                Erişim hakkı soyutlaması (Constitution VII); MVP: her şey açık
  Developer/             Tarif ayar ekranı (yalnızca Debug derlemesi)
```

## Teknik kararlar

| Konu | Karar | Gerekçe |
|---|---|---|
| Tarif değerleri | Birimsiz, −1…1 arası normalize değerler (ör. `temperature: 0.15`). Fiziksel karşılıkları yalnızca `LookRenderer`'da. | Spec 05'in tarif çıkarması aynı ölçekte üretir; kullanıcıya sayı gösterilmez (II). |
| Renk işleme | Noktasal kısımlar (pozlama, kontrast eğrisi, parlak/gölge, sıcaklık/ton, doygunluk, canlılık, renk aralıkları, soluk siyah) Swift'te saf fonksiyon olarak yazılır ve 33³'lük 3B LUT'a dökülür. Core Image `CIColorCubeWithColorSpace` uygular. | Tek geçiş, iPhone 12'de canlı önizleme için hızlı. Saf fonksiyon macOS'ta ayrıntılı test edilir; deterministik (FR-003). |
| Görünüm gücü | Güç `s` için tarifin bütün değerleri `s` ile ölçeklenir ve LUT yeniden üretilir (yaklaşık 2 ms, önbellekli). Kaydırma sırasında güç 0,05 adımla önbelleğe alınır. | Güç 0'da kimlik dönüşümü (SC-002); kademesiz geçiş. |
| Gren ve vinyet | Görüntü boyutuna göre ölçeklenir. Gren deterministik desenle yapılır (`CIRandomGenerator` sabit). | Önizleme ile kayıt aynı görünür (SC-003); aynı girdi aynı çıktı. |
| Bulanıklık | Derinlikten konu maskesi (odak düzlemine yakın = net) → `CIMaskedVariableBlur`. Önizlemede düşük çözünürlükte, kayıtta fotoğrafın kendi derinliğiyle. En son yapılır (karar 2). | Performans riski en yüksek parça. |
| Canlı önizleme | Video karesi → `LookRenderer` → `MTKView` (`CIContext` Metal). Kare kaynağı spec 01'deki `FrameSource`. Derinlik için `AVCaptureDepthDataOutput` + eşzamanlayıcı. | Görünümün canlı görünmesi önizleme katmanıyla mümkün değil. |
| Çekim | Orijinal + `LookRenderer` ile işlenmiş 4:5 düzenleme. `EditRecord`'a isteğe bağlı `look { id, version, strength }` eklenir (eski okuyucular yok sayar). | FR-005; Fotoğraflar'da Geri Al orijinali getirir. |
| Erişim hakkı | `Entitlements` protokolü, tek soru: "bu öğe kullanılabilir mi?". MVP: `AllUnlocked`. Debug'da başlatma argümanıyla premium görünümler kilitlenebilir (Hikâye 5.2 testi). | Constitution VII. |
| Hatırlama | Son seçilen görünüm ve görünüm başına güç `UserDefaults`'ta. | Hikâye 1.4, karar 3. Cihazdan çıkmaz. |
| Lisans kontrolü (FR-009) | Her tarifin örnek görseli için lisans kaydı zorunlu. LookKit testi ve uygulama derlemesindeki bir betik eksik kayıtta derlemeyi durdurur. | Lisansı olmayan görsel derlemeye giremez. |
| Geliştirici ekranı | `#if DEBUG`. Tüm parametreler adlı ve sayılı kaydırıcılarla; canlı ya da donmuş kare üzerinde; dışa aktarma paylaşım menüsüyle, içe aktarma dosya seçicisiyle. | Hikâye 4; App Store derlemesine girmez. |

## Kamera ekranı yerleşimi (taslak)

Önizleme üste yaslanır; lens düğmeleri önizlemenin alt kenarının üstünde, görüntünün içinde durur (Apple Kamera gibi). Görünüm şeridi ve güç kaydırıcısı önizlemenin altında. 4:5 dışındaki soluk bantlar korunur (spec 01 Hikâye 1.1).

```
┌────────────────────────────┐
│  Nasıl bir fotoğraf        │  ← soru; ilk açılışta ve şerit kaydırılınca
│  istiyorsun?               │     görünür, sonra solar
├────────────────────────────┤
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  ← 4:5 dışı soluk bant
│                            │
│                            │
│      canlı görüntü         │
│   (seçili görünümle)       │
│                            │
│                            │
│   ( Geniş  Normal  Yakın ) │  ← lens düğmeleri görüntünün içinde
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
├────────────────────────────┤
│ ─────────●──────────       │  ← görünüm gücü (sayı yok)
│ [Doğal][Sabah][Kahve][..]  │  ← görünüm şeridi: örnek ikon + ad
│  ▢           ◯             │  ← son fotoğraf · deklanşör
└────────────────────────────┘
```

## Riskler

- **iPhone 12'de 30 kare/sn:** Elimizde yalnızca iPhone 17 var. Performans iPhone 17'de ölçülür; iPhone 12 için bir test cihazı bulunana kadar SC-004 "kısmen ölçüldü" sayılır.
- **Canlı derinlik:** Her lens ve mesafede gelmez. Gelmezse bulanıklık sessizce atlanır.
- **Renk uzayı:** iPhone Display P3 çeker; LUT sRGB'de uygulanır. Çok doygun renklerde hafif kırpılma olabilir. Testte bantlanma/kırılma ölçülür (SC-001).

## Constitution kontrolü

I ✅ ağ yok, hatırlama cihazda · II ✅ kullanıcı yalnızca görünüm seçimi ve güç kaydırıcısı görür; geliştirici ekranı yalnızca Debug · III ✅ kamera ve işleme tarifin kaynağını bilmez · IV ✅ LookKit macOS'ta test edilir · V ✅ yalnızca Apple çerçeveleri · VI ✅ adlar ve açıklamalar iki dilde · VII ✅ tek erişim hakkı soyutlaması · VIII ✅ izin verilen iki soyutlama dışında yok
