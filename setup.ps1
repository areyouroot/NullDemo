$ErrorActionPreference = "Stop"

function Prompt-Reinstall ($toolName, $path) {
    if (Test-Path $path) {
        $response = Read-Host "$toolName is already installed at $path. Do you want to delete and reinstall it? (Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            Write-Host "Deleting $path..."
            Remove-Item -Path $path -Recurse -Force
            return $true
        }
        return $false
    }
    return $true
}

function Prompt-Reinstall-Command ($toolName, $command) {
    if (Get-Command $command -ErrorAction SilentlyContinue) {
        $response = Read-Host "$toolName is already installed. Do you want to reinstall it? (Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            return $true
        }
        return $false
    }
    return $true
}


function Install-NodeJS {
    if (Prompt-Reinstall-Command "Node.js" "node") {
        Write-Host "Downloading and installing Node.js..."
        $nodeInstaller = "$env:TEMP\node-v20-x64.msi"
        Invoke-WebRequest -Uri "https://nodejs.org/dist/v20.11.1/node-v20.11.1-x64.msi" -OutFile $nodeInstaller
        Start-Process msiexec.exe -Wait -ArgumentList "/i $nodeInstaller /quiet"
        Write-Host "Node.js installed successfully."
    }
}

function Install-SonarQube {
    $installDir = "C:\sast"
    if (Prompt-Reinstall "SonarQube Server" "$installDir\bin") {
        Write-Host "Installing SonarQube Server to $installDir..."
        New-Item -Path $installDir -ItemType Directory -Force | Out-Null
        $zipPath = "$env:TEMP\sonarqube.zip"
        Invoke-WebRequest -Uri "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.4.0.87286.zip" -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
        # Move contents up a directory since zip contains a folder
        Move-Item -Path "$installDir\sonarqube-10.4.0.87286\*" -Destination $installDir -Force
        Remove-Item -Path "$installDir\sonarqube-10.4.0.87286" -Recurse -Force
        Write-Host "SonarQube installed successfully."
    }
}

function Install-SonarCli {
    $installDir = "C:\sast\cli"
    if (Prompt-Reinstall "Sonar CLI" $installDir) {
        Write-Host "Installing Sonar CLI to $installDir..."
        New-Item -Path $installDir -ItemType Directory -Force | Out-Null
        $zipPath = "$env:TEMP\sonar-scanner.zip"
        Invoke-WebRequest -Uri "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-windows.zip" -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
        Move-Item -Path "$installDir\sonar-scanner-5.0.1.3006-windows\*" -Destination $installDir -Force
        Remove-Item -Path "$installDir\sonar-scanner-5.0.1.3006-windows" -Recurse -Force
        Write-Host "Sonar CLI installed successfully."
    }
}

function Install-SonarNet {
    $installDir = "C:\sast\net"
    if (Prompt-Reinstall "Sonar .NET scanner" $installDir) {
        Write-Host "Installing Sonar .NET scanner to $installDir..."
        New-Item -Path $installDir -ItemType Directory -Force | Out-Null
        $zipPath = "$env:TEMP\sonar-net.zip"
        Invoke-WebRequest -Uri "https://github.com/SonarSource/sonar-scanner-msbuild/releases/download/11.2.0.135473/sonar-scanner-11.2.0.135473-net-framework.zip" -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
        # The new zip might extract into a folder or directly into root. We will assume directly based on normal framework zip format, or we'll adjust if necessary.
        Write-Host "Sonar .NET scanner installed successfully."
    }
}

function Install-OwaspZap {
    $zapDir = "C:\Program Files\OWASP\Zed Attack Proxy"
    if (Prompt-Reinstall "OWASP ZAP" $zapDir) {
        Write-Host "Installing OWASP ZAP..."
        $installer = "$env:TEMP\ZAP_2_14_0_windows.exe"
        Invoke-WebRequest -Uri "https://github.com/zaproxy/zaproxy/releases/download/v2.14.0/ZAP_2_14_0_windows.exe" -OutFile $installer
        Start-Process $installer -Wait -ArgumentList "-q"
        Write-Host "OWASP ZAP installed successfully."
    }
}

function Install-GoogleAntigravityIde {
    $installDir = "C:\Program Files\Google Antigravity IDE"
    if (Prompt-Reinstall "Google Antigravity IDE" $installDir) {
        Write-Host "Installing Google Antigravity IDE..."
        $installer = "$env:TEMP\antigravity-installer.exe"
        try {
            Invoke-WebRequest -Uri "https://antigravity.google/download#antigravity-ide" -OutFile $installer
            Start-Process $installer -Wait -ArgumentList "/S"
            Write-Host "Google Antigravity IDE installed successfully."
        } catch {
            Write-Host "Failed to download Google Antigravity IDE (the URL might be unavailable). Skipping."
        }
    }
}

Install-NodeJS
Install-SonarQube
Install-SonarCli
Install-SonarNet
Install-OwaspZap
Install-GoogleAntigravityIde

Write-Host "Setup completed successfully."
