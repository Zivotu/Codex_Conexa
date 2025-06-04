@echo off
cd /d C:\Users\Amir\Desktop\Conexa_Codex_Test

echo ----------------------------------------
echo ⏳ Prebacujem se na granu main...
git checkout main

echo ----------------------------------------
echo 📦 Dodajem sve lokalne promjene...
git add .

echo ----------------------------------------
echo 💬 Komitam promjene...
git commit -m "Automatski commit lokalnih promjena"

echo ----------------------------------------
echo 🔄 Povlacim najnovije promjene s GitHuba...
git pull origin main --no-edit

echo ----------------------------------------
echo 🚀 Saljem promjene na GitHub...
git push origin main

echo ----------------------------------------
echo ✅ Gotovo! Lokalno i GitHub su sinkronizirani.
pause
