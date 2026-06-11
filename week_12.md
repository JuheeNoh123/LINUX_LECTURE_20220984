# 12주차

## 서버 트렌드 이해

### 1. 서버 보안 트렌드 (2026)

**웹보안: 실무 보안 필수 계층**

- **암호화**: 데이터 전송(TLS)
  - 포스트 양자 암호화(PQC)의 도입
- **시스템 보안**: 서버 OS 하드닝과 접근 제어 (IAM)
  - AI 기반 위협방지
  - IAM → 커널 수준 정책 확대
- **S/W 감사**: 소스코드 취약점
  - AI 및 정적/동적 분석 도구

**주요 위협 이슈**

- AI의 무질서한 성장
- 사이버 위험 관리 확대
- 오픈소스/공급망 등

### 2. 웹서버 암호화의 핵심

**TLS 1.3**

- HTTPS의 최신 표준
- 데이터를 보호하는 최신 전송 계층 프로토콜
- 구현 OS 및 H/W 호환성 문제 존재

**PQC (양자 내성 암호) 전환 계획**

- 2030년 이내 PQC 내성 암호 전환 계획
- PQC 디지털 서명 (ML-DSA) 적용 진행중

| 구분 | 기존 암호 (Classic) | 양자 내성 암호 (PQC) | 주요 이슈 |
|---|---|---|---|
| 주요 알고리즘 | RSA-2048 / ECC (P-256) | ML-KEM-768 (Kyber) | 전환 시급성 |
| 공개키 크기 | 32 - 256 Bytes | 1,184 Bytes (약 37배↑) | 통신 패킷 오버헤드 |
| 서명 크기 | 64 Bytes | 3,309 Bytes (약 51배↑) | 메모리 점유율 증가 |
| 양자 저항성 | 없음 (취약함) | 강력함 (안전함) | 미래 보안 보장 |

---

## 실습

### 시나리오

1. 웹서버 보안 설정
   a. Nginx HTTPS 설정
   b. 보안 인증서 및 설정
2. Lynis 시스템 보안 감서
   a. 시스템 설정 등 분석
3. Trivy 취약점 스캔
   a. 컨테이너 이미지 분석

---

## 웹 서버 관리 - Nginx HTTPS 설정

### 1. HTTP(80) vs HTTPS (443)

- HTTPS = 기본 + SSL/TLS 보안 계층 (암호화)
- 인증서 필요, 업계 표준 (PKCS 등)

### 2. 인증서 종류

**공인 CA 서명 인증서**

- 공인인증서 (폐지) → 공동인증서로 변경
- 금융인증서, 민간 인증서 등

**self-signed(자체서명) 인증서**

- 직접 인증서 생성
- 신뢰 X, 개발, 실습용
- OpenSSL 활용

---

### 1) OpenSSL 인증서 생성

```bash
$ openssl req -x509 -nodes \
  -days 365 \
  -newkey rsa:2048 \
  -keyout nginx-selfsigned.key \
  -out nginx-selfsigned.crt \
  -subj "/C=KR/ST=Seoul/L=Seoul/O=SSU/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
```

**옵션 설명**

- -x509 : 자체 서명 인증서
- 개인키 암호화 없음 (Nginx 자동 로드용)
- 유효기간 1년, RSA 2048비트

**생성된 파일**

<img width="813" height="77" alt="image" src="https://github.com/user-attachments/assets/d0d12e3e-2d5b-43b9-afe3-80fd9d04faa3" />

- nginx-selfsigned.crt ← 인증서 (공개)
- nginx-selfsigned.key ← 개인키 (노출 금지)

**인증서 내용 확인**

<img width="676" height="162" alt="image" src="https://github.com/user-attachments/assets/c2baacce-ef09-413c-a1f7-04dac0707e48" />

---

### 2) Nginx 443 설정 (TLS 1.3 전용)

default.conf 수정 (반드시 백업)

<img width="620" height="270" alt="image" src="https://github.com/user-attachments/assets/d08f8094-ece3-4d86-8f3d-c96e08c54a58" />


| 설정 코드 | 의미 및 역할 | 비고 |
|---|---|---|
| listen 80; | 기본 포트 접속 대기 | 일반 웹 요청을 수신 |
| return 301 ...; | Moved Permanently (영구 이동) | 검색 엔진(SEO)에 주소가 영구히 변경되었음을 알림 |
| https://$host:8443$request_uri; | HTTPS 프로토콜의 8443번 포트로 강제 전환 | 핵심 리다이렉트 목적지 주소 |

---

### 3) 보안 헤더 설정 (OWASP 권장)

<img width="820" height="272" alt="image" src="https://github.com/user-attachments/assets/c601fb1c-d149-4cb7-9047-2e5121f742a2" />

**보안 헤더 설명**

| 헤더 | 역할 | 차단 공격 |
|---|---|---|
| X-Frame-Options | 동일 출처에서만 iframe 허용 | Clickjacking |
| X-Content-Type-Options | 브라우저가 MIME 타입 임의 변경 금지 | MIME 스니핑 |
| X-XSS-Protection | XSS 감지 시 페이지 차단 | XSS (구형 브라우저) |
| Strict-Transport-Security | 1년간 HTTPS만 허용 강제 | HTTP 다운그레이드 |
| Referrer-Policy | 외부 사이트로 URL 정보 제한 | 정보 유출 |

---

### 4) 설정 적용 및 확인

<img width="802" height="226" alt="image" src="https://github.com/user-attachments/assets/5b50d7cd-8562-4fa0-bbbf-6270bc4e935c" />

```bash
# 저장 후 문법 검사
docker exec wp_nginx nginx -t
```

```bash
# 재시작 없이 반영
docker exec wp_nginx nginx -s reload
```

```bash
# 보안 헤더 적용 확인
curl -k -I https://localhost:8443 | \
  grep -E "(X-Frame|X-Content|Strict|X-XSS)"
```

---

### 5) compose.nginx.yaml 수정

443 포트 추가 및 마운트 설정

<img width="621" height="450" alt="image" src="https://github.com/user-attachments/assets/9fef7824-e399-4be9-bb4c-dc4f4409a080" />

- "8443:443"  # ← 443 포트 추가
- ./nginx/certs:/etc/nginx/certs:ro  # ← 인증서 마운트 추가

---

### 6) 웹 서버 HTTPS 확인 - 테스트 1~3

<img width="1005" height="293" alt="image" src="https://github.com/user-attachments/assets/2584ea13-c90e-4885-9988-c455182100e7" />


**테스트 1: curl HTTPS 응답 확인**

```bash
curl -k -o /dev/null -w "%{http_code}" https://localhost:8443
```

**테스트 2: HTTP → HTTPS 리다이렉트**

```bash
curl -I http://localhost:8080
```

**테스트 3: 인증서 유효기간 확인**

```bash
echo | openssl s_client -connect localhost:8443 2>/dev/null | openssl x509 -noout -dates
```

---

### 7) 웹 서버 HTTPS 확인 - 테스트 4~6

<img width="1002" height="223" alt="image" src="https://github.com/user-attachments/assets/0b84b0cf-34c9-4979-b581-2ab5f1c6040a" />

**테스트 4: TLS 1.2 차단 확인**

```bash
openssl s_client -connect localhost:8443 -tls1_2 2>/dev/null | grep "handshake"
```

**테스트 5: TLS 1.3 동작 및 차단 검증**

```bash
openssl s_client -connect localhost:8443 -tls1_3 2>/dev/null | grep "Protocol"
```


**테스트 6: 협상된 암호 스위트 확인**

```bash
openssl s_client -connect localhost:8443 -tls1_3 2>/dev/null | grep "Cipher"
```

---

### 8) 443 vs 8443 포트 비교

| 구분 | 443 포트 | 8443 포트 |
|---|---|---|
| 정의 | HTTPS 공식 표준 포트 | HTTPS 대체 및 테스트용 포트 |
| 주요 용도 | 실제 상용(운영) 웹사이트 서비스 | 아파치 톰캣(Tomcat) SSL 서비스, 개발 서버 |
| URL 주소 표시 | 포트 번호 생략 가능 (자동 접속) | 포트 번호 명시 필수 (:8443) |
| 방화벽 허용 | 대부분의 공공망/사내망에서 기본 허용 | 엄격한 사내망이나 학교 등에서 차단될 확률 높음 |

---

### 9) 브라우저 확인 및 워드프레스 DB 수정

최종: 브라우저 확인 https://localhost:8443 (localhost:8080 으로 들어가도 8443번으로 리다이렉트)

<img width="928" height="918" alt="image" src="https://github.com/user-attachments/assets/63edef67-d854-4b76-88ca-20f4ae8720bf" />


---

## Lynis 시스템 보안 검사

### 1) 시스템 감사 도구 개요

- 오픈소스, 에이전트 불필요
- 결과를 Hardening Index로 점수화
- 감사 항목 : 500개 이상 자동 검사

**결과 등급**

- [OK] 안전한 설정
- [WARNING] 즉시 조치 필요
- [SUGGESTION] 개선 권장

**검사 영역**

- 부트 보안: GRUB 설정, 부트로더
- 파일시스템: 마운트 옵션, 권한
- SSH 설정: root 로그인, 포트, 키
- 사용자 계정: 패스워드 정책, sudo
- 네트워크: 열린포트, 방화벽
- 로깅: syslog, auditd
- 컨테이너: Docker 보안 설정

---

### 2) 전체 시스템 감사 실행

```bash
sudo lynis audit system
```

<img width="746" height="680" alt="image" src="https://github.com/user-attachments/assets/f8ec2fce-a0eb-4a68-96dc-6c98e757e2b1" />


**Hardening Index 점수: 65**

| 점수 범위 | 평가 |
|---|---|
| 0 ~ 49 | 위험 (즉시 조치) |
| 50 ~ 69 | 보통 (개선 필요) |
| 70 ~ 84 | 양호 |
| 85 ~ 100 | 우수 (실무 목표) |

**보고서 저장 위치**

- /var/log/lynis.log ← 전체 상세 로그
- /var/log/lynis-report.dat ← 구조화된 결과

---

### 3) 해결해야할 항목 목록

<img width="992" height="390" alt="image" src="https://github.com/user-attachments/assets/1c903754-90af-4372-9dc0-89debd901544" />

| 항목 | 내용 | 우선순위 |
|---|---|---|
| PKGS-7392 | 취약 패키지 업그레이드 | 높음 |
| DEB-0880 | fail2ban 설치 (무차별 로그인 차단) | 중간 |
| AUTH-9230 | 패스워드 해싱 강화 | 중간 |
| KRNL-5820 | core dump 비활성화 | 낮음 |
| DEB-0280 | libpam-tmpdir 설치 | 낮음 |
| BOOT-5264 | systemd 서비스 강화 | 낮음 |
| LYNIS | Lynis 버전 업데이트 | 낮음 |

→ 부분적으로 해결하여 Hardening Index 점수를 높이자

---

### 4) PKGS-7392 해결

```bash
# 취약한 패키지 확인
$ sudo apt list --upgradable 2>/dev/null

# 보안 패치만 업그레이드(에러 수정) - 설정 파일 수정
$ sudo nano /etc/apt/apt.conf.d/50unattended-upgrades

# 보안 패치 실행
$ sudo unattended-upgrade -v -o 'Unattended-Upgrade::OnlyOnACPower=false'
```

---

### 5) DEB-0880, AUTH-9230 해결

**DEB-0880: fail2ban 설치 (무차별 로그인 차단)**

```bash
$ sudo apt install fail2ban -y
```

**AUTH-9230: 패스워드 해싱 강화**

```bash
$ sudo nano /etc/login.defs
```

> 참고: 주석 해제 후 MIN 10000, MAX 65536으로 수정

**시스템 재스캔 및 점수 확인**

```bash
$ sudo lynis audit system
```

(대기 후 점수 확인 → 68점으로 상승)

<img width="442" height="142" alt="image" src="https://github.com/user-attachments/assets/90f93cfa-f723-43fe-9b43-c3fd277792ba" />

---

### 6) Docker 환경 보안 상태 확인

<img width="698" height="111" alt="image" src="https://github.com/user-attachments/assets/14942a59-f88e-4c66-81f4-e2f9793b831c" />

- **UNSAFE** = systemd 서비스에 보안 설정 X, ROOT 실행 가능성 → SAFE 상태를 위한 설정 필요
- **WSL2 기반 환경**: UNSAFE가 정상 (정상 동작임)
- 이외 데몬 및 컨테이너는 모두 정상 실행, 이상 없음

---

## Trivy 취약점 스캔

### 1) 개요

**스캔 대상**

- OS 패키지: apt, apk 설치 패키지
- 언어 라이브러리: pip, npm, composer
- 비밀 정보: API 키, 패스워드 노출

**컨테이너 이미지 취약점 스캔**

- 내부 패키지 CVE DB와 비교
  - 이미지 안의 OS 패키지
  - 언어별 라이브러리

**CVE (Common Vulnerabilities and Exposures)**

- 공개된 보안 취약점 DB, 식별 번호 체계

**심각도 등급**

- CRITICAL > HIGH > MEDIUM > LOW > UNKNOWN
- 실무: CRITICAL / HIGH 먼저 처리

---

### 2) 설치

```bash
# 사전 패키지(키 처리 도구)
$ sudo apt-get install wget apt-transport-https gnupg lsb-release -y

# GPG 키 등록(공개키)
$ wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null

# 저장소 등록(키링 포함)
$ echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] \
https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list

# 설치 후 확인
$ sudo apt-get update && sudo apt-get install trivy -y
$ trivy --version
```

<img width="532" height="127" alt="image" src="https://github.com/user-attachments/assets/b956e88b-9c2b-44aa-8f53-c13953283b84" />


---

### 3) 기본 스캔 (nginx:alpine)

- 취약점 DB 업데이트(대기)
- 스캔하기

<img width="1487" height="587" alt="image" src="https://github.com/user-attachments/assets/aab72c1a-6155-4109-9cfe-a2b8d99fd52c" />

**결과**

`Total: 31 (UNKNOWN: 0, LOW: 20, MEDIUM: 8, HIGH: 3, CRITICAL: 0)`

> 슬라이드 예시(18개, HIGH:1)와 숫자가 다른 이유
>
> CVE 데이터베이스는 매일 업데이트되기 때문에, 같은 이미지라도 스캔 시점에 따라 새로 등록된 취약점이 추가되어 결과 개수가 달라질 수 있음 (정상적인 현상)

**HIGH 등급 취약점 3건 (모두 Fixed Version 존재)**

| Library | CVE | Severity | Status | Installed Version | Fixed Version | 내용 |
|---|---|---|---|---|---|---|
| libcrypto3 | CVE-2026-45447 | HIGH | fixed | 3.5.6-r0 | 3.5.7-r0 | OpenSSL PKCS7_verify() 처리 중 Heap Use-After-Free |
| libssl3 | CVE-2026-45447 | HIGH | fixed | 3.5.6-r0 | 3.5.7-r0 | (동일 취약점, libssl3에도 적용) |
| libxml2 | CVE-2026-6732 | HIGH | fixed | 2.13.9-r0 | 2.13.9-r1 | 조작된 XSD 검증 문서 처리 시 DoS(서비스 거부) |

**취약점 상세**

**CVE-2026-45447 (libcrypto3, libssl3)**

- PKCS7_verify() 함수가 조작된 PKCS7 데이터를 처리할 때 이미 해제된 메모리(heap)에 접근하는 Use-After-Free 취약점
- 크래시나 임의 코드 실행으로 이어질 수 있음

**CVE-2026-6732 (libxml2)**

- 특정 형태로 조작된 XSD 검증 문서를 처리할 때 발생하는 서비스 거부(DoS) 취약점

---

### 4) WordPress 이미지 스캔 (8.2버전)

```bash
trivy image --severity HIGH,CRITICAL wordpress:php8.2-fpm
```

<img width="1405" height="550" alt="image" src="https://github.com/user-attachments/assets/48071414-591b-42fe-bd5c-fcea6b8904a7" />

**스캔 결과 항목 의미**

- **Library**: 취약점이 있는 패키지 이름
- **Vulnerability**: CVE 번호
- **Severity**: 심각도 (CRITICAL/HIGH/MEDIUM/LOW)
- **Status**: fixed / affected
- **Installed Version**: 현재 설치된 버전
- **Fixed Version**: 패치된 버전 (있으면 업그레이드 가능)
- **Title**: 취약점 요약 설명

---

## 실습 과제 : MySQL 8.0 컨테이너 CRITICAL 취약점 분석

```bash
trivy image --severity CRITICAL mysql:8.0
```

<img width="1043" height="927" alt="image" src="https://github.com/user-attachments/assets/f8a7cbe2-5c03-46c2-80f1-e29694e0e61f" />

<img width="1282" height="183" alt="image" src="https://github.com/user-attachments/assets/41150d8b-8126-4d1a-9619-8f6e365e26e7" />

### 취약점 상세

| 항목 | 내용 |
|---|---|
| 위치 | /usr/local/bin/gosu (Go 바이너리) |
| CVE 번호 | CVE-2025-68121 Cvereports |
| Severity | CRITICAL |
| Status | fixed |
| Installed Version | Go 1.24.6 |
| Fixed Version | 1.24.13 / 1.25.7 / 1.26.0-rc.3 |
| CVSS 점수 | 10.0 (CVSS v3.1, NVD 기준) |

### 취약점 설명

TLS 세션을 재사용(재개)할 때, Go의 crypto/tls가 인증서를 다시 검증하지 않는 결함

이로 인해 이미 폐기된 인증서라도 과거 세션 티켓만 있으면 계속 접근이 유지됨

### 공격 유형

인증서 검증 우회를 통한 비인가 접근 지속(인증/접근통제 우회)

단, 공격자가 사전에 유효했던 인증서를 보유하고 있어야 해서 (Wiz 평가상 권한 요구 수준 HIGH) 실제 악용 난이도는 다소 높음

### 평가 및 해결 방안

- gosu는 컨테이너 내부 권한 전환용 보조 도구로, MySQL의 DB 통신/TLS와 직접 관련 없어 실질 위험도는 낮음
- 해결: 패치된 Go 버전으로 빌드된 최신 mysql:8.0 이미지로 교체

> 2026-06-12 기준 docker pull 시도 결과 mysql:8.0 이미지가 최신 상태(up to date)임에도 CVE-2025-68121이 패치되지 않은 채로 유지되고 있음. 이는 이미지 메인테이너의 패치 미반영으로 판단되며, 추후 이미지 업데이트 시 재스캔을 통한 확인이 필요함.
