$ErrorActionPreference = 'Stop'
Push-Location (Split-Path -Parent $PSScriptRoot)
try {
  flutter create --project-name mystreamflix_flutter --org com.mystreamflix --platforms=android,ios,windows .
  if ($LASTEXITCODE -ne 0) { throw 'Flutter platform generation failed' }
  python scripts/configure_android.py
  if ($LASTEXITCODE -ne 0) { throw 'Android manifest configuration failed' }
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency installation failed' }
  dart run flutter_launcher_icons
  if ($LASTEXITCODE -ne 0) { throw 'Icon generation failed' }
  Write-Host 'Project ready. Use flutter run -d windows or flutter run -d <android device>.'
} finally { Pop-Location }
