param()

Write-Host "=== EcoReport Backend - Setup ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "uv no esta instalado. Instalalo con:" -ForegroundColor Red
    Write-Host "  winget install --id=astral-sh.uv -e" -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/2] Sincronizando dependencias con uv..." -ForegroundColor Yellow
Push-Location $PSScriptRoot
uv sync
$uvExit = $LASTEXITCODE
Pop-Location
if ($uvExit -ne 0) {
    Write-Host "  ERROR: uv sync fallo" -ForegroundColor Red
    exit 1
}
Write-Host "  OK" -ForegroundColor Green

Write-Host "[2/2] Configurando .env..." -ForegroundColor Yellow
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    $envExample = Join-Path $PSScriptRoot ".env.example"
    if (Test-Path $envExample) {
        Copy-Item $envExample $envFile
    }
    Add-Content $envFile "`nCORS_ORIGINS=http://localhost:4200"
    Write-Host "  .env creado desde .env.example" -ForegroundColor Yellow
    Write-Host "  IMPORTANTE: Edita las credenciales de BD en .env" -ForegroundColor Magenta
} else {
    $hasCors = Select-String -Path $envFile -Pattern "CORS_ORIGINS" -SimpleMatch -Quiet
    if (-not $hasCors) {
        Add-Content $envFile "`nCORS_ORIGINS=http://localhost:4200"
        Write-Host "  CORS_ORIGINS agregado al .env existente" -ForegroundColor Yellow
    } else {
        Write-Host "  .env ya existe y tiene CORS_ORIGINS" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SETUP COMPLETADO" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para iniciar el backend:" -ForegroundColor White
Write-Host "  uv run uvicorn app.main:app --reload --port 8000" -ForegroundColor Yellow
Write-Host ""
Write-Host "Backend:  http://localhost:8000" -ForegroundColor Cyan
Write-Host "API Docs: http://localhost:8000/docs" -ForegroundColor Cyan
