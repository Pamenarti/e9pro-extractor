# Xilinx Firmware Güncelleme Aracı

Bu araç, Xilinx işletim sistemi kullanan madencilik cihazları (Antminer E9 Pro vb.) için firmware güncellemeleri hazırlamak üzere tasarlanmıştır.

## Güncelleme Süreci Adımları

Güncelleme süreci 3 ana adımdan oluşur:

1. **CPIO Arşivi Oluşturma**: Malabak klasöründeki dosyalar bir CPIO arşivine dönüştürülür
2. **BIN Dosyası Oluşturma**: CPIO arşivi, gerekli başlıklarla birleştirilerek BIN dosyasına dönüştürülür
3. **BMU Dosyası Oluşturma**: BIN dosyası private key ile imzalanarak BMU dosyası oluşturulur

## Kullanım

### 1. Orijinal Firmware Çıkarma
```bash
./extract_cpio.sh extract
```
Bu komut, orijinal firmware'i `/home/agrotest2/e9pro-extractor/malabak` klasörüne çıkarır.

### 2. Dosyaları Düzenleme
Malabak klasöründeki dosyaları ihtiyacınıza göre düzenleyin. İşiniz bittiğinde:

### 3. Yeni Firmware Oluşturma ve İmzalama
```bash
./extract_cpio.sh create
```
Bu komut:
1. Düzenlenen dosyalardan CPIO arşivi oluşturur
2. CPIO arşivini BIN formatına dönüştürür 
3. BIN dosyasını özel anahtar (private key) ile imzalayarak BMU oluşturur

Oluşturulan dosyalar:
- `minerfs_new.cpio` - CPIO arşivi
- `minerfs_new.bin` - BIN formatında firmware
- `minerfs_signed.bmu` - İmzalı BMU dosyası (cihaza yüklemeye hazır)

### 4. Anahtar Yönetimi
```bash
./extract_cpio.sh keys
```
Bu komut yeni bir anahtar çifti (private key ve public key) oluşturur.

### 5. Bilgi ve Analiz
```bash
./extract_cpio.sh info     # Dosya bilgilerini gösterir
./extract_cpio.sh analyze  # Detaylı firmware analizi yapar

## Firmware Yapısı

Xilinx tabanlı cihazlar için firmware yapısı şu şekildedir:

1. **Başlık** (16 byte): 
   - "E9-Pro" tanımlayıcısı
   - Tarih (YYYYMMDD formatında)

2. **CPIO Arşivi**:
   - Linux dosya sistemi içeriği
   - newc formatında sıkıştırılmış

3. **İmza** (BMU dosyasında):
   - "SIGN" tanımlayıcısı (4 byte)
   - İmza boyutu (8 byte hex)
   - SHA256 imza verisi

## İmzalama Formatı Değişikliği

**Önemli Güncelleme**: Firmware imzalama formatı değiştirildi.

Önceki format (HATALI):
```
SIGN + İmza Boyutu + İmza + BMU İçeriği
```

Yeni format (DOĞRU):
```
E9-Pro Başlığı + BMU İçeriği + SIGN + İmza Boyutu + İmza
```

Bu değişiklik, imzayı dosyanın sonuna taşıyarak E9-Pro başlığının dosyanın başında kalmasını sağlar. Bu, cihazın doğru şekilde firmware'i tanıması için gereklidir.

### Oluşturulan Dosyaları Doğrulama

Tüm oluşturulan dosyaları doğrulamak için:

```bash
./extract_cpio.sh verify-all
```

Bu komut, CPIO arşivini, BIN dosyasını ve imzalı BMU dosyasını inceleyerek doğru bir formatta olup olmadıklarını kontrol eder.

## Gereksinimler

- Linux işletim sistemi
- OpenSSL (imzalama için)
- cpio (arşiv oluşturmak için)
- u-boot-tools (FIT formatı için, isteğe bağlı)

## Güvenlik Notları

- Firmware imzalama için ürettiğimiz özel anahtarlar, cihaz üreticisinin anahtarlarından farklıdır
- İmzalanmış BMU dosyası, cihazın güvenlik doğrulamasından geçmeyebilir
- Bazı cihazlar geliştirici modunda imza doğrulamasını atlar

## Sorun Giderme

**Firmware imzalama başarısız olursa:**
- Private key erişim izinlerini kontrol edin: `chmod 600 private.key`
- OpenSSL kurulumunu doğrulayın: `openssl version`

**Cihaz firmware güncellemesini reddederse:**
- Cihazın geliştirici modunda olup olmadığını kontrol edin
- Firmware başlığının doğru olduğundan emin olun
- İmzalama adımını atlayıp imzasız BMU dosyasını deneyebilirsiniz

## Xilinx İşletim Sistemi Özellikleri

Antminer E9 Pro gibi cihazlarda Xilinx işletim sistemi kullanılır:
- FPGA yapılandırması için özel dosyalar içerir
- Boot süreci U-Boot üzerinden gerçekleşir
- Madencilik yazılımı genellikle cgminer veya türevleridir

## Firmware Yükleme Hata Ayıklama

Firmware yükleme işleminde hata alıyorsanız, aşağıdaki adımları izleyin:

### 1. Cihaz Seri Konsoluna Bağlanma

Seri konsoldan boot ve firmware yükleme hatalarını görmek için:

```bash
# USB-Serial dönüştürücüyü bağlayın ve port adını bulun
ls -l /dev/ttyUSB* /dev/ttyACM*

# Konsol bağlantısını başlatın
./debug-console.sh /dev/ttyUSB0
```

### 2. Basitleştirilmiş Test Firmware'i Oluşturma

Daha basit bir firmware ile test yaparak hatayı daraltın:

```bash
# İmzasız ve basitleştirilmiş test firmware'i oluştur  
./extract_cpio.sh debug
```

Bu komut 3 farklı test dosyası oluşturur:
- `debug_cpio.cpio` - Ham CPIO arşivi
- `debug_bmu.bmu` - Başlıksız ve imzasız BMU
- `debug_with_header.bmu` - Başlıklı ama imzasız BMU

### 3. Firmware Doğrulama

Oluşturulan firmware'in formatını doğrulayın:

```bash
# Firmware formatını doğrula
./verify-firmware.sh minerfs_signed.bmu
```

### 4. Yaygın Sorunlar

| Problem | Olası Neden | Çözüm |
|---------|-------------|-------|
| "Invalid signature" | İmzalama anahtarı yanlış | Cihazın geliştirici modunu aktif edin veya üreticiden özel anahtar isteyin |
| "File too large" | Firmware dosyası çok büyük | Daha az dosya içeren basitleştirilmiş firmware oluşturun |
| "Invalid header" | Başlık formatı hatalı | Orijinal firmware başlığını kopyalayarak yeni oluşturun |
| "Incompatible version" | Cihaz modeli uyumsuz | Cihaz modelinizi doğrulayın ve başlık bilgilerini güncelleyin |

### 5. Geliştirici Modunu Aktifleştirme

Bazı Antminer cihazlarında imza doğrulamasını atlamak için geliştirici modu aktifleştirilebilir:

1. Web arayüzünde oturum açın
2. Sistem > Gelişmiş ayarlar yolunu izleyin 
3. "Geliştirici Modu" seçeneğini aktifleştirin
4. Cihazı yeniden başlatın

## Python BMU Aracı

`bmu.py` analiz sonuçlarına dayanarak, BMU formatını daha doğru oluşturmak için yeni bir Python aracı ekledik:

```bash
# BMU dosyası oluşturma
python3 create_bmu.py create minerfs_new.cpio custom_bmu.bmu --private-key private.key

# BMU dosyası analiz etme
python3 create_bmu.py analyze minerfs_signed.bmu
```

### BMU Format Detayları

BMU formatı şu bileşenlerden oluşur:

1. **Başlık (16 byte)**
   - Magic Byte (0x26)
   - Miner Tipi (E9-Pro)
   - Tarih (YYYYMMDD)
   - Diğer meta veriler

2. **Public Key Bölümü**
   - PEM formatında public key

3. **CPIO Dosya Sistemi**
   - Linux dosya sistemi içeriği

4. **İmza Bölümü** (dosya sonunda)
   - "SIGN" başlığı
   - İmza boyutu (4 byte)
   - SHA256 ile oluşturulan imza

### Python İle Oluşturma Gereksinimleri

Python aracını kullanmak için:
```bash
pip install pycryptodome
```
