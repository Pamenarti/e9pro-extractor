#!/usr/bin/env python3
import os
import struct
import argparse
import binascii
import zlib
import tarfile
import io
import re
from datetime import datetime

def hexdump(data, length=16):
    """Basit bir hex dump fonksiyonu"""
    result = []
    for i in range(0, len(data), length):
        chunk = data[i:i+length]
        # f-strings yerine .format() kullanalım
        hexa = ' '.join(['{:02x}'.format(b) for b in chunk])
        ascii_text = ''.join([chr(b) if 32 <= b <= 126 else '.' for b in chunk])
        result.append('{:08x}  {:<48}  |{}|'.format(i, hexa, ascii_text))
    return '\n'.join(result)

def extract_bmu(bmu_file, output_dir):
    """BMU dosyasını analiz edip extract etme"""
    try:
        # Çıktı dizinini oluştur
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
            
        with open(bmu_file, 'rb') as f:
            data = f.read()
            
        # Dosya boyutu
        file_size = len(data)
        print("Dosya Boyutu: {} bytes".format(file_size))
        
        # İlk 100 byte'ı göster (header bilgileri için)
        print("\nDosya Başlığı (ilk 100 byte):")
        print(hexdump(data[:100]))
        
        # Magic number kontrolü (Antminer firmware imzası)
        # Not: Gerçek magic number değeri bilinmediğinden örnek olarak ilk 4 byte kontrol edildi
        magic = data[:4]
        print("\nMagic Number: {}".format(binascii.hexlify(magic).decode()))

        # Firmware içeriği potansiyel olarak bir sıkıştırılmış TAR arşivi olabilir
        # gzip formatını deneme
        try:
            decompressed = zlib.decompress(data, 16+zlib.MAX_WBITS)
            tar_file = os.path.join(output_dir, 'extracted.tar')
            with open(tar_file, 'wb') as f:
                f.write(decompressed)
            print("\nGZip sıkıştırması kaldırıldı: {}".format(tar_file))
            
            # TAR dosyasını açmayı dene
            try:
                tar = tarfile.open(tar_file)
                tar.extractall(path=output_dir)
                tar.close()
                print("TAR arşivi {} dizinine çıkarıldı.".format(output_dir))
            except:
                print("Dosya TAR arşivi olarak açılamadı.")
        except:
            print("\nGZip formatında değil, farklı sıkıştırma formatları deneniyor...")
        
        # Başka formatları deneme (xz, bz2, vs)
        try:
            decompressed = zlib.decompress(data)
            with open(os.path.join(output_dir, 'extracted_raw'), 'wb') as f:
                f.write(decompressed)
            print("Raw zlib sıkıştırması kaldırıldı.")
        except:
            print("Raw zlib formatında değil.")
        
        # Veri yapısını anlamaya çalışalım - bazı genel başlık alanlarını bulmaya çalış
        print("\nOlası Başlık Alanları:")
        
        # Timestamp araması (32-bit UNIX timestamp formatı)
        for i in range(0, min(1000, file_size - 4), 4):
            val = struct.unpack("<I", data[i:i+4])[0]
            # 2020-2030 arası tarihler için yaklaşık timestamp değer aralığı
            if 1577836800 <= val <= 1893456000:  
                date_str = datetime.fromtimestamp(val).strftime('%Y-%m-%d %H:%M:%S')
                print("Olası timestamp @ 0x{:x}: {} ({})".format(i, val, date_str))
        
        # Binary dosyayı kaydet
        bin_path = os.path.join(output_dir, 'firmware.bin')
        with open(bin_path, 'wb') as f:
            f.write(data)
        print("\nOrijinal binary dosya kaydedildi: {}".format(bin_path))
        
        print("\nAnaliz tamamlandı. Tüm çıkarılan dosyalar {} dizininde.".format(output_dir))
    
    except Exception as e:
        print("Hata: {}".format(e))

def analyze_firmware(firmware_file, output_dir):
    """Firmware binary dosyasını analiz edip içeriğini extract etme"""
    try:
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
            
        with open(firmware_file, 'rb') as f:
            data = f.read()
            
        file_size = len(data)
        print("Firmware Dosya Boyutu: {} bytes".format(file_size))
        
        print("\nFirmware Başlığı (ilk 128 byte):")
        print(hexdump(data[:128]))
        
        # Yaygın dosya sistemi imzalarını tanımla
        signatures = {
            b"hsqs": "SquashFS (little endian)",
            b"sqsh": "SquashFS (big endian)",
            b"jffs2": "JFFS2",
            b"UBI#": "UBIFS",
            b"\x85\x19\x01\xe9": "Cramfs",
            b"PTAR": "Tar archive",
            b"\x1f\x8b\x08": "GZip compressed",
            b"BZh": "BZip2 compressed",
            b"\xfd\x37\x7a\x58\x5a\x00": "XZ compressed"
        }
        
        # Tüm dosya boyunca bilinen imzaları ara
        print("\nTanımlanan Dosya Sistemi/Format İmzaları:")
        fs_found = False
        
        for offset in range(0, file_size - 20, 4):
            for signature, fs_type in signatures.items():
                if data[offset:offset+len(signature)] == signature:
                    print("0x{:08x}: {} imzası bulundu".format(offset, fs_type))
                    fs_found = True
                    
                    # SquashFS bölümünü çıkar
                    if signature in [b"hsqs", b"sqsh"]:
                        squashfs_file = os.path.join(output_dir, "squashfs_at_{:08x}.bin".format(offset))
                        with open(squashfs_file, 'wb') as f_out:
                            f_out.write(data[offset:])
                        print("SquashFS bölümü {} dosyasına kaydedildi.".format(squashfs_file))
                        print("SquashFS içeriğini çıkarmak için: 'unsquashfs -d çıktı_dizini squashfs_dosyası' komutunu kullanabilirsiniz.")
                    
                    # JFFS2 bölümünü çıkar
                    elif signature == b"jffs2":
                        jffs2_file = os.path.join(output_dir, "jffs2_at_{:08x}.bin".format(offset))
                        with open(jffs2_file, 'wb') as f_out:
                            f_out.write(data[offset:])
                        print("JFFS2 bölümü {} dosyasına kaydedildi.".format(jffs2_file))
                        print("JFFS2 içeriğini çıkarmak için: 'jefferson jffs2_dosyası -d çıktı_dizini' komutunu kullanabilirsiniz.")
                    
                    # GZip, BZip2, XZ sıkıştırılmış dosyaları çıkarmayı dene
                    elif signature in [b"\x1f\x8b\x08", b"BZh", b"\xfd\x37\x7a\x58\x5a\x00"]:
                        compressed_file = os.path.join(output_dir, "compressed_at_{:08x}.bin".format(offset))
                        with open(compressed_file, 'wb') as f_out:
                            f_out.write(data[offset:])
                        print("Sıkıştırılmış veri {} dosyasına kaydedildi.".format(compressed_file))
                        
                        # GZip ise, açmayı dene
                        if signature == b"\x1f\x8b\x08":
                            try:
                                decompressed = zlib.decompress(data[offset:], 16+zlib.MAX_WBITS)
                                decompressed_file = os.path.join(output_dir, "decompressed_gzip_{:08x}.bin".format(offset))
                                with open(decompressed_file, 'wb') as f_out:
                                    f_out.write(decompressed)
                                print("GZip sıkıştırması açıldı: {}".format(decompressed_file))
                            except:
                                print("GZip sıkıştırması açılamadı: {:08x}".format(offset))
        
        # String'leri ara
        strings_file = os.path.join(output_dir, "strings.txt")
        with open(strings_file, 'w', encoding='utf-8') as f_out:
            ascii_chars = re.findall(b'[ -~]{5,}', data)
            for s in ascii_chars:
                try:
                    decoded = s.decode('utf-8', errors='replace')
                    f_out.write("{}\n".format(decoded))
                except:
                    pass
        print("\nMetin içerikleri {} dosyasına kaydedildi.".format(strings_file))

        # Firmware içinde versiyon bilgisi aramayı dene
        version_patterns = [
            rb"VERSION\s*=\s*[\"\']?([0-9\.a-zA-Z_-]+)[\"\']?",
            rb"version\s*[\:\=]\s*[\"\']?([0-9\.a-zA-Z_-]+)[\"\']?",
            rb"firmware[_\-\s]*version\s*[\:\=]\s*[\"\']?([0-9\.a-zA-Z_-]+)[\"\']?"
        ]
        
        print("\nOlası Versiyon Bilgileri:")
        version_found = False
        for pattern in version_patterns:
            matches = re.finditer(pattern, data)
            for match in matches:
                version = match.group(1).decode('utf-8', errors='replace')
                offset = match.start()
                print("0x{:08x}: {}".format(offset, version))
                version_found = True
        
        if not version_found:
            print("Versiyon bilgisi bulunamadı.")
        
        if not fs_found:
            print("\nBilinen dosya sistemi imzası bulunamadı. Dosya bölümlerini daha detaylı analiz edin.")
            print("Binwalk kullanarak dosyayı analiz edebilirsiniz: 'binwalk firmware.bin'")
            print("Veya: 'binwalk -e firmware.bin' komutuyla içeriği çıkarmayı deneyebilirsiniz.")
            
        print("\nFirmware analizi tamamlandı. Çıkarılan veriler {} dizininde.".format(output_dir))
        
    except Exception as e:
        print("Hata: {}".format(e))

def analyze_extracted_files(input_dir):
    """Çıkarılan firmware dosyalarını inceler ve içerikleri hakkında bilgi verir"""
    try:
        print("Dizin içeriği inceleniyor: {}".format(input_dir))
        
        if not os.path.exists(input_dir):
            print("Hata: {} dizini bulunamadı!".format(input_dir))
            return
            
        # GZip dosyalarını ara
        gzip_files = []
        for file in os.listdir(input_dir):
            if file.startswith("decompressed_gzip_"):
                gzip_files.append(os.path.join(input_dir, file))
        
        if not gzip_files:
            print("GZip dosyaları bulunamadı!")
        else:
            print("\nToplam {} GZip dosyası bulundu:".format(len(gzip_files)))
            
            for gzip_file in gzip_files:
                file_size = os.path.getsize(gzip_file)
                print("\n[{}] - {} bytes".format(os.path.basename(gzip_file), file_size))
                
                # Dosya türünü tespit etmeye çalış
                try:
                    with open(gzip_file, 'rb') as f:
                        header = f.read(4096)  # İlk 4KB'ı oku
                        
                        # ELF dosyası mı?
                        if header.startswith(b'\x7fELF'):
                            print("  ✓ ELF çalıştırılabilir dosyası tespit edildi")
                        
                        # Kernel imajı mı?
                        elif b'Linux version ' in header:
                            version = re.search(rb'Linux version ([0-9\.\-a-z]+)', header)
                            if version:
                                print("  ✓ Linux Kernel imajı tespit edildi: {}".format(version.group(1).decode('utf-8', errors='replace')))
                            else:
                                print("  ✓ Linux Kernel imajı tespit edildi")
                        
                        # HTML veya XML mı?
                        elif b'<!DOCTYPE' in header or b'<html' in header:
                            print("  ✓ HTML/XML içeriği tespit edildi")
                        
                        # Shell script?
                        elif header.startswith(b'#!/bin/sh') or header.startswith(b'#!/bin/bash'):
                            print("  ✓ Shell script tespit edildi")
                        
                        # Metin dosyası gibi görünüyor mu?
                        elif b'\x00' not in header[:1000]:
                            # İlk 5 satırı göster
                            lines = header.split(b'\n')[:5]
                            print("  ✓ Metin dosyası gibi görünüyor. İlk 5 satır:")
                            for i, line in enumerate(lines):
                                try:
                                    print("    {}: {}".format(i+1, line.decode('utf-8', errors='replace')))
                                except:
                                    pass
                        else:
                            # İlk 32 byte'ı hexdump olarak göster
                            print("  ✓ Binary veri. İlk 32 byte:")
                            print("    " + ' '.join(['{:02x}'.format(b) for b in header[:32]]))
                except Exception as e:
                    print("    Error analyzing file: {}".format(e))
                
                # Bazı önemli kelimeleri ara
                try:
                    with open(gzip_file, 'rb') as f:
                        content = f.read()
                        
                    keywords = [
                        ('config', rb'[Cc][Oo][Nn][Ff][Ii][Gg]'), 
                        ('password', rb'[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]'),
                        ('username', rb'[Uu][Ss][Ee][Rr][Nn][Aa][Mm][Ee]'),
                        ('api', rb'[Aa][Pp][Ii]'),
                        ('miner', rb'[Mm][Ii][Nn][Ee][Rr]'),
                        ('ethash', rb'[Ee][Tt][Hh][Aa][Ss][Hh]'),
                        ('ethereum', rb'[Ee][Tt][Hh][Ee][Rr][Ee][Uu][Mm]'),
                        ('crypto', rb'[Cc][Rr][Yy][Pp][Tt][Oo]')
                    ]
                    
                    print("\n  Anahtar kelime taraması:")
                    for name, pattern in keywords:
                        matches = re.findall(pattern, content)
                        if matches:
                            print("    ✓ '{}' kelimesi {} kez bulundu".format(name, len(matches)))
                except Exception as e:
                    print("    Hata: {}".format(e))
        
        # strings.txt dosyasını incele
        strings_file = os.path.join(input_dir, "strings.txt")
        if os.path.exists(strings_file):
            print("\n[strings.txt] dosyasında önemli bilgiler:")
            try:
                interesting_patterns = {
                    'IP Adresleri': r'\b(?:\d{1,3}\.){3}\d{1,3}\b',
                    'URL': r'https?://[^\s"\']+',
                    'Email': r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
                    'Versiyon': r'[Vv]ersion\s*[:=]?\s*[0-9.]+',
                    'Tarih': r'\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b'
                }
                
                with open(strings_file, 'r', encoding='utf-8', errors='replace') as f:
                    content = f.read()
                
                for category, pattern in interesting_patterns.items():
                    matches = set(re.findall(pattern, content))
                    if matches:
                        print("\n  {}:".format(category))
                        for match in list(matches)[:5]:  # En fazla 5 eşleşme göster
                            print("    - {}".format(match))
                        if len(matches) > 5:
                            print("    ... ve {} daha".format(len(matches)-5))
            except Exception as e:
                print("  strings.txt incelenirken hata: {}".format(e))
        else:
            print("\nstrings.txt dosyası bulunamadı")
            
        print("\nDetaylı inceleme için:")
        print("1. Hex editör ile dosyaları açabilirsiniz (örn: HxD)")
        print("2. Linux sistemde 'binwalk' ile analiz yapabilirsiniz")
        print("3. 'file' komutu ile dosya türlerini tespit edebilirsiniz")
        print("4. ELF dosyaları için 'readelf -a' komutu kullanabilirsiniz")
        
    except Exception as e:
        print("Analiz sırasında hata: {}".format(e))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='BMU firmware dosyasını analiz et ve extract et')
    parser.add_argument('file', help='BMU firmware dosyası veya çıkarılmış binary dosya')
    parser.add_argument('-o', '--output', default='extracted', help='Çıktı dizini (varsayılan: ./extracted)')
    parser.add_argument('--firmware', action='store_true', help='Doğrudan firmware analizi yap')
    parser.add_argument('--analyze-extracted', action='store_true', help='Çıkarılmış dosyaları analiz et')
    
    args = parser.parse_args()
    
    if args.analyze_extracted:
        analyze_extracted_files(args.file)
    elif args.firmware:
        analyze_firmware(args.file, args.output)
    else:
        extract_bmu(args.file, args.output)
