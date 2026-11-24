# Plan — Spec 05 Hikâye 7: Örneğin tarifi kartı

> Kapsam: spec 05 Hikâye 7, FR-011..FR-017, SC-007..SC-013. Constitution 2.0.0.

## Mimari

| Parça | Yer | Not |
|---|---|---|
| `ExampleReading` (kartın içeriği) | CompositionKit `Reading.swift` | Girdi: `ColorStats` + `isMonochrome`, `Subject?`, `LightReading?`, `ShotAngleEstimate?`. Çıktı: isteğe bağlı satırlar ve en fazla 3 madde; hepsi cümle anahtarı. Saf, deterministik. |
| Çekim açısı | CompositionKit `Angle.swift` | `ShotAngleEstimator`: Vision kontur algılama → kapalı konturlara elips oturtma (momentlerle) → elips oranı (kısa/uzun eksen). Oran ≥ 0.82 tepeden, 0.32–0.72 eğik, ≤ 0.24 göz hizası; aradaki bantlar ve tutarsız elipsler "emin değil". Saf kısım (`classify(ellipses:)`, `fitEllipse(points:)`) sentetik verilerle test edilir. Vision'ın ufuk algılaması yalnızca yuvarlanma açısını (roll) verir, eğimi vermez; bu yüzden kullanılmadı. Kişili örneklerde elips yoksa satır gizlenir (netleştirme 4). |
| Işığın karakteri | CompositionKit `Light.swift` | `LightReading`'e isteğe bağlı alanlar: `verticalBalance`, `contrast` (konudaki parlak/koyu uç oranı, lineer), `edgeSharpness` (gölge geçişlerinin keskinliği). Bu üçü örnek için 96×120 ince ızgaradan hesaplanır. Canlı yönlendirme eski alanları kullanmaya devam eder. Eski kayıtlar çözülür (alanlar boş). |
| Işık yönü ve karakter kararı | `LightCharacter.classify(_:)` | Ters ışık (oran < 0.55) → arkadan; \|yan\| > 0.12 → soldan/sağdan; üst/alt > 0.15 → tepeden; düz ve kontrast düşük değil → önden; yoksa yön yok. Sert: keskinlik yüksek **ve** kontrast yüksek; yumuşak: keskinlik düşük; arası gizli. |
| Uygulama | `ReferenceStore` | Örnek eklenirken açı ve ince ışık okuması bir kez hesaplanıp `Reference`'a yazılır (FR-017). Konu yoksa ışık orta bölgeden okunur. `selectionCount` her seçimde artar; açılışta artmaz. |
| Kart arayüzü | `ExampleCardView` | Sheet. Satırlar SF Symbol + cümle; "Böyle çek" numaralı maddeler; altta "Örneği değiştir" ve "Örneksiz çek". İkon (chip) kartı açar. Kart açıkken `CameraModel.isShowingCard` → durum cümlesi bildirilmez. |
| Metin kontrolü (SC-011) | CompositionKitTests | `ExampleReading.allPhraseKeys` ile `App/photoshape/Localizable.xcstrings` karşılaştırılır: TR+EN dolu, kelime sınırları. |
| Test seti ölçümü | CompositionKitTests (TestSetKit test bağımlılığı) | `camera_angle`, `light_direction`, `light_quality` etiketli kareler; set boşken test ölçümü atlar ve bunu yazar. |

## Bağımlılıklar
- CompositionKit → LookKit (yalnızca `ColorStats` için). Döngü yok: LookKit bağımsız.
- CompositionKitTests → TestSetKit (yalnızca macOS test hedefi; uygulamaya girmez).

## Eşikler (ilk değerler, test setiyle ayarlanacak)
- Aydınlık: `meanL` > 60 aydınlık, < 40 karanlık, arası "dengeli". Gölgeler: `lowL` < 12 derin, > 30 yumuşak.
- Renk: sıcaklık griye yakın yüzeylerden okunur (`ColorStats.neutralB`, LookKit'e eklendi; eski profillerde boş): > 2 sıcak, < −2 soğuk. Gri yüzey yoksa tüm görüntünün `meanB`'si: > 9 sıcak, < −3 soğuk. `meanChroma` > 18 canlı, < 10.5 soluk. Siyah-beyazda yalnızca "siyah-beyaz". Turuncu bir yemek bu yüzden fotoğrafı "sıcak" yapmaz.
- Konu: alan > 0.40 "kareyi dolduruyor", < 0.08 "küçük"; merkez \|dx\| < 0.12 ortada, yoksa sol/sağ; dikeyde \|dy\| > 0.15 üstte/altta.

## Constitution kontrolü
- I: hepsi cihazda; görüntü saklanmaz, yalnızca okuma değerleri.
- II (2.0.0): kart bilgi ve eylem öğesi; çekim kontrolü eklenmedi.
- III: ışık maddesi yalnızca tavsiye.
- IV: karar mantığı CompositionKit'te, macOS testli.
- V: yalnızca Vision ve Core Graphics.
- VI: tüm cümleler TR+EN, maddeler ≤ 6 kelime (SC-011 testi).
- VIII: yeni soyutlama yok; tek değer tipi.

## Karmaşıklık gerekçesi
Yok.
