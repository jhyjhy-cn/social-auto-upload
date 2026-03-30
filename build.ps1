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
if (Test-Path "dist") { Remove-Item -Recurse -Force "dist" }
if (Test-Path "build") { Remove-Item -Recurse -Force "build" }

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
    @DataArgs `
    sau_backend.py

# 6. 检查结果
$ExePath = Join-Path $ProjectDir "dist\sau_backend.exe"
if (Test-Path $ExePath) {
    $Size = (Get-Item $ExePath).Length / 1MB
    Write-Host ""
    Write-Host "===== 打包成功 =====" -ForegroundColor Green
    Write-Host "输出文件: $ExePath" -ForegroundColor Cyan
    Write-Host ("文件大小: {0:N1} MB" -f $Size) -ForegroundColor Cyan
} else {
    Write-Host "===== 打包失败 =====" -ForegroundColor Red
    exit 1
}
