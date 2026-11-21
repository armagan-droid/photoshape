# Plan — Spec 05, 1. adım: "Örnekle çek" (v1 ana akış)

> Bağlam: README yön değişikliği (2026-11-21), spec 05 Hikâye 0, FR-009, FR-010; spec 02 FR-004.
> Bu adımın kapsamı: örnek seçme, renk ve parlaklık eşleştirme, örnekle açılan kamera. **Kapsam dışı:** Instagram arayüzünü ayıklama (2. adım), açı/mesafe/ışık yönlendirmesi (3. adım, spec 04), cilt ayırma (FR-004).

## Ana fikir: sahneye göre eşleştirme

Örnekten sabit bir tarif çıkarmak ("bu fotoğraf sıcak, +0,3 sıcaklık ekle") yanlış sonuç verir. Kullanıcının sahnesi zaten sıcaksa fotoğraf turuncuya kaçar. Bunun yerine:

1. **Örnek profili** (`ReferenceProfile`): örnek seçilince bir kez hesaplanır. Örneğin parlaklık ortalaması, kontrastı (parlaklık dağılımı), gölge ve parlak uçları, sıcaklık ve ton (Lab a/b ortalamaları), doygunluk ve köşe kararması.
2. **Eşleştirme** (`LookMatcher`): canlı görüntüden saniyede yaklaşık bir kez küçük bir örneklem alınır. Hangi renk ayarlarının **bu sahneyi** örneğin profiline en çok yaklaştırdığı aranır (koordinat iniş, küçük ayarlar tercih edilir). Sonuç bir `LookAdjustments`'tır; spec 03'ün motoru onu önizlemede ve kayıtta uygular.
3. **Kamera parlaklığı** (spec 02 FR-004): sahnenin parlaklığı örneğe göre düşükse ya da yüksekse kameranın pozlama hedefi yavaşça kaydırılır (±1,5 EV sınırı, parlak alan patlıyorsa artırılmaz). Renk ayarındaki pozlama, kameranın kapatamadığı farkı kapatır.

Deklanşöre basıldığı an geçerli olan ayarlar kaydedilir; yani kayıt ekranda görülenle aynıdır.

## Yapı

| Parça | Yer | Not |
|---|---|---|
| `ReferenceProfile`, `ColorStats`, `SceneSample` | LookKit | Saf; macOS'ta test edilir |
| `LookMatcher` | LookKit | Saf; deterministik; macOS'ta test edilir |
| Örnek seçme ekranı | App/Reference | Sistem fotoğraf seçicisi, izin istemez (Constitution I) |
| Örnek deposu | App/Reference | Application Support'ta küçük ikon + profil (JSON). Tam boy görüntü saklanmaz (Hikâye 6.2) |
| Eşleştirme döngüsü | App/Camera | Saniyede bir ölçüm, yumuşatma (titreşim olmasın) |
| Pozlama hedefi | AVCameraBackend | `setExposureTargetBias`, cihaz sınırlarına sıkıştırılır |
| Filtre şeridi ve kaydırıcı | Kaldırılır | Yön değişikliği |

## Başarı ölçümü

- **SC-002 (spec 05):** Her hazır tarif P için örnek = P(sahne) alınır. Eşleştirme, P'yi bilmeden aynı sahneye uygulanınca örnekle ortalama ΔE2000 ≤ 5 farkla eşleşmelidir.
- **Kendisiyle eşleşme:** Örnek ile sahne aynıysa ayarlar sıfıra yakın kalır ve sonuç ΔE ≤ 1,5 içinde olur.
- **Siyah-beyaz örnek:** Doygunluk −0,8'in altına iner (uç durum).
- **Süre (SC-001):** Profil + bir eşleştirme macOS'ta (hata ayıklama derlemesi) 2 saniyenin altında kalır; telefonda ayrıca ölçülür.

## Bilinen sınırlar

- Eşleştirme genel istatistiklere dayanır; örnekteki belirli bir nesnenin rengini bilmez. Cilt ayırma (FR-004) ve sahne türüne göre eşleştirme sonraki adımlardır.
- Örneklerin çoğu Instagram ekran görüntüsü olacak. 2. adıma kadar ekran görüntüsündeki arayüz çubukları istatistiğe karışır; kullanıcıya şimdilik fotoğrafı seçerken kırpması önerilmez, 2. adımda otomatik ayıklanır.
