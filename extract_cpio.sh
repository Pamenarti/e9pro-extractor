#!/bin/bash

# Hata takibi için
set -e
LOGFILE="cpio_operation.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "=== İşlem başladı: $(date) ==="

# Arşiv dosyasının yolu
CPIO_ARCHIVE="/home/agrotest2/e9pro-extractor/extracted/_firmware.bin.extracted/minerfs.cpio"

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
    
    # .cpio dosyasını .bmu olarak kopyala/yeniden adlandır
    echo "CPIO dosyası BMU formatına dönüştürülüyor"
    cp "$OUTPUT_CPIO" "$OUTPUT_BMU" || { echo "BMU oluşturma başarısız oldu!"; exit 1; }
    
    # BMU dosyasını FIT formatına dönüştürmeye çalışalım
    if command -v mkimage &> /dev/null; then
        echo "U-Boot fitImage formatına dönüştürülüyor"
        mkimage -f auto -A arm -O linux -T filesystem -C none -d "$OUTPUT_BMU" "${OUTPUT_BMU}.fit" || \
            echo "UYARI: FIT imaj dönüşümü başarısız oldu, devam ediliyor"
        
        if [ -f "${OUTPUT_BMU}.fit" ]; then
            mv "${OUTPUT_BMU}.fit" "$OUTPUT_BMU"
        fi
    else
        echo "UYARI: mkimage komutu bulunamadı, FIT formatına dönüştürülemedi"
    fi
    
    # İmzalama işlemi için OpenSSL kullanabiliriz
    echo "BMU dosyası imzalanıyor"
    openssl dgst -sha256 -sign "$PUBKEY_FILE" -out "${OUTPUT_BMU}.sig" "$OUTPUT_BMU" || \
        echo "UYARI: İmzalama işlemi başarısız oldu, ancak işleme devam edilecek"
    
    # İmzayı ve dosyayı birleştirme
    if [ -f "${OUTPUT_BMU}.sig" ]; then
        cat "${OUTPUT_BMU}.sig" "$OUTPUT_BMU" > "$OUTPUT_SIGNED" || \
            echo "UYARI: İmza ve BMU dosyası birleştirilemedi"
        echo "İmzalı BMU dosyası: $OUTPUT_SIGNED"
    fi
    
    # Dosya büyüklükleri hakkında bilgi
    echo "Dosya büyüklükleri:"
    ls -lh "$OUTPUT_CPIO" "$OUTPUT_BMU" 2>/dev/null
    [ -f "$OUTPUT_SIGNED" ] && ls -lh "$OUTPUT_SIGNED"
    
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
    
    # Eğer varsa yeni oluşturulmuş CPIO dosyası hakkında bilgi
    if [ -f "$OUTPUT_CPIO" ]; then
        echo -e "\nYeni oluşturulan CPIO dosya bilgisi:"
        file "$OUTPUT_CPIO"
        
        echo -e "\nYeni CPIO içeriği:"
        cpio -itv < "$OUTPUT_CPIO" 2>/dev/null || echo "İçerik listelenemiyor"
    fi
else
    echo "Geçersiz parametre! Kullanım:"
    echo "  $0           # arşivi çıkar"
    echo "  $0 extract   # arşivi çıkar"
    echo "  $0 create    # yeni arşiv oluştur ve .bmu yap"
    echo "  $0 info      # CPIO dosyası hakkında bilgi göster"
fi

echo "=== İşlem tamamlandı: $(date) ==="
echo "Log dosyasına bakın: $LOGFILE"
