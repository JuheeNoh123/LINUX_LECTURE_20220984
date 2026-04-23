# 7주차

## 1. 서버 트렌드 이해

### 1-1. 물리계층 - 저장 장치가 엄청나게 빨라졌다

- 요즘 서버에는 NVMe SSD (PCIe 5.0, 최대 14GB/s)가 들어감
- 삼성 9100 기준 1TB 약 55만원, AI/ML 학습 서버에 본격 도입중

→ 저장장치 자체가 빨라졌으니, 이걸 제대로 쓰려면 **소프트웨어(파일 시스템, I/O 드라이버)도 함께 따라와야 함.**

---

### 1-2. 드라이버 I/O 계층 - 읽기/쓰기 요청을 어떻게 처리하는가

- 기존에는 aio방식 사용, Linux 5.1부터 io_uring이 새로운 표준으로 자리잡음

| 항목 | 내용 |
|------|------|
| io_uring | 비동기 I/O의 새 표준, 기존 aio 대체 |
| 채택 기업 | Meta, Cloudflare, PostgreSQL 등 |
| IOMMU | 성능 저하 문제 해결 |

→ **"디스크에 더 빠르고 효율적으로 읽고 쓰는 방법"** 이 업계 전반에서 바뀌는 중

---

### 1-3. 파일 시스템 계층 - EXT4와 Docker의 관계

- 리눅스에는 EXT4, XFS, Btrfs, ZFS 등 다양한 파일시스템이 있음.
- 수업에서는 EXT4를 중심으로 배움
  - **Ubuntu 기본 파일시스템**
  - Docker의 **overlay2 스토리지 드라이버**와 가장 잘 맞기 때문

#### EXT4의 핵심 특징 3가지

| 특징 | 설명 |
|------|------|
| 저널링 | 정전/장애 발생 시 데이터 무결성 보장, 빠른 복구 |
| Extents 기반 블록 할당 | 연속 블록 묶음 관리 → 단편화 최소화, 읽기 성능 향상 |
| Delayed Allocation | 쓰기 직전까지 블록 위치 결정을 미룸 → 효율적 배치 |

#### Docker overlay2와의 관계

> Docker의 overlay2는 EXT4 위에서 동작하는 **레이어 기반 가상 파일시스템**

- **lowerdir** (읽기 전용 이미지 레이어) : 여러 컨테이너가 공유
- **upperdir** (쓰기 레이어) : 컨테이너마다 1개씩 독립
- **merged** (실제로 보이는 파일시스템) : 둘을 합쳐서 보여줌

⇒ 컨테이너 100개를 띄워도 이미지 100번 복사하지 않아도 되는 이유가 바로 이것

---

## 2. 파일시스템 실습

### 2-1. 기본 디스크 상태 확인 - `df -Th`

```bash
df -Th
```

→ 현재 시스템에 어떤 파일 시스템이 마운트 되어있는지 한눈에 파악 가능

<img width="1158" height="400" alt="image" src="https://github.com/user-attachments/assets/6f13913b-be53-4f0b-8514-5f9738e5171a" />


#### 파일 시스템 종류

| 파일시스템 | 설명 |
|-----------|------|
| `/dev/sdd` + ext4 | 실제 데이터가 저장되는 공간 (루트 `/`) |
| overlay | Docker 및 WSL 레이어 기반 가상 FS |
| tmpfs | 메모리 기반 임시 파일시스템, 부팅 시 삭제됨 |
| 9p (drivers, C:, D:) | 윈도우 드라이브를 리눅스에서 공유, EXT4보다 속도 매우 낮음 |
| rootfs | WSL 루트 파일시스템 |

→ **모든 마운트 경로는 하나의 파일이다!**

---

### 2-2. 블록 디바이스 구조 확인 - `lsblk`, `fdisk`

> 디스크가 어떻게 나눠져 있는지(파티션), 각 장치의 UUID와 파일 시스템 타입을 확인해보자.

```bash
lsblk --f        # 블록 디바이스 트리 구조 확인
ls -al /dev/sda  # 디바이스 파일 확인
sudo fdisk -l    # 섹터/블록 상세 정보 확인
```
<img width="1120" height="190" alt="image" src="https://github.com/user-attachments/assets/15c75e04-d4a2-4d53-93e9-6daf727dad1f" />

<img width="663" height="53" alt="image" src="https://github.com/user-attachments/assets/1328ac3b-070b-4a6d-aa00-8ad302773370" />

- **b**는 블록 디바이스를 의미
  - 블록 디바이스 : **블록(4096 bytes) 단위로 읽고 쓰는 장치**

| 맨 앞 문자 | 의미 | 예시 |
|-----------|------|------|
| `-` | 일반 파일 | `test.txt`, `image.png` |
| `d` | 디렉터리 | `/home`, `/etc` |
| `b` | **블록 디바이스** | `/dev/sda`, `/dev/sdd` |
| `c` | 캐릭터 디바이스 | `/dev/tty` (터미널) |
| `l` | 심볼릭 링크 | `sym.txt -> origin.txt` |

<img width="710" height="557" alt="image" src="https://github.com/user-attachments/assets/9f05a761-3383-4f33-b084-08ee4e1bc054" />

- **sdc(swap)** : 가상 메모리
- **sdd** : 실제 물리 파일 시스템 (Distro, gui 지원용)

| 계층 | 단위 | 크기 | 관리 주체 |
|------|------|------|----------|
| 섹터 | Sector | 512 bytes | 하드웨어 |
| 블록 | Block | 4,096 bytes | 파일시스템 (EXT4) |

→ 섹터 8개 = 블록 1개. 파일시스템은 섹터가 아닌 **블록 단위**로 데이터를 관리한다.

#### 섹터와 블록

- **섹터** : 디스크를 **물리적으로 나누는 가장 작은 단위 (512bytes)**
- **블록** : 섹터는 너무 작아서, **파일시스템(EXT4 등)은 섹터 8개를 묶어서 하나의 블록으로 관리** (섹터 8개 묶음 = 블록 1개)

---

### 2-3. Inode 확인 - `stat`, `df -i`

> **inode란?** 파일의 실제 내용이 아닌 **메타데이터 저장소**

inode에 담긴 정보:
- 파일권한, UID, GID
- 타임스탬프 (접근/수정/변경)
- 실제 데이터 블록의 주소 목록

| 계층 | 크기 | 관리 주체 |
|------|------|----------|
| inode | 128~256 bytes | 파일시스템 |
| 파일 | 가변 | 사용자/OS |

> **중요한 점 — 실제 크기 vs 디스크 점유 크기**
> 
> 예를 들어 201byte짜리 파일이라도, 디스크에서는 **블록 1개(4096 bytes)** 를 통째로 점유. 나머지 3895 bytes는 낭비되는 공간
> 
> → 작은 파일이 엄청나게 많으면 inode가 고갈될 수 있고, 디스크 용량보다 inode 부족으로 먼저 문제가 생기기도 함

```bash
stat 파일명  # 파일의 inode 정보 확인
df -i        # 전체 inode 사용량 확인
ls -i        # 파일별 inode 번호 확인
```

<img width="1165" height="645" alt="image" src="https://github.com/user-attachments/assets/8bfd7d20-b8a9-4a08-ba10-955736889db4" />

- sdd 기준 약 6700만개 생성
- 실제 약 65000개 사용중

---

### 2-4. 링크(Link) 이해 — `ln`, `stat`

> 리눅스에서 파일 삭제가 어떻게 동작하는지, 링크 종류에 따라 무슨 차이가 생기는지 이해해보자.

```bash
ln test hardlink   # 하드 링크 생성
ln -s test syml    # 심볼릭 링크 생성
stat test.txt      # 링크 카운터 확인
```

- **하드링크 생성 시** : test 파일과 hard 파일의 inode 값이 같음
  - 백업 용도 : 원본과 동일한 파일이 최소 하나 이상 있어야하니까. 단, 공간을 많이 차지함.
  
  <img width="889" height="416" alt="image" src="https://github.com/user-attachments/assets/cdd30141-4091-4c0c-81da-9c6bcc046955" />

- **심볼릭 링크 생성시** : 설정, 연결 등
  <img width="898" height="211" alt="image" src="https://github.com/user-attachments/assets/e70cfffa-8a54-4ffa-afbc-162a76dc0b15" />


#### Links 카운터의 의미

Links 카운터가 0이 되는 순간 inode와 블록이 해제됨.

= 즉, 리눅스에서 `rm` 은 "파일을 삭제" 하는게 아니라 **"링크 카운터 1을 줄이는 것"** 임

| 상황 | Links 변화 |
|------|-----------|
| 일반 파일 생성 | 1 |
| 디렉터리 생성 | 2 (자기 자신 + 부모 엔트리) |
| 하드링크 추가 | +1 |
| 하위 디렉터리 추가 (ext4+) | 변화 없음 |

#### 하드링크 vs 심볼릭 링크 비교

| 항목 | 하드 링크 | 심볼릭 링크 |
|------|----------|------------|
| inode | 원본과 동일 | 별개 |
| Links 카운터 | +1 증가 | 변화 없음 |
| 원본 삭제 시 | 데이터 유지 | 깨짐 |
| 다른 파티션 | 불가 | 가능 |
| 디렉터리에 사용 | 불가 | 가능 |
| 주 용도 | 백업 | 설정파일 연결 등 |

---

### 2-5. 주요 폴더 구조와 용량 확인

> 어디서 디스크가 얼마나 사용되고 있는지 파악해보자.
> → 나중에 디스크 추가/분리/제한 작업을 어디에 해야할지 결정할 수 있다.

```bash
# 홈 기준 상위 10개 폴더 용량 분석
sudo du -ah --max-depth=1 /home | sort -hr

# Docker 전체 디스크 점유 크기 확인
sudo du -sh /var/lib/docker
```
<img width="940" height="297" alt="image" src="https://github.com/user-attachments/assets/db31fec9-149a-4816-b6cc-8b29f460cf48" />

<img width="765" height="56" alt="image" src="https://github.com/user-attachments/assets/3f92b5cb-5d59-4985-b991-9895de2bcad0" />

#### 주요 폴더 역할

| 폴더 | 역할 | 비고 |
|------|------|------|
| `/var` | 가변 데이터 저장소 | Docker 데이터, 로그, 캐시가 집중됨 |
| `/home` | 사용자 개인 폴더 | 학생 실습 파일 저장 |
| `/mnt` | 마운트 포인트 | WSL2에서 윈도우 C:, D:\ 연결 |
| `/proc`, `/sys` | 가상 파일시스템 | 실제 용량 없음, 커널 정보 |

---

### 2-6. Docker 파일시스템 구조 분석

```bash
docker info | grep -i "storage driver"  # overlay2 확인
cat /proc/mounts | grep docker           # 마운트 네임스페이스 확인
sudo ls -F /var/lib/docker               # Docker 내부 폴더 확인
docker system df -v                      # Docker 논리적 용량 확인
docker logs 컨테이너이름                 # 컨테이너 로그 확인
```

<img width="1447" height="499" alt="image" src="https://github.com/user-attachments/assets/7f9abef4-6dbe-45e5-ae5d-3de73e3fa996" />

<img width="1456" height="348" alt="image" src="https://github.com/user-attachments/assets/438db08b-d479-4cf4-9fd8-47158cfdc331" />


#### Docker 내부 폴더 구조

| 폴더 | 역할 |
|------|------|
| `overlay2/` | 이미지 레이어 + 컨테이너 레이어 전체 |
| `containers/` | 컨테이너 메타데이터 + 로그 파일 |
| `images/` | 이미지 인덱스/메타데이터 |
| `volumes/` | docker volume 데이터 |
| `buildkit/` | 빌드 캐시 |

→ Docker는 **내부 로그 저장에 기본 제한이 없다.**  
장기 운영 시 로그(`containers/`), 볼륨(`volumes/`), 빌드 캐시(`buildkit/`)가 수십 GB씩 늘어날 수 있다.

---

### 2-7. 실제 디스크 사용량 예측

> 수업 서버(학생 70명 기준)로 예상 사용량을 계산해보자.

| 항목 | 크기 |
|------|------|
| Docker 이미지 (공유) | ~1.4 GB |
| overlay2 UpperDir (플러그인 등) | ~10.8 GB |
| MySQL 데이터 파일 | ~23 GB |
| WordPress 미디어 업로드 | ~1~5 GB |
| 컨테이너 로그 | ~2~5 GB |
| buildkit 빌드 캐시 | ~2~3 GB |
| **Docker 합계** | **약 40~48 GB** |
| 홈 폴더 (주차별 실습 파일) | 70~210 GB |

→ 현재 구조는 `/var`, `/home` 이 모두 `/dev/sdd` 단일 파티션에 있어서, **한 영역이 꽉 차면 전체 시스템이 다운될 위험이 있다**

→ **디스크 추가 및 제한 필요 (이후 실습)**

---

## 기본 실습 문제

### 링크 생성 및 inode 확인

```bash
$ echo "linux filesystem" > origin.txt
$ ln origin.txt hard.txt
$ ln -s origin.txt sym.txt
$ ls -li origin.txt hard.txt sym.txt
```

**1. 각 파일의 inode 번호는?**

- `origin.txt` : 38290
- `hard.txt` : 38290
- `sym.txt` : 38291

<img width="767" height="137" alt="image" src="https://github.com/user-attachments/assets/b92f7052-d32e-4dca-ac18-75b56ebe636e" />


하드 링크는 새 inode를 만들지 않는다. 그래서 `origin.txt` 와 `hard.txt` 둘다 같은 inode 번호를 갖게 된다.

심볼릭 링크는 새 inode를 새로 할당받기 때문에 파일 시스템이 다음 비어있는 번호인 38291을 갖게 된다.

**2. sym.txt 파일의 맨 앞 문자는 무엇인가? 의미는?**

<img width="751" height="173" alt="image" src="https://github.com/user-attachments/assets/90176b3a-1e08-41de-bf0d-c3c15a1c712f" />


맨 앞 문자는 `l` 이다. `origin.txt` 파일을 심볼릭 링크 했기 때문이다.

- `-` : 일반 파일
- `d` : 디렉터리
- `b` : 블록 디바이스
- `l` : 심볼릭 링크

**3. 원본 삭제 후 동작 차이 확인**

**4. `cat` 으로 두 파일을 열어본다. 어떻게 다른가?**

<img width="754" height="211" alt="image" src="https://github.com/user-attachments/assets/b4503d3b-979e-4c7d-b830-dbec8df01f90" />

`hard.txt`는 잘 읽히나, `sym.txt`는 깨지는 것을 볼 수 있다.

```
삭제 전)
origin.txt ──┐
             ├──→ inode 38290 → "linux filesystem"
hard.txt   ──┘

삭제 후)
origin.txt  (이름표만 제거됨)
hard.txt  ──→ inode 38290 → "linux filesystem" (데이터 살아있음)
```

`sym.txt`의 내용은 **"origin.txt로 가라"** 는 경로 문자열뿐이다.

```
sym.txt ──→ inode 38291 ──→ "origin.txt" ──→ ??? (없음!)
```

`origin.txt`가 삭제되면 그 경로 자체가 사라지니까, `sym.txt`는 존재하지 않는 곳을 가리키는 상태가 된다.

---

### 직접/간접 포인터 테스트

크기별 테스트 파일 생성 후 `stat`로 확인

```bash
$ dd if=/dev/zero of=tiny.bin   bs=1K count=1   # 1KB
$ dd if=/dev/zero of=small.bin  bs=1K count=40  # 40KB
$ dd if=/dev/zero of=medium.bin bs=1M count=1   # 1MB
$ dd if=/dev/zero of=large.bin  bs=1M count=10  # 10MB
```

<img width="800" height="635" alt="image" src="https://github.com/user-attachments/assets/a160571f-bcf6-49bc-9c21-100eb8d83e65" />


| 파일 | 실제 크기 | Blocks (섹터수) | 실제 점유 크기 (Blocks×512) | 낭비 크기 |
|------|----------|----------------|---------------------------|----------|
| tiny.bin | 1 KB (1024 bytes) | 8 | 4096 bytes | **3072 bytes** |
| small.bin | 40 KB (40960 bytes) | 80 | 40960 bytes | 0 |
| medium.bin | 1 MB (1048576 bytes) | 2048 | 2048 × 512 bytes | 0 |
| large.bin | 10 MB (10485760 bytes) | 20480 | 20480 × 512 bytes | 0 |

→ **tiny.bin만 낭비가 된다. 파일이 작을수록 블록 내부 낭비가 크다.**
