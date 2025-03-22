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
TARGET_DIR="malabak"

# Çıktı dosyaları
OUTPUT_CPIO="minerfs_new.cpio"
OUTPUT_BMU="minerfs_new.bmu"
OUTPUT_SIGNED="minerfs_signed.bmu"

# Public key dosyası
PUBKEY_FILE="/home/agrotest2/e9pro-extractor/pubkey.pem"

# Public key'i kaydet
if [ ! -f "$PUBKEY_FILE" ]; then
    cat > "$PUBKEY_FILE" << 'EOF'
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4nK2btpK1JYkkB9t4Krs
NUuxTdGxABFkEP8dWAaf6F+wjZGi8EjVI3ISWEaijXQ0KdY1jP4ijyeEVNIP4mm+
Xt55rTQIuaV2r7U7tko8ZJqlRiS88Ls5ZFs6LYzeledAdL9IPQK4iNFah04JQU9t
P/cPsSZ62C7QhFEGT19DrKcjJ9HP8/424JRt+6suIjkiQPdeFkHoxTVwF+QGiQ04
uUbg2WS+aTVTyJv0pAMPxe1URo9ang3J4X75wOqJl4/9X+W/UDknz5g67zyBzBtU
/6RQQBzZWXgsMp70Gwc55kpUX9TfvEA0sdURD+fms8fVGbzOn23P/A8InVr7Vxbr
SQIDAQAB
-----END PUBLIC KEY-----
EOF
    echo "Public key dosyası oluşturuldu: $PUBKEY_FILE"
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
    echo "Dosyalar arşivleniyor: $OUTPUT_CPIO"
    
    # malabak klasörüne git
    cd "$TARGET_DIR" || { echo "Klasöre geçilemedi: $TARGET_DIR"; exit 1; }
    
    # Tüm dosya ve klasörleri listele, sonra cpio ile arşivle
    echo "CPIO arşivi oluşturuluyor (format: newc)"
    find . -depth -print | cpio -H newc -ov > "../$OUTPUT_CPIO" || { echo "CPIO oluşturma başarısız oldu!"; exit 1; }
    
    # Ana dizine dön
    cd ..
    
    # Orijinal firmware başlığını analiz et ve kullan
    if [ -f "$ORIG_FIRMWARE" ]; then
        echo "Orijinal firmware başlığı analiz ediliyor"
        # E9-Pro başlığını çek (ilk 16 byte)
        head -c 16 "$ORIG_FIRMWARE" > "${OUTPUT_BMU}.header"
        
        # Şu anki tarihi başlıkta güncelle (YYYYMMDD formatı)
        CURR_DATE=$(date +"%Y%m%d")
        printf "%s" "$CURR_DATE" | dd of="${OUTPUT_BMU}.header" bs=1 seek=10 count=8 conv=notrunc
        
        # Başlığı ve CPIO içeriğini birleştir
        echo "E9-Pro başlığı ekleniyor"
        cat "${OUTPUT_BMU}.header" "$OUTPUT_CPIO" > "$OUTPUT_BMU"
        rm -f "${OUTPUT_BMU}.header"
    else
        echo "Orijinal firmware bulunamadı, başlık eklenemiyor"
        cp "$OUTPUT_CPIO" "$OUTPUT_BMU"
    fi
    
    # BMU dosyasını FIT formatına dönüştürme 
    if command -v mkimage &> /dev/null; then
        echo "U-Boot fitImage formatına dönüştürülüyor"
        mkimage -f auto -A arm -O linux -T filesystem -C none -d "$OUTPUT_BMU" "${OUTPUT_BMU}.fit" || \
            echo "UYARI: FIT imaj dönüşümü başarısız oldu, devam ediliyor"
        
        if [ -f "${OUTPUT_BMU}.fit" ]; then
            mv "${OUTPUT_BMU}.fit" "$OUTPUT_BMU"
        fi
    else
        echo "UYARI: mkimage komutu bulunamadı, FIT formatına dönüştürülemedi"
        echo "u-boot-tools paketini yüklemeyi deneyin: sudo apt-get install u-boot-tools"
    fi
    
    # NOT: İmzalama için private key gerekli, public key kullanılamaz
    echo "NOT: İmzalama işlemi için private key gereklidir. Public key ile imzalama yapılamaz."
    
    # Dosya büyüklükleri hakkında bilgi
    echo "Dosya büyüklükleri:"
    ls -lh "$OUTPUT_CPIO" "$OUTPUT_BMU" 2>/dev/null
    
    echo "İşlem tamamlandı."
    echo "CPIO arşivi: $OUTPUT_CPIO"
    echo "BMU dosyası: $OUTPUT_BMU"

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

else
    echo "Geçersiz parametre! Kullanım:"
    echo "  $0           # arşivi çıkar"
    echo "  $0 extract   # arşivi çıkar"
    echo "  $0 create    # yeni arşiv oluştur ve .bmu yap"
    echo "  $0 info      # CPIO dosyası hakkında bilgi göster"
    echo "  $0 analyze   # Firmware'i detaylı analiz et"
fi

echo "=== İşlem tamamlandı: $(date) ==="
echo "Log dosyasına bakın: $LOGFILE"
