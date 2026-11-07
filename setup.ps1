param([switch]$FrontendOnly)

Write-Host "=== EcoReport - Setup Automatizado ===" -ForegroundColor Cyan
Write-Host ""

if (-not $FrontendOnly) {
    Write-Host "[1/5] Creando entorno virtual..." -ForegroundColor Yellow
    $venvPath = Join-Path $PSScriptRoot "venv"
    if (-not (Test-Path $venvPath)) {
        python -m venv $venvPath
    }
    Write-Host "  OK" -ForegroundColor Green

    Write-Host "[2/5] Instalando dependencias del backend..." -ForegroundColor Yellow
    & "$venvPath\Scripts\python" -m pip install --quiet "setuptools_scm[toml]>=5.0,<9.0"
    & "$venvPath\Scripts\python" -m pip install --quiet --no-build-isolation `
        fastapi[standard]==0.115.0 `
        uvicorn[standard]==0.31.0 `
        gunicorn==23.0.0 `
        pyodbc `
        python-dotenv==1.0.1 `
        passlib[bcrypt]==1.7.4 `
        python-jose[cryptography]==3.3.0
    Write-Host "  OK" -ForegroundColor Green

    Write-Host "[3/5] Configurando .env..." -ForegroundColor Yellow
    $envFile = Join-Path $PSScriptRoot ".env"
    if (-not (Test-Path $envFile)) {
        $envExample = Join-Path $PSScriptRoot ".env.example"
        if (Test-Path $envExample) {
            Copy-Item $envExample $envFile
        }
        Add-Content $envFile "`nCORS_ORIGINS=http://localhost:4200"
        Write-Host "  .env creado desde .env.example" -ForegroundColor Yellow
        Write-Host "  IMPORTANTE: Edita las credenciales de BD en backend\.env" -ForegroundColor Magenta
    } else {
        $hasCors = Select-String -Path $envFile -Pattern "CORS_ORIGINS" -SimpleMatch -Quiet
        if (-not $hasCors) {
            Add-Content $envFile "`nCORS_ORIGINS=http://localhost:4200"
            Write-Host "  CORS_ORIGINS agregado al .env existente" -ForegroundColor Yellow
        } else {
            Write-Host "  .env ya existe y tiene CORS_ORIGINS" -ForegroundColor Green
        }
    }
}

Write-Host "[4/5] Instalando dependencias del frontend..." -ForegroundColor Yellow
$rootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $rootDir
npm ci
if ($LASTEXITCODE -ne 0) {
    npm install
}
Write-Host "  OK" -ForegroundColor Green

Write-Host "[5/5] Build de produccion..." -ForegroundColor Yellow
npx ng build --configuration production
Write-Host "  OK" -ForegroundColor Green
Pop-Location

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SETUP COMPLETADO" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para iniciar el backend (mantener abierto):" -ForegroundColor White
Write-Host "  cd backend" -ForegroundColor Yellow
Write-Host "  .\venv\Scripts\Activate" -ForegroundColor Yellow
Write-Host "  .\venv\Scripts\uvicorn app.main:app --reload --port 8000" -ForegroundColor Yellow
Write-Host ""
Write-Host "Para iniciar el frontend (otra terminal):" -ForegroundColor White
Write-Host "  npm start" -ForegroundColor Yellow
Write-Host ""
Write-Host "Frontend: http://localhost:4200" -ForegroundColor Cyan
Write-Host "Backend:  http://localhost:8000" -ForegroundColor Cyan
Write-Host "API Docs: http://localhost:8000/docs" -ForegroundColor Cyan
