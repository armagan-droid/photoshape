# Görevler — Spec 07 (paylaşım ve ödeme)

## 07a Paylaşım (2026-11-24)
- [x] T1 CaptureKit `StoryComposer`: 4:5 fotoğraf 1080 × 1920 Hikâye tuvalinde, boşluk aynı fotoğrafın bulanık ve hafif koyulaştırılmış hali (açık soru 4 varsayılanı); test
- [x] T2 Kayıtta galeri kimliği (`PHObjectPlaceholder.localIdentifier`) saklanır; ekleme izni yeter
- [x] T3 İnceleme ekranında "Instagram'a gönder" (Instagram yüklüyse, `LSApplicationQueriesSchemes`): Gönderi → `instagram://library?LocalIdentifier=…`; Hikâye → panoya arka plan görseli + `instagram-stories://share` (yalnızca Meta uygulama kimliği varsa); başarısızlıkta standart paylaşım menüsü (Hikâye 1.5)
- [x] T4 UI testleri: Instagram yokken yalnız standart paylaşım (1.4); Instagram varken iki dokunuşta Gönderi (SC-001), kimlik yokken Hikâye yok, çalışmayınca paylaşım menüsü
- [ ] Meta uygulama kimliği kaydı (geliştirici) ve `FACEBOOK_APP_ID`
- [ ] Cihazda: Instagram yüklü ve yüklü değil; Gönderi ekranında 4:5 fotoğraf; Hikâye arka planı

## 07b Ödeme ve kota
- [ ] T5 Erişim mantığı (saf, macOS'ta testli): işlem bilgilerinden premium (yıllık geçerli / bitmiş / iade / ömür boyu / Aile Paylaşımı); kayan 7 günde 3 örnek kotası
- [ ] T6 StoreKit 2: ürünler, `Transaction.currentEntitlements` + `updates`, satın alma, geri yükleme; StoreKit yapılandırma dosyası
- [ ] T7 Erişim hakkı soyutlamasının StoreKit uygulaması (FR-003); kota sayacı Keychain'de (spec 05 Hikâye 5.1)
- [ ] T8 Ödeme ekranı: iki seçenek, StoreKit'ten yerel fiyat, "abonelik zorunlu değil", geri yükleme, yenileme koşulları, gizlilik/kullanım bağlantıları (FR-006, FR-007); dördüncü örnekte açılır
- [ ] T9 UI testleri (StoreKit yapılandırmasıyla)
