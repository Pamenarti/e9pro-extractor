#!/bin/bash

# Bu betik firmware dosyasının formatını ve yapısını doğrulamak için kullanılır

# Kullanım kontrolü
if [ $# -lt 1 ]; then
    echo "Kullanım: $0 <firmware_dosyası> [orijinal_firmware]"
    echo "Örnek: $0 minerfs_signed.bmu"
    echo "       $0 debug_with_header.bmu /home/agrotest2/e9pro-extractor/extracted/firmware.bin"
    exit 1
fi

FIRMWARE=$1
ORIG_FIRMWARE=${2:-"/home/agrotest2/e9pro-extractor/extracted/firmware.bin"}

# Firmware dosyasının varlığını kontrol et
if [ ! -f "$FIRMWARE" ]; then
    echo "HATA: $FIRMWARE dosyası bulunamadı."
    exit 1
fi

echo "=== Firmware Doğrulama Raporu ==="
echo "Firmware: $FIRMWARE"
echo ""

# Dosya türü kontrolü
echo "1. Dosya Türü Analizi:"
file "$FIRMWARE"
echo ""

# Boyut kontrolü
SIZE=$(stat -c %s "$FIRMWARE")
echo "2. Boyut Analizi:"
echo "   Dosya boyutu: $SIZE byte ($(echo "$SIZE/1024/1024" | bc -l | xargs printf "%.2f") MB)"

if [ -f "$ORIG_FIRMWARE" ]; then
    ORIG_SIZE=$(stat -c %s "$ORIG_FIRMWARE")
    echo "   Orijinal firmware boyutu: $ORIG_SIZE byte ($(echo "$ORIG_SIZE/1024/1024" | bc -l | xargs printf "%.2f") MB)"
    
    # Boyut karşılaştırması
    if [ "$SIZE" -gt "$ORIG_SIZE" ]; then
        echo "   UYARI: Firmware dosyası orijinalinden daha büyük"
        echo "   Bazı cihazlar maksimum boyut sınırlaması olabilir"
    elif [ "$SIZE" -lt "$(($ORIG_SIZE * 80 / 100))" ]; then
        echo "   UYARI: Firmware boyutu orijinalinden çok küçük"
        echo "   Eksik bileşenler olabilir"
    fi
fi
echo ""

# Başlık kontrolü
echo "3. Başlık Analizi:"
hexdump -C -n 32 "$FIRMWARE"

# E9-Pro başlık kontrolü
if hexdump -C -n 16 "$FIRMWARE" | grep -q "E9-Pro"; then
    echo "   Geçerli E9-Pro başlığı tespit edildi"
else
    echo "   UYARI: E9-Pro başlığı tespit edilemedi"
fi
echo ""

# İmza kontrolü
echo "4. İmza Analizi:"
# İlk imza başlığını kontrol et - başta olmamalı
if hexdump -C -n 16 "$FIRMWARE" | grep -q "SIGN"; then
    echo "   UYARI: İmza başlığı dosyanın başında - bu yanlış format olabilir!"
else
    # Dosyanın sonunda imza arama
    FILESIZE=$(stat -c%s "$FIRMWARE")
    END_OFFSET=$(($FILESIZE - 300))  # İmza yaklaşık son 300 byte'ta olmalı
    
    if [ $END_OFFSET -gt 0 ]; then
        if dd if="$FIRMWARE" bs=1 skip=$END_OFFSET 2>/dev/null | grep -q "SIGN"; then
            echo "   İmza bilgisi dosyanın sonunda bulundu (doğru format)"
            
            # İmza boyutunu çıkarma
            SIG_HEADER=$(dd if="$FIRMWARE" bs=1 skip=$END_OFFSET count=12 2>/dev/null | hexdump -ve '1/1 "%.2x"')
            if [[ "$SIG_HEADER" =~ 5349474e([0-9a-f]{8}) ]]; then
                SIG_SIZE_HEX="${BASH_REMATCH[1]}"
                SIG_SIZE=$((16#$SIG_SIZE_HEX))
                echo "   İmza boyutu: 0x$SIG_SIZE_HEX ($SIG_SIZE bayt)"
            fi
        else
            echo "   İmza bilgisi bulunamadı"
        fi
    else
        echo "   Dosya çok küçük, imza alanı incelenemedi"
    fi
fi
echo ""

# FIT format kontrolü
echo "5. FIT Format Kontrolü:"
strings "$FIRMWARE" | grep -q "FIT desc" && echo "   FIT başlığı tespit edildi" || echo "   FIT başlığı tespit edilemedi"

# U-Boot kontrolü
echo "   U-Boot referansı aranıyor..."
strings "$FIRMWARE" | grep -i "u-boot" | head -3
echo ""

# CPIO analizi
echo "6. CPIO İçerik Analizi:"
# CPIO başlık arama
HEADER_SIZE=0
if [ -f "$ORIG_FIRMWARE" ]; then
    # Orijinal firmware'de E9-Pro başlığından sonra CPIO başlar
    HEADER_SIZE=16
fi

# FIT header varsa, başlık boyutunu ayarla
if strings "$FIRMWARE" | grep -q "FIT desc"; then
    echo "   FIT header tespit edildi, CPIO başlangıcı ayarlanıyor"
    HEADER_SIZE=1024  # Yaklaşık değer
fi

# CPIO içeriği analizi
echo "   CPIO içeriği aranıyor (başlıktan sonra)..."
dd if="$FIRMWARE" bs=1 skip=$HEADER_SIZE count=1024 2>/dev/null | hexdump -C | head -5
echo ""

# Deneme çıkarma
echo "7. CPIO Çıkarma Denemesi:"
TMP_DIR=$(mktemp -d)
(dd if="$FIRMWARE" bs=1 skip=$HEADER_SIZE 2>/dev/null | cpio -idmv -D "$TMP_DIR" 2>&1) | head -5
NUM_FILES=$(find "$TMP_DIR" -type f | wc -l)
echo "   $NUM_FILES dosya çıkarıldı"
if [ $NUM_FILES -eq 0 ]; then
    echo "   UYARI: Hiç dosya çıkarılamadı, CPIO formatı doğru olmayabilir"
fi
rm -rf "$TMP_DIR"
echo ""

echo "=== Firmware Doğrulama Tamamlandı ==="

# Hata özeti
echo ""
echo "TANILAMA ÖZETİ:"
if ! hexdump -C -n 16 "$FIRMWARE" | grep -q "E9-Pro"; then
    echo "SORUN: E9-Pro başlığı eksik"
fi

if [ $NUM_FILES -eq 0 ]; then
    echo "SORUN: CPIO içeriği çıkarılamadı"
fi

# Çözüm önerileri
echo ""
echo "ÖNERİLER:"
echo "1. ./extract_cpio.sh debug ile basit bir test firmware'i oluşturun"
echo "2. Cihaz seri konsola bağlanıp hata mesajlarını incelemek için debug-console.sh kullanın"
echo "3. Orijinal firmware'i analiz edin: ./extract_cpio.sh analyze"
echo "4. Tüm oluşturulan dosyaları doğrulayın: ./extract_cpio.sh verify-all"
echo "5. İmzalama sistemini doğrulayın: Dosyanın başında E9-Pro başlığı, sonunda imza olmalı"
