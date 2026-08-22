# GAME_STRATEGY_V2.md

**Element TD esinli mobil tower defense için ürün ve tasarım stratejisi — ikinci sürüm.**

Bu belge [GAME_STRATEGY.md](GAME_STRATEGY.md) (V1, 2.077 satır) yerine geçer. V1'i
kopyalamıyor: önce onu eleştiriyor, üç somut kusurunu düzeltiyor ve hedefi değiştiriyor.

V1'in hedefi "oyuncu dostu ve çocuk-okunabilir bir oyun"du. V2'nin hedefi aynısı **artı
ticari olarak sürdürülebilir olmak** — ve bu ikisi V1'in sandığı kadar çatışmıyor.

---

## Etiketler

| Etiket | Anlamı |
|---|---|
| **[EXTRACTED]** | Warcraft III harita dosyalarından okunmuş veri. `tools/extract_w3x.py` ile yeniden üretilebilir. |
| **[BUILT]** | Mevcut Godot projesinin gerçek davranışı. `godottowerdefense/scripts/` içinde okunabilir. |
| **[MARKET]** | Güncel piyasa verisi. Kaynak linki verilir. |
| **[POLICY]** | Güncel platform veya mevzuat kuralı. Kaynak linki verilir. |
| **[PROPOSAL]** | Benim tasarım önerim. Tartışılabilir, kaynak değil gerekçe taşır. |

---

## Kararlar (kullanıcıyla netleşti)

| Konu | Karar | Belgeye etkisi |
|---|---|---|
| Pazara çıkış | **Organik, UA bütçesi yok** | Ölçek satın alınamaz → kurulum başına gelir optimize edilir |
| İş modeli | Analize bırakıldı | Bölüm 15 karar veriyor: **Model B** |
| Pazarlar | **Global, gerçekçi karışım** | Harmanlanmış rewarded eCPM ~10 $ varsayılır |
| Element isimleri | **Fire / Water / Earth / Nature sabit** | İsimlendirme tartışması yok |
| Kule tavanı | Kalıcı 4 sınırı yok | 5. aile, yeni bir *rol* getiriyorsa gelir |

---

# 0. Yönetici özeti

## V2'nin tezi, üç cümlede

1. **Oynanış tarafında V1 büyük ölçüde doğruydu** — dört kule, Lv3 branch, kart döngüsü,
   sonlu Standard mod. Bunları koruyoruz.
2. **Para kazanma tarafında V1 bir ilke değil, yarım kalmış bir düşünceydi** — kendi
   belgesinde "5 bin indirmede iş değil" yazıp ölçeğin nereden geleceğini hiç sormadı.
3. **Organik dağıtım + düşük harmanlanmış eCPM, tek bir çapa satın almayı zorunlu kılıyor:**
   ücretsiz çekirdek + tek seferlik ~6,99 $ tam sürüm kilidi, ödemeyenlerden gelir üreten
   gönüllü rewarded reklamla birlikte.

## En kritik altı sayı

| | V1 | **V2** | Neden |
|---|---|---|---|
| Kart dalgaları | 5 / 10 / 15 / 20 | **3 / 7 / 11 / 15** | W20 kartının etkileyeceği dalga yok — V1'in hatası |
| Matchup güçlü çarpanı | ×2.0 | **×1.6** | ×2.0 oyunu "rengi oku, karşıtını dik"e indirger |
| Zırhlı dalga oranı | %100 | **~%60** | Çarpandan daha güçlü kaldıraç; matchup baharat olur, ana yemek değil |
| Standard süre | 12–14 dk | **10–11 dk** | 1,8 run/oturum × 13 dk = 25 dk; mobil için iyimser |
| Workshop tavanı | +%79 hasar | **+%10,4 hasar** | Kalıcı güç merdiveni satılabilir hâle gelirse pay-to-win olur |
| Reklam | Hiç yok | **Gönüllü rewarded, günde 2** | Mobilin en değerli ve en sevilen yüzeyi; yasaklamak veri değil his |

## Ticari gerçeklik, açıkça

Kurulum başına net gelir tahminim **~0,21 $** (Bölüm 15'te hesaplanıyor). Bu şu demek:

| Organik kurulum | Tahmini brüt ömür geliri |
|---|---|
| 10.000 | ~2.100 $ |
| 50.000 | ~10.500 $ |
| 250.000 | ~52.000 $ |

Dürüst çerçeve: bu **"50 bin kurulumda anlamlı bir yan gelir, 250 bin+'da gerçek bir gelir"**
işi. "İşi bırak" işi değil — patlama yapmadıkça. Bunu baştan söylemek, sonradan hayal
kırıklığı yaşamaktan iyidir; ve bu, kapsamın neden küçük kalması gerektiğinin de gerekçesi.

---

## İçindekiler

| § | | § | |
|---|---|---|---|
| [1](#1-v1-neyi-doğru-yaptı) | **V1 neyi doğru yaptı** | [17](#17-second-chance--analiz-otomatik-onay-veya-ret-değil) | Second Chance |
| [2](#2-v1-neyi-yanlış-yaptı-nerede-dogmatikti) | **V1 neyi yanlış yaptı** | [18](#18-interstitial-reklam--modellenip-reddedildi) | Interstitial |
| [3](#3-element-kimlikleri) | Element kimlikleri | [19](#19-ad-removal) | Ad Removal |
| [4](#4-kule-yapısı-ve-branchler) | Kule yapısı ve branch'ler | [20](#20-iap-ürünleri) | IAP ürünleri |
| [5](#5-kart-zamanlaması--v1in-hatasının-düzeltilmesi) | **Kart zamanlaması** | [21](#21-journey-pass--süresiz) | Journey Pass |
| [6](#6-kart-havuzu--oyunun-ana-tekrar-oynanabilirlik-sistemi) | Kart havuzu | [22](#22-premium-para-birimi) | Premium para birimi |
| [7](#7-matchup-çarpanları) | Matchup çarpanları | [23](#23-ne-satılır-ne-satılmaz) | Ne satılır, ne satılmaz |
| [8](#8-faiz-ve-ekonomi-üçgeni) | Faiz + ekonomi üçgeni | [24](#24-retention--daha-az-dogmatik) | Retention |
| [9](#9-kule-satışı) | Kule satışı | [25](#25-kitle-stratejisi--bu-bir-iş-kararı) | **Kitle / mevzuat** |
| [10](#10-dalgalar-düşmanlar-ve-bosslar) | Dalgalar, düşmanlar, boss'lar | [26](#26-soft-launch-metrikleri) | Soft launch metrikleri |
| [11](#11-standard-mod-ve-oturum-süresi) | Standard mod ve süre | [27](#27-ab-test-planı) | A/B test planı |
| [12](#12-haritalar--ve-v1in-çelişkisinin-çözümü) | Haritalar | [28](#28-ürün-fazları) | Ürün fazları |
| [13](#13-meta-ilerleme) | Meta ilerleme | [29](#29-ekonomi--kesin-sayılar-ve-simülasyon) | **Ekonomi + simülasyon** |
| [14](#14-workshop--küçük-tavanlı-ve-rekabette-normalize) | Workshop | [30](#30-gerçekten-yayınlayacağım-oyun) | **YAYINLAYACAĞIM OYUN** |
| [15](#15-para-kazanma--sıfırdan) | **Para kazanma (sıfırdan)** | [31](#31-akış-diyagramı) | Akış diyagramı |
| [16](#16-rewarded-reklam--ödül-boyutu-hesaplanarak) | Rewarded reklam | [—](#build-next) | **BUILD NEXT** |

---

# 1. V1 neyi doğru yaptı

Kullanıcının "muhtemelen korunmaya değer" dediği 14 maddeyi bağımsız değerlendirdim.
Hepsi aynı ağırlıkta çıkmadı: bazıları gerçekten sağlam kararlar, bazıları **karar değil
değer** (yani kimsenin itiraz etmeyeceği, dolayısıyla hiçbir şeyi belirlemeyen ifadeler),
biri de doğru sonuç ama zayıf gerekçe.

| # | Madde | Hüküm | Not |
|---|---|---|---|
| 1 | **Dört başlangıç kule ailesi** | ✅ **Sağlam** | Tek palet satırı, dört renk, dört şekil. **[EXTRACTED]** Element TD'nin 41 kule / ~115 durumuna karşı ölçülebilir bir kazanç. |
| 2 | **Düşük palet karmaşıklığı** | ✅ **Sağlam** | **[BUILT]** palet zaten dünyanın 240 px'ini yiyor (`Game.PLAY_RIGHT`) ve tıklamaları yutuyor. Palet büyümesi doğrudan oynanabilir alanı yer. |
| 3 | **Beş kule seviyesi** | ⚠️ **Doğru sonuç, zayıf gerekçe** | V1 beşi **[EXTRACTED]** Element TD'den miras aldı ve sorgulamadı. Bölüm 4'te yeniden gerekçelendiriyorum: branch Lv3'teyse, 4 ve 5 branch'in üstünde kalır — 4 seviye olsaydı branch'ten sonra tek seviye kalır ve seçim ödülsüz olurdu. Beş, branch'in *sonucu*, keyfi bir sayı değil. |
| 4 | **Tek büyük branch kararı** | ✅ **Sağlam — belgenin en iyi yapısal kararı** | Karar, oyuncunun zaten baktığı nesnenin üstünde. Menü yok, tarif listesi yok. Kingdom Rush'ın da çözümü bu. |
| 5 | **Sekiz uç durum kule kimliği** | ⚠️ **Karar değil, türev** | 8, 4×2'nin *sonucu*. V1 bunu bağımsız bir tasarım kararıymış gibi sunuyor. Asıl karar "her kulede iki branch"; sekiz ondan düşüyor. |
| 6 | **Run bazlı kartlar** | ✅ **Sağlam ve bedava** | **[BUILT]** `Game.UPGRADE_POOL`, `Run.roll_choices()`, `TowerMods.fold`, `upgrade_choice.gd`, `Balance.RARITY_WEIGHTS` zaten var ve çalışıyor. Tasarımın en değerli sistemi, yazılmış olan sistem. |
| 7 | **Cross-element sinerji = kart, kombinasyon kulesi değil** | ✅ **En iyi fikir** | Element TD'nin 15 tarifelik kombinasyon tablosunu **yerleşim bulmacasına** çeviriyor. Dört veri satırı, on beş kule yerine. Bölüm 6 bunu ana stratejik kanca yapıyor. |
| 8 | **Sonlu Standard mod** | ✅ **Sağlam — [BUILT]'a göre en büyük değişiklik** | **[BUILT]** run şu an sonsuz ve *her oturum yenilgiyle biter*. Kazanabilen bir run, retention'ın temeli. |
| 9 | **~10–14 dakikalık oturum** | ⚠️ **Aralık doğru, üst ucu iyimser** | V1 aynı belgede "1,8 run/oturum" hedefi koyuyor; 1,8 × 13 dk = 25 dk. Bölüm 11'de **10–11 dk**'ya çekiyorum. |
| 10 | **Güçlü görsel iletişim** | ⚠️ **Karar değil, değer** | "Görsel iletişim iyi olsun" cümlesine kimse itiraz etmez, dolayısıyla hiçbir şeyi belirlemez. Asıl kararlar V1'in *mekanizmaları*: ×N rozeti, yerdeki zırh halkası, siluet okunabilirliği, 12 kelimelik metin bütçesi. Bunlar sağlam; başlık değil. |
| 11 | **Küçük düşman arketip seti** | ✅ **Sağlam** | **[EXTRACTED]** Element TD'nin on sınıfının dördü taktiksel, altısı flavour. Altı arketip + boss, aynı taktiksel yükü taşıyor. |
| 12 | **Mekanikli boss'lar** | ✅ **İlke sağlam, uygulama inceydi** | V1 iki boss ve birer kural veriyor. İlke doğru; içerik yetersiz. Bölüm 10 boss tasarımını genişletiyor. |
| 13 | **"Bir run daha" felsefesi** | ⚠️ **Karar değil, hedef** | V1'in dört bileşeni (okunabilir kayıp, tek tuş retry, farklı sonraki run, kısa süre) asıl içerik. Felsefe başlığı değil, o dört madde korunmalı. |
| 14 | **Mobil okunabilirlik** | ✅ **Kısıt olarak sağlam — ama V1 kendi kuralını çiğnedi** | §6.3 "iki bağımsız şerit telefonda okunmaz" diyor, §6.2 Hard'a ikinci giriş koyuyor. Kural doğru, uygulaması tutarsız. Bölüm 12 düzeltiyor. |

**Özet:** 14 maddenin **8'i gerçek ve sağlam karar**, 2'si doğru ama zayıf gerekçeli,
2'si karar değil değer/hedef, 1'i türev, 1'i kendisiyle çelişen. V2 sekizini olduğu gibi
alır, geri kalanını yeniden gerekçelendirir veya somutlaştırır.

---

# 2. V1 neyi yanlış yaptı, nerede dogmatikti

## 2.1 Üç somut hata

### Hata 1 — Son dalgaya kart koymak

V1 kartları **5 / 10 / 15 / 20**'ye koyuyor ve Standard mod 20. dalgada bitiyor. **Dalga
20'de alınan kartın etkileyebileceği hiçbir dalga yok.** Hata belgede dört ayrı yerde
tekrarlanıyor: `GAME_STRATEGY.md:897`, `:1301`, `:1540`, `:1804`.

Bu bir tercih değil, tasarım hatası. Bölüm 5 düzeltiyor.

### Hata 2 — Kendi mobil okunabilirlik kuralını çiğnemek

| Konum | Ne diyor |
|---|---|
| `GAME_STRATEGY.md:977` (§6.2) | Hard ruleset: *"tam yol **+ dalga 12'den itibaren ikinci bir giriş**"* |
| `GAME_STRATEGY.md:982-990` (§6.3, kural 2) | *"Tek yol, en fazla bir opsiyonel dal. İki bağımsız şerit dikkat maliyetini ikiye katlar ve kule değerini yarıya indirir; telefonda oyuncu birini tamamen kaybeder."* |

Aynı belgede, beş sayfa arayla, iki zıt kural. Ve §6.3 kendini *"tercih değil, katı kısıt"*
diye tanımlıyor. Bölüm 12 çözüyor: kural kalır, ikinci giriş gider.

### Hata 3 — Ölçek sorusunu sorup cevabını aramamak

V1 §8.3 (`:1141`) aynen şunu yazıyor:

> *"200 bin+ kurulumda gerçek bir iş ve 5 binde iş değil."*

Belge burada kozmetik-only modelin **ölçeğe bağımlı olduğunu doğru teşhis ediyor** — ve
sonra kozmetik-only öneriyor, o ölçeğin nereden geleceğini hiç sormuyor. Kullanıcının UA
bütçesi yok. Yani V1'in önerdiği model, V1'in kendi kabul ettiği koşulu sağlayamıyor.

**Bu bir ilke değil, yarım kalmış bir düşünce.** V2'nin varlık sebebi bu satır.

## 2.2 Para kazanma aşırı düzeltmesi — madde madde yeniden yargı

V1 §8.2 ve §9.3 toplam **on sekiz yasak** koyuyor. Her birini tekrar yargıladım.

| V1 yasağı | V1'in gerekçesi | **V2 hükmü** | Neden değişti / değişmedi |
|---|---|---|---|
| **Rewarded video** ("MVP'de ve v1.0'da yok") | "10-14 dakikalık akışı böler ve çocuk uygulamasını reklam ağı veri işlemeye sokar" | ❌ **YANLIŞ — kaldırıldı** | Rewarded reklam akışı bölmez, **oyuncu başlatır ve savaş dışındadır**. Piyasa: reklam gelirinin ~%60'ı, eCPM 15–25 $, oyuncu tercihinde interstitial'a 4:1 üstün, ARPDAU'yu %30–66 yükseltiyor ve IAP'yi yamyamlaştırmıyor **[MARKET]**. V1 mobilin en sevilen yüzeyini veriye bakmadan yasakladı. Bölüm 16. |
| **Welcome / starter pack** | "En az bilgiye sahip olunan ana nişan alır" | ⚠️ **Kısmen yanlış** | *İlk açılışta* gösterilen paket için doğru. **3–5 run sonra** gösterilen paket ise oyunu tanıyan birine sunulur — bu tam tersi bir durum. Bölüm 20. |
| **İlerleme hızlandırma** | "§8.1" (kendine referans) | ⚠️ **Gerekçe döngüsel** | V1 gerekçe olarak kendi ilkesine link veriyor. V2 gerçek gerekçeyi kuruyor **ve aynı sonuca varıyor** — ama Bölüm 23'teki nedenle: Workshop o kadar küçük ki hızlandırma satılabilir bir ürün değil. |
| **Premium para birimi** | "Fiyatı gizlemek, gücü satmak veya ikinci döngü üretmek için var" | ✅ **Doğru, gerekçe de doğru** | V2 aynı sonuçta kalıyor, Bölüm 22'de daha iyi bir gerekçeyle: 10'dan az SKU'da premium kur hiçbir işe yaramaz. |
| **Loot box / gacha** | "Çocuklara yönelik kumar mekaniği" | ✅ **Doğru** | Tartışmasız. |
| **Enerji / can sistemi** | "Mobildeki en oyuncu-düşmanı mekanik" | ✅ **Doğru** | Tartışmasız. |
| **Timer / geri sayım / FOMO** | "Çocuklara yönelik yapay aciliyet" | ✅ **Doğru** | Bölüm 21'in süresiz Journey Pass'i bu ilkeyi *koruyarak* para kazanıyor. |
| **Interstitial** | "10-14 dakikalık akışı böler" | ✅ **Sonuç doğru, gerekçe eksik** | V2 aynı sonuçta ama **rakamla**: DAU başına <1 sent. Bölüm 18. |
| **Second Chance** | Hiç değerlendirilmemiş | ❌ **Eksik — V1 bunu düşünmedi bile** | Bölüm 17: kısıtlı olarak **evet**. |
| **Loadout slotu satmak** | "Anahtar satmak için yapılmış kafes" | ✅ **Doğru** | Bu tasarımda loadout yok; slot satmak yapay kısıt üretmek olurdu. |
| **Booster / consumable** | "Temel oyunun gizlice ona göre ayarlandığı anlamına gelir" | ✅ **Doğru** | Tartışmasız. |
| **Düşman skin'i satmak** | "Siluetler oynanış bilgisidir" | ✅ **Doğru ve zekice** | V1'in en iyi monetizasyon kararı. |
| **UI teması satmak** | Aynı gerekçe | ✅ **Doğru** | HUD herkes için aynı okunmalı. |
| **Kayıptan hemen sonra mağaza** | "Hayal kırıklığı anında mağaza göstermek kalıbın tanımıdır" | ✅ **Doğru** | Bölüm 9'daki kurallar aynen kalıyor. |
| **Günlük görevler** | "Oyunu ödev listesine çevirir" | ✅ **Doğru** | "200 düşmanı Fire ile öldür" oyuncuya kasten kötü oynatır. |
| **Login streak / gün serisi** | "Yokluğu cezalandırır" | ⚠️ **Aşırı geniş** | *Streak* doğru yasak. Ama **cezasız, artmayan "günün ilk galibiyeti" bonusu** streak değil. Bölüm 24. |
| **Battle pass** | "Geri sayım baskısı" | ⚠️ **Yanlış hedefi vurdu** | Sorun *pass* değil, *süre sınırı*. Süresiz pass ilkeyi bozmadan gelir üretir. Bölüm 21. |
| **Tüm meta progression'ı MVP'den çıkarmak** | "Eğlenceli olup olmadığını ölçerken satıp satmadığını ölçemezsin" | ✅ **Prototip için doğru** | Ama V1 bunu ticari sürümle karıştırıyor. Bölüm 13 ve 28 ikisini ayırıyor. |

**Skor: 18 yasağın 10'u doğru, 5'i aşırı geniş veya yanlış gerekçeli, 2'si yanlış, 1'i
hiç düşünülmemiş.** V1 doğru sezgiye sahipti, ama sezgiyi test etmedi.

---

## 2.3 "Non-negotiable" denen her şey yeniden yargılandı

V1'de mutlak dille yazılmış üç iddia var. Hepsini tekrar test ettim.

| İddia | Konum | **V2 hükmü** |
|---|---|---|
| *"Yükseltmeler sadece hasarı değiştirir. **Non-negotiable.**"* | `:372` | ✅ **Ayakta kalıyor — ama tam olarak değil.** Kural doğru: **[EXTRACTED]** Element TD'de Fire, 50 altınlık kuleyken de Pure Fire'ken de 500 menzil / 0,33 sn. Elementlerin birbirine dönüşmesini engelleyen tek şey bu. **Ama V1 kendi istisnasını zaten koymuştu**: branch menzili ve atış hızını değiştiriyor. Yani kural aslında *"seviye sadece hasarı değiştirir; branch her şeyi değiştirebilir"*. Bu hâliyle non-negotiable, ve V2 böyle yazıyor. |
| *"Güçlendiren hiçbir şey asla satılmaz."* | §8.1 | ⚠️ **İlke olarak ayakta, mutlak olarak değil.** Bölüm 23'teki çerçeve daha dürüst: satılan şey **rekabet avantajı** olmamalı. Workshop'ın +%10'u zaten oyunda var ve Essence'la kazanılıyor; Essence'ı *hızlandıran* rewarded reklam dolaylı olarak savaş gücüne dokunuyor. V1 bunu görmezden gelirdi; V2 **açıkça yazıyor ve sınırlıyor** (Bölüm 16), ayrıca leaderboard'larda normalize ediyor (Bölüm 14). |
| *"Harita editörü / kullanıcı içeriği — **Non-negotiable hayır.**"* | `:1508` | ✅ **Ayakta.** Çocukların bulunduğu bir üründe moderasyon yükü gerçek. |

## 2.4 Diğer dogmatizmler

| Konu | V1 | **V2** | Gerekçe |
|---|---|---|---|
| **Matchup çarpanı** | ×2.0 güçlü / ×0.8 zayıf | **×1.6 / ×0.85** + zırhlı dalga oranı %60 | ×2.0'da optimal strateji "dalganın rengini oku, karşıt rengi dik" olur. Yerleşim, branch ve sinerji ikinci plana düşer. Bölüm 7. |
| **Faiz** | **[EXTRACTED]** Element TD'nin 15 sn'lik tick'i "türün en iyi kararı", neredeyse dokunulmaz | Dilemma korunur, **mekanik değişir**: dalga sonu %5, cap'li, HUD'da görünür | V1 mekanizmayı fikirle karıştırdı. Değerli olan *harca-mı-biriktir* gerilimi; görünmez 15 saniyelik timer mobilde okunmuyor. **[EXTRACTED]** haritanın kendi ipucu listesi bile faizi bir cümleyle anlatmak zorunda kalmış. Bölüm 8. |
| **Kule sayısı tavanı** | "4 → 6 → 7 tavan", kule eklemek "tek pahalı kaldıraç" | **Sayı tavanı yok, *rol* tavanı var** | Doğru soru "kaç kule?" değil, *"bu kule mevcut dördünün temiz ifade edemediği bir rol getiriyor mu?"*. Bölüm 3.4. |
| **Satış iadesi** | Sabit %80 | **Savaşa girmeden %100, sonra %80** | V1 %50'yi (**[BUILT]** `Balance.SELL_REFUND`) doğru şekilde eleştirdi ama tek sayıyla çözdü. İki kademe hem acemiyi korur hem uzmanın sürekli taşımasını engeller. Bölüm 9. |
| **Workshop** | +%79 hasar tavanını "+%26"ya çekiyor | **+%10,4** ve leaderboard'da normalize | V1 doğru yönde ama yeterince değil, ve **leaderboard normalizasyonunu tamamen atladı** — kalıcı gücün rekabetçi modda ne yaptığı hiç sorulmamış. Bölüm 14. |
| **Meta progression** | MVP'de sıfır, v1.0'da dört sistem | Aynı — ama **prototip / soft launch / v1.0** olarak üçe ayrılmış | V1 "MVP" ile "ticari sürüm"ü tek kelimede topluyordu. Bölüm 28. |
| **Offline Essence** | Sil | ✅ **Aynı fikirdeyim** | **[BUILT]** `Balance.offline_essence` + `Meta._collect_offline` oyuncuya *oynamamanın* ilerleme olduğunu öğretiyor. Bu bir idle oyun mekaniği. |
| **Zorluk ruleset'leri** | Easy/Normal/Hard, Hard'da ikinci giriş | Easy/Normal/Hard, **Hard'da yol değil alan ve zamanlama değişir** | Bölüm 12. |
| **Kart sayısı** | 4 kart / run | **4 kart / run, farklı dalgalarda** | Sayı doğruydu, yerleri yanlıştı. |

## 2.5 V1'in görmediği üç şey

1. **İndirme hacmi.** Monetizasyon oyuncu *başına* geliri belirler; keşfedilebilirlik ve
   retention oyuncu *sayısını*. Organik-only'de ikincisi bağlayıcı kısıt ve V1 bundan hiç
   bahsetmiyor. Bölüm 15.
2. **Farklılaşma.** Mağazada binlerce TD var. "Neden bunu indireyim?" sorusunun cevabı
   yoksa monetizasyon tasarımının hiçbir önemi yok. Bölüm 15.4.
3. **Premium modelin varlığı.** V1 F2P'yi verili kabul etti. Oysa Batı'nın en başarılı iki
   TD'si tek seferlik ücretli **[MARKET]**. Bölüm 15.2.

---

# 3. Element kimlikleri

İsimler sabit: 🔥 **FIRE** · 💧 **WATER** · 🪨 **EARTH** · 🌿 **NATURE**. Mekanikleri
yeniden değerlendirdim ve V1'de gözden kaçmış **iki kimlik çakışması** buldum.

## 3.1 V1'in görmediği iki çakışma

### Çakışma 1 — Fire'ın burn'ü ile Nature'ın poison'ı aynı mekanik

İkisi de "vurduktan sonra hasar vermeye devam eden efekt". Farklı isim, aynı şey. Bir
çocuk için ikisi arasında hiçbir fark yok. **[BUILT]** projede de öyle: `projectile.gd`
her ikisini de aynı poison alanından uyguluyor.

**[PROPOSAL] Çözüm — DoT'u iki eksene ayır:**

| | 🔥 Fire **Burn** | 🌿 Nature **Poison** |
|---|---|---|
| Yön | **Dikey** — tek hedefte *üst üste biner* (3'e kadar) | **Yatay** — ölümde/temasla *komşulara yayılır* |
| Süre / şiddet | Kısa ve sert | Uzun ve yumuşak |
| Zırh | Matchup çarpanından etkilenir | **Zırhı tamamen yok sayar** |
| Ek etki | Yok | **Regen'i bastırır** |
| Cevap olduğu problem | Tek büyük hedef (Brute, boss) | Kalabalık, Mender, Splitter |

Artık ikisi bakınca da oynanınca da farklı: biri **bir hedefi eritir**, diğeri **sürüye
bulaşır**.

### Çakışma 2 — V1'in Fire/Mortar branch'i Earth'ün işini çalıyor

V1'in Fire B branch'i "Mortar": yavaş, lob atışlı, **splash**. Ama splash Earth'ün kimliği.
İki farklı element ailesinin aynı taktiksel soruya aynı cevabı vermesi, hem denge yüzeyini
büyütür hem "hangisini diksem?" sorusunu anlamsızlaştırır.

**[PROPOSAL]** Fire'ın ikinci branch'i splash olmaz. Fire her iki dalında da *burn*
kalır; değişen şey burn'ün **dikey mi yatay mı** ilerlediğidir (aşağıda).

## 3.2 Dört kimlik, tek cümlede

| Element | Renk + şekil | Tek cümle | Savaştaki işi |
|---|---|---|---|
| 🔥 **FIRE** | turuncu üçgen | *"Yakar ve eritir."* | Sürekli hasar. Burn üst üste biner. Tek büyük hedefin cevabı. En kısa menzil. |
| 💧 **WATER** | mavi damla | *"Yavaşlatır ve durdurur."* | Kontrol. Her vuruşta Chill. Diğer bütün kulelere atış zamanı satın alır. Hızlının cevabı. |
| 🪨 **EARTH** | kahverengi altıgen | *"Ağır vurur, çok vurur."* | Yavaş, ağır, splash. Zırh kırar. Kalabalığın ve zırhlının cevabı — **ama göğe ateş edemez.** |
| 🌿 **NATURE** | yeşil yaprak | *"Zehirler ve destekler."* | Zırhı yok sayan ve yayılan zehir, artı komşu kuleleri güçlendiren aura. Mender'ın, sürünün ve zayıf ekonominin cevabı. |

Her cümle Lv1'de de Lv5'te de doğru. Bir iş tanımının geçmesi gereken test bu.

## 3.3 Matchup halkası

**[BUILT]** Mevcut halka altı elementli: `light → darkness → water → fire → nature → earth
→ light`. Light ve Darkness çıkınca kalan halka kendi üzerine mükemmel kapanıyor:

```
        WATER  ──yener──▶  FIRE
          ▲                  │
          │                yener
        yener                │
          │                  ▼
        EARTH  ◀──yener── NATURE
```

- **Water, Fire'ı yener** — su ateşi söndürür.
- **Fire, Nature'ı yener** — ateş bitkiyi yakar.
- **Nature, Earth'ü yener** — kökler taşı çatlatır.
- **Earth, Water'ı yener** — toprak suyu emer, set çeker.

**Dördünün de fiziksel karşılığı var; hiçbiri anlatılmayı gerektirmiyor.** Altı elementli
hâlde "Earth, Light'ı yener" gibi öğrenilmesi gereken keyfi ilişkiler vardı.

**[BUILT]** Kod tarafında bu tek satır: `Game.ELEMENT_BEATS` içinde üç ilişki zaten doğru,
sadece `earth` hedefi `light`'tan `water`'a döner.

Çarpanlar Bölüm 7'de — ve V1'in ×2.0'ı orada düşürülüyor.

## 3.4 Light ve Darkness'a ne oldu

**[BUILT]** Bunlar gerçek varlıklar: tam stat blokları, **beşer tier boyanmış sprite
seti** (`assets/art/towers/light_1..5.png`, `darkness_1..5.png`), tutorial dersleri, dual
tarifleri. Silmek gerçek varlık yakmaktır.

**[PROPOSAL]** `Game.TOWER_ORDER`'dan ve `ELEMENT_BEATS`'ten çıkar, `TOWER_DEFS`'te ve
`assets/`'te **referanssız bırak**. Bunlar hazır bekleyen bir genişleme paketi. Bölüm 28,
Faz 4.

## 3.5 Beşinci aile ne zaman gelir — sayı değil, kural

V1 "4 → 6 → 7 tavan" diyordu. Bu yanlış soru. Doğru kural:

> **[PROPOSAL]** Yeni bir kule ailesi, ancak mevcut dördünün *temiz ifade edemediği* bir
> taktiksel rol getiriyorsa eklenir. Farklı renk ve farklı DPS bir rol değildir.

Aday roller ve durumları:

| Aday rol | Mevcut dörtle ifade edilebilir mi? | Hüküm |
|---|---|---|
| **Zincirleme (chain)** | Hayır — hiçbiri hedefler arası sıçramıyor | ✅ **5. aile için en güçlü aday.** Bu yüzden Bölüm 4'te Water'ın branch'ine chain koymuyorum: gelecekteki bir elementin kimliğini şimdiden harcamak olur. |
| **Delici (pierce) / hat hasarı** | Hayır — splash radyal, hat değil | ✅ Güçlü aday |
| **Işın (beam) / sürekli hasar** | Kısmen — Fire'ın hızlı atışı yakın durur | ⚠️ Zayıf; **[BUILT]** `TowerBehavior` alt sınıfı gerektirir |
| **Aşırı menzil** | Hayır ama **[BUILT]** Light zaten buydu ve V1 §1.9'da ölçüldü: 2000 menzilli kule kendi haritasının %94'ünü görüyor **[EXTRACTED]** | ❌ **Rol değil, denge sorunu.** Bu yüzden Light emekliye ayrıldı. |
| **Summon / birim üretme** | Hayır | ⚠️ Aday, ama pathfinding ve mobil performans riski taşır |
| **Zaman kontrolü** | Kısmen — Water zaten yavaşlatıyor | ❌ Water'ın üstüne biner |

**Sonuç:** beşinci aile gelirse **chain** veya **pierce** olarak gelir. İkisi de mevcut
dördün cevap veremediği bir soruya cevap verir.

---

# 4. Kule yapısı ve branch'ler

## 4.1 Yapı

```
Lv1  inşa
 │
Lv2  stat
 │
Lv3  ══ BRANCH ══  iki kart, iki ikon, ≤5 kelime
 ├── A ─── Lv4 stat ─── Lv5 ULTIMATE A
 └── B ─── Lv4 stat ─── Lv5 ULTIMATE B
```

**Neden 5 seviye ve neden branch 3'te?** V1 beşi **[EXTRACTED]** Element TD'den miras aldı
ve sorgulamadı. Gerçek gerekçe yapısal: branch Lv3'teyse, üstünde **iki seviye** kalır —
biri seçimi ödüllendiren stat artışı, biri seçimin karşılığı olan ultimate. Dört seviyede
branch'ten sonra tek adım kalır ve seçim ödülsüz hissettirir. Altı seviyede maçın içinde
maksimuma ulaşılamaz. **Beş, branch'in sonucudur, keyfi bir sayı değil.**

## 4.2 Yükseltme merdiveni

| Seviye | Maliyet | Kümülatif | Hasar | Ne değişir |
|---|---|---|---|---|
| 1 (inşa) | 50 | 50 | ×1,0 | — |
| 2 | 40 | 90 | ×1,8 | stat |
| 3 | 70 | 160 | ×3,2 | **BRANCH — mekanik değişir** |
| 4 | 120 | 280 | ×5,6 | stat |
| 5 | 200 | 480 | ×10,0 | **ULTIMATE — mekanik değişir** |

Fire için ekranda görünen hasar: **10 / 18 / 32 / 56 / 100**. Dört haneyi hiç geçmiyor.
Karşılaştırma: **[EXTRACTED]** Element TD 23 → 115 → 575 → 2.875 → **28.750**, maliyet
50 / 175 / 788 / 3.544 / **24.444**.

**Lv2'nin inşadan ucuz olması kasıtlı**: yeni oyuncu önce *yükseltmeyi*, sonra yaymayı
öğrensin.

**Kural (Bölüm 2.3'te düzeltilmiş hâliyle):** *seviye sadece hasarı değiştirir; branch her
şeyi değiştirebilir.* Menzil ve atış aralığı seviyeyle asla oynamaz — bu **[EXTRACTED]**
haritanın kuralı ve elementlerin birbirine dönüşmesini engelleyen tek şey.

## 4.3 Sekiz uç durum

Lv1 statları eşit DPS, farklı *şekil* hedefiyle:

| Element | Lv1 hasar | Aralık | DPS | Menzil | Yan etki |
|---|---|---|---|---|---|
| 🔥 Fire | 10 | 0,40 sn | 25 | 170 px | Burn 4/sn, 2 sn, 1 kat |
| 💧 Water | 6 | 0,25 sn | 24 | 210 px | Chill −%25 hız, 1,5 sn |
| 🪨 Earth | 34 | 1,40 sn | 24 | 200 px | Splash 90 px @%50. **Sadece kara.** |
| 🌿 Nature | 12 | 0,90 sn | 13 | 220 px | Poison 12/sn, 3 sn (≈36, zırhı yok sayar) |

### 🔥 FIRE — *dikey mi, yatay mı*

```
Lv1-2  EMBER      hızlı tek hedef, 1 kat burn
   │
   ├─ A  BLAZE       Lv3  aralık 0,40 → 0,28. Burn 3 kata kadar biner.
   │                 Lv5  CINDERHEART — 3 katta hedef iki kat hızlı yanar.
   │                      → Brute ve boss'un cevabı. DİKEY.
   │
   └─ B  WILDFIRE    Lv3  Burn, yanan düşmanın 70 px çevresine yarı güçle BULAŞIR.
                     Lv5  FIRESTORM — yanarak ölen düşman 4 sn yanan bir zemin bırakır.
                          → Swarm ve Splitter'ın cevabı. YATAY.
```

Not: **Wildfire splash değildir.** Anlık alan hasarı vermez; *burn statüsünü* yayar. Splash
Earth'ün kimliği ve orada kalıyor (Bölüm 3.1, Çakışma 2).

### 💧 WATER — *zaman mı, mesafe mi*

```
Lv1-2  FROST       hızlı zayıf vuruş, her vuruşta Chill
   │
   ├─ A  GLACIER      Lv3  Chill −%25 → −%45. Her 4. atış menzildeki HERKESİ chill'ler.
   │                  Lv5  ABSOLUTE ZERO — %15 ihtimalle FREEZE (1 sn tam durma).
   │                       → ZAMAN satın alır. Sprinter ve Swarm'ın cevabı.
   │
   └─ B  UNDERTOW     Lv3  %25 ihtimalle hedefi yol boyunca ~60 px GERİ İTER.
                      Lv5  RIPTIDE — itme mesafesi iki katı, inişte Chill uygular.
                           → MESAFE satın alır. Kaçmak üzere olan sızıntının cevabı.
```

**[PROPOSAL] Undertow kısıtı:** her düşman en fazla 2 saniyede bir itilebilir (düşman
başına dahili cooldown). Bu olmadan Undertow duvarı düşmanları kalıcı kilitler ve run
kırılır. Boss'lar itilmez.

**Neden chain değil?** V1'in Water B'si "Torrent" (zincirleme) idi. Zincirleme, kullanıcının
kendi listesinde **beşinci element adayı** olarak geçiyor (Bölüm 3.5). Onu bir branch'e
harcamak, gelecekteki bir ailenin kimliğini şimdiden yakmaktır. Undertow ise hem yeni bir
eksen açıyor hem de ekranda okunması çok daha kolay: düşman gözle görülür şekilde geri
kayıyor.

### 🪨 EARTH — *kalabalık mı, tek hedef mi*

```
Lv1-2  BOULDER     yavaş ağır splash, SADECE KARA
   │
   ├─ A  QUAKE        Lv3  splash 90 → 140 px; vuruşlar 0,4 sn sendeletir.
   │                  Lv5  FISSURE — splash ayrıca 2 sn %30 yavaşlatır.
   │                       → Swarm ve Splitter'ın cevabı. Köşeyi ölüm kutusuna çevirir.
   │
   └─ B  SIEGE        Lv3  splash 90 → 50 px, hasar +%60; vuruşlar ZIRH ÇATLATIR:
                      Lv4  hedef 3 sn boyunca HER kaynaktan +%25 hasar alır.
                      Lv5  SUNDER — çatlak 80 px içindeki düşmanlara yayılır.
                           → Brute ve boss'un cevabı.
```

### 🌿 NATURE — *yıpratma mı, destek mi*

```
Lv1-2  THORN       orta vuruş, zırhı yok sayan ve regen'i bastıran Poison
   │
   ├─ A  BLIGHT       Lv3  poison hasarı +%80, süre 3 → 8 sn ve düşman hayattayken
   │                       KENDİNİ YENİLER — bir kez zehirlenen temizlenmez.
   │                  Lv5  PLAGUE — zehirli düşman ölünce zehir EN YAKIN tek düşmana geçer.
   │                       → Mender'ın TEK cevabı. Uzun yolun cevabı.
   │
   └─ B  GROVE        Lv3  SAVAŞMAZ, DESTEKLER: 160 px içindeki kuleler +%15 atış hızı,
                      Lv4  o yarıçaptaki her öldürme +1 altın.
                      Lv5  HEARTWOOD — aura ayrıca +%12 hasar; yarıçapta öldürülen her
                           düşmanın %3 ihtimalle bir can geri vermesi.
                           → Zayıf ekonominin TEK cevabı.
```

**Fire'ın yayılmasıyla Nature'ın yayılması nasıl ayrışıyor?** Fire **bire-çok** yayar
(yanan düşmanın çevresindeki herkes tutuşur, canlıyken). Nature **bire-bir** aktarır
(zehirli düşman ölünce zehir tek bir komşuya geçer, hem de Lv5'te). Biri sürüyü tutuşturur,
diğeri zinciri sürdürür.

## 4.4 Karşı-cevap matrisi — hiçbir branch matematiksel olarak üstün olamaz

Bir branch ancak **en az bir taktiksel problemin tek ya da en iyi cevabı** ise gerçek bir
seçimdir. Test bu:

| Problem | Blaze | Wildfire | Glacier | Undertow | Quake | Siege | Blight | Grove |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Brute** (tek, zırhlı, çok can) | **★** | | | | | **★** | ✔ | |
| **Swarm** (kalabalık) | | **★** | ✔ | | **★** | | ✔ | |
| **Sprinter** (hızlı) | | | **★** | ✔ | ✔ | | | |
| **Flyer** (hava) | ✔ | ✔ | ✔ | ✔ | ✖ | ✖ | ✔ | — |
| **Mender** (iyileşen) | | | | | | | **★** | |
| **Splitter** (bölünen) | | ✔ | | | **★** | | ✔ | |
| **Boss 1** (kontrole bağışık) | **★** | ✔ | ✖ | ✖ | ✖ | **★** | ✔ | |
| **Çıkışa yaklaşan sızıntı** | | | ✔ | **★** | | | | |
| **Zayıf ekonomi** | | | | | | | | **★** |

★ = tek ya da açık ara en iyi cevap · ✔ = işe yarar · ✖ = işlemez

Her sütunda en az bir ★ var. Boş sütun yok. **Bu matris, dengenin tamamı** — sekiz kule ×
dokuz problem = 72 hücre, bir kişinin oynayarak doğrulayabileceği büyüklük.
Karşılaştırma: **[EXTRACTED]** Element TD'nin 41 kule × 60 dalga × 10 sınıfı.

İki yapısal zayıflık kasıtlı ve korunmalı:
- **Earth göğe ateş edemez.** Flyer satırındaki iki ✖, Earth'ün bedeli. Bu, "her şeyi
  Earth'le çöz" oyununu engelleyen tek şey.
- **Water, Boss 1'e işlemez.** Kontrol bağışıklığı, oyuncuyu hasara zorlar (Bölüm 10).

## 4.5 Seviyeler stat, branch ve ultimate mekanik değiştirir

| Seviye | Değişim türü | Oyuncunun hissi |
|---|---|---|
| 2 | stat | "Güçlendi." — ucuz, sık, tatmin edici |
| **3** | **mekanik (branch)** | "Bu kulenin *ne olduğuna* ben karar verdim." |
| 4 | stat | "Güçlendi." — verdiğim kararın karşılığı |
| **5** | **mekanik (ultimate)** | "Artık yeni bir şey yapıyor." |

Kule başına **iki olay**, beş değil. Her seviye mekanik olsaydı on kulelik bir tahta yirmi
kural taşırdı ve okunmazdı. Hiçbiri olmasaydı yükseltme bir sürgü olurdu.

## 4.6 Reddedilenler

| Fikir | Neden hayır |
|---|---|
| Lv3'te üçüncü seçenek | %50 daha fazla denge yüzeyi, yeni bir *karar türü* yok |
| Lv5'te ikinci branch (16 uç durum) | Doğru fikir, yanlış yıl. Palet büyütmeden roster genişleten en iyi geç kaldıraç — Faz 4'te |
| Branch'i geri alabilmek (respec) | Kararı kararsızlaştırır. Kuleyi sat, yenisini dik — zaten %80 iade var |
| Branch'i kilitlemek / hesap seviyesiyle açmak | İlk saati demoya çevirir |

---

# 5. Kart zamanlaması — V1'in hatasının düzeltilmesi

## 5.1 Üç aday, ölçülerek

Bir kartın değeri, **kaç dalgayı etkilediğiyle** ölçülür. 20 dalgalık Standard modda:

| | V1: 5/10/15/20 | Kullanıcı: 4/8/12/16 | **[PROPOSAL] V2: 3/7/11/15** |
|---|---|---|---|
| Kart 1 etkilediği dalga | 15 | 16 | **17** |
| Kart 2 | 10 | 12 | **13** |
| Kart 3 | 5 | 8 | **9** |
| Kart 4 | **0** ← hata | 4 | **5** |
| **Toplam etki-dalgası** | **30** | **40** | **44** |
| Boss 10 öncesi hazırlık | 0 dalga (kart 10'da, boss'la aynı anda) | 2 dalga | **3 dalga** |
| Boss 20 öncesi hazırlık | — | 4 dalga | **5 dalga** |

**V1 açıkça hatalı.** Kullanıcının önerisi hatayı düzeltiyor. V2 dört etki-dalgası ve iki
kritik hazırlık dalgası daha kazandırıyor.

## 5.2 W3 neden W4'ten iyi — ve farkın küçük olduğunu kabul ederek

Dürüst olmak gerekirse **W3 ile W4 arasındaki fark marjinal**. Asıl düzeltme "20'ye kart
koyma"ydı ve onu ikisi de yapıyor. W3'ü tercih etmemin iki gerekçesi var:

1. **İlk kart bir öğretme anıdır.** Kart ekranını ne kadar erken görürse, oyuncu run'ın
   kimliğinin değişebileceğini o kadar erken öğrenir. **[BUILT]** `upgrade_choice.gd` zaten
   ağacı duraklatıyor, yani bu tam ekran bir olay — erken olması iyi.
2. **W3'te seçim gerçekten ilginç.** Oyuncunun 2–3 kulesi var, yani "Fire kuleleri +%25"
   bir kuleyi etkiliyor; "+2 altın/öldürme" ise 17 dalga boyunca bileşikleniyor. Yani ilk
   kart, oyuncuya **erken kartın ekonomi kartı olduğunu** oynatarak öğretir. W4'te bu ders
   biraz zayıflar.

Kullanıcının 4/8/12/16'sı kabul edilebilir bir alternatif. Playtest'te ikisi de denenebilir
(Bölüm 27).

## 5.3 Neden 4 kart, 5 değil

Kart ekranı **ölü zamandır** — oyun durur, oyuncu okur. Kabaca 20 saniye sürer.

| Kart sayısı | Ölü zaman | 10,5 dk'lık run'ın yüzdesi |
|---|---|---|
| 3 | 60 sn | %9,5 |
| **4** | **80 sn** | **%12,7** |
| 5 | 100 sn | %15,9 |
| 6 (**[BUILT]** `CHOICE_EVERY = 3`) | 120 sn | %19,0 |

**[BUILT]** Mevcut ayar 3 dalgada bir, yani 20 dalgada 6 kart ve run'ın beşte biri menüde.
Dört, run kimliği ile akış arasındaki denge noktası.

## 5.4 Ortaya çıkan ritim

```
W1  W2  [W3 KART]  W4  W5  W6  [W7 KART]  W8  W9  [W10 BOSS]
                                                       │
[W11 KART]  W12  W13  W14  [W15 KART]  W16 ... W19  [W20 FİNAL BOSS]  →  ZAFER
```

Üç iyi özellik:

1. **W11 kartı, boss'u yendikten hemen sonra gelir.** Bir zaferin ardından gelen ödül,
   dalga arasına serpiştirilmiş ödülden çok daha güçlü hissettirir.
2. **W15'ten sonra beş dalgalık temiz koşu var.** Son beşte yeni hiçbir şey tanıtılmaz —
   ne kart, ne arketip. Final, ustalığı sınar, kural öğretmez.
3. **Her kart bir zorluk artışının öncesindedir**, sonrasında değil: W3 ilk gerçek testten
   sonra, W7 boss'tan önce, W15 finale girmeden önce.

---

# 6. Kart havuzu — oyunun ana tekrar oynanabilirlik sistemi

## 6.1 Neden roster değil kart

| | 100 kule | 4 kule × 2 branch + 22 kart |
|---|---|---|
| Ezberlenecek kimlik | 100 | 4 iş + 8 ultimate + o an ekrandaki kart |
| Farklı run şekli | ~1 (meta build) | 16 branch seti × kart çekilişleri = yüzlerce |
| Sanat maliyeti | 100 × N tier | 8 kule + **0** (kart = metin + ikon) |
| Bir birim içeriğin maliyeti | sanat + kod + tier + tooltip + denge | **`Game.UPGRADE_POOL`'da bir satır** |
| Çeşitliliğin hissedildiği yer | run'dan önce, mağazada | **run sırasında, seçim anında** |

Son satır belirleyici: **roster çeşitliliği bir kez tüketilir** (en iyi build'i bulan kişi
tarafından); **run çeşitliliği her oyuncu tarafından her run yeniden tüketilir.**

**[BUILT]** Ve bu sistemin maliyeti sıfır: `Game.UPGRADE_POOL`, `Run.roll_choices()`,
`Run._fold_into`, `TowerMods.fold`, `upgrade_choice.gd`, `Balance.RARITY_WEIGHTS` ve
`RARITY_WAVE_DRIFT` zaten yazılmış ve çalışıyor.

## 6.2 Cross-element kartlar — tarif bulmacası yerine yerleşim bulmacası

Bu, tasarımın **ana stratejik kancası**. Element TD'de Fire + Water = *yeni bir kule inşa
et* (ve 15 satırlık tarif tablosunu ezberle). Burada Fire + Water = **iki kuleyi nereye
koyduğun**.

İki farklı bulmaca türü var ve ikisi de havuzda bulunur:

| Tür | Koşul | Zorluk |
|---|---|---|
| **Bitişiklik** | Kule A, kule B'nin 140 px'i içinde | Kolay görülür, kolay kurulur |
| **Örtüşme** | *Düşman* iki elementten de etkilenmiş | Daha derin — menzil çemberlerinin kesişimini düşündürür |

Dört elementin altı çifti, altı kart:

| Kart | Çift | Etki | Tür |
|---|---|---|---|
| **STEAM** | 🔥+💧 | Chill'li düşmanlar Fire burn'ünden **+%50** hasar alır | örtüşme |
| **EROSION** | 💧+🪨 | Chill'li düşmanlara Earth **+%40** hasar verir | örtüşme |
| **MAGMA** | 🔥+🪨 | Earth splash'i, vurduğu yanan düşmanların burn süresini **yeniler** | örtüşme |
| **EMBERSEED** | 🔥+🌿 | Zehirli bir düşman **yanarak** ölürse zehir tek komşuya değil **üç** komşuya geçer | örtüşme |
| **BLOOM** | 💧+🌿 | Bir Water kulesinin 140 px'indeki Nature kuleleri poison'ı **%30 daha hızlı** tick'ler | bitişiklik |
| **BEDROOT** | 🪨+🌿 | Bir Nature kulesinin 140 px'indeki Earth kuleleri splash'iyle **zehir de** bulaştırır | bitişiklik |

Bunların hepsi **[BUILT]** mevcut sistemle ifade edilebilir: aura mantığı (`aura_radius`
/ `aura_stat`, komşular tarafından `Tower._recompute()` içinde okunuyor) bitişiklik
kartlarını, `projectile.gd` `_apply()` içindeki durum kontrolü örtüşme kartlarını taşır.
Yeni mimari gerekmiyor.

## 6.3 Yirmi iki kartlık başlangıç havuzu

**Oran hedefi:** mekanik %36 · cross-element %27 · ekonomi %18 · run kimliği %18.
"+%5 hasar" tipi dolgu kart yok; en zayıf kart bile *bir davranışı* değiştiriyor.

### Kule mekaniği (8)

| Kart | Nadirlik | Etki |
|---|---|---|
| **Wick** | common | Burn süresi iki katı |
| **Permafrost** | common | Chill süresi +1,5 sn |
| **Long Sight** | common | Tüm kuleler +25 menzil |
| **Backdraft** | rare | Fire'ın burn'ü ayrıca **%15 yavaşlatır** — Fire kontrol kazanır |
| **Aftershock** | rare | Earth splash'i 0,3 sn sonra **%40 ile tekrar** vurur |
| **Spore** | rare | Nature kuleleri **uçanlara +%60** hasar — Nature anti-air uzmanı olur |
| **Overclock** | epic | Her kulenin her **5. atışı çift** vurur |
| **Groundwork** | legendary | **Earth artık göğe ateş edebilir**, ama splash'i yarıya iner |

**Groundwork** kasıtlı olarak run-belirleyici: bir elementin *yapısal* zaafını gerçek bir
bedelle kaldırıyor. Bu, "+%50 hasar"ın asla veremeyeceği bir karar.

### Cross-element (6)

Yukarıdaki tablo. Nadirlik: BLOOM ve BEDROOT rare; STEAM ve EROSION rare; MAGMA ve
EMBERSEED epic.

### Ekonomi (4)

| Kart | Nadirlik | Etki |
|---|---|---|
| **Prospector** | common | +2 altın / öldürme |
| **Foreman** | common | Yükseltmeler **%20 ucuz** |
| **Salvage** | rare | Satış iadesi **her zaman %100** — deneme özgürlüğü |
| **Compound** | epic | Dalga sonu faizi **%5 → %8** (cap aynı) |

### Run kimliği (4)

| Kart | Nadirlik | Etki |
|---|---|---|
| **Deadeye** | epic | Tüm kuleler artık **canı en az olan** düşmanı hedefler |
| **Bulwark** | epic | **+5 can**, ama tüm kuleler −%10 hasar |
| **Monoculture** | legendary | Bir element seç: o **+%50**, diğer üçü **−%20** |
| **Frontload** | legendary | Anında **+300 altın**, ama öldürme başına altın **−%25** |

**Monoculture** ve **Frontload** run'ın *şeklini* değiştiriyor, gücünü değil. Biri
uzmanlaşmaya zorlar, diğeri ekonominin eğrisini tersine çevirir. İyi bir legendary'nin
işi budur.

## 6.4 Kurallar

| Kural | Değer | Gerekçe |
|---|---|---|
| Sunulan kart | **3**, 1 seçilir | Telefonda yatay modda okunabilir maksimum |
| Reroll | **Yok** | Reroll seçimi bedavaya çevirir |
| Havuz büyümesi | 22 → ~40 (hesap seviyesiyle) | Bölüm 13 |
| Nadirlik | 4 kademe, dalga derinliğiyle iyiye kayan | **[BUILT]** `Balance.RARITY_WEIGHTS` + `RARITY_WAVE_DRIFT` aynen kalır |
| Metin bütçesi | **≤10 kelime** + 1 ikon | Bölüm 25 |
| Aynı kart tekrarı | `max_stacks` ile sınırlı | **[BUILT]** zaten var |

---

# 7. Matchup çarpanları

## 7.1 V1 dengeyi arayüz için seçti

V1 ×2.0'ı şu gerekçeyle seçiyor: *"'İki kat hasar' bir çocuğun zaten sahip olduğu bir
kavram. 1,75 ise anlatılması gereken bir sayı."*

Bu **arayüz gerekçesiyle denge sayısı seçmektir.** Rozet "×2" yazabilsin diye çarpan 2,0
yapılmış. Oysa rozetin sayı göstermesi hiç gerekmiyor (7.4).

## 7.2 ×2.0 neden baskın

Bir kararın ne kadar önemli olduğu, diğer kararlarla kıyaslanarak ölçülür:

| Karar | Getirisi |
|---|---|
| İyi yerleşim (viraj) vs kötü (düz yol) | ~±%50 (menzilde geçirilen süre) |
| Doğru branch vs yanlış branch | ~±%40 |
| Bir run'daki dört kartın toplamı | ~+%60–100 |
| **Doğru elementi dikmek — ×2.0'da** | **+%100, tek başına** |
| **Doğru elementi dikmek — ×1.6'da** | **+%60** |

×2.0'da matchup **oyundaki en büyük tek kaldıraç** olur ve optimal strateji şuna iner:
*dalganın rengini oku, karşıt rengi dik.* Yerleşim, branch ve sinerji ikinci plana düşer.

×1.6'da matchup, yerleşim ve branch ile **aynı ligde** oynar. Hedef bu.

**[PROPOSAL] Başlangıç değerleri:**

| | Değer | Gerekçe |
|---|---|---|
| Güçlü | **×1,6** | Yerleşim/branch ile aynı büyüklük sınıfında |
| Nötr | ×1,0 | — |
| Zayıf | **×0,85** | Ödülden kasten daha yumuşak — **ödül-öncelikli asimetri** |

Tam doğru element ile tam yanlış element arası fark: **1,88 kat**. Hissedilir, belirleyici
değil. (Kullanıcının önerdiği ×1,5 / ×0,8 pratikte neredeyse aynı: 1,875 kat. İkisi de
kabul edilebilir; ×1,6 / ×0,85 ödülü biraz daha yüksek, cezayı biraz daha alçak tutuyor.)

**[BUILT]** Mevcut: `Game.ELEMENT_STRONG = 1.75`, `ELEMENT_WEAK = 0.7`. Yani 2,5 kat fark
— V1'in önerdiği ×2.0/×0.8'den bile daha keskin.

## 7.3 Çarpandan daha güçlü kaldıraç: kaç dalganın zırhı var

V1'in tamamen atladığı nokta. **[BUILT]** `wave_generator.gd` `ELEMENT_CYCLE` zırh
elementlerini sırayla dağıtıyor ve `Game.WAVES` 5. dalgadan sonra neredeyse her dalgaya bir
element veriyor. Yani **pratikte her dalganın zırhı var.**

Her dalganın zırhı varsa, oyuncuya her dalga aynı soru sorulur ve matchup çarpanı ne olursa
olsun oyunun ritmi "renk oku, renk dik" olur.

**[PROPOSAL] Dalgaların ~%60'ı zırhlı olsun.** Zırhsız kalacaklar:

| Dalga | Neden zırhsız |
|---|---|
| 1–3 | Öğretim. Tek seferde tek fikir. |
| Bütün boss dalgaları (10, 20) | Boss'un zaten bir kuralı var; üstüne zırh koymak iki soruyu üst üste bindirir |
| Flyer ve Splitter dalgaları | Arketip zaten zor bir soru soruyor |
| Kalanın ~1/3'ü | Genel gücün — yerleşim, branch, kart — cevap olduğu dalgalar |

Sonuç: 20 dalganın ~12'si zırhlı. Matchup **baharat** olur, ana yemek değil.

Ayrıca dört elementle zırhlı bir dalgada: 1 güçlü, 1 zayıf, **2 nötr** kule vardır. Yani
karma bir savunma zırhlı dalgada bile çalışır — sadece optimal değildir. Doğru his bu.

## 7.4 Geri bildirim — sayı göstermeden

V1'in "×2 rozeti" fikri, çarpan 2,0 olmadığında çalışmaz. Daha iyisi:

> **Hasar sayısının kendisi zaten daha büyük.** Ekranda okunan rakam gerçek hasar.
> Güçlü vuruşta o rakam **büyük, altın renkli ve yukarı ok'lu** çıkar; zayıf vuruşta
> **küçük ve gri**. Çarpanın kendisi hiçbir yerde yazmaz.

**[BUILT]** `projectile.gd` `_show_damage()` (satır 136-146) zaten tam olarak bunu yapıyor:
güçlü vuruşta 26 punto altın, zayıf vuruşta 16 punto gri. Eklenecek tek şey ok işareti.
(V1 bu kodu `floating_text.gd`'de sanıyordu; orası sadece etiketi çiziyor.) Bu, çarpan hangi sayı olursa olsun çalışır — yani **denge, arayüzden
bağımsızlaşır.**

---

# 8. Faiz ve ekonomi üçgeni

## 8.1 Mekanizma fikirden ayrılır

**[EXTRACTED]** Element TD faizi 15 saniyede bir, %2,5, cap'siz veriyor ve oyuncu bunu
ancak bir ipucu metnini okuyarak öğreniyor (ipucu #4 — Bölüm 2.1). V1 bu mekanizmayı
"türün en iyi kararı" diye neredeyse dokunulmaz ilan etti.

**V1 mekanizmayı fikirle karıştırdı.** Değerli olan *harca-mı-biriktir* gerilimi. Görünmez
bir 15 saniyelik timer, mobilde o gerilimi taşıyamaz — oyuncu ne zaman ödendiğini bilmez,
ne kadar ödendiğini görmez.

**[PROPOSAL] Dalga sonunda, %5, cap +60, ve HUD'da görünür.**

Hazırlık aşamasında HUD şunu gösterir:

```
   💰 340      ⟳ +17
```

Yani "bankanda 340 var, bu dalgayı böyle bitirirsen +17 alacaksın". Görünmez mekanik,
görünür karara dönüşür — ve **[EXTRACTED]** haritanın bir cümleyle anlatmak zorunda kaldığı
şey, ikonla anlatılmış olur.

## 8.2 Faiz neden bileşiklenip oyunu bozmuyor

50 altınlık bir kule ~25 DPS ekler. Aynı 50 altını 10 dalga bankada tutmak:
`50 × (1,05¹⁰ − 1) = 31 altın` kazandırır.

**Yani 10 dalga biriktirmek, bir kule almaya bile yetmiyor.** Faiz süresiz istifi
ödüllendirmiyor; **bir eşiğe doğru biriktirmeyi** ödüllendiriyor — mesela 3 dalga sonra
200 altınlık bir ultimate almak için. Doğru davranış bu.

Cap +60, bankada **1.200** altında bağlanır — yani "iki buçuk tam kule değerinden fazlasını
elde tutmak artık para kazandırmaz". Okunabilir bir tavan.

Uçtan uca kontrol: hiç harcamayan bir oyuncu 20 dalgada toplam ~870 faiz kazanır (dalga
9'dan sonra cap bağlar). Ama hiç harcamayan oyuncu 5. dalgada ölür. Gerçekçi bir
biriktirici ~400–500 kazanır: toplam gelirin **~%8'i**. Anlamlı, asla baskın değil.

## 8.3 Ekonomi üçgeni — üç teşvik birbiriyle yarışmalı

```
                    HARCA
              (daha güvenli savunma)
                     ╱   ╲
                    ╱     ╲
                   ╱       ╲
                  ╱         ╲
            BİRİKTİR ───── ERKEN ÇAĞIR
             (faiz)         (bonus altın)
```

Üçü de aynı altını istiyor ve hiçbiri her zaman doğru değil. Ama **V1'in kurgusunda bu
üçgen yoktu** — çünkü erken çağırmanın hiçbir maliyeti yoktu.

### V1'in gizli açığı

**[BUILT]** "Send Next ▶" butonu sadece hazırlık boşluğunda, yani **mevcut dalga zaten
temizlenmişken** aktif. Ve **[BUILT]** kule dikmek dalga sırasında da serbest. Yani erken
çağırmanın riski **sıfır**: optimal oyun her dalgayı erken çağırmaktır. Bu bir karar değil,
bir tıklama vergisi.

### [PROPOSAL] Düzeltme: erken çağır gerçek risk taşısın

> **"Erken çağır", mevcut dalganın *spawn'ı bittiği* anda açılır — düşmanlar hâlâ yoldayken.
> Ne kadar çok düşman hayattaysa bonus o kadar büyük.**

`erken_bonus = (3 + dalga) + 2 × hayattaki_düşman`, tavan `3 × (3 + dalga)`.

Butonun üstünde o anki değer yazar, yani karar görünürdür:

```
   ▶ SONRAKİ DALGA   +38
```

Bu, **[EXTRACTED]** Element TD'nin çok oyunculu yarış baskısını ("herhangi bir oyuncu
seviyeyi bitirdiğinde sonraki seviye herkes için başlar") tek kişilik bir mekaniğe çeviriyor
— ki V1 §1.8 tam olarak bunun hayatta kalması gerektiğini yazmıştı ama mekaniği kurmamıştı.

**Sömürü kontrolü:** her dalgada maksimum riskle çağıran bir oyuncu run boyunca ~+400
altın kazanır (toplam gelirin ~%7'si) — karşılığında iki dalgayı üst üste bindirme riskini
alarak. Dengeli. Ve run 20 dalga olduğu için erken çağırmak *ekstra dalga* kazandırmaz,
yani sonsuz farm mümkün değil.

---

# 9. Kule satışı

## 9.1 Problem

**[BUILT]** `Balance.SELL_REFUND = 0.5`. Yerleşim hatasını düzeltmek, harcadığının yarısına
mal oluyor — yani oyun, acemi oyuncunun **öğrenmek için yapması gereken şeyi** cezalandırıyor.

**[EXTRACTED]** Element TD bunu doğru yapmış: element dışı kuleler **%100**, element
kuleleri **%75** iade ediyor. Yerleşim kalıcı değil, dolayısıyla denemek bedava.

Ama koşulsuz %100 de doğru değil: uzman oyuncu her dalga öncesi tüm savunmayı bedavaya
taşıyabilir, ki bu yerleşim kararını tamamen ortadan kaldırır.

## 9.2 [PROPOSAL] İki kademeli iade

> **Kule henüz hiç ateş etmediyse: %100.
> Bir kez bile ateş ettiyse: %80.**

Tek koşul, dört kelimeyle anlatılır: *"Ateş etmeden satarsan tamamını alırsın."*

| Uygulama detayı | Karar |
|---|---|
| Koşul | Kulenin `has_fired` bayrağı — ilk mermiyi çıkardığında `true` olur |
| Görsel | Satış ✕'i, %100 iade geçerliyken **yeşil**, sonra **kırmızı** |
| Sıfırlanır mı | Hayır. Bir kez ateş eden kule kalıcı olarak %80'e düşer |
| Yükseltmeler | Aynı oran, `total_spent` üzerinden — **[BUILT]** `tower.gd:273` zaten böyle hesaplıyor |

Neden "ateş etti mi", "dalga başladı mı" değil: oyuncu bir kuleyi dalga ortasında yanlış
yere dikip menzil dışında kaldığını fark edebilir. O kule hiç ateş etmediyse hata hâlâ
ücretsiz düzeltilebilir olmalı. Koşul **oyuncunun hatasını** ölçüyor, saati değil.

**Salvage kartı** (Bölüm 6.3) bunu run boyunca %100'e sabitler — yani "özgürce dene" bir
build kimliği hâline gelir.

---

# 10. Dalgalar, düşmanlar ve boss'lar

## 10.1 Altı arketip

**Bir dalga bir sorudur.** Sadece "+%10 can" olan dalga hiçbir şey sormaz; oyuncu geçen
dalgada ne yaptıysa aynısını yapar ve oyun sürüklenen bir sürgüye döner.

| # | Arketip | Sorduğu soru | Cevabı | İlk görünüş | Görsel işaret (metinsiz) |
|---|---|---|---|---|---|
| 1 | **Runner** | yok — her şeyin ölçüldüğü taban | her şey | **W1** | sade, orta boy, yürür |
| 2 | **Sprinter** | yavaş atan kule iki kez ateş edemeden menzilden çıkar | Water (Chill), hızlı Fire, girişe yakın yerleşim | **W3** | küçük, öne eğik, toz izi |
| 3 | **Swarm** | tek hedef DPS'i *sayıya* yetişemez | Earth splash, Wildfire, Quake, Blight | **W5** | çok sayıda minik gövde, sıkı küme |
| 4 | **Brute** | çok can **+ %40 hasar azaltma + kontrole bağışık** | Siege (zırh çatlatır), Nature poison (zırhı yok sayar), Blaze | **W7** | kocaman, ağır, zırh plakaları, vuruşta parlama |
| 5 | **Flyer** | yolu takip etmez ve **Earth ona ateş edemez** | Earth dışında her şey | **W9** | havada, yerde gölgesiyle |
| 6 | **Mender** | sürekli iyileşir, kesintili hasar işe yaramaz | **Blight (tek gerçek cevap)**, sürekli DPS | **W12** | üstünde nabız gibi atan yeşil artı; bastırılınca nabız **durur** |
| B | **Boss** | bir *kural*, artı çok can | build'e bağlı | **W10, W20** | taçlı, ekranı dolduran, üstte kendi can barı |

**[BUILT]** Hepsi zaten `Game.WAVE_TYPES` içinde var (`normal`, `fast`, `swarm`, `tank`,
`immune`, `regen`, `air`, `split`) ve **hepsi 12 kareli animasyon döngüleriyle boyanmış**.
Yapılacak iş *birleştirmek*, üretmek değil: `immune` → `tank` içine erir, ikisi **Brute**
olur. `split` prototipte devre dışı kalır, Faz 2'de döner.

### Reddedilen arketipler

| Arketip | Neden hayır |
|---|---|
| **Magic-resistant** (zırhlıdan ayrı) | İki "dirençli" kavramı bir fazla. Brute üç sonucu tek siluette taşıyor. |
| **Stealth / görünmez** | 6 inçlik ekranda görmediğin düşman bulmaca değil, hata raporudur. |
| **Shielded** (ikinci can barı) | Zırhlının üstüne fazladan UI. İki bar, stat okumasının başlangıcıdır. |
| **Healer / destek düşman** | *Diğer* düşmanları problem yapar; oyuncu hasarının neden işlemediğini göremez. Mender sadece kendini iyileştirir, bu okunur. |
| **Miniboss** | "Elite" dalga (daha az, çok daha sert) aynı işi mevcut arketiple yapar. **[BUILT]** `wave_generator.gd` `ELITE_EVERY` zaten var. |

## 10.2 Zırh kuralı (Bölüm 7.3'ün uygulaması)

> **Bir dalga şu üç durumda zırhsızdır: öğretim dalgalarıysa (1–3), boss dalgasıysa, ya da
> bir arketipi ilk kez tanıtıyorsa.**

"Tek seferde tek fikir" ilkesinin zırha uygulanmış hâli. 20 dalganın 9'u zırhsız, 11'i
zırhlı — **%55**.

## 10.3 Standard mod, dalga dalga

| Dalga | İçerik | Zırh | Öğrettiği | Olay |
|---|---|---|---|---|
| 1 | Runner ×9, yavaş | — | kule dik, ateş etmesini izle | |
| 2 | Runner ×10 | — | kule yükselt | |
| 3 | **Sprinter** ×13 | — | hız kaçar; Water tutar | **KART 1** |
| 4 | Runner ×12 | 🔥 | **ilk matchup** — Water büyük altın sayılar basar | |
| 5 | **Swarm** ×26 | — | tek kule yetmez | |
| 6 | Sprinter ×15 | 💧 | matchup'ı baskı altında uygula | |
| 7 | **Brute** ×5 | — | zırh + kontrol bağışıklığı; poison ve Siege | **KART 2** |
| 8 | Swarm ×28 | 🌿 | ilk kez iki problem üst üste | |
| 9 | **Flyer** ×12 | — | Earth ıskalar; kapsama karışık olmalı | |
| 10 | **BOSS — Muhafız** | — | kontrol işlemez, hasar gerek | **BOSS** |
| 11 | Runner ×19 + Sprinter ×6 | 🪨 | ilk karışık dalga | **KART 3** |
| 12 | **Mender** ×10 | — | sürekli hasar olmadan ölmez | |
| 13 | Brute ×7 | 🪨 | Nature hem zırhı geçer hem iyileşmeyi keser | |
| 14 | Flyer ×16 | 🔥 | hava + matchup | |
| 15 | Swarm ×32 + Mender ×6 | 💧 | iyileşen, kalabalığın içine saklanır | **KART 4** |
| 16 | **Elite** Brute ×3 | 💧 | daha az, çok daha sert | |
| 17 | Sprinter ×20 | 🌿 | kötü matchup altında hız | |
| 18 | Flyer ×14 + Runner ×10 | 🔥 | son kombinasyon | |
| 19 | Brute ×8 + Swarm ×20 | 🌿 | her iki uç aynı anda | |
| 20 | **FİNAL BOSS — Uyanmış Muhafız** | döner | ustalık sınavı | **ZAFER** |

İki özellik kasıtlı:

1. **Dalga 15'ten sonra hiçbir yeni şey tanıtılmaz** — ne arketip, ne kart, ne mekanik.
   Final, öğrendiklerini sınar; kural öğretmez.
2. **Her yeni fikir kendi dalgasında, yalnız gelir.** Sprinter tek başına W3'te, Swarm tek
   başına W5'te. Kombinasyonlar W11'den sonra başlar.

## 10.4 Boss tasarımı — kural, can barı değil

**[BUILT]** Şu an boss `hp ×6, hız ×0.6, ödül ×10, 10 can`. Yani sadece büyük bir Runner:
hiçbir kararı değiştirmiyor.

**[PROPOSAL] Her boss'un tek bir kuralı olur ve o kural can barının üstünde ikon olarak durur.**

### Boss 1 — **MUHAFIZ** (W10): *kontrole tamamen bağışık*

Yavaşlamaz, donmaz, itilmez, sendelemez. Yani **Water'ın hiçbir branch'i işlemez**, Quake'in
sendeletmesi de.

Sorduğu soru: *"Kontrolün arkasına saklandın. Ya gerçek hasarın var mı?"*
Cevabı: Blaze, Siege, Blight — ve boss çıkışa varmadan onu düşürecek kadar yoğunluk.

V1 bunu "yavaşlatılamaz" diye yazmıştı. **Tek bir kontrol türünü yasaklamak yerine
hepsini yasaklamak daha temiz**: oyuncu tek bir ikon öğrenir, ve Undertow gibi yeni bir
kontrol eklendiğinde kural kendiliğinden kapsar.

### Boss 2 — **UYANMIŞ MUHAFIZ** (W20): *zırhı 5 saniyede bir değişir*

Altındaki halka 🔥 → 💧 → 🪨 → 🌿 diye döner. Görsel olarak tartışmasız okunur.

Sorduğu soru: *"Tek elemente mi yatırdın, dördüne mi?"*

**Kullanıcının önerdiği "küçük düşmanlar doğurur" alternatifini değerlendirdim ve
reddediyorum:** düşman doğurmak *aynı problemden daha fazlasını* ekler — yani W19'da zaten
sorulmuş soruyu tekrar sorar. Dönen zırh **farklı** bir soru sorar ve tam olarak final
boss'un sorması gereken soruyu sorar: bütün run boyunca verdiğin element kararlarının
toplamı neydi?

Yan fayda: **Monoculture** kartını (Bölüm 6.3) gerçek bir takasa çevirir. Mono build
boss'a karşı ortalama ×1,11 alır, karışık build her an bir sayaca sahiptir. Ceza sert değil,
ama hissedilir — legendary bir kartın taşıması gereken tam da bu.

### Boss sayıları

| | Değer | V1 | Neden |
|---|---|---|---|
| Can | wave eğrisi **×8** | ×6 | Boss ayrı bir olay olmalı |
| Hız | **×0,7** | ×0,6 | Çok yavaş boss sıkıcı bir bekleyiş olur |
| Ödül | **×12** | ×10 | Run'ın sonraki üçte birini görünür şekilde finanse etmeli |
| Sızarsa can | **5** | **10** | 20 canın yarısı, tek hata için fazla. Genç oyuncu için run bitirici. |

---

# 11. Standard mod ve oturum süresi

## 11.1 En büyük yapısal değişiklik: run kazanılabilir olmalı

**[BUILT]** Şu an run **sonsuz**, kazanma koşulu yok, son dalga yok; sadece canlar bitince
biter. **Yani her oturum yenilgiyle sonlanıyor.**

> Kaybetmiş bir oyuncu *tekrar deneyip denemeyeceğine* karar verir.
> **Kazanmış** bir oyuncu *sırada ne deneyeceğine* karar verir.
> İkincisi yarın uygulamayı tekrar açar.

**[EXTRACTED]** Element TD'nin kendisi de sonsuz değil: 60 seviye ve bir "Congratulations"
mesajı var. Sonsuz iyi bir *mod*, kötü bir *varsayılan*.

## 11.2 Süre aritmetiği — V1 bu hesabı hiç yapmadı

V1 "12–14 dakika" dedi ve aynı belgede "oturum başına 1,8 run" hedefledi. 1,8 × 13 = **23–25
dakikalık oturum**, ki mobil için iyimser.

Hedef: **~10,5 dakika.** Bütçe:

| Kalem | Süre |
|---|---|
| İlk hazırlık | 10 sn |
| 20 dalga × ortalama ~26 sn | 520 sn |
| 4 kart ekranı × 20 sn | 80 sn |
| **Toplam** | **~610 sn = 10,2 dk** |

Dalga başına 26 saniye şu demek: 3 sn hazırlık + ~7 sn spawn + ~16 sn temizleme.

| Ayar | **[BUILT]** | **[PROPOSAL]** |
|---|---|---|
| Dalgalar arası hazırlık | 4,0 sn (`PREP_TIME`) | **3,0 sn** |
| İlk dalga öncesi | 12,0 sn (`FIRST_PREP_TIME`) | **10,0 sn** |
| Spawn aralığı | 0,9 → 0,3 sn | **0,7 → 0,3 sn** |
| Dalga başına düşman | `9 + 1,2n`, tavan 28 | **`8 + n`, tavan 28** |

**Kritik uyarı:** `CLAUDE.md` ve `balance.gd` `BASE_SPEED_FLAT` / `BASE_SPEED_LINEAR`'ın
**yol uzunluğuna bağlı** olduğunu ve başka hiçbir yerin o uzunluğu okumadığını kaydediyor.
**[BUILT]** mevcut spiral yol 3.992 px ve dalga-1 geçişi ~55 sn — yani *sızan* bir düşman
yolu terk etmek için neredeyse iki dalga süresi harcıyor.

**[PROPOSAL]** Prototip haritasının yolu **~2.800–3.200 px** hedeflensin. Bu, hız sabitlerini
artırmadan (yani okunabilirliği bozmadan) dalga süresini kısaltır. Değişiklikten sonra
`--dump-board` ile ölçülmeli — bu sayı hissedilerek ayarlanamaz.

**Bu bölümdeki süre tahmini ölçülmemiş bir tahmindir.** V1'in hatası sayıyı ölçmeden iddia
etmekti; V2 aynı hatayı yapmamak için: `--shot:N` ile gerçek bir run zamanlanmalı
(BUILD NEXT #9).

## 11.3 Modlar ve ne zaman gelirler

| Mod | Dalga | Süre | Ne katıyor | Faz |
|---|---|---|---|---|
| **Standard** | 20 + 2 boss | **~10,5 dk** | Ana oyun. Kazanılabilen tam bir yay. Yıldızlar burada kazanılır. | **Faz 1** |
| **Endless** | ∞, her 10'da boss | açık uçlu | "Ne kadar derine inebilirim." Skor = dalga. | Faz 2 |
| **Quick** | 10 + 1 boss | ~5 dk | Otobüs durağı formatı. Maks 2 yıldız — kolay yol değil, *format*. | Faz 3 |
| **Challenge** | 12, sabit seed + zorunlu modifier | ~7 dk | Haftalık. Herkes için aynı. Karşılaştırma yüzeyi. | Faz 3 |

**[BUILT]** `wave_generator.gd` korunur ama **rütbesi düşer**: sadece Endless'ı besler.
Standard el yazımı 20 dalgalık tabloyu kullanır.

---

# 12. Haritalar — ve V1'in çelişkisinin çözümü

## 12.1 Çelişki

| Konum | İfade |
|---|---|
| `GAME_STRATEGY.md:977` | Hard ruleset: *"tam yol **+ dalga 12'den itibaren ikinci bir giriş**"* |
| `GAME_STRATEGY.md:982-990` | *"Tek yol, en fazla bir opsiyonel dal… iki bağımsız şerit… telefonda oyuncu birini tamamen kaybeder."* — ve bu bölüm kendini *"tercih değil, katı kısıt"* diye tanımlıyor |

**[PROPOSAL] Çözüm: kural kalır, ikinci giriş gider.**

> **Bir haritada her zaman tek giriş ve tek çıkış vardır. En fazla bir opsiyonel dal olur
> ve o dal ana yola geri katılır. İki bağımsız şerit hiçbir zorluk seviyesinde olmaz.**

## 12.2 Hard neyi değiştirir — yol değil, alan ve zamanlama

| | Easy | Normal | **Hard** |
|---|---|---|---|
| Düşman canı | %70 | %100 | **%135** |
| Düşman sayısı | %85 | %100 | **%115** |
| Başlangıç altını | 150 | 120 | **100** |
| Can | 25 | 20 | **15** |
| Yol | tam | tam | **kısaltılmış** — bir kıvrımı atlayan bypass |
| İnşa alanı | tamamı | tamamı | **bir blok kapalı** |
| Modifier | yok | yok | **bir tane, boyamada görünür** |

**Kısaltılmış yol neden Hard?** Kısa yol = kulelerin ateş edeceği daha az süre = daha zor.
V1 bunu tersten kurmuştu (Easy'ye kısa yol vermişti), ki bu Easy'yi *zorlaştırırdı*.

Can/sayı ikilisi doğrudan **[EXTRACTED]** Element TD'nin kendi zorluk tasarımı:
`50 + 12,5×(zorluk−1)` % can ve `15 + 3×zorluk` adet. Tek seçim iki şeyi birden ölçekliyor
ve alttaki eğri hiç değişmiyor.

**[BUILT]** Ve bu ucuz: `Game.configure_board()` zaten yol, engeller ve inşa bölgelerini
parametre olarak alıyor. Bir ruleset, aynı boyamanın ikinci profilidir.

## 12.3 Modifier listesi (sadece Hard, harita başına bir tane)

Hepsi **boyamada görünür** — gizli bilgi yok:

| Modifier | Etki | Zorladığı karar | Görsel |
|---|---|---|---|
| **Sağanak** | Fire burn süresi −%40 | Fire buranın varsayılan cevabı değil | yağmur, ıslak taşlar |
| **Heyelan** | Bir inşa bloğu kapalı, +40 başlangıç altını | Daha az nokta, nokta başına daha zengin | moloz yığını |
| **Zengin Damar** | +2 altın/öldürme, −5 can | Agresif ekonomi, güvenlik ağı yok | yerdeki altın damarları |

### Reddedilen modifier'lar

**Sis / görüş kısıtı** (telefonda okunmaz ve görmediğin sızıntı hata raporudur) ·
**yıkılabilir dekor** (başparmak boyutunda ekranda kulelerle yarışan ikinci dokunma hedefi) ·
**dalga ortasında değişen yol** (TD'nin verdiği tek sözü bozar).

## 12.4 Kaç harita, ne zaman

| Aşama | Harita | Ruleset | Seviye | Yıldız |
|---|---|---|---|---|
| **Faz 1 (prototip)** | **1** | 2 (Easy, Normal) | 2 | 6 |
| Faz 2 (soft launch) | 2 | 3 | 6 | 18 |
| Faz 3 (v1.0) | 3 | 3 | 9 | 27 |
| İçerik paketi | +3 | 3 | +9 | +27 |

**[BUILT]** Üç boyalı tahta ve izlenmiş yolları zaten var (`winding`, `spiral`, `s` —
`Game.BOARD_SEQUENCE`). Bugün *tek bir sonsuz run'ın bölümleri*; **seçilebilir seviyelere**
dönüşüyorlar.

Yıldız kriterleri — hepsi *oyunla* ilgili, harcanan zamanla değil:
**★** bitir · **★★** ≤5 can kaybet · **★★★** hiç can kaybetme.

---

# 13. Meta ilerleme

## 13.1 Filtre

Her sistem için tek soru: **hangi oyuncu motivasyonuna hizmet ediyor, ve bunu zaten başka
bir sistem yapıyor mu?** İki sistem aynı motivasyona hizmet ediyorsa biri gider.

## 13.2 Dört sistem, dört motivasyon

| Sistem | Motivasyon | İşi | Sayılar |
|---|---|---|---|
| **Yıldızlar** | başarı | Omurga. Seviye başına 3 yıldız; yıldızlar sonraki haritayı açar | Faz 1'de 6 → v1.0'da 27. Harita 2: 4 yıldızda; harita 3: 12 yıldızda |
| **Hesap seviyesi** | keşif | Her run'dan yavaş XP. Her seviye **havuza bir kart ekler** — yani seviye atlamak gelecekteki run'ları *çeşitlendirir* | 20 seviye. Seviye *n* maliyeti `60 × n` XP. Run XP = `ulaşılan_dalga × 8` (+100 tamamlarsa). ~48 run'da tamamlanır |
| **Element ustalığı** | ustalık | Element başına, o elementle verilen hasardan XP. Skin'leri ve elementine özel kartı açar | Element başına 5 kademe. **Genişliği ödüllendirir** — dördünü de kullanmak zorunda bırakır |
| **Haftalık challenge** | rekabet | Sabit seed + zorunlu modifier, herkes için aynı, Pazartesi sıfırlanır | Haftada 1. Kaçırmanın **hiçbir cezası yok** |

Kart havuzu bu iki kanaldan büyür: hesap seviyesi 12 kart, ustalık 8 kart → **22 → 42**.

## 13.3 Essence — ve kaybedilen run'ın da bir şey kazandırması

`essence = (dalga + dalga²/20) × 1,5^(tamamlandıysa) × (1 + 0,2 × yıldız)`

| Run sonucu | Essence |
|---|---|
| Dalga 8'de kaybedildi | 11 |
| Dalga 12'de kaybedildi | 19 |
| Dalga 20 tamamlandı, ★ | 72 |
| Dalga 20 tamamlandı, ★★★ | 96 |

**Kaybedilen bir run bile mükemmel bir run'ın ~%20'sini öder.** Bu, kullanıcının istediği
"başarısız run da anlamlı ilerleme üretsin" koşulunu karşılar — idle RPG'ye dönüşmeden,
çünkü Essence'ın harcanabileceği yer **sınırlı ve erken biter** (Bölüm 14).

Süperlineer eğri kasıtlı **[BUILT]** (`Balance.run_essence`): iki dalga daha derine inmek,
iki sığ run oynamaktan değerli. "Bir run daha"yı gerçek bir karar yapan şey bu.

**[PROPOSAL] Offline Essence silinir.** **[BUILT]** `Balance.offline_essence` ve
`Meta._collect_offline()` oyuncuya *oynamamanın* ilerleme olduğunu öğretiyor. Bu bir idle
oyun mekaniği ve bu oyunun mekaniği değil.

## 13.4 Faz dağılımı

| Sistem | Faz 1 prototip | Faz 2 soft launch | Faz 3 v1.0 |
|---|---|---|---|
| Yıldızlar | ✅ (6) | ✅ (18) | ✅ (27) |
| Essence + Workshop | ❌ | ✅ | ✅ |
| Hesap seviyesi | ❌ | ✅ | ✅ |
| Element ustalığı | ❌ | ❌ | ✅ |
| Haftalık challenge | ❌ | ❌ | ✅ |

**Faz 1'de meta yok, çünkü ölçülen soru "eğlenceli mi?"** İlerleme sistemi, eğlenceli
olmayan bir çekirdeğin üstüne serildiğinde sorunu **gizler**, göstermez.

---

# 14. Workshop — küçük, tavanlı ve rekabette normalize

## 14.1 Bugün ne var

**[BUILT]** `Game.WORKSHOP_DEFS`:

| Kalem | Seviye başına | Maks | Maksimumda toplam |
|---|---|---|---|
| Forge | ×1,06 hasar | 10 | **+%79 hasar** (bileşik) |
| Tempo | ×1,04 atış hızı | 8 | +%37 |
| Lens | +6 menzil | 8 | +48 px |
| Treasury | +20 başlangıç altını | 10 | +200 altın |
| Ramparts | +2 can | 8 | **20 canlık tabana +16 can** |

Maksimuma ulaşmış bir hesap, yeni bir hesapla **aynı oyunu oynamıyor**. Üç sonuç, üçü de
kötü: yeni oyuncunun kayıpları kısmen kendi hatası değil; zorluk eğrisi *bir* Workshop
seviyesine göre ayarlanmak zorunda ve herkes için yanlış oluyor; ve Essence bir gün
satılabilir hâle gelirse oyun **inşaat gereği** pay-to-win oluyor.

## 14.2 [PROPOSAL] Yeni tavanlar

| Kalem | Seviye başına | Maks | Toplam | Essence maliyeti |
|---|---|---|---|---|
| **Forge** | +%2 hasar | 5 | **+%10,4** | 330 |
| **Tempo** | +%2 atış hızı | 4 | **+%8,2** | 244 |
| **Lens** | +4 menzil | 5 | **+20 px** (~+%10) | 264 |
| **Treasury** | +15 başlangıç altını | 4 | **+60 altın** | 163 |
| **Ramparts** | +1 can | 2 | **+2 can** | 104 |
| | | | | **toplam 1.105** |

Ortalama ~50 Essence/run ile **~22 run'da tamamen biter.** Ondan sonra Essence sadece
**yatay** şeyler alır: kart havuzu genişletmeleri, ruleset'ler, kozmetikler.

Toplam savaş gücü artışı **~+%20**. V1'in önerdiği +%26'dan da düşük, mevcut +%79'un
dörtte biri. Yeterince hissedilir ki ilk hafta motive etsin; yeterince küçük ki oyunu
bölmesin.

## 14.3 V1'in tamamen kaçırdığı şey: leaderboard normalizasyonu

V1 Workshop'ı küçültmeyi önerdi ama **kalıcı gücün rekabetçi modda ne yaptığını hiç
sormadı.** Küçük bile olsa +%20, haftalık bir sıralamada kalıcı bir avantajdır — ve o
avantaj oynanan run sayısıyla (yani zamanla) korelasyonludur.

> **[PROPOSAL] Haftalık Challenge ve her türlü leaderboard modu, Workshop seviyeleri
> ZORLA 0 kabul edilerek çalışır.**

Sonuçları:
- Uzun süredir oynayan bir oyuncu, sırf istatistikleri yüzünden liderlik tablosuna hükmedemez.
- Rewarded reklam Essence'ı hızlandırdığı için **dolaylı olarak** savaş gücüne dokunuyor
  (Bölüm 16'da açıkça yazılıyor) — normalizasyon bu bağlantıyı rekabetçi modda **koparır**.
- Modun ekranında açık bir rozet: **"NORMALİZE"** — gizli kural yok.

Bu tek kural, "hızlandırma satılabilir mi?" sorusunun tehlikeli tarafını da baştan çözüyor:
satılabilir olsa bile rekabette hiçbir işe yaramaz.

---

# 15. Para kazanma — sıfırdan

## 15.1 Doğru başlangıç sorusu

V1 şuradan başladı: *"Güçlendiren hiçbir şey satılmaz."* Bu bir sonuç, başlangıç değil.

V2 şuradan başlıyor:

> **Bu oyun, oyuncular onu telefonlarında tutmaktan memnun kalırken nasıl anlamlı gelir
> üretebilir?**

## 15.2 Piyasa gerçeği

| Bulgu | Kaynak |
|---|---|
| 2026'da en iyi performans gösteren model **hybrid**: IAP + rewarded video (+ bazen pass). Hybrid artık istisna değil norm. **[MARKET]** | [GGA](https://gamegrowthadvisor.com/blog/2026-04-02-f2p-monetization-models-comparison-2026/), [AppFollow](https://appfollow.io/blog/mobile-game-monetization) |
| Rewarded video reklam gelirinin **~%60'ı**; eCPM tier-1'de **15–25 $**, global ortalama **10–22 $**; interstitial'ın ~3 katı **[MARKET]** | [Playio](https://blog.playio.co/rewarded-ad-benchmarks-2026) |
| Rewarded eklemek ARPDAU'yu **%30–66** yükseltiyor ve **IAP'yi yamyamlaştırmıyor** **[MARKET]** | [Tenjin](https://tenjin.com/blog/ad-mon-gaming-2026/), [Playio](https://blog.playio.co/rewarded-ad-benchmarks-2026) |
| Oyuncular rewarded'ı interstitial'a **4:1** tercih ediyor; tamamlama oranı **%95+** **[MARKET]** | [Playio](https://blog.playio.co/rewarded-ad-benchmarks-2026) |
| Interstitial eCPM **~14 $** — rewarded'ın belirgin altında **[MARKET]** | [Playio](https://blog.playio.co/rewarded-ad-benchmarks-2026) |
| Kurulumdan satın almaya dönüşüm **%2,6** (30 gün içinde); ödeyen oranı DAU'nun %2–5'i **[MARKET]** | [MAF](https://maf.ad/en/blog/mobile-game-conversion-rates/) |
| Midcore Android'de hybrid D90 ROAS **1,46×**, sadece-IAP **0,93×** **[MARKET]** | [MAF](https://maf.ad/en/blog/mobile-game-conversion-rates/) |
| TD pazarında freemium gelirin **%52,5'i** — ama bunu VIP kademeli, loot crate'li Asya oyunları sürüklüyor. **Batı'nın en başarılı iki TD'si tek seferlik ücretli**: Bloons TD 6 **6,99 $**, timer yok, reklam yok; Kingdom Rush premium **[MARKET]** | [Dataintelo](https://dataintelo.com/report/mobile-tower-defence-games-market), [StrategyGame](https://strategygame.org/best-android-tower-defense-games/) |

**V1'in en büyük hatası buradan görünüyor:** mobilin en değerli ve oyuncunun en çok tercih
ettiği para kazanma yüzeyini, hiçbir veriye bakmadan yasakladı.

**Teknik risk yok:** Godot 4 için olgun AdMob eklentisi mevcut — GDScript, rewarded dahil
tüm formatlar, editörde mock reklam, UMP/GDPR onay akışı dahil
([Poing Studios](https://github.com/poingstudios/godot-admob-plugin)).

## 15.3 Üç model, hesaplanarak

**Varsayımlar** — hepsi doğrulanacak tahmin, benchmark değil:

| Varsayım | Değer | Gerekçe |
|---|---|---|
| Harmanlanmış rewarded eCPM | **10 $** | Global ortalama 10–22 $ **[MARKET]**; organik kurulum ucuz bölgelere kayar, alt uç alındı |
| Rewarded izlenme / DAU | **1,5** | Günde 2 tavanı, aktif günlerin ~%65'inde kullanılıyor. Referans vaka 2,1 **[MARKET]** |
| Kurulum başına aktif gün | **5** | D1 %30 / D7 %12 / D30 %4 eğrisinin altındaki alan |
| Mağaza kesintisi | %30 | Play / App Store |

| | **A. Saf F2P hybrid** | **B. F2P + 6,99 $ tam sürüm kilidi** | **C. Baştan ücretli 4,99 $** |
|---|---|---|---|
| Reklam geliri / kurulum | 0,075 $ | 0,073 $ (ödemeyen %97'den) | 0 $ |
| IAP dönüşümü | %2,6 × 6 $ ARPPU | **%3 × 6,99 $** + %20'si ek paket | %100 × 4,99 $ |
| IAP net / kurulum | 0,109 $ | **0,164 $** | 3,49 $ |
| **Net / kurulum** | **0,184 $** | **0,237 $** | **3,49 $** |
| 100.000 organik kurulumda | 18.400 $ | **23.700 $** | — kurulum sayısı çöker |
| Gerçekçi organik kurulum | yüksek | **yüksek** | **~%3–8'i** (kapıda ödeme duvarı) |
| 100.000 B-eşdeğeri trafikte | 18.400 $ | **23.700 $** | ~5.000 satış × 3,49 = 17.450 $ |

## 15.4 Karar: **Model B** — ve asıl gerekçe rakam değil

Kurulum başına B, A'yı %29 geçiyor. Ama **asıl gerekçe içerik maliyeti:**

| | Model A'nın sattığı şey | Model B'nin sattığı şey |
|---|---|---|
| Ne | Skin, tema, kozmetik — **oynanış değeri sıfır olan, sürekli üretilmesi gereken sanat** | Harita ve içerik — **zaten yapacağın şey** |
| Tek kişilik ekipte | Sürekli kozmetik üretim hattı kurmayı gerektirir | Yol haritasındaki içeriği paketlemek yeter |
| Kaç SKU'yu iyi yapmak gerekir | 6–8 | **1** |

**Tek kişilik bir ekipte tek bir mükemmel SKU, yedi vasat SKU'yu döver.**

Model C'yi (baştan ücretli) reddetme gerekçesi ise ahlaki değil, dağıtımsal: **UA bütçesi
yokken ücretsiz katman pazarlamanın kendisidir.** C bir keşif bahsidir — basın, streamer,
Reddit ilgisi gerektirir. B bu bahse girmez; B'de ücretsiz oyun kendi trafiğini üretir ve
seven oyuncuda C'nin ekonomisine dönüşür.

**[BUILT] Ve elimizde bu huninin ilk basamağı zaten var:** çalışan bir Web export ve
GitHub Pages deploy hattı (`.github/workflows/deploy.yml`). **Oynanabilir web demosu**,
bütçesiz bir geliştiricinin sahip olabileceği en iyi organik kanal:

```
   Web demosu (ücretsiz, kurulumsuz)  →  mobil kurulum  →  tam sürüm kilidi
```

## 15.5 Ölçek — V1'in hiç sormadığı soru

Gelir = **kurulum × kurulum başına gelir.** Para kazanma tasarımı sadece ikinci çarpanı
belirler. Organik-only'de bağlayıcı kısıt **birincisi**.

| Organik kurulum | Tahmini net ömür geliri (Model B) |
|---|---|
| 10.000 | ~2.400 $ |
| 50.000 | ~11.900 $ |
| 100.000 | ~23.700 $ |
| 250.000 | ~59.300 $ |

**Dürüst çerçeve:** bu, 50 bin kurulumda anlamlı bir yan gelir, 250 bin+'da gerçek bir
gelirdir. Ve tam da bu yüzden **kapsam küçük kalmalı** — 250 bin kurulumu garanti edemeyen
bir projeye iki yıllık geliştirme yüklemek matematiksel olarak yanlıştır.

Organik kurulumu belirleyen şeyler, önem sırasıyla: **mağaza sayfası kalitesi ve ASO** ·
**web demosu** · **streamer / YouTube ilgisi** · **r/towerdefense ve Element TD nostaljisi
taşıyan topluluklar** · **retention** (mağaza algoritmaları elde tutmayı ödüllendirir).

## 15.6 Farklılaşma — "neden bunu indireyim?"

Mağazada binlerce TD var. Bu sorunun tek cümlelik bir cevabı yoksa, para kazanma
tasarımının hiçbir önemi yok. Üç aday:

| Kanca | Güç | Sorun |
|---|---|---|
| "Element TD'den ilham alan" | WC3 nostaljisi gerçek bir kitle | Dar; ve oyun kasten Element TD *gibi değil* |
| "Sadece dört kule, ama sekiz farklı son" | Sadeliği satıyor | Sadelik heyecan vermez, güven verir |
| **"Hangi kuleyi koyduğundan çok, NEREYE koyduğun önemli"** | **Cross-element yerleşim sinerjisi türde gerçekten yeni** | Anlatması bir ekran görüntüsü gerektirir — ama gösterilebilir |

**[PROPOSAL] Üçüncüsüyle git.** Cross-element bulmacası (Bölüm 6.2) bu tasarımın tek
gerçekten özgün mekaniği ve mağaza videosunda gösterilebilir: iki kule yan yana geldiğinde
aralarında beliren bağ. Diğer ikisi alt başlık olur.

---

# 16. Rewarded reklam — ödül boyutu hesaplanarak

## 16.1 İki yerleşim, başka yok

| # | Yerleşim | Ödül | Sınır |
|---|---|---|---|
| 1 | **Run sonrası sonuç ekranı** | **+%50 Essence** | Günde 2 |
| 2 | **Second Chance** (Bölüm 17) | 5 can ile devam | Run başına 1 |

Reddedilen yerleşimler: **run öncesi "+50 altınla başla"** (Bölüm 8'in ekonomi tasarımını
bozar ve pay-to-win'in ilk basamağıdır) · **dalga arası "bu dalgayı atla"** · **kart
ekranında "4. kartı gör"** (kartın kıtlığı tasarımın kendisi).

## 16.2 Neden +%50 — "kulağa hoş geliyor" değil, hesap

Bağlayıcı kısıt: **Workshop'ın tamamlanma süresi.** Workshop 1.105 Essence tutuyor
(Bölüm 14.2) ve ortalama ~50 Essence/run ile **~22 run**'da bitiyor.

| Ödül | Günde 2 run oynayan biri için Workshop | Hüküm |
|---|---|---|
| +%25 | ~18 run | Opt-in için çok zayıf — düşük izlenme, düşük gelir |
| **+%50** | **~15 run** | **Hissedilir hızlanma, ama reklam zorunlu hissettirmez** |
| +%100 | ~11 run | Reklam izlemeyen oyuncu geride kalmış hisseder |

**+%50, günde 2 tavanla.** Tavan *run başına* değil *gün başına* olmalı: run başına olsaydı
çok oynayan oyuncu için reklam bir vergi hâline gelirdi.

## 16.3 Dürüst açıklama: rewarded reklam savaş gücüne DOLAYLI dokunuyor

```
rewarded reklam → daha hızlı Essence → daha hızlı Workshop → +%20'ye kadar savaş gücü
```

V1 bu bağlantıyı görmezden gelirdi. V2 yazıyor ve iki yerden kesiyor:

1. **Workshop tavanlı ve zaten bitiyor.** Reklam sonucu değil, hızı değiştiriyor: 22 run
   yerine 15 run. Reklam izlemeyen oyuncu birkaç run sonra aynı yere varıyor.
2. **Leaderboard ve haftalık challenge Workshop'ı sıfırlıyor** (Bölüm 14.3). Rekabetin
   olduğu her yerde bu bağlantı **tamamen kopuk**.

## 16.4 Beklenen gelir

`1,5 izlenme/DAU × 10 $ eCPM ÷ 1000 = **0,015 $ ARPDAU**`

Küçük görünüyor ve küçük. Ama ödemeyen %97'den gelen tek gelir bu, ve
**[MARKET]** IAP'yi yamyamlaştırmıyor — yani tamamen ek.

---

# 17. Second Chance — analiz, otomatik onay veya ret değil

## 17.1 Lehte

- **Yüksek opt-in.** Oyuncu tam olarak en motive olduğu anda soruluyor: 17. dalgada,
  emek verdiği bir run bitmek üzereyken.
- **Oturumu kurtarır.** Dalga 18'de biten bir run, oturumu da bitirebilir. Devam etme
  seçeneği o oturumu ayakta tutar.
- **Reklamın en dürüst hâli:** oyuncu ne aldığını tam olarak biliyor ve karşılığını
  kendisi istiyor.

## 17.2 Aleyhte — ve kullanıcının listelemediği asıl risk

V1'in retry döngüsü argümanı değil. Asıl risk **gerilim**:

> Güvenlik ağı olduğunu **bilen** oyuncu, 15–19. dalgaları farklı oynar.
> Riskli yerleşimi dener, kritik yükseltmeyi erteler, sızıntıyı göze alır.

Yani Second Chance sadece kaybı değil, **kaybetmeden önceki oyunu** da değiştirir. Bu,
oyunun en gergin bölümünü sulandırma riskidir.

## 17.3 [PROPOSAL] Karar: evet, ama sıkı kısıtlarla

| Kısıt | Değer | Neden |
|---|---|---|
| Run başına | **1 kez** | İkincisi run'ı şakaya çevirir |
| En erken | **Dalga 12'den sonra** | 6. dalgada teklif etmek reklam duvarıdır, kurtarma değil |
| Geri verilen can | **5** (tam değil) | Devam ettirir ama sıfırlamaz; hâlâ kaybedebilirsin |
| Yıldız | **★ alınabilir, ★★ ve ★★★ alınamaz** | Mükemmel run satın alınamaz |
| Haftalık / leaderboard | **Tamamen kapalı** | Rekabet normalize |
| **Duyurulma** | **İlk kez tetiklenene kadar varlığından hiç bahsedilmez** | Gerilim riskinin (17.2) tek gerçek panzehiri: bilmediğin ağa güvenemezsin |

Son satır kritik ve V2'nin özgün katkısı: **oyuncu Second Chance'in var olduğunu ancak ilk
kez karşılaştığında öğrenir.** İlk 12+ run'da gerilim tamamen korunur; ondan sonra oyuncu
zaten oyunu biliyor ve seçim onun.

**Gelir katkısı küçük** (~0,004 $ ARPDAU). **Bu bir gelir mekaniği değil, bir retention
mekaniği** ve öyle değerlendirilmeli. Soft launch'ta açık/kapalı A/B testi (Bölüm 27).

---

# 18. Interstitial reklam — modellenip reddedildi

## 18.1 Hesap

Kullanıcının önerdiği test adayı: "uygun kullanıcılar için 2–3 tamamlanan run'da bir, run
sonrası bir interstitial".

| | Değer |
|---|---|
| Oturum başına run | ~1,5 |
| Sıklık | 3 run'da 1 |
| **Gösterim / DAU** | **~0,5** |
| Interstitial eCPM **[MARKET]** | ~14 $ |
| **ARPDAU katkısı** | **~0,007 $** |
| Karşılaştırma: rewarded | **0,015 $** — iki katından fazla |

**Interstitial bir gelir kararı değil.** DAU başına yarım sentin altında getiriyor ve
karşılığında 10 dakikalık kesintisiz akışın sonuna zorunlu bir reklam koyuyor.

## 18.2 Tek gerçek argüman — ve neden yine de hayır

Interstitial'ın savunulabilir tek gerekçesi gelir değil: **Ad Removal satın almasına talep
yaratması.** Yani rahatsızlığı üretip sonra rahatsızlığın çözümünü satmak.

Bunu açıkça yazıyorum çünkü sessizce karar vermek doğru olmaz: **bu meşru bir ticari
strateji ve aynı zamanda biraz sinik bir strateji.**

**[PROPOSAL] Karar: lansmanda interstitial yok.** Üç gerekçe:

1. Getirisi ölçülebilir şekilde küçük.
2. Model B'de Ad Removal zaten **Tam Sürüm Kilidi'nin içinde** ve kilidin asıl değeri
   *içerik*. Yani talep üretmek için rahatsızlığa ihtiyaç yok — satılan şey gerçek.
3. Retention, organik-only bir üründe **gelirden daha değerli**, çünkü mağaza algoritmaları
   elde tutmayı ödüllendiriyor ve tek trafik kaynağımız o.

**Soft launch'ta A/B testi olarak açık kalsın** (Bölüm 27): eğer Tam Sürüm dönüşümü %1,5'in
altında kalırsa, "3 run'da 1 interstitial" kohortu test edilir ve **hem gelir hem D7
birlikte** okunur. Sadece gelire bakan bir test yanlış cevabı verir.

---

# 19. Ad Removal

## 19.1 Ayrı bir SKU değil — kilidin içinde

**[PROPOSAL]** Ayrı bir "Reklamları Kaldır" ürünü **yok**. Reklamsızlık, **Tam Sürüm
Kilidi'nin (6,99 $) bir özelliği**.

Neden ayrıştırmıyoruz: iki ayrı SKU (2,99 $ reklamsız + 4,99 $ içerik) birbirini yer ve
oyuncuyu "hangisini alsam?" ikilemine sokar. Tek çapa SKU, tek karar.

## 19.2 Kilidi alan oyuncu rewarded'a ne yapacak

Kullanıcının sorduğu dört seçenek:

| | Seçenek | Hüküm |
|---|---|---|
| A | Rewarded gönüllü kalır, izleyebilir | ⚠️ Ödeyene "hâlâ reklam izleyebilirsin" demek zayıf bir teşekkür |
| **B** | **Ödülü reklam izlemeden alabilir** | ✅ **Seçilen** |
| C | Alternatif bir bonus verilir | ⚠️ İkinci bir sistem, karmaşıklık |
| D | Rewarded tamamen kapanır | ❌ Ödeyeni Essence bonusundan mahrum bırakır — cezalandırma |

**Seçim B.** Kilidi olan oyuncu sonuç ekranında aynı butonu görür, basar, reklam
oynatılmaz, ödül gelir. Mesaj net: **"Bir daha hiç reklam izlemeyeceksin."**

Maliyet: ödeyen %3'ten gelen reklam gelirini kaybediyoruz. Hesap: bir oyuncunun ömür boyu
rewarded geliri ~0,075 $; 6,99 $'lık satın alma bunun **~90 katı**. Tartışmasız değer.

---

# 20. IAP ürünleri

## 20.1 Ücretsiz katman ne içerir — ve neden cömert olmak zorunda

Model B'nin tek gerçek riski: içeriği duvarın arkasına koymak, ücretsiz oyunun
retention'ını ve kulaktan kulağa yayılımını düşürür — **ki organik-only'de tek dağıtım
kanalımız o.**

> **[PROPOSAL] Kilit, "oyunun geri kalanı" değil, "daha fazlası" olmalı.
> Ücretsiz sürüm eksik hissettiriyorsa model çöker.**

| | Ücretsiz | Tam Sürüm Kilidi (6,99 $) |
|---|---|---|
| Kuleler | **Dördü de** | — |
| Branch'ler | **Sekizi de** | — |
| Kart havuzu | **Tamamı** | — |
| İlerleme (yıldız, XP, ustalık, Essence, Workshop) | **Tamamı** | — |
| Harita | **Harita 1, üç ruleset (9 yıldız)** | +Harita 2 ve 3 (18 yıldız daha) |
| Modlar | **Standard + Endless** | +Quick, +Challenge (haftalık) |
| Reklam | Gönüllü rewarded | **Hiç reklam yok** (ödül izlemeden alınır) |

Ücretsiz oyuncu **tam bir oyun** oynuyor: dört kule, sekiz branch, 22 kart, 20 dalga,
zafer ekranı, üç zorluk, dokuz yıldız ve sonsuz mod. ~20–30 run'lık içerik. Kilit,
sevmiş oyuncuya *devamını* satıyor.

## 20.2 SKU listesi

| SKU | Ne | Fiyat | Tür | Faz |
|---|---|---|---|---|
| **TAM SÜRÜM KİLİDİ** | Tüm haritalar, tüm modlar, reklamsız | **6,99 $** | içerik — **çapa** | Faz 2 |
| **Welcome Pack** | 1 skin seti + 200 Essence | 2,99 $ | kozmetik | Faz 2 |
| Skin seti (Kristal / Çarklı / Mercan …) | Dört kulenin beş seviyesi için tema | 2,99 $ | kozmetik | Faz 3 |
| Harita teması (Karyağışı / Kumullar / Kül) | Bir haritanın yeniden boyanması | 1,99 $ | kozmetik | Faz 3 |
| **Journey Pass** | Süresiz 25 kademe premium hat (Bölüm 21) | 4,99 $ | ilerleme + kozmetik | Faz 3 |
| Expedition Pack I | 3 harita + 1 yeni element + 6 kart + 1 boss | 4,99 $ | içerik | Faz 4 |
| Founder Bundle | O ana kadarki her şey + profil rozeti | 12,99 $ | paket | Faz 3 |

**Bir çapa, altı kuyruk.** Faz 2'de sadece ikisi var.

## 20.3 Welcome Pack — V1'in otomatik reddi yeniden değerlendirildi

V1 starter pack'i *"en az bilgiye sahip olunan anı hedef alır"* diye reddetti. Bu **ilk
açılışta gösterilen** paket için doğru.

**[PROPOSAL] Ama 3–5 tamamlanmış run sonra gösterilen paket, tam tersi bir durumdur:**
oyunu tanıyan, sevdiğini bilen ve karar verebilecek biriyle konuşuyorsun.

Kurallar:
- **En erken 3 tamamlanmış run sonra**, ve sadece oyuncu mağazaya girdiğinde.
- **Popup yok.** Mağaza ikonunda bir nokta belirir, o kadar.
- **Süre sınırı yok, kaybolmaz.** "3 GÜN KALDI" yok.
- **İçinde reklam kaldırma yok** — bu Tam Sürüm Kilidi'ni yer. İçeriği kozmetik + Essence.
- **Savaş avantajı yok.** 200 Essence, Workshop'ın ~%18'i; zaten 22 run'da kendi başına
  biten bir sistemi birkaç run öne alır, tavanı değiştirmez.

## 20.4 Asla satılmayacaklar

Altın · can · devam hakkı · dalga atlama · Workshop seviyesi · kart · branch · kule ·
loot box / gacha / rastgele herhangi bir şey · düşman skin'i (siluet oynanış bilgisidir) ·
UI teması (HUD herkes için aynı okunmalı) · sıralamada avantaj.

---

# 21. Journey Pass — süresiz

## 21.1 Neden bu, klasik battle pass'ten iyi

V1 battle pass'i "geri sayım baskısı" diye reddetti. **Yanlış hedefi vurdu:** sorun *pass*
değil, *süre sınırı*.

| | Klasik battle pass | Abonelik | **Süresiz Journey** |
|---|---|---|---|
| Aciliyet | Yüksek (sezon biter) | Orta (aylık) | **Yok** |
| Dönüşüm | **En yüksek** | Yüksek | **Orta** |
| Oyuncu duygusu | "Kaçırırsam kaybederim" | "Ödemeyi bıraksam kaybederim" | **"İstediğim zaman bitiririm"** |
| Çocuk kitlesine uygunluk | ❌ | ❌ | ✅ |
| Tekrarlayan gelir | ✅ sezon başına | ✅ ay başına | ✅ **Journey başına** |

**Dürüst takas:** süresiz olmak **dönüşümü düşürür.** Aciliyet satar; onu kaldırmak gelirden
feragat etmektir. Ama bu tasarımın kimliği tam olarak bu, ve tekrarlayan gelir hâlâ mümkün:
**her yeni Journey ayrı ve yine süresiz bir satın alma.**

## 21.2 Yapı

| | |
|---|---|
| Kademe | **25** |
| İlerleme | Kazanılan Essence ile (Workshop 22 run'da bitiyor — Essence'a ikinci bir kullanım gerekiyor ve bu tam yerine oturuyor) |
| Ücretsiz hat | 25 kademenin ~8'i: Essence, bir kart, bir profil ikonu |
| Premium hat | **4,99 $** — 25 kademenin tamamı: skin varyantları, mermi VFX'leri, bir harita teması, profil kozmetikleri, Essence |
| Süre | **Süresiz.** Bugün de bitirebilir, altı ay sonra da |
| Sonraki Journey | Ayrı ürün, yine süresiz. Eskisi kaybolmaz |
| **Savaş gücü** | **Yok.** Journey'de tek bir stat bile yok |

**Faz 3.** Faz 2'de tek çapa SKU'ya odaklan; Journey ancak elde tutma kanıtlandıktan sonra
anlamlı.

---

# 22. Premium para birimi

**[PROPOSAL] Hayır.** V1 ile aynı sonuç, daha iyi bir gerekçeyle.

V1'in gerekçesi ahlakiydi ("fiyatı gizlemek için var"). Doğru ama eksik. Asıl soru şu:
**premium kur BU oyunda hangi problemi çözerdi?**

| Premium kurun gerçek işlevi | Bu oyunda geçerli mi |
|---|---|
| Çok sayıda SKU'yu paketlemek ve promosyon yapmak | ❌ Toplam **7 SKU** var, ve Faz 2'de sadece 2 |
| Bölgesel fiyat esnekliği | ❌ Play ve App Store bunu **zaten kendisi yapıyor** |
| Küsuratlı bakiye bırakıp sonraki satın almayı ön-taahhüde bağlamak | ❌ Zaten istemediğimiz şey |
| Kazanılabilir ödül olarak dağıtmak | ❌ **Essence bu işi zaten yapıyor** |

Premium kur, **50+ SKU'lu ve haftalık promosyonlu** bir ekonomide hak ettiği yeri bulur.
Bizde asla o ölçek olmayacak.

**Maç içinde iki şey vardır: ALTIN ve CAN. Maç dışında bir şey vardır: ESSENCE.**
XP ve ustalık **sayaçtır, para birimi değil** — biriktirilir ve kilit açar, harcanmaz,
dönüştürülmez, bakiye olarak gösterilmez. Toplam para birimi sayısı: **iki**.

---

# 23. Ne satılır, ne satılmaz

## 23.1 Çerçeve

| Kategori | Bu oyunda | Örnek |
|---|---|---|
| **PAY TO EXPRESS** (ifade) | ✅ Evet | Skin setleri, harita temaları, profil kozmetikleri, Journey |
| **PAY TO EXPAND** (genişlet) | ✅ **Evet — ana gelir** | Tam Sürüm Kilidi, Expedition Pack |
| **PAY TO PROGRESS FASTER** (hızlandır) | ⚠️ **Sadece dolaylı ve tavanlı** | Welcome Pack'in 200 Essence'ı; rewarded reklamın +%50'si |
| **PAY TO WIN** | ❌ **Asla** | — |

## 23.2 Kullanıcının §14 ↔ §23 çelişkisinin çözümü

Brief §14 Workshop'ı ~+%10 hasarla sınırlıyor ve 20–30 run'da bitiriyor.
Brief §23 ilerleme hızlandırmasının satılabilirliğini soruyor.

**Bu ikisi bir arada duramaz:**

> Workshop toplam +%20 güç veriyorsa ve 22 run'da kendi başına bitiyorsa, "hızlandırma"
> SKU'sunun sattığı şey **birkaç run'lık zaman**dır. Bunun parasal değeri bir doların
> altındadır. **Satılabilir bir ürün değildir.**

Yani seçenek şu: **ya Workshop satılabilecek kadar büyüktür** (ve o zaman oyun pay-to-win
olur), **ya küçüktür ve hızlandırma bir ürün değildir.**

**[PROPOSAL] Karar: küçük Workshop, ve savaş gücü hızlandırması hiçbir zaman ayrı bir SKU
olarak satılmaz.** Var olan tek dolaylı hızlandırmalar — Welcome Pack'in Essence'ı ve
rewarded reklamın +%50'si — üç koşulla sınırlı:

1. Tavanı değiştirmezler, sadece varış zamanını.
2. Tavan zaten küçük (+%20) ve herkes 22 run'da oraya varır.
3. **Rekabetçi her modda sıfırlanır** (Bölüm 14.3).

Bu üçü bir arada, "dolaylı savaş gücü satışı"nı ölçülebilir şekilde önemsiz kılar. Ve
hepsi belgede yazılı — gizlenmiş bir ilişki yok.

---

# 24. Retention — daha az dogmatik

## 24.1 "Bir run daha" — dört bileşen (V1'den korunuyor)

| Bileşen | Nasıl sağlanıyor |
|---|---|
| **1. Kayıp okunabilir ve benimdi** | Dalga önceden ikonla haber verilir; hasar sayıları matchup'a göre büyür/küçülür; sonuç ekranı tek cümleyle sebebi söyler: *"Dalga 14 — Mender'lar Fire'ının içinden iyileşti"* |
| **2. Tekrar denemek ucuz** | Sonuç ekranında **tek buton: TEKRAR**. Aynı harita, aynı ruleset, yeni kart çekilişi. Yükleme yok, menü yok, mağaza yok |
| **3. Sonraki run farklı olacak** | Kart çekilişi + pişman olunan branch kararları |
| **4. Run risk alınacak kadar kısa** | ~10,5 dk |

## 24.2 V1'in dogmasından geri adım: günlük bonus

V1 tüm alışkanlık sistemlerini yasakladı. **Aşırı geniş.** Cezalandırmayan bir günlük bonus,
streak değildir.

**[PROPOSAL] "Günün ilk galibiyeti": tamamlanan ilk Standard run için +%50 Essence.**

| Kural | Değer |
|---|---|
| Artan seri ödülü | **Yok** — 7. gün 1. günle aynı |
| Kaçırma cezası | **Yok** — hiçbir şey sıfırlanmaz, hiçbir şey kaybolmaz |
| Geri sayım / hatırlatma bildirimi | **Yok** |
| Gösterim | Sonuç ekranında bir satır. Menüde sayaç yok |

Fark şu: *"bugün oynarsam küçük bir bonus var"* ile *"bugün oynamazsam serimi kaybederim"*
arasındaki fark. Birincisi alışkanlık kurar, ikincisi suçluluk kurar.

## 24.3 Haftalık challenge — ve neden günlük challenge yok

**Haftalık:** sabit seed + zorunlu modifier, herkes için aynı, Workshop normalize
(Bölüm 14.3). Kaçırmanın cezası yok. **Faz 3.**

**Günlük seeded challenge: hayır.** Haftalık bir challenge *olay*tır; günlük olan *ödev*tir.
Ve bir günlük challenge'ı kaçırmak, kaçınılmaz olarak kaçırma hissi üretir — cezalandırmasa
bile. Bir ürün 24 saatte bir yeni içerik üretemez; haftada bir üretebilir.

## 24.4 Hâlâ reddedilenler

Login streak · giriş takvimi · enerji/can sistemi · süreli battle pass · "ekininiz soldu"
tipi kayıp bildirimleri · günlük görev listesi · seri kırılma bildirimi.

---

# 25. Kitle stratejisi — bu bir iş kararı

## 25.1 İki meşru strateji

### Strateji A — Çocuk kapsayıcı / Families ürünü

Google Play "Families" programına girmek veya Apple "Kids" kategorisinde yer almak.

**[POLICY]** Kısıtlar:

| Platform | Kural | Kaynak |
|---|---|---|
| Google Play Families | **Yalnızca sertifikalı reklam SDK'sı** kullanılabilir; **kişiselleştirilmiş reklam, ilgi alanı bazlı reklam ve remarketing kapalı** olmalı | [Play Console](https://support.google.com/googleplay/android-developer/answer/9893335), [Families Self-Certified Ads SDK](https://support.google.com/googleplay/android-developer/answer/9900633) |
| Google Play Families | Çocuklardan veya **yaşı bilinmeyen** kullanıcılardan AAID, IMEI, IMSI, MAC, SSID vb. **iletilemez** | [Play Console](https://support.google.com/googleplay/android-developer/answer/9893335) |
| Google Play (karma kitle) | Karma kitleli uygulamada **nötr yaş ekranı** zorunlu, çocuklar yalnızca kişiselleştirilmemiş reklam görebilir | [Play Console](https://support.google.com/googleplay/android-developer/answer/9893335) |
| Apple Kids Category | **Üçüncü taraf reklam veya analitik içermemeli.** Sınırlı istisna: IDFA ve kimliklendirici toplamayan analitik; ve yayınlanmış politikası olan, reklamları **insan tarafından incelenen** platformlardan **bağlamsal** reklam | [App Review Guidelines 1.3](https://developer.apple.com/app-store/review/guidelines/) |

**Ticari sonucu:** kişiselleştirilmemiş reklamın eCPM'i kişiselleştirilmişin belirgin
altındadır ve iOS tarafında üçüncü taraf reklam pratikte kapanır. Analitik kısıtı ayrıca
**atıf ve A/B testini** ciddi biçimde zorlaştırır — yani Bölüm 26 ve 27 büyük ölçüde
uygulanamaz hâle gelir.

### Strateji B — Genel kitle, görsel olarak çocuk-erişilebilir

Kids kategorisinde veya Families programında **yer almamak**; oyunu genel kitleye
derecelendirmek (şiddet, metin, sohbet, kullanıcı içeriği yok — doğal olarak düşük
derecelendirme alır), ama **çocuk-hedefli ürün olarak beyan etmemek**.

## 25.2 Karşılaştırma

| | Strateji A (Families / Kids) | **Strateji B (genel kitle)** |
|---|---|---|
| Reklam geliri | Belirgin düşük (kişiselleştirilmemiş; iOS'ta pratikte yok) | **Tam esneklik** |
| Analitik | Çok kısıtlı | **Tam** — atıf, kohort, A/B |
| Uyum yükü | Yüksek ve sürekli | Orta (nötr yaş ekranı + kişiselleştirilmemiş reklam altyapısı) |
| Mağaza konumlandırma | "Aileler için" rafında görünürlük | Strateji/TD kategorisinde, gerçek rakiplerinin yanında |
| UA | Kısıtlı hedefleme | Serbest (ama zaten bütçe yok) |
| Para kazanma esnekliği | Düşük | **Yüksek** |

## 25.3 [PROPOSAL] Öneri: **Strateji B — dürüstçe beyan edilerek**

Üç bileşeni var ve üçü birlikte olmazsa savunulabilir değil:

1. **Ürün genel kitleye beyan edilir.** Yaş derecelendirmesi anketleri dürüstçe doldurulur.
   Oyunun içeriği zaten düşük derecelendirme alır — bu bir manipülasyon değil, gerçeğin
   sonucu. **Çocuk-hedefli olmayan bir ürünü çocuk-hedefli olarak beyan etmemek kadar,
   tersini yapmak da yanlıştır.**
2. **Nötr yaş ekranı uygulanır.** **[POLICY]** Oyun görsel olarak çocuklara hitap ettiği
   için karma kitle kabul edilir; ilk açılışta **yönlendirmeyen** bir doğum yılı/yaş sorusu
   sorulur ve 13 yaş altı beyan eden kullanıcıya **kişiselleştirilmemiş reklam** servis
   edilir, kimliklendirici toplanmaz.
3. **Tasarım zaten uyumlu.** Bölüm 20.4'teki "asla satılmayacaklar" listesi (loot box yok,
   gacha yok, süre baskısı yok, enerji yok) çocuk-koruma mevzuatının hedeflediği kalıpların
   tamamını zaten dışarıda bırakıyor. **Yani uyum, monetizasyon tasarımının bir sonucu —
   ona eklenen bir katman değil.**

Bu kombinasyon hem ticari olarak en mantıklı hem hukuken en savunulabilir olan: reklam ve
analitik esnekliği korunur, ama çocuk kullanıcılar mevzuatın öngördüğü korumayı gerçekten
alır.

**Not:** Bu bir hukuki görüş değildir. Yayın öncesinde hedef pazarların
(AB — GDPR-K, ABD — COPPA, Türkiye — KVKK) güncel gereklilikleri bir hukukçuyla teyit
edilmelidir. **[POLICY]** kuralları burada yayın tarihindeki hâliyle alıntılandı ve platform
politikaları düzenli değişiyor.

---

# 26. Soft launch metrikleri

Benchmark ile hedef ayrı sütunlarda. **Benchmark bulamadığım yerde "yok" yazıyorum ve
sadece hedef veriyorum** — uydurulmuş sektör ortalaması, hiç ortalama olmamasından kötüdür.

| Metrik | `[MARKET]` benchmark | `[PROPOSAL]` hedef | Kaynak |
|---|---|---|---|
| **D1 retention** | medyan ~%26; "iyi" %35; üst çeyrek %40 | **%32** | [Playio](https://blog.playio.co/d1-d7-d30-retention-benchmarks-2026) |
| **D7 retention** | tüm türler %6–14; **midcore %20–21** | **%14** | [Playio](https://blog.playio.co/d1-d7-d30-retention-benchmarks-2026) |
| **D30 retention** | %1–7; "iyi" profil %5 | **%5** | [Playio](https://blog.playio.co/d1-d7-d30-retention-benchmarks-2026) |
| Ortalama oturum süresi | yok | **~14 dk** (1 run + menü) | — |
| Oturum başına run | yok | **1,3** (V1'in 1,8'i iyimserdi — Bölüm 11.2) | — |
| **İlk run bitişinden 60 sn içinde ikinci run** | yok | **%45** — *çekirdeğin eğlenceli olup olmadığını ölçen tek metrik* | — |
| Standard tamamlama oranı (Normal, ilk 5 run) | yok | **%15–35** | — |
| **Rewarded opt-in** | %40–70 | **%55** | [Playio](https://blog.playio.co/rewarded-ad-benchmarks-2026) |
| **Rewarded izlenme / DAU** | referans vaka 2,1 | **1,5** | [Playio](https://blog.playio.co/rewarded-ad-benchmarks-2026) |
| Interstitial gösterim / DAU | — | **0** (Bölüm 18) | — |
| **Reklam ARPDAU** | hybrid-casual harmanlanmış 0,15–0,50 $ (bizden yüksek tür) | **0,015 $** | [GGA](https://gamegrowthadvisor.com/blog/2026-04-16-hybrid-casual-game-design-strategy-2026/) |
| **IAP dönüşümü (kuruluma göre, 30 gün)** | **%2,6** | **%3,0** (tek çapa SKU, dağınık portföyden yüksek olmalı) | [MAF](https://maf.ad/en/blog/mobile-game-conversion-rates/) |
| Ödeyen oranı (DAU) | %2–5 | **%3** | [MAF](https://maf.ad/en/blog/mobile-game-conversion-rates/) |
| **ARPPU** | yok (tek SKU'lu modeller için) | **7,40 $** | — |
| **ARPDAU (toplam)** | yok | **0,048 $** | — |
| Tam Sürüm Kilidi dönüşümü | yok | **%3,0** | — |
| Welcome Pack dönüşümü | yok | **%1,5** | — |
| Journey dönüşümü | yok | **%1,0** (Faz 3) | — |
| İçerik paketi dönüşümü | yok | kilit alanların **%20'si** | — |
| **Gelir dağılımı** | hybrid'de reklam ~%56, IAP ~%35, abonelik ~%7 | **IAP %69 / rewarded %31 / interstitial %0** | [AppsFlyer via GGA](https://gamegrowthadvisor.com/blog/2026-04-02-f2p-monetization-models-comparison-2026/) |

**Dağılım neden piyasadan farklı:** piyasa ortalaması UA ile beslenen, yüksek hacimli
oyunlardan geliyor. Organik-only'de hacim düşük, dolayısıyla **kurulum başına gelir** ön
plana çıkıyor ve tek çapa SKU ağırlığı alıyor. Bu bir sapma değil, modelin kendisi.

**Karar metriği tek:** *ilk run bitişinden 60 saniye içinde ikinci run başlatma oranı.*
%45'in altındaysa **hiçbir monetizasyon ayarı kurtarmaz** — çekirdek eğlenceli değildir ve
Faz 2'ye geçilmez.

---

# 27. A/B test planı

## 27.1 Önce bir gerçeklik: trafiğimiz yok

UA bütçesi olmadan soft launch DAU'su muhtemelen **birkaç yüz**. Bir retention testinin
kol başına ~1.000 kullanıcıya ihtiyacı var. Yani:

> **Aynı anda tek test. Sadece büyük beklenen etkili testler. Küçük etkili testler
> (örneğin +%25 vs +%50 rewarded ödülü) bu trafikte asla anlamlı çıkmaz.**

Bu, kullanıcının brief'indeki test listesini yeniden sıralamayı gerektiriyor.

## 27.2 Sıralı test planı

| # | Test | Kollar | Okunan metrik | Beklenen etki | Faz |
|---|---|---|---|---|---|
| 1 | **Second Chance** | açık / kapalı | D7, oturum başına run, tamamlama | **Büyük** | Faz 2 |
| 2 | **Tam Sürüm Kilidi fiyatı** | 4,99 $ / 6,99 $ | dönüşüm × fiyat = kurulum başına gelir | **Büyük** | Faz 2 |
| 3 | **Kilit sınırı** | Harita 1 ücretsiz / Harita 1+2 ücretsiz | D7 **ve** dönüşüm birlikte | **Büyük** | Faz 2 |
| 4 | **Mağazanın görünme anı** | 2. run sonrası / 4. run sonrası | dönüşüm, D7 | Orta | Faz 2 |
| 5 | **Kart cadence** | 3/7/11/15 / 4/8/12/16 | tamamlama oranı, ikinci-run oranı | Orta | Faz 2 |
| 6 | **Matchup çarpanı** | ×1,5 / ×1,6 / ×1,75 | tamamlama oranı, element çeşitliliği | Orta | Faz 2 |
| 7 | **Faiz oranı** | %3 / %5 | ortalama banka, kule sayısı, tamamlama | Orta | Faz 3 |
| 8 | **Welcome Pack içeriği** | sadece kozmetik / kozmetik + Essence | dönüşüm, sonraki satın alma | Küçük | Faz 3 |
| 9 | **Interstitial** | yok / 3 run'da 1 | **gelir VE D7 birlikte** | Küçük | Faz 3, sadece #2 başarısızsa |
| 10 | **Rewarded ödülü** | +%25 / +%50 | opt-in, Workshop hızı | **Çok küçük — muhtemelen ölçülemez** | erteledi |

**Kural:** hiçbir test bir kohortu kasten mutsuz etmez. Test #9'un "interstitial" kolu bile
run'ın *içine* değil, sonuna reklam koyar.

**Optimize edilen hedef:** `RETENTION × ENGAGEMENT × GELİR`, tek başına gelir değil. Test
#3 ve #9 tek metrikle okunursa yanlış cevabı verir — ikisinde de gelir ve D7 birlikte
değerlendirilir.

---

# 28. Ürün fazları

## Faz 1 — ÇEKİRDEK PROTOTİP

**Ölçtüğü soru:** *"Bir run bittiğinde oyuncu hemen bir tane daha oynamak istiyor mu?"*

| | İçerik |
|---|---|
| Kuleler | 4, hepsi ilk dalgadan itibaren açık |
| Seviye / branch | 5 seviye, Lv3'te branch → **8 uç durum** |
| Düşman | **6 arketip** (Splitter yok) |
| Boss | **1 boss, 2 kez** (W10 Muhafız, W20 Uyanmış Muhafız) |
| Dalga | **20**, el yazımı |
| Harita | **1**, 2 ruleset (Easy, Normal) |
| Kart | **22**, W3/7/11/15 |
| Mod | **Standard**, zafer ekranıyla |
| İlerleme | **Sadece yıldız** (6) |
| Para kazanma | **Hiç** — reklam yok, IAP yok, Essence yok, Workshop yok |
| Tutorial | 90 sn, 5 adım |
| Analitik | Sadece yerel: ikinci-run oranı, tamamlama, ölüm dalgası |

**Neden monetizasyon yok:** eğlenceli olup olmadığını ölçerken satıp satmadığını ölçemezsin.
Ve eğlenceli olmayan bir çekirdeğin üstüne serilen ilerleme sistemi, sorunu **gizler**.

## Faz 2 — TİCARİ SOFT LAUNCH

**Ölçtüğü soru:** *"Hem elde tutabiliyor hem para kazanabiliyor muyuz?"*

Eklenenler: Essence + tavanlı Workshop · hesap seviyesi · **harita 2** ve **3. ruleset** ·
Endless modu · Splitter · **rewarded reklam (2 yerleşim)** · **Tam Sürüm Kilidi (6,99 $)** ·
**Welcome Pack** · küçük mağaza (tek giriş, 3. run sonrası) · nötr yaş ekranı ·
tam analitik · bulut kayıt.

**Geçiş koşulu:** Faz 1'de ikinci-run oranı ≥ %45.

## Faz 3 — VERSİYON 1.0

Yalnızca soft launch verisi izin verirse. Adaylar: harita 3 · Quick ve Challenge modları ·
element ustalığı · haftalık challenge · Journey Pass · skin setleri ve harita temaları ·
kart havuzu 22 → 42 · 2 boss daha.

**Hepsinin çıkacağı varsayılmaz. Kapsamı veri belirler.**

## Faz 4 — GENİŞLEMELER

Öncelik sırasıyla, her biri bir öncekinin kendini finanse etmesine bağlı:
**Expedition Pack** (3 harita + 5. element — chain veya pierce) · **düşman fraksiyonu**
(ortak kurallı 3 arketip) · **Lv5'te ikinci branch** (16 uç durum, palet büyümeden) ·
**Light ve Darkness'ın dönüşü** (**[BUILT]** sanatı hazır bekliyor).

---

# 29. Ekonomi — kesin sayılar ve simülasyon

## 29.1 Maç içi

| Kalem | Değer | Not |
|---|---|---|
| Başlangıç altını | **120** (Easy 150 / Hard 100) | 2 kule + üstü |
| Başlangıç canı | **20** (Easy 25 / Hard 15) | |
| Kule inşa | **50** | Her element aynı fiyat — maliyet asla element seçme sebebi olmamalı |
| Lv2 | **40** | İnşadan ucuz: önce yükseltmeyi öğret |
| Lv3 (branch) | **70** | |
| Lv4 | **120** | |
| Lv5 (ultimate) | **200** | Tam kule toplamı: **480** |
| Öldürme başına altın | **`3 + dalga`** | W1 = 4, W20 = 23. Doğrusal ve tahmin edilebilir |
| Dalga başına düşman | **`8 + dalga`**, tavan 28 | W1 = 9, W20 = 28 |
| Dalga sonu faizi | **bankanın %5'i**, tavan **+60** | Tavan 1.200 altında bağlanır |
| Sızıntısız bonus | **+8** | |
| Erken çağır bonusu | **`(3 + dalga) + 2 × hayattaki`**, tavan **2 × (3 + dalga)** | Bölüm 8.3 |
| Satış iadesi | **%100** ateş etmeden / **%80** sonra | Bölüm 9 |
| Boss ödülü | **×12** | |
| Boss sızarsa | **−5 can** | |

## 29.2 Simülasyon — 20 dalga, Normal ruleset

| Dalga | Adet | Ödül | Dalga geliri | Kümülatif kullanılabilir* |
|---|---|---|---|---|
| başlangıç | — | — | — | **120** |
| 1 | 9 | 4 | 36 | 170 |
| 3 | 11 | 6 | 66 | 320 |
| 5 | 13 | 8 | 104 | **530** |
| 7 | 15 | 10 | 150 | 850 |
| 10 | boss + 7 | 13 | **247** | **1.533** |
| 13 | 21 | 16 | 336 | 2.320 |
| 15 | 23 | 18 | 414 | **3.343** |
| 17 | 25 | 20 | 500 | 4.400 |
| 20 | boss + 11 | 23 | **529** | **~6.090** |

\* öldürme geliri + başlangıç + sızıntısız bonuslar + orta düzey faiz (~250)

### Kontrol 1 — Lv5 kuleye gerçekten ulaşılabiliyor mu?

Bir kuleyi Lv5'e çıkarmak **480 altın**. Odaklanan bir oyuncu:
- W5 civarında ilk Lv3 (160 harcanmış)
- **W12–14 civarında ilk Lv5**
- Run sonunda 3–5 adet Lv5

✅ **Evet, ama pahalı.** İlk ultimate'i görmek run'ın yarısını alıyor, yani gerçek bir hedef.

### Kontrol 2 — Bir run kaç kule taşır?

| Strateji | Maliyet | Kule sayısı |
|---|---|---|
| Az ve maksimum | 480 / kule | **12 adet Lv5 = 5.760** — mükemmel oyunla ancak yetişir |
| Dengeli | 280 / kule (Lv4) | **~15 adet Lv4 = 4.200**, 1.890 artar |
| Geniş ve ucuz | 160 / kule (Lv3) | **~20 adet Lv3 = 3.200** — ama tahtada ~12 iyi nokta var |

**Bağlayıcı kısıt tahtanın kendisi olmalı, altın değil** — ve öyle: ~12 iyi nokta × 480 =
5.760, toplam bütçe ~6.090. Yani **oyun geç dönemde "nereye koyayım" sorusuna dönüşüyor,
"param yetmiyor" sorusuna değil.** Hedeflenen his bu.

### Kontrol 3 — Biriktirmek harcamayı yenebilir mi?

Hayır. 50 altını 10 dalga bankada tutmak `50 × (1,05¹⁰ − 1) = 31` altın getirir — bir kule
almaya bile yetmez. Faiz **eşiğe doğru biriktirmeyi** (3 dalga sonra 200'lük ultimate)
ödüllendirir, süresiz istifi değil. ✅

### Kontrol 4 — Faiz bileşikleniyor mu?

Hiç harcamayan bir oyuncu 20 dalgada ~870 faiz kazanır ama **9. dalgadan sonra tavan
bağlar** (banka 1.200'ü geçtiği an) ve **5. dalgada zaten ölmüştür.** Gerçekçi bir
biriktirici ~400–500 kazanır: toplam gelirin **%8'i.** ✅

### Kontrol 5 — Erken çağır sömürülebilir mi?

Teorik maksimum: `2 × Σ(3 + n)` = **540 altın** = gelirin %8,9'u — ve bunun için her dalgayı
düşmanlar hâlâ yoldayken çağırman gerekir. Run 20 dalga sabit olduğu için erken çağırmak
**ekstra dalga kazandırmaz**, yani sonsuz farm yok. ✅

### Kontrol 6 — Rewarded reklam ekonomiyi bozuyor mu?

**Hayır, çünkü rewarded Essence verir, altın değil.** Maç içi ekonomiyle **hiç
kesişmiyor**. Essence'ın gidebileceği tek savaş-gücü yeri Workshop, o da +%20'de tavanlı ve
zaten 22 run'da kendiliğinden bitiyor. ✅

**Bu ayrım tasarımın en önemli güvenlik duvarı:** para maç içi ekonomiye hiçbir yerden
giremiyor.

## 29.3 Maç dışı

| Kalem | Formül / değer |
|---|---|
| **Essence** | `(dalga + dalga²/20) × 1,5^(tamamlandı) × (1 + 0,2 × yıldız)` |
| — dalga 8'de kayıp | **11** |
| — dalga 12'de kayıp | **19** |
| — dalga 20 tamam, ★ | **72** |
| — dalga 20 tamam, ★★★ | **96** |
| **Hesap XP** | `ulaşılan_dalga × 8` (+100 tamamlarsa). Seviye *n* = `60 × n` XP. 20 seviye ≈ 48 run |
| **Ustalık XP** | O elementle verilen hasar. Element başına 5 kademe |
| **Rewarded ödülü** | Run sonrası **+%50 Essence**, günde 2 |
| **Günün ilk galibiyeti** | Tamamlanan ilk run'a **+%50 Essence**, seri yok, ceza yok |

### Workshop maliyetleri

| Kalem | Seviye başına | Maks | Toplam etki | Essence |
|---|---|---|---|---|
| Forge | +%2 hasar | 5 | +%10,4 | 25/38/56/84/127 = **330** |
| Tempo | +%2 atış hızı | 4 | +%8,2 | 30/45/68/101 = **244** |
| Lens | +4 menzil | 5 | +20 px | 20/30/45/68/101 = **264** |
| Treasury | +10 başlangıç altını | 4 | +40 altın | 20/30/45/68 = **163** |
| Ramparts | +1 can | 2 | +2 can | 40/64 = **104** |
| | | | **~+%20 güç** | **1.105 toplam** |

**Doğrulama:** ortalama ~50 Essence/run → **22 run**. Rewarded + günlük bonus kullanan
oyuncuda **~15 run**. İkisi de "20–30 run'da bitsin" hedefinin içinde. ✅

## 29.4 Okunabilirlik kontrolü

Oyuncunun bir maçta gördüğü en büyük sayılar:

| | En büyük değer |
|---|---|
| Kule hasarı | **100** (Fire Lv5) |
| Kule maliyeti | **200** (Lv5 yükseltme) |
| Öldürme başına altın | **23** |
| Banka | ~1.200 |
| Düşman canı | ~1.500 (dalga 20 normal), boss ~12.000 |

Boss canı dört haneli — tek istisna, ve boss'un canı **bar olarak** gösterilir, sayı olarak
değil. Geri kalan her şey üç hanenin altında.
Karşılaştırma: **[EXTRACTED]** Element TD'de Pure Darkness **206.241** hasar, Pure tier
**24.444** altın, dalga 60 canı **476.522**.

---

# 30. GERÇEKTEN YAYINLAYACAĞIM OYUN

Burada alternatif yok. Seçim yapılmış hâli.

## Çekirdek savaş

Tek ekran, tek yol, kaydırma yok. Palette **dört ikon**. Kule sürükleyip bırakırsın, dokunup
yükseltirsin, köşesindeki ✕ ile satarsın. Hedefleme sabit ("çıkışa en yakın"), ayar yok.
20 dalga, ~10,5 dakika, **kazanılabilir bir final.**

## Kuleler

🔥 **FIRE** *"Yakar ve eritir"* — sürekli hasar, üst üste binen burn, en kısa menzil.
💧 **WATER** *"Yavaşlatır ve durdurur"* — her vuruşta Chill, diğer kulelere atış zamanı satar.
🪨 **EARTH** *"Ağır vurur, çok vurur"* — splash ve zırh kırma, **göğe ateş edemez.**
🌿 **NATURE** *"Zehirler ve destekler"* — zırhı yok sayan zehir, komşu kuleleri güçlendiren aura.

5 seviye: **50 / 40 / 70 / 120 / 200** altın. Hasar **10 → 100**. Seviye sadece hasarı
değiştirir; menzil ve atış hızı asla.

## Branch'ler — her element bir eksende ikiye ayrılır

| Element | Eksen | A | B |
|---|---|---|---|
| 🔥 Fire | **dikey / yatay** | **Blaze** — burn üst üste biner → Cinderheart | **Wildfire** — burn komşulara bulaşır → Firestorm |
| 💧 Water | **zaman / mesafe** | **Glacier** — alan chill → Absolute Zero (freeze) | **Undertow** — yolda geri iter → Riptide |
| 🪨 Earth | **kalabalık / tek hedef** | **Quake** — geniş splash + sendeleme → Fissure | **Siege** — zırh çatlatır → Sunder |
| 🌿 Nature | **yıpratma / destek** | **Blight** — zehir bitmez → Plague | **Grove** — aura + altın → Heartwood |

Her branch **en az bir problemin tek ya da en iyi cevabı** (Bölüm 4.4 matrisi). Matematiksel
olarak üstün branch yok.

## Kartlar

**W3 / W7 / W11 / W15**'te 3 karttan 1. Havuz **22** (→ 42). Reroll yok.
Dört tür: mekanik %36 · **cross-element %27** · ekonomi %18 · run kimliği %18.

**Cross-element kartlar oyunun ana kancası:** STEAM, EROSION, MAGMA, EMBERSEED, BLOOM,
BEDROOT. Element kombinasyonu bir **tarif** değil, bir **yerleşim bulmacası** — hangi kuleyi
diktiğinden çok, onu neyin yanına diktiğin.

## Dalgalar

20 el yazımı dalga. **Her yeni fikir kendi dalgasında yalnız gelir.** Dalga 15'ten sonra
hiçbir yeni şey tanıtılmaz. Can eğrisi **[EXTRACTED]** `75 × 1,16^(n-1)`.
Dalgaların **%55'i zırhlı** — öğretim, boss ve arketip tanıtım dalgaları zırhsız.
Her dalga **ikonla** önceden duyurulur: arketip silueti + zırh halkası rengi + rakam. Metin yok.

## Düşmanlar

**Runner** (W1) · **Sprinter** (W3) · **Swarm** (W5) · **Brute** (W7, zırhlı + kontrole
bağışık) · **Flyer** (W9) · **Mender** (W12). Splitter Faz 2'de.
Her biri: bir problem, bir siluet, tooltip'siz.

## Boss'lar

**Kural taşırlar, can barı değil.**
**W10 MUHAFIZ** — *kontrole tamamen bağışık*: yavaşlamaz, donmaz, itilmez, sendelemez.
Sorusu: "Kontrolün arkasına saklandın, gerçek hasarın var mı?"
**W20 UYANMIŞ MUHAFIZ** — *zırhı 5 saniyede bir döner*.
Sorusu: "Tek elemente mi yatırdın, dördüne mi?"
Can ×8, hız ×0,7, ödül ×12, sızarsa −5 can.

## Ekonomi

**Üçgen:** harca (güvenlik) ↔ biriktir (dalga sonu %5 faiz, tavan +60) ↔ erken çağır
(düşmanlar yoldayken çağır, bonus hayattaki düşman sayısıyla büyür).
Üçü aynı altını ister, hiçbiri her zaman doğru değil.
Satış: **ateş etmeden %100, sonra %80.**
Toplam run bütçesi ~6.090 altın, tahtadaki ~12 iyi nokta × 480 = 5.760.
**Geç dönemde soru "nereye koyayım" olur, "param yetmiyor" değil.**

## Haritalar

**Tek giriş, tek çıkış, en fazla bir geri katılan dal. İki bağımsız şerit hiçbir zorlukta
yok.** (V1'in çelişkisi burada kapanıyor.)
Harita × ruleset: Easy / Normal / Hard. Hard **yolu kısaltır** (daha az atış süresi), bir
inşa bloğunu kapatır ve **boyamada görünen** tek bir modifier ekler.
Faz 1: 1 harita × 2 ruleset. v1.0: 3 × 3 = 9 seviye, 27 yıldız.
★ bitir · ★★ ≤5 can kaybet · ★★★ hiç kaybetme.

## İlerleme

**Yıldızlar** (başarı) · **hesap seviyesi** (keşif — her seviye havuza bir kart) ·
**element ustalığı** (ustalık — genişliği ödüllendirir) · **haftalık challenge** (rekabet).
**Essence:** kaybedilen run bile mükemmelin ~%20'sini öder.
**Workshop:** toplam **+%20** güç, **22 run'da biter**, sonrası tamamen yatay.
**Leaderboard ve haftalıkta Workshop zorla 0** — "NORMALİZE" rozetiyle.
Offline Essence **silinir**.

## Retention

**Kayıp okunabilir ve benim** (sonuç ekranı sebebi tek cümleyle söyler) · **tekrar tek tuş**
· **sonraki run farklı** (kart çekilişi) · **run risk alınacak kadar kısa**.
**Günün ilk galibiyeti** +%50 Essence — seri yok, ceza yok, geri sayım yok, bildirim yok.
Login streak yok, günlük görev yok, enerji yok, süreli pass yok.

## Para kazanma — kesin liste

| Soru | Cevap |
|---|---|
| **Hangi reklamlar var?** | **Sadece rewarded.** İki yerleşim: run sonrası **+%50 Essence** (günde 2) ve **Second Chance** (run başına 1). |
| **Reklamlar nerede çıkar?** | **Sadece sonuç ekranında.** Dalga içinde, kart ekranında, boss'ta, menüde, açılışta **asla**. |
| **Interstitial var mı?** | **Hayır.** DAU başına <1 sent getiriyor ve 10 dakikalık akışın bedeli buna değmiyor (Bölüm 18). Faz 3'te A/B testi olarak açık bırakılıyor, ama **sadece Tam Sürüm dönüşümü %1,5'in altında kalırsa.** |
| **Hangi IAP'ler var?** | **TAM SÜRÜM KİLİDİ 6,99 $** (çapa) · Welcome Pack 2,99 $ · skin setleri 2,99 $ · harita temaları 1,99 $ · Journey Pass 4,99 $ · Expedition Pack 4,99 $ · Founder Bundle 12,99 $ |
| **Ad Removal var mı?** | **Ayrı SKU değil** — Tam Sürüm Kilidi'nin bir özelliği. Kilidi olan oyuncu **ödülü reklam izlemeden alır.** |
| **Journey var mı?** | **Evet, Faz 3'te. Süresi asla dolmaz.** Her yeni Journey ayrı ve yine süresiz bir ürün. İçinde tek bir stat yok. |
| **Welcome Pack var mı?** | **Evet — ama en erken 3 tamamlanmış run sonra**, popup'sız, süre sınırsız, içinde reklam kaldırma yok. |
| **İlerleme hızlandırma satılıyor mu?** | **Ayrı SKU olarak hayır.** Var olan iki dolaylı hızlandırma (Welcome Pack'in Essence'ı, rewarded'ın +%50'si) tavanı değiştirmez, sadece varış zamanını — ve **rekabetçi her modda sıfırlanır**. |
| **Premium para birimi var mı?** | **Hayır.** 7 SKU'lu bir ekonomide hiçbir problemi çözmez; mağazalar bölgesel fiyatlamayı zaten yapıyor. **Maçta ALTIN + CAN, maç dışında ESSENCE. Toplam iki.** |
| **Asla ne satılmaz?** | Altın · can · devam hakkı · dalga atlama · Workshop seviyesi · kart · branch · kule · loot box / gacha / rastgele hiçbir şey · düşman skin'i · UI teması · sıralamada avantaj. |

## Kitle stratejisi

**Strateji B — genel kitle, görsel olarak çocuk-erişilebilir, Kids kategorisinde değil.**

Üç bileşen birlikte olmazsa savunulabilir değil: **(1)** yaş derecelendirmesi dürüstçe
doldurulur; **(2)** **[POLICY]** karma kitle için **nötr yaş ekranı** konur, 13 altına
kişiselleştirilmemiş reklam servis edilir ve kimliklendirici toplanmaz; **(3)** tasarım
zaten uyumludur — loot box, gacha, enerji ve süre baskısı hiç yok.
**Uyum, monetizasyon tasarımının sonucu; üstüne eklenen bir katman değil.**
Yayın öncesi hedef pazarlar için hukuki teyit gerekir.

## Prototip MVP (Faz 1)

4 kule · 8 branch ucu · 6 düşman · **20 dalga** · 1 boss (2 kez) · **1 harita × 2 ruleset** ·
22 kart · **sadece Standard, zafer ekranıyla** · **sadece yıldızlar (6)** ·
**para kazanma yok, Essence yok, Workshop yok** · 90 saniyelik tutorial.

**Tek soru:** ilk run bittikten sonraki 60 saniye içinde ikinci run başlatma oranı **≥%45** mi?

## Ticari soft launch (Faz 2)

Essence + tavanlı Workshop · hesap seviyesi · harita 2 · 3. ruleset · Endless · Splitter ·
**rewarded reklam** · **Tam Sürüm Kilidi 6,99 $** · Welcome Pack · tek girişli mağaza
(3. run sonrası) · nötr yaş ekranı · tam analitik · bulut kayıt.

**Soru:** hem elde tutabiliyor hem para kazanabiliyor muyuz?

## V1.0 (Faz 3) — hangi içerik yapılma hakkını kazanır

Yalnızca soft launch verisi izin verirse: harita 3 · Quick ve Challenge · element ustalığı ·
haftalık challenge · Journey Pass · skin ve tema setleri · kart havuzu 42'ye · 2 boss daha.
**Hepsinin çıkacağı varsayılmaz. Kapsamı veri belirler.**

---

# 31. Akış diyagramı

```
                          OYUNCU OYUNU AÇAR
                                  |
                          HARİTA + ZORLUK SEÇ
                                  |
 =================================v=========================================
 |                      OYNANIŞ DÖNGÜSÜ  (~10,5 dk)                        |
 |                                                                         |
 |   RUN BAŞLAR — 120 altın | 20 can | 4 ikon                              |
 |        |                                                                |
 |        v                                                                |
 |   +--> DALGA HABERCİSİ  (arketip ikonu + zırh halkası + rakam)          |
 |   |        |             metin yok                                      |
 |   |        v                                                            |
 |   |   İNŞA ET / YÜKSELT / BRANCH SEÇ / YER DEĞİŞTİR                     |
 |   |        |                                                            |
 |   |        v                                                            |
 |   |   DALGA AKAR — sızıntı can götürür, öldürme altın getirir           |
 |   |        |                                                            |
 |   |        v                                                            |
 |   |   +------------- EKONOMİ ÜÇGENİ --------------+                     |
 |   |   |  HARCA <-> BİRİKTİR (%5) <-> ERKEN ÇAĞIR  |  <-- tekrarlayan    |
 |   |   +-------------------------------------------+      ikilem         |
 |   |        |                                                            |
 |   |        v   W3 - W7 - W11 - W15                                      |
 |   |   3 KARTTAN 1 SEÇ --> run'ın şekli değişir                          |
 |   |        |                                                            |
 |   +--------+   dalga 1-19                                               |
 |            v   W10 MUHAFIZ (kontrole bağışık)                           |
 |                W20 UYANMIŞ MUHAFIZ (zırhı 5 sn'de bir döner)            |
 |      RUN BİTER --> ZAFER (dalga 20)   ya da   YENİLGİ (0 can)           |
 ==================================+========================================
                                   |
        +--------------------------+---------------------------+
        v                          v                           v
+----------------+   +------------------------+   +------------------------+
|  SONUÇ EKRANI  |   |   İLERLEME DÖNGÜSÜ     |   |   RETENTION DÖNGÜSÜ    |
|                |   |                        |   |                        |
| "Dalga 14 —    |   |  yıldız  --> harita    |   |  farklı kart çekilişi  |
|  Mender'lar    |   |  Essence --> Workshop  |   |  + kıl payı kaçan      |
|  Fire'ının     |   |           (22 run'da   |   |    yıldız              |
|  içinden       |   |            biter)      |   |  + pişman olunan       |
|  iyileşti"     |   |  XP      --> KART      |   |    branch kararı       |
|                |   |  ustalık --> skin      |   |                        |
| [TEKRAR][SONRA]|   +-----------+------------+   |  "bir tane daha"       |
+-------+--------+               |                +-----------+------------+
        |          açılan kartlar HAVUZA geri besler          |
        |                        |                            |
        |      +-----------------v-------------------+        |
        |      |     PARA KAZANMA DÖNGÜSÜ            |        |
        |      |  (yukarıdaki iki döngüye HİÇBİR     |        |
        |      |   OK göndermez)                     |        |
        |      |                                     |        |
        |      |  rewarded --> +%50 Essence          |        |
        |      |   (günde 2, gönüllü, savaş dışı)    |        |
        |      |                                     |        |
        |      |  oyunu sev --> haritalar bitti      |        |
        |      |            --> TAM SÜRÜM 6,99 $     |        |
        |      |            --> daha çok seviye,     |        |
        |      |                AYNI kurallar        |        |
        |      +-----------------+-------------------+        |
        |                        |                            |
        +------------------------+----------------------------+
                                 v
                            YENİ RUN
```

**Diyagramı, olmayan oka göre okuyun.** Para kazanma döngüsünden oynanış döngüsüne
**hiçbir ok gitmiyor.** Para **daha fazla oyun** alır, **daha iyi sayı** almaz.

Rewarded'ın tek oku İlerleme döngüsüne değiyor — o da tavanlı (+%20), 22 run'da kendiliğinden
biten ve **rekabetçi her modda sıfırlanan** bir sistem. Bu, "dolaylı savaş gücü satışı"nın
ölçülebilir şekilde önemsiz olduğu anlamına geliyor, ve gizlenmiyor: Bölüm 16.3'te yazılı.

**Para kazanma döngüsü diğer üçünü destekler; yerlerine geçmez.**

---

# V1 → V2 değişiklik tablosu

| Sistem | V1 | **V2** | Neden değişti |
|---|---|---|---|
| **Kart zamanlaması** | 5 / 10 / 15 / 20 | **3 / 7 / 11 / 15** | W20 kartının etkileyeceği dalga yok — V1'in hatası, dört yerde tekrarlanmış |
| **Kart havuzu** | 20 kart, %20'si düz stat | **22 kart, 6'sı cross-element** | Cross-element yerleşim bulmacası ana kanca hâline getirildi |
| **Matchup çarpanı** | ×2,0 / ×0,8 | **×1,6 / ×0,85** | ×2,0'da optimal strateji "rengi oku, karşıtını dik" olur; yerleşim ve branch ezilir |
| **Zırhlı dalga oranı** | belirtilmemiş (pratikte %100) | **%55** | Çarpandan güçlü kaldıraç. Matchup baharat olmalı, ana yemek değil |
| **Matchup geri bildirimi** | "×2 rozeti" | **Sayı yok — büyük altın rakam + ok** | V1 dengeyi arayüz için seçmişti; V2 ikisini ayırıyor |
| **Fire branch B** | Mortar (splash) | **Wildfire (burn yayılır)** | Splash Earth'ün kimliği; iki element aynı soruya aynı cevabı veremez |
| **Water branch B** | Torrent (zincirleme) | **Undertow (geri itme)** | Zincirleme 5. elementin kimlik adayı — branch'e harcanmamalı |
| **Fire burn / Nature poison** | ikisi de genel DoT | **Fire dikey (biner), Nature yatay (yayılır, zırhı yok sayar)** | V1'de aynı mekaniğin iki adıydı |
| **Boss 1 kuralı** | "yavaşlatılamaz" | **kontrole tamamen bağışık** | Tek ikon, tek kural; yeni kontrol türleri otomatik kapsanır |
| **Boss 2 kuralı** | Swarm doğurur | **zırhı 5 sn'de bir döner** | Doğurmak aynı problemden daha fazlası; dönen zırh *farklı* ve doğru soruyu sorar |
| **Boss sızıntı bedeli** | 10 can | **5 can** | 20 canın yarısı tek hata için fazla |
| **Standard süre** | 12–14 dk | **~10,5 dk** | 1,8 run/oturum × 13 dk = 25 dk; V1 bu çarpımı hiç yapmadı |
| **Satış iadesi** | sabit %80 | **ateş etmeden %100, sonra %80** | Acemiyi korur, uzmanın bedava taşımasını engeller |
| **Faiz** | dalga sonu %5 | **aynı + HUD'da görünür projeksiyon** | Görünmeyen mekanik karar üretmez |
| **Erken çağır** | (3+dalga), risksiz | **düşmanlar yoldayken çağrılabilir, bonus riskle büyür** | V1'de maliyeti sıfırdı; karar değil tıklama vergisiydi |
| **Hard ruleset** | ikinci giriş (dalga 12+) | **kısaltılmış yol + kapalı blok + modifier** | V1 kendi "iki bağımsız şerit olmaz" kuralını çiğniyordu |
| **Workshop tavanı** | +%26 güç | **+%20 güç, 22 run'da biter** | Daha da küçültüldü |
| **Leaderboard** | hiç ele alınmamış | **Workshop zorla 0, "NORMALİZE" rozeti** | V1 kalıcı gücün rekabette ne yaptığını hiç sormadı |
| **Rewarded reklam** | ❌ yasak | **✅ iki yerleşim, +%50 Essence, günde 2** | Mobilin en değerli ve en sevilen yüzeyi, veriye bakılmadan yasaklanmıştı |
| **Second Chance** | ele alınmamış | **✅ kısıtlı: 1/run, dalga 12+, 5 can, ★★ alamaz, önceden duyurulmaz** | Gerilim riski gerçek; duyurulmama kuralı panzehir |
| **Interstitial** | ❌ "akışı böler" | **❌ — ama rakamla: <1 sent/DAU** | Sonuç aynı, gerekçe ölçülebilir |
| **Ad Removal** | ❌ (reklam yoktu) | **Tam Sürüm Kilidi'nin içinde; ödeyen ödülü izlemeden alır** | Ayrı SKU iki ürünü birbirine yedirir |
| **Welcome Pack** | ❌ yasak | **✅ 3 run sonra, popup'sız, süresiz, reklamsızlık içermez** | "En az bilgi anı" itirazı ilk açılış için doğru, 3. run için yanlış |
| **Journey Pass** | ❌ (battle pass yasak) | **✅ süresiz, Faz 3** | Sorun pass değil, süre sınırıydı |
| **Ana gelir modeli** | kozmetik + içerik paketleri | **F2P çekirdek + tek seferlik 6,99 $ Tam Sürüm Kilidi** | Organik-only'de dağınık kozmetik portföyü ölçek ister; tek çapa SKU istemez |
| **Günlük bonus** | ❌ tüm alışkanlık sistemleri yasak | **✅ "günün ilk galibiyeti", seri ve ceza yok** | V1 aşırı genişti; streak ile cezasız bonus aynı şey değil |
| **Kitle** | "çocuk ürünü" varsayımı | **Genel kitle + nötr yaş ekranı** | **[POLICY]** Families/Kids kısıtları reklam ve analitiği ciddi biçimde kapatıyor |
| **Ölçek / UA** | hiç ele alınmamış | **Bölüm 15.5** | "Ticari olarak sürdürülebilir", kurulum sayısı konuşulmadan tanımsız |
| **Farklılaşma** | hiç ele alınmamış | **Bölüm 15.6** | "Neden bunu indireyim?" cevaplanmadan monetizasyonun önemi yok |
| **Faz ayrımı** | MVP / v1.0 | **Prototip / Soft launch / v1.0 / Genişleme** | V1 "eğlenceli mi?" ile "satıyor mu?" sorularını tek kelimede topluyordu |
| **Offline Essence** | sil | **sil** | Aynı fikirdeyiz |
| **Element isimleri** | Fire/Water/Earth/Nature | **aynı** | Kullanıcı sabitledi |

---

# BUILD NEXT

Onaydan sonra yapılacak ilk **10 geliştirme görevi**, sırayla. **Hiçbiri henüz yapılmadı.**
Sıralamanın mantığı: **önce silme, sonra sayı, sonra yapı, en son ölçme.**

| # | Görev | Dokunulan dosyalar | Boyut |
|---|---|---|---|
| **1** | **Referans anlık görüntüsü al.** `--wipe-save` sonrası `--dump-stats`, `--dump-board` ve `--dump-waves` çıktılarını kaydet. Bundan sonraki her sayı değişikliği bu taban çizgisine göre okunur — `CLAUDE.md` bunun neden zorunlu olduğunu yazıyor. | — (sadece çıktı) | XS |
| **2** | **Dört elemente in.** `TOWER_ORDER` → 4; `ELEMENT_BEATS` → dörtlü halka (`earth` hedefi `light` → `water`); `DUAL_RECIPES` ve `DUAL_ELEMENT_LEVEL` kaldır; 15 dual + `lightning` defs'ini çıkar; `light`/`darkness` defs ve sanatını **referanssız bırak**. | `game.gd` | S |
| **3** | **Sayı merdivenini yeniden yaz.** `TIER_COSTS` → `[50,40,70,120,200]`; hasar tier'ları 10/18/32/56/100 ölçeğine; `ELEMENT_STRONG/WEAK` → 1,6 / 0,85; `SELL_REFUND` iki kademeli; `PREP_TIME` 3,0; `FIRST_PREP_TIME` 10,0; `BASE_COUNT_*` → `8+n`; bounty → `3+n`; `INTEREST_RATE` 0,05 ve `INTEREST_CAP` 60; `BOSS_*`; `CHOICE_EVERY` yerine açık dalga listesi. | `balance.gd`, `game.gd` | M |
| **4** | **Run'ı sonlandır.** 20 dalgada biten Standard mod, **zafer ekranı**, sonuç ekranında tek birincil buton **TEKRAR**, ve ölüm sebebini tek cümleyle söyleyen satır. `wave_generator.gd` yalnızca Endless'a bağlanır. | `wave_manager.gd`, `main.gd`, `end_screen.gd` | M |
| **5** | **Branch sistemi.** Lv3'te iki kartlık seçim popup'ı, `Tower` üzerinde `branch` alanı, branch'e özel stat/menzil/aralık override'ları, kayıt-yükleme. **Tek gerçek yeni özellik.** | `tower.gd`, yeni `branch_choice.gd`, `main.gd` | **L** |
| **6** | **Sekiz branch davranışı.** Blaze/Wildfire · Glacier/Undertow · Quake/Siege · Blight/Grove ve ultimate'ler. Undertow'un **düşman başına 2 sn cooldown**'u ve boss bağışıklığı atlanmamalı — bu olmadan run kilitlenir. | `tower_behavior.gd` alt sınıfları, `projectile.gd`, `enemy.gd` | **L** |
| **7** | **Boss kuralları.** `control_immune` bayrağı (yavaşlatma/dondurma/itme/sendeleme hepsini kapsar) ve `rotating_armor` (5 sn'de bir `armor_element` döner, yerdeki halka rengi değişir). Can barının üstünde kural ikonu. | `enemy.gd`, `wave_manager.gd`, `game.gd` | M |
| **8** | **Ruleset'ler ve yıldızlar.** Easy/Normal profilleri (can %, adet %, altın, can, yol varyantı, kapalı blok). `Game.configure_board()` zaten parametrik — ikinci profil olarak eklenir. Yıldız değerlendirmesi ve kaydı. | `game.gd`, `save_service.gd`, `menu.gd` | M |
| **9** | **Kart havuzunu değiştir.** 22 kart; element kartları ve `unlock_lightning` çıkar; **altı cross-element kartı** eklenir (bitişiklik için mevcut aura mantığı, örtüşme için `projectile.gd` `_apply()` içindeki durum kontrolü). Cadence W3/7/11/15. | `game.gd` `UPGRADE_POOL`, `run.gd` | M |
| **10** | **Tutorial'ı 5 adıma indir ve GERÇEK BİR RUN'I ÖLÇ.** `LESSONS` 6 → 4 element, düz metin yerine gösterim, adım başına ≤5 kelime. Sonra `--shot:N` ile zamanlanmış tam bir run: **20 dalga gerçekten ~10,5 dakika sürüyor mu?** Bölüm 11.2'nin tahmini ölçülmemiş — ve V1'in hatası tam olarak ölçmeden iddia etmekti. | `tutorial.gd`, ölçüm koşusu | M |

**11 numara yok, çünkü 10'dan sonra ölçüm konuşacak.** Faz 2'nin (Essence, Workshop, reklam,
mağaza) yapılıp yapılmayacağına **ikinci-run oranı** karar verir: %45'in altındaysa para
kazanma değil, çekirdek düzeltilir.

---

*Belge sonu. **[EXTRACTED]** etiketli her sayı `tools/extract_w3x.py` ile yeniden
üretilebilir · **[BUILT]** etiketli her iddia `godottowerdefense/scripts/` içinde okunabilir ·
**[MARKET]** ve **[POLICY]** etiketli her iddianın yanında kaynak linki var ·
**[PROPOSAL]** etiketli her şey öneridir ve tartışılmak içindir.*
