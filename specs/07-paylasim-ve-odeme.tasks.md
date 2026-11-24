# Görevler — Spec 07 (paylaşım ve ödeme)

## 07a Paylaşım (2026-11-24)
- [x] T1 CaptureKit `StoryComposer`: 4:5 fotoğraf 1080 × 1920 Hikâye tuvalinde, boşluk aynı fotoğrafın bulanık ve hafif koyulaştırılmış hali (açık soru 4 varsayılanı); test
- [x] T2 Kayıtta galeri kimliği (`PHObjectPlaceholder.localIdentifier`) saklanır; ekleme izni yeter
- [x] T3 İnceleme ekranında "Instagram'a gönder" (Instagram yüklüyse, `LSApplicationQueriesSchemes`): Gönderi → `instagram://library?LocalIdentifier=…`; Hikâye → panoya arka plan görseli + `instagram-stories://share` (yalnızca Meta uygulama kimliği varsa); başarısızlıkta standart paylaşım menüsü (Hikâye 1.5)
- [x] T4 UI testleri: Instagram yokken yalnız standart paylaşım (1.4); Instagram varken iki dokunuşta Gönderi (SC-001), kimlik yokken Hikâye yok, çalışmayınca paylaşım menüsü
- [ ] Meta uygulama kimliği kaydı (geliştirici) ve `FACEBOOK_APP_ID`
- [ ] Cihazda: Instagram yüklü ve yüklü değil; Gönderi ekranında 4:5 fotoğraf; Hikâye arka planı

## 07b Ödeme ve kota
- [x] T5 AccessKit paketi (saf, macOS'ta 12 test, SC-005): `AccessState.resolve` — yıllık geçerli/bitmiş, iade, ömür boyu, Aile Paylaşımı (ayarlanabilir), paket sahipliği (ömür boyuna dahil değil), yıllık + ömür boyu birlikte uyarısı; `ReferenceQuota` — kayan 7 günde 3, sonraki hakkın zamanı, premiumda sınırsız
- [x] T6 StoreKit 2 (`StoreEntitlements`): ürünler, `Transaction.currentEntitlements` + `updates`, satın alma (bekleyen onay dahil), `AppStore.sync` ile geri yükleme; `Config/Products.storekit` (yıllık 19,99 $, ömür boyu 39,99 $), şemaya bağlı
- [x] T7 Erişim hakkı soyutlaması (FR-003): `Feature.addExample`; kota tarihleri Keychain'de (yeniden kurulumda sıfırlanmaz, yalnızca tarih). `PAYWALL_ENABLED` (Config/Base.xcconfig) v1 için NO: kapalıyken `AllUnlocked`, uygulama bugünkü gibi ücretsiz. Çağıran kod değişmedi (örnek ekleme dışında)
- [x] T8 Ödeme ekranı: yıllık ve ömür boyu (ömür boyu sarı, belirgin), StoreKit'ten yerel fiyat, "abonelik zorunlu değil", sonraki ücretsiz örneğin zamanı, geri yükleme, yenileme koşulları, Kullanım Koşulları (Apple standart EULA) ve Gizlilik Politikası bağlantısı (`PRIVACY_POLICY_URL`, boşsa gizli); kota doluyken "yeni örnek" düğmesi ödeme ekranını açar, fotoğraf seçtirmez
- [x] T9 UI testleri: dördüncü örnekte ödeme ekranı, kapatınca geri dönüş; kota içindeyken ekleme. Komut satırı testlerinde StoreKit yapılandırması uygulanmayabiliyor: fiyat denetimi ürün yüklenirse yapılır
- [ ] Gizlilik politikası sayfası ve `PRIVACY_POLICY_URL` (App Store incelemesi için gerekli)
- [ ] App Store Connect'te ürünler ve bölgesel fiyatlar; Aile Paylaşımı ayarı
- [ ] Sandbox: yıllık ve ömür boyu satın alma, geri yükleme, uçak modunda premium (SC-003, SC-004), iade
- [ ] v2'de `PAYWALL_ENABLED = YES`
- [ ] Paketler (Hikâye 4–5): barındırma ve imza kararı
