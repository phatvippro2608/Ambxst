# Hướng dẫn Cấu hình Cá nhân (Custom Environment & Utilities)

Tài liệu này lưu trữ thông tin về các cấu hình tuỳ chỉnh giao diện, máy in, quản lý giấc ngủ và cách khôi phục nhanh trên các máy cài Arch Linux mới.

---

## 1. Đồng bộ & Khôi phục Giao diện Dolphin & GTK
Toàn bộ cấu hình giao diện của **Dolphin** (trình quản lý file Qt6), **Kvantum** (engine vẽ theme), **Qt6ct** và **GTK File Picker** (cửa sổ chọn file hệ thống) được quản lý tự động qua script:
📂 Đường dẫn lưu cấu hình: `assets/dolphin/`
📜 Script quản lý: `scripts/sync_dolphin_config.sh`

### Các lệnh sử dụng:
* **Sao lưu (Backup)**: Chạy lệnh này để lưu các thiết lập hiện tại từ máy của bạn vào thư mục Git:
  ```bash
  ./scripts/sync_dolphin_config.sh backup
  ```
* **Khôi phục & Cài đặt máy mới (Restore)**: Tự động tải tất cả các thư viện liên quan, driver máy in, các gói hiển thị ảnh thu nhỏ (thumbnails), cập nhật bộ nhớ đệm hệ thống và sao chép cấu hình về đúng vị trí:
  ```bash
  ./scripts/sync_dolphin_config.sh restore
  ```

---

## 2. Danh sách các gói phần mềm được khôi phục tự động
Khi chạy lệnh `restore`, script sẽ cài đặt các gói sau:
1. **Giao diện & Icon**: `qt6ct`, `kvantum`, `kvantum-qt5`, `papirus-icon-theme`.
2. **Ảnh thu nhỏ (Thumbnails)**: `ffmpegthumbs` (video), `kdegraphics-thumbnailers` (PDF/graphics), `kimageformats` (các định dạng ảnh WebP/AVIF), `kdesdk-thumbnailers` (code/diffs).
3. **Tiện ích hệ thống & Máy in (Cups)**:
   * Trình quản lý in ấn: `cups`, `cups-filters`, `cups-pdf`, `system-config-printer`.
   * Trình điều khiển (Drivers): `hplip`, `foomatic-db-engine`, `libcups`, `libcupsfilters`, `libppd`.
4. **Hỗ trợ ứng dụng bên thứ 3**: `kio-fuse` (để ứng dụng ngoài mở được file trong Trash/SFTP của Dolphin).
5. **Định nghĩa file & Sửa lỗi mất icon WPS Office**: Gói AUR `wps-office-mime-cn`.

---

## 3. Cấu hình Chế độ Ngủ sâu (S3 Deep Sleep) - Chống hao pin
Mặc định Linux thường chạy chế độ ngủ `s2idle` làm laptop rất nhanh hết pin. Để bật chế độ ngủ sâu `deep` (S3 Suspend to RAM):

* **Kích hoạt tạm thời**:
  ```bash
  echo deep | sudo tee /sys/power/mem_sleep
  ```
* **Kích hoạt vĩnh viễn (Cho máy mới)**:
  Thêm tham số `mem_sleep_default=deep` vào tệp cấu hình bootloader.
  * Nếu dùng **systemd-boot** (như máy hiện tại), mở tệp boot entry tương ứng trong `/boot/loader/entries/` và thêm vào cuối dòng `options`:
    ```text
    options ... mem_sleep_default=deep
    ```
  * Nếu dùng **GRUB**, thêm vào dòng `GRUB_CMDLINE_LINUX_DEFAULT` trong `/etc/default/grub` rồi chạy `sudo update-grub`:
    ```text
    GRUB_CMDLINE_LINUX_DEFAULT="... mem_sleep_default=deep"
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

