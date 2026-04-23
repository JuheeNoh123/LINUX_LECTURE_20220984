# 5주차

## 프로세스란?

> **소프트웨어(프로그램)가 메모리 위에 올라가서 실행되고 있는 상태**

프로그램은 디스크(HDD/SSD)에 저장된 정적 파일이지만, 실행되는 순간 OS가 이걸 메모리에 올리면서 **프로세스**가 됨

**프로세스 구성**

- **코드**: 실행할 명령어들
- **데이터:** 전역변수, 정적 데이터 등
- **저장(메모리)**: 힙(동적 할당), 스택(함수 호출 정보)

---

## ELF 실행 파일 구조 (리눅스 실행 파일 형식)

리눅스에서 실행 파일은 **ELF 형식** - 내부가 여러 섹션으로 나뉨

| 섹션 | 역할 |
| --- | --- |
| `.init` | 프로그램 시작 초기화 코드 |
| `.text` | 실제 실행 코드(읽기 전용) |
| `.rodata` | 읽기 전용 데이터(상수, 문자열 등) |
| `.data` | 초기화된 전역/정적 변수 (읽기/쓰기) |
| `.bss` | 초기화되지 않은 전역/정적 변수 |
| `.symtab` | 심볼 테이블 (디버깅용) |
| `.debug` | 디버깅 정보 |

---

## 리눅스 vs 윈도우 프로세스 비교

> 리눅스는 `fork()`로 자신을 복사해서 자식 프로세스를 만들고, `exec()`로 다른 프로그램을 실행하는 방식. 윈도우는 `CreateProcess()` 하나로 다 처리

| 구분 | 리눅스 | 윈도우 |
| --- | --- | --- |
| 생성함수 | `fork()` , `exec()` | `CreateProcess()` |
| 관리단위 | Task (프로세스/스레드 통합관리) | 프로세스 & 스레드 (명확히 구분) |
| 자원 소모 | 상대적으로 가볍고 빠름 | 생성 시 오버헤드가 상대적으로 큼 |
| 구조 | 트리(Tree) 계층 구조 | 독립적 구조 위주 |
| 실행환경 | CLI(터미널) 중심, 효율성 강조 | GUI 중심, 보안 및 격리 강조 |

---

## 서버 OS로서 리눅스가 좋은 이유

- **프로세스 중심 설계** → 대규모 요청 처리에 유리
- **최소 메모리 사용** → 자원 효율적
- **최소 장애 전파** → 한 프로세스가 죽어도 다른 프로세스에 영향 적음

### 리눅스의 단점 (예전 기준, 지금은 대부분 해결됨)

1. 공개 운영체제라 문제 발생 시 보상 없음
2. 한글 입출력 어려움
3. 기술지원 부족
4. 특정 하드웨어 지원 부족
5. 사용자의 숙련된 기술 요구

---

## 스레드와 서버 부하 분석

### 리눅스 NPTL (스레드 시스템)

> NPTL = Native POSIX Thread Library

**스레드**: 프로세스 안에서 실행되는 **작은 실행 단위.** 하나의 프로세스 안에 여러 스레드 존재 가능

**특징**

- **1:1 매핑 :** 스레드 하나 = 커널 실행 단위 하나 → 진짜 동시 실행 가능
- **다수 프로세스처럼 동작:** 여러 작업을 병렬로 처리
- **BUT 공유 메모리 방식 :** 같은 프로세스의 스레드끼리는 메모리를 공유함 (복사 X)
  - 장점 : 빠름
  - 단점: 하나의 메모리를 잘못 건들면 다같이 문제 생길 수 있음

**과거(리눅스 스레드) vs 현재(NPTL) 비교**

| 구분 | 과거 | 현재 |
| --- | --- | --- |
| 모델 | Many-to-One/Many-to-Many 혼합 | 1:1 매핑 |
| 관리 주체 | 별도의 매니저 스레드가 관리 | 커널이 직접 관리 |
| 확장성 | 스레드가 많아지면 성능 급격히 저하 | 수만 개 스레드도 효율적 처리 |
| 안정성 | 신호 처리 및 PID 관리가 불안정 | POSIX 표준 완벽 준수 |

### 서버 부하 및 최적화

서버가 느려지거나 문제가 생겼을 때 어디서 병목이 생겼는지 파악해야함.

**Load Average(평균 부하)가 높은 경우**

- CPU를 기다리는 프로세스가 너무 많다는 뜻
- 단순히 CPU 가 바쁜것과는 다름 (I/O 대기도 포함)

**메모리가 부족한 경우**

- 스왑 사용 증가 → 디스크를 메모리처럼 쓰게 됨 → 매우 느려짐

**프로세스 상태 분석 (R, D, S, Z)**

| **상태** | **의미** |
| --- | --- |
| **R (Running)** | 실행 중 또는 실행 대기 중 |
| **D (Uninterruptible Sleep)** | I/O 대기중 (디스크/네트워크 등) |
| **S (Sleep)** | 이벤트 대기 중 (일반적인 대기) |
| **Z (Zombie)** | 종료됐지만 부모가 회수 안 한 상태 |

D 상태가 많으면 → **디스크/네트워크 I/O 병목**

R 상태가 많으면 → **CPU 병목**

---

## 실습

> 목표 : 서버에서 문제가 생겼을 때, 지금 무슨 일이 벌어지고 있는지 읽고 원인을 찾는 능력

### 1. 지난 주 docker-compose 확인 및 nginx 추가 실행

지난주 도커 컴포즈로 실행중인 컨테이너가 살아있는지 확인하고 nginx 컨테이너를 하나 더 추가 실행한다.  
<img width="1465" height="126" alt="image" src="https://github.com/user-attachments/assets/1491fac6-cfab-4341-8a51-b529f9032990" />

- **지금 실행중인 nginx**
  - 지난주에 docker-compose로 만든 것 (80 포트)
  - 방금 만든 stress-nginx (8081포트)

---

### 2. 프로세스 확인 및 제어

> **서버에서 지금 뭐가 돌아가고 있는가? 어떤 구조로 연결되어있는가?**

#### ps 명령어로 전체 프로세스 확인

- `ps -ef` / `ps -aux` : **실행중인 모든 프로세스 목록 조회**
  - 차이점

    | 구분 | ps -ef | ps -aux |
    | --- | --- | --- |
    | 옵션 체계 | UNIX 스타일 (- 사용) | BSD 스타일 (대시 없음) |
    | 출력 기준 | 프로세스 중심 | 사용자 중심 |
    | 부모 PID 표시 | O | O |
    | CPU / 메모리 표시 | X | O |

<img width="1102" height="487" alt="image" src="https://github.com/user-attachments/assets/554011e4-56f7-4bf4-9ef6-0a433b9361bb" />


**출력 컬럼 의미**

- UID : 실행자
- PID : 프로세스 ID
  - 프로세스 고유 번호
  - 최상위는 0번, init(systemd)이 1번
- PPID : 부모 프로세스 ID
  - 이 번호로 누가 누구를 만들었는지 추적 가능
- TTY : 터미널 연결 여부. ?이면 터미널 없이 실행된 것 (데몬)

#### pstree로 프로세스 계층 구조 확인

```bash
pstree -p $(pgrep dockerd)
```
<img width="789" height="527" alt="image" src="https://github.com/user-attachments/assets/9ded0a53-4b0b-435a-bc4e-b34c75506842" />

- `pgrep dockerd` : docker의 PID를 숫자로 찾아줌
- `$()` : 괄호 안 명령어 결과를 인자로 넣어줌
- 결과적으로 **docker 프로세스만 트리**로 볼 수 있음
- 출력에서 {} 안에 있는 것들이 **NPTL 스레드.** (하나의 프로세스가 다수 스레드로 관리)

> 📌 **왜 프로세스 트리를 보는가?**
>
> `ps -ef`는 목록을 쭉 보여주는데, 관계가 한눈에 안 들어옴.
>
> `pstree`는 부모-자식 관계를 트리로 보여줘서 **"누가 누구를 실행했는지"** 바로 파악할 수 있음.
>
> ---
>
> `docker run`으로 nginx를 실행하면 단순히 nginx 하나만 뜨는 게 아님
>
> 트리를 파악해서
> - 문제가 생겼을 때 **어느 레이어에서 문제가 생겼는지** 알 수 있음
> - nginx가 죽었는지, docker가 죽었는지, containerd가 죽었는지 구분 가능
> - 어떤 프로세스를 재시작해야 하는지 판단 가능

#### docker-proxy 포트 확인

```bash
sudo ss -lnp | grep -E '612|618|1120|1127'
# ss -lnp : 현재 열려있는 포트와 어떤 프로세스가 사용중인지 보여줌
```
<img width="1784" height="133" alt="image" src="https://github.com/user-attachments/assets/47644660-29c6-4ff9-9f8b-9ed3def989be" />

docker 컨테이너 1개에 2개의 proxy가 활성화됨

- 0.0.0.0:8081, 0.0.0.0:8080 → IPv4 용 프록시
- [::]:8081, [::]:8080 → IPv6 용 프록시

> 📌 **그럼 docker-proxy 포트를 왜 확인하나?**
>
> → nginx가 실행됐다는 건 알겠는데, **외부에서 실제로 접근 가능한지**를 확인
>
> 외부 사용자 → 8081포트 → docker-proxy → nginx 컨테이너 80포트
>
> docker-proxy가 없거나 포트가 잘못 연결됐으면 nginx가 아무리 잘 돌아가도 외부에서 접근이 안 됨.
>
> ⇒ **"포트가 제대로 열려서 연결되어 있나?"** 를 확인

#### nginx 프로세스의 부모 확인

포트가 열려있는건 확인했고, 이제 nginx 프로세스가 어떤 구조로 동작하는지 확인해보자.

```bash
pstree -p | grep nginx
nproc
```
<img width="712" height="281" alt="image" src="https://github.com/user-attachments/assets/7a5944d9-bcd2-486e-9cec-fb56d4e13029" />

<img width="561" height="63" alt="image" src="https://github.com/user-attachments/assets/2f141631-3bf8-4e48-ac6e-0c98b3b6455a" />


- **마스터 1개 + worker 여러개 구조 → worker 수를 조정해서 성능을 튜닝할 수 있음**
- **그 아래 nginx들 = worker 프로세스** (실제 요청 처리)
- `containerd-shim` : docker가 컨테이너를 관리하는 중간 프로세스
  - 컨테이너 1개당 shim 1개가 붙어서 그 컨테이너의 생명 주기를 관리

> 📌 **nginx 안에 worker가 여러 개인 이유?**
>
> **→ 요청을 동시에 여러 개 처리**하기 위해서
>
> 그리고 worker 개수는 기본적으로 **CPU 논리 코어 수**와 **같다.**
>
> 왜?
> - CPU 코어가 8개인데 worker가 1개면 → 코어 7개가 놀고 있음 (비효율)
> - CPU 코어가 8개인데 worker가 100개면 → 코어 하나가 worker 여러 개를 번갈아 처리해야 해서 오히려 느려짐
> - 코어 수 = worker 수가 가장 효율적

#### 컨테이너 내부에서 프로세스 확인

```bash
docker ps #현재 실행 중인 컨테이너 목록과 ID 확인
docker exec 컨테이너ID ps -ef #컨테이너 내부의 프로세스 목록을 외부에서 확인
```
<img width="695" height="401" alt="image" src="https://github.com/user-attachments/assets/20771c12-7438-42d2-a883-c926538a33b9" />


**호스트에서 보이는 PID 번호와 컨테이너 안에서 보이는 PID 번호가 다름.**

**중요한점** : 컨테이너는 격리된 공간이라 **내부에서는 PID가 1번부터 다시 시작함.**

```bash
# 컨테이너 밖에서 kill할 때 → 호스트 PID 사용
kill -9 599

# 컨테이너 안에서 kill할 때 → 내부 PID 사용
docker exec stress-nginx kill -9 1
```

#### 프로세스 종류

**종류에 따라 종료하는 방법이 다르다.**

| 구분 | TTY 연결 | 부모PID | 종료 방식 | 대표 예시 | 관리 명령어 |
| --- | --- | --- | --- | --- | --- |
| 포그라운드 | O | 현재 쉘 | **Ctrl + C** | top, vim, bash | - |
| 백그라운드 | O | 현재 쉘 | **kill, jobs** | sleep 1000 & | jobs, fg, bg |
| 데몬 | X | 1 (systemd) | **systemctl stop, kill -9** | sshd, crond, dockerd | systemctl status |
| 서비스 | X | 1 (systemd) | **systemctl restart/stop** | docker.service, nginx | systemctl start/enable |

- **포그라운드** : 터미널을 점유하고 실행되는 프로세스. 실행 중엔 다른 명령어 입력 불가.
- **백그라운드** : 터미널을 점유하지 않고 뒤에서 실행. 명령어 뒤에 `&` 붙이면 백그라운드로 실행
- **데몬** : 터미널과 아예 분리되어 시스템 시작부터 계속 돌아가는 프로세스. 부모가 init(1).
- **서비스** : 데몬을 systemd가 관리하는 단위. `systemctl`로 제어함. 윈도우의 서비스 탭과 비슷함.

#### 서비스 목록 및 상태 확인

docker 같은 서비스는 단순히 프로세스 하나가 아니라 systemd가 관리하는 단위이다.

`systemctl status`로 보면 단순 실행 여부뿐 아니라 언제 시작됐는지, 하위 프로세스가 몇 개인지, 최근 로그까지 한눈에 볼 수 있다.

```bash
#현재 실행 중인 모든 서비스 목록 확인
systemctl list-units --type=service

#docker 서비스의 자세한 상태 확인 (실행 중인지, 언제 시작됐는지, 하위 프로세스 등)
systemctl status docker
```
<img width="1162" height="455" alt="image" src="https://github.com/user-attachments/assets/bfa6f5a5-3e49-4dac-b6f0-d8c2639cffab" />

- 지금 도커, nginx가 실제로 서비스로 등록되어 있음을 확인할 수 있다.
- 부팅할 때 자동으로 켜짐

<img width="1169" height="541" alt="image" src="https://github.com/user-attachments/assets/5faf6e06-15f6-4ea8-84a1-312831a470c3" />

- 서비스 하위 4개 프록시가 있음.

#### 실시간 모니터링: top & htop

`ps -ef`는 **그 순간의 스냅샷**임.

근데 서버 문제는 대부분 시간이 지나면서 나타난다.

`top`과 `htop`은 실시간으로 계속 갱신되니까
**"지금 이 순간 어떤 프로세스가 CPU를 얼마나 쓰는지"** 바로 볼 수 있다.
(윈도우 작업 관리자와 같은 역할)

```bash
docker top stress-nginx
sudo apt install htop
htop
```

<img width="1790" height="126" alt="image" src="https://github.com/user-attachments/assets/7453d0d3-5c84-46a6-a6e3-8c499e2de76c" />

<img width="1769" height="594" alt="image" src="https://github.com/user-attachments/assets/140193bf-cbf1-474e-9ebf-75da430c5cdc" />

---

### 3. 프로세스 상태와 시그널

> **프로세스가 지금 정상인지 비정상인지 판단하고, 필요할 때 제어하는 방법**
>
> 2에서 프로세스 구조를 파악했다면, 이제 각 프로세스의 상태가 정상인지 확인해보자. 그리고 문제가 있는 프로세스를 어떻게 종료하거나 제어하는지 보자.

#### 프로세스 상태코드 이해

```bash
ps aux
```

<img width="929" height="485" alt="image" src="https://github.com/user-attachments/assets/9478235e-8ca1-4a13-94bd-bedadb3fcd1a" />

STAT 컬럼 확인

| **코드** | **의미** | **서버 관리 관점** |
| --- | --- | --- |
| **R** | Running | CPU 사용 중 → 정상 |
| **S** | Sleeping | I/O 대기 → 대부분 정상 (가장 많음) |
| **D** | Uninterruptible sleep | 디스크 I/O 대기 → **위험 신호** |
| **Z** | Zombie | 종료됐는데 회수 안 함 → **비정상** |
| **T** | Stopped | 일시 정지 상태 |

서버가 느릴 때 증상만 보고 틀린 곳을 고치는 실수를 방지하기 위해 확인해야한다.

CPU 사용률은 낮은데 서버가 느리다 → ps aux로 확인
→ D 상태가 많다 → 디스크나 네트워크가 병목
→ CPU 업그레이드해봤자 소용없음, 디스크/네트워크를 봐야 함

Z 상태가 수천 개 쌓여 있다 → PID 고갈 위험
→ 새 프로세스를 아예 못 만드는 심각한 상황 발생 가능
→ 프로그램 코드에 wait() 누락 버그가 있는 것

**추가 코드 (STAT에 붙어서 나옴)**

| 코드 | 의미 | 설명 |
| --- | --- | --- |
| s | Session leader | 세션의 리더 (bash, init, tmux 등) |
| l | Multi-threaded | 멀티스레드 프로세스 (NPTL 사용) |
| < | High priority | 우선순위 높음 |
| + | Foreground | Ctrl+C로 kill 가능 |
| N | Low priority | 우선순위 낮음 |

#### 좀비 프로세스 실습

Z 상태 프로세스를 만났을 때, 이게 뭔지 왜 생겼는지 어떻게 없애는지 직접 만들어보며 이해해보자

**C코드 작성**

<img width="638" height="460" alt="image" src="https://github.com/user-attachments/assets/5642328c-7b08-451f-8872-9a06b0f90242" />


```c
[코드 흐름]

부모가 fork()로 자식을 복제해서 만든다
        ↓
자식이 3초 후 _exit(0)으로 종료
        ↓
커널: 자식의 종료 상태(exit code)를 PCB에 남겨둔다
     (부모가 wait()로 수거해야 하는데 이 코드엔 wait()가 없다)
        ↓
부모: while(1) sleep(1)로 무한 대기만 한다 (wait() 안 부름)
        ↓
자식: 메모리는 해제됐지만 PID만 남아있는 좀비(Z) 상태로 영원히 존재
```

**왜 좀비가 위험한가?**

- 당장은 메모리를 안 먹어서 괜찮아 보여도
- 이게 수천 개 쌓이면 PID가 고갈됨
- PID가 고갈되면 새 프로세스를 아예 못 만듦 → 서버 마비

**컨테이너 내부 복사**

```bash
docker cp make_zombie.c stress-nginx:/tmp/make_zombie.c
```

**왜 컨테이너 안에서 하나?** 좀비 프로세스는 호스트에서 만들면 실제 시스템에 영향을 줄 수 있음. 컨테이너 안에서 하면 격리된 환경이라 안전하게 실험할 수 있음.

**컨테이너 내부 접속**

```bash
docker exec -it stress-nginx sh
cd tmp/
cat make_zombie.c
chmod +x /tmp/make_zombie.c #실행 권한 부여
```

**gcc 설치 및 컴파일**

```bash
apk update
apk add gcc musl-dev

gcc make_zombie.c -o zombie
./zombie &
```
<img width="386" height="135" alt="image" src="https://github.com/user-attachments/assets/712f6f53-36c0-4771-af94-f0fd58f6c989" />


**좀비 프로세스 확인**

- 컨테이너 내부:

```bash
ps -o pid,user,comm,stat | grep Z
```

<img width="431" height="56" alt="image" src="https://github.com/user-attachments/assets/bbbe8c3a-e763-48dd-801a-a15b8109b995" />

- WSL 새창에서 외부 확인

```bash
docker top stress-nginx -o pid,ppid,stat,comm #호스트가 OS 컨테이너 안을 들여다 보는 방식 (PID도 호스트 기준으로 표시)
docker exec -it stress-nginx ps -o pid,ppid,stat,comm #컨테이너 안에 직접 들어가서 ps를 실행하는 방식
```

<img width="898" height="280" alt="image" src="https://github.com/user-attachments/assets/f17af7e9-b793-4c66-9d90-e55462a7318d" />

⇒ **흥미로운 점:** 내부에서는 `Z`로 보이지만 외부(호스트)에서는 `S`로 보임.

왜?
→ 호스트 커널이 컨테이너 내부 상태를 그대로 반영하지 않기 때문 (컨테이너 격리의 특성)

#### 포그라운드/백그라운드 전환

> 실무에서 뭔가를 실행했는데 터미널이 block 되거나, 반대로 백그라운드에서 돌고 있는걸 잠깐 앞으로 가져와야할 때 자주 쓰는 기술

```bash
jobs -l # 현재 쉘에서 실행 중인 백그라운드/정지된 작업 목록 확인
kill -STOP %1 # 1번 작업 일시 정지 (Ctrl+Z와 동일). 상태가 T로 변경됨.
bg %1 # 정지된 1번 작업을 백그라운드에서 다시 실행. T → R로 상태 변경.
fg %1 # 백그라운드 1번 작업을 포그라운드로 가져오기. 이후 Ctrl+C로 종료 가능.
```

| 목적 | 명령어 | 비고 |
| --- | --- | --- |
| 목록 확인 | `jobs / jobs -l` | 현재 쉘 작업만 보여줌 |
| 정지된 작업 재시작 | `fg %n / bg %n` | T → R 상태 변경 |
| 작업 강제 종료 | `kill %n / kill -9 %n` | 부모 종료 → 좀비 회수 가능 |

<img width="449" height="265" alt="image" src="https://github.com/user-attachments/assets/5fcf2824-ea4a-4ead-94ed-e91b7eba24ea" />

**좀비 프로세스 종료**

- 컨테이너 내부에서 이름으로 종료:

  ```bash
  pkill -f zombie || true
  ```

  - `-f` : 명령어 전체 이름으로 검색
  - `|| true` : 이미 종료된 경우 오류가 나도 그냥 넘어감

- 외부에서 PID로 강제 종료:

  ```bash
  docker exec stress-nginx kill -9 PID번호
  ```

  **부모 프로세스를 강제 종료하면 좀비 자식도 자동으로 회수됨.**

#### 시그널 종류

| 번호 | 시그널 | 기본 처리 | 발생 조건 |
| --- | --- | --- | --- |
| 1 | SIGHUP | 종료 | 터미널 연결 끊어졌을 때 |
| 2 | SIGINT | 종료 | Ctrl+C |
| 9 | SIGKILL | 강제 종료 | **무시 불가** |
| 15 | SIGTERM | 정상 종료 | **무시 가능** |
| 19 | SIGSTOP | 정지 | SIGCONT 받을 때까지 정지 |
| 20 | SIGTSTP | 정지 | Ctrl+Z |
| 25 | SIGCONT | 재개 | 정지된 프로세스 실행 |

- **15번(SIGTERM)** → "정상 종료해줘" 요청.
  프로세스가 현재 작업을 마무리하고 깔끔하게 종료할 수 있음. 데이터 손실 없음.

- **9번(SIGKILL)** → "즉시 강제 종료".
  프로세스가 하던 작업이 있어도 그냥 죽음. 데이터 손실 가능성 있음.

#### kill vs pkill 비교

| 항목 | kill | pkill |
| --- | --- | --- |
| 기본 기능 | PID 직접 지정해서 종료 | 프로세스 이름/패턴으로 종료 |
| 사용 방식 | `kill [옵션] PID` | `pkill [옵션] 패턴` |
| 예시 | `kill 2539` / `kill -9 2539` | `pkill nginx` / `pkill -f make_zombie` |
| 실무 사용 | PID를 이미 알 때 | 이름으로 빠르게 여러 개 종료 |
| 대표 옵션 | `-9` (강제) / `-15` (정상) | `-f` (전체 명령어 매칭) / `-u` (특정 사용자) |

#### 종료 방법 3가지 비교

| 구분 | Ctrl+C | kill | pkill |
| --- | --- | --- | --- |
| 대상 지정 | 포그라운드 자동 | PID 직접 | 프로세스 이름 |
| 전송 시그널 | SIGINT(2) 고정 | 선택 가능 (기본 SIGTERM) | 선택 가능 (기본 SIGTERM) |
| 적용 범위 | 프로세스 그룹 전체 | 1개 (PID 기준) | 이름 매칭 전체 |
| 무시 가능 | 가능 | SIGKILL만 불가 | SIGKILL만 불가 |

위 방법이 모두 안 될 때 → `kill -9 PID`

---

### 4. 모니터링을 위한 부하 분석

> **"서버가 얼마나 힘든지 숫자로 읽고, 어디서 병목이 생기는지 찾는 방법"**
>
> 2~3에서 프로세스 구조와 상태를 파악했다면, 이제 서버 전체가 얼마나 부하를 받고 있는지 **수치로 판단해보자**

#### 평균 부하 분석

```bash
uptime
```
<img width="613" height="45" alt="image" src="https://github.com/user-attachments/assets/334c137d-1db5-4f15-b952-ebc54abbc533" />

| 순서 | 예시 값 | 설명 |
| --- | --- | --- |
| 1 | `14:30:45` | 현재 시각 |
| 2 | `up` | 부팅 이후 계속 실행 중 |
| 3 | `5 days, 3:12` | 마지막 부팅 이후 경과 시간 |
| 4 | `2 users` | 현재 로그인한 세션 수 |
| 5 | `load average:` | 시스템 부하 평균 |
| 6 | `0.45` | **지난 1분** 평균 대기 프로세스 수 |
| 7 | `0.32` | **지난 5분** 평균 대기 프로세스 수 |
| 8 | `0.28` | **지난 15분** 평균 대기 프로세스 수 |

**Load Average 해석 (CPU 싱글코어 기준):**

- `1.0` → CPU 100% 활용 중
- `0.5` → CPU 50% 활용
- `1.7` → CPU 170%, 과부하 상태
- 코어가 4개면 `4.0`까지는 여유 있음

**1분, 5분, 15분을 같이 보는 이유:**

```
1분값 > 15분값 → 부하가 점점 늘어나는 중 (위험 신호)
1분값 < 15분값 → 부하가 점점 줄어드는 중 (회복 중)
1분만 높고 15분은 낮다 → 일시적인 스파이크 (크게 걱정 안 해도 됨)
15분도 계속 높다 → 구조적인 문제 (원인 찾아야 함)
```

> Load Average는 EMA(지수이동평균) 방식으로 계산함
>
> 단순 평균이 아니라 최근 값에 더 가중치를 주는 방식

**`%CPU` 컬럼으로 실시간 CPU 사용률 확인**

```bash
top
```

대부분 0.0%면 여유로운 거임. 높으면 느려지지만 충돌은 안 남.

<img width="886" height="601" alt="image" src="https://github.com/user-attachments/assets/7994d127-1112-492c-9f5d-b18a6932c7d8" />

#### Docker 컨테이너 부하 분석

```bash
docker top stress-nginx -o pid,ppid,pcpu,comm
```

<img width="812" height="84" alt="image" src="https://github.com/user-attachments/assets/a151a231-34a0-4a5b-9ff4-c1f3029c1c5c" />

`docker stats`는 컨테이너 전체 수치만 보여줌. 컨테이너 안에서 **어떤 프로세스가 CPU를 많이 쓰는지** 개별로 확인할 때 사용

상위가 마스터, 하위가 워커 프로세스

```bash
docker exec stress-nginx top
```

컨테이너 내부에서 직접 top 실행. worker들이 대부분 S(대기) 상태면 자원 소모가 적어서 정상

<img width="824" height="461" alt="image" src="https://github.com/user-attachments/assets/3ab9e834-4fb7-4df1-a23b-86f29c98c36a" />

```bash
docker stats #현재 도커 상태 확인
```
<img width="1131" height="77" alt="image" src="https://github.com/user-attachments/assets/e39c389b-ae5d-478e-9ed9-ae2ad6427933" />

→ 현재 실행 중인 모든 컨테이너의 CPU%, 메모리, 네트워크 I/O를 한눈에 봐서 어떤 컨테이너가 자원을 과하게 쓰는지 바로 파악할 수 있음

#### 인위적으로 부하 만들기

```bash
docker exec -it stress-nginx sh
apk add stress-ng
stress-ng --cpu 8 --timeout 60s &
```

- `--cpu 8` : 논리 CPU 8개를 100% 풀로드로 사용
- `--timeout 60s` : 60초 동안만 실행
- `&` : 백그라운드로 실행해서 터미널 안 막히게

**부하상태 모니터링**

새 WSL 탭에서

```bash
#1초마다 프로세스별 CPU 사용률이 갱신
watch -n 1 docker top stress-nginx -o pid,ppid,pcpu,comm
```
<img width="774" height="502" alt="image" src="https://github.com/user-attachments/assets/599cff54-4577-4aea-ab9d-d13c942ae05c" />

**→ stress-ng 워커들이 pcpu 약 101~102%로 각 코어를 풀로 씀**

```bash
docker stats
```
<img width="1154" height="77" alt="image" src="https://github.com/user-attachments/assets/ffce67b9-3ccd-46a7-ab19-82b83d5fce41" />

8개 워커가 다 돌면 총 **800% 이상**으로 나온다. **1개 워커 = 100%** 기준

**컨테이너 내부 vs 외부 CPU% 차이**

내부에선 9% 정도로 나오는데 외부에서는 100%로 나옴

**왜 다른가?**

- 컨테이너 내부 top은 **자기 컨테이너 기준 100%** 로 계산해요
- 내 PC 논리 CPU 12개에서 8개 워커가 66%정도 사용
- 66.7% ÷ 8개 워커 = 약 8.3% ≈ 9%

> 📌
> - 컨테이너 안에서만 모니터링하면 실제 서버 자원을 얼마나 쓰는지 놓칠 수 있음
> - **외부에서 확인해야 실제 서버 전체 기준으로 정확한 수치**를 알 수 있음
>
> 결론:
> - 컨테이너 전체 자원 → `docker stats` (외부, 정확)
> - 컨테이너 내 개별 프로세스 → `docker top` (외부)
> - 컨테이너 내부 top → 상대적 수치라 부정확할 수 있음

---

## 실습 문제

- 도커 내부 워커 프로세스 제한
  - `vi /etc/nginx/nginx.conf`

    ```
    worker_processes auto;   ← 이걸
    worker_processes 4;      ← 이렇게 (원하는 숫자로) 수정
    ```
  <img width="785" height="546" alt="image" src="https://github.com/user-attachments/assets/db50f030-a6e9-4acf-b54c-336597f60da3" />

  <img width="982" height="290" alt="image" src="https://github.com/user-attachments/assets/cfc7f3d7-712c-4797-97c3-904baa2140f1" />

  4개로 잘 수정되었다.

- 워커 프로세스의 부하 전후 확인
  - 부하 전: docker stats로 CPU 사용률 확인
    <img width="1138" height="84" alt="image" src="https://github.com/user-attachments/assets/a82797eb-0cd7-48a4-b015-f51bfdae6057" />

  - 부하 후:

    ```bash
    stress-ng --cpu 4 --cpu-method rand --timeout 30s --metrics
    ```
    <img width="1152" height="86" alt="image" src="https://github.com/user-attachments/assets/4b362510-edd5-4d33-b0e5-6999d544f9bb" />

    <img width="1152" height="86" alt="image" src="https://github.com/user-attachments/assets/cad35a3c-b21e-4113-8150-57e001017ed6" />


---
## 내가 겪은 문제와 알게 된 것

### 1. pdf와 수치가 다르게 나온 이유

강사 PC는 논리 코어가 16개, 내 PC는 12개였다.
`stress-ng --cpu 8`로 8코어를 풀로드했을 때:

- PDF: worker 1개당 ~102% (16코어 중 8코어 사용)
- 나: worker 1개당 ~12% (12코어 중 8코어 사용)

코어 수가 다르면 같은 명령어를 실행해도 % 수치가 다르게 나온다.
수치가 달라도 실제 부하는 동일하다.

### 2. 컨테이너에 CPU가 1개만 할당된 문제
처음에 `docker stats`에서 100%밖에 안 나왔고,
nginx worker도 1개밖에 없었다.

원인: 컨테이너가 CPU를 1개만 인식하고 있었음

```bash
docker exec stress-nginx nproc  # 1이 나왔음
```

해결: 컨테이너를 삭제하고 CPU 제한 없이 다시 실행

```bash
docker stop stress-nginx
docker rm stress-nginx
docker run -d --name stress-nginx -p 8081:80 nginx:alpine
```

다시 실행 후 nproc이 12로 나오고 worker도 12개 생성됨.

### 3. 내부 vs 외부 모니터링 수치 차이

같은 WSL 터미널에서 입력해도 명령어에 따라 보는 시점이 달라진다.

| 명령어 | 시점 | 정확도 |
|--------|------|--------|
| `docker top stress-nginx` | 호스트 전체 기준 | 정확 |
| `docker stats` | 호스트 전체 기준 | 정확 |
| `docker exec stress-nginx top` | 컨테이너 내부 기준 | 상대적 수치 |

컨테이너 내부 top에서 각 worker가 ~9%로 나왔는데,  
이건 12코어 중 8코어 사용 = 66.7%, 8개 worker로 나누면 약 8.3%라서 맞는 수치였다.  

외부에서 확인하는 것이 실제 서버 자원 기준으로 정확하다.
