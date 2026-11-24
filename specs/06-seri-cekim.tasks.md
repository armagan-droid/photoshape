# Görevler — Spec 06 (seri çekim)

## 1. dilim (2026-11-24)
- [x] T1 CompositionKit: `Sharpness` (konu bölgesinde Laplace varyansı; kasıtlı arka plan bulanıklığı sayılmaz, FR-002), `FaceEyes` (Vision göz konturunun en/boy oranı; açık soru 3), `BurstSelector` (önce herkesin gözü açık, yoksa en çok açık göz, sonra en net; hepsi bulanıksa bildirir), `BurstPlan` (kişi / hareket / loş → 3 kare, hareketsiz yemek → 1; ısınma ve bellek baskısında 1); 9 test (SC-001/002 sentetik)
- [x] T2 Kamera: aynı pozlamalı bracket çekimiyle tek basışta seri (tek ses); desteklenmezse tek kare. En iyi kare kaydedilir, diğerleri yalnızca oturum boyunca bellekte (FR-005); hepsi bulanıksa "Telefonu sabit tut"
- [x] T3 "Diğer kareler": seçilen kare galeriye yeni fotoğraf olarak eklenir (açık soru 2 varsayılanı; ekleme izni yeter); UI testleri
- [ ] Spec 00'a `burst_id`, `eyes_closed_count` etiketleri (açık soru 4) ve SC-001/002 test seti ölçümü
- [ ] Cihazda: bracket ayarlarının iPhone 17'de çalıştığı, SC-003 (≤ 3,5 sn), SC-004, göz kapalılık eşiği (0,17), elle test listesi
