# 13주차

## 서버 백업 관리

### 서버 트렌드 이해

#### 데이터 보호 시장 - 3-2-1 법칙

- **3-2-1**: 데이터 복사본 3개, 서로 다른 스토리지/매체 2개, 그중 최소 1개는 오프사이트 보관
- **3-2-1-1-0**: 1개는 오프라인(Air Gap), 0은 백업 복구 검증 시 에러 0건(무결성)

#### 데이터 격리/자동화

- **Air Gap**: 백업 서버를 네트워크적으로 분리
- **CDP**: 지속적 데이터 보호

#### 데이터 손실 위협

- 랜섬웨어(불변성 이슈), S/W 에러/재난

#### 컨테이너 시대의 백업

- 도커/쿠버네티스 환경에서는 `/var`, `/etc` 통째 백업 방식이 안 맞음
- **백업 단위 = 컨테이너 단위** → 이번 수업 실습 도구: **Restic**
- 기존 방식: rsync + cron

#### rsync vs BorgBackup/Restic 비교

| 비교 요소 | rsync (전통) | Restic/Borg (모던) |
|---|---|---|
| 중복 제거 | 매번 통째 복사 또는 하드링크 꼼수 | 블록(Chunk) 단위, 60~80% 절감 |
| 보안 | 평문 저장 | AES-256 종단간 암호화 기본 제공 |
| 랜섬웨어 대응 | 원본 감염 시 백업도 덮어써짐 | 불변성/스냅샷으로 보호 |

#### 백업 종류 비교

| 종류 | 대상 | 백업 속도 | 복구 속도 | 저장 공간 |
|---|---|---|---|---|
| 전체(Full) | 매번 전체 복사 | 느림 | 가장 빠름 | 가장 많음 |
| 증분(Incremental) | 직전 백업 이후 변경분만 | 가장 빠름 | 느림(전체+모든 증분 필요) | 가장 적음 |
| 차분(Differential) | 마지막 전체 백업 이후 누적 변경분 | 보통 | 보통(전체+마지막 차분 필요) | 보통 |

---

## 실습

<img width="576" height="60" alt="image" src="https://github.com/user-attachments/assets/b72dd09a-0c71-47a7-a89b-4cc8e443518d" />


| 폴더 | 용도 | 생성 주체 |
|---|---|---|
| ~/week13/restic-repo/ | Restic 저장소(암호화 데이터) | restic init |
| ~/week13/backup/db/ | mysqldump 덤프 | 직접 생성 |
| ~/week13/backup/files/ | tar 백업 | 직접 생성 |
| ~/week13/restore/ | 복구 임시 저장 | restic restore |

### Restic 주요 명령어

| 명령어 | 설명 |
|---|---|
| init | 저장소 초기화 (최초 1회) |
| backup | 백업 수행 → 스냅샷 생성 |
| restore | 스냅샷 복구 |
| snapshots | 스냅샷 목록 조회 |
| diff | 두 스냅샷 비교 |
| forget | 오래된 스냅샷 삭제 |
| prune | 불필요 데이터 정리 |
| check | 저장소 무결성 검사 |
| stats | 저장소 통계 |
| unlock | 잠금 해제 |

---

## 1) WordPress 볼륨 백업

볼륨 위치: `/var/lib/docker/volumes/wordpress_wp_data/_data` (컨테이너 내 `/var/www/html`)

### 1. WordPress 볼륨을 Restic으로 백업

<img width="932" height="312" alt="image" src="https://github.com/user-attachments/assets/aef8409e-9708-4e4d-a505-25d03b34a799" />

- `-r ~/linux/week13/restic-repo`: 백업 데이터를 저장할 저장소 위치 지정
- `backup /var/lib/docker/volumes/wordpress_wp_data/_data`: 워드프레스 볼륨 폴더를 백업 대상으로 지정
- `--tag wp_files --tag week13`: 나중에 구분하기 쉽게 "wp_files", "week13"이라는 이름표(태그)를 붙임
- `sudo`가 필요한 이유: 도커 볼륨 안의 파일들이 root나 www-data 소유라 일반 유저로는 못 읽기 때문

### 2. 스냅샷 목록 확인

<img width="972" height="597" alt="image" src="https://github.com/user-attachments/assets/29000e74-11a0-44f0-a5d1-f26d0892512f" />

```bash
sudo restic -r ~/linux/week13/restic-repo snapshots
```

지금까지 백업한 기록 (스냅샷)들을 시간 순으로 보여줌. 각 스냅샷마다 ID, 시간, 태그, 경로가 나옴

### a. 저장소 통계 확인

```bash
sudo restic -r ~/linux/week13/restic-repo stats
```

백업한 파일 개수, 실제 용량 등을 보여줌 (중복 제거되어 얼마나 절약됐는지 확인 가능)

### b. 저장소 내부 구조 확인

```bash
cd ~/linux/week13/restic-repo
ls
```

`config`, `data/`, `index/`, `keys/`, `snapshots/` 등의 폴더가 보이면 정상적으로 init된 것

---

## 2) MySQL(DB) 볼륨 백업

**DB는 볼륨 직접 백업 불가** - 실행중인 DB 파일 복사 시 트랜잭션 중단으로 데이터 불일치 발생

→ **mysqldump 후 Restic으로 백업**

<img width="1012" height="312" alt="image" src="https://github.com/user-attachments/assets/9543ebd3-e421-407a-a2f6-33bd927ed510" />

### 날짜 포맷

| 포맷 | 출력 예시 | 용도 |
|---|---|---|
| date +%F | 2026-05-26 | 날짜만 (권장) |
| date +%F_%T | 2026-05-26_09:30 | 날짜+시간 |
| date +%s | 1748235600 | Unix 타임스탬프 |
| date +%Y%m%d | 20260526 | 압축형 날짜 |

---

## 3) DB 백업 → Restic 연계 (실무 표준 패턴)

```bash
# 압축 파일 안의 테이블 생성문 확인
gunzip -c ~/linux/week13/backup/db/db_$(date +%F).sql.gz | grep "^CREATE TABLE"

# 덤프 파일을 Restic으로 백업
sudo restic -r ~/linux/week13/restic-repo backup ~/linux/week13/backup/db/ \
  --tag db_backup --tag $(date +%F)

# 전체 스냅샷 목록 확인
sudo restic -r ~/linux/week13/restic-repo snapshots
```

---

## 4) Restic 백업 확인

```bash
# 두 스냅샷 비교 (서로 다른 경로/시점 백업이면 비교 의미 적음)
sudo restic -r ~/linux/week13/restic-repo diff 스냅샷ID1 스냅샷ID2

# 백업 무결성 확인
sudo restic -r ~/linux/week13/restic-repo check
```

| 항목 | 의미 |
|---|---|
| Files | 파일 추가/삭제/변경 |
| Dirs | 디렉토리 변화 |
| Others | 심볼릭링크 등 변화 |
| Data Blobs | 실제 데이터 블록 변화 |
| Tree Blobs | 디렉토리 구조 갱신 |

---

## 5) Restic 복구 실습 (워드프레스 장애 시나리오)

<img width="1000" height="672" alt="image" src="https://github.com/user-attachments/assets/1690f08d-1e70-41c4-94de-2e7a42ced6d8" />


### 1. 복구 전 게시글 개수 확인

```bash
docker exec wp_db mysql -u wpuser -pwppass_2026! wordpress \
  -e "SELECT COUNT(*) FROM wp_posts;"
```

```
mysql: [Warning] Using a password on the command line interface can be insecure.
COUNT(*)
5
```

### 2. (장애 재현) 게시글 전체 삭제

```bash
docker exec wp_db mysql -u wpuser -pwppass_2026! wordpress \
  -e "SELECT COUNT(*) FROM wp_posts;"
```

```
mysql: [Warning] Using a password on the command line interface can be insecure.
COUNT(*)
6
```

```bash
docker exec wp_db mysql -u wpuser -pwppass_2026! wordpress \
  -e "SELECT COUNT(*) FROM wp_posts;"
```

```
mysql: [Warning] Using a password on the command line interface can be insecure.
COUNT(*)
6
```

```bash
docker exec wp_db mysql -u wpuser -pwppass_2026! wordpress \
  -e "DELETE FROM wp_posts;"
```

```
mysql: [Warning] Using a password on the command line interface can be insecure.
```

### 3. db_backup 스냅샷 ID 확인 후 복원

```bash
sudo restic -r ~/linux/week13/restic-repo snapshots --tag db_backup

sudo restic -r ~/linux/week13/restic-repo restore fd6a6695 --target ~/linux/week13/restore/
```

```
enter password for repository:
repository df4e9438 opened (version 2, compression level auto)

restoring <Snapshot fd6a6695 of [/home/njh19270/linux/week13/backup/db] at 2026-06-12 04:37:34.238559097 +0900 KST by root@
JUHEE-NOH> to /home/njh19270/linux/week13/restore/
Summary: Restored 7 files/dirs (273.379 KiB) in 0:00
```

### 4. 복원된 덤프로 DB 복구

```bash
cd ~/linux/week13/restore/home/njh19270/linux/week13/backup/db
```

```bash
sudo gunzip -c db_2026-06-12.sql.gz | docker exec -i wp_db mysql -u wpuser -pwppass_2026! wordpress
```


### 5. 복구 확인

```bash
docker exec wp_db mysql -u wpuser -pwppass_2026! wordpress \
  -e "SELECT COUNT(*) FROM wp_posts;"
```

```
mysql: [Warning] Using a password on the command line interface can be insecure.
COUNT(*)
```

<img width="947" height="570" alt="image" src="https://github.com/user-attachments/assets/6376f273-001c-452a-a10a-7584e68c7117" />


---

## 워드프레스 자체 백업 (UpdraftPlus)

- 플러그인 설치: 플러그인 추가하기 → "백업" 검색 → UpdraftPlus 설치/활성화
- "지금 백업" 클릭 → DB + 파일 백업 자동 분류 저장
- 실제 저장 위치: `/var/lib/docker/volumes/wordpress_wp_data/_data/wp-content/updraft/`

| 파일명 | 크기 | 내용 |
|---|---|---|
| backup_...db.gz | 291K | MySQL DB 덤프 |
| backup_...others.zip | 1.5M | wp-config.php 등 |
| backup_...plugins.zip | 7.8M | 설치 플러그인 전체 |
| backup_...themes.zip | 13M | 설치 테마 전체 |
| backup_...uploads.zip | 2.8M | 미디어 업로드 |

> 핵심 기능(원격저장/증분/예약)은 Premium(유료)

---

## CLI(Restic) vs UpdraftPlus 비교

| 항목 | CLI 백업 (Restic+mysqldump) | UpdraftPlus |
|---|---|---|
| 백업 방식 | 터미널 명령어 | WP 관리자 GUI |
| 백업 위치 | 외부(restic-repo) | 내부(wp-content) |
| 볼륨 장애 시 | ✅ 안전 | ❌ 백업도 함께 소멸 |
| 암호화 | AES-256 기본 | 없음(zip/gz만) |
| 중복제거 | ✅ 있음 | ❌ 없음 |
| 증분 백업 | ✅ 영구 증분 | ❌ 매번 전체 |
| 백업 용량 | 작음 | 큼 |
| DB 백업 | mysqldump 별도 필요 | ✅ 자동 포함 |
| 무결성 검사 | ✅ restic check | ❌ 없음 |
| 복구 난이도 | 높음(CLI) | 낮음(GUI) |
| 3-2-1/오프사이트 | ✅ rclone 연계 가능 | △ 수동 설정 |
| 사용 대상 | 서버 관리자 | WordPress 관리자 |
