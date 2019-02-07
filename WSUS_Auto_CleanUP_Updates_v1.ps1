$WSUSServer = ''
$Port = ''

$i = 0

$DataFrom = (get-date).AddDays(-120)
$DataLast = (get-date).AddDays(-30)

$Log = "C:\temp\Log-Auto_CleanUP_WSUS-$(Get-Date -Format "dd.MM.yyyy_hh.mm.ss tt").log"

Write-Progress -Activity 'Armazenando as informações do WSUS'

$SrvWsus = Get-WsusServer -Name $WSUSServer -PortNumber $Port

Add-Content -Path $Log -Value "** LOG DE LIMPEZA DO WSUS ** `r`nData da criação: $DataAtual"
Add-Content -Path $Log -Value "`r`n`r`n** IDENTIFICAÇÃO DO SERVIDOR WSUS ** `r`nServidor WSUS: $WSUSServer `r`nPorta: $Port"

Write-Progress -Activity 'Coletando os uptades, este processo pode demorar...' -PercentComplete -1

$AnyUpd = Get-WsusUpdate -UpdateServer $SrvWsus -Approval AnyExceptDeclined -Status Any

Write-Progress -Activity 'Updates coletados' -PercentComplete 90

$SupersededUdp = $AnyUpd | ? {$_.Update.IsSuperseded -eq $True -or $_.Update.Title -like "*Itanium*" -or $_.Update.Title -like "*Multipoint*" -or $_.Update.Title -like "*Windows Storage Server*" -or $_.Update.Title -like "*32 Bits*" -or $_.Update.Title -like "*x86*" -and $_.ComputersNeedingThisUpdate -eq 0}
$SupersededUdpTotal = $SupersededUdp.count

Add-Content -Path $Log -Value "`r`n`r`n** ATUALIZAÇÕES DECLINADAS **"

ForEach ($Update in $SupersededUdp)
{

    Write-Progress -Activity 'Declinando os updates' -Status "$($Update.Update.Title)" -PercentComplete (($i/$SupersededUdpTotal) * 100)
    $Update.Update.Decline()
    $DeclUpdLog = $Update.Update.Title
    Add-Content -Path $Log -Value "$DeclUpdLog"
    $i++

}
Add-Content -Path $Log -Value "`r`nTotal de updates declinados= $SupersededUdpTotal"

Add-Content -Path $Log -Value "`r`n`** COMPUTADORES COM MAIS DE 30 DIAS SEM COMUNICAÇÃO COM WSUS **"
Get-WsusComputer -FromLastReportedStatusTime $DataFrom -ToLastReportedStatusTime $DataLast | Where {$_.OSDescription -notlike "*Windows Server*"} | Sort-Object LastReportedStatusTime | Out-File $Log -Append utf8

Add-Content -Path $Log -Value "`r`n** COMPUTADORES QUE NUNCA REPORTARAM PARA O WSUS **"
Get-WsusComputer -FromLastReportedStatusTime 01/01/0001 -ToLastReportedStatusTime 01/01/0001 | Out-File $Log -Append utf8

Add-Content -Path $Log -Value "`r`n** SERVIDORES COM MAIS DE 30 DIAS SEM COMUNICAÇÃO COM WSUS **"
Get-WsusComputer -FromLastReportedStatusTime $DataFrom -ToLastReportedStatusTime $DataLast | Where {$_.OSDescription -like "*Windows Server*"} | Sort-Object LastReportedStatusTime | Out-File $Log -Append utf8

Add-Content -Path $Log -Value "`r`n** SERVIDORES QUE NUNCA SE COMUNICARAM COM WSUS **`r`n"
Get-WsusComputer -FromLastReportedStatusTime 01/01/0001 -ToLastReportedStatusTime 01/01/0001 | Where {$_.OSDescription -like "*Windows Server*"} | Sort-Object LastReportedStatusTime | Out-File $Log -Append utf8


Write-Progress -Activity 'Efetuando a limpeza dos updates, este processo pode demorar...' -PercentComplete -1

Invoke-WsusServerCleanup -CleanupObsoleteComputers -CleanupObsoleteUpdates -CleanupUnneededContentFiles -CompressUpdates -DeclineExpiredUpdates | Out-File $Log -Append utf8