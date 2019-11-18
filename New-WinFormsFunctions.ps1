$pref = $ErrorActionPreference
$ErrorActionPreference = "silentlycontinue"
New-Item -Path "generatedWinFormFunctions.ps1" -Value ""  -Force
([Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")).GetTypes()| ForEach-Object{
    if(New-Object System.Windows.Forms.$($_.Name)){
    "
    function New-$($_.Name){
        [OutputType([System.Windows.Forms.$($_.Name)])]
        param([HashTable]`$Property)
        New-Object System.Windows.Forms.$($_.Name) -Property `$Property
    }
    "| Out-File "generatedWinFormFunctions.ps1" -Append
    }
}
$ErrorActionPreference = $pref