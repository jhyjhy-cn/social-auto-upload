# build.ps1 - social-auto-upload 打包脚本

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectDir

Write-Host "===== 开始打包 sau_backend =====" -ForegroundColor Green

# 1. 检查 PyInstaller
if (-not (pip show pyinstaller 2>$null)) {
    Write-Host "安装 PyInstaller..." -ForegroundColor Yellow
    pip install pyinstaller
}

# 2. 构建前端（如果存在）
$FrontendDir = Join-Path $ProjectDir "sau_frontend"
if (Test-Path $FrontendDir) {
    Write-Host "===== 构建前端 =====" -ForegroundColor Green
    Push-Location $FrontendDir
    if (Test-Path "node_modules") {
        npm run build
    } else {
        npm install
        npm run build
    }
    Pop-Location
}

# 3. 清理旧的构建产物
if (Test-Path "dist") { Remove-Item -Recurse -Force "dist" -ErrorAction SilentlyContinue }
if (Test-Path "build") { Remove-Item -Recurse -Force "build" -ErrorAction SilentlyContinue }

# 4. 收集需要打包的数据文件（仅非 Python 资源）
$DataArgs = @()

# 配置文件
if (Test-Path "conf.py") {
    $DataArgs += "--add-data", "conf.py;."
}

# 数据库目录
if (Test-Path "db") {
    $DataArgs += "--add-data", "db;db"
}

# 媒体资源
if (Test-Path "media") {
    $DataArgs += "--add-data", "media;media"
}

# 前端构建产物
$DistDir = Join-Path $FrontendDir "dist"
if (Test-Path $DistDir) {
    if (Test-Path "$DistDir\index.html") {
        $DataArgs += "--add-data", "$DistDir\index.html;."
    }
    if (Test-Path "$DistDir\assets") {
        $DataArgs += "--add-data", "$DistDir\assets;assets"
    }
}

# 5. 执行打包
# 使用 --paths 指向项目根目录，让 PyInstaller 正确分析本地 Python 模块（myUtils, uploader, utils, skills）的依赖
Write-Host "===== 执行 PyInstaller 打包 =====" -ForegroundColor Green

pyinstaller --onefile `
    --name sau_backend `
    --clean `
    --paths $ProjectDir `
    --collect-all playwright `
    --collect-all patchright `
    @DataArgs `
    sau_backend.py

# 6. 复制前端文件和运行时资源到 dist 目录
if (Test-Path $DistDir) {
    Write-Host "===== 复制前端文件 =====" -ForegroundColor Green
    if (Test-Path "$DistDir\index.html") {
        Copy-Item "$DistDir\index.html" "dist\" -Force
    }
    if (Test-Path "$DistDir\assets") {
        Copy-Item "$DistDir\assets" "dist\assets" -Recurse -Force
    }
}

# 复制运行时需要的资源文件（conf.py 中 BASE_DIR 指向 exe 所在目录）
Write-Host "===== 复制运行时资源 =====" -ForegroundColor Green
foreach ($dir in @("utils", "media")) {
    if (Test-Path $dir) {
        Copy-Item $dir "dist\$dir" -Recurse -Force
    }
}

# 7. 检查结果
$ExePath = Join-Path $ProjectDir "dist\sau_backend.exe"
if (Test-Path $ExePath) {
    $Size = (Get-Item $ExePath).Length / 1MB
    Write-Host ""
    Write-Host "===== 打包成功 =====" -ForegroundColor Green
    Write-Host "输出目录: $(Join-Path $ProjectDir 'dist')" -ForegroundColor Cyan
    Write-Host ("exe 大小: {0:N1} MB" -f $Size) -ForegroundColor Cyan
    Write-Host "启动 sau_backend.exe 后访问 http://127.0.0.1:5409" -ForegroundColor Yellow
} else {
    Write-Host "===== 打包失败 =====" -ForegroundColor Red
    exit 1
}
