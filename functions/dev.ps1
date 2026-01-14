param (
    [string]$VolumeOrDirectory,
    [string[]]$Port,
    [string]$Tag
)

. "$PSScriptRoot/config.ps1"
. "$PSScriptRoot/identities.ps1"

if ($VolumeOrDirectory) {
    $directoryOrVolume = $VolumeOrDirectory
    $name = ""

    $commandOutput = docker volume ls --format "{{.Name}}"

    $availableVolumes = ($commandOutput -split "/n")

    for ($i = 0; $i -lt $availableVolumes.length; $i++) {
        $availableVolumes[$i] = $availableVolumes[$i].ToString().Trim()
    }

    $mountType = 'bind'
    if ($availableVolumes -contains $directoryOrVolume) {
        $mountType = 'volume'
        $name = "--name=$directoryOrVolume --hostname=dev-${directoryOrVolume}"
    }

    $history = "dev-history"
    if ($mountType -eq "volume") {
        $history = $directoryOrVolume + '-history'
    }

    $data = LoadConfig -Name $directoryOrVolume

    if ($Port -And $Port[0] -eq "null") {
        $data.port = @()
    } elseif ($Port -And $Port.Length -gt 0) {
        $data.port = $Port
    }

    # Ensure ports is an array
    if (-not $data.port) {
        $data.port = @()
    }

    # Always expose port 3010 (avoid duplicates whether number or string)
    if (-not ($data.port -contains "3010") -and -not ($data.port -contains 3010)) {
        $data.port += "3010"
    }

    $ports = ""
    if ($data.port.Length -gt 0) {
        $prefix = "-p"
        foreach ($p in $data.port) {
            $mapping = $p.toString() + ":" + $p.toString()
            $ports = $ports + $prefix + $mapping + " "
        }
    }

    if ($Tag -AND $Tag -eq "null") {
        $data.tag = ""
    } elseif ($Tag -And $Tag -ne "") {
        $data.tag = $Tag
    }

    $tag = ""
    if ($data.tag -And $data.tag -ne "") {
        $tag = ":$($data.tag)"
    }

    SaveConfig -Data $data

    Write-Host "Starting environment with:"
    Write-Host "Ports:" $data.port
    Write-Host "Tag:" $data.tag

    # Change tab title in the new windows terminal
    if ($mountType -eq "volume") {
        $Host.UI.RawUI.WindowTitle = "dev ${directoryOrVolume}"
    } else {
        $absPath = (Join-Path $PWD $directoryOrVolume) | Resolve-Path
        $Host.UI.RawUI.WindowTitle = "dev ${absPath}"
    }

    $sshMount = ""
    if ($SSH_DIRECTORY) {
        $sshMount = "--mount type=bind,src=$SSH_DIRECTORY,target=/root/.ssh"
    }

    $npmrcMount = ""
    if ($NPM_FILE) {
        $npmrcMount = "--mount type=bind,src=$NPM_FILE,target=/root/.npmrc"
    }

    $gpgMount = ""
    if ($GPG_DIRECTORY) {
        $gpgMount = "--mount type=bind,src=$GPG_DIRECTORY/pubring.kbx,target=/root/.gnupg/pubring.kbx --mount type=bind,src=$GPG_DIRECTORY/trustdb.gpg,target=/root/.gnupg/trustdb.gpg --mount type=bind,src=$GPG_DIRECTORY/private-keys-v1.d,target=/root/.gnupg/private-keys-v1.d"
    }

    $sharedMount = ""
    if ($SHARED_DIRECTORY) {
        $sharedMount = "--mount type=bind,src=$SHARED_DIRECTORY,target=/root/shared"
    }

    $kubeMount = ""
    if ($KUBE_DIRECTORY) {
        $kubeMount = "--mount type=bind,src=$KUBE_DIRECTORY,target=/root/.kube"
    }

    $ngrokMount = ""
    if ($NGROK_DIRECTORY) {
        $ngrokMount = "--mount type=bind,src=$NGROK_DIRECTORY,target=/root/.config/ngrok"
    }

    $azureCacheMount = ""
    if ($AZURE_CACHE_DIRECTORY) {
        $azureCacheMount = "--mount type=bind,src=$AZURE_CACHE_DIRECTORY,target=/root/.azure"
    }

    $localVolume = "dev-local"

    $dockerMount = "--mount type=bind,src=//var/run/docker.sock,target=//var/run/docker.sock"
    $historyMount = "--mount type=volume,src=$history,target=/root/.history --env HISTFILE=/root/.history/.bash_history"
    $localMount = "--mount type=volume,src=$localVolume,target=/root/.local"
    $pipxMount = "--mount type=volume,src=dev-pipx,target=/root/.pipx"
    $npmMount = "--mount type=volume,src=dev-npm,target=/root/.npm"
    $copilotMount = "--mount type=volume,src=dev-copilot,target=/root/.config/github-copilot"

    $identityEnv = ""
    $activeIdentity = LoadActiveIdentity
    if ($activeIdentity) {
        $identityEnvMail = $activeIdentity.email
        $identityEnvName = $activeIdentity.name
        $identityEnvKeyid = $activeIdentity.keyid
        $identityEnv = "--env GIT_EMAIL=`"${identityEnvMail}`" --env GIT_USER=`"${identityEnvName}`" --env GIT_SIGNINGKEY=`"${identityEnvKeyid}`""
    }

    $llmKeys = ""
    if ($GEMINI_API_KEY) {
        $llmKeys = "${llmKeys} --env GEMINI_API_KEY=`"${GEMINI_API_KEY}`""
    }
    if ($CLAUDE_API_KEY) {
        $llmKeys = "${llmKeys} --env CLAUDE_API_KEY=`"${CLAUDE_API_KEY}`""
    }
    if ($LLM_PROVIDER) {
        $llmKeys = "${llmKeys} --env LLM_PROVIDER=`"${LLM_PROVIDER}`""
    }
    if ($LLM_MODEL) {
        $llmKeys = "${llmKeys} --env LLM_MODEL=`"${LLM_MODEL}`""
    }

    $tz = "-e TZ=Europe/Berlin"
	
	wsl.exe --distribution rancher-desktop /etc/local.d/startup.start
	Invoke-Expression "docker run ${ports} ${name} --privileged --rm ${identityEnv} ${llmKeys} ${tz} -v /root/.gnupg/S.gpg-agent:/root/.gnupg/S.gpg-agent -v /root/.gnupg/S.gpg-agent.ssh:/root/.gnupg/S.gpg-agent.ssh --mount type=${mountType},src=${directoryOrVolume},target=/root/workspace $sshMount $npmrcMount $gpgMount $sharedMount $historyMount $localMount $dockerMount $pipxMount $npmMount $copilotMount $kubeMount $ngrokMount $azureCacheMount -it --memory 24gb ${DOCKER_DEV_ENV}${tag}"

    # Undo title change
    $Host.UI.RawUI.WindowTitle = "Windows PowerShell"
} else {
    $remotes = $REMOTE_DEV_ENV.split(",")
    foreach ($remote in $remotes) {
        try {
            Write-Host "Connecting to: $remote"
            ssh -o ConnectTimeout=5 $remote
        }
        catch {
            Write-Host "Failed to connect to: $remote"
            <#Do this if a terminating exception happens#>
        }
    }
}

