@echo off
cd /d C:\Users\Amir\Desktop\Conexa_Codex_Test
git add .
git commit -m "Auto commit"
git pull origin main --no-edit
git push
pause
