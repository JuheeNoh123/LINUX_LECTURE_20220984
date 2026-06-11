# 9주차

## 서버 스토리지 계층

### 전체 흐름 (위 → 아래: 추상화 → 하드웨어)

| 계층 | 설명 |
|---|---|
| 애플리케이션 | read, write, mmap, io_uring, open, fsync 등 시스템콜 사용 |
| VFS | 모든 파일 시스템(ext4, XFS, Btrfs, ZFS, NFS등)을 동일한 인터페이스로 추상화 |
| Page Cache/Buffer Cache | RAM에 데이터 캐싱 (CPU > 디스크 속도 차이 때문), 4KB 페이지 단위 |
| 블록 계층(커널) | blk-mq(멀티큐 I/O 스케줄링), Device Mapper(LVM/암호화), MD RAID 등이 위치 |
| 드라이버/HBA 계층 | nvme, ahci 같은 실제 장치 드라이버 |
| 물리 장치 | 실제 SSD, HDD 등 하드웨어 |

### 핵심 개념 정리

#### VFS

- App ↔ FS 사이의 공통 인터페이스
- 다양한 FS에 자동 연결 (open, read 등 시스템콜 공통화)
- inode, dentry, file 추상화
  - inode: 파일의 "실체" (데이터/메타데이터)
  - dentry(directory entry): 파일의 "이름과 경로 정보"
  - file: 프로세스가 연 "세션/핸들"

#### Page Cache/Buffer Cache

- 목적: 속도 개선 (CPU 속도 > 디스크 속도)
- 모든 디스크 I/O가 일단 거쳐가며 RAM에 저장
- 현재는 Page Cache로 통합되어 운영
- 4KB 페이지 단위 처리
- 관련 정책: dirty writeback, readahead, direct I/O bypass

#### 블록 계층(커널)

- 병합 / 스케줄링을 통한 I/O 요청 최적화
- Page Cache 미스 시 여기로 요청 전달

---

## Device Mapper (dm-*)

> 커널의 블록 매핑 프레임워크 - 모든 "가상 블록 장치"의 기반

### 주요 모듈

| 모듈 | 기능 |
|---|---|
| dm-linear | LVM의 기본 LV (논리 볼륨) |
| dm-thin | Thin Provisioning (물리>논리 오버커밋 허용) |
| dm-crypt | 디스크 암호화 (LUKS2, AES-XTS-plain64, 512bit) |
| dm-cache | SSD를 HDD 캐시로 사용 |
| dm-raid | mdadm 기반 SW RAID |

### 동작 구조

```
[USERSPACE]
application / LVM2
    ↓
DM library (libdevmapper)
    ↓ ioctl
[KERNEL]
DEVICE MAPPER → Mapping Tables → DM TARGETS
```

### 사용자 도구 ↔ DM 타겟 매핑

| 사용자 도구 | DM 타겟 |
|---|---|
| lvm2 | linear / stripe / thin / raid |
| cryptsetup | crypt |
| mdadm | raid |
| docker | thin (devicemapper 드라이버) |

### 추가 궁금증

| 도구 | 역할 | DM 타겟 |
|---|---|---|
| lvm2 | 디스크를 PV/VG/LV로 나눠 유연하게 관리하는 볼륨 관리 도구 (pvcreate, vgcreate, lvcreate 등) | linear/stripe/thin/raid |
| cryptsetup | 디스크/파티션을 암호화하는 도구 (LUKS 포맷 생성·해제) | crypt |
| mdadm | 소프트웨어 RAID 구성 도구 (RAID 0/1/5/6 등) | raid |
| docker | 컨테이너 실행 도구. devicemapper 스토리지 드라이버 사용 시 컨테이너 레이어를 thin provisioning으로 관리 | thin |

---

## LVM 구조

> 물리 디스크(PV) → VG(여러 디스크를 합친 창고) → LV(그 창고에서 떼어 쓰는 용량 한도)

### 구성요소

- **PV (Physical Volume)**: 디스크의 파티션된 상태
- **VG (Volume Group)**: PV들을 묶은 풀
- **LV (Logical Volume)**: 실제 마운트 가능한 논리 볼륨
- **PE**: VG를 구성하는 블록 단위 (~4MB)

### 왜 필요한가?

디스크를 직접 마운트하면 나중에 용량 늘리기가 매우 번거로움. LVM은 디스크들을 풀(Pool)처럼 묶어서 유연하게 나눠 쓸 수 있게 해줌.

### 핵심 깨달음

1. /dev/mapper/... 는 진짜 디스크가 아니라 "포인터" — 데이터는 실제로 물리 디스크에 저장되고, /dev/mapper/...는 거기로 가는 입구일 뿐

2. LVM/DM 매핑 ≠ 마운트
   - LVM/DM: 물리 디스크 ↔ 가상 블록 장치 (블록 단위 연결)
   - 마운트: 블록 장치 ↔ 폴더 (파일시스템 단위 연결)
   - 둘 다 "이어주기"라는 본질은 같지만, 연결하는 대상의 형태가 다름

3. LVM이 필요한 이유: 물리 디스크를 직접 쓰면 "디스크 1개 = 고정 용량 1개"라서, 나중에 용량을 늘리려면 새 마운트 포인트를 따로 만들어야 함

4. lvextend 의 진짜 의미: 디스크를 추가해도 물리 디스크 자체가 커지는 건 아님. 추가한 디스크를 VG(창고)에 합쳐서 → 처음에 정해놓은 LV의 용량 한도를 늘리는 것
   - VG에 여유공간 없음 → 디스크 추가로 VG 먼저 키움
   - VG에 여유공간 있음 → lvextend로 LV 한도만 늘리면 끝

---

## 실습

WSL2는 물리 디스크 추가가 안되므로 loop 디바이스로 가상 디스크 생성

### loop 디바이스 정리

- loop 디바이스: 일반 파일을 디스크처럼 다룰 수 있게 해주는 가상 장치 (/dev/loop0, /dev/loop1...)
- WSL2는 물리 디스크 추가 불가 → 이미지 파일(disk1.img)을 만들어 loop 디바이스에 연결해서 디스크처럼 사용
- /dev/loop0: 폴더가 아니라 커널이 미리 만들어둔 빈 디바이스 노드 (콘센트/포트 같은 개념, 평소엔 비어있음)
- losetup /dev/loop0 disk1.img : disk1.img 파일을 /dev/loop0에 연결(매핑) → 이후 /dev/loop0은 진짜 디스크처럼 인식됨
- 1:1 연결: loop 디바이스 하나당 파일 하나 연결 (다른 파일 쓰려면 loop1, loop2...)
- 파일 = 디스크 통째로: disk1.img 하나가 디스크 전체를 표현하는 이미지. 그 안에 파티션, 파일시스템, 수많은 파일/폴더가 들어 있음
- 연결+포맷+마운트 후에는 그 디스크 안에 자유롭게 파일/폴더 저장 가능
- mkfs.ext4 /dev/loop0 : 빈 디스크 위에 ext4 파일시스템(inode 테이블, 블록 비트맵, 저널 등 메타데이터)을 생성하는 명령. 이게 있어야 OS가 파일/폴더 위치를 관리할 수 있음 → "포맷 = 파일시스템 생성"

---

## 오늘 분리 목표

기존엔 /var/lib/docker , /home , / (root)가 전부 같은 디스크( /dev/sdd )를 쓰고 있어서 한 곳이 가득 차면 시스템 전체가 다운될 위험이 있음. 이걸 디스크별로 분리해서 격리하는 게 목표.

| 영역 | 디스크 | I/O 특성 |
|---|---|---|
| /var/lib/docker | Disk A (1GB) | 순차 I/O 우세 |
| /var/lib/mysql | Disk B (2GB) | 랜덤 I/O 우세 |
| /home | Disk C (2GB) | Quota 제한 필요 |

분리 효과: 한 영역이 포화돼도 다른 영역에 영향 없음

---

## 1. Disk A → Docker 분리

### 1) 가상 디스크 생성

```bash
sudo dd if=/dev/zero of=disk_a.img bs=1M count=1024
```

dd는 데이터를 복사하는 명령어.

/dev/zero (0으로 채워진 무한소스)에서 읽어서, 1MB씩 ( bs=1M ) 1024번( count=1024 ) 써서 1GB짜리 빈 파일을 만드는 것. 이 파일이 곧 "가상 디스크"가 됨.

### 2) loop 디바이스로 연결

```bash
sudo losetup -fP --show disk_a.img    # -> /dev/loop0
```

일반 파일을 커널이 "블록 디바이스"처럼 인식하게 만드는 명령어

- -f : 비어있는 loop 번호를 자동으로 찾아서 사용
- -P : 파티션이 있으면 인식
- --show : 연결된 디바이스 이름( /dev/loop0 )을 출력

이제 disk_a.img 파일이 /dev/loop0 이라는 디스크처럼 동작함.

<img width="851" height="308" alt="image" src="https://github.com/user-attachments/assets/00b0ba6d-6406-48e0-a634-12a8ddec1e49" />


### 3) LVM 구성

LVM 영역
이 디스크 공간은 일반 파티션이 아니라, LVM이 유연하게 쪼개고 합칠 수 있도록 관리하는 풀의 일부입니다"라는 표시가 된 공간

```bash
sudo pvcreate /dev/loop0
```

/dev/loop0 을 LVM이 관리할 수 있는 "물리볼륨(PV)"로 초기화 → 디스크에 LVM 메타데이터를 기록하는 단계

```bash
sudo vgcreate vg_docker /dev/loop0
```

vg_docker 라는 이름의 볼륨 그룹을 만들고, 방금 만든 PV를 여기에 포함시킴. → 이제 1GB짜리 "저장공간 풀"이 생긴 것.

```bash
sudo lvcreate -l 100%FREE -n lv_docker vg_docker
```

vg_docker 풀에서 남은 공간 전부(100%FREE)를 떼어내서, lv_docker 라는 논리 볼륨을 생성.
이게 실제로 마운트할 대상이 됨.

<img width="871" height="158" alt="image" src="https://github.com/user-attachments/assets/b4b84cde-aae6-4220-a4d8-0ce7a88e2ca6" />


| 이름 | 정체 | 역할 | 비유 |
|---|---|---|---|
| /dev/loop0 | disk_a.img를 디스크처럼 보이게 한 것 → PV | "원재료" 디스크 1장 | 벽돌 한장 |
| vg_docker | loop0(들)을 묶은 그룹 | "재료들을 모아둔 창고" | 벽돌들로 쌓은 창고 |
| lv_docker | vg_docker에서 떼어낸 실제 사용 공간 | "창고에서 실제로 쓰는 방" | 그 창고 안에 칸막이 친 방 하나 |

```bash
sudo mkfs.ext4 /dev/vg_docker/lv_docker
```

lv_docker 를 ext4 파일시스템으로 포맷. 이제 일반 파티션처럼 마운트 가능

### 4) Docker 데이터 이관

```bash
# 도커 중지
sudo systemctl stop docker
sudo service docker stop

sudo mkdir /mnt/docker_new
sudo mount /dev/vg_docker/lv_docker /mnt/docker_new
```

새 LV를 임시 위치( /mnt/docker_new )에 마운트. 일단 여기에 데이터를 옮기고, 나중에 진짜 위치로 다시 마운트할 예정

```bash
sudo rsync -aHAX /var/lib/docker/ /mnt/docker_new/
```

기존 Docker 데이터를 새 디스크로 복사. cp 를 안쓰는 이유는 Docker 데이터에는 권한, 하드링크, 심볼릭링크, 확장 속성 같은 매타 데이터가 매우 중요하기 때문.

```bash
sudo mv /var/lib/docker /var/lib/docker.backup
```

원본 디렉토리는 지우지 않고 이름만 바꿔서 백업으로 보관. 문제 생기면 롤백 가능.

<img width="842" height="193" alt="image" src="https://github.com/user-attachments/assets/424d8c14-63a0-4479-b414-299396c399fb" />


### 5) 마운트 위치를 진짜 경로로 교체

```bash
sudo mkdir /var/lib/docker
sudo umount /mnt/docker_new
sudo mount /dev/vg_docker/lv_docker /var/lib/docker
```

- 원본을 .backup 으로 옮겼으니 /var/lib/docker 가 비었음
- 임시 위치에서 연결 해제. 데이터는 LV 내부에 그대로 남아있음 (umout는 단지 "어디서 보이게 할지" 연결을 끊는것 뿐)
- 이번엔 진짜 Docker 경로에 LV 를 마운트. 이제 /var/lib/docker 에 접근하면 실제로는 lv_docker (=disk_a.img)를 보게됨.

💡 정리
1. lv_docker 를 /mnt/docker_new 라는 임시 통로로 보이게 마운트 (lv_docker는 비어있음)
2. 원래 도커 데이터를 그 통로를 통해 lv_docker 안에 복사 (rsync) → lv_docker에 데이터 들어감
3. 원래 /var/lib/docker 폴더는 이름만 바꿔서( docker.backup ) 백업으로 빼둠 → 원래 경로는 비워짐
4. /mnt/docker_new umount (임시 통로 정리)
5. 비워진 /var/lib/docker 에 lv_docker를 마운트
6. 이제부터 /var/lib/docker 로 들어가면 lv_docker(=disk_a.img)가 보이고, 앞으로 도커 데이터는 전부 거기 저장됨

```bash
sudo service docker start

df -hT | grep docker    # 마운트된 파일시스템과 용량 확인
docker ps -a             # 기존 컨테이너 정보가 그대로 남아있는지 확인
```

Docker 재시작. 새 디스크 위에서 정상 동작하는지 확인.

<img width="886" height="172" alt="image" src="https://github.com/user-attachments/assets/c3022ea0-1ccf-41bf-9f64-761c1d4cde89" />


---

## 2. Disk B → MySQL 분리

### 1) 가상 디스크 생성 & 연결

```bash
sudo dd if=/dev/zero of=disk_b.img bs=1M count=2072
sudo losetup -fP --show disk_b.img    # → /dev/loop1
```

이번엔 2072MB (약 2GB) 짜리 파일. loop0은 이미 disk_a가 쓰고 있으므로 자동으로 loop1에 연결됨.

### 2) LVM 구성 (이번엔 일부러 여유 공간을 남김)

```bash
sudo pvcreate /dev/loop1
sudo vgcreate vg_mysql /dev/loop1
sudo lvcreate -L 1G -n lv_mysql vg_mysql

sudo mkfs.ext4 /dev/vg_mysql/lv_mysql    #ext4로 포맷
```

-L 1G 는 "전체의 몇%"가 아니라 정확히 1GB만 할당하라는 뜻. VG는 2GB인데 LV는 1GB만 만들어서, 나머지 1GB는 나중에 온라인 확장 실습에서 사용할 예정

### 3) 영구 마운트 설정 (fstab)

Docker는 서비스가 알아서 경로를 마운트하지만, MySQL 볼륨은 그렇지 않으므로 부팅 시 자동 마운트되도록 fstab에 등록해야함.

```bash
sudo mkdir /mnt/mysql_data
sudo blkid /dev/vg_mysql/lv_mysql
```

blkid는 디바이스의 고유 식별자(UUID)를 출력하는 명령어.
fstab에 등록할 때 디바이스 이름( /dev/... )대신 UUID를 쓰는 이유는, loop 디바이스 번호는 재부팅마다 바뀔 수 있지만, UUID는 고정이기 때문.

```bash
sudo nano /etc/fstab
# UUID=xxxx-xxxx /mnt/mysql_data ext4 defaults,noatime 0 2
```

fstab 한줄 의미: [디바이스] [마운트위치] [파일시스템종류] [옵션] [덤프여부] [fsck 검사순서]

- defaults : 기본 옵션 세트 (rw, suid, dev, exec, auto, nouser, async 등)
- noatime : 파일을 읽기만 해도 발생하는 "마지막 접근시간 기록" 쓰기를 생략 → 불필요한 I/O 감소
- 0 : 덤프 백업 안함
- 2 : 부팅 시 fsck 무결성 검사 순서 (root는 1, 나머지는 2)

```bash
sudo systemctl daemon-reload
sudo mount -a
```

mount -a 는 fstab에 적힌 항목을 전부 마운트 시도. 방금 추가한 줄이 정상 작동하는지 바로 테스트하는 용도.

```bash
df -hT /mnt/mysql_data    #정상적으로 마운트됐는지, 용량이 어떻게 잡혔는지 확인
```

<img width="677" height="57" alt="image" src="https://github.com/user-attachments/assets/86fb26b6-8965-4066-9d61-f29c4e64d725" />


### 4) MySQL 컨테이너 연결

MySQL 컨테이너 볼륨 연결

```bash
docker run -d --name mysql_lab \
  --restart=unless-stopped \
  -e MYSQL_ROOT_PASSWORD=비밀번호 \
  -v /mnt/mysql_data:/var/lib/mysql \
  -p 3306:3306 \
  mysql:8.0
```

- -v 호스트경로:컨테이너경로 : 바인드 마운트 - 호스트의 /mnt/mysql_data 를 컨테이너 안의 /var/lib/mysql 에 연결.
  ⇒ 즉 MySQL 데이터가 실제로는 디스크B에 저장됨.

```bash
sudo ls -la /mnt/mysql_data/

docker exec -it mysql_lab mysql -u root -p    #실행중인 컨테이너 내부에서 명령을 실행
```

컨테이너가 처음 실행되면서 ibdata1 같은 MySQL 데이터 파일을 디스크B에 자동 생성했는지 확인.

<img width="696" height="95" alt="image" src="https://github.com/user-attachments/assets/71732a7b-d335-45db-b9af-7b8fa84322e6" />


### 5) 온라인 확장 (서비스 중단 없이 용량 늘리기)

```bash
sudo lvextend -L +500M /dev/vg_mysql/lv_mysql
```

LV 크기를 현재보다 500MB만큼 추가.

+ 가 붙으면 "현재값 기준 증가량", 안붙으면 "절대값"

VG에 남겨둔 1GB 여유공간에서 떼어오는 것.

```bash
sudo resize2fs /dev/vg_mysql/lv_mysql
```

lvextend 는 블록 디바이스(LV) 크기만 키운 것이고, 그 위에 있는 파일시스템(ext4)은 아직 옛날 크기를 그대로 인식하고 있음.

resize2fs 가 파일 시스템 자체를 새 크기에 맞게 확장해줌.

<img width="977" height="152" alt="image" src="https://github.com/user-attachments/assets/bab0a9a0-4334-47ea-9468-452ee48347aa" />


```bash
df -hT /mnt/mysql_data    # 1G → 약 1.5G(나의 경우 2G)로 늘어근데 난 것 확인
```

<img width="703" height="57" alt="image" src="https://github.com/user-attachments/assets/7ed5fad4-3ca9-4fda-98b1-feced86f1541" />

---

## 실습 과정 비교

| 목적 | /var/lib/docker 분리 (순차I/O) | MySQL 볼륨 분리 (랜덤 I/O) |
|---|---|---|
| 이미지 크기 | count = 1024 → 1GB | count=2072 → 2GB |
| 가상 디스크 | disk_a.img → /dev/loop0 | disk_b.img → /dev/loop1 |
| LVM 구성 | 1. pvcreate /dev/loop0<br>2. vgcreate vg_docker /dev/loop0<br>3. lv_create -l 100%Free -n lv_docker | 1. pvcreate /dev/loop1<br>2. vgcreate vg_mysql /dev/loop1<br>3. lvcreate -L 1G -n lv_mysql |
| LV 할당 방식 | -l 100%FREE (여유 전부) | -L 1G (고정 크기 지정) |
| 파일 시스템 | mkfs.ext4 | mkfs.ext4 |
| 영구 마운트 | X . fstab 등록 없음 | O. fstab UUID 등록 필수 |
| 마운트 대상 | 기존 /var/lib/docker 경로 교체 | 신규 /mnt/mysql_data 마운트 포인트 |
| 볼륨 연결 방식 | Docker가 경로 직접 사용 (서비스 재시작) | -v /mnt/mysql_data:/var/lib/mysql 바인드 |
| 데이터 이관 | rsync -aHAX 기존 데이터 정밀 복사 | 없음 - 컨테이너 최초 기동 시 자동 초기화 |
| 온라인 확장 | 계획 없음 | lvextend +500M → resize2fs |

복습용으로 한번 더해서 500MB 더늘어남.

---

## 3. I/O 특성 비교 (fio 벤치마크)

### 목적

Docker LV(디스크A) 와 MySQL LV(디스크 B)가 실제로 다른 I/O 패턴을 보이는지 측정으로 확인

- fio는 디스크 성능 벤치마크 도구

### 순차 읽기 테스트 (Docker LV 대상)

```bash
sudo fio --name=seq --rw=read --bs=1M --size=256M \
  --filename=/var/lib/docker/fio_test --direct=1 --runtime=10
```

- --rw=read : 읽기 작업
- --bs=1M : 한번에 1MB씩 처리 (큰블록)
- --size=256M : 총 256MB 분량 테스트
- --filename : 테스트용 파일을 생성할 위치 (디스크 A 위)
- --direct=1 : Page Cache를 거치지 않고 디스크에 직접 접근 (캐시 효과 배제, 진짜 디스크 성능 측정)
- --runtime=10 :최대 10초간 실행

→ 디스크 처음부터 끝까지 연속으로 읽는 패턴

<img width="1020" height="566" alt="image" src="https://github.com/user-attachments/assets/daa92511-4a28-4e84-8456-a2019cca071d" />

### 랜덤 읽기 테스트 (MySQL LV 대상)

```bash
sudo fio --name=rand --rw=randread --bs=4k --size=256M \
  --filename=/mnt/mysql_data/fio_test --direct=1 --runtime=10
```

- --rw=randread : 랜덤 읽기
- --bs=4k : 4KB의 작은 블록 단위 (DB의 실제 I/O 단위와 유사)

→ 디스크의 임의 위치를 불규칙하게 점프하며 읽는 패턴

<img width="1007" height="527" alt="image" src="https://github.com/user-attachments/assets/bd72992b-ea52-4ba6-a392-ecbb9880870b" />


### 결과 비교 및 해석

| 항목 | 순차(Docker, 1M) | 랜덤(MySQL, 4k) |
|---|---|---|
| BW (대역폭) | 1,255 MiB/s | 71.9 MiB/s |
| IOPS | 1,254 | 18,400 |
| 평균 지연 | 790 µs | 53 µs |
| 256MB 처리시간 | 204 ms | 3,560 ms |

### 해석

- 순차 I/O는 큰 블록을 한번에 옮기므로 BW(초당 전송량)가 압도적으로 높음 (대역폭 중심)
- 랜덤 I/O는 한번에 옮기는 양은 적지만(4KB), 요청 횟수(IOPS)가 훨씬 많음 → 디스크 위치 이동 오버헤드 때문에 같은 256MB를 처리하는데 17배 더 오래 걸림

### 그래서 디스크를 분리하는게 의미 있음

만약 같은 디스크를 같이 쓰면, 랜덤 I/O가 디스크 헤드를 계속 움직이게 만들어 순차 I/O 작업까지 느려지는 I/O 경합이 발생

---

## 실습 문제1 : DISK C → /home 분리 + Quota

### 1) 가상 디스크 생성 & LVM (Disk A와 동일 패턴)

<img width="646" height="348" alt="image" src="https://github.com/user-attachments/assets/3bfd9e15-3f99-4d73-9fc7-38d1707ee7fd" />

2GB 전체를 lv_home 으로 할당 (확장 실습은 이미 디스크 B에서 했으므로 여기선 100% 사용).

### 2) fstab 등록 (quota 옵션 추가)

<img width="797" height="71" alt="image" src="https://github.com/user-attachments/assets/d836785a-4025-4333-84eb-dba0e5f15aac" />

<img width="772" height="157" alt="image" src="https://github.com/user-attachments/assets/ef0d512c-6cc7-4914-b62e-e374c35e7c0f" />

usrquota,grpquota 옵션 : 이 마운트 지점에서 사용자별/그룹별 용량 제한 기능을 커널이 활성화하도록 지시

참고: 실제로는 /home 을 직접 교체하지 않고 /mnt/home_quota 라는 별도 위치에 만듦. ( /home 을 직접 바꾸면 현재 로그인된 계정 충돌 위험이 있어서 회피)

### 3) Quota 시스템 활성화

<img width="1007" height="305" alt="image" src="https://github.com/user-attachments/assets/3050a703-75a2-4d28-a2f9-703e210a315c" />


quota 데이터베이스(사용량 기록 파일)를 생성/스캔 후, 해당 마운트 지점에서 quota 기능을 실제로 켬

### 4) 테스트 사용자에게 용량 제한 부여

<img width="755" height="62" alt="image" src="https://github.com/user-attachments/assets/62514871-93d2-4b5c-8596-4bd20839f43f" />

(잘못 만들어서 student10으로 경로 수정)

student10 이라는 사용자를 새로 생성.

- -d 경로 : 홈 디렉토리 위치를 /mnt/home_quota/student1 로 지정 (즉, Quota가 걸린 디스크 C 위에 홈을 둠)
- -m : 홈 디렉토리가 없으면 자동 생성

<img width="755" height="218" alt="image" src="https://github.com/user-attachments/assets/00474354-fb47-401f-b9e9-b67e09f486a1" />


student1 에게 디스크 C( /mnt/home_quota )에서의 용량 제한을 설정.

인자 순서: soft블록 hard블록 soft아이노드 hard아이노드

- 100M (soft): 이 용량을 넘으면 경고만 뜸, grace 기간 동안은 계속 쓸 수 있음
- 120M (hard): 이 용량을 넘으면 즉시 쓰기 차단
- 0 0 : 파일 개수(inode) 제한은 안 둠

### 5) 한계 동작 테스트

<img width="750" height="195" alt="image" src="https://github.com/user-attachments/assets/1230360f-d9b8-4005-adc8-58a3236be7d9" />


150MB짜리 파일을 만들어보는 테스트.

hard 한도(120M)를 넘기 때문에 "Disk quota exceeded" 에러가 발생하며 120MB 부근에서 쓰기가 강제 중단됨.

---

## 실습문제2: WSL 재부팅 대응 - 자동 복구 스크립트

### 왜 필요한가?

WSL을 재시작하면 pvcreate / vgcreate / lvcreate 로 만든 구조 정보 자체는 디스크 이미지 파일 안에 남아있지만,

loop 디바이스 연결( losetup )은 매번 끊어짐.

그래서 재부팅할 때마다 수동으로 다시 연결해줘야 하는데, 이를 스크립트로 자동화.

<img width="448" height="557" alt="image" src="https://github.com/user-attachments/assets/a8b4712d-5373-4b68-a19a-917edc7cb209" />


- losetup -a 는 현재 연결된 모든 loop 디바이스 목록을 출력
  - 그 안에 disk_a.img 라는 문자열이 없으면( ! grep -q ) 아직 연결 안 된 것이므로 새로 연결
  - 이미 연결돼 있으면 중복 연결 방지
- vgchange -ay 는 모든 볼륨 그룹을 활성화(activate)시킴
  - loop 디바이스가 다시 연결돼도 LVM이 그 위의 PV/VG/LV 구조를 자동으로 인식하지 못할 수 있어서, 이 명령으로 강제로 활성화
  - → /dev/vg_xxx/lv_xxx 경로들이 다시 나타남
- fstab에 등록해둔 항목들( /mnt/mysql_data , /mnt/home_quota )을 자동 마운트
- 디스크들이 다 준비된 후에 Docker 서비스와 mysql 컨테이너를 시작
  - 순서가 중요 - 디스크가 마운트되기 전에 시작하면 데이터 접근 실패

---

## 실습 회고

### 실습 내용

1. LVM(Logical Volume Manager) 구성
   - disk_a.img, disk_b.img, disk_c.img 생성
   - loop 디바이스 연결
   - PV(Physical Volume) 생성
   - VG(Volume Group) 생성
   - LV(Logical Volume) 생성
   - ext4 파일 시스템 생성
   - 마운트 및 fstab 등록

2. Docker + MySQL 데이터 영속화
   - LVM 볼륨을 /mnt/mysql_data로 마운트
   - Docker MySQL 컨테이너의 데이터 디렉터리를 LVM에 연결
   - WSL 재부팅 후에도 데이터 유지 확인

3. 사용자 Quota 실습
   - vg_home / lv_home 생성
   - quota 옵션으로 마운트
   - 사용자 홈 디렉터리 생성
   - 디스크 사용량 제한 설정

4. WSL 재시작 대응 자동 복구 스크립트 작성
   - loop 디바이스 자동 연결
   - VG 활성화
   - 마운트 복구
   - Docker 및 컨테이너 자동 시작

---

## 발생한 문제

WSL 재부팅 후 Docker가 정상적으로 동작하지 않음.

### 증상

docker compose up -d 실행 시

```
failed to connect to the docker API at unix:///var/run/docker.sock
```

Docker 서비스 상태 확인

```bash
sudo systemctl status docker
```

결과:

```
Active: inactive (dead)
```

containerd 서비스도 시작되지 않음

```bash
sudo systemctl start containerd
```

실행 시 계속 멈추거나 취소됨.

---

## 원인 분석

### 1. Docker 데이터 일부 손상

Docker 로그 확인

```bash
sudo journalctl -u docker -n 50 --no-pager
```

오류:

```
RW layer for container not found
RWLayer of container is unexpectedly nil
```

기존 컨테이너의 OverlayFS 레이어 정보가 유실됨.

### 2. WSL 부팅 시 fstab 오류

WSL 실행 시

```
wsl: Processing /etc/fstab with mount -a failed.
```

오류 발생.

확인 결과

```bash
cat /etc/fstab
```

```
UUID=70604d6d-984d-4627-bad5-ecf4a4d1330b /mnt/mysql_data ext4 defaults,noatime 0 2
```

존재하지 않는 UUID를 자동 마운트하려고 시도하고 있었음.

### 3. systemd 정상 동작 방해

fstab 오류 때문에

```
WSL 부팅
→ fstab 오류
→ systemd 비정상
→ containerd 시작 실패
→ docker 시작 실패
```

연쇄적으로 발생.

---

## 해결 과정

### 1. fstab 항목 비활성화

```bash
sudo nano /etc/fstab
```

수정

```
# UUID=70604d6d-984d-4627-bad5-ecf4a4d1330b /mnt/mysql_data ext4 defaults,noatime 0 2
```

### 2. WSL 완전 재시작

Windows PowerShell

```powershell
wsl --shutdown
```

다시 WSL 실행

### 3. systemd 상태 확인

```bash
systemctl is-system-running
```

결과

```
running
```

### 4. Docker 재설치

기존 패키지 제거

```bash
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo apt autoremove -y
```

재설치

```bash
sudo apt install -y \
docker-ce \
docker-ce-cli \
containerd.io \
docker-buildx-plugin \
docker-compose-plugin
```

### 5. containerd 시작 확인

```bash
sudo systemctl start containerd
```

상태 확인

```bash
sudo systemctl status containerd
```

결과

```
Active: active (running)
```

### 6. Docker 시작 확인

```bash
sudo systemctl start docker

docker version
```

정상 동작 확인.

---

## 7주차 기준 Docker 환경 복구

### 실행 컨테이너

```yaml
my-nginx
  image: nginx:latest
  port : 8080:80

stress-nginx
  image: nginx:alpine
  port : 8081:80
```

### 실행 확인

```bash
docker ps
```

결과

```
my-nginx      nginx:latest   8080->80
stress-nginx  nginx:alpine   8081->80
```

---

## 최종 결론

문제의 핵심 원인은 Docker 자체가 아니라 WSL의 fstab 설정 오류였다.

```
잘못된 UUID 자동 마운트
→ WSL 부팅 오류
→ systemd 비정상
→ containerd 시작 실패
→ Docker 시작 실패
```

fstab 수정 후 WSL 재시작 및 Docker 재설치를 통해 정상 복구 완료.
