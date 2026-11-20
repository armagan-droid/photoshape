# Test seti (spec 00)

Gerçek kafe/yemek kareleri ve etiket dosyaları. Uygulama derlemesine girmez. Beyin testleri sete yalnızca `TestSetKit` üzerinden ulaşır.

> **İlk kareyi commit etmeden önce:** `brew install git-lfs && git lfs install`. Görüntüler `.gitattributes` ile LFS'e gider.

## Çekim

- iPhone Kamera uygulaması, HEIC (Ayarlar → Kamera → Biçimler → Yüksek Verimlilik).
- Derinlik verisi için mümkün olduğunca **Portre** modu. `has_depth = true` kotası 10 kare.
- Kötü pozlanmış eşler için aynı sahneyi pozlamayı bilerek kaydırarak (güneş simgesini sürükleyerek) tekrar çek ve aynı `pair_id`'yi ver.
- Dosyaları Mac'e AirDrop ile (orijinal biçimde) aktar ve `TestSet/` altına koy. İstersen alt dizinlere böl (`TestSet/cafe_food/…`). `id` tüm sette benzersiz olmalı.

## Etiketleme

```sh
cd Packages/TestSetKit
swift run testset init-labels      # her etiketsiz kareye boş bir IMG_xxxx.json üretir
swift run testset validate         # hataları, etiketsiz kareleri, kotaları ve dağılımı gösterir
swift run testset validate --strict  # kotalar dolmadıysa da 1 ile çıkar (SC-002 kapısı)
swift run testset schema > /tmp/labels.schema.json   # editör tamamlaması için JSON Schema
```

Örnek etiket dosyası (`IMG_0012.json`):

```json
{
  "id": "IMG_0012",
  "category": "cafe_food",
  "scene_type": "drink_closeup",
  "light": ["window_daylight", "backlit"],
  "exposure": "under",
  "white_balance": "neutral",
  "highlights_clipped": true,
  "sharpness": "sharp",
  "composition": "bad",
  "composition_issue": "subject_cut",
  "people_visible": "hands",
  "pair_id": "latte-pencere",
  "notes": "fincan kenarı kesik"
}
```

Kurallar:
- `light` her zaman bir dizidir.
- `composition_issue` yalnızca `composition = "bad"` olduğunda yazılır ve o zaman zorunludur.
- `has_depth`, `device` ve `lens` yazılmaz, dosyadan okunur.
- Bilinmeyen alan hata verir; yazım hatalarını böyle yakalarız.

Alanların ve kotaların tamamı için bkz. `specs/00-test-seti.md`.

## Testlerde kullanım

```swift
import TestSetKit

let set = try TestSet.locate()   // $PHOTOSHAPE_TESTSET ya da depo kökündeki TestSet/
let dimWarm = set.frames { $0.labels.light.isSuperset(of: [.dim, .warmIndoor]) }
let image = try dimWarm[0].loadImage()
let depth = try dimWarm[0].loadDepth()   // derinlik yoksa nil
```
