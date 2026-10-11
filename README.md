# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI

## Mục tiêu

- Tạo **Custom Bridge Network** `app-net` để các container giao tiếp nội bộ qua tên service (DNS resolution).
- Tạo **Named Volume** `db-data` để lưu trữ dữ liệu PostgreSQL bền vững (persistent).

---

## Kiến trúc

```
┌─────────────────────────────────────────────────┐
│               Docker Bridge Network              │
│                    app-net                       │
│                                                  │
│  ┌────────────────┐      ┌──────────────────┐   │
│  │  app-container │─────▶│    db-server     │   │
│  │  (nginx:alpine)│ DNS  │ (postgres:15-alp)│   │
│  │  port 8080:80  │      │  port 5432       │   │
│  └────────────────┘      └────────┬─────────┘   │
│                                   │              │
└───────────────────────────────────┼─────────────┘
                                    │ mount
                              ┌─────▼──────┐
                              │  db-data   │
                              │ (Named Vol)│
                              └────────────┘
```

---

## Cách chạy

```bash
# Cấp quyền thực thi
chmod +x commands.sh

# Chạy toàn bộ script
./commands.sh
```

---

## Giải thích từng bước trong `commands.sh`

### Bước 1 — Tạo Custom Bridge Network

```bash
docker network create --driver bridge app-net
```

- `--driver bridge`: tạo mạng nội bộ cô lập, các container trong cùng network có thể ping nhau qua **tên container** (DNS tự động).

### Bước 2 — Tạo Named Volume

```bash
docker volume create db-data
```

- Named volume được Docker quản lý tại `/var/lib/docker/volumes/db-data/`.
- Dữ liệu **không bị mất** khi container bị xóa.

### Bước 3 — Khởi chạy Database Container

```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=secret123 \
  postgres:15-alpine
```

| Flag | Ý nghĩa |
|------|---------|
| `--name db-server` | Tên container, cũng là hostname DNS trong network |
| `--network app-net` | Tham gia vào custom network |
| `-v db-data:/var/lib/postgresql/data` | Mount Named Volume vào thư mục data của Postgres |
| `-e POSTGRES_*` | Biến môi trường khởi tạo database |

### Bước 4 — Khởi chạy Backend Container

```bash
docker run -d \
  --name app-container \
  --network app-net \
  -p 8080:80 \
  -e DB_HOST=db-server \
  postgres:15-alpine
```

- `DB_HOST=db-server`: Backend kết nối DB bằng **hostname** `db-server` — Docker DNS tự phân giải thành IP nội bộ.

### Bước 5 — Kiểm tra DNS Resolution

```bash
docker exec app-container ping -c 2 db-server
```

Kết quả mong đợi:
```
PING db-server (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.123 ms
64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.089 ms
```

### Bước 6 — Kiểm tra Data Persistence

```
Thêm dữ liệu → Xóa container (docker rm -f db-server)
→ Tạo lại container gắn cùng db-data → Dữ liệu vẫn còn
```

---

## Lệnh kiểm tra thủ công

```bash
# Xem danh sách networks
docker network ls | grep app-net

# Xem danh sách volumes
docker volume ls | grep db-data

# Xem chi tiết network (IP các container)
docker network inspect app-net

# Kiểm tra DNS từ Backend → DB
docker exec -it app-container ping -c 2 db-server

# Xem logs DB container
docker logs db-server

# Truy cập PostgreSQL trực tiếp
docker exec -it db-server psql -U appuser -d appdb
```

---

## Dọn dẹp sau bài tập

```bash
docker rm -f db-server app-container
docker network rm app-net
docker volume rm db-data
```

---

## Sản phẩm nộp bài

- [x] `commands.sh` — script thực thi đầy đủ các bước
- [x] `README.md` — tài liệu giải thích
