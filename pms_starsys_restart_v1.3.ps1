# --- Konfigurasi ---
$appName            = "Pms.exe"
$windowTitleKeyword = "Pms"
$shortcutPath       = "C:\Users\trans\Desktop\Pms.lnk"
$logFolder          = "D:\Starsys\Log"
$timeout            = 300   # 5 menit tidak responsif
$checkInterval      = 1     # cek tiap 1 detik
$requiredStableTime = 1     # dianggap stabil kalau aktif selama >= 1 detik
$maxStableDuration  = 120   # jika stabil 2 menit, restart juga (opsional reset periodik)

# --- Variabel Internal ---
$remainingTime = $timeout
$wasResponding = $true
$runningCount  = 0

# --- Fungsi Logging Harian ---
function Write-Log($message) {
    $dateString = Get-Date -Format "yyyy-MM-dd"
    $logPath = Join-Path $logFolder "$dateString-Monitoring.txt"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logPath -Value "$timestamp - $message"
}

# --- Cek & Buat Folder Log ---
if (-not (Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}

Write-Log "Memulai monitoring $appName"
Write-Host "[$(Get-Date)] Monitoring $appName..."

while ($true) {
    $process = Get-Process -Name ($appName -replace ".exe", "") -ErrorAction SilentlyContinue
    $isRunningWithWindow = $false

    if ($process) {
        foreach ($p in $process) {
            if ($p.Responding -and $p.MainWindowHandle -ne 0 -and $p.MainWindowTitle -like "*$windowTitleKeyword*") {
                $isRunningWithWindow = $true
                break
            }
        }
    }

    if ($isRunningWithWindow) {
        $runningCount++

        if ($runningCount -ge $requiredStableTime) {
            if (-not $wasResponding) {
                Write-Host "[$(Get-Date)] Aplikasi berjalan normal. Timer direset."
                Write-Log "Aplikasi berjalan kembali."
            }

            $remainingTime = $timeout
            $wasResponding = $true
        }

        Write-Progress -Activity "Monitoring $appName" `
                       -Status "Stabil ($runningCount detik)" `
                       -PercentComplete 100

        if ($runningCount -ge $maxStableDuration) {
            Write-Host "[$(Get-Date)] Aplikasi berjalan stabil 2 menit. Restart sebagai reset."
            Write-Log "Aplikasi berjalan stabil selama 2 menit. Restart untuk reset."

            Stop-Process -Name ($appName -replace ".exe", "") -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 20
            Start-Process -FilePath $shortcutPath

            Write-Log "Restart dilakukan setelah 2 menit stabil."
            $remainingTime = $timeout
            $wasResponding = $true
            $runningCount  = 0
        }
    } else {
        $runningCount = 0
        $wasResponding = $false
        $remainingTime -= $checkInterval

        $percent = 100 - (($remainingTime / $timeout) * 100)
        Write-Progress -Activity "Monitoring $appName" `
                       -Status "Tidak responsif. Restart dalam $remainingTime detik" `
                       -PercentComplete $percent

        if ($remainingTime -le 0) {
            Write-Host "[$(Get-Date)] Timeout tercapai. Restarting $appName..."
            Write-Log "$appName tidak merespons. Melakukan restart."

            Stop-Process -Name ($appName -replace ".exe", "") -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 20
            Start-Process -FilePath $shortcutPath

            Write-Log "Restart dilakukan karena aplikasi tidak responsif."
            $remainingTime = $timeout
            $wasResponding = $true
            $runningCount  = 0
        }
    }

    Start-Sleep -Seconds $checkInterval
}