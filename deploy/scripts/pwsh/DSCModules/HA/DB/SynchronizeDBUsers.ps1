param
(

    [Parameter(Mandatory)]
    [String]$AGListenerName
    
)

Import-Module dbatools
 
$primaryReplica    = Get-DbaAgReplica -SqlInstance $AGListenerName | Where Role -eq Primary
$secondaryReplicas = Get-DbaAgReplica -SqlInstance $AGListenerName | Where Role -eq Secondary
     
$LoginsOnPrimary = (Get-DbaLogin -SqlInstance $primaryReplica.Name)
     
$secondaryReplicas | ForEach-Object {
        
    $LoginsOnSecondary = (Get-DbaLogin -SqlInstance $_.Name)
     
    $diff = $LoginsOnPrimary | Where-Object Name -notin ($LoginsOnSecondary.Name)
    if($diff) {
        Copy-DbaLogin -Source $primaryReplica.Name -Destination $_.Name -Login $diff.Nane
    }   
}
