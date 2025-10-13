@echo off
setlocal DisableDelayedExpansion
keytool -genkeypair -v -keystore android\keystore\reporeader-release.keystore -alias reporeader -keyalg RSA -keysize 2048 -validity 10000 -storepass DaSoEm.2021! -keypass DaSoEm.2021! -dname "CN=David Albrecht, OU=App, O=Mindoro Evolution, L=Duesseldorf, S=NRW, C=DE"
if errorlevel 1 exit /b %errorlevel%