# BMU Firmware Extractor ve Analiz Aracı

Bu araç, Antminer E9 Pro ve benzeri cihazlar için BMU (Bitminer Firmware Update) dosyalarını analiz etmek ve içeriğini çıkarmak amacıyla geliştirilmiştir.

## Özellikler

- BMU firmware dosyalarını analiz etme
- Binary formatındaki firmware dosyalarını çözümleme
- Dosya sistemi imzalarını (SquashFS, JFFS2, vb.) tespit etme
- Sıkıştırılmış kısımları açma (GZip, BZip2, XZ)
- Metin içeriklerini (string) çıkarma
- Versiyon bilgilerini arama

## Gereksinimler

- Python 3.6 veya daha yeni bir sürüm
- Linux için ek araçlar (isteğe bağlı):
  - `unsquashfs` - SquashFS dosya sistemlerini açmak için
  - `jefferson` - JFFS2 dosya sistemlerini açmak için
  - `binwalk` - Daha detaylı firmware analizi için

## Kurulum

1. Scripti bilgisayarınıza indirin:
   ```bash
   git clone https://github.com/yourusername/bmu-extractor.git
   cd bmu-extractor
   ```

2. İsteğe bağlı ek araçları kurma:
   ```bash
   # SquashFS araçları
   sudo apt-get install squashfs-tools
   
   # Jefferson (JFFS2 için)
   pip install jefferson
   
   # Binwalk
   pip install binwalk
   ```

## Kullanım

### 1. BMU Dosyasını Analiz Etme ve Çıkarma

```bash
python bmu_extractor.py "g:\GithubProj\e9pro\Antminer-E9-Pro-ETHW&ETHF-release-202403221450 (2).bmu" -o "g:\GithubProj\e9pro\extracted"
```

### 2. Firmware Dosyasını Analiz Etme

```bash
python bmu_extractor.py --firmware "G:\GithubProj\e9pro\extracted\firmware.bin" -o "G:\GithubProj\e9pro\extracted\firmware_contents"
```

### Hızlı Başlangıç: Firmware.bin Dosyasını Extract Etme

Eğer halihazırda `firmware.bin` dosyasını çıkardıysanız ve içeriğini incelemek istiyorsanız:

```bash
# Windows için:
python bmu_extractor.py --firmware "G:\GithubProj\e9pro\extracted\firmware.bin" -o "G:\GithubProj\e9pro\extracted\firmware_contents"

# Linux için:
python3 bmu_extractor.py --firmware "/path/to/firmware.bin" -o "/path/to/output_directory"
```

Bu komut:
1. Firmware dosyasını tarar
2. Bilinen dosya sistemi imzalarını (SquashFS, JFFS2, GZip vb.) arar
3. GZip, BZip2, XZ vb. sıkıştırılmış bölümleri açar
4. Bulunan içerikleri belirtilen çıktı dizinine kaydeder
5. Metin (string) içeriklerini çıkarır

#### İçeriği Daha Detaylı İncelemek

Çıkarılmış dosyaları daha detaylı incelemek için:

```bash
# Linux komutları:
cd G:\GithubProj\e9pro\extracted\firmware_contents
file decompressed_gzip_*
binwalk decompressed_gzip_000049e0.bin
strings decompressed_gzip_000049e0.bin | grep -i version
```

#### Binwalk ile Daha Detaylı Analiz

Firmware dosyasını daha detaylı analiz etmek için binwalk kullanabilirsiniz:

```bash
# Binwalk ile dosyanın içeriğini göster
binwalk "G:\GithubProj\e9pro\extracted\firmware.bin"

# Binwalk ile dosyayı otomatik olarak extract et
binwalk -e "G:\GithubProj\e9pro\extracted\firmware.bin"
```

## Çıktılar

### BMU Dosyası Analizi

- `firmware.bin`: Çıkarılan ana firmware dosyası
- `extracted.tar`: Sıkıştırılmış TAR arşivi (bulunursa)
- `extracted_raw`: Raw zlib sıkıştırması açılmış veri (bulunursa)

### Firmware Dosyası Analizi

- `squashfs_at_XXXXXXXX.bin`: Tespit edilen SquashFS bölümleri
- `jffs2_at_XXXXXXXX.bin`: Tespit edilen JFFS2 bölümleri
- `compressed_at_XXXXXXXX.bin`: Tespit edilen sıkıştırılmış bölümler
- `decompressed_gzip_XXXXXXXX.bin`: GZip sıkıştırması açılmış bölümler
- `strings.txt`: Firmware içinden çıkarılan metin içerikler

## Örnekler

### 1. BMU Dosyasını Analiz Etme

```bash
python bmu_extractor.py "firmware.bmu" -o "çıktı_klasörü"
```

Bu komut:
1. BMU dosyasını analiz eder
2. Dosya başlığını görüntüler
3. Sıkıştırma formatını tespit etmeye çalışır
4. İçeriği çıkarır ve `firmware.bin` dosyasını oluşturur

### 2. Çıkarılan Firmware'i Analiz Etme

```bash
python bmu_extractor.py --firmware "çıktı_klasörü/firmware.bin" -o "firmware_içerik"
```

Bu komut:
1. Firmware binary'sini analiz eder
2. Dosya sistemi imzalarını arar (SquashFS, JFFS2, vb.)
3. Bulunan bölümleri çıkarır
4. Metin içeriklerini ve versiyon bilgilerini toplar

### 3. E9-Pro Firmware Analiz Örneği

Aşağıda gerçek bir Antminer E9-Pro firmware analiz örneği gösterilmiştir:

```
python3 bmu_extractor.py --firmware "G:\GithubProj\e9pro\extracted\firmware.bin" -o "G:\GithubProj\e9pro\extracted\firmware_contents"
Firmware Dosya Boyutu: 11136304 bytes

Firmware Başlığı (ilk 128 byte):
00000000  26 01 45 39 2d 50 72 6f 00 00 01 02 00 32 30 32   |&.E9-Pro.....202|
00000010  34 30 33 32 32 00 01 c3 2d 2d 2d 2d 2d 42 45 47   |40322...-----BEG|
00000020  49 4e 20 50 55 42 4c 49 43 20 4b 45 59 2d 2d 2d   |IN PUBLIC KEY---|
00000030  2d 2d 0a 4d 49 49 42 49 6a 41 4e 42 67 6b 71 68   |--.MIIBIjANBgkqh|
...

Tanımlanan Dosya Sistemi/Format İmzaları:
0x000049e0: GZip compressed imzası bulundu
Sıkıştırılmış veri G:\GithubProj\e9pro\extracted\firmware_contents\compressed_at_000049e0.bin dosyasına kaydedildi.
GZip sıkıştırması açıldı: G:\GithubProj\e9pro\extracted\firmware_contents\decompressed_gzip_000049e0.bin
0x00386a1c: GZip compressed imzası bulundu
Sıkıştırılmış veri G:\GithubProj\e9pro\extracted\firmware_contents\compressed_at_00386a1c.bin dosyasına kaydedildi.
GZip sıkıştırması açıldı: G:\GithubProj\e9pro\extracted\firmware_contents\decompressed_gzip_00386a1c.bin

Metin içerikleri G:\GithubProj\e9pro\extracted\firmware_contents\strings.txt dosyasına kaydedildi.
```

#### E9-Pro Firmware Yapısı

Analiz sonucunda, E9-Pro firmware dosyasının şu yapıda olduğu görülmektedir:

1. **Header Bölümü**: İlk bytes'lar model bilgisini içeriyor - "E9-Pro" ve tarih "20240322"
2. **İmza Bölümü**: Firmware'in imzasını doğrulamak için kullanılan PUBLIC KEY
3. **GZip Bölümleri**: 
   - 0x000049e0 offsetinde ilk GZip sıkıştırılmış veri
   - 0x00386a1c offsetinde ikinci GZip sıkıştırılmış veri

#### GZip İçeriğini İncelemek

Çıkarılan GZip dosyalarının içeriğini incelemek için:

```bash
# İlk GZip içeriği için
hexdump -C "G:\GithubProj\e9pro\extracted\firmware_contents\decompressed_gzip_000049e0.bin" | head -20
strings "G:\GithubProj\e9pro\extracted\firmware_contents\decompressed_gzip_000049e0.bin" | head -30

# İkinci GZip içeriği için
hexdump -C "G:\GithubProj\e9pro\extracted\firmware_contents\decompressed_gzip_00386a1c.bin" | head -20
strings "G:\GithubProj\e9pro\extracted\firmware_contents\decompressed_gzip_00386a1c.bin" | head -30
```

GZip dosyaları genellikle sistem dosyaları, yapılandırmalar veya işletim sistemi bileşenlerini içerir. Bu decompressed dosyaları daha detaylı inceleyerek miner'ın çalışma mantığını anlayabilirsiniz.

## Çıkarılmış Dosyaları İnceleme

Firmware'den çıkarılmış dosyaları analiz etmek için aşağıdaki komutu kullanabilirsiniz:

```bash
# Windows için:
python bmu_extractor.py --analyze-extracted "G:\GithubProj\e9pro\extracted\firmware_contents"

# Linux için:
python3 bmu_extractor.py --analyze-extracted "/path/to/extracted_folder"
```

Bu komut:
1. Çıkarılan GZip dosyalarını bulur ve inceler
2. Dosya türlerini tespit etmeye çalışır (ELF, Kernel, Script, vb.)
3. Önemli anahtar kelimeleri arar (config, password, miner, vb.)
4. strings.txt dosyasında IP adresleri, URL'ler, email'ler vb. bilgileri bulur

### GZip Dosyalarını Manuel İnceleme

E9 Pro firmware'inden çıkarılan iki GZip dosyası bulunmakta:

1. `decompressed_gzip_000049e0.bin` - 0x000049e0 offsetinden çıkarılmış dosya
2. `decompressed_gzip_00386a1c.bin` - 0x00386a1c offsetinden çıkarılmış dosya

#### Windows'ta Dosyaları İnceleme:

1. **7-Zip ile İnceleme**: GZip dosyalarını 7-Zip ile açarak içerikleri görebilirsiniz
2. **HxD Hex Editor**: Binary dosyaları hex editör ile açarak byte seviyesinde inceleyebilirsiniz
3. **Linux Subsystem**: Windows 10/11'de Linux alt sistemi kurarak Linux araçlarını kullanabilirsiniz

#### Linux'ta Dosyaları İnceleme:

```bash
# Dosya türünü tespit etme
file decompressed_gzip_000049e0.bin
file decompressed_gzip_00386a1c.bin

# Hexdump ile içeriği görüntüleme
hexdump -C decompressed_gzip_000049e0.bin | head -30
hexdump -C decompressed_gzip_00386a1c.bin | head -30

# Metin içeriklerini listeleme
strings decompressed_gzip_000049e0.bin | less
strings decompressed_gzip_00386a1c.bin | less

# ELF dosyalarının header bilgilerini görüntüleme
readelf -h decompressed_gzip_000049e0.bin
readelf -h decompressed_gzip_00386a1c.bin

# Kernel imajı olup olmadığını kontrol etme
strings decompressed_gzip_000049e0.bin | grep -i "linux version"
strings decompressed_gzip_00386a1c.bin | grep -i "linux version"
```

### Yaygın Dosya Tipleri ve Nasıl İncelenir

1. **Kernel imajı**: Genelde Linux çekirdeği, aşağıdaki komutlarla incelenebilir:
   ```bash
   binwalk -e decompressed_gzip_XXXXXXXX.bin
   strings decompressed_gzip_XXXXXXXX.bin | grep -i "linux version"
   ```

2. **SquashFS/JFFS2 dosya sistemleri**: Cihazın dosya sistemi, aşağıdaki komutlarla çıkarılabilir:
   ```bash
   unsquashfs -d çıktı_klasörü squashfs_dosyası.bin
   jefferson jffs2_dosyası.bin -d çıktı_klasörü
   ```

3. **ELF çalıştırılabilir dosyaları**: Miner yazılımı, çalıştırılabilir araçlar:
   ```bash
   file dosya.bin      # ELF dosyası olup olmadığını kontrol eder
   readelf -a dosya.bin    # ELF header bilgilerini gösterir
   strings dosya.bin | grep -i "version"  # Versiyon bilgisini arar
   ```

### Antminer E9 Pro İnceleme İpuçları

- **`cgminer` veya `bmminer`**: Madencilik yazılımı, genellikle firmware içinde bulunur
- **Config dosyaları**: `.conf` veya `.json` uzantılı yapılandırma dosyaları
- **Web arayüzü**: HTML/JavaScript dosyaları, web ara yüzünü oluşturur
- **init script'leri**: Başlangıç script'leri, genelde `/etc/init.d` veya `/etc/rc.d` altında

## Sorun Giderme

### 1. "Bilinen dosya sistemi imzası bulunamadı" Hatası

Bu durumda firmware özel bir formatta olabilir. Binwalk aracını kullanarak daha detaylı analiz yapabilirsiniz:

```bash
binwalk firmware.bin
binwalk -e firmware.bin
```

### 2. Python Modülü Hataları

Eğer modül bulunamadı hataları alıyorsanız, eksik modülleri yükleyin:

```bash
pip install zlib tarfile
```

## Lisans

Bu araç özgürce kullanılabilir ve değiştirilebilir.

# E9Pro Firmware İşlemleri

## Kullanım

### CPIO Arşivini Çıkarma
```bash
./extract_cpio.sh extract
```

### CPIO Arşivini Yeniden Oluşturma ve BMU Formatına Dönüştürme
```bash
./extract_cpio.sh create
```

### CPIO/BMU Dosya Bilgisi Görüntüleme
```bash
./extract_cpio.sh info
```

## Hata Ayıklama
1. Cihaza yükleme sonrası tepki alınamıyorsa:
   - `cpio_operation.log` dosyasını inceleyiniz
   - Orijinal ve yeni dosya formatlarını karşılaştırınız: `./extract_cpio.sh info`

2. U-Boot Fit Image Gereksinimleri:
   - Dosyanın Zynq7020 Linux-4.19 uyumlu olması gerekiyor
   - Public key ile imzalanmalı
   - Orijinal dosyayı fitImage formatını görmek için `dumpimage` ile inceleyebilirsiniz: 
     ```
     dumpimage -l /home/agrotest2/e9pro-extractor/extracted/_firmware.bin.extracted/minerfs.cpio
     ```

3. Olası çözümler:
   - Orijinal CPIO arşivini çıkarın ve tekrar oluşturun
   - Formatın uyumlu olduğundan emin olun (newc format)
   - `dtc` (Device Tree Compiler) ve `mkimage` araçlarını yükleyin
