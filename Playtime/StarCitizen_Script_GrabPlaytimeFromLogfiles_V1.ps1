#GET INSTALLATION PATH FROM LAST LAUNCHER STARTUP, MIGHT POINT TO LIVE OR PTU, DEPENDS WHICH WAS LAUNCHED LAST TIME
$LogfileLauncher = "$env:APPDATA\rsilauncher\log.log"       
$CurrentGameDetails = Get-Content -Path $LogfileLauncher | Select-String -Pattern "Launching Star Citizen" | Select-Object -Last 1
$GameDir = ($CurrentGameDetails.Line.split('(').split(')').replace("\\","\"))[1]
$logDirectory = "$GameDir\logbackups"

#OTHERWISE SET UR DIRECTORY HERE MANUALLY
#$logDirectory = "C:\Spiele\StarCitizen\StarCitizen\LIVE\logbackups"


$LogFiles = Get-ChildItem $logDirectory

$TimeFormat = [System.Globalization.CultureInfo]::GetCultureInfo(1031).DateTimeFormat.FullDateTimePattern
$InFormat = "yyyy-MM-ddTHH:mm:ss.SSSZ"


#| ForEach-Object -Parallel{
& { 
    $sum = 0
    $PlaytimeSummary = @()
    foreach ($logfile in $LogFiles){
        #$logfile
        
        $Logdate = ($logfile | Get-ChildItem).LastWriteTime #get date from file
        $LogContent = $logfile | Get-Content  #get content of logfile
        
        #Iterate through logfile until a tiemstamp was found
        $StartCounter = 25
        do{
            $LogStart = try {(Get-Date ($LogContent[$StartCounter].split("<z>")[1]) -UFormat '+%Y-%m-%dT%H:%M:%S.000Z' -ErrorAction SilentlyContinue)}catch{}
            $StartCounter += 1
        }
        until($LogStart -as [DateTime])
        #$StartCounter

        #In case of crash iterate through logfile until a date was found
        $EndCounter = -1
        do{
            $LogEnd = try {(Get-Date ($LogContent[$EndCounter].split("<z>")[1]) -UFormat '+%Y-%m-%dT%H:%M:%S.000Z' -ErrorAction SilentlyContinue)}catch{}
            $EndCounter -= 1
        }
        until($LogEnd -as [DateTime])
        #$EndCounter

        $LogStart2 = Get-Date $LogStart -UFormat '+%Y-%m-%dT%H:%M:%S.000Z'
        $LogEnd2 = Get-Date $LogEnd -UFormat '+%Y-%m-%dT%H:%M:%S.000Z'
        $Playtime = (NEW-TIMESPAN –End $LogEnd2 -Start $LogStart2).TotalHours
        $item = [PSCustomObject]@{
            #Date     = $Logdate
            Playtime = [Math]::Round($Playtime, 2)
            Start    = Get-Date $LogStart2 -Format $TimeFormat
            End      = Get-Date $LogEnd2 -Format $TimeFormat
        }
        $PlaytimeSummary += $item #store all data in an array
        $sum += $Playtime # store all durations in a variable
        $item #Output Result to liveview
        $Logdate = $LogContent = $LogStart = $LogEnd = $LogStart2 = $LogEnd2 = $Playtime = "" #reset all values for next loop, just worst case
    }
    $Summary = [PSCustomObject]@{
        Playtime = $sum
        Start    = "Total"
        End      = "Hours"
    }
    $Summary
} | Out-GridView -Wait -Title "Star Citizen Playtime Analysis"
