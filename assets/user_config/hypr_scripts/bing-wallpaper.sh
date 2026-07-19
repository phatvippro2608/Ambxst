#!/bin/bash

# 1. Tạo thư mục chứa ảnh (nếu chưa có)
DIR="$HOME/Pictures/Bing"
mkdir -p "$DIR"

# 2. Parse arguments
MODE="daily"
if [ "${1:-}" = "--random" ] || [ "${1:-}" = "-r" ]; then
    MODE="random"
fi

# 3. Gọi API của Bing
if [ "$MODE" = "random" ]; then
    # Lấy danh sách 8 ảnh gần đây và chọn ngẫu nhiên một ảnh
    BING_API="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=8&mkt=en-US"
    JSON_DATA=$(curl -s "$BING_API")
    # Chọn ngẫu nhiên index từ 0 đến 7
    RAND_IDX=$(( RANDOM % 8 ))
    IMG_PATH=$(echo "$JSON_DATA" | jq -r ".images[$RAND_IDX].url")
else
    # Lấy ảnh hôm nay (mặc định)
    BING_API="https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=1&mkt=en-US"
    IMG_PATH=$(curl -s "$BING_API" | jq -r '.images[0].url')
fi

if [ -z "$IMG_PATH" ] || [ "$IMG_PATH" = "null" ]; then
    echo "Lỗi: Không thể lấy thông tin ảnh từ Bing."
    exit 1
fi

# 4. Tạo link tải hoàn chỉnh và tên file
FULL_URL="https://www.bing.com$IMG_PATH"
# Tách tên file
IMG_NAME=$(echo "$IMG_PATH" | grep -o -E "OHR\.[a-zA-Z0-9_-]+_[a-zA-Z0-9-]+_1920x1080\.jpg" | head -n 1)
if [ -z "$IMG_NAME" ]; then
    IMG_NAME=$(echo "$IMG_PATH" | awk -F'id=' '{print $2}' | awk -F'&' '{print $1}')
fi
if [ -z "$IMG_NAME" ]; then
    IMG_NAME="bing_wallpaper_$(date +%Y%m%d_%H%M%S).jpg"
fi
SAVE_PATH="$DIR/$IMG_NAME"

# 5. Tải ảnh về nếu chưa có trong máy
if [ ! -f "$SAVE_PATH" ]; then
    echo "Đang tải ảnh: $IMG_NAME..."
    curl -s -o "$SAVE_PATH" "$FULL_URL"
fi

# 6. Thiết lập hình nền trong Ambxst (ghi đè vào file cache config)
CACHE_FILE="$HOME/.cache/ambxst/wallpapers.json"
if [ -f "$CACHE_FILE" ]; then
    echo "Cập nhật hình nền Ambxst: $SAVE_PATH"
    # Dùng jq để cập nhật thuộc tính currentWall
    jq --arg wall "$SAVE_PATH" '.currentWall = $wall' "$CACHE_FILE" > "${CACHE_FILE}.tmp" && mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
else
    echo "Không tìm thấy file cấu hình Ambxst, thiết lập qua swaybg (fallback)..."
    killall swaybg 2>/dev/null || true
    swaybg -i "$SAVE_PATH" -m fill &
fi
