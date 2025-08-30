# --- הגדרות ---
$server  = "moka@69.62.109.118"
$remote  = "/home/moka/api"
$profile = "prod"

# --- Build JAR ---
Write-Host ">> Building JAR (skip tests)..." -ForegroundColor Cyan
mvn -DskipTests package
if ($LASTEXITCODE -ne 0) { throw "Maven build failed" }

# --- Find latest jar in target ---
$jar = Get-ChildItem -Path "target" -Filter "*.jar" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $jar) { throw "JAR not found under target/" }
Write-Host ">> JAR: $($jar.FullName)" -ForegroundColor Green

# --- Upload as app.new.jar (atomic swap) ---
Write-Host ">> Uploading to server..." -ForegroundColor Cyan
scp "$($jar.FullName)" "$server:`"$remote/app.new.jar`""

# --- Atomic move + PM2 restart/start ---
$cmd = @"
mv $remote/app.new.jar $remote/app.jar && \
(pm2 restart spring-api || pm2 start "java -jar $remote/app.jar --spring.profiles.active=$profile --spring.config.additional-location=$remote/" --name spring-api) && \
pm2 save
"@

Write-Host ">> Restarting PM2 on server..." -ForegroundColor Cyan
ssh $server $cmd

Write-Host ">> Done. API should be live on port 8081 (via reverse proxy)." -ForegroundColor Green
