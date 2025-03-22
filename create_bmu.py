#!/usr/bin/env python3
"""
Antminer BMU oluşturma ve doğrulama aracı.
BMU formatına göre firmware oluşturur veya analiz eder.
"""

import os
import sys
import struct
import hashlib
import argparse
from Crypto.PublicKey import RSA
from Crypto.Signature import pkcs1_15
from Crypto.Hash import SHA256
from datetime import datetime

# BMU dosya formatı sabit değerleri
BMU_MAGIC = 0x26
MINER_TYPE_E9PRO = b'E9-Pro'
CURRENT_DATE = datetime.now().strftime("%Y%m%d")

def create_bmu(cpio_file, output_file, private_key_file=None):
    """BMU dosyası oluştur."""
    print(f"CPIO dosyası: {cpio_file}")
    print(f"Çıktı dosyası: {output_file}")
    
    # CPIO dosyasını oku
    with open(cpio_file, 'rb') as f:
        cpio_data = f.read()
    
    # 1. BMU Başlığını oluştur (16 bytes)
    # Başlık formatı: magic + miner_type + date + ...
    header = struct.pack('<B', BMU_MAGIC)  # Magic number (1 byte)
    header += MINER_TYPE_E9PRO  # Miner tipi (6 bytes)
    header += b'\x00\x00\x01\x02\x00'  # Sabit veriler (5 bytes)
    header += CURRENT_DATE.encode('ascii')  # Tarih (8 bytes)
    header += b'\x00\x01'  # Son 2 byte
    
    print(f"Başlık uzunluğu: {len(header)} bytes")
    
    # 2. Miner.pem verisi (public key) ekle
    # Bu kısım örnek bir public key kullanıyor, gerçek anahtarınızı kullanın
    with open("/home/agrotest2/e9pro-extractor/pubkey.pem", 'rb') as f:
        public_key_data = f.read()
    
    # 3. BMU dosyasını oluştur
    with open(output_file, 'wb') as f:
        # Başlığı yaz
        f.write(header)
        
        # Public key'i yaz (ayrı bölüm olarak)
        f.write(public_key_data)
        
        # CPIO verisi
        f.write(cpio_data)
    
    # 4. İmzalama (eğer private key varsa)
    if private_key_file:
        try:
            with open(private_key_file, 'rb') as key_file:
                private_key = RSA.import_key(key_file.read())
            
            # BMU dosyasının hash'ini al
            with open(output_file, 'rb') as f:
                bmu_data = f.read()
            
            # Hash oluştur ve imzala
            h = SHA256.new(bmu_data)
            signature = pkcs1_15.new(private_key).sign(h)
            
            # İmzayı dosyanın sonuna ekle
            with open(output_file, 'ab') as f:
                # İmza formatı: "SIGN" + imza boyutu (hex) + imza verisi
                f.write(b'SIGN')
                f.write(struct.pack('<L', len(signature)))
                f.write(signature)
            
            print(f"BMU dosyası imzalandı: {len(signature)} bytes signature")
        except Exception as e:
            print(f"İmzalama hatası: {str(e)}")
    
    print(f"BMU dosyası oluşturuldu: {output_file}")
    print(f"Dosya boyutu: {os.path.getsize(output_file)} bytes")

def analyze_bmu(bmu_file):
    """BMU dosyasını analiz et ve detaylı bilgi göster."""
    with open(bmu_file, 'rb') as f:
        data = f.read()
    
    if len(data) < 16:
        print("Hata: Dosya çok küçük, BMU formatında olmayabilir.")
        return
    
    # Başlık analizi
    magic = data[0]
    miner_type = data[1:7].decode('utf-8', errors='ignore')
    date_str = data[10:18].decode('utf-8', errors='ignore')
    
    print("=== BMU Analizi ===")
    print(f"Magic: 0x{magic:02x}")
    print(f"Miner Type: {miner_type}")
    print(f"Tarih: {date_str}")
    print(f"Dosya boyutu: {len(data)} bytes")
    
    # Public key arama
    pub_key_start = data.find(b'-----BEGIN PUBLIC KEY-----')
    if pub_key_start > 0:
        pub_key_end = data.find(b'-----END PUBLIC KEY-----', pub_key_start)
        if pub_key_end > 0:
            pub_key_end += len(b'-----END PUBLIC KEY-----')
            print(f"\nPublic key bulundu (offset {pub_key_start}-{pub_key_end})")
            print(data[pub_key_start:pub_key_end].decode('utf-8'))
    
    # İmza arama
    sig_pos = data.find(b'SIGN')
    if sig_pos > 0:
        print(f"\nİmza başlığı bulundu (offset {sig_pos})")
        if sig_pos + 8 <= len(data):
            sig_size = struct.unpack('<L', data[sig_pos+4:sig_pos+8])[0]
            print(f"İmza boyutu: {sig_size} bytes")
            print(f"İmza konumu: dosyanın {sig_pos} - {sig_pos + 8 + sig_size} byte arası")
    
    # CPIO içeriğini kontrol et
    tmp_file = "/tmp/bmu_cpio_extract.cpio"
    with open(tmp_file, 'wb') as f:
        # İlk 16 byte'ı atla (başlık)
        f.write(data[16:])
    
    import subprocess
    try:
        result = subprocess.run(['cpio', '-it'], 
                               input=data[16:], 
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE,
                               check=False)
        if result.returncode == 0:
            print("\nCPIO içeriği başarıyla doğrulandı")
            print("İlk 10 dosya:")
            for line in result.stdout.decode('utf-8').splitlines()[:10]:
                print(f"  {line}")
        else:
            print("\nCPIO içeriği doğrulanamadı, format doğru değil olabilir.")
    except Exception as e:
        print(f"CPIO kontrol hatası: {str(e)}")
    
    # Geçici dosyayı temizle
    os.remove(tmp_file)

def main():
    parser = argparse.ArgumentParser(description='Antminer BMU dosya oluşturma ve analiz aracı')
    subparsers = parser.add_subparsers(dest='command', help='Komut')
    
    # create komutu
    create_parser = subparsers.add_parser('create', help='BMU dosyası oluştur')
    create_parser.add_argument('cpio_file', help='CPIO arşiv dosyası')
    create_parser.add_argument('output_file', help='Çıkış BMU dosyası')
    create_parser.add_argument('--private-key', '-k', help='İmzalama için private key dosyası')
    
    # analyze komutu
    analyze_parser = subparsers.add_parser('analyze', help='BMU dosyasını analiz et')
    analyze_parser.add_argument('bmu_file', help='Analiz edilecek BMU dosyası')
    
    args = parser.parse_args()
    
    if args.command == 'create':
        create_bmu(args.cpio_file, args.output_file, args.private_key)
    elif args.command == 'analyze':
        analyze_bmu(args.bmu_file)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
