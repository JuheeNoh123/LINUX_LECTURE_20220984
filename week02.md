# 📦 2주차 - 서버 환경 구축과 Docker

## 1. 수업 목표
- 서버 트렌드 이해
- WSL 기반 Ubuntu 환경 구축
- Docker 기본 개념 및 명령어 학습
- GitHub를 통한 실습 결과 관리

---

## 2. 서버 트렌드 이해

### VM vs Container

| 항목 | Virtual Machine | Container |
|------|----------------|----------|
| OS | Guest OS 포함 | Host OS 커널 공유 |
| 크기 | 수 GB | 수 MB |
| 속도 | 느림 | 빠름 |
| 효율 | 낮음 | 높음 |

- 컨테이너는 빠르고 가벼운 실행 환경 제공
- 개발/운영 환경 일관성 유지 가능

---

## 3. WSL 기반 Ubuntu 환경 구축

### WSL 개념
- Windows에서 Linux 실행 환경 제공
- 가상화 기술 (컨테이너 아님)
- 실제 Linux 커널 사용

### 설치
wsl --install  # WSL 활성화 (미설치 시) — 재부팅 필요

wsl --version # 버전 및 설치 가능 배포판 확인
wsl --list --online

wsl --install -d Ubuntu-24.04  # Ubuntu 24.04 LTS 설치 (약 2 GB, LTS 지원)

설치가 완료되면 초기 아이디/비밀번호를 설정하고 셸에 진입한다. WSL Settings에서 CPU 코어 수, 메모리, 스왑 크기, 네트워크 모드 등을 조정할 수 있으며, 저사양 환경에서는 필수적으로 점검하는 것이 좋다.

### 기본 설정
sudo apt update && sudo apt upgrade -y  
wsl --shutdown  

### 확인
wsl --version  
wsl --list --online  
wsl --list --verbose  # 배포판/버전 확인 (WSL2로 표기되어야 정상)

---

## 4. GitHub 실습 기록(script)

### 실습 디렉터리 생성
mkdir -p ~/linux/week02  
cd ~/linux/week02  

### 터미널 입력/출력 및 타이밍을 함께 기록
script -t=t.txt -af 2026_학번_week02_log.txt
watch -n 1 ls -l 2026_학번_week02_log.txt # (다른 터미널에서) 로그 생성 여부 실시간 확인
exit  # 기록 종료
주의: exit를 2번 이상 입력하면 script 세션이 종료되므로, Docker 컨테이너 내부에서 빠져나올 때 세션을 실수로 끊지 않도록 주의한다.

### Git 연동 및 업로드
git init # Git 초기화
git config --global user.name "노주희" # 최초 커밋 전 사용자 정보 설정 (필수)
git config --global user.email "user@example.com"
git add .
git commit -m "First commit: week02"
git branch -M main # 기본 브랜치 main으로 변경
git remote add origin https://github.com/<username>/OS_LINUX_학번.git # 원격 저장소 연결 (이름 규칙: OS_LINUX_학번)
git push -u origin main

---

## 5. Docker 개념
- 컨테이너 기반 가상화 기술
- 애플리케이션 실행 환경을 패키징
- 빠른 배포 및 확장 가능

---

## 6. Docker 설치

curl -fsSL https://get.docker.com -o get-docker.sh   # 공식 설치 스크립트 다운로드 (29.1.x 기준)
sudo sh get-docker.sh  

### 권한 설정
sudo usermod -aG docker $USER   # 현재 사용자를 docker 그룹에 추가하여 sudo 없이 실행
newgrp docker  # 그룹 변경 즉시 반영

---

## 7. Docker 기본 명령어

### 설치 확인
docker --version  
docker info  
docker run hello-world  

### 이미지 관리
docker images   # 로컬 이미지 목록
docker pull ubuntu:latest  # 이미지 Pull / 삭제
docker rmi ubuntu:latest  

### 컨테이너 확인
docker ps  # 실행 중
docker ps -a  # 전체 (Exited 포함)

---

## 8. Nginx 컨테이너 실행

docker run -d --name my-nginx -p 8080:80 nginx:latest  
-d: detached 모드 (백그라운드 실행)
--name: 컨테이너 이름 지정
-p 8080:80: 호스트의 8080 → 컨테이너의 80으로 포트 포워딩

브라우저 접속: http://localhost:8080  
Windows 브라우저에서 http://localhost:8080 접속 시 Nginx 기본 페이지가 표시되면 정상이다.

---

## 9. 컨테이너 내부 접근

docker exec -it my-nginx bash  # 컨테이너 내부 셸 진입
ls /usr/share/nginx/html # (컨테이너 내부) 정적 리소스 위치 확인
exit  

---

## 10. 파일 복사 및 마운트

### 파일 복사 
docker cp my-nginx:/usr/share/nginx/html/. ./www/   # 컨테이너 내부 파일을 호스트로 복사

### 바인드 마운트로 재배포
docker cp로 가져온 www/ 디렉터리를 호스트의 실제 소스 루트로 사용하도록 컨테이너를 재배포한다.
docker run -d --name my-nginx -p 8080:80 --mount type=bind,source=./www,target=/usr/share/nginx/html nginx:latest  
이후 호스트에서 nano www/index.html로 직접 수정하면 브라우저 새로고침만으로 즉시 반영된다. 
이는 개발-운영 환경 일관성을 유지하면서 빠른 피드백 루프를 구성하는 기본 패턴이다.

---

## 11. 컨테이너 관리

docker stop my-nginx 
docker rm -f my-nginx 

### 전체 정리
docker stop $(docker ps -q)   # 실행 중 컨테이너 일괄 정지
docker rm $(docker ps -aq)   # 모든 컨테이너(Exited 포함) 삭제
docker system prune -af  # 중단된 컨테이너, 네트워크, 빌드 캐시, 미사용 이미지까지 완전 정리

---

## 12. 추가 실습
스크립트 자동 기록 파일 추가하기
<img width="607" height="133" alt="image" src="https://github.com/user-attachments/assets/14e7155a-c235-4f1e-a8ec-c8723260f1b5" />

<img width="1183" height="528" alt="image" src="https://github.com/user-attachments/assets/956dbe06-9b5e-4f84-b063-e199fb111503" />
이런식으로 실습 로그를 출력할 수 있다.

---

## 13. 정리

- WSL을 통해 Linux 환경 구축 가능
- Docker를 통해 컨테이너 기반 실행 가능
- 컨테이너는 빠르고 가벼운 실행 환경 제공
- GitHub를 통해 실습 내용 관리 가능
