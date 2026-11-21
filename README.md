# photoshape — spec paketi

Kod adı: **photoshape** (ürün adı sonra belirlenecek). Spec dili Türkçe; kod ve teknik terimler İngilizce; kullanıcıya görünen metinler Türkçe + İngilizce.

## Spec Kit'te kullanım

1. `constitution.md` → `/speckit.constitution` (ya da doğrudan `.specify/memory/constitution.md`)
2. Her `specs/0X-*.md` dosyası sırayla → `/speckit.specify`
3. Her spec için `/speckit.clarify`. Dosyaların sonundaki "Açık sorular" ve `[NEEDS CLARIFICATION]` işaretleri bu adımda kapatılır.
4. `/speckit.plan`: `docs/ortak-kamera-paketi.md` plan aşamasına bağlam olarak verilir.
5. `/speckit.tasks` → `/speckit.implement`

## Yol haritası

> **Yön değişikliği (2026-11-21):** İlk sürüm hazır görünümler (filtre şeridi) etrafında kurulmuştu. Cihazda denendiğinde ortaya bir filtre uygulaması çıktı; ürün vaadi bu değil. Uygulama artık **örnek fotoğrafla başlar**: kullanıcı beğendiği fotoğrafı seçer, uygulama kamera ayarlarını o fotoğrafa göre yapar, açı/mesafe ve ışık için yönlendirir ve renk havasını otomatik eşleştirir. Hazır görünüm şeridi kullanıcıya gösterilmez; renk motoru (spec 03) arka planda kalır.

| Sürüm | İçerik | Kategori |
|---|---|---|
| Ön hazırlık | 00 Test seti ve etiketleme | kafe/yemek |
| **v1 (MVP)**, tamamen ücretsiz | 01 Temel kamera · **05 Örnek fotoğraftan tarif (ana akış)** · 02 Akıllı pozlama ve beyaz dengesi (örneğe göre hedefler dahil) · 04 Açı, mesafe ve ışık yönlendirmesi (örneğe göre) · 03 Tarif formatı ve renk motoru (arka planda) | kafe/yemek |
| **v2** | 07 Instagram paylaşımı, ödeme | kafe/yemek |
| **v3** | 06 Seri çekim ve en iyi kare · seyahat/manzara kategorisi | + seyahat |
| **v4** | Arkadaşlarla portre: cilt tonu koruma, ön kamera, gruplarda göz kırpma | + portre |
| İleride | Fotoğrafçı imzalı örnek paketleri (gelir paylaşımı) | — |

Seyahat ve portre kategorileri için spec'ler, o sürümlere gelindiğinde 04'ün yapısı örnek alınarak yazılacak.

## Dosyalar

- `constitution.md`
- `specs/00-test-seti.md`
- `specs/01-temel-kamera.md`
- `specs/02-akilli-pozlama.md`
- `specs/03-hazir-gorunumler.md`
- `specs/04-kafe-kompozisyon.md`
- `specs/05-referanstan-tarif.md`
- `specs/06-seri-cekim.md`
- `specs/07-paylasim-ve-odeme.md`
- `docs/ortak-kamera-paketi.md`
