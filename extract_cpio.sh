#!/bin/bash

# Hata takibi için
set -e
LOGFILE="cpio_operation.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "=== İşlem başladı: $(date) ==="

# Arşiv dosyasının yolu
CPIO_ARCHIVE="/home/agrotest2/e9pro-extractor/extracted/_firmware.bin.extracted/minerfs.cpio"
ORIG_FIRMWARE="/home/agrotest2/e9pro-extractor/extracted/firmware.bin"

# Hedef klasör
TARGET_DIR="/home/agrotest2/e9pro-extractor/malabak"

# Çıktı dosyaları
OUTPUT_CPIO="minerfs_new.cpio"
OUTPUT_BIN="minerfs_new.bin"
OUTPUT_BMU="minerfs_new.bmu"
OUTPUT_SIGNED="minerfs_signed.bmu"

# Anahtar dosyaları
PRIVKEY_FILE="/home/agrotest2/e9pro-extractor/private.key"
PUBKEY_FILE="/home/agrotest2/e9pro-extractor/pubkey.pem"

# Private key ve public key oluştur
generate_keys() {
    echo "Private ve public key oluşturuluyor..."
    
    # RSA private key oluştur
    openssl genrsa -out "$PRIVKEY_FILE" 2048
    
    # Private key'den public key çıkar
    openssl rsa -in "$PRIVKEY_FILE" -pubout -out "$PUBKEY_FILE"
    
    echo "Anahtarlar oluşturuldu:"
    echo "Private key: $PRIVKEY_FILE"
    echo "Public key: $PUBKEY_FILE"
    
    # Güvenlik için private key için izinleri kısıtla
    chmod 600 "$PRIVKEY_FILE"
}

# Eğer private key yoksa oluştur
if [ ! -f "$PRIVKEY_FILE" ]; then
    generate_keys
else
    echo "Mevcut anahtarlar kullanılacak"
fi

# İşlem seçimi
if [ "$1" == "extract" ] || [ -z "$1" ]; then
    # Hedef klasörü oluştur (yoksa)
    mkdir -p "$TARGET_DIR"

    # Hedef klasöre geç
    cd "$TARGET_DIR" || { echo "Klasöre geçilemedi: $TARGET_DIR"; exit 1; }

    # CPIO arşivini çıkar
    echo "Arşiv çıkarılıyor: $CPIO_ARCHIVE"
    cpio -idmv < "$CPIO_ARCHIVE" || { echo "CPIO çıkarma başarısız oldu!"; exit 1; }

    echo "İşlem tamamlandı. Dosyalar '$TARGET_DIR' klasörüne çıkarıldı."

elif [ "$1" == "create" ]; then
    # Düzenlenen dosyaları .cpio olarak arşivle
    echo "1. ADIM: CPIO Arşivi Oluşturma"
    echo "------------------------------"
    echo "Dosyalar arşivleniyor: $OUTPUT_CPIO"
    
    # malabak klasörüne git
    cd "$TARGET_DIR" || { echo "Klasöre geçilemedi: $TARGET_DIR"; exit 1; }
    
    # Tüm dosya ve klasörleri listele, sonra cpio ile arşivle
    echo "CPIO arşivi oluşturuluyor (format: newc)"
    find . -depth -print | cpio -H newc -ov > "../$OUTPUT_CPIO" || { echo "CPIO oluşturma başarısız oldu!"; exit 1; }
    
    # Ana dizine dön
    cd ..
    
    echo "CPIO arşivi başarıyla oluşturuldu: $OUTPUT_CPIO"
    
    # 2. ADIM: CPIO arşivini BIN formatına dönüştürme
    echo ""
    echo "2. ADIM: BIN Dosyası Oluşturma"
    echo "------------------------------"
    echo "CPIO arşivi BIN dosyasına dönüştürülüyor: $OUTPUT_BIN"
    
    # Orijinal firmware başlığını analiz et ve kullan
    if [ -f "$ORIG_FIRMWARE" ]; then
        echo "Orijinal firmware başlığı analiz ediliyor"
        # E9-Pro başlığını çek (ilk 16 byte)
        head -c 16 "$ORIG_FIRMWARE" > "${OUTPUT_BIN}.header"
        
        # Şu anki tarihi başlıkta güncelle (YYYYMMDD formatı)
        CURR_DATE=$(date +"%Y%m%d")
        printf "%s" "$CURR_DATE" | dd of="${OUTPUT_BIN}.header" bs=1 seek=10 count=8 conv=notrunc
        
        # Başlığı ve CPIO içeriğini birleştir
        echo "E9-Pro başlığı ekleniyor"
        cat "${OUTPUT_BIN}.header" "$OUTPUT_CPIO" > "$OUTPUT_BIN"
        rm -f "${OUTPUT_BIN}.header"
    else
        echo "Orijinal firmware bulunamadı, BIN dosyası doğrudan CPIO'dan oluşturuluyor"
        cp "$OUTPUT_CPIO" "$OUTPUT_BIN"
    fi
    
    # BMU dosyasını FIT formatına dönüştürme 
    if command -v mkimage &> /dev/null; then
        echo "U-Boot fitImage formatına dönüştürülüyor"
        mkimage -f auto -A arm -O linux -T filesystem -C none -d "$OUTPUT_BIN" "${OUTPUT_BIN}.fit" || \
            echo "UYARI: FIT imaj dönüşümü başarısız oldu, devam ediliyor"
        
        if [ -f "${OUTPUT_BIN}.fit" ]; then
            mv "${OUTPUT_BIN}.fit" "$OUTPUT_BIN"
            echo "BIN dosyası FIT formatında güncellendi"
        fi
    else
        echo "UYARI: mkimage komutu bulunamadı, FIT formatına dönüştürülemedi"
        echo "u-boot-tools paketini yüklemeyi deneyin: sudo apt-get install u-boot-tools"
    fi
    
    echo "BIN dosyası başarıyla oluşturuldu: $OUTPUT_BIN"
    
    # 3. ADIM: BIN dosyasını imzalayarak BMU oluşturma
    echo ""
    echo "3. ADIM: BMU Dosyası Oluşturma ve İmzalama"
    echo "------------------------------"
    echo "BIN dosyası BMU formatına dönüştürülüyor: $OUTPUT_BMU"
    
    # Önce BIN dosyasını BMU formatına dönüştür
    cp "$OUTPUT_BIN" "$OUTPUT_BMU"
    
    # Private key ile dosyayı imzalama
    if [ -f "$PRIVKEY_FILE" ]; then
        echo "BMU dosyası özel anahtar ile imzalanıyor"
        
        # İmzalama için geçici dosya
        SIGNATURE_FILE="${OUTPUT_BMU}.sig"
        
        # Dosyayı imzala (sha256 hash ile)
        openssl dgst -sha256 -sign "$PRIVKEY_FILE" -out "$SIGNATURE_FILE" "$OUTPUT_BMU"
        
        if [ -f "$SIGNATURE_FILE" ]; then
            # İmza dosyasının boyutunu al
            SIG_SIZE=$(stat -c%s "$SIGNATURE_FILE")
            echo "İmza boyutu: $SIG_SIZE bayt"
            
            # İmza boyutunu dosya başına ekle ve imza + dosyayı birleştir
            printf "SIGN%08x" "$SIG_SIZE" > "$OUTPUT_SIGNED.header"
            cat "$OUTPUT_SIGNED.header" "$SIGNATURE_FILE" "$OUTPUT_BMU" > "$OUTPUT_SIGNED"
            
            echo "İmzalı BMU dosyası oluşturuldu: $OUTPUT_SIGNED"
            rm -f "$SIGNATURE_FILE" "$OUTPUT_SIGNED.header"
        else
            echo "UYARI: İmza dosyası oluşturulamadı"
            cp "$OUTPUT_BMU" "$OUTPUT_SIGNED"
        fi
    else
        echo "UYARI: Private key bulunamadı, imzalama yapılamadı"
        cp "$OUTPUT_BMU" "$OUTPUT_SIGNED"
    fi
    
    # Dosya büyüklükleri hakkında bilgi
    echo ""
    echo "Oluşturulan Dosyalar:"
    echo "------------------------------"
    echo "CPIO arşivi: $OUTPUT_CPIO"
    echo "BIN dosyası: $OUTPUT_BIN"
    echo "BMU dosyası: $OUTPUT_BMU"
    echo "İmzalı BMU dosyası: $OUTPUT_SIGNED"
    
    ls -lh "$OUTPUT_CPIO" "$OUTPUT_BIN" "$OUTPUT_BMU" "$OUTPUT_SIGNED" 2>/dev/null
    
    echo ""
    echo "İşlem tamamlandı. İmzalı BMU dosyası cihaza yüklenmeye hazır: $OUTPUT_SIGNED"

elif [ "$1" == "info" ]; then
    # Orijinal CPIO dosyası hakkında bilgi edinme
    echo "Orijinal CPIO dosya bilgisi:"
    file "$CPIO_ARCHIVE"
    
    # İçeriği hakkında bilgi edinme
    echo -e "\nOrijinal CPIO içeriği:"
    cpio -itv < "$CPIO_ARCHIVE" 2>/dev/null || echo "İçerik listelenemiyor"
    
    # Orijinal firmware hakkında bilgi
    if [ -f "$ORIG_FIRMWARE" ]; then
        echo -e "\nOrijinal firmware başlık analizi:"
        hexdump -C "$ORIG_FIRMWARE" | head -20
        
        # Tarih bilgisi çıkarma (10. bayttan itibaren 8 bayt)
        echo -e "\nFirmware tarihi:"
        dd if="$ORIG_FIRMWARE" bs=1 skip=10 count=8 2>/dev/null | hexdump -C
    fi
    
    # Eğer varsa yeni oluşturulmuş CPIO dosyası hakkında bilgi
    if [ -f "$OUTPUT_CPIO" ]; then
        echo -e "\nYeni oluşturulan CPIO dosya bilgisi:"
        file "$OUTPUT_CPIO"
        
        echo -e "\nYeni CPIO içeriği baş kısmı:"
        cpio -itv < "$OUTPUT_CPIO" 2>/dev/null | head -10 || echo "İçerik listelenemiyor"
    fi
    
    # Eğer varsa yeni BMU dosyası hakkında bilgi
    if [ -f "$OUTPUT_BMU" ]; then
        echo -e "\nOluşturulan BMU başlık analizi:"
        hexdump -C "$OUTPUT_BMU" | head -20
    fi

elif [ "$1" == "analyze" ]; then
    # Daha detaylı analiz için
    echo "Orijinal firmware detaylı analiz:"
    
    if [ -f "$ORIG_FIRMWARE" ]; then
        echo -e "\nOrijinal firmware başlık yapısı:"
        hexdump -C "$ORIG_FIRMWARE" | head -50
        
        # E9-Pro tanıtıcısını çek
        echo -e "\nFirmware tanıtıcısı:"
        dd if="$ORIG_FIRMWARE" bs=1 count=16 2>/dev/null | hexdump -C
        
        echo -e "\nU-Boot bilgi analizi (eğer formattaysa):"
        strings "$ORIG_FIRMWARE" | grep -i "u-boot" || echo "U-Boot bilgisi bulunamadı"
    fi
    
    if [ -f "$CPIO_ARCHIVE" ]; then
        echo -e "\nCPIO arşiv yapısı:"
        hexdump -C "$CPIO_ARCHIVE" | head -20
    fi

elif [ "$1" == "keys" ]; then
    # Yeni veya mevcut anahtarları görüntüle
    if [ -f "$PRIVKEY_FILE" ] && [ -f "$PUBKEY_FILE" ]; then
        echo "Mevcut anahtarlar siliniyor ve yeniden oluşturuluyor..."
        rm -f "$PRIVKEY_FILE" "$PUBKEY_FILE"
    fi
    
    generate_keys
    
    echo -e "\nPublic Key İçeriği:"
    cat "$PUBKEY_FILE"
else
    echo "Geçersiz parametre! Kullanım:"
    echo "  $0           # arşivi çıkar"
    echo "  $0 extract   # arşivi çıkar"
    echo "  $0 create    # yeni arşiv oluştur ve .bmu yap"
    echo "  $0 info      # CPIO dosyası hakkında bilgi göster"
    echo "  $0 analyze   # Firmware'i detaylı analiz et"
    echo "  $0 keys      # Yeni private ve public key oluştur"
fi

echo "=== İşlem tamamlandı: $(date) ==="
echo "Log dosyasına bakın: $LOGFILE"
