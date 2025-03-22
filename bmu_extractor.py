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
        hexa = ' '.join([f'{b:02x}' for b in chunk])
        ascii_text = ''.join([chr(b) if 32 <= b <= 126 else '.' for b in chunk])
        result.append(f'{i:08x}  {hexa:<48}  |{ascii_text}|')
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
        print(f"Dosya Boyutu: {file_size} bytes")
        
        # İlk 100 byte'ı göster (header bilgileri için)
        print("\nDosya Başlığı (ilk 100 byte):")
        print(hexdump(data[:100]))
        
        # Magic number kontrolü (Antminer firmware imzası)
        # Not: Gerçek magic number değeri bilinmediğinden örnek olarak ilk 4 byte kontrol edildi
        magic = data[:4]
        print(f"\nMagic Number: {binascii.hexlify(magic).decode()}")

        # Firmware içeriği potansiyel olarak bir sıkıştırılmış TAR arşivi olabilir
        # gzip formatını deneme
        try:
            decompressed = zlib.decompress(data, 16+zlib.MAX_WBITS)
            tar_file = os.path.join(output_dir, 'extracted.tar')
            with open(tar_file, 'wb') as f:
                f.write(decompressed)
            print(f"\nGZip sıkıştırması kaldırıldı: {tar_file}")
            
            # TAR dosyasını açmayı dene
            try:
                tar = tarfile.open(tar_file)
                tar.extractall(path=output_dir)
                tar.close()
                print(f"TAR arşivi {output_dir} dizinine çıkarıldı.")
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
                print(f"Olası timestamp @ 0x{i:x}: {val} ({date_str})")
        
        # Binary dosyayı kaydet
        bin_path = os.path.join(output_dir, 'firmware.bin')
        with open(bin_path, 'wb') as f:
            f.write(data)
        print(f"\nOrijinal binary dosya kaydedildi: {bin_path}")
        
        print(f"\nAnaliz tamamlandı. Tüm çıkarılan dosyalar {output_dir} dizininde.")
    
    except Exception as e:
        print(f"Hata: {e}")

def analyze_firmware(firmware_file, output_dir):
    """Firmware binary dosyasını analiz edip içeriğini extract etme"""
    try:
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
            
        with open(firmware_file, 'rb') as f:
            data = f.read()
            
        file_size = len(data)
        print(f"Firmware Dosya Boyutu: {file_size} bytes")
        
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
                    print(f"0x{offset:08x}: {fs_type} imzası bulundu")
                    fs_found = True
                    
                    # SquashFS bölümünü çıkar
                    if signature in [b"hsqs", b"sqsh"]:
                        squashfs_file = os.path.join(output_dir, f"squashfs_at_{offset:08x}.bin")
                        with open(squashfs_file, 'wb') as f_out:
                            f_out.write(data[offset:])
                        print(f"SquashFS bölümü {squashfs_file} dosyasına kaydedildi.")
                        print("SquashFS içeriğini çıkarmak için: 'unsquashfs -d çıktı_dizini squashfs_dosyası' komutunu kullanabilirsiniz.")
                    
                    # JFFS2 bölümünü çıkar
                    elif signature == b"jffs2":
                        jffs2_file = os.path.join(output_dir, f"jffs2_at_{offset:08x}.bin")
                        with open(jffs2_file, 'wb') as f_out:
                            f_out.write(data[offset:])
                        print(f"JFFS2 bölümü {jffs2_file} dosyasına kaydedildi.")
                        print("JFFS2 içeriğini çıkarmak için: 'jefferson jffs2_dosyası -d çıktı_dizini' komutunu kullanabilirsiniz.")
                    
                    # GZip, BZip2, XZ sıkıştırılmış dosyaları çıkarmayı dene
                    elif signature in [b"\x1f\x8b\x08", b"BZh", b"\xfd\x37\x7a\x58\x5a\x00"]:
                        compressed_file = os.path.join(output_dir, f"compressed_at_{offset:08x}.bin")
                        with open(compressed_file, 'wb') as f_out:
                            f_out.write(data[offset:])
                        print(f"Sıkıştırılmış veri {compressed_file} dosyasına kaydedildi.")
                        
                        # GZip ise, açmayı dene
                        if signature == b"\x1f\x8b\x08":
                            try:
                                decompressed = zlib.decompress(data[offset:], 16+zlib.MAX_WBITS)
                                decompressed_file = os.path.join(output_dir, f"decompressed_gzip_{offset:08x}.bin")
                                with open(decompressed_file, 'wb') as f_out:
                                    f_out.write(decompressed)
                                print(f"GZip sıkıştırması açıldı: {decompressed_file}")
                            except:
                                print(f"GZip sıkıştırması açılamadı: {offset:08x}")
        
        # String'leri ara
        strings_file = os.path.join(output_dir, "strings.txt")
        with open(strings_file, 'w', encoding='utf-8') as f_out:
            ascii_chars = re.findall(b'[ -~]{5,}', data)
            for s in ascii_chars:
                try:
                    decoded = s.decode('utf-8', errors='replace')
                    f_out.write(f"{decoded}\n")
                except:
                    pass
        print(f"\nMetin içerikleri {strings_file} dosyasına kaydedildi.")

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
                print(f"0x{offset:08x}: {version}")
                version_found = True
        
        if not version_found:
            print("Versiyon bilgisi bulunamadı.")
        
        if not fs_found:
            print("\nBilinen dosya sistemi imzası bulunamadı. Dosya bölümlerini daha detaylı analiz edin.")
            print("Binwalk kullanarak dosyayı analiz edebilirsiniz: 'binwalk firmware.bin'")
            print("Veya: 'binwalk -e firmware.bin' komutuyla içeriği çıkarmayı deneyebilirsiniz.")
            
        print(f"\nFirmware analizi tamamlandı. Çıkarılan veriler {output_dir} dizininde.")
        
    except Exception as e:
        print(f"Hata: {e}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='BMU firmware dosyasını analiz et ve extract et')
    parser.add_argument('file', help='BMU firmware dosyası veya çıkarılmış binary dosya')
    parser.add_argument('-o', '--output', default='extracted', help='Çıktı dizini (varsayılan: ./extracted)')
    parser.add_argument('--firmware', action='store_true', help='Doğrudan firmware analizi yap')
    
    args = parser.parse_args()
    
    if args.firmware:
        analyze_firmware(args.file, args.output)
    else:
        extract_bmu(args.file, args.output)
