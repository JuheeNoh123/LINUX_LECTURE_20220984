#!/bin/bash

# disk_a.img 연결
if ! losetup -a | grep -q disk_a.img; then
    sudo losetup -fP disk_a.img
fi

# disk_b.img 연결
if ! losetup -a | grep -q disk_b.img; then
    sudo losetup -fP disk_b.img
fi

# disk_c.img 연결
if ! losetup -a | grep -q disk_c.img; then
    sudo losetup -fP disk_c.img
fi

# LVM 활성화
sudo vgchange -ay

# fstab 마운트
sudo mount -a

# Docker 시작
sudo service docker start

# 1. 실습 디렉토리 이동
PROJECT_DIR="$HOME/linux/week10/wordpress"
cd $PROJECT_DIR || { echo "디렉토리를 찾을 수 없습니다."; exit 1; }

# 2. 필수 설정 파일 체크
echo "=== 설정 파일 체크 ==="
if [ ! -f ".env" ] || [ ! -f "./nginx/default.conf" ]; then
    echo "[오류] .env 또는 nginx/default.conf 파일이 누락되었습니다."
    exit 1
fi

# 3. MySQL 전용 LVM 마운트 확인
echo "=== MySQL 전용 LVM 스토리지 확인 ==="
if ! df -hT | grep -q "/mnt/mysql_data"; then
    echo "[경고] /mnt/mysql_data 마운트가 확인되지 않습니다."
    exit 1
fi

# 4. 기존 컨테이너 정리 (mysql_lab 포함)
echo "=== 기존 서비스 정리 ==="
docker stop mysql_lab 2>/dev/null
docker rm mysql_lab 2>/dev/null
docker compose \
  -f compose.db.yaml \
  -f compose.wordpress.yaml \
  -f compose.nginx.yaml \
  down

# 5. 3-Tier 병합 실행
echo "=== 3-Tier 아키텍처 병합 실행 시작 ==="
docker compose \
  -f compose.db.yaml \
  -f compose.wordpress.yaml \
  -f compose.nginx.yaml \
  up -d

# 6. 최종 상태 확인
echo "=== 디스크 상태 ==="
losetup -a
sudo lvs
df -hT

echo "=== 서비스 전체 상태(PS) 확인 ==="
docker compose \
  -f compose.db.yaml \
  -f compose.wordpress.yaml \
  -f compose.nginx.yaml \
  ps

echo "=== 설치 마법사 접속 준비 완료 ==="
echo "http://localhost:8080 에 접속하여 워드프레스 홈 접속."
