@echo off
setlocal
if "%~1"=="" (
  echo Usage: collect_tv_crash.bat PACKAGE_ID
  echo Example PACKAGE_ID: com.mystreamflix.mystreamflix_flutter
  echo To find it: adb shell pm list packages ^| findstr mystreamflix
  exit /b 2
)
where adb >nul 2>&1
if errorlevel 1 (
  echo Android platform-tools adb.exe is not on PATH.
  exit /b 3
)
adb devices
adb shell getprop ro.product.cpu.abilist > tv_device_abis.txt
adb shell getprop ro.build.version.sdk >> tv_device_abis.txt
echo Resetting device logcat ...
adb logcat -c
echo Force stopping %~1 ...
adb shell am force-stop "%~1"
echo Launching app ...
adb shell monkey -p "%~1" -c android.intent.category.LEANBACK_LAUNCHER 1
if errorlevel 1 adb shell monkey -p "%~1" 1
ping -n 11 127.0.0.1 >nul
adb logcat -d -b main -b system -b crash -v time > mbox_tv_startup_log.txt
echo Created mbox_tv_startup_log.txt and tv_device_abis.txt
endlocal
