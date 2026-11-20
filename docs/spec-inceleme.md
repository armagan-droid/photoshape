# Spec paketi incelemesi — 2026-11-20

`/speckit.clarify` öncesi tutarlılık kontrolü. Her madde, kapatıldığında ilgili spec'e ya da constitution'a işlenmelidir.

## Ortam

- **Spec Kit CLI kurulu değil.** `.specify/` dizini de yok. Spec 00 için plan ve görevler elle yazıldı (`specs/00-test-seti.plan.md`, `.tasks.md`).
- **Xcode kurulu değil, yalnızca Command Line Tools var.** Beyin paketleri `swift test` ile test edilebilir (`scripts/test.sh` Swift Testing makro yolunu düzeltir). iOS uygulaması (gövde) Xcode olmadan derlenemez. Spec 01'e başlamadan önce Xcode gerekli.
- **git-lfs kurulu değil** (spec 00 plan kararı 1).

## Constitution ile çelişkiler (karar gerekir)

1. **Spec 04 açık soru 1, öneri (b) ↔ Constitution III.** Constitution "sahne türü uyuşmuyorsa kompozisyon ipuçları kapanır" diyor. Önerilen (b) ise sahnenin varsayılan şablonuna geçilmesi. (b) seçilirse Constitution III'te bir istisna yazılmalı: "tarifin şablonu yoksa sahnenin varsayılanı kullanılır; şablon varsa ve uyuşmuyorsa ipuçları kapanır". Bu, FR-005 ile de tutarlı olur.
2. **Constitution II kontrol listesi kapalı bir liste, ama spec'ler başka dokunulabilir öğeler ekliyor:** son çekim önizlemesi ve "Paylaş" (01), "kendi fotoğrafını ekle", yeniden adlandır ve sil (05), "diğer kareler" (06), "Instagram'a gönder", ödeme ekranı ve geri yükleme (07). Öneri: listenin "çekim ekranındaki kamera kontrolleri" için geçerli olduğu açıkça yazılsın (PATCH ya da MINOR).
3. **Cilt tonu koruma sürümü.** Spec 03 "portre kategorisine (v3+) taşındı" diyor; README ve spec 06 portreyi v4'e koyuyor. Spec 03 "v4" olarak düzeltilmeli.

## Spec'ler arası boşluklar

4. **Spec 02'nin SC-003 ve SC-004 kriterleri, spec 00'da bulunmayan bölge etiketlerine ihtiyaç duyuyor.** SC-003 "nötr referans bölgesi" (beyaz tabak, fincan), SC-004 ise "konu bölgesi" ister. Spec 00'a isteğe bağlı `subject_region` ve `neutral_region` alanları (normalize dikdörtgen) eklenmeli. Eklemek mevcut etiket dosyalarını bozmaz (FR-007). Kareler etiketlenmeden önce karar verilirse kareler ikinci kez açılmaz.
5. **Spec 02 SC-001/SC-002 hareketsiz kare üzerinde ölçülüyor**, ama karar "kameraya uygulanacak hedef değerler" üretiyor. Kararın bir kare üzerinde ölçülebilir bir düzeltme yönü/miktarı da vermesi gerekir. Bu bir plan konusu; spec 02 planında tanımlanmalı.
6. **Spec 04 SC-002 ve spec 00 çift tanımı.** "İyi/kötü çift" hem pozlama hem kompozisyon için kullanılıyor. Spec 00 planında şöyle yorumlandı: aynı `pair_id` içinde `exposure` ya da `composition` iyi/kötü ayrımı varsa grup bir çift sayılır. Spec 04 SC-002 yalnızca kompozisyon çiftlerini saymalı. 5 çiftin bir kısmı kompozisyon çifti olmalı.
7. **Spec 04 açık soru 4 (sınıflandırıcı eğitim verisi).** Create ML kullanılırsa eğitim seti test setinden ayrı olmalı. Bu, spec 00'da ikinci bir set ya da `split` alanı gerektirir. Spec 04 planından önce karar verilmeli.
8. **Spec 05 ↔ 07 karşılıklı bağımlılık** (kota ↔ ödeme ekranı). İkisi aynı sürümde olduğu için sorun yok, ama plan aşamasında önce erişim hakkı (07b) gelmeli.
9. **Spec 06'nın etiket alanları** (`burst_id`, `eyes_closed_count`) ve **spec 05'in ekran görüntüsü seti** (fotoğraf bölgesi doğruluğu) spec 00'ın genişlemeleri olarak yazılmalı. Bunlar v2/v3 işi.

## Küçük düzeltmeler

10. Spec 00'da `id` alanı dosya adıyla aynı olduğu için gereksiz. Tutuldu ve doğrulama aracı tutarlılığını denetliyor.
11. Spec 01 FR-001 ve spec 03 FR-006 birlikte okununca uygulama kamerayla açılıyor ve görünüm şeridi aynı ekranda. Tutarlı.
12. Konum (Constitution açık soru 1) ile görünüm gücünün hatırlanması (Constitution açık soru 2 = spec 03 açık soru 3) iki yerde soruluyor. Tek yerde kapatılmalı.
