#!/bin/bash

echo "Binwalk Kurulum Scripti Başlatılıyor..."

# Mevcut kurulumu temizle
echo "Mevcut binwalk kurulumunu temizleme..."
pip uninstall -y binwalk
rm -rf ~/.local/lib/python*/site-packages/binwalk*

# Gerekli bağımlılıkları kur
echo "Bağımlılıklar kuruluyor..."
sudo apt-get update
sudo apt-get install -y build-essential autoconf git python3-dev python3-pip

# Binwalk'ı GitHub'dan kur
echo "Binwalk indiriliyor ve kuruluyor..."
rm -rf /tmp/binwalk
git clone https://github.com/ReFirmLabs/binwalk.git
cd /tmp/binwalk || {
    echo "Hata: /tmp/binwalk dizinine geçilemedi!"
    exit 1
}

# Doğru dizinde olduğumuzu kontrol et
if [ ! -f "setup.py" ]; then
    echo "Hata: setup.py dosyası bulunamadı! Binwalk kaynak kodu doğru şekilde indirilemedi."
    echo "Mevcut dizin: $(pwd)"
    ls -la
    exit 1
fi

# Kurulum işlemi
python3 /tmp/binwalk/setup.py install --user

# İsteğe bağlı bağımlılıklar
echo "İsteğe bağlı bağımlılıklar kuruluyor..."
sudo apt-get install -y libqt5opengl5-dev python3-opengl python3-pyqt5 python3-pyqt5.qtsvg python3-numpy python3-scipy

# Extraction araçları
echo "Extraction araçları kuruluyor..."
sudo apt-get install -y mtd-utils gzip bzip2 tar arj lhasa p7zip p7zip-full cabextract squashfs-tools zlib1g-dev liblzma-dev liblzo2-dev sleuthkit

# Kurulumun başarılı olduğunu kontrol et
echo "Kurulumu test ediliyor..."
if command -v binwalk &>/dev/null; then
    echo "Binwalk başarıyla kuruldu!"
    binwalk --version
else
    echo "Binwalk kurulumu doğrulanamadı. PATH'i kontrol edin."
    echo "Kurulum tamamlandı, ancak sistemi yeniden başlatmanız gerekebilir."
fi

echo "Kurulum tamamlandı."
echo "Not: Eğer 'cramfsprogs' veya 'cramfsswap' paketleri bulunamazsa, bunlar dağıtımınızda mevcut olmayabilir."
