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

## Notlar
- `scripts/test.sh`: paket testleri (62). `scripts/test-app.sh`: simülatörde UI testleri (4).
- T17: Simülatörde kaydedilen fotoğrafın Fotoğraflar kütüphanesinde orijinal HEIC + 4:5 düzenleme (1512×1890) + `Adjustments.plist` (`app.photoshape.ios`, sürüm 1) olarak durduğu doğrulandı.
- Simülatör HEIC kodlayamıyor; düzenleme orada JPEG'e düşer. Cihazda HEIC beklenir (elle testte kontrol et).

## Elle (iPhone 12)
- [ ] Spec 01 "Elle test listesi" ve SC-001…SC-006
