# Spec 00 — Etiketli test seti ve etiketleme yapısı

> `/speckit.specify` girdisi. Sürüm: MVP öncesi altyapı. Bağımlılık: yok. Diğer bütün "beyin" spec'leri bu sete dayanır.

## Ne ve neden

Uygulamanın "beyni" (pozlama kararı, renk işleme, sahne sınıflandırma, kompozisyon puanlama) Claude Code tarafından telefon olmadan test edilebilmeli (Constitution IV). Bunun için gerçek koşullarda çekilmiş, insan tarafından etiketlenmiş ve repoda yaşayan bir fotoğraf setine ihtiyaç var.

Seti geliştirici kendisi çekecek: ilk aşamada kafe/yemek kategorisinden 30–50 kare. Bu spec şunları tanımlar:
- setin içeriği,
- her kare için zorunlu etiketler,
- zor durumların asgari sayısı,
- setin doğrulanma şekli.

Amaç, her beyin özelliğinin "çalışıyor mu?" sorusuna sayıyla cevap verebilmek.

## Kullanıcı senaryoları

### Hikâye 1 — Geliştirici seti çekip etiketler (P1)

Geliştirici, telefonun kendi Kamera uygulamasıyla HEIC formatında, mümkünse Portre modunda (derinlik verisi için) kafe/yemek fotoğrafları çeker. Her kare için bir etiket dosyası doldurur.

**Kabul senaryoları**
1. **Verilen:** bir kare ve doldurulmuş etiket dosyası. **Olduğunda:** doğrulama aracı çalıştırılır. **O zaman:** eksik ya da geçersiz alan varsa kare adıyla birlikte raporlanır.
2. **Verilen:** etiket dosyası olmayan bir kare. **Olduğunda:** doğrulama çalışır. **O zaman:** kare "etiketsiz" olarak listelenir ve testlerde kullanılmaz.

### Hikâye 2 — Bir beyin testi seti alt kümeye göre kullanır (P1)

Bir test, örneğin "loş ortam ve sarı ışık" etiketli kareleri seçip yalnızca onlar üzerinde çalışabilir.

**Kabul senaryoları**
1. **Verilen:** etiketli bir set. **Olduğunda:** bir test belirli etiket değerleriyle filtreleme ister. **O zaman:** yalnızca o etiketlere sahip kareler döner ve sonuç deterministiktir.

### Hikâye 3 — Set büyüdükçe kapsam raporu üretilir (P2)

Doğrulama aracı, her etiket değerinden kaç kare olduğunu ve zor durum kotalarının dolup dolmadığını raporlar.

## Etiketleme yapısı

Her kare için aynı ada sahip bir etiket dosyası bulunur (örneğin `IMG_0012.heic` + `IMG_0012.json`). Etiketler İngilizce anahtar ve değerlerle yazılır. Serbest not alanı Türkçe olabilir.

| Alan | Zorunlu | Değerler | Açıklama |
|---|---|---|---|
| `id` | evet | dosya adı | Benzersiz |
| `category` | evet | `cafe_food` (ileride `travel`, `portrait`) | Kategori |
| `scene_type` | evet | `drink_closeup`, `food_top_down`, `food_angled`, `table_spread`, `cafe_interior`, `other` | Sahne türü. Spec 04'teki kompozisyon şablonlarıyla aynı liste |
| `light` | evet, birden fazla değer olabilir | `window_daylight`, `outdoor_daylight`, `warm_indoor` (sarı iç mekân), `cool_indoor` (floresan/beyaz LED), `mixed`, `backlit`, `dim` | Işık durumu |
| `exposure` | evet | `good`, `under`, `over` | İnsan yargısı: bu kare iyi pozlanmış mı? |
| `white_balance` | evet | `neutral`, `warm_cast`, `cool_cast`, `green_magenta_cast` | İnsan yargısı: renk kayması var mı? |
| `highlights_clipped` | evet | `true` / `false` | Beyaz tabak, pencere gibi patlamış alan var mı? |
| `sharpness` | evet | `sharp`, `motion_blur`, `focus_miss` | Netlik |
| `composition` | evet | `good`, `bad` | İnsan yargısı |
| `composition_issue` | `composition = bad` ise | `too_close`, `too_far`, `tilted`, `subject_cut`, `cluttered_edges`, `off_center_unintended`, `wrong_angle` | Ana sorun |
| `people_visible` | evet | `none`, `hands`, `faces` | İleride cilt tonu testleri için |
| `has_depth` | otomatik | `true` / `false` | Dosyadan okunur, elle girilmez |
| `device`, `lens` | otomatik | — | Dosyadan okunur |
| `pair_id` | hayır | serbest | Aynı sahnenin farklı denemelerini bağlar (örneğin iyi ve kötü pozlanmış hali) |
| `notes` | hayır | serbest | — |

## Zor durum kotaları (asgari)

Set aşağıdaki kotaları sağlamadan beyin spec'lerinin kabul kriterleri "ölçüldü" sayılmaz:

| Durum | Asgari kare |
|---|---|
| `mixed` ışık (pencere + sarı lamba gibi) | 5 |
| `backlit` (ters ışık: pencere önünde fincan gibi) | 5 |
| `dim` (loş kafe, akşam) | 5 |
| `warm_indoor` (sarı iç mekân ışığı) | 5 |
| `exposure = under` | 4 |
| `exposure = over` | 4 |
| `highlights_clipped = true` | 3 |
| `composition = bad` | 8; her `composition_issue` değerinden en az 1 |
| `has_depth = true` | 10 |
| Her `scene_type` değeri (`other` hariç) | 3 |
| `pair_id` ile eşlenmiş iyi/kötü çift | 5 çift |

Kötü pozlanmış örnekleri elde etmek için aynı sahne, telefonun Kamera uygulamasında pozlama bilerek kaydırılarak tekrar çekilebilir. Böyle kareler `pair_id` ile bağlanır.

## Fonksiyonel gereksinimler

- **FR-001:** Set repoda ayrı ve belirli bir dizinde yaşar ve sürüm kontrolündedir.
- **FR-002:** Her etiket dosyası makine tarafından doğrulanabilir bir şemaya uyar. Şema, yukarıdaki tablonun tek doğru kaynağıdır.
- **FR-003:** Bir doğrulama aracı şunları raporlar: eksik/geçersiz etiketler, etiketsiz kareler, kota doluluk durumu ve her etiket değerinin dağılımı.
- **FR-004:** Beyin testleri sete yalnızca etiketlere göre filtreleme yapan tek bir erişim noktasından ulaşır. Dosya yolları testlere gömülmez.
- **FR-005:** Otomatik alanlar (`has_depth`, `device`, `lens`) dosyanın kendisinden çıkarılır, elle girilmez.
- **FR-006:** Test seti uygulama derlemesine girmez.
- **FR-007:** Set ileride yeni kategoriler (seyahat, portre) ve referans ekran görüntüleri (spec 05) için genişletilebilir. Yeni kategori eklemek mevcut etiket dosyalarını bozmaz.

## Temel varlıklar

- **TestFrame:** görüntü, varsa derinlik haritası, çekim meta verisi.
- **FrameLabels:** yukarıdaki etiketler.
- **CoverageReport:** kota ve dağılım raporu.

## Başarı kriterleri

- **SC-001:** Doğrulama aracı tüm set üzerinde iPhone'a ihtiyaç duymadan, macOS'ta 10 saniyenin altında çalışır.
- **SC-002:** MVP beyin spec'leri (02, 03, 04) ölçülmeden önce set en az 30 kareye ulaşmış ve tüm kotaları sağlamıştır.
- **SC-003:** Aynı set ve aynı kodla iki ardışık test çalıştırması aynı sonucu verir.

## Elle yapılacaklar

- Çekim ve etiketleme geliştirici tarafından yapılır. Kare başına 1–2 dakika hedeflenir.

## Açık sorular

1. **Repo boyutu:** 50 HEIC kare + derinlik verisi yaklaşık 150–250 MB eder. Büyük dosya depolama (örneğin Git LFS) kullanılacak mı, yoksa set repo dışında mı tutulacak? Plan aşamasında karar verilecek; spec'in gereği yalnızca sürümlü olması.
2. **Arka plandaki insanlar:** Kafede başka insanların yüzü kareye girebilir. Repo gizli olsa bile bu kareler sette kalmalı mı, yoksa çekimde kaçınılmalı mı?
3. **Etiket tutarlılığı:** `exposure = good` gibi yargılar kişiseldir. Tek etiketleyici (sen) yeterli mi? Yoksa zor durumlarda ikinci bir kişinin görüşü alınmalı mı?
4. Uygulama hazır olduğunda setin bir kısmı photoshape'in kendi kamerasıyla yeniden çekilmeli mi? Ham çekim meta verisi (uygulamanın verdiği pozlama kararı dahil) ancak o zaman elde edilir.
