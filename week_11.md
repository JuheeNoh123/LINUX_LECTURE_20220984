# 11주차

## 웹 서버 관리 - 1

### 서버 트렌드 이해

#### 컨테이너 오케스트레이션

**Docker Compose**

- 소규모용
- 기본 실행 자동화는 되지만 장애 복구, 스케일링은 수동
- dockerd가 root로 실행되어 보안 이슈 존재
- 2022년 Docker Desktop 유료화 이후 무료 대안 필요성 증가

**Kubernetes**

- 대규모 표준
- 멀티 노드
- 수백 수천 컨테이너를 완전 자동 배포, 복구, 스케일링 함
- 관리 난이도 매우 높음

#### AI/ML 분야 자원 관리 이슈

- GPU 단편화, 동적 스케줄링 부족
- 무거운 컨테이너 이미지, I/O 병목
- IP 고갈, 노드간 트래픽 비용
- → 아직 초기 시장, 다양한 도구 (kuberflow, Arfo, KServe 등)로 변화중

---

## 실습

GUI 기반 관리 도구 3종 학습:

- **Portainer**: Docker 컨테이너 관리
- **Netdata**: NGINX 웹 서버 모니터링
- **phpMyAdmin**: DB 관리 (이번엔 패스)

---

### Portainer

```bash
docker compose -f compose.manage.yaml up -d portainer
```

<img width="1007" height="131" alt="image" src="https://github.com/user-attachments/assets/150afc7a-d077-4bbb-a436-f03ba6b255b2" />


```bash
docker ps | grep portainer
```

#### Portainer UI 탐색

- **Containers**: wp_db, wp_app, wp_nginx, wp_portainer 상태 확인

<img width="857" height="625" alt="image" src="https://github.com/user-attachments/assets/5290ec6e-5233-491b-8d5a-b7b7df17d00b" />


- 컨테이너 클릭 → Inspect(JSON 정보), Stats(CPU/메모리 그래프), Logs(접근 로그)
- Restart / Stop / Start 버튼으로 컨테이너 제어 (CLI `docker restart` 와 동일)

<img width="830" height="537" alt="image" src="https://github.com/user-attachments/assets/75c2bb26-cb1c-4d44-9c3c-c114ab28d505" />


- **Volumes**: wordpress_wp_data, portainer_data
- **Images**: nginx:alpine, wordpress:php8.2-fpm, mysql:8.0 등 용량 비교
- **Networks**: wordpress_wp_net에 연결된 컨테이너 4개 확인
- **Stacks**: Compose 프로젝트 단위 관리

---

### Netdata (웹서버 모니터링)

#### NETDATA - 대시보드

- 기본: 로컬 System Overview
  - CPU 사용률 / 메모리 / Disk I/O / 네트워크 실시간 그래프

<img width="1918" height="853" alt="image" src="https://github.com/user-attachments/assets/40b1bfa0-9b31-4e08-a97b-5249c3fa0c9a" />


#### NETDATA - UI 탐색

- 상단 Nodes
  - 현재 로컬 서버의 성능 통계 확인
- 상단 Metrics 탭의 검색 (다양함)
  - **nginx**
    - active connections: 현재 연결수
    - request/sec : 초당 요청수
  - **Docker**
    - 섹션 컨테이너별 CPU / 메모리 사용량 비교

<img width="533" height="737" alt="image" src="https://github.com/user-attachments/assets/ea410d55-04c2-42ed-9977-0e0f8167f220" />


---

## Apache Bench (ab)로 부하 테스트

### 핵심 지표

| 지표 | 의미 |
|---|---|
| Requests per second (RPS) | 처리량 |
| Time per request | 평균 응답 시간 |
| Failed requests | 실패 요청 수 |

### 주요 옵션

| 옵션 | 설명 |
|---|---|
| -n | 총 요청 수 |
| -c | 동시 요청 수 |
| -t | 최대 테스트 시간(초) |
| -k | KeepAlive 활성화 |

---

## 부하 테스트 실험 및 결과 분석

### 실험1. 동적 페이지 부하 (index.php)

```bash
ab -n 2000 -c 50 http://localhost:8080/ &
```

| 컨테이너 | CPU | 해석 |
|---|---|---|
| wp_nginx | 0→9% | 이벤트 기반 비동기, 거의 부하 없음 (단순 전달) |
| wp_app | 0→420% | PHP-FPM 다중 프로세스 풀가동 (4코어 이상 사용, 병목 지점) |
| wp_db | 46.2% | SQL 쿼리 처리 |

<img width="472" height="242" alt="image" src="https://github.com/user-attachments/assets/39bb810b-8bfd-4beb-90d5-2f74eba414a2" />

<img width="652" height="342" alt="image" src="https://github.com/user-attachments/assets/ee5d3fc1-8917-4fc0-802f-90837bc387e3" />


### 핵심

php-fpm(406%) vs nginx(10.9%) → 약 37:1 비율.

PHP 처리가 압도적 병목, Nginx는 매우 효율적

### 요청 처리 흐름

- **wp_nginx (0→9%)**:
  - 요청을 받아 PHP-FPM에 전달만 함.
  - 이벤트 기반 비동기 구조라 거의 부하 없음
  - 정적 파일 캐싱, 연결 관리만 처리

- **wp_app (0→420%)**:
  - 실제 PHP 코드 실행
  - 템플릿 렌더링, DB 호출 처리
  - 다중 워커 프로세스로 4코어 이상 풀가동 → 병목 지점

- **wp_db (46.2%)**: wp_app 요청에 따라 SQL 쿼리 처리. PHP 렌더링보다는 가벼움

→ Nginx는 단순 전달자, PHP-FPM(wp_app)이 실제 일꾼이자 병목, DB는 보조 역할

---

### 실험2. 정적 이미지 부하

1. 워드프레스 관리자 /wp-admin에서 이미지 업로드 → URL 확인
2. `ab -t 30 -c 50 [이미지URL] &`

| 컨테이너 | CPU | Network | 해석 |
|---|---|---|---|
| wp_nginx | 160%→0% 급락 | RX 1GB→40GB | 정적 파일 직접 처리, 첫 요청만 디스크 읽기 후 즉시 종료 |
| wp_app | 60~70% (안정) | 큰 변화 없음 | URL 라우팅만 처리, 실제 파일 전송은 안 함 |

inode/네트워크: 이미지 요청 시 inode 사용량 급증, Inbound 44Gbit/s(WSL2 루프백 포함, 정상), 패킷 손실 0


---

## 동적 vs 정적 요청 비교 종합

| 항목 | 동적 요청 (index.php) | 정적 요청 (이미지) |
|---|---|---|
| wp_nginx CPU | 낮음(7.8%) | 매우 높음 (디스크 I/O·전송 전담) |
| wp_app CPU | 매우 높음(356%) | 최저(0~1%) |
| wp_db CPU | 완만(46%) | 0% |
| 결론 | PHP 처리가 병목 | Nginx가 정적 파일 효율적으로 직접 처리 |
