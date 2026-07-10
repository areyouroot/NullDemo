$ErrorActionPreference = "Stop"

$projectDir = "C:\sast\vuln_ecommerce"
$sonarScannerDir = "C:\sast\net"
$env:Path = "$sonarScannerDir;" + $env:Path

Write-Host "=========================================================="
Write-Host " SonarQube Interactive Scanner "
Write-Host "=========================================================="
Write-Host "Opening SonarQube web UI. Please log in (admin/admin), change your password, and create a local project to generate a token."

# Open browser
Start-Process "http://localhost:9000"

# Prompt for credentials
$projectKey = Read-Host "Enter the Project Key from SonarQube UI"
$projectName = Read-Host "Enter the Project Name from SonarQube UI"
$token = Read-Host "Enter the generated Token Key from SonarQube UI"

if (-not $projectKey -or -not $token) {
    Write-Host "Project Key and Token are required to scan. Exiting..."
    Start-Sleep -Seconds 3
    exit
}

Write-Host "`nStarting SonarQube analysis on $projectDir..."
Set-Location $projectDir

# Begin scan
Write-Host "Running: dotnet sonarscanner begin"
# Since it's downloaded as standalone msbuild scanner zip instead of dotnet global tool,
# the executable is SonarScanner.MSBuild.exe
SonarScanner.MSBuild.exe begin /k:"$projectKey" /n:"$projectName" /d:sonar.host.url="http://localhost:9000" /d:sonar.token="$token"

# Build project
Write-Host "Running: dotnet build"
dotnet build

# End scan
Write-Host "Running: dotnet sonarscanner end"
SonarScanner.MSBuild.exe end /d:sonar.token="$token"

Write-Host "=========================================================="
Write-Host "SonarQube is analysing the code pls wait check the sonarqube web ui"
Write-Host "This console will close in 10 seconds..."
Start-Sleep -Seconds 10
Exit
