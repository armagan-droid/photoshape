# Görevler — Spec 01

## Paketler (test önce, macOS)
- [x] T1 FrameKit: `Frame`, `FrameSource`, `RecordedFrameSource` (testler için)
- [x] T2 CaptureKit `CropGeometry`: 4:5 dikdörtgen, önizleme çerçevesi ile kırpmanın aynı olması
- [x] T3 CaptureKit `LensCatalog`: cihaz yetenekleri → geniş/normal/yakın (telefotolu, telefotosuz, ultra geniş yok)
- [x] T4 CaptureKit `ShutterGate`: art arda basma, kuyruk yok
- [x] T5 CaptureKit `EditRecord`: kodlama/çözme, sürüm, ileride tarif alanları için yer
- [x] T6 CaptureKit `EditedPhotoRenderer`: orijinalden yönelimi doğru 4:5 HEIC/JPEG; tam 4:5 oran (SC-005)

## Uygulama
- [x] T7 Xcode projesi, xcconfig, Info.plist anahtarları, yalnızca dikey, iOS 18
- [x] T8 String Catalog (TR/EN): arayüz ve izin metinleri
- [x] T9 Kamera: oturum, sanal cihaz, lens geçişi, çekim, derinlik, kare kaynağı
- [x] T10 Önizleme ve 4:5 çerçeve, dokunarak netleme işareti, otomatiğe dönüş
- [x] T11 Deklanşör geri bildirimi, köşe önizlemesi, büyük önizleme ve paylaşım
- [x] T12 Kaydetme: yalnızca ekleme izni, düzenleme kaydıyla, başarısızlıkta kareyi tutma
- [x] T13 İzin akışları: kamera reddi ekranı ve Ayarlar düğmesi, galeri reddi mesajı
- [x] T14 Kesintiler, arka plan, ısınma
- [x] T15 Simülatörde benzetilmiş kamera
- [x] T16 UI testi: çek → önizleme → paylaşım menüsü; izin reddi ekranı
- [x] T17 Simülatörde kayıtta düzenleme verisinin bulunduğunu doğrulama

- [x] T18 Büyük önizlemede ilk 3 gösterimde geri alma notu, yalnızca düzenleme kaydıyla kaydedildiyse (Hikâye 4.3, FR-012)

## Notlar
- `scripts/test.sh`: paket testleri (62). `scripts/test-app.sh`: simülatörde UI testleri (5).
- T17: Simülatörde kaydedilen fotoğrafın Fotoğraflar kütüphanesinde orijinal HEIC + 4:5 düzenleme (1512×1890) + `Adjustments.plist` (`app.photoshape.ios`, sürüm 1) olarak durduğu doğrulandı.
- Simülatör HEIC kodlayamıyor; düzenleme orada JPEG'e düşer. Cihazda HEIC beklenir (elle testte kontrol et).

## Elle (gerçek cihaz)

İlk deneme (2026-11-21, iPhone 17, iOS 27.2.1, telefon dili İngilizce):
- [x] Uygulama hızlı açılıyor (SC-001, göz kararı)
- [x] Üç lens düğmesi görünüyor (Wide / Normal / Close; ultra geniş + geniş, "yakın" 2× dijital)
- [x] Paylaşım menüsü açılıyor
- [x] Lens geçişinde görüntü donmuyor ya da kararmıyor (SC-003)
- [x] Fotoğraflar'da 4:5 ve dik; ⋯ > "Revert to Original" ile kırpılmamış orijinal geri geliyor (FR-004). Kayıt: HEIC düzenleme ekli (teşhis çıktısı).
- [x] Dokunarak netleme (ilk sürümde dokunuştan hemen sonra merkeze dönüyordu; 2 sn bekleme ve sürekli netleme ile düzeltildi)
- [ ] İzin akışları (kamera reddi, galeri reddi), iki dilde
- [ ] Kesintiler (Kontrol Merkezi, uygulamadan çıkıp dönme, arama)
- [ ] Instagram ve WhatsApp'a gönderme
- [ ] Çekimden galeriye ≤ 2 sn (SC-002); 100 çekimde çökme yok (SC-004)
- [ ] En düşük desteklenen cihazda (iPhone 12, iOS 18) tekrar
