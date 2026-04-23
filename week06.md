# 운영체제 6주차 - 프로세스 스케줄링

## 서버 트렌드 이해 - 프로세스 스케줄링

### 프로세스 스케줄링

> 컴퓨터에는 동시에 수십~수백 개의 프로세스가 실행되는데, 이걸 어떻게 CPU에 배분할지 결정하는 것 (CPU는 한정된 자원)

---

### 컨텍스트 스위칭

CPU가 프로세스 A를 처리하다가 B로 넘어갈 때, A의 **현재 상태(레지스터, 카운터 등)를 저장**하고 B 상태를 불러오는 작업

```
Process 1 실행 -> 잠깐 멈춤 -> 상태 저장 (PCB에)
-> Process 2 불러옴 -> Process 2 실행
-> 다시 Process 1 상태 복원 -> 이어서 실행
```

### PCB (Process Control Block)

프로세스의 **신분증** 같은 것

- PS 상태 (실행중/대기중 등)
- 실제 레지스터 값
- 프로그램 카운터(어디까지 실행했는지) 등을 저장

---

### 스케줄링의 3가지 목표

| 목표 | 의미 |
|------|------|
| **공평성** | 모든 프로세스가 자원을 공평하게 배정받아야 함 |
| **효율성** | CPU가 놀지 않고 항상 일하도록, 중요한 프로세스 우선 |
| **안정성** | 악성 프로세스가 자원을 독점/파괴하지 못하게 보호 |

---

### 리눅스 스케줄러 종류

리눅스에는 목적에 따라 다른 스케줄러가 존재함.

#### RT(실시간) 스케줄러 - 실시간성이 중요한 작업에 사용

| 정책 | 특징 |
|------|------|
| `SCHED_FIFO` | 선점 없음. 일단 CPU 잡으면 자발적으로 양보할 때까지 독점 |
| `SCHED_RR` | 타임슬라이스(시간 조각) 사용. 같은 우선순위끼리 돌아가며 실행 |
| `SCHED_DEADLINE` | 마감시간 기반. 데드라인 가장 가까운 작업 먼저 실행 |

#### 일반 프로세스 스케줄러 → CFS (우리가 쓰는 대부분의 프로그램)

| 정책 | 특징 |
|------|------|
| `SCHED_OTHER` | 기본값. CFS로 공정 분배 (가장 일반적) |
| `SCHED_BATCH` | 배치 작업용. 인터랙티브 작업보다 처리량 우선 |
| `SCHED_IDLE` | 최저 우선순위. CPU 완전 유휴 시에만 실행 |

---

### CFS (Complete Fair Scheduler)

리눅스 2.6.23 이후 기본 스케줄러

#### vruntime (가상 실행 시간) 개념

```
vruntime = 실제로 CPU를 사용한 시간
           (우선순위가 낮을수록 더 빠르게 증가)
```

CFS는 **vruntime이 가장 낮은 프로세스**를 다음에 실행함
→ CPU를 가장 적게 쓴 애를 먼저 실행해서 **공평하게** 만드는 원리

#### nice 값

```
nice 값:  -20 ──────────── 0 ──────────── +19
            ↑                               ↑
         우선순위 높음                   우선순위 낮음
      (vruntime 천천히 증가)          (vruntime 빨리 증가)
```

- `nice -20`: "나 중요해! 나 먼저 써줘"
- `nice +19`: "나 별로 안 급해, 나중에 줘도 돼"

#### CFS가 공평성/효율성/안정성을 해결하는 방법

| 문제 | CFS 해결책 |
|------|-----------|
| 공평성 | vruntime이 낮은 순서대로 실행 → 모두 비슷하게 CPU 사용 |
| 효율성 | Red-Black Tree(정렬된 트리)로 가장 낮은 vruntime을 O(log n)으로 빠르게 찾음 |
| 안정성 | CPU 독점 방지 (한 프로세스가 계속 쓰면 vruntime이 올라가서 자동으로 밀려남) |

#### 전체 흐름 요약

```
새 프로세스 생성
↓
대기 큐에 들어감 (vruntime 기록)
↓
CFS: "vruntime 제일 낮은 놈 누구야?" → 그 프로세스 실행
↓
실행하면 vruntime 증가
↓
다른 프로세스의 vruntime이 더 낮아지면 → 컨텍스트 스위치
↓
반복 → 결과적으로 모두 공평하게 CPU 사용
```

---

## 프로세스 우선순위 확인 - ps와 top의 차이

### 1. `ps -al`로 확인

```bash
ps -al
```
<img width="771" height="125" alt="image" src="https://github.com/user-attachments/assets/d4cd3351-cce6-4670-a68f-6c2b2517c499" />

- PRI 80, NI 0이 기본값

### 2. `top`으로 확인

```bash
top
```
<img width="898" height="304" alt="image" src="https://github.com/user-attachments/assets/b8d05e83-b019-4b28-b6fe-8de5ce8f5a81" />

- PR 20, NI 0이 기본값

### ⚠️ 왜 ps는 80이고 top은 20인가?

- **ps의 PRI = top의 PR + 60** (표현 방식이 다를 뿐, 같은 프로세스)
- ps → PRI 80 (낮을수록 높은 우선순위, 기준점이 60)
- top → PR 20 (낮을수록 높은 우선순위, 기준점이 0)
- 실제 내부 우선순위 계산: `top 기준: PR = 20 + NI값`

---

## nice로 우선순위 직접 바꿔보기

### 실습: nice 15로 sleep 실행

`sleep` 명령어는 지정한 시간만큼 아무것도 안 하고 대기하는 명령어.  
sleep은 CPU를 거의 안 쓰기 때문에 우선순위 실습용 더미 프로세스로 사용.

```bash
# nice 15 = 낮은 우선순위로 sleep 300초 실행 (백그라운드)
nice -n 15 sleep 300 &

# ps로 확인 → PRI: 95, NI: 15 (ps 기준 80+15=95)
ps -al

# top으로 확인 → PR: 35, NI: 15 (top 기준 20+15)
top
```

<img width="846" height="150" alt="image" src="https://github.com/user-attachments/assets/f4673965-d770-44aa-9ed3-bca3e5f8dba2" />

<img width="968" height="359" alt="image" src="https://github.com/user-attachments/assets/e37579db-8390-4bf5-803f-3749f3967ed4" />

> CPU가 바쁠 때(부하상태): nice 0 프로세스가 먼저 CPU를 받고, nice 15 프로세스는 뒤로 밀려서 sleep 종료가 지연됨

### 우선순위 높이기 (음수 nice, root 필요)

```bash
# 일반 사용자는 우선순위를 높일 수 없음 (에러 발생)
nice -n -15 sleep 300 &   # 실패

# root로 실행해야 가능
sudo nice -n -15 sleep 300 &   # 성공
```

<img width="841" height="315" alt="image" src="https://github.com/user-attachments/assets/a9e9f28c-be3f-4dc2-8a5a-5c5fb773ffcf" />


### 언제 nice를 쓰나?

컴파일/빌드 같은 무거운 작업을 백그라운드에서 낮은 우선순위로 돌릴 때 사용.  
서버가 다른 중요한 작업을 계속 잘 처리하도록 함.

---

## Docker에서 nice 0 vs nice 10 비교 실험

노트북마다 CPU 코어수가 달라서 비교가 어려우므로, `--cpuset-cpus="0"` 옵션으로 CPU 0번 코어 1개에만 고정시켜 공정한 비교를 진행.

### a. Docker 재실행 (0번 코어 고정)

```bash
# 기존 컨테이너 정지 및 삭제
docker stop stress-nginx
docker rm stress-nginx

# CPU 0번 코어만 쓰도록 재실행
docker run -d --name stress-nginx \
  --cpuset-cpus="0" \
  -p 8081:80 \
  nginx:alpine

# Docker에 stress-ng 설치
docker exec stress-nginx apk add --no-cache stress-ng
docker exec stress-nginx stress-ng --version
```

<img width="1780" height="530" alt="image" src="https://github.com/user-attachments/assets/7a774fda-67b9-4ba1-b5e5-b8ceef1d8f85" />


### b. 모니터링 터미널 준비 (터미널 1)

```bash
# 1초마다 stress 프로세스의 CPU 점유율 확인
watch -n 1 'ps -eo pid,ni,pcpu,comm --sort=-pcpu | grep stress | head -10'
```

### c. 비교 실험 실행 (터미널 2)

```bash
# nice 0 (기본 우선순위) - CPU 1개, 60초
docker exec stress-nginx sh -c 'nice -n 0  stress-ng --cpu 1 --timeout 60 &
                                 nice -n 10 stress-ng --cpu 1 --timeout 60 &'
```

### d. 결과 해석  
<img width="1454" height="181" alt="image" src="https://github.com/user-attachments/assets/240c42eb-0385-45a2-b4c8-e1cdfba5eaec" />

같은 작업인데 nice 10이 CPU를 훨씬 적게 받음  
→ CFS 스케줄러가 vruntime 기반으로 공정하게 배분한 결과  
→ nice 0이 우선순위가 높으니까 더 많이 받는 것

---

## RT(실시간) 프로세스 확인

```bash
# 현재 내 쉘의 스케줄링 정책 확인
chrt -p $$
# → 일반 사용자 프로세스는 모두 SCHED_OTHER (= CFS) 로 동작

# 모든 프로세스의 스케줄링 클래스 확인
ps -eo pid,class,rtprio,ni,pri,comm | head -30
# CLS를 보면 모든 프로세스가 TS (Time Sharing = CFS)
# WSL은 경량 커널이라 RT를 보장하지 않음
```
<img width="573" height="66" alt="image" src="https://github.com/user-attachments/assets/da9e5f2d-39fa-498b-8b54-f9c81bff900d" />

<img width="492" height="577" alt="image" src="https://github.com/user-attachments/assets/84c7515c-6010-427d-95a3-711c69f197e7" />

### RT vs 일반 프로세스 정리

| 구분 | 스케줄러 | nice 범위 | 설정 권한 | 예시 |
|------|----------|-----------|-----------|------|
| 일반 | CFS (SCHED_NORMAL) | -20 ~ +19 | 일반사용자: 0~+19만 가능 | 웹서버, DB, 대부분의 사용자 프로그램 |
| RT | SCHED_FIFO/RR | nice 없음 | root만 | 오디오/비디오, 실시간 제어 |

> RT는 root만 설정 가능하고, 일반 서버 운영에서는 거의 쓸 일이 없음

---

## ulimit으로 프로세스 개수 제한 (세션 제한)

### 1. 현재 제한 전체 확인

```bash
ulimit -a
```
<img width="650" height="384" alt="image" src="https://github.com/user-attachments/assets/d14e8231-82ac-4022-805b-d659bdbea51b" />

주요 항목:
- `max user processes (-u) 31205` : 이 사용자가 만들 수 있는 최대 프로세스 수
- `open files (-n) 10240` : 동시에 열 수 있는 파일/소켓 수
- `stack size (-s) 8192` : 스택 최대 크기

### 2. 현재 내가 쓰고 있는 프로세스 개수 확인

```bash
ps -u $USER --no-header | wc -l
```
<img width="816" height="55" alt="image" src="https://github.com/user-attachments/assets/24dd02f8-ce60-4287-bd3a-4af94ce602d1" />

### 3. 30개로 제한 설정

```bash
ulimit -u 30
```

### 4. 제한 초과 테스트

```bash
# 35개 백그라운드 프로세스 생성 시도
for i in $(seq 1 35); do
  sleep 300 &
  echo "생성 $i : PID=$!"
done

# 백그라운드에서 계속 실행 중인 job 확인
jobs
```
<img width="688" height="182" alt="image" src="https://github.com/user-attachments/assets/e04bf8b7-803a-466e-9cdd-59d5dcdd9a77" />

> `ulimit`은 **현재 터미널 세션에만** 적용됨. `exit`하면 제한이 사라짐

---

## limits.conf로 영구 제한 (사용자/그룹)

### 세션 제한 vs 영구 제한 차이

| 항목 | 세션 제한 (ulimit) | 영구 제한 (limits.conf) |
|------|-------------------|------------------------|
| 적용 범위 | 현재 터미널만 | 모든 새 로그인 세션 |
| 재시작 후 | 사라짐 | 유지됨 |
| 권한 | 일반 사용자 (낮추기만) | root 필요 |
| 언제 쓰나 | 긴급하게 빠르게 | 정책으로 영구 적용 |

### limits.conf 파일 수정 (영구 제한)

```bash
sudo nano /etc/security/limits.conf
```
<img width="482" height="100" alt="image" src="https://github.com/user-attachments/assets/81b276d1-edc2-429e-a04d-7052a498f6c0" />

(나는 student3으로 새로 생성함)  
```
# 사용자별 제한
student3  soft  nproc   10   # 현재 적용값: 10개
student3  hard  nproc   15   # 최대 한도: 15개 (root만 올릴 수 있음)
student3  soft  nofile  20   # 파일 오픈 현재 적용값: 20개
student3  hard  nofile  30   # 파일 오픈 최대 한도: 30개
```

### 적용 확인
```
# 다시 student3으로 전환 후 확인
su student3
ulimit -u   # 10 출력됨

# 35개 생성 스크립트 돌리면? → 10개 초과에서 에러!
for i in $(seq 1 35); do
  sleep 300 &
  echo "생성 $i : PID=$!"
done
```
<img width="450" height="48" alt="image" src="https://github.com/user-attachments/assets/798ccb20-3b82-4ed2-8121-0ac8016929e0" />

<img width="620" height="370" alt="image" src="https://github.com/user-attachments/assets/2ca1b52c-cbe1-4dad-a4a0-091104cb508e" />


### soft vs hard 개념

```
hard 한도 (절대 천장, root만 수정 가능)
    ↑
    | ← 사용자가 올릴 수 있는 범위
soft 한도 (현재 적용값)
    |
    | ← 사용자가 낮출 수 있는 범위
    ↓
    0
```


### 그룹 제한

```bash
sudo nano /etc/security/limits.conf

# @기호 붙이면 그룹 제한
@dev_team1  soft  nproc   15
@dev_team1  hard  nproc   30
@dev_team1  soft  nofile  50
```

### 개인 제한 vs 그룹 제한이 겹치면? → **개인 설정이 우선!**

- student3은 개인(soft 10) + 그룹(soft 15) 둘 다 해당 → **개인 설정인 10이 적용됨**
- student4는 그룹(soft 15)만 해당 → **그룹 설정인 15(soft)가 적용됨**

<img width="472" height="166" alt="image" src="https://github.com/user-attachments/assets/92998274-595a-4da7-b475-b3f634c07c82" />

---

## Docker 컨테이너 프로세스 & CPU 제한

### 1. 프로세스 개수 제한 (pids-limit)

```bash
# nginx 워커 프로세스 실시간 모니터링
watch -n 1 'docker exec stress-nginx ps -ef | grep nginx'
```

### 2. 웹 서버 부하 테스트

```bash
# ab (Apache Benchmark) 설치
sudo apt install -y apache2-utils

# 10000개 요청, 동시 1000명 접속
ab -n 10000 -c 1000 http://localhost:8081/
```
<img width="661" height="118" alt="image" src="https://github.com/user-attachments/assets/e466c1c1-3fd3-402f-bda2-ab80a2df8037" />

→ 실행 전과 똑같이 **워커 1개 고정**

**nginx 워커 프로세스 개수가 변하지 않는다.**

왜?
- nginx는 워커 프로세스 개수가 **CPU 코어 수**로 고정됨
- pids-limit으로는 nginx 워커를 제한 못함
- **CPU 점유율 자체를 제한해야 함!**

> `pids-limit`: 컨테이너 안에서 생성할 수 있는 최대 프로세스 수 제한  
> (예: `docker run --pids-limit 10 nginx:alpine`)

### Docker CPU 제한 옵션 정리

| 옵션 | 의미 | 예시 |
|------|------|------|
| `--cpus` | 최대 CPU 사용량 (코어 단위) | `--cpus="1.5"` = 최대 1.5코어 |
| `--cpuset-cpus` | 사용할 CPU 코어 고정 | `--cpuset-cpus="0-3"` = 0,1,2,3번만 |
| `--cpu-shares` | CPU 비중 (상대적) | 기본 1024, 2048이면 2배 |

```bash
# docker stats로 실시간 확인
docker stats stress-nginx
```
<img width="1142" height="80" alt="image" src="https://github.com/user-attachments/assets/ca231421-81c4-4c27-9aa5-462699fd1d43" />

---

## 커널 수준 프로세스 튜닝 (sysctl)

### 왜 필요한가?

```
nice       → 우선순위 조정은 되지만, 프로세스 개수/시간 제한 불가
ulimit     → 사용자/세션 단위 제한
limits.conf → 사용자/그룹 단위 영구 제한
```

이것들은 전부 **"사용자 레벨"** 제한.  
커널 자체의 동작 방식을 바꾸려면? → **sysctl**

> 비유: ulimit은 "이 직원은 하루 10개 업무만 해", sysctl은 "회사 전체 운영 규칙을 바꾸는 것"

### sysctl 기본 사용법

```bash
# 커널 설정 전체 보기
sudo sysctl -a

# 스케줄링 관련 항목만 필터링
sudo sysctl -a | grep -iE 'sched|pid_max|threads-max|nice|task_delay|cpu.cfs'
```
<img width="656" height="462" alt="image" src="https://github.com/user-attachments/assets/935f3633-a98b-443c-88cb-3adb8a138e2a" />

<img width="724" height="246" alt="image" src="https://github.com/user-attachments/assets/0a2136af-dc61-41f8-8215-7e9232a19d37" />

### 주요 커널 파라미터

**`kernel.pid_max = 4194304`**
- 시스템에서 동시에 사용할 수 있는 최대 PID 번호
- PID가 다 차면 → 새 프로세스 생성 불가 (서버 장애!)
- 컨테이너를 수백 개 돌리는 고부하 서버에서 늘려줌

**`kernel.threads-max = 62411`**
- 시스템 전체에서 동시에 실행 가능한 최대 스레드 수
- WSL에서는 메모리 양에 따라 자동 계산됨

**CFS 관련 (건드리지 말기)**

| 파라미터 | 값 | 설명 |
|---------|-----|------|
| `kernel.sched_cfs_bandwidth_slice_us` | 5000 | CFS가 한 번에 프로세스에게 주는 시간 조각 (5ms) |
| `kernel.sched_child_runs_first` | 0 | fork() 시 부모(0) vs 자식(1) 중 누가 먼저 실행되나 |

**RT(실시간) 관련**

| 파라미터 | 값 | 설명 |
|---------|-----|------|
| `kernel.sched_rr_timeslice_ms` | 100 | SCHED_RR 스케줄러의 타임슬라이스 (기본 100ms) |
| `kernel.sched_rt_period_us` | 1000000 | RT 프로세스 주기 (1초) |
| `kernel.sched_rt_runtime_us` | 950000 | RT 프로세스가 1초 중 사용 가능한 시간 (95%) |

> RT 프로세스가 CPU 100% 독점하는 것을 방지 (나머지 5%는 일반 프로세스용)

### 리눅스 배포판별 차이

| 배포판 | pid_max | threads-max | sched_latency_ns |
|--------|---------|-------------|------------------|
| Ubuntu 22.04 LTS | 4194304 | ~80k~300k | ~24ms |
| Ubuntu 24.04 | 4194304 | ~100k~500k | ~12~20ms |
| Fedora 40~42 | 4194304 | ~200k~1M | ~10~15ms |
| RHEL 9 / AlmaLinux 9 | 4194304 | ~300k~1M | ~20ms |
| Arch Linux (최신) | 4194304 | 매우 높음 | 최신 커널 최적화 |

- **서버용** (Ubuntu Server, RHEL, Rocky): pid_max 높음, 안정성 우선
- **데스크톱** (Ubuntu Desktop, Fedora): 응답성/UI 반응 우선
- **Arch Linux**: 항상 최신 커널, 성능 최적화되어 있지만 안정성 검증 덜함

---

## 실습 문제

### Nice 설정에 따른 Docker 프로세스 부하 분석


- 기존 Docker 정지 후 삭제  
  ```
  docker stop stress-nginx
  docker rm stress-nginx
  ```
  <img width="601" height="89" alt="image" src="https://github.com/user-attachments/assets/a1fb34cf-e81c-4ede-8746-fc773d928f09" />

- --privileged 옵션 추가하여 재실행 (음수 nice 사용 위해)  
  <img width="702" height="125" alt="image" src="https://github.com/user-attachments/assets/31790b85-667f-43aa-bbe3-c3eaf66c4f9f" />

- nice 0 vs nice -10 비교 (120초)
  ```
  docker exec stress-nginx sh -c '
  nice -n 0   stress-ng --cpu 1 --timeout 120 &
  nice -n -10 stress-ng --cpu 1 --timeout 120 &
  ```
- 1초마다 CPU 점유율 모니터링
  ```
  watch -n 1 'ps -eo pid,ni,pcpu,comm --sort=-pcpu | grep stress | head -10'
  ```
  <img width="358" height="136" alt="image" src="https://github.com/user-attachments/assets/3cbc8439-6cf1-4841-b2a7-0b72037bdd19" />

**결과**: nice -10이 더 높은 우선순위이므로 CPU 점유율이 더 높다. (최대 90% 정도)

---

### Docker 프로세스 CPU 점유율 제한
- 기본 Docker를 정지 후 삭제
  <img width="647" height="85" alt="image" src="https://github.com/user-attachments/assets/2ea9b7cc-4a05-4a0c-bbf5-6541134ef94a" />

  <img width="651" height="83" alt="image" src="https://github.com/user-attachments/assets/3ac7329d-5119-45f0-b897-3fa93356d62a" />

- 현재 내 Docker 설정 확인
  - 전체 논리 코어 개수는? **12개**
    <img width="461" height="49" alt="image" src="https://github.com/user-attachments/assets/7739dc6a-c80c-4245-943a-d9ca0613b362" />

  - 실행 중 컨테이너 개수는? **다 삭제해서 0개**
    <img width="716" height="56" alt="image" src="https://github.com/user-attachments/assets/6e16be58-a6fa-4e53-87e4-0982ed20e7e7" />

- 웹서버 전용 서버
  - 두 컨테이너 재실행
    <img width="1326" height="165" alt="image" src="https://github.com/user-attachments/assets/98d3b80c-50cd-43b9-aa3e-1022cb92aaa0" />

  **(전체 코어 비중 25%)**

  **`--cpuset-cpus="3-5”` : cpu 코어 3-5번 사용**

  **`--cpuset-cpus="6-8”` : cpu 코어 6-8번 사용**

  **`--cpus="3.0”` : 워커 프로세스 3개** 

  - 시스템/WSL/Docker 데몬 x 코어 (25%)  
  - My-web-proxy x 코어 (25%)  
  - stress-nginx x 코어 (25%)  
  - 여유/스파이크 대응 x 코어 (25%)

- 모니터링 결과를 캡쳐
  - 내부 worker 프로세스 개수
    <img width="849" height="201" alt="image" src="https://github.com/user-attachments/assets/a47d3ba2-733d-4a53-8b1f-168489645070" />

    워커가 각각 3개 → 할당된 코어수와 일치  
  - Ab 부하테스트 결과
    <img width="555" height="80" alt="image" src="https://github.com/user-attachments/assets/92b91daa-3f09-4a8c-85eb-ff33a66411e1" />
    <img width="578" height="84" alt="image" src="https://github.com/user-attachments/assets/5e688b8a-8ca1-4ca6-85e4-6e0362aad003" />


