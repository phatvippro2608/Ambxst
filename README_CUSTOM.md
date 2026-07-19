# Hướng dẫn Cấu hình Cá nhân (Custom Environment & Utilities)

Tài liệu này lưu trữ thông tin về các cấu hình tuỳ chỉnh giao diện, máy in, quản lý giấc ngủ và cách khôi phục nhanh trên các máy cài Arch Linux mới.

---

## 1. Đồng bộ & Khôi phục Toàn bộ Cấu hình Người dùng (User Environment Sync)
Toàn bộ cấu hình hệ thống bao gồm **Ambxst Shell**, **Hyprland** (`hyprland.conf`), **Dolphin** (trình quản lý file Qt6), **Kvantum**, **Qt6ct**, **GTK File Picker**, **Bộ gõ Fcitx5**, **Terminal Kitty**, **Script ảnh nền Bing**, và **Máy in CUPS** được quản lý tự động qua script:
📂 Đường dẫn lưu cấu hình: `assets/user_config/`
📜 Script quản lý chính: `scripts/sync_user_config.sh` (hoặc `scripts/sync_dolphin_config.sh`)

### Các lệnh sử dụng:
* **Sao lưu (Backup)**: Chạy lệnh này để lưu toàn bộ các thiết lập hiện tại từ máy của bạn vào thư mục Git:
  ```bash
  ./scripts/sync_user_config.sh backup
  ```
* **Khôi phục & Cài đặt máy mới (Restore)**: Tự động cài các gói phần mềm cần thiết, driver máy in, ảnh thu nhỏ, khôi phục cấu hình cá nhân và nạp lại hệ thống:
  ```bash
  ./scripts/sync_user_config.sh restore
  ```

---

## 2. Danh sách các gói phần mềm & Cấu hình được khôi phục tự động
Khi chạy lệnh `restore`, script sẽ cài đặt và khôi phục toàn bộ các phần sau:
1. **Giao diện & Icon**: `qt6ct`, `kvantum`, `kvantum-qt5`, `papirus-icon-theme`.
2. **Bộ gõ Tiếng Việt & Terminal**: `fcitx5`, `fcitx5-gtk`, `fcitx5-qt`, `fcitx5-unikey`, `kitty` (khôi phục toàn bộ cài đặt phím gõ & theme Terminal).
3. **Ảnh thu nhỏ (Thumbnails)**: `ffmpegthumbs` (video), `kdegraphics-thumbnailers` (PDF/graphics), `kimageformats` (các định dạng ảnh WebP/AVIF), `kdesdk-thumbnailers` (code/diffs).
4. **Tiện ích hệ thống & Máy in (Cups)**:
   * Trình quản lý in ấn: `cups`, `cups-filters`, `cups-pdf`, `system-config-printer`.
   * Trình điều khiển (Drivers): `hplip`, `foomatic-db-engine`, `libcups`, `libcupsfilters`, `libppd`.
5. **Hỗ trợ ứng dụng bên thứ 3**: `kio-fuse` (để ứng dụng ngoài mở được file trong Trash/SFTP của Dolphin).
6. **Định nghĩa file & Sửa lỗi mất icon WPS Office**: Gói AUR `wps-office-mime-cn`.
7. **Toàn bộ cấu hình tinh chỉnh Ambxst**:
   * Tất cả file cấu hình JSON (`dock.json`, `bar.json`, `theme.json`, `weather.json`, `desktop.json`, `lockscreen.json`, `notch.json`, `overview.json`, `workspaces.json`, `binds.json`).
   * **Script tự động tải ảnh nền Bing**: `~/.config/hypr/scripts/bing-wallpaper.sh`.
   * Lịch và Token Google Calendar, Preset đang kích hoạt (`active_preset`).

---

## 3. Cấu hình Chế độ Ngủ sâu (S3 Deep Sleep) - Chống hao pin
Mặc định Linux thường chạy chế độ ngủ `s2idle` làm laptop rất nhanh hết pin. Để bật chế độ ngủ sâu `deep` (S3 Suspend to RAM):

* **Kích hoạt tự động 1-Click (Cho máy mới)**:
  ```bash
  ./scripts/setup_deep_sleep.sh
  ```
  *(Script sẽ tự phát hiện bạn dùng systemd-boot hay GRUB để chèn tham số `mem_sleep_default=deep` tương ứng)*.

* **Kích hoạt thủ công**:
  ```bash
  echo deep | sudo tee /sys/power/mem_sleep
  ```

---

## 4. Luật Định vị Cửa sổ Chọn file (Hyprland Window Rules)
Để cửa sổ chọn file hệ thống (`Xdg-desktop-portal-gtk`) tự động nổi lên, căn giữa màn hình và có kích thước vừa vặn thay vì bị lệch hoặc tràn màn hình, hãy thêm dòng sau vào `/home/dev/.config/hypr/hyprland.conf`:

```ini
# File / Folder Picker Rules (Cú pháp mới của Hyprland)
windowrule = float 1, match:class ^([Xx]dg-desktop-portal-gtk)$
windowrule = size 900 650, match:class ^([Xx]dg-desktop-portal-gtk)$
windowrule = center 1, match:class ^([Xx]dg-desktop-portal-gtk)$

---

## 5. Sao lưu & Khôi phục Cấu hình Máy in (CUPS & PPD Drivers)
Cấu hình máy in hệ thống được tích hợp trực tiếp vào script đồng bộ chính để bạn không bị mất danh sách máy in đã cài đặt:

* **Tự động sao lưu**: Khi chạy lệnh backup, script sẽ sao lưu danh sách máy in (`printers.conf`) và các driver PPD tương ứng của từng máy in vào thư mục Git:
  ```bash
  ./scripts/sync_dolphin_config.sh backup
  ```
* **Tự động khôi phục**: Khi chạy lệnh restore trên máy mới, script sẽ tự động chép trả lại cấu hình, phân quyền chuẩn hệ thống (`root:cups`), khôi phục thư mục driver PPD và tự động restart service `cups` để áp dụng cấu hình máy in ngay lập tức:
  ```bash
  ./scripts/sync_dolphin_config.sh restore
  ```

---

## 6. Hướng dẫn Cài mới & Cập nhật Ambxst từ Upstream

### 6.1. Hướng dẫn cài đặt trên máy mới tinh (Clean Install)
Để cài đặt Ambxst đã tích hợp toàn bộ các thay đổi tùy biến cá nhân của bạn trên một máy mới, hãy chạy các lệnh sau theo thứ tự:

1. **Clone trực tiếp Fork của bạn**:
   ```bash
   git clone https://github.com/phatvippro2608/ambxst.git ~/.local/src/ambxst
   ```
2. **Cài đặt Dependencies & Hyprland**:
   ```bash
   cd ~/.local/src/ambxst
   ./install.sh
   ambxst install hyprland
   ```
3. **Khôi phục cấu hình Dolphin & Máy in**:
   ```bash
   ./scripts/sync_dolphin_config.sh restore
   ```
4. **Khởi động shell**:
   ```bash
   ambxst & disown
   ```

### 6.2. Hướng dẫn cập nhật tính năng mới từ tác giả gốc (Upstream Update)
Khi tác giả gốc (`Axenide/Ambxst`) ra bản vá lỗi hoặc tính năng mới, hãy chạy các lệnh sau tại thư mục nguồn để kéo code mới về và gộp (merge) mà không làm mất các thay đổi tùy biến cá nhân:

1. **Thêm remote upstream (chỉ cần làm một lần duy nhất)**:
   ```bash
   cd ~/.local/src/ambxst
   git remote add upstream https://github.com/Axenide/Ambxst.git || true
   ```
2. **Lấy code mới nhất từ Upstream**:
   ```bash
   git fetch upstream
   ```
3. **Trộn code mới vào nhánh chính của bạn**:
   ```bash
   git merge upstream/main
   ```
4. **Xử lý xung đột (nếu có)**:
   Nếu Git báo xung đột (Merge Conflict), hãy mở thư mục dự án trong trình soạn thảo (VS Code), chọn giữ cấu hình cũ hoặc mới đối với những dòng bị đỏ, sau đó đánh dấu đã giải quyết và commit:
   ```bash
   git add <tên_file_xung_đột>
   git commit -m "merge: resolve conflicts with upstream"
   ```
5. **Nạp lại giao diện**:
   ```bash
   ambxst reload
   ```

---

## 7. Phím tắt Chuyển Workspace Tiện lợi (Ergonomic & Infinite Workspaces)
Để chuyển Workspace dễ dàng bằng 1 tay (không bị căng cơ khi tay phải đang giữ chuột kéo file):

* **Dùng chuột + Phím Super (Cực nhanh khi đang kéo file)**:
  * `Super + Con lăn chuột xuống/lên`: Chuyển sang Workspace tiếp theo / trước đó.
  * `Super + Shift + Con lăn chuột`: Chuyển cửa sổ đang chọn sang Workspace tiếp theo / trước đó.
* **Dùng 1 tay trái trên bàn phím (Chống căng cơ)**:
  * `Super + Tab`: Chuyển sang Workspace tiếp theo.
  * `Super + Shift + Tab`: Chuyển sang Workspace trước đó.
  * `Super + ~ (Phím dấy ngã)`: Chuyển nhanh về Workspace vừa dùng trước đó.
  * `Super + Mũi tên Trái/Phải`: Chuyển Workspace theo hướng mũi tên.
* **Hỗ trợ Workspace lớn hơn 10**:
  * `Super + Alt + 1..5`: Chuyển nhanh tới Workspace 11, 12, 13, 14, 15.
  * `Super + Alt + Shift + 1..5`: Di chuyển cửa sổ tới Workspace 11..15.

