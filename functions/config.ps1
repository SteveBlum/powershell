$environmentsPath = "~/.environments.json"

Function SaveConfig {
    param (	
	[object]$Data
    )

	  $fixedEnvironments = LoadConfigAll
    $environments = New-Object System.Collections.ArrayList
    if ($fixedEnvironments) {
        $environments = $fixedEnvironments
    }

    $indexToRemove
    for ($i = 0; $i -lt $environments.Count; $i++) {
        if ($environments[$i].Name -eq $data.Name) {
            $indexToRemove = $i
            break
        }
    }

    if ($null -ne $indexToRemove) {
	    $environments.removeAt($indexToRemove)
    }
    if ($Data) {
	    $environments.Add($Data) > $null
    }
    $jsonOutput = ConvertTo-Json @($environments) -Depth 5
    $jsonOutput | Out-File $environmentsPath
}

Function LoadConfig {
    param (	
	[string]$Name
    )

    $jsonContent = LoadRaw
    $environments = $jsonContent | ConvertFrom-Json

    for ($i = 0; $i -lt $environments.Count; $i++) {
        if ($environments[$i].Name -eq $Name) {
            return $environments[$i]
        }
    }

    return @{
	    name = $name
	    port = @()
        tag = ""
    }
}

Function LoadRaw { 
    try {	
	    return Get-Content -Raw -Path $environmentsPath 
    }
    catch {
	    return "[]"
    }
}

Function LoadConfigAll {
	$SourceJson = LoadRaw
	$Target = New-Object System.Collections.ArrayList
	if($SourceJson -eq $null) {
		return $Target
	}
	$Source = $SourceJson | ConvertFrom-Json
	foreach( $row in $Source ) {
		$Target.Add($Row) > $null
	}
	return ,$Target
}
