# --- Konfigurasi ---
$appName            = "Pms.exe"
$windowTitleKeyword = "Pms"
$shortcutPath       = "C:\Users\trans\Desktop\Pms.lnk"
$logFolder          = "D:\Starsys\Log"
$timeout            = 300   # 5 menit
$checkInterval      = 1     # tiap detik
$requiredStableTime = 1     # minimal stabil 1 detik

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

# --- Fungsi Notifikasi Tray Balloon ---
function Show-Notification($title, $message) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.BalloonTipTitle = $title
    $notify.BalloonTipText = $message
    $notify.BalloonTipIcon = "Info"
    $notify.Visible = $true

    $notify.ShowBalloonTip(15000)
    Start-Sleep -Seconds 16
    $notify.Dispose()
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

            Show-Notification "$appName Direstart" "$appName tidak merespons dan telah direstart otomatis."
            Write-Log "Notifikasi tray dikirim ke user."

            $remainingTime = $timeout
            $wasResponding = $true
            $runningCount  = 0
        }
    }

    Start-Sleep -Seconds $checkInterval
}