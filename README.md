# Pardus Müzik Oynatıcı

Pardus Linux için geliştirilmiş hem grafik hem de terminal arayüzü sunan modern ve kullanışlı bir müzik çalar uygulaması.

## Kılavuz Videosu

Detaylı kullanım kılavuzu için YouTube videomuzu izleyebilirsiniz:

[[Kılavuz Videosu]](https://www.youtube.com/watch?v=QVcJiZsK1GY)

## Özellikler

- **Grafik Arayüz (GUI)**: YAD kullanarak modern ve kullanıcı dostu arayüz
- **Terminal Arayüzü (TUI)**: Whiptail ile terminal tabanlı menü sistemi
- **Tek Dosya**: Tüm özellikler tek bir bash script içinde
- **Gerçek Zamanlı Süre Gösterimi**: Şarkının kaçıncı saniyede olduğunu gösterir
- **Otomatik Yenileme**: GUI arayüzü her saniye otomatik güncellenir
- **Çalma Listesi Yönetimi**: Şarkı ekleme, silme ve listeden seçerek çalma
- **Oynatma Kontrolleri**: Oynat, duraklat, durdur, sonraki/önceki şarkı
- **Otomatik Geçiş**: Şarkı bittiğinde otomatik sonraki şarkıya geçer
- **Akıllı Önceki Butonu**: 5 saniyeden az geçtiyse önceki şarkıya, fazlaysa başa sarar

## Ekran Görüntüleri

### Arayüz Seçim Menüsü
![Arayüz Seçimi](screenshots/arayuz-secimi.png)

### GUI Kontrol Paneli
![GUI Kontrol Paneli](screenshots/gui-panel.png)

### GUI Dosya Ekleme
![Dosya Ekleme](screenshots/gui-ekle.png)

### GUI Çalma Listesi
![Çalma Listesi](screenshots/gui-liste.png)

### TUI Menüsü
![TUI Menüsü](screenshots/tui-menu.png)

## Gereksinimler

Bu scriptin çalışması için aşağıdaki paketlerin yüklü olması gerekmektedir:

| Paket | Açıklama | Zorunlu |
|-------|----------|---------|
| `mpg123` | MP3 dosyalarını çalmak için | ✅ Evet |
| `yad` | Grafik arayüz için | ⚠️ GUI için gerekli |
| `whiptail` | Terminal arayüzü için | ⚠️ TUI için gerekli |

## Kurulum

### Pardus için Tek Komut

```bash
sudo apt update && sudo apt install -y mpg123 yad whiptail
```

### Projeyi İndirme

```bash
git clone https://github.com/KULLANICI_ADI/pardus-muzik-oynatici.git
cd pardus-muzik-oynatici
chmod +x mpg123-oynatici.sh
```

### Çalıştırma

```bash
./mpg123-oynatici.sh
```

Sistem genelinde kullanmak için:

```bash
sudo cp mpg123-oynatici.sh /usr/local/bin/pardus-oynatici
pardus-oynatici
```

## Kullanım

### Başlangıç

Scripti çalıştırdığınızda önce arayüz seçim menüsü açılır:

- **G**: Grafik Arayüz (YAD)
- **T**: Terminal Arayüzü (TUI)
- **Q**: Çıkış

### Grafik Arayüz (GUI) Kullanımı

1. Ana menüden **G** seçeneğini seçin
2. Açılan pencerede şu kontroller bulunur:

| Buton | İşlev |
|-------|-------|
| ⏮ Önceki | Önceki şarkıya geç (5 sn içindeyse başa sar) |
| ⏯ Oynat/Pause | Oynatmayı başlat veya duraklat |
| ⏹ Stop | Çalmayı tamamen durdur |
| ⏭ Sonraki | Sonraki şarkıya geç |
| ➕ Ekle | Yeni MP3 dosyaları ekle |
| 📋 Liste | Çalma listesini görüntüle/yönet |
| ❌ Çıkış | Ana menüye dön |

3. **Şarkı Ekleme**: "Ekle" butonuna tıklayarak dosya seçici penceresinden birden fazla MP3 dosyası seçebilirsiniz.

4. **Çalma Listesi**: "Liste" butonundan şarkıları görebilir, seçip çalabilir veya silebilirsiniz.

### Terminal Arayüzü (TUI) Kullanımı

1. Ana menüden **T** seçeneğini seçin
2. Menüden istediğiniz işlemi seçin:

| Seçenek | İşlev |
|---------|-------|
| 1 | Oynat / Restart |
| 2 | Pause / Resume |
| 3 | Sonraki Şarkı |
| 4 | Önceki Şarkı |
| 5 | Durdur |
| 6 | Dosya Ekle |
| 7 | Çalma Listesi |
| 8 | Yenile (Süreyi güncelle) |
| 9 | Geri |

3. **Şarkı Ekleme**: Seçenek 6'yı seçip MP3 dosyasının tam yolunu girin.

## Scriptten Kod Bölümleri

### Süre Hesaplama Fonksiyonu

Script, çalan şarkının süresini gerçek zamanlı hesaplar:

```bash
gecen_sure_hesapla() {
    if [ "$DURUM" = "DURDURULDU" ] || [ "$BASLANGIC_ZAMANI" -eq 0 ]; then
        echo "00:00"
        return
    fi
    
    local simdi=$(date +%s)
    local gecen=0
    
    if [ "$DURUM" = "DURAKLATILDI" ]; then
        gecen=$((DURAKLATMA_ZAMANI - BASLANGIC_ZAMANI - TOPLAM_DURAKLATMA))
    else
        gecen=$((simdi - BASLANGIC_ZAMANI - TOPLAM_DURAKLATMA))
    fi
    
    [ $gecen -lt 0 ] && gecen=0
    printf "%02d:%02d" $((gecen / 60)) $((gecen % 60))
}
```

Bu fonksiyon:
- Duraklatma süresini doğru hesaplar
- MM:SS formatında süre döndürür
- Negatif değerleri engeller

### Müzik Başlatma Fonksiyonu

```bash
muzik_baslat() {
    pkill -x mpg123 2>/dev/null
    
    if [ ${#PLAYLIST[@]} -eq 0 ]; then
        return 1
    fi
    
    DOSYA_YOLU="${PLAYLIST[$SUAN_INDEX]}"
    
    if [ ! -f "$DOSYA_YOLU" ]; then
        return 1
    fi
    
    SUAN_CALAN=$(basename "$DOSYA_YOLU")
    mpg123 -q "$DOSYA_YOLU" >/dev/null 2>&1 &
    
    DURUM="OYNATILIYOR"
    BASLANGIC_ZAMANI=$(date +%s)
    TOPLAM_DURAKLATMA=0
    return 0
}
```

Bu fonksiyon:
- Önceki çalma işlemini durdurur
- Çalma listesi ve dosya kontrolü yapar
- `mpg123` ile arka planda çalar
- Süre değişkenlerini sıfırlar

### Duraklat/Devam Et Fonksiyonu

```bash
muzik_duraklat_devam() {
    if pgrep -x mpg123 >/dev/null; then
        if [ "$DURUM" = "OYNATILIYOR" ]; then
            pkill -STOP -x mpg123 2>/dev/null
            DURUM="DURAKLATILDI"
            DURAKLATMA_ZAMANI=$(date +%s)
        else
            pkill -CONT -x mpg123 2>/dev/null
            DURUM="OYNATILIYOR"
            local simdi=$(date +%s)
            TOPLAM_DURAKLATMA=$((TOPLAM_DURAKLATMA + simdi - DURAKLATMA_ZAMANI))
        fi
    fi
}
```

Bu fonksiyon:
- `STOP` sinyali ile duraklatır
- `CONT` sinyali ile devam ettirir
- Duraklatma süresini toplam süreye ekler

### GUI Kontrol Paneli (Otomatik Yenileme)

```bash
gui_kontrol_paneli() {
    while true; do
        local gecen_sure=$(gecen_sure_hesapla)
        
        yad --form \
            --title="$PROGRAM_ADI" \
            --text="<b>$durum_icon $DURUM</b>\n\nŞarkı: $SUAN_CALAN\nSüre: $gecen_sure\nListe: $liste_bilgi" \
            --timeout=1 \
            --timeout-indicator=bottom \
            --button="⏮ Önceki:2" \
            --button="⏯ Oynat/Pause:3" \
            # ... diğer butonlar
        
        case $exit_code in
            70) # Timeout - otomatik yenileme
                if [ "$DURUM" = "OYNATILIYOR" ] && ! pgrep -x mpg123 >/dev/null; then
                    sonraki_sarki  # Şarkı bitti, sonrakine geç
                fi
                ;;
            # ... diğer durumlar
        esac
    done
}
```

Bu fonksiyon:
- Her saniye otomatik yenilenir (`--timeout=1`)
- Süre ve durum bilgilerini günceller
- Şarkı bittiğinde otomatik sonrakine geçer

## Değişkenler

Script içinde kullanılan ana değişkenler:

| Değişken | Açıklama |
|----------|----------|
| `PLAYLIST` | Şarkı dosya yollarını tutan dizi |
| `SUAN_INDEX` | Çalınan şarkının indeksi |
| `DURUM` | Oynatıcının durumu (OYNATILIYOR, DURAKLATILDI, DURDURULDU) |
| `SUAN_CALAN` | Şu an çalan şarkının adı |
| `BASLANGIC_ZAMANI` | Şarkının başlama zamanı (Unix timestamp) |
| `DURAKLATMA_ZAMANI` | Duraklatma anının zamanı |
| `TOPLAM_DURAKLATMA` | Toplam duraklatma süresi (saniye) |

## Teknik Detaylar

- **Platform:** Pardus Linux
- **Dil:** Bash Script
- **UI Kütüphaneleri:** YAD (GTK+), Whiptail (ncurses)
- **Ses Motoru:** mpg123
- **Desteklenen Format:** MP3, OGG, WAV

## 🇹🇷 Pardus Uyumluluğu

Bu araç özellikle Pardus işletim sistemi için optimize edilmiştir ve Pardus 23.x sürümüyle tam uyumludur. Tüm bağımlılıklar Pardus'un varsayılan paket depolarından kolayca kurulabilir.

## Notlar

- Script sadece MP3 formatını tam destekler
- Çalma listesi oturum boyunca bellekte tutulur (script kapatıldığında sıfırlanır)
- GUI arayüzü her saniye otomatik yenilenir
- Önceki şarkıya geçerken şarkı 5 saniyeden az çalındıysa başa sarılır

## Sorun Giderme

### Ses Çıkmıyor

```bash
# ALSA ses sistemini kontrol edin
alsamixer

# Ses seviyesini kontrol edin
amixer
```

### YAD Kurulu Değil

```bash
sudo apt install yad
```

### mpg123 Bulunamıyor

```bash
sudo apt install mpg123
```

### Script Çalışmıyor

```bash
chmod +x mpg123-oynatici.sh
```

## Geliştirici Notları

Bu proje Pardus için **Linux Araçları ve Kabuk Programlama** dersi kapsamında geliştirilmiştir. Projede kullanılan temel kavramlar:

- Bash scripting ve fonksiyonlar
- Koşullu ifadeler (if-else, case)
- Döngüler (while, for)
- GUI-TUI arayüzleri (YAD, Whiptail)
- Sinyal yönetimi (STOP, CONT, trap)
- Süreç kontrolü (pgrep, pkill)
- Zaman hesaplama ve formatlama

## Geliştirici

**[Ali Yılmaz]**  

---

**Not:** Bu proje Pardus Linux üzerinde test edilmiştir ve tam uyumludur.
