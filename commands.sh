#!/bin/bash
# =============================================================================
# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI
# Kết nối Backend Web API + PostgreSQL bằng Docker CLI thủ công
# =============================================================================

set -e  # Dừng script ngay khi có lỗi

echo "============================================="
echo " BƯỚC 1: Tạo Custom Bridge Network"
echo "============================================="
docker network create \
  --driver bridge \
  app-net

echo "✅ Network 'app-net' đã được tạo"

# Kiểm tra network vừa tạo
docker network ls | grep app-net

echo ""
echo "============================================="
echo " BƯỚC 2: Tạo Named Volume"
echo "============================================="
docker volume create db-data

echo "✅ Volume 'db-data' đã được tạo"

# Kiểm tra volume vừa tạo
docker volume ls | grep db-data

echo ""
echo "============================================="
echo " BƯỚC 3: Khởi chạy Database Container (PostgreSQL)"
echo "============================================="
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=secret123 \
  postgres:15-alpine

echo "✅ Container 'db-server' đã khởi chạy"

# Chờ PostgreSQL sẵn sàng
echo "⏳ Chờ PostgreSQL khởi động..."
sleep 5

echo ""
echo "============================================="
echo " BƯỚC 4: Khởi chạy Backend Container"
echo "============================================="
# Dùng image nginx làm Backend giả lập (thay bằng image thực tế nếu có)
docker run -d \
  --name app-container \
  --network app-net \
  -p 8080:80 \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=appdb \
  -e DB_USER=appuser \
  -e DB_PASSWORD=secret123 \
  nginx:alpine

echo "✅ Container 'app-container' đã khởi chạy"

echo ""
echo "============================================="
echo " BƯỚC 5: Kiểm tra kết nối DNS nội bộ"
echo "============================================="
echo ">>> Ping từ app-container đến db-server qua DNS nội bộ:"
docker exec app-container ping -c 2 db-server

echo ""
echo ">>> Inspect network app-net:"
docker network inspect app-net

echo ""
echo "============================================="
echo " BƯỚC 6: Kiểm tra Data Persistence"
echo "============================================="

echo "--- 6.1: Tạo dữ liệu mẫu trong PostgreSQL ---"
docker exec -it db-server psql -U appuser -d appdb -c "
  CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
  );
  INSERT INTO users (name) VALUES ('Alice'), ('Bob'), ('Charlie');
  SELECT * FROM users;
"

echo ""
echo "--- 6.2: Xóa cứng container DB (docker rm -f) ---"
docker rm -f db-server
echo "✅ Container 'db-server' đã bị xóa"

echo ""
echo "--- 6.3: Khởi chạy lại container DB mới với cùng Volume db-data ---"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=secret123 \
  postgres:15-alpine

echo "✅ Container 'db-server' mới đã khởi chạy"
echo "⏳ Chờ PostgreSQL khởi động lại..."
sleep 5

echo ""
echo "--- 6.4: Xác minh dữ liệu còn nguyên vẹn ---"
docker exec db-server psql -U appuser -d appdb -c "SELECT * FROM users;"

echo ""
echo "============================================="
echo " ✅ HOÀN THÀNH - Tất cả kiểm tra đều thành công!"
echo "============================================="
echo ""
echo "Tóm tắt tài nguyên đã tạo:"
echo "  Network : app-net (bridge)"
echo "  Volume  : db-data (named)"
echo "  Container DB     : db-server  (postgres:15-alpine)"
echo "  Container Backend: app-container (nginx:alpine)"
echo ""
echo "Dọn dẹp sau khi kiểm tra (tuỳ chọn):"
echo "  docker rm -f db-server app-container"
echo "  docker network rm app-net"
echo "  docker volume rm db-data"
