using namespace Windows.Storage
using namespace Windows.Graphics.Imaging
Add-Type -AssemblyName System.Drawing

function Test-AltKey {
  # key code for ALT key:
  $key = 19
  #18 = ALT
  #19 = PAUSE    
    
  # this is the c# definition of a static Windows API method:
  $Signature = @'
    [DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
    public static extern short GetAsyncKeyState(int virtualKeyCode); 
'@

  Add-Type -MemberDefinition $Signature -Name Keyboard -Namespace PsOneApi
  [bool]([PsOneApi.Keyboard]::GetAsyncKeyState($key) -eq -32767)
}
function Get-ScreenCapture {
    Add-Type -AssemblyName System.Windows.Forms
    Add-type -AssemblyName System.Drawing

    $File = "$env:TEMP\ScreenCapturePlayer.jpg"

    $Screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = New-Object System.Drawing.Bitmap $Screen.Width, $Screen.Height
    $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphic.CopyFromScreen(0, 0, 0, 0, $bitmap.Size)

    $bitmap.Save($File)
    #Write-Host "saved image"
    $bitmap.Dispose()
}
function Crop-Screenshot {
    #$XCoord = "1960"
    #$YCoord = "850"
    $XCoord = "40"
    $YCoord = "852"
    #$CropX = "250"
    #$CropY = "10"

    $src=[System.Drawing.Image]::FromFile("$env:TEMP\ScreenCapturePlayer.jpg")
    $destRect = new-object Drawing.Rectangle (0, 0, $src.Width, $src.Height) # top, left, width, height
    $srcRect = new-object Drawing.Rectangle ($XCoord,$YCoord, $src.Width, $src.Height) # top, left, width, height
    $bmp=new-object System.Drawing.Bitmap 200,50
    $graphics=[System.Drawing.Graphics]::FromImage($bmp)
    $units = [System.Drawing.GraphicsUnit]::Pixel
    $graphics.DrawImage($src, $destRect, $srcRect, $units)
    $graphics.Dispose()
    $InputFile = "$env:TEMP\ScreenCapturePlayer_cropped.jpg"
    #$OutputFile = "$pwd\ScreenCapture_scaled.png"
    $bmp.Save($InputFile)
    #Resize-Image -InputFile $InputFile -OutputFile $OutputFile -Scale 150
    #Write-Host "cropped image"
}
function Get-WindowsOCR{
    <#
    .Synopsis
       Runs Windows 10 OCR on an image.
    .DESCRIPTION
       Takes a path to an image file, with some text on it.
       Runs Windows 10 OCR against the image.
       Returns an [OcrResult], hopefully with a .Text property containing the text
    .EXAMPLE
       $result = .\Get-Win10OcrTextFromImage.ps1 -Path 'c:\test.bmp'
       $result.Text
    #>
    [CmdletBinding()]
    Param
    (
        # Path to an image file
        [Parameter(Mandatory=$true, 
                    ValueFromPipeline=$true,
                    ValueFromPipelineByPropertyName=$true, 
                    Position=0,
                    HelpMessage='Path to an image file, to run OCR on')]
        [ValidateNotNullOrEmpty()]
        $Path
    )

                                                                                                            Begin {
    # Add the WinRT assembly, and load the appropriate WinRT types
    Add-Type -AssemblyName System.Runtime.WindowsRuntime

    $null = [Windows.Storage.StorageFile,                Windows.Storage,         ContentType = WindowsRuntime]
    $null = [Windows.Media.Ocr.OcrEngine,                Windows.Foundation,      ContentType = WindowsRuntime]
    $null = [Windows.Foundation.IAsyncOperation`1,       Windows.Foundation,      ContentType = WindowsRuntime]
    $null = [Windows.Graphics.Imaging.SoftwareBitmap,    Windows.Foundation,      ContentType = WindowsRuntime]
    $null = [Windows.Storage.Streams.RandomAccessStream, Windows.Storage.Streams, ContentType = WindowsRuntime]
    
    
    # [Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages
    $ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
    

    # PowerShell doesn't have built-in support for Async operations, 
    # but all the WinRT methods are Async.
    # This function wraps a way to call those methods, and wait for their results.
    $getAwaiterBaseMethod = [WindowsRuntimeSystemExtensions].GetMember('GetAwaiter').
                                Where({
                                        $PSItem.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
                                    }, 'First')[0]

    Function Await {
        param($AsyncTask, $ResultType)

        $getAwaiterBaseMethod.
            MakeGenericMethod($ResultType).
            Invoke($null, @($AsyncTask)).
            GetResult()
    }
    }

    Process
                                                                                                                                                {
    foreach ($p in $Path)
    {
      
        # From MSDN, the necessary steps to load an image are:
        # Call the OpenAsync method of the StorageFile object to get a random access stream containing the image data.
        # Call the static method BitmapDecoder.CreateAsync to get an instance of the BitmapDecoder class for the specified stream. 
        # Call GetSoftwareBitmapAsync to get a SoftwareBitmap object containing the image.
        #
        # https://docs.microsoft.com/en-us/windows/uwp/audio-video-camera/imaging#save-a-softwarebitmap-to-a-file-with-bitmapencoder

        # .Net method needs a full path, or at least might not have the same relative path root as PowerShell
        $p = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
        
        $params = @{ 
            AsyncTask  = [StorageFile]::GetFileFromPathAsync($p)
            ResultType = [StorageFile]
        }
        $storageFile = Await @params


        $params = @{ 
            AsyncTask  = $storageFile.OpenAsync([FileAccessMode]::Read)
            ResultType = [Streams.IRandomAccessStream]
        }
        $fileStream = Await @params


        $params = @{
            AsyncTask  = [BitmapDecoder]::CreateAsync($fileStream)
            ResultType = [BitmapDecoder]
        }
        $bitmapDecoder = Await @params


        $params = @{ 
            AsyncTask = $bitmapDecoder.GetSoftwareBitmapAsync()
            ResultType = [SoftwareBitmap]
        }
        $softwareBitmap = Await @params

        # Run the OCR
        Await $ocrEngine.RecognizeAsync($softwareBitmap) ([Windows.Media.Ocr.OcrResult])
        #Write-Host "OCRed image"

    }
    }
}
function Open-PlayerStats {
    $URL = "https://mobitracker.co/$Result"
    Start-Process "C:\Program Files\Mozilla Firefox\firefox.exe" -ArgumentList "-new-tab $URL"
    }

Write-Warning 'Hold PAUSE to check current Name'
while ($true)
{
    Write-Host '.' -NoNewline
    $pressed = Test-AltKey
    if ($pressed) {
        Get-ScreenCapture
        Crop-Screenshot
        $Result = ((Get-WindowsOCR -Path "$env:TEMP\ScreenCapturePlayer_cropped.jpg").Text -split ">" -split " ")[0]
        if($Result){
            Write-Host "$Result"
            Open-PlayerStats
            }
        Start-Sleep -Seconds 5
        #Remove-Item -Path "$env:TEMP\ScreenCapture.jpg"
        #Remove-Item -Path "$env:TEMP\ScreenCapture_cropped.jpg"
        Start-Sleep -Seconds 1
    }
    Start-Sleep -Milliseconds 700
}