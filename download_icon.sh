#!/bin/bash

# Параметры: URL и имя приложения
url="$1"
app_name="$2"

# Папка для иконок
icon_dir="$(pwd)/icons"
mkdir -p "$icon_dir"
icon_path="$icon_dir/$app_name.png"

# Извлекаем домен из URL
domain=$(echo "$url" | sed -E 's|^https?://([^/]+).*|\1|')

# Массив URL иконок
favicon_urls=(
    "http://$domain/favicon.ico"
    "http://$domain/favicon.png"
    "http://$domain/favicon.svg"
    "http://$domain/favicon32.png"
    "http://$domain/apple-touch-icon.png"
)

# Временный файл
temp_icon="$icon_dir/temp_icon"

# Пробуем скачать иконку по очереди
for favicon_url in "${favicon_urls[@]}"; do
    echo "Пробуем скачать иконку с: $favicon_url" >&2
    if wget -q --timeout=10 --tries=1 "$favicon_url" -O "$temp_icon" && [ -s "$temp_icon" ]; then
        mv -f "$temp_icon" "$icon_path"
        echo "Иконка успешно скачана: $icon_path" >&2
        echo "$icon_path"
        exit 0
    else
        echo "Не удалось скачать: $favicon_url" >&2
        rm -f "$temp_icon"
    fi
done

# Если ничего не скачалось
echo "Не удалось скачать ни одну иконку для $app_name" >&2
echo ""
exit 1
