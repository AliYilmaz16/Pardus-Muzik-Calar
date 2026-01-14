#!/bin/bash

# Pardus Müzik Oynatıcı - mpg123 GUI/TUI Arayüzü

# DEGISKENLER
PLAYLIST=()
SUAN_INDEX=0
DURUM="DURDURULDU"
SUAN_CALAN="Yok"
SURUCU="alsa"
BASLANGIC_ZAMANI=0
DURAKLATMA_ZAMANI=0
TOPLAM_DURAKLATMA=0
PROGRAM_ADI="Pardus Müzik Oynatıcı"
VERSION="1.0"
FIFO_FILE="/tmp/mpg123_fifo_$$"
MPG123_PID=""

# YARDIMCI FONKSIYONLAR

bagimlilik_kontrol() {
    local eksik=0
    
    if ! command -v mpg123 >/dev/null 2>&1; then
        echo "HATA: mpg123 yüklü değil!"
        echo "Kurulum için: sudo apt install mpg123"
        eksik=1
    fi
    
    if ! command -v yad >/dev/null 2>&1; then
        echo "UYARI: yad yüklü değil. GUI arayüzü çalışmayacak."
        echo "Kurulum için: sudo apt install yad"
    fi
    
    if ! command -v whiptail >/dev/null 2>&1; then
        echo "UYARI: whiptail yüklü değil. TUI arayüzü çalışmayacak."
        echo "Kurulum için: sudo apt install whiptail"
    fi
    
    return $eksik
}

sure_formatla() {
    local saniye=$1
    local dakika=$((saniye / 60))
    local kalan_saniye=$((saniye % 60))
    printf "%02d:%02d" $dakika $kalan_saniye
}

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
    sure_formatla $gecen
}

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
    MPG123_PID=$!
    
    DURUM="OYNATILIYOR"
    BASLANGIC_ZAMANI=$(date +%s)
    TOPLAM_DURAKLATMA=0
    DURAKLATMA_ZAMANI=0
    return 0
}

sonraki_sarki() {
    ((SUAN_INDEX++))
    [ "$SUAN_INDEX" -ge "${#PLAYLIST[@]}" ] && SUAN_INDEX=0
    muzik_baslat
}

onceki_sarki() {
    local gecen=$(gecen_sure_hesapla)
    local saniye=${gecen##*:}
    saniye=$((10#$saniye))
    local dakika=${gecen%%:*}
    dakika=$((10#$dakika))
    local toplam_saniye=$((dakika * 60 + saniye))
    
    if [ $toplam_saniye -gt 5 ]; then
        muzik_baslat
    else
        ((SUAN_INDEX--))
        [ $SUAN_INDEX -lt 0 ] && SUAN_INDEX=$((${#PLAYLIST[@]} - 1))
        muzik_baslat
    fi
}

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

muzik_durdur() {
    pkill -x mpg123 2>/dev/null
    DURUM="DURDURULDU"
    SUAN_CALAN="Yok"
    BASLANGIC_ZAMANI=0
    TOPLAM_DURAKLATMA=0
    DURAKLATMA_ZAMANI=0
}

listeye_ekle() {
    local dosya_yolu="$1"
    
    if [ -f "$dosya_yolu" ]; then
        for item in "${PLAYLIST[@]}"; do
            if [ "$item" = "$dosya_yolu" ]; then
                return 1
            fi
        done
        
        PLAYLIST+=("$dosya_yolu")
        return 0
    fi
    return 1
}

listeden_sil() {
    local index=$1
    if [ $index -ge 0 ] && [ $index -lt ${#PLAYLIST[@]} ]; then
        if [ $index -eq $SUAN_INDEX ]; then
            muzik_durdur
        fi
        
        PLAYLIST=("${PLAYLIST[@]:0:$index}" "${PLAYLIST[@]:$((index + 1))}")
        
        if [ $SUAN_INDEX -ge ${#PLAYLIST[@]} ] && [ ${#PLAYLIST[@]} -gt 0 ]; then
            SUAN_INDEX=$((${#PLAYLIST[@]} - 1))
        fi
        return 0
    fi
    return 1
}

# GUI FONKSIYONLARI

gui_listeye_ekle() {
    if ! command -v yad >/dev/null 2>&1; then
        return 1
    fi
    
    local SECILENLER
    SECILENLER=$(yad --file-selection \
        --multiple \
        --separator="|" \
        --title="Müzik Dosyaları Ekle" \
        --file-filter="MP3 Dosyaları|*.mp3" \
        --file-filter="Tüm Ses Dosyaları|*.mp3 *.ogg *.wav *.flac" \
        --file-filter="Tüm Dosyalar|*" \
        --width=800 --height=500 \
        --center)
    
    local yad_exit=$?
    
    if [ $yad_exit -ne 0 ] || [ -z "$SECILENLER" ]; then
        return 0
    fi
    
    local eklenen=0
    IFS='|' read -ra ADDR <<< "$SECILENLER"
    for dosya in "${ADDR[@]}"; do
        if listeye_ekle "$dosya"; then
            ((eklenen++))
        fi
    done
    
    return 0
}

gui_liste_goster() {
    if [ ${#PLAYLIST[@]} -eq 0 ]; then
        yad --info \
            --title="Çalma Listesi" \
            --text="Çalma listesi boş!" \
            --button="Tamam:0" \
            --width=300 \
            --center
        return
    fi
    
    local liste_data=""
    for i in "${!PLAYLIST[@]}"; do
        local isaret=""
        [ $i -eq $SUAN_INDEX ] && isaret="▶ "
        liste_data+="$i|${isaret}$(basename "${PLAYLIST[$i]}")|${PLAYLIST[$i]}\n"
    done
    
    local secim
    secim=$(echo -e "$liste_data" | yad --list \
        --title="Çalma Listesi (${#PLAYLIST[@]} şarkı)" \
        --column="No:HD" \
        --column="Şarkı" \
        --column="Yol:HD" \
        --width=600 \
        --height=400 \
        --center \
        --button="Çal:2" \
        --button="Sil:3" \
        --button="Kapat:0")
    
    local exit_code=$?
    
    case $exit_code in
        2)
            if [ -n "$secim" ]; then
                local index=$(echo "$secim" | cut -d'|' -f1)
                if [ -n "$index" ]; then
                    SUAN_INDEX=$index
                    muzik_baslat
                fi
            fi
            ;;
        3)
            if [ -n "$secim" ]; then
                local index=$(echo "$secim" | cut -d'|' -f1)
                if [ -n "$index" ]; then
                    listeden_sil $index
                fi
            fi
            ;;
    esac
}

gui_kontrol_paneli() {
    if ! command -v yad >/dev/null 2>&1; then
        echo "GUI için 'yad' gereklidir. sudo apt install yad"
        return 1
    fi
    
    export YAD_OPTIONS="--center"
    
    while true; do
        local gecen_sure=$(gecen_sure_hesapla)
        
        local durum_icon=""
        case $DURUM in
            "OYNATILIYOR") durum_icon="▶" ;;
            "DURAKLATILDI") durum_icon="⏸" ;;
            "DURDURULDU") durum_icon="⏹" ;;
        esac
        
        local liste_bilgi=""
        if [ ${#PLAYLIST[@]} -gt 0 ]; then
            liste_bilgi="[$((SUAN_INDEX+1))/${#PLAYLIST[@]}]"
        else
            liste_bilgi="[Boş]"
        fi
        
        local info_text="<span size='large'><b>$durum_icon $DURUM</b></span>\n\n"
        info_text+="<b>Şarkı:</b> $SUAN_CALAN\n"
        info_text+="<b>Süre:</b> $gecen_sure\n"
        info_text+="<b>Liste:</b> $liste_bilgi"
        
        yad --form \
            --title="$PROGRAM_ADI" \
            --text="$info_text" \
            --width=450 \
            --height=180 \
            --center \
            --no-focus \
            --timeout=1 \
            --timeout-indicator=bottom \
            --button="⏮ Önceki!go-previous:2" \
            --button="⏯ Oynat/Pause!media-playback-start:3" \
            --button="⏹ Stop!media-playback-stop:4" \
            --button="⏭ Sonraki!go-next:5" \
            --button="➕ Ekle!list-add:6" \
            --button="📋 Liste!view-list:7" \
            --button="❌ Çıkış!application-exit:1"
        
        local exit_code=$?
        
        case $exit_code in
            2) [ ${#PLAYLIST[@]} -gt 0 ] && onceki_sarki ;;
            3) [ "$DURUM" = "DURDURULDU" ] && muzik_baslat || muzik_duraklat_devam ;;
            4) muzik_durdur ;;
            5) [ ${#PLAYLIST[@]} -gt 0 ] && sonraki_sarki ;;
            6) gui_listeye_ekle ;;
            7) gui_liste_goster ;;
            1|252) break ;;
            70) [ "$DURUM" = "OYNATILIYOR" ] && ! pgrep -x mpg123 >/dev/null && sonraki_sarki ;;
        esac
    done
}

# TUI FONKSIYONLARI

tui_listeye_ekle() {
    if ! command -v whiptail >/dev/null 2>&1; then
        return 1
    fi
    
    local YOL
    YOL=$(whiptail --title "Dosya Ekle" \
        --inputbox "MP3 dosya yolunu girin:\n\nÖrnek: /home/kullanici/Muzik/sarki.mp3" 12 60 \
        "$HOME/" \
        3>&1 1>&2 2>&3)
    
    local exit_code=$?
    
    if [ $exit_code -ne 0 ] || [ -z "$YOL" ]; then
        return 0
    fi
    
    if [ -f "$YOL" ]; then
        if listeye_ekle "$YOL"; then
            whiptail --title "Başarılı" --msgbox "Dosya eklendi!\n\nToplam: ${#PLAYLIST[@]} şarkı" 8 50
        else
            whiptail --title "Uyarı" --msgbox "Dosya zaten listede!" 8 40
        fi
    else
        whiptail --title "Hata" --msgbox "Dosya bulunamadı!\n\n$YOL" 10 50
    fi
}

tui_liste_goster() {
    if [ ${#PLAYLIST[@]} -eq 0 ]; then
        whiptail --title "Uyarı" --msgbox "Çalma listesi boş!" 8 40
        return
    fi
    
    local liste_items=()
    for i in "${!PLAYLIST[@]}"; do
        local isaret=""
        [ $i -eq $SUAN_INDEX ] && isaret="▶ "
        liste_items+=("$i" "${isaret}$(basename "${PLAYLIST[$i]}")")
    done
    
    local secim
    secim=$(whiptail --title "Çalma Listesi" \
        --menu "Şarkı seçin (Enter ile çal):" \
        20 60 10 \
        "${liste_items[@]}" \
        3>&1 1>&2 2>&3)
    
    if [ -n "$secim" ]; then
        SUAN_INDEX=$secim
        muzik_baslat
    fi
}

tui_kontrol_paneli() {
    if ! command -v whiptail >/dev/null 2>&1; then
        echo "TUI için 'whiptail' gereklidir. sudo apt install whiptail"
        return 1
    fi
    
    while true; do
        local gecen_sure=$(gecen_sure_hesapla)
        
        local durum_text="Durum: $DURUM"
        [ "$DURUM" != "DURDURULDU" ] && durum_text+=" | Süre: $gecen_sure"
        durum_text+="\nŞarkı: $SUAN_CALAN"
        [ ${#PLAYLIST[@]} -gt 0 ] && durum_text+=" [$((SUAN_INDEX+1))/${#PLAYLIST[@]}]"
        
        local SECIM
        SECIM=$(whiptail --title "$PROGRAM_ADI - TUI" \
            --menu "$durum_text" 20 65 9 \
            "1" "⏯  Oynat / Restart" \
            "2" "⏸  Pause / Resume" \
            "3" "⏭  Sonraki Şarkı" \
            "4" "⏮  Önceki Şarkı" \
            "5" "⏹  Durdur" \
            "6" "➕ Dosya Ekle" \
            "7" "📋 Çalma Listesi" \
            "8" "🔄 Yenile" \
            "9" "❌ Geri" \
            3>&1 1>&2 2>&3)
        
        case "$SECIM" in
            1) muzik_baslat || whiptail --title "Uyarı" --msgbox "Çalma listesi boş!" 8 50 ;;
            2) [ "$DURUM" != "DURDURULDU" ] && muzik_duraklat_devam ;;
            3) [ ${#PLAYLIST[@]} -gt 0 ] && sonraki_sarki ;;
            4) [ ${#PLAYLIST[@]} -gt 0 ] && onceki_sarki ;;
            5) muzik_durdur ;;
            6) tui_listeye_ekle ;;
            7) tui_liste_goster ;;
            8) [ "$DURUM" = "OYNATILIYOR" ] && ! pgrep -x mpg123 >/dev/null && sonraki_sarki ;;
            9|"") break ;;
        esac
    done
}

# ANA MENU

ana_menu() {
    while true; do
        local ARAYUZ
        
        if command -v whiptail >/dev/null 2>&1; then
            ARAYUZ=$(whiptail --title "$PROGRAM_ADI v$VERSION" \
                --menu "Arayüz Seçin:" 15 50 3 \
                "G" "🖥️  Grafik Arayüz (YAD)" \
                "T" "💻 Terminal Arayüzü (TUI)" \
                "Q" "❌ Çıkış" \
                3>&1 1>&2 2>&3)
        else
            clear
            echo "=========================================="
            echo "  $PROGRAM_ADI v$VERSION"
            echo "=========================================="
            echo ""
            echo "Arayüz Seçin:"
            echo "  G - Grafik Arayüz (YAD)"
            echo "  T - Terminal Arayüzü (TUI)"
            echo "  Q - Çıkış"
            echo ""
            read -rp "Seçiminiz: " ARAYUZ
        fi
        
        case "$ARAYUZ" in
            G|g) gui_kontrol_paneli ;;
            T|t) tui_kontrol_paneli ;;
            Q|q|"") muzik_durdur; exit 0 ;;
            *) 
                if command -v whiptail >/dev/null 2>&1; then
                    whiptail --title "Hata" --msgbox "Geçersiz seçim!" 8 40
                else
                    echo "Geçersiz seçim!"
                    sleep 1
                fi
                ;;
        esac
    done
}

# PROGRAM BASLAT

main() {
    if ! bagimlilik_kontrol; then
        echo "Lütfen eksik bağımlılıkları kurun."
        exit 1
    fi
    
    trap 'muzik_durdur; exit 0' INT TERM
    ana_menu
}

main
