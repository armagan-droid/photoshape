# Spec 06 — Seri çekim ve en iyi kareyi otomatik seçme

> `/speckit.specify` girdisi. Sürüm: **v3** (seyahat kategorisiyle birlikte). Bağımlılık: 00 (genişletilmiş test seti), 01, 03.

## Ne ve neden

Fotoğraftan anlamayan kullanıcının en sık kaybı ayar değil, andır: el titrer, konu kıpırdar, birinin gözü kapanır. Kullanıcı tek bir deklanşör basışıyla birkaç kare çeker. Uygulama bulanık ve (yüz varsa) gözü kapalı kareleri eler ve en iyisini kaydeder. Kullanıcı hiçbir seçim yapmak zorunda kalmaz. İsterse seçimi değiştirebilir.

Seyahat ve manzarada (v3) hareketli insanlar ve rüzgâr gibi sorunlar vardır. Portrede (v4) göz kırpma ana sorundur. Bu yüzden bu özellik kafe/yemekten sonra gelir.

## Kullanıcı senaryoları

### Hikâye 1 — Tek basış, en iyi kare (P1)

**Kabul senaryoları**
1. **Verilen:** seri çekim etkin. **Olduğunda:** deklanşöre bir kez basılır. **O zaman:** kısa bir anda birden fazla kare çekilir. Kullanıcı tek bir çekim hissi yaşar: tek ses, tek geri bildirim.
2. **Olduğunda:** seçim tamamlanır. **O zaman:** en iyi kare görünüm uygulanmış halde galeriye kaydedilir.
3. **Verilen:** karelerin hepsi bulanık. **O zaman:** en az bulanık kare kaydedilir. Spec 04'ün yönlendirme kanalıyla "telefonu sabit tut" tavsiyesi verilir.

### Hikâye 2 — Gözü kapalı kareyi eler (P1, yüz varsa)

**Kabul senaryoları**
1. **Verilen:** karelerde bir ya da daha fazla yüz var. **O zaman:** gözü kapalı yüz içeren kareler, gözü açık bir kare varsa seçilmez.
2. **Verilen:** birden fazla kişi var ve hiçbir karede herkesin gözü açık değil. **O zaman:** gözü açık kişi sayısı en fazla olan kare seçilir.

### Hikâye 3 — Kullanıcı seçimi değiştirir (P2)

**Kabul senaryoları**
1. **Verilen:** son çekimin önizlemesi açık. **Olduğunda:** kullanıcı "diğer kareler"e dokunur. **O zaman:** serinin diğer kareleri gösterilir ve kullanıcı başka birini seçebilir. Seçim galerideki fotoğrafı değiştirir ya da yeni bir fotoğraf ekler. [NEEDS CLARIFICATION: açık soru 2]

### Hikâye 4 — Ne zaman seri çekilir? (P1)

**Kabul senaryoları**
1. Seri çekim kullanıcının açıp kapattığı bir ayar değildir (Constitution II). Uygulama, sahneye göre (hareket, yüz varlığı, loş ortam) seri çekip çekmeyeceğine kendisi karar verir. [NEEDS CLARIFICATION: açık soru 1]

## Uç durumlar

- Bellek baskısı ya da ısınma durumunda seri çekim sessizce tek kareye düşer.
- Kaydetme sırasında uygulama arka plana alınırsa seçilen kare yine kaydedilir.
- Loş ortamda seri kareler gürültü azaltma için birleştirilebilir (spec 02 açık soru 2). Bu spec yalnızca seçimi tanımlar; birleştirme ayrı bir karardır.
- Seri karelerin seçilmeyenleri cihazda en fazla oturum süresince tutulur.

## Fonksiyonel gereksinimler

- **FR-001:** Kare puanlaması beyin modülünde yapılır: girdi kare dizisi + yüz/göz bilgisi, çıktı sıralama ve gerekçe (`sharp`, `motion_blur`, `focus_miss`, `eyes_closed`). macOS'ta test edilebilir.
- **FR-002:** Netlik değerlendirmesi, konu bölgesinin netliğine öncelik verir. Kasıtlı arka plan bulanıklığı "bulanık kare" sayılmaz.
- **FR-003:** Seçim, en iyi karenin kaydedilmesini tek bir karenin kaydedilmesinden algılanabilir ölçüde geciktirmez (SC-003).
- **FR-004:** Seri çekim kararı (çek/çekme ve kare sayısı) beyin modülünde verilir ve kullanıcıya ayar olarak gösterilmez.
- **FR-005:** Seçilmeyen kareler, kullanıcı istemedikçe galeriye kaydedilmez.

## Temel varlıklar

- **BurstSequence:** kare dizisi + çekim meta verisi.
- **FrameQuality:** netlik, göz durumu, toplam puan.
- **BurstSelection:** seçilen kare + gerekçe.

## Başarı kriterleri

macOS'ta, genişletilmiş test setinde ölçülenler. Bu kriterler için sete etiketli seri çekimler eklenir: her seride en az bir `sharp` kare ve bulanık/gözü kapalı kareler.
- **SC-001:** Seride en az bir `sharp` kare varsa, seçilen kare ≥ %95 oranında `sharp` etiketlidir.
- **SC-002:** Seride gözü açık bir kare varsa, seçilen kare ≥ %95 oranında gözü kapalı kişi içermez.

iPhone 12'de ölçülenler:
- **SC-003:** Seri çekimde deklanşörden galeriye ulaşma süresi ≤ 3,5 sn.
- **SC-004:** 50 seri çekimlik kullanımda sıfır çökme ve bellek uyarısı nedeniyle sıfır kayıp çekim.

## Elle test listesi

- [ ] Yürürken çekim
- [ ] İki kişilik grup, göz kırpma
- [ ] Loş ortamda seri
- [ ] "Diğer kareler" ile seçim değiştirme

## Açık sorular

1. **Seri çekim kararı:** Her çekim seri mi olmalı (en basiti; depolama ve pil maliyeti var), yoksa uygulama sahneye göre mi karar vermeli? Öneri: hareket ya da yüz varsa seri, hareketsiz yemekte tek kare.
2. **Seçim değişikliği:** "Diğer kareler"den seçim galerideki fotoğrafın yerine mi geçmeli (bu, galeride düzenleme izni gerektirir), yoksa ikinci bir fotoğraf olarak mı eklenmeli?
3. **Göz değerlendirmesi:** Vision'ın yüz noktaları göz kapalılığını doğrudan vermiyor; göz noktalarından türetilmesi gerekebilir. Doğruluk yetersiz kalırsa bu, Constitution V kapsamında belgelenmiş bir boşluk sayılır mı?
4. **Test seti genişlemesi:** Seri çekim etiketleri için spec 00'a hangi alanlar eklenmeli? Öneri: `burst_id`, kare başına `sharpness` ve `eyes_closed_count`.
