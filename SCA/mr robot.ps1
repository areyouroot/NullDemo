$ErrorActionPreference = "Stop"

Write-Host "I am a vibe coder"

$projectDir = "test project"

if (!(Test-Path $projectDir)) {
    Write-Error "The 'test project' folder does not exist. Please run 'Create pilot.ps1' first."
}

Write-Host "Injecting vulnerable dependencies..."

# Inject vulnerable Newtonsoft.Json into the C# project
# Specifically adding version 12.0.3 which has known vulnerabilities (e.g., CVE-2024-21319)
$csprojPath = Get-ChildItem -Path $projectDir -Filter "*.csproj" | Select-Object -First 1
if ($csprojPath) {
    Write-Host "Adding vulnerable Newtonsoft.Json to $($csprojPath.Name)"
    Set-Location $projectDir
    dotnet add package Newtonsoft.Json --version 12.0.3
    Set-Location ..
} else {
    Write-Host "Could not find a .csproj file to inject Newtonsoft.Json"
}

# Inject vulnerable packages into the Angular package.json
# We'll use 'request' (deprecated and has vulns) and 'lodash' (older version with prototype pollution)
$packageJsonPath = "$projectDir\ClientApp\package.json"

# In newer angular templates from dotnet, package.json might be in a different place, try finding it
if (!(Test-Path $packageJsonPath)) {
    $packageJsonPath = (Get-ChildItem -Path $projectDir -Filter "package.json" -Recurse | Select-Object -First 1).FullName
}

if ($packageJsonPath -and (Test-Path $packageJsonPath)) {
    Write-Host "Adding vulnerable npm packages to $($packageJsonPath)"

    $json = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
    if (!($json.dependencies)) {
        $json | Add-Member -MemberType NoteProperty -Name "dependencies" -Value @{}
    }

    # Adding known vulnerable versions
    $json.dependencies | Add-Member -MemberType NoteProperty -Name "lodash" -Value "4.17.15" -Force
    $json.dependencies | Add-Member -MemberType NoteProperty -Name "request" -Value "2.88.2" -Force

    $json | ConvertTo-Json -Depth 10 | Set-Content $packageJsonPath

    Write-Host "Running npm install to update lockfile..."
    $packageJsonDir = Split-Path $packageJsonPath
    Push-Location $packageJsonDir
    npm install --package-lock-only
    Pop-Location

} else {
    Write-Host "Could not find package.json to inject vulnerable npm packages."
}

Write-Host "Vulnerabilities injected successfully."
