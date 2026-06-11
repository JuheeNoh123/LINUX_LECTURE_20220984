<img width="767" height="605" alt="image" src="https://github.com/user-attachments/assets/e99d951e-46f5-431a-a0e2-b90212fe24d4" /># 10주차

## 웹서버 구축 운영 (Nginx + Wordpress + MySQL 3-Tier)

### 핵심 개념

#### 서버트랜드

- Nginx(34%) vs Apache(28%) - 2021년경 Nginx가 역전
- Apache: 프로세스/스레드 기반, C10K 문제
- Nginx: 이벤트 기반 비동기, 단일/소수 워커로 대량 연결 처리, 메모리 1/3~1/5

#### 3-Tier 아키텍처

```
브라우저 → Nginx(8080, 정적파일+리버스프록시)
        → WordPress(php8.2-fpm, 9000, FastCGI)
        → MySQL 8.0(3306)
```

#### Reverse Proxy vs FastCGI

|  | proxy_pass | fastcgi_pass |
|---|---|---|
| 프로토콜 | HTTP | FastCGI(바이너리) |
| 용도 | API/MSA | PHP-FPM 전용 |

---

## 실습

### 1) 웹서버 구축 준비

<img width="527" height="100" alt="image" src="https://github.com/user-attachments/assets/e793d05c-72f5-4f14-9703-a9d57bd8c740" />


#### 1. 디렉토리 구조

```
wordpress/
├── compose.db.yaml
├── compose.wordpress.yaml
├── compose.nginx.yaml
├── .env
├── nginx/default.conf
└── logs/
```

#### 2. .env 작성

<img width="603" height="173" alt="image" src="https://github.com/user-attachments/assets/a9db3e24-766b-4282-8c7b-cf54c5c46e4c" />


#### 3. nginx/default.conf — 4가지 location 블록

<img width="522" height="371" alt="image" src="https://github.com/user-attachments/assets/04c211c9-37ca-4097-ac9b-f4110394ad04" />


```nginx
# ①기본 요청 처리
location / {
        try_files $uri $uri/ /index.php?$args;
}
location ~ \.php$ {
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_read_timeout 300;
}
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
        access_log off;
}
location /nginx_status {
        stub_status on;
        allow 172.0.0.0/8;
        deny all;
}
# ④보안: .htaccess 접근 차단
location ~ /\.(ht|git) {
        deny all;
}
```

- `location /` → try_files (퍼머링크 라우팅)
- `location ~ \.php$` → fastcgi_pass wordpress:9000
  - PHP 요청 → 워드프레스
- `location ~* \.(js|css|png...)$` → 정적 캐싱(expires 30d)
  - 주요 자원 nginx 서버가 처리
  - PHP-FPM 부하 감소, 응답 속도 향상
- `location ~ /\.(ht|git)` → deny all (보안)
  - 불필요한 설정 노출 방지

#### 4. compose.db.yaml (MySQL)

- 9주차 disk_b LVM 재사용: `/mnt/mysql_data:/var/lib/mysql`
- healthcheck로 mysqladmin ping 체크
- 기존 mysql_lab 정리 후 데이터 초기화 필요

<img width="797" height="576" alt="image" src="https://github.com/user-attachments/assets/39e20e22-13ec-49d0-b540-340fd6f9d1e5" />


```bash
docker stop mysql_lab
docker rm mysql_lab

sudo ls -lh /mnt/mysql_data/

sudo rm -rf /mnt/mysql_data/*
ls -ld /mnt/mysql_data/
df -hT /mnt/mysql_data
```

#### 5. compose.wordpress.yaml

<img width="737" height="547" alt="image" src="https://github.com/user-attachments/assets/01715f1c-d757-4c67-952f-df9093eb7a6a" />


```yaml
services:
  wordpress:
    image: wordpress:php8.2-fpm
    container_name: wp_app
    depends_on:
      db:
        condition: service_healthy   # DB healthy 확인 후 기동
    env_file: .env
    environment:
      WORDPRESS_DB_HOST: db:3306     # 서비스 이름 = DNS 호스트명
      WORDPRESS_DB_NAME: ${MYSQL_DATABASE}
      WORDPRESS_DB_USER: ${MYSQL_USER}
      WORDPRESS_DB_PASSWORD: ${MYSQL_PASSWORD}
    volumes:
      - wp_data:/var/www/html        # Nginx와 나중에 공유
    networks:
      - wp_net
    restart: unless-stopped

volumes:
  wp_data:                  # compose.db.yaml과 동일 이름
    external: false         # 이미 생성된 볼륨 재사용

networks:
  wp_net:
    external: false         # 이미 생성된 네트워크 재사용
```

- `depends_on: db: condition: service_healthy`
- `WORDPRESS_DB_HOST: db:3306`
- `wp_data` named volume 공유

#### 6. compose.nginx.yaml

<img width="737" height="547" alt="image" src="https://github.com/user-attachments/assets/86cf3e7b-2dfb-471d-8b77-0ffc1eef2c62" />


```yaml
services:
  nginx:
    image: nginx:alpine
    container_name: wp_nginx
    ports:
      - "8080:80"                          # 외부 노출은 Nginx만
      - "8443:443"
    volumes:
      - wp_data:/var/www/html:ro           # WordPress 파일 읽기 전용
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - ./logs:/var/log/nginx               # 로그 호스트에 저장
      - ./nginx/certs:/etc/nginx/certs:ro
    depends_on:
      - wordpress
    networks:
      - wp_net
    restart: unless-stopped

volumes:
  wp_data:
    external: false

networks:
  wp_net:
    external: false
```

- `ports: "8080:80"` (외부 노출은 nginx만)
- `wp_data:/var/www/html:ro`
- nginx 설정/로그 마운트

#### 7. 단계별 실행 & 검증

| | wp_data(Named Volume) | /mnt/mysql_data (Bind Mount) |
|---|---|---|
| 저장 위치 | Docker 관리 (disk_a LVM 위) | 호스트 직접 (disk_b LVM 위) |
| I/O 특성 | 순차I/O (overlay2와 공존) | 랜던 I/O 전용 분리 |
| 9주차 연속성 | 신규 생성 | 기존 LVM 재사용 |
| 물리 경로 제어 | Docker가 결정 | 관리자가 직접 결정 |

disk_b는 MySQL 전용으로 이미 마운트되어 있던 걸 재사용했고,
워드프레스 파일은 Docker 기본 영역(disk_a) 안에 새로 만든 볼륨에 저장

**DB 단독**

```bash
docker compose -f compose.db.yaml up -d
```

<img width="697" height="362" alt="image" src="https://github.com/user-attachments/assets/0fb17aaf-3fd0-4c64-894e-0cf86b0df8c8" />


```bash
docker exec -it wp_db mysql -u wpuser -pwppass_2026!
```

```sql
SHOW DATABASES;
```

**DB+WP**

```bash
docker compose -f compose.db.yaml -f compose.wordpress.yaml up -d
```

<img width="998" height="182" alt="image" src="https://github.com/user-attachments/assets/79318fc5-b918-443c-adcc-d9bbc421ec37" />


```bash
docker exec wp_app getent hosts db
```

전체 3개

```bash
docker compose -f compose.db.yaml -f compose.wordpress.yaml -f compose.nginx.yaml up -d
```

<img width="988" height="150" alt="image" src="https://github.com/user-attachments/assets/3f66db3a-4878-4a07-959f-cf2700be9fbc" />


```bash
docker compose -f compose.db.yaml -f compose.wordpress.yaml -f compose.nginx.yaml ps
```

#### 8. 워드프레스 설치

<img width="932" height="932" alt="image" src="https://github.com/user-attachments/assets/4b1badc5-9be4-4742-b4b2-51f25e974956" />


브라우저 접속: `https://localhost:8443/wp-admin/install.php?step=1`

---

## 실습 문제 - 자동화 스크립트 수정

<img width="572" height="823" alt="image" src="https://github.com/user-attachments/assets/a0f5102a-dcf3-4958-b2e2-9174c8a06f95" />


```bash
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
```

- 디스크/LVM/Docker 시작 부분( losetup ~ docker start )은 9주차 그대로 유지 — 매주 이게 선행돼야 함
- docker start mysql_lab 줄은 빼고, 대신 4번에서 docker stop/rm mysql_lab 으로 정리
- 그 뒤에 디렉토리 이동 → 파일 체크 → mysql_data 마운트 체크 → 기존 컨테이너 정리 → 3-tier up → 상태 확인 순서로 추가
