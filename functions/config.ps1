$environmentsPath = "~/.environments.json"

Function SaveConfig {
    param (	
	[object]$Data
    )

    
    $jsonContent = LoadRaw 

    # Convert the JSON content to PowerShell objects
    $fixedEnvironments = $jsonContent | ConvertFrom-Json

    $environments = New-Object System.Collections.ArrayList
    if ($fixedEnvironments) {
        $environments.Add($fixedEnvironments)
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
	    $index = $environments.Add($Data)
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
