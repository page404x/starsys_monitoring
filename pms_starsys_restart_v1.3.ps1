# --- Konfigurasi ---
$appName            = "Pms.exe"
$windowTitleKeyword = "Pms"  # Keyword nama aplikasi
$shortcutPath       = "C:\Users\trans\Desktop\Pms.lnk"  # Ganti ke lokasi shortcut aplikasi kamu
$logFolder          = "D:\Starsys\Log"
$timeout            = 300   # dalam detik (5 menit)
$checkInterval      = 1     # cek setiap 1 detik
$requiredStableTime = 1     # dianggap stabil kalau aktif selama >= 1 detik

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

# --- Fungsi Notifikasi Toast ---
function Show-Notification($title, $message) {
    $template = @"
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null

$xml = @"
<toast duration='long'>
  <visual>
    <binding template='ToastGeneric'>
      <text>$title</text>
      <text>$message</text>
    </binding>
  </visual>
  <audio src='ms-winsoundevent:Notification.Default' />
</toast>
"@

$doc = New-Object Windows.Data.Xml.Dom.XmlDocument
$doc.LoadXml($xml)

$toast = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PMS Watcher")
$toast.Show($doc)
"@
    Invoke-Expression $template
}

# --- Buat folder log jika belum ada ---
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
            Write-Log "Notifikasi dikirim ke user."

            $remainingTime = $timeout
            $wasResponding = $true
            $runningCount  = 0
        }
    }

    Start-Sleep -Seconds $checkInterval
}