# Docker 이해하기  
## Virtual Machine에서 Process 격리까지

## 목차

1. 왜 가상화가 필요했을까?
2. Virtual Machine은 어떻게 동작하는가?
3. VM 이후에도 남아 있던 문제
4. Container라는 새로운 접근
5. Docker의 핵심 철학
6. Docker Engine과 Daemon
7. Docker는 어떻게 프로세스 격리를 구현하는가?
8. Image와 Container의 차이
9. 전체 흐름 정리


# 1. 왜 가상화가 필요했을까?

과거에는 서버 한 대에 애플리케이션 하나를 설치하는 방식이 일반적이었습니다.

하지만 이런 문제가 발생했습니다.

- CPU와 메모리가 남는다.
- 서버 수가 늘어나면서 관리가 복잡해진다.
- 물리 서버 비용이 증가한다.

“이 서버 자원을 더 효율적으로 사용할 수는 없을까?”

이 고민에서 등장한 기술이 가상화(Virtualization) 입니다.


# 2. Virtual Machine은 어떻게 동작하는가?

## 2.1 Virtual Machine의 구조

<!-- VM Architecture Image Here -->

Virtual Machine 구조는 네 개의 계층으로 나뉩니다.

### 1) Hardware  
실제 물리 자원입니다. (CPU, Memory, Disk)

### 2) Hypervisor  
하드웨어 위에서 여러 VM을 생성하고 자원을 분배합니다.

### 3) Guest OS  
각 VM 안에 설치되는 독립적인 운영체제입니다.

### 4) Application  
Guest OS 위에서 실행되는 실제 서비스입니다.


## 2.2 VM의 핵심 특징

VM은 OS 단위 가상화이다.

VM이 여러 개라면 OS도 여러 개입니다.  
각 VM은 독립적인 Kernel을 가집니다.

이 구조는 강력한 격리를 제공합니다.  
하지만 동시에 무겁습니다.


# 3. VM 이후에도 남아 있던 문제

VM은 자원 문제를 해결했지만, 또 다른 문제가 남아 있었습니다.

“내 컴퓨터에서는 잘 되는데, 왜 서버에서는 안 되지?”

이 문제는 코드가 아니라 환경(Environment) 문제였습니다.


## 3.1 환경 불일치 예시

- Node 18 (개발) vs Node 16 (운영)
- pandas 2.x vs 1.x
- libssl 버전 차이
- OS 패키지 버전 차이

VM으로 OS를 복제할 수는 있었지만:

- 이미지가 너무 큼
- 배포가 느림
- 관리 복잡성 증가

그래서 등장한 것이 Container 입니다.


# 4. Container라는 새로운 접근

## 4.1 OS 복제가 아니라 실행 환경의 캡슐화

Container는 OS 전체를 복제하지 않습니다.

애플리케이션과 필요한 실행 환경만 Image에 포함합니다.

예시:

```dockerfile
FROM node:18
COPY app.js .
RUN npm install
```

이제 개발/테스트/운영 환경이 동일해집니다.


## 4.2 Container 구조

<!-- Container Architecture Image Here -->

핵심 차이:

- VM → OS 단위 가상화
- Container → 프로세스 단위 격리

모든 컨테이너는 Host OS의 Kernel을 공유합니다.


# 5. Docker의 핵심 철학

Docker는 단순한 컨테이너 실행 도구가 아닙니다.  
명확한 설계 철학을 가지고 등장했습니다.

1. Lightweight  
   OS 전체를 포함하지 않는다.

2. Portability  
   Build once, run anywhere.

3. Immutable Infrastructure  
   환경을 코드(Dockerfile)로 정의한다.

Docker는 실행 환경을 코드로 정의하고, 어디서든 동일하게 실행하는 것을 목표로 한다.


# 6. Docker Engine과 Daemon

Container를 실행하는 주체는 Docker Engine입니다.

Docker는 Host OS 위에서 동작합니다.


## 6.1 Docker 구성 요소

- Docker Client (CLI)
- Docker Daemon (dockerd)
- Docker Engine
- Linux Kernel


## 6.2 Docker Daemon이란?

Docker Daemon은 백그라운드에서 동작하는 프로세스입니다.

docker run 실행 시 동작 흐름:

1. CLI가 요청을 보냄
2. Docker Daemon이 요청 수신
3. Daemon이 Linux Kernel 기능 호출
4. Namespace 및 Cgroups 설정
5. Container 생성

Docker는 Linux Kernel 위에서 동작하는 관리 계층입니다.


# 7. Docker는 어떻게 프로세스 격리를 구현하는가?

Docker는 새로운 OS를 만든 것이 아닙니다.

Linux Kernel이 이미 제공하던 기능을 활용합니다.


## 7.1 격리 구조

<!-- Namespace & Cgroups Image Here -->


## 7.2 Namespace

Namespace는 프로세스가 독립된 환경에 있는 것처럼 보이게 합니다.

- PID 분리
- 네트워크 분리
- 파일 시스템 분리
- 사용자 공간 분리

Kernel은 하나지만, 보이는 자원은 분리됩니다.


## 7.3 Cgroups

Cgroups(Control Groups)는 자원 사용량을 제한합니다.

- CPU 제한
- 메모리 제한
- I/O 제한

Namespace가 공간을 나누고,  
Cgroups가 자원을 통제합니다.


## 7.4 핵심 정리

Docker는 Linux Kernel의 Namespace와 Cgroups를 활용해  
프로세스 격리를 구현한다.

모든 컨테이너는 동일한 Kernel을 공유하지만,  
격리는 프로세스 레벨에서 이루어집니다.


# 8. Image와 Container의 차이

## 8.1 구조로 이해하기

<!-- Image vs Container Diagram Here -->


## 8.2 Image란?

Image는 실행 환경의 설계도(Template) 입니다.

- 실행되지 않음
- 읽기 전용
- 레이어 구조


## 8.3 Container란?

Container는 Image를 기반으로 실행된 인스턴스입니다.

```bash
docker run my-app
```

이 순간:

- Image가 메모리에 로드
- Namespace 설정
- Cgroups 설정
- 격리된 프로세스 실행


## 8.4 예시

- 하나의 Image를 기반으로 여러 개의 Container를 동시에 생성할 수 있습니다. 
- 예를 들어 동일한 웹 서버 이미지를 사용하여 세 개의 웹 서버 컨테이너와 다섯 개의 API 서버 컨테이너를 실행할 수 있습니다. 이 경우 모든 컨테이너는 동일한 실행 환경을 공유하지만, 각각 독립적인 프로세스로 동작합니다. 
- Image는 설계도에 해당하며, Container는 그 설계도를 기반으로 실제로 실행된 프로세스라고 이해하면 됩니다.


# 9. 전체 흐름 정리

- VM은 OS 단위 가상화이다.
- Docker는 프로세스 단위 격리이다.
- Docker는 Linux Kernel 위에서 동작한다.
- Docker Daemon이 Namespace와 Cgroups를 설정한다.
- Image는 설계도이고, Container는 실행 중인 인스턴스이다.