# Veri Temizleme Notları — SDG 11.3.1 / LCRPGR Analizi

**Proje:** UOL Development Economics — Türkiye'de Sürdürülebilir Kentleşme  
**Tarih:** 2026-05-26  
**Kapsam:** 193 ülke × 10 dönem (1975–2020), GHSL Built + GHS-POP zonal istatistikleri  
**Veri kaynağı:** GEE Zonal Statistics → `03_datasets/raw/Zonal_Stats_Global/`  
**İlgili script:** `02_scripts/01_data_preprocessing/02_merge_and_clean.R`

---

## 1. Analiz Yöntemi

Tüm 193 ülke dosyası (`*.csv`) sistematik olarak şu kriterler açısından tarandı:

- Negatif built\_m2 veya pop değerleri  
- Tekrarlı GID\_1 kodları  
- Built veya pop sütunlarında NA  
- Ülke toplamında yıllar arası built azalması (>%1)  
- Ülke toplamında ani nüfus düşüşü (>%10 / 5 yıl)  
- Ülke toplamında aşırı nüfus artışı (>%50 / 5 yıl)  
- ADM1 düzeyinde built > 0 ama pop = 0 (veya tersi)  
- İşlenmiş LCRPGR verisinde sonsuz / aşırı değerler  

---

## 2. Kategori A — Tarihsel Olaylarla Açıklanan Nüfus Anomalileri

**Karar: Veri olduğu gibi bırakıldı. Analiz notlarına ve paper'a bağlam olarak eklenmeli.**

Bu ülkelerdeki nüfus değişimleri GHSL/GHS-POP kaynaklarındaki hata değil, gerçek demografik olayların yansımasıdır. Literatürde bu tür gözlemlerin dışarıda bırakılması yerine kontrol değişkeni veya kukla değişken eklenerek ele alınması tercih edilmektedir.

| Ülke | GID | Dönem | Değişim | Tarihsel Açıklama |
|------|-----|-------|---------|-------------------|
| Afghanistan | AFG | 1980→1985 | −%15.7 nüfus | Sovyet işgali (1979); kitlesel mülteci göçü Pakistan ve İran'a |
| Afghanistan | AFG | 1990→1995 | +%53.0 nüfus | Sovyet çekilmesi sonrası mülteci dönüşü |
| Bosnia & Herzegovina | BIH | 1990→1995 | −%16.5 nüfus | Bosna Savaşı (1992–1995); zorunlu göç ve kayıplar |
| Kuwait | KWT | 1985→1990 | −%11.2 nüfus | 1990 Irak işgali öncesi yabancı işçi çıkışı |
| Rwanda | RWA | 1990→1995 | −%22.2 nüfus | 1994 Soykırımı; tahminen 800.000 kayıp + mülteci dalgası |
| Syria | SYR | 2010→2015 | −%14.0 nüfus | Suriye İç Savaşı (2011–); kitlesel dışa göç |
| Georgia | GEO | 1995→2000 | −%12.6 nüfus | Sovyet sonrası ekonomik çöküş; Gürcüstan'dan Rusya ve AB'ye göç |
| Moldova | MDA | 2010→2015 | −%10.9 nüfus | Kronik işgücü göçü (AB ülkeleri); nüfus eğimi devam etmekte |
| Andorra | AND | 2005→2010 | −%10.5 nüfus | 2008 finansal krizi; Andorra'ya bağımlı İspanya/Fransa göçmen dönüşü |
| Lebanon | LBN | 2015→2020 | −%11.5 nüfus | 2019 ekonomik krizi + COVID dönemi; 2015 artışı Suriyeli mülteci girişi |
| Marshall Islands | MHL | 2015→2020 | −%13.3 nüfus | İklim göçü; built hâlâ artmaktadır (arazi terk edilmeden önce) |

**Regresyon implikasyonu:** Bu ülkeler için ilgili dönemlerde PGR negatif olacağından lcrpgr da negatif (veya çok büyük negatif) çıkabilir. Kategori E'deki eşik tartışmasına bakınız.

---

## 3. Kategori B — Yüksek Ama Gerçek Nüfus Artışları (Göçmen İşçi Patlamaları)

**Karar: Veri olduğu gibi bırakıldı. Aykırı değer analizinde izlenmeli.**

Bu ülkelerde PGR son derece yüksek olduğundan lcrpgr oranı küçük çıkacaktır — bu matematiksel olarak doğrudur ve ekonomik yorumu destekler (nüfus o kadar hızlı artıyor ki built alan ona yetişemiyor). Ancak bu gözlemler regresyon analizinde yüksek leverage noktaları oluşturabilir.

| Ülke | GID | Dönem | Nüfus Değişimi | Açıklama |
|------|-----|-------|----------------|----------|
| UAE | ARE | 1975→1980 | +%86.5 | Petrol geliri patlaması; yabancı işçi göçü |
| UAE | ARE | 2005→2010 | +%97.0 | İkinci göçmen dalgası; 2008 krizi öncesi pik |
| Qatar | QAT | 2005→2010 | +%101.7 | FIFA 2022 Dünya Kupası inşaat işçileri; LNG patlaması |
| Djibouti | DJI | 1975→1980 | +%55.2 | 1977 bağımsızlık + Ogaden Savaşı (Etiyopya) mültecileri |

**Regresyon implikasyonu:** Bu gözlemler özellikle cross-sectional analizde potansiyel outlier. Cook's D veya DFBetas ile kontrol edilmeli; gerekirse Körfez ülkeleri için kukla değişken eklenebilir.

---

## 4. Kategori C — Uninhabited ADM1 Bölgeler (built = 0, pop = 0)

**Karar: Bu bölgeler pipeline'dan çıkarıldı.**  
**Uygulama:** `02_merge_and_clean.R` — `EXCLUDED_ADM1` vektörü (Step 1b)

Bu bölgeler tüm gözlem dönemlerinde hem built\_m2 hem pop değeri sıfırdır. LCRPGR hesaplanamaz (pgr tanımsız), LCR hesaplanamaz (built\_lag = 0), dolayısıyla sadece NA üretirler. Ülke toplamlarını etkilemezler ama ADM1 düzeyi analizde gereksiz NA satırları oluştururlar (toplam 60 beklenmedik NA lcrpgr gözlemi).

| ADM1 Bölgesi | GID\_1 | Ülke | Durum |
|-------------|--------|------|-------|
| Redonda | ATG.2\_1 | Antigua & Barbuda | Uninhabited volkanik ada (0.5 km²) |
| Ashmore and Cartier Islands | AUS.1\_1 | Australia | Uninhabited nature reserve |
| Coral Sea Islands Territory | AUS.3\_1 | Australia | Uninhabited (2.9 km² kara alanı) |
| Saint Brandon (Cargados Carajos) | MUS.11\_1 | Mauritius | Yalnızca balıkçı barınakları; kalıcı nüfus yok |
| Hatohobei | PLW.4\_1 | Palau | ~50 kişilik mevsimlik yerleşim; built = 0 |
| Niulakita | TUV.4\_1 | Tuvalu | 2002'ye kadar uninhabited; built = 0 |

---

## 5. Kategori D — Built > 0 ama pop = 0 olan ADM1'ler (Uydu Artefaktı)

**Karar: Bu bölgeler pipeline'dan çıkarıldı.**  
**Uygulama:** `02_merge_and_clean.R` — `EXCLUDED_ADM1` vektörü (Step 1b)

Bu bölgelerde GHSL uydu görüntüsünde küçük built alanı tespit edilmiş (95–942 m²) ancak GHS-POP nüfus tahmini sıfır kalmıştır. Söz konusu built değerleri ölçüm hassasiyeti sınırında bulunduğundan uydu piksel artefaktı olarak değerlendirildi. pop = 0 ile birlikte pgr ve lcrpgr hesaplanamaz.

| ADM1 Bölgesi | GID\_1 | Ülke | Built 1975 | Built 2020 | Pop |
|-------------|--------|------|------------|------------|-----|
| Northern Islands | NZL.10\_1 | New Zealand | 95 m² | 182 m² | 0 (tüm dönemler) |
| Southern Islands | NZL.13\_1 | New Zealand | 494 m² | 942 m² | 0 (tüm dönemler) |

**Not:** Değerler ihmal edilebilir küçüklükte (< 1000 m²); ülke toplamı (~1 milyar m²) üzerinde hiçbir etkisi yok.

---

## 6. Pipeline Düzenlemesi Özeti

`02_scripts/01_data_preprocessing/02_merge_and_clean.R` dosyasına **Step 1b** bloğu eklendi:

```r
EXCLUDED_ADM1 <- c(
  "ATG.2_1",   # Redonda
  "AUS.1_1",   # Ashmore and Cartier Islands
  "AUS.3_1",   # Coral Sea Islands Territory
  "MUS.11_1",  # Saint Brandon
  "PLW.4_1",   # Hatohobei
  "TUV.4_1",   # Niulakita
  "NZL.10_1",  # Northern Islands (NZ)
  "NZL.13_1"   # Southern Islands (NZ)
)
```

Bu filtre `raw` data.frame'e bind_rows'dan hemen sonra uygulanır; dolayısıyla `panel_adm1`, `panel_country`, `lcrpgr_adm1` ve `lcrpgr_country` dosyalarının tamamı bu dışlamayı yansıtır.

**Etkilenen satır sayısı:** 8 ADM1 × 10 yıl = 80 satır `panel_adm1`'den çıkarıldı.  
**Ülke toplamlarına etkisi:** Sıfır (tüm dışlanan bölgelerin built\_m2 ve pop değerleri zaten 0 veya ihmal edilebilir).

---

## 7. Kategori E — LCRPGR Matematiksel Patlama (PGR ≈ 0)

**Karar: Henüz uygulanmadı. Yöntem seçimi devam ediyor.**

### 7.1 Sorunun Tanımı

LCRPGR = LCR / PGR olduğundan PGR sıfıra yaklaştıkça oran sınırsız büyür:

| Senaryo | pgr değeri | lcrpgr |
|---------|-----------|--------|
| Neredeyse sıfır pozitif büyüme | +0.000010 | +1347 |
| Neredeyse sıfır negatif büyüme | −0.000010 | −1347 |
| Gerçek sıfır | 0 | NA (tanımsız) |

**Ülke düzeyi bulgular (lcrpgr\_country.csv):**
- `lcrpgr > 50`: 13 gözlem (en kötü: Montenegro 2000-05 = +184.8)
- `lcrpgr < −10`: 35 gözlem (en kötü: Czechia 1985-90 = −1346.7)
- Toplam `lcrpgr < 0`: 174 gözlem

**ADM1 düzeyi bulgular (lcrpgr\_adm1.csv):**
- `lcrpgr > 100`: 111 gözlem
- `lcrpgr < −100`: 71 gözlem
- Aralık: −3412 ile +9427

### 7.2 Uygulanan 3-Katmanlı Strateji

**Script:** `02_scripts/02_analysis/03_robustness_lcrpgr.R`  
**Output:** `03_datasets/processed/reg_panel_robust.csv`, `robustness_results.csv`, `04_outputs/tables/robustness_table.html`

#### Strateji Tanımları

| Strateji | DV | Filtre / İşlem | Obs. | Ülke |
|---------|-----|----------------|------|------|
| **S0** | BpCR = LCR − PGR | Bölme yok; tüm sample | 1,373 | 190 |
| **S1** | LCRPGR\_log | \|pgr\_log\| ≥ 0.001 (← **Ana spec**) | 1,323 | 190 |
| **S2** | LCRPGR\_log | \|pgr\_log\| ≥ 0.002 | 1,276 | 188 |
| **S3** | LCRPGR\_log | \|pgr\_log\| ≥ 0.005 | 1,135 | 185 |
| **S4** | LCRPGR\_log | Winsorize 1/99. persentil | 1,373 | 190 |
| **S5** | LCRPGR\_log | Winsorize 5/95. persentil | 1,373 | 190 |

Winsorize sınırları: 1/99 → [−23.3, +26.4] | 5/95 → [−3.85, +6.78]

**Türkiye notu:** Türkiye'nin pgr\_log değerleri her dönemde 0.0107–0.0222 (yıllık) — hiçbir eşik filtresi Türkiye'yi etkilemiyor; 8 dönemin tamamı her stratejide mevcut.

#### Regresyon Sonuçları — TWFE (Ülke + Dönem FE), Kümelenmiş SE

Tüm modeller: `DV ~ ln(GDP p.c.) + urban_pct + ln(pop. density) | iso3 + period`

| Değişken | S0 BpCR | S1 LCRPGR | S2 | S3 | S4 wins.1/99 | S5 wins.5/95 |
|---------|---------|----------|----|----|-------------|-------------|
| ln(GDP p.c.) | −0.0013 | +0.088 | +0.236 | +0.110 | +0.407 | +0.399\* |
| Urban share | +0.0002 | +0.022 | +0.034 | +0.017 | +0.035 | +0.015 |
| ln(Pop. dens) | **+0.016\*\*\*** | +0.306 | +0.733 | +0.687\* | +1.152 | +0.949\* |
| Within R² | **0.048** | 0.002 | 0.014 | 0.019 | 0.003 | 0.011 |
| N | 1,369 | 1,318 | 1,272 | 1,119 | 1,369 | 1,369 |

#### Temel Bulgular

1. **DV olarak BpCR (S0) daha stabil:** Within R² = 0.048 (LCRPGR modellerinde max 0.019). `ln_pop_dens` güçlü ve anlamlı (p < 0.001); diğer modellerde sadece zayıf sinyaller.

2. **ln(GDP p.c.) işareti değişiyor:** S0'da negatif (daha yüksek GDP → daha verimli arazi kullanımı), LCRPGR modellerinde pozitif — DV seçimi bulguyu köklü değiştiriyor.

3. **LCRPGR DV olarak kullanıldığında WR² ≈ 0:** Ülke ve dönem FE absorbe ettikten sonra açıklayıcı değişkenler LCRPGR'daki within-country varyasyonu açıklamıyor. Bu, LCRPGR'ın yüksek gürültüsünden kaynaklanıyor.

4. **S1 (pgr eşiği) S4 (winsorize)'dan daha iyi davranışlı:** S1'de \|lcrpgr\| > 10 olan 31 obs. var; S4'te 78 var — filtre, winsorize'dan daha etkili.

#### Öneri: Ana Spesifikasyon

**BpCR (S0) birincil regresyon DV'si olarak** kullanılmalı — Lu & Weng (2026) Eq. 6 ile tutarlı, matematiksel olarak kararlı, daha yüksek WR². Paper'da şu yapı kullanılacak:

- **Ana tablo:** BpCR ~ TWFE (M6 yapısıyla)
- **Karşılaştırma:** LCRPGR S1 (pgr eşikli) aynı spesifikasyonla
- **Robustness appendix:** S2, S3, S4, S5 — sonuçların eşik seçimine duyarsızlığı

#### S1 Tarafından Dışlanan Gözlemler (|pgr| < 0.001)

Çoğunlukla gelişmiş, nüfusu stabilize olmuş ülkeler: Almanya, İtalya, Japonya, İsveç, Polonya, Barbados, Nauru, vb. — bunlar *shrinking cities* literatürüyle ilgili olup ayrıca tartışılabilir.

---

## 8. Veri Bütünlüğü Kontrolleri — Genel Bulgular

| Kontrol | Sonuç |
|---------|-------|
| Negatif built\_m2 | 0 satır ✓ |
| Negatif pop | 0 satır ✓ |
| Tekrarlı GID\_1 | 0 ✓ |
| NA built/pop sütunları | 0 ✓ |
| Ülke toplamında built azalması (>%1) | 0 ✓ |
| Uninhabited ADM1 (built=0, pop=0) | 6 bölge → çıkarıldı |
| Built>0 ama pop=0 (artefakt) | 2 bölge (NZL) → çıkarıldı |
| LCRPGR sonsuz değer | 0 ✓ |
| LCRPGR aşırı değer (pgr≈0) | 174+ gözlem → Kategori E |

---

## 9. Nüfus Verisinin Kullanımı — WDI `SP.POP.TOTL`

### 9.1 Kaynak Tercihi

**GHSL-POP (uydu bazlı nüfus gridi) yerine WDI `SP.POP.TOTL` kullanıldı.** Gerekçe: Lu & Weng (2026)'e dayanarak ülkeler arası karşılaştırılabilirlik — WDI ulusal istatistik kurumları kaynaklı olduğundan GHS-POP'un ülkeden ülkeye değişen uydu tahmini hatalarını taşımıyor.

### 9.2 Kullanım Rolleri

| Rol | Değişken | Açıklama |
|-----|----------|----------|
| **PGR hesabı** | `SP.POP.TOTL` | LCRPGR formülünün paydası; logaritmik büyüme hızı olarak hesaplandı |
| **BpCR paydası** | `SP.POP.TOTL` | Built-up per capita = ln(built\_m2 / pop); PGR'ye bölme olmadığından patlama riski yok |
| **Kentsel nüfus payı** | `SP.URB.TOTL.IN.ZS` | Regresyon kontrol değişkeni (%) |
| **Nüfus yoğunluğu** | `EN.POP.DNST` | Regresyon kontrol değişkeni (kişi/km²) |

### 9.3 Bilinen Nüfus Veri Sorunları

#### Türkiye — İdari Sınır Değişikliği (2012)

2012'de Türkiye'nin idari yapısı yeniden düzenlendi: büyükşehir sınırları il sınırlarına genişletildi. Bu değişiklik WDI kentsel nüfus payını (SP.URB.TOTL.IN.ZS) tek bir 5-yıllık pencerede ~69%'dan ~87%'ye (+18 puan) yapay olarak fırlattı. **Etki:** BpCR paydası (toplam nüfus değil urban nüfus payı kontrol değişkeni) üzerinde; `SP.POP.TOTL` toplam nüfus bu değişiklikten etkilenmiyor, dolayısıyla PGR ve BpCR hesapları güvenilir. Ancak urban\_pct kontrol değişkeni Türkiye için 2010–2015 döneminde aykırı değer üretiyor — bu regresyon yorumlanırken not edilmeli.

#### Suriye — Savaş Kaynaklı Nüfus Düşüşü (2010–2015)

İç savaş nedeniyle kayıtlı nüfus düştü; ancak built-up alan büyümeyi sürdürdü (veya yavaşladı). **Etki:** BpCR `= ln(built / pop)` — payda küçüldüğünden BpCR yapay olarak arttı. Bu Kategori A anomalisi olarak zaten kayıt altında (bakınız §2). Regresyon analizinde kukla değişken veya dışlama ile ele alınabilir.

#### Penn World Tables Çapraz Kontrolü

WDI nüfus serisindeki anakronistik değişiklikler Penn World Tables (PPP-adjusted) GDP per capita serisiyle çapraz kontrol edildi. Bazı ülkelerde WDI'nın stagnant GDP serisiyle PWTnin büyüme serisi çelişiyor — bu, nüfus paydası değişiminin GDP per capita oranını da saptırdığına işaret ediyor (Suriye ve benzer vakalar için).

---

*Bu dosya `02_merge_and_clean.R` pipeline düzenlemesiyle eş zamanlı oluşturulmuştur.*
