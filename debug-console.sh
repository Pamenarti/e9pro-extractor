#!/bin/bash

# Bu betik Antminer E9 Pro cihazının seri konsoluna bağlanıp, boot ve firmware yükleme 
# loglarını kaydetmek için kullanılır

# Kullanım kontrolü
if [ $# -lt 1 ]; then
    echo "Kullanım: $0 <port> [baud_rate]"
    echo "Örnek: $0 /dev/ttyUSB0 115200"
    echo "       $0 /dev/ttyACM0"
    exit 1
fi

PORT=$1
BAUD_RATE=${2:-115200}  # Varsayılan baud rate: 115200
LOG_FILE="console_log_$(date +%Y%m%d_%H%M%S).txt"

# USB-Serial dönüştürücünün varlığını kontrol et
if [ ! -e "$PORT" ]; then
    echo "HATA: $PORT bulunamadı."
    echo "Lütfen USB-Serial dönüştürücünün bağlı olduğundan emin olun."
    echo "Mevcut portları kontrol edin: ls -l /dev/ttyUSB* /dev/ttyACM*"
    exit 1
fi

# screen yüklü mü kontrol et
if ! command -v screen &> /dev/null; then
    echo "HATA: 'screen' komutu bulunamadı."
    echo "Lütfen şu komutu çalıştırın: sudo apt-get install screen"
    exit 1
fi

echo "Seri port konsoluna bağlanılıyor: $PORT ($BAUD_RATE baud)"
echo "Loglar $LOG_FILE dosyasına kaydedilecek"
echo "Çıkmak için CTRL+A ardından \\ tuşlarına basın"
echo ""

# Screen ile seri porta bağlan ve logları kaydet
screen -L -Logfile "$LOG_FILE" "$PORT" "$BAUD_RATE"

# Bağlantı sonlandığında
echo ""
echo "Konsol bağlantısı sonlandı. Loglar $LOG_FILE dosyasına kaydedildi."
echo "Log dosyasını incelemek için: less $LOG_FILE"
