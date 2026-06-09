#Requires -Version 5.1
<#
.SYNOPSIS
  Mac에서 구축한 LoadTestLab 인프라를 전제로, Windows에서 부하 테스트만 반복할 때
  필요한 도구 설치·검증·EC2 동기화를 한 번에 수행합니다.

.DESCRIPTION
  전제: EKS(loadtest-lab), ALB, Route53, LoadTest EC2, Grafana/Argo CD 앱 — 이미 구축됨.
  이 스크립트는 클러스터를 새로 만들지 않습니다.

.PARAMETER PemPath
  LoadTest EC2 SSH용 .pem 절대 경로 (예: C:\Users\me\.ssh\EKS_loadtest.pem)

.PARAMETER LoadTestEc2Ip
  LoadTest EC2 Public IP (필수)

.PARAMETER InstallMissing
  aws/kubectl/git 이 없으면 winget 으로 설치 시도 (기본: true)

.PARAMETER SyncToEc2
  loadtest/ 디렉터리를 EC2 ~/loadtest 로 scp 동기화 (기본: true)

.PARAMETER SkipGitPull
  git pull 건너뜀

.EXAMPLE
  .\setup-windows-loadtest.ps1 `
    -PemPath "C:\Users\me\.ssh\EKS_loadtest.pem" `
    -LoadTestEc2Ip "43.202.100.84"

.EXAMPLE
  $env:LOADTEST_PEM = "C:\Users\me\.ssh\EKS_loadtest.pem"
  $env:LOADTEST_EC2_IP = "43.202.100.84"
  .\setup-windows-loadtest.ps1
#>
[CmdletBinding()]
param(
    [string] $PemPath = $env:LOADTEST_PEM,
    [string] $LoadTestEc2Ip = $env:LOADTEST_EC2_IP,
    [string] $AwsRegion = $(if ($env:AWS_REGION) { $env:AWS_REGION } else { "ap-northeast-2" }),
    [string] $ClusterName = $(if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME } else { "loadtest-lab" }),
    [string] $AppHost = $(if ($env:APP_HOST) { $env:APP_HOST } else { "loadtest.k8s-study.club" }),
    [string] $Ec2User = "ec2-user",
    [switch] $InstallMissing = $true,
    [switch] $SyncToEc2 = $true,
    [switch] $SkipGitPull
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LoadTestDir = Join-Path $ScriptDir "loadtest"
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..\..")).Path

function Write-Step([string]$Message) {
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Write-Ok([string]$Message) {
    Write-Host "  OK  $Message" -ForegroundColor Green
}

function Write-Fail([string]$Message) {
    Write-Host "  FAIL  $Message" -ForegroundColor Red
}

function Test-CommandExists([string]$Name) {
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Install-WingetPackage([string]$Id, [string]$Label) {
    if (-not (Test-CommandExists "winget")) {
        Write-Fail "winget 없음 — $Label 수동 설치 필요: https://winget.run/pkg/$Id"
        return $false
    }
    Write-Host "  winget install $Id ..."
    winget install -e --id $Id --accept-package-agreements --accept-source-agreements | Out-Null
    return $true
}

function Ensure-Tool([string]$Name, [string]$WingetId, [string]$ManualHint) {
    if (Test-CommandExists $Name) {
        Write-Ok "$Name — $(Get-Command $Name | Select-Object -ExpandProperty Source)"
        return
    }
    if ($InstallMissing -and $WingetId) {
        Install-WingetPackage -Id $WingetId -Label $Name | Out-Null
        # PATH 갱신 (현재 세션)
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" `
            + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
    if (-not (Test-CommandExists $Name)) {
        throw "$Name 없음. $ManualHint"
    }
    Write-Ok "$Name 설치 완료"
}

function Fix-PemPermissions([string]$Path) {
    # OpenSSH: 다른 사용자 ACL 제거 (Windows)
    $acl = icacls $Path 2>$null
    if ($LASTEXITCODE -ne 0) { return }
    icacls $Path /inheritance:r | Out-Null
    icacls $Path /grant:r "$($env:USERNAME):(R)" | Out-Null
    Write-Ok "PEM ACL 정리: $Path"
}

function Invoke-External([string]$Exe, [string[]]$Args, [string]$FailMessage) {
    & $Exe @Args
    if ($LASTEXITCODE -ne 0) {
        throw $FailMessage
    }
}

Write-Step "LoadTestLab — Windows 부하 테스트 준비"
Write-Host "전제: Mac에서 구축한 EKS/ALB/EC2 사용 | 클러스터: $ClusterName | 리전: $AwsRegion"

# ── 1) 도구 설치·확인 ─────────────────────────────────────────────
Write-Step "1/6 도구 (aws CLI, kubectl, git, ssh)"
Ensure-Tool "aws"     "Amazon.AWSCLI"        "https://aws.amazon.com/cli/"
Ensure-Tool "kubectl" "Kubernetes.kubectl" "https://kubernetes.io/docs/tasks/tools/"
Ensure-Tool "git"     "Git.Git"            "https://git-scm.com/download/win"
if (-not (Test-CommandExists "ssh")) {
    throw "OpenSSH Client 없음. 설정 → 앱 → 선택적 기능 → OpenSSH Client 설치"
}
Write-Ok "ssh — $(Get-Command ssh | Select-Object -ExpandProperty Source)"

$awsVer = aws --version 2>&1
if ($awsVer -notmatch "aws-cli/2") {
    throw "AWS CLI v2 필요 — 현재: $awsVer"
}
Write-Ok "AWS CLI v2 — $awsVer"

# ── 2) 입력값 검증 ────────────────────────────────────────────────
Write-Step "2/6 PEM / EC2 IP"
if ([string]::IsNullOrWhiteSpace($PemPath)) {
    $PemPath = Read-Host "PEM 파일 절대 경로 (예: C:\Users\me\.ssh\EKS_loadtest.pem)"
}
if (-not (Test-Path -LiteralPath $PemPath)) {
    throw "PEM 파일 없음: $PemPath"
}
Fix-PemPermissions -Path $PemPath

if ([string]::IsNullOrWhiteSpace($LoadTestEc2Ip)) {
    $LoadTestEc2Ip = Read-Host "LoadTest EC2 Public IP"
}
if ($LoadTestEc2Ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
    throw "유효하지 않은 IP: $LoadTestEc2Ip"
}
Write-Ok "PEM: $PemPath"
Write-Ok "EC2: ${Ec2User}@${LoadTestEc2Ip}"

# ── 3) git pull ───────────────────────────────────────────────────
if (-not $SkipGitPull) {
    Write-Step "3/6 git pull"
    if (Test-Path (Join-Path $RepoRoot ".git")) {
        Push-Location $RepoRoot
        try {
            git pull --ff-only
            Write-Ok "git pull — $RepoRoot"
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "  skip — git 저장소 아님: $RepoRoot"
    }
} else {
    Write-Step "3/6 git pull (건너뜀)"
}

# ── 4) AWS 자격 · kubeconfig ──────────────────────────────────────
Write-Step "4/6 AWS 자격 · EKS kubeconfig"
$identity = aws sts get-caller-identity --output json 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "AWS 자격 증명 실패 — 'aws configure' 실행 후 재시도`n$identity"
}
Write-Ok "STS — $identity"

Invoke-External "aws" @(
    "eks", "update-kubeconfig",
    "--name", $ClusterName,
    "--region", $AwsRegion
) "kubeconfig 업데이트 실패"

kubectl cluster-info | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "kubectl 클러스터 접속 실패"
}
Write-Ok "kubectl — cluster-info"

kubectl get nodes --no-headers 2>&1 | ForEach-Object { Write-Host "  $_" }
$readyNodes = (kubectl get nodes --no-headers 2>$null | Select-String " Ready").Count
if ($readyNodes -lt 1) {
    throw "Ready 노드 없음"
}
Write-Ok "Ready 노드: $readyNodes"

# ── 5) 앱 · HTTPS 검증 ───────────────────────────────────────────
Write-Step "5/6 앱 · HTTPS 검증"
kubectl -n loadtest get deploy,svc,ingress,hpa,pod 2>&1 | ForEach-Object { Write-Host "  $_" }

try {
    # PowerShell 5.1+
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $resp = Invoke-WebRequest -Uri "https://$AppHost/" -UseBasicParsing -TimeoutSec 15
    if ($resp.StatusCode -eq 200) {
        Write-Ok "https://$AppHost/ — HTTP 200"
    } else {
        Write-Fail "https://$AppHost/ — HTTP $($resp.StatusCode)"
    }
} catch {
    Write-Fail "https://$AppHost/ 접속 실패 — Route53/ALB 확인: $($_.Exception.Message)"
}

# ── 6) EC2 동기화 · SSH 검증 ──────────────────────────────────────
Write-Step "6/6 LoadTest EC2"
if (-not (Test-Path $LoadTestDir)) {
    throw "loadtest 디렉터리 없음: $LoadTestDir"
}

if ($SyncToEc2) {
    if (-not (Test-CommandExists "scp")) {
        Write-Fail "scp 없음 — OpenSSH Client 설치 후 loadtest/ 수동 복사"
    } else {
        $remote = "${Ec2User}@${LoadTestEc2Ip}:~/loadtest"
        scp -i $PemPath -r -o StrictHostKeyChecking=accept-new "$LoadTestDir" "${Ec2User}@${LoadTestEc2Ip}:~/"
        if ($LASTEXITCODE -ne 0) {
            throw "scp 실패 — EC2 IP/PEM/SG(SSH 22) 확인"
        }
        Write-Ok "scp — $LoadTestDir → $remote"
    }
}

ssh -i $PemPath -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 `
    "${Ec2User}@${LoadTestEc2Ip}" "k6 version && test -x ~/loadtest/run-step.sh && echo ec2-ready"
if ($LASTEXITCODE -ne 0) {
    throw "EC2 SSH 또는 k6/run-step.sh 확인 실패"
}
Write-Ok "EC2 SSH · k6 · run-step.sh"

# ── 다음 단계 안내 ────────────────────────────────────────────────
Write-Step "준비 완료 — 부하 테스트 실행 방법"

$sshCmd = "ssh -i `"$PemPath`" ${Ec2User}@${LoadTestEc2Ip}"
$run100 = "export APP_HOST=$AppHost && cd ~/loadtest && ./run-step.sh 100 10"
$run1k  = "export APP_HOST=$AppHost && cd ~/loadtest && ./run-step.sh 1000 10"

Write-Host @"

[터미널 A — Grafana 관찰 (PowerShell)]
  kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
  브라우저: http://localhost:3000  (admin / loadtest-admin)
  대시보드: LoadTest — HTTP 200/500

[터미널 B — HPA 관찰 (PowerShell)]
  kubectl -n loadtest get hpa echo-cpu -w

[터미널 C — 부하 실행 (PowerShell에서 SSH 접속 후 bash)]
  $sshCmd
  $run100
  $run1k

[Git Bash에서 run-step.sh 직접 실행 시]
  export APP_HOST=$AppHost
  cd ~/loadtest
  bash ./run-step.sh 100 10

리포트: ~/loadtest/reports/step-<RPS>-<초>s-report.txt
상세:   AWS/LoadTestLab/test-guide.md

"@ -ForegroundColor Yellow
