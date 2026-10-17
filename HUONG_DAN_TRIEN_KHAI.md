# Hướng dẫn triển khai (Deploy) – Hệ thống xây dựng giá DVKT tỉnh Vĩnh Long

Hệ thống gồm một máy chủ Node.js (API + giao diện) và một file CSDL SQLite. Triển khai bằng Docker, tự cấp HTTPS bằng Caddy.

## Mục lục
1. Chạy thử trên máy cá nhân
2. Đưa mã nguồn lên GitHub
3. Tạo máy chủ (DigitalOcean hoặc Hostinger VPS)
4. Cài đặt máy chủ và chạy hệ thống
5. Nhập dữ liệu từ file Excel cũ
6. Tự động cập nhật khi sửa code (GitHub Actions)
7. Sao lưu và khôi phục
8. Bảo mật – danh sách kiểm tra trước khi mở cho đơn vị dùng
9. Vận hành hằng ngày và xử lý sự cố

---

## 1. Chạy thử trên máy cá nhân

Cần cài [Node.js](https://nodejs.org) bản 22.13 trở lên (khuyên dùng 24).

```bash
npm install
npm run import -- "C:\duong-dan\DVKT2_DANG CHAY.xlsx"
```

Chạy server (PowerShell trên Windows):

```powershell
$env:ADMIN_PASSWORD = "mat-khau-quan-tri-cua-ban"
$env:CPQL_APP_URL = "https://script.google.com/macros/s/.../exec"
npm start
```

Mở trình duyệt: <http://localhost:8000>

Vì phần lớn đơn vị đang ở trạng thái **Đã khóa**, để thử nhập liệu hãy mở khóa một đơn vị và đặt Token thử:

```bash
node scripts/admin.mjs unlock BV011
node scripts/admin.mjs set-token BV011 matkhauthu123
```

Chạy bộ kiểm thử tự động (dùng bản sao CSDL, không ảnh hưởng dữ liệu thật):

```bash
npm test
```

## 2. Đưa mã nguồn lên GitHub

1. Tạo tài khoản và một repository **Private** tại <https://github.com/new> (ví dụ `dvkt-vinhlong`). Không tích "Add README".
2. Cài [Git](https://git-scm.com/downloads) rồi chạy trong thư mục dự án:

```bash
git init
git add .
git commit -m "Chuyển hệ thống sang Node.js"
git branch -M main
git remote add origin https://github.com/<tai-khoan>/dvkt-vinhlong.git
git push -u origin main
```

File `.gitignore` đã loại `data/` (CSDL chứa Token và thông tin người dùng) và `.env` (mật khẩu), nên chúng **không** bị đưa lên GitHub. Tuyệt đối không bỏ hai mục này khỏi `.gitignore`.

## 3. Tạo máy chủ

Cấu hình đề xuất: **2 vCPU, 2–4 GB RAM, 50 GB SSD, Ubuntu 24.04 LTS**, đặt tại Singapore.

**DigitalOcean:** Create → Droplets → Region *Singapore* → Image *Ubuntu 24.04* → Basic, Regular SSD (khoảng 12–18 USD/tháng, cấu hình 2 GB RAM) → Authentication *SSH Key* (khuyên dùng) → Create. Ghi lại địa chỉ IP.

**Hostinger VPS:** chọn gói KVM 2 (hoặc tương đương) → hệ điều hành Ubuntu 24.04 → vị trí Singapore → ghi lại địa chỉ IP.

Trỏ tên miền: tại nơi quản lý tên miền, tạo bản ghi **A** cho `giadvkt.example.vn` trỏ về IP máy chủ. Chờ vài phút đến vài giờ để DNS cập nhật. Cần tên miền thật để có HTTPS (nếu chưa có, xin tên miền con từ Sở/Trung tâm CNTT).

## 4. Cài đặt máy chủ và chạy hệ thống

Kết nối SSH (Windows: dùng PowerShell hoặc PuTTY):

```bash
ssh root@IP_MAY_CHU
```

Cài Docker và mở tường lửa:

```bash
curl -fsSL https://get.docker.com | sh
ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw --force enable
```

Tải mã nguồn (repository Private cần deploy key – xem mục 6; lần đầu có thể dùng `git clone` với token cá nhân):

```bash
mkdir -p /opt && cd /opt
git clone https://github.com/<tai-khoan>/dvkt-vinhlong.git dvkt
cd dvkt
cp .env.example .env
nano .env        # điền DOMAIN, ADMIN_PASSWORD (chuỗi dài, khó đoán), CPQL_APP_URL
docker compose up -d --build
```

Kiểm tra:

```bash
docker compose ps
docker compose logs -f app
```

Truy cập `https://giadvkt.example.vn`. Caddy tự lấy chứng chỉ HTTPS lần đầu (mất khoảng 1 phút).

## 5. Nhập dữ liệu từ file Excel cũ

Từ máy cá nhân, gửi file Excel lên máy chủ:

```bash
scp "DVKT2_DANG CHAY.xlsx" root@IP_MAY_CHU:/opt/dvkt/dvkt.xlsx
```

Trên máy chủ:

```bash
cd /opt/dvkt
docker compose cp dvkt.xlsx app:/tmp/dvkt.xlsx
docker compose exec app node --no-warnings scripts/import-excel.mjs /tmp/dvkt.xlsx
docker compose exec app rm /tmp/dvkt.xlsx && rm dvkt.xlsx
```

Kết quả mong đợi: `Đơn vị: 168`, `Lần gửi (lịch sử): 487`, danh mục PL1–PL5.

Lưu ý quan trọng:
- Token của từng đơn vị được **mã hóa một chiều** khi nhập, không còn lưu dạng chữ thường. Đơn vị vẫn dùng đúng Token cũ.
- Lệnh nhập **xóa và nạp lại** danh sách đơn vị, danh mục và lịch sử các lần gửi. Chỉ chạy một lần lúc chuyển hệ thống. Không chạy lại sau khi đơn vị đã nộp báo cáo trên hệ thống mới.
- Link Google Drive/Sheet của các phiên cũ vẫn được giữ và hiển thị ở mục Tra cứu. Phiên nộp trên hệ thống mới sẽ tải báo cáo `.xlsx` trực tiếp.

## 6. Tự động cập nhật khi sửa code (GitHub Actions)

Quy trình: bạn đẩy code lên nhánh `main` → GitHub chạy kiểm thử → tự đăng nhập máy chủ, `git pull` và dựng lại container (file `.github/workflows/deploy.yml`).

Cấu hình một lần:

1. Trên máy chủ, tạo khóa triển khai (deploy key) để máy chủ tải được repository Private:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/dvkt_deploy -N ""
   cat ~/.ssh/dvkt_deploy.pub
   ```
   GitHub → repository → Settings → Deploy keys → Add deploy key → dán nội dung khóa công khai (chỉ cấp quyền đọc). Trên máy chủ đổi remote sang SSH: `git remote set-url origin git@github.com:<tai-khoan>/dvkt-vinhlong.git` và thêm vào `~/.ssh/config` mục `Host github.com` với `IdentityFile ~/.ssh/dvkt_deploy`.
2. Tạo khóa riêng cho GitHub Actions: `ssh-keygen -t ed25519 -f ~/.ssh/gha -N ""`, thêm `~/.ssh/gha.pub` vào `~/.ssh/authorized_keys` của máy chủ.
3. GitHub → Settings → Secrets and variables → Actions → New repository secret:
   - `VPS_HOST`: địa chỉ IP máy chủ
   - `VPS_USER`: `root` (hoặc tài khoản triển khai)
   - `VPS_SSH_KEY`: toàn bộ nội dung file `~/.ssh/gha` (khóa **riêng**)

Từ đó mỗi lần `git push` lên `main`, hệ thống tự cập nhật. Dữ liệu nằm trong volume Docker nên **không bị mất** khi cập nhật.

## 7. Sao lưu và khôi phục

Toàn bộ dữ liệu: CSDL `dvkt.db` và thư mục `files/` (hồ sơ đính kèm) trong volume `dvkt-data`.

Sao lưu CSDL (an toàn khi hệ thống đang chạy):

```bash
docker compose exec app node --no-warnings scripts/admin.mjs backup
```

Sao lưu toàn bộ dữ liệu ra file nén:

```bash
docker run --rm -v dvkt_dvkt-data:/data -v /root/backup:/backup alpine tar czf /backup/dvkt-$(date +%F).tgz -C /data .
```

Đặt lịch chạy mỗi đêm bằng `crontab -e`:

```
0 2 * * * cd /opt/dvkt && docker run --rm -v dvkt_dvkt-data:/data -v /root/backup:/backup alpine tar czf /backup/dvkt-$(date +\%F).tgz -C /data . && find /root/backup -name 'dvkt-*.tgz' -mtime +30 -delete
```

Tên volume có thể khác tên thư mục; kiểm tra bằng `docker volume ls`. Hãy **copy thư mục `/root/backup` về nơi khác** (máy cá nhân, ổ đĩa ngoài) hằng tuần, hoặc bật tính năng backup/snapshot của nhà cung cấp máy chủ.

Khôi phục: dừng hệ thống (`docker compose stop app`), giải nén file `.tgz` vào volume, rồi `docker compose start app`.

## 8. Bảo mật – kiểm tra trước khi mở cho đơn vị dùng

- [ ] Đã đặt `ADMIN_PASSWORD` mới, dài và khó đoán (mật khẩu cũ `SYT@2026` đã từng nằm trong mã nguồn công khai, **không dùng lại**).
- [ ] Repository GitHub ở chế độ **Private**; `.env` và `data/` không nằm trong repository (`git status` phải sạch).
- [ ] Truy cập qua `https://` (có ổ khóa).
- [ ] Tường lửa chỉ mở cổng 22, 80, 443.
- [ ] Tài khoản GitHub bật xác thực hai lớp (2FA).
- [ ] Đăng nhập máy chủ bằng SSH key, tắt đăng nhập bằng mật khẩu (`PasswordAuthentication no` trong `/etc/ssh/sshd_config`).
- [ ] Đã đặt lịch sao lưu và thử khôi phục ít nhất một lần.
- [ ] Mã Firebase cũ và Apps Script cũ: sau khi chuyển hẳn, thu hồi quyền truy cập/xóa bản triển khai cũ, và đặt lại quy tắc Firebase thành "chặn tất cả" để dữ liệu cũ không bị truy cập.
- [ ] Cân nhắc quy định về nơi lưu trữ dữ liệu của cơ quan; nếu bắt buộc lưu trong nước, chọn nhà cung cấp máy chủ đặt tại Việt Nam (cùng cách triển khai trên).

## 9. Vận hành hằng ngày và xử lý sự cố

| Việc cần làm | Lệnh (trên máy chủ, trong `/opt/dvkt`) |
|---|---|
| Xem log | `docker compose logs -f app` |
| Khởi động lại | `docker compose restart app` |
| Cập nhật thủ công | `git pull && docker compose up -d --build` |
| Mở khóa đơn vị | Trên web: mục Tra cứu → Bảng tổng hợp → nút *Mở khóa*; hoặc `docker compose exec app node --no-warnings scripts/admin.mjs unlock MA` |
| Đặt Token mới cho đơn vị | `docker compose exec app node --no-warnings scripts/admin.mjs set-token MA TOKEN_MOI` |
| Danh sách đơn vị đang khóa | `docker compose exec app node --no-warnings scripts/admin.mjs list-locked` |

Sự cố thường gặp:
- **Không vào được bằng HTTPS:** kiểm tra bản ghi DNS đã trỏ đúng IP và cổng 80/443 đã mở; xem `docker compose logs caddy`.
- **Lỗi "Chưa cấu hình ADMIN_PASSWORD":** thiếu giá trị trong `.env`; sửa rồi `docker compose up -d`.
- **Đơn vị báo Token sai:** đặt lại Token bằng lệnh `set-token` ở trên.
- **Tải tệp báo lỗi:** tệp quá lớn (PDF xếp hạng tối đa 1MB, quyết định phê duyệt 10MB, đủ điều kiện khám sức khỏe 1MB, minh chứng khác 5MB) hoặc sai định dạng (các mục quyết định chỉ nhận PDF).

## Khác biệt so với hệ thống Apps Script cũ

Giữ nguyên: tên hệ thống, tên 7 mục, tên và số thứ tự các cột PL1–PL5, quy tắc khóa đơn vị sau khi nộp, quy tắc đối chiếu Excel, giới hạn dung lượng tệp, bảng tổng hợp có mật khẩu.

Thay đổi (có chủ đích):
- Dữ liệu lưu trong CSDL của hệ thống thay cho Google Sheets; hồ sơ lưu trên máy chủ thay cho Google Drive.
- Báo cáo mỗi phiên tải về dạng `.xlsx` (cùng bố cục, tiêu đề cột như cũ) thay vì mở Google Sheet.
- Đồng bộ nhiều người dùng chung một đơn vị bằng cập nhật định kỳ 8 giây thay cho Firebase; không còn giới hạn 100 kết nối của Firebase (chỉ số "Đang kết nối" vẫn hiển thị).
- Token được mã hóa; mật khẩu quản trị lấy từ biến môi trường; có giới hạn số lần đăng nhập sai/phút; kiểm tra định dạng tệp tải lên.
- Mục "Thuyết minh CPQL" vẫn mở web app Apps Script riêng (chưa chuyển).

## 10. (Tùy chọn) Tự tạo Google Sheet cho mỗi phiên nộp

Mặc định báo cáo tải về dạng `.xlsx`. Nếu muốn mỗi lần nộp có thêm **Google Sheet** trong Google Drive của Sở (như hệ thống cũ):

1. Vào <https://console.cloud.google.com> → tạo dự án mới (ví dụ `dvkt-vinhlong`).
2. Menu **APIs & Services → Library** → tìm **Google Drive API** → **Enable**.
3. **APIs & Services → Credentials → Create credentials → Service account** → đặt tên → Create → Done.
4. Bấm vào tài khoản dịch vụ vừa tạo → tab **Keys → Add key → Create new key → JSON**. Trình duyệt tải về một file `.json` (giữ kín, không đưa lên GitHub).
5. Trong Google Drive, tạo thư mục (ví dụ `BaoCao_DVKT`) → chuột phải → **Chia sẻ** → thêm địa chỉ email của tài khoản dịch vụ (dạng `...@...iam.gserviceaccount.com`, nằm trong file JSON ở mục `client_email`) với quyền **Người chỉnh sửa**.
6. Mở thư mục đó, lấy mã thư mục trên thanh địa chỉ (đoạn sau `/folders/`).
7. Trên máy chủ, sửa `.env`: dán nội dung file JSON (gộp thành một dòng) vào `GOOGLE_SERVICE_ACCOUNT_JSON`, điền `GOOGLE_DRIVE_FOLDER_ID`, rồi `docker compose up -d`.

Từ đó, mỗi báo cáo nộp chính thức sẽ tự có Google Sheet; link hiện ở mục Tra cứu và Bảng tổng hợp, cùng với nút tải `.xlsx`. Nếu Google gặp lỗi, việc nộp báo cáo vẫn thành công và hệ thống tự thử tạo lại Sheet ở lần tra cứu kế tiếp. Lưu ý: tài khoản dịch vụ có dung lượng Drive riêng (15 GB), mỗi báo cáo chỉ vài trăm KB nên đủ dùng.
