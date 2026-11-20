# Plan — Spec 00: Etiketli test seti

> `/speckit.plan` çıktısı yerine elle yazıldı (Spec Kit CLI bu makinede kurulu değil). Bağlam: `constitution.md` v1.0.0.

## Kararlar (spec 00 açık soruları)

| # | Soru | Karar | Durum |
|---|---|---|---|
| 1 | Repo boyutu | Set repoda `TestSet/` dizininde yaşar. `.gitattributes` HEIC/JPG dosyalarını Git LFS'e yönlendirir. Makinede `git lfs` henüz kurulu değil; kurulmadan ilk kare commit edilmemeli (`brew install git-lfs && git lfs install`). | Geliştirici onayı bekliyor |
| 2 | Arka plandaki yüzler | Kod etkisi yok. Öneri: çekimde kaçınılır; kaçınılamazsa `people_visible = faces` ve `notes` alanına yazılır. | Ertelendi (süreç) |
| 3 | Tek etiketleyici | Kod etkisi yok. MVP'de tek etiketleyici; `notes` alanı tereddütleri kaydeder. | Ertelendi (süreç) |
| 4 | photoshape kamerasıyla yeniden çekim | Kod etkisi yok; spec 02 planında değerlendirilir. | Ertelendi |

## Yorumlar (spec'te kesin olmayan noktalar)

- **"iyi/kötü çift" kotası:** Aynı `pair_id`'yi taşıyan grupta en az bir kare `exposure = good` ve en az bir kare `exposure ≠ good` ise, ya da aynı şey `composition` için geçerliyse grup bir çift sayılır.
- **`composition_issue`:** `composition = bad` iken zorunludur, `composition = good` iken bulunması hatadır.
- **`light`:** Her zaman dizi olarak yazılır (tek değer de olsa). Boş dizi ve tekrar eden değer hatadır.
- **Bilinmeyen anahtar:** Yazım hatalarını yakalamak için hatadır.
- **Otomatik alanlar** (`has_depth`, `device`, `lens`): JSON'da bulunmaları hatadır; dosyadan ImageIO ile okunur.
- **Desteklenen görüntü türleri:** `heic`, `heif`, `jpg`, `jpeg`, `png` (spec 05 ekran görüntüleri için genişleme payı). Set alt dizinlere bölünebilir; `id` tüm sette benzersizdir.

## Yapı

```
Packages/TestSetKit/            Swift paketi (yalnızca macOS, uygulama derlemesine girmez — FR-006)
  Sources/TestSetKit/           Şema, etiket modeli, yükleyici, doğrulama, kapsam raporu
  Sources/testset/              CLI: validate | schema | init-labels
  Tests/TestSetKitTests/        Test önce; fikstürler çalışma anında üretilir (HEIC + derinlik)
TestSet/                        Gerçek kareler ve etiket dosyaları (FR-001)
scripts/test.sh                 Command Line Tools'ta Swift Testing makro yolu düzeltmesiyle `swift test`
```

- **Şemanın tek kaynağı (FR-002):** `LabelSchema` içindeki alan tablosu. Doğrulama da, `testset schema` ile üretilen JSON Schema (editör tamamlaması için) da bu tablodan türetilir.
- **Erişim noktası (FR-004):** `TestSet.locate()` → `frames(where:)`. Konum `PHOTOSHAPE_TESTSET` ortam değişkeninden ya da depo kökündeki `TestSet/` dizininden bulunur; testlere yol gömülmez.
- **Determinizm (SC-003):** Kareler `id`'ye göre sıralanır; filtre sırası korunur.
- **Bağımlılık:** Yalnızca Foundation, ImageIO, CoreGraphics, UniformTypeIdentifiers. Üçüncü taraf yok (Constitution V).

## Constitution kontrolü

I ✅ (ağ yok) · II n/a (geliştirici aracı) · III n/a · IV ✅ (macOS'ta `swift test`) · V ✅ · VI n/a (kullanıcıya görünen metin yok) · VII n/a · VIII ✅ (tek paket, erken soyutlama yok)
