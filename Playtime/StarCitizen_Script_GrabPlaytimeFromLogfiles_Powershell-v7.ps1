$debug = $false
$ErrorActionPreference = 'SilentlyContinue'
#$ProgressPreference = "Continue"

if((Get-Host).Version.Major -le "5"){Write-Host "v5";$psv = 5}
if((Get-Host).Version.Major -ge "7"){Write-Host "v7";$psv = 7}

#GET INSTALLATION PATH FROM LAST LAUNCHER STARTUP, MIGHT POINT TO LIVE OR PTU, DEPENDS WHICH WAS LAUNCHED LAST TIME
$LogfileLauncher = "$env:APPDATA\rsilauncher\log.log"       
$CurrentGameDetails = Get-Content -Path $LogfileLauncher | Select-String -Pattern "Launching Star Citizen" | Select-Object -Last 1
$GameDir = ($CurrentGameDetails.Line.split('(').split(')').replace("\\","\"))[1]
if($GameDir -like '*\PTU'){$GameDir = $GameDir.replace('\PTU','\LIVE')}
$LiveLogDirectory = "$GameDir\logbackups"


if ((Get-ChildItem "$($GameDir.replace('\LIVE','\PTU'))\logbackups").count -gt 0){
    $PtuLogDirectory  = "$($GameDir.replace('\LIVE','\PTU'))\logbackups"
    $LogFiles = Get-ChildItem $LiveLogDirectory, $PtuLogDirectory
}
else{
    $LogFiles = Get-ChildItem $LiveLogDirectory
}

#Output Paths to User
if($debug){
    Write-Host -ForegroundColor Gray "LIVE Log: $LiveLogDirectory"
    Write-Host -ForegroundColor Gray "PTU Log: $PtuLogDirectory"
}

$TimeFormat = [System.Globalization.CultureInfo]::GetCultureInfo(1031).DateTimeFormat.FullDateTimePattern
$InFormat = "yyyy-MM-ddTHH:mm:ss.SSSZ"

$sum = $LiveSum = $PtuSum = 0
$i = 0

#| ForEach-Object -Parallel{

$PlaytimeSummary = @()
foreach ($logfile in $LogFiles){
#$LogFiles | ForEach-Object -Parallel{  
    #Progress Bar for Powershell V7
    $i += 1
    $Completed = ($i/$LogFiles.count) * 100
    Write-Progress -Activity "Grabbing Playtimes" -Status "Progressing Logfile $i of $($LogFiles.count)" -PercentComplete $Completed -ID 1

    if($debug){Write-Host $logfile}
    $LogPath = ($logfile | Get-ChildItem).FullName
    if ($LogPath -like "*StarCitizen\LIVE\logbackups*"){$Environment = "LIVE"}else{$Environment = "PTU"}
    #$Environment
    $Logdate = ($logfile | Get-ChildItem).LastWriteTime #get date from file
    $LogContent = $logfile | Get-Content  #get content of logfile
    
    #if($debug){Write-Host $LogContent}

    #Iterate through logfile until a tiemstamp was found
    $StartCounter = 25
    do{
        Write-Progress -Activity "Detecting Starttime" -Status "Checking Line $StartCounter of 500" -PercentComplete ($StartCounter/500*100) -ID 2
        $LogStart = (Get-Date ($LogContent[$StartCounter].split("<").split("z").split(">")[1]) -UFormat '+%Y-%m-%dT%H:%M:%S.000Z')

        $StartCounter += 1
        if($debug){Write-Host $StartCounter}
    }
    until($LogStart -as [DateTime] -OR $StartCounter -gt 500)
    Write-Progress -Activity "Detecting Starttime" -ID 2 -Completed
    #$StartCounter

    #In case of crash iterate through logfile until a date was found
    $EndCounter = -1
    do{
        Write-Progress -Activity "Detecting Endtime" -Status "Checking Line $StartCounter of 500" -PercentComplete ($StartCounter/500*100) -ID 3
        $LogEnd = (Get-Date ($LogContent[$EndCounter].split("<").split("z").split(">")[1]) -UFormat '+%Y-%m-%dT%H:%M:%S.000Z')

        $EndCounter -= 1
        if($debug){Write-Host $EndCounter}
    }
    until($LogEnd -as [DateTime] -OR $EndCounter -lt -500)
    Write-Progress -Activity "Detecting Endtime" -ID 3 -Completed
    #$EndCounter

    $LogStart2 = Get-Date $LogStart -UFormat '+%Y-%m-%dT%H:%M:%S.000Z'
    $LogEnd2 = Get-Date $LogEnd -UFormat '+%Y-%m-%dT%H:%M:%S.000Z'
    $Playtime = (NEW-TIMESPAN –End $LogEnd2 -Start $LogStart2).TotalHours
    $item = [PSCustomObject]@{
        Environment = $Environment 
        Playtime = [Math]::Round($Playtime, 2)
        Start    = Get-Date $LogStart2 -Format $TimeFormat
        End      = Get-Date $LogEnd2 -Format $TimeFormat
    }
    $PlaytimeSummary += $item #store all data in an array
    $sum += $Playtime # store all durations in a variable
    if ($LogPath -like "*\StarCitizen\LIVE\logbackups*"){$LiveSum += $Playtime}else{$PtuSum += $Playtime}

    #$item #Output Result to liveview
    if($debug){Write-Host $item}
    $Logdate = $LogContent = $LogStart = $LogEnd = $LogStart2 = $LogEnd2 = $Playtime = "" #reset all values for next loop, just worst case
}
Write-Progress -Activity "Grabbing Playtimes" -ID 1 -Completed

$LiveSummary = [PSCustomObject]@{
    Environment = "LIVE Summary"
    Playtime = $LiveSum
    Start    = "Total"
    End      = "Hours"
}
$PlaytimeSummary += $LiveSummary

$PtuSummary = [PSCustomObject]@{
    Environment = "PTU Summary"
    Playtime = $PtuSum
    Start    = "Total"
    End      = "Hours"
}
$PlaytimeSummary += $PtuSummary

$Summary = [PSCustomObject]@{
    Environment = "Total Summary"
    Playtime = $sum
    Start    = "Total"
    End      = "Hours"
}
$PlaytimeSummary += $Summary

$PlaytimeSummary | Out-GridView -Wait -Title "Star Citizen Playtime Analysis"