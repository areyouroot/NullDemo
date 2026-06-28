$ErrorActionPreference = "Stop"

$projectDir = "test project"

if (!(Test-Path $projectDir)) {
    Write-Error "The 'test project' folder does not exist."
}

Write-Host "Updating vulnerable dependencies..."

# Fix C# Project (Newtonsoft.Json)
$csprojPath = Get-ChildItem -Path $projectDir -Filter "*.csproj" | Select-Object -First 1
if ($csprojPath) {
    Write-Host "Updating Newtonsoft.Json to a safe version in $($csprojPath.Name)"
    Set-Location $projectDir
    # Remove the vulnerable package and add latest stable
    dotnet remove package Newtonsoft.Json
    dotnet add package Newtonsoft.Json
    Set-Location ..
}

# Fix Angular Project (npm packages)
$packageJsonFile = Get-ChildItem -Path $projectDir -Filter "package.json" -Recurse | Select-Object -First 1
if ($packageJsonFile) {
    $packageJsonPath = $packageJsonFile.FullName
    $packageJsonDir = $packageJsonFile.Directory.FullName
    Write-Host "Updating vulnerable npm packages in $packageJsonPath"

    $json = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
    if ($json.dependencies) {
        if ($json.dependencies."lodash") {
            # Update lodash to latest safe
            $json.dependencies."lodash" = "^4.17.21"
        }
        if ($json.dependencies."request") {
            # Request is deprecated, usually we'd remove it, but we can set to latest version
            # or remove entirely. We'll remove it.
            $json.dependencies.PSObject.Properties.Remove("request")
        }
    }
    $json | ConvertTo-Json -Depth 10 | Set-Content $packageJsonPath

    Write-Host "Running npm install to update lockfile..."
    Set-Location $packageJsonDir
    npm install
    Set-Location -Path $PSScriptRoot
}


Write-Host "Applying Security Configuration Rules..."

# 1. Enforce Package Source Mapping & 3. Enforce Code-Signing Verification
$nugetConfigPath = "$projectDir\nuget.config"
$nugetConfigContent = @"
<configuration>
  <packageSources>
    <clear /> <!-- Clears machine-level global inheritance -->
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
    <add key="internal-feed" value="https://azure.com" />
  </packageSources>

  <packageSourceMapping>
    <!-- Route all public packages strictly to nuget.org -->
    <packageSource key="nuget.org">
      <package pattern="Microsoft.*" />
      <package pattern="System.*" />
      <package pattern="Newtonsoft.Json" />
    </packageSource>
    <!-- Route your corporate packages strictly to your private feed -->
    <packageSource key="internal-feed">
      <package pattern="MyCompany.*" />
    </packageSource>
  </packageSourceMapping>

  <!-- Require signature verification for all downloaded packages -->
  <config>
    <add key="signatureValidationMode" value="require" />
  </config>
  <trustedSigners>
    <repository name="nuget.org" serviceIndex="https://api.nuget.org/v3/index.json">
      <certificate fingerprint="0E5F38F57DC1BCC806D8494F4F90FBCEDD988B46760709CBEEC6F4219AA6157D" hashAlgorithm="SHA256" allowUntrustedRoot="false" />
    </repository>
  </trustedSigners>
</configuration>
"@
Set-Content -Path $nugetConfigPath -Value $nugetConfigContent
Write-Host "Created nuget.config"


# 2. Lock Down Version Floating & 4. Enable Native NuGet Auditing
$dirBuildPropsPath = "$projectDir\Directory.Build.props"
$dirBuildPropsContent = @"
<Project>
  <PropertyGroup>
    <!-- Enable Lockfiles -->
    <RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>

    <!-- Enable Native NuGet Auditing -->
    <NuGetAudit>true</NuGetAudit>
    <!-- Treat security warnings as errors to stop the build -->
    <WarningsAsErrors>`$(WarningsAsErrors);NU1901;NU1902;NU1903;NU1904</WarningsAsErrors>
  </PropertyGroup>
</Project>
"@
Set-Content -Path $dirBuildPropsPath -Value $dirBuildPropsContent
Write-Host "Created Directory.Build.props"


# 5. Utilize Update Cooldowns via Dependency Bots (Dependabot config)
$githubDir = "$projectDir\.github"
if (!(Test-Path $githubDir)) {
    New-Item -ItemType Directory -Path $githubDir | Out-Null
}
$dependabotPath = "$githubDir\dependabot.yml"
$dependabotContent = @"
version: 2
updates:
  - package-ecosystem: "nuget"
    directory: "/"
    schedule:
      interval: "weekly"
    # Dependabot ignores newly minted updates for a safer timeline
    minimum-package-age: 3 # Wait 3 days after release
"@
Set-Content -Path $dependabotPath -Value $dependabotContent
Write-Host "Created .github/dependabot.yml"


# NPM Supply Chain Defenses (.npmrc)
# Enforce a Dependency Cooldown Period, Disable Lifecycle Scripts Globally,
# Guard Against Dependency Confusion
if ($packageJsonFile) {
    $npmrcPath = "$($packageJsonFile.Directory.FullName)\.npmrc"
    $npmrcContent = @"
# Enforce Dependency Cooldown (if using pnpm, but good to have)
minimumReleaseAge=1440

# Disable Lifecycle Scripts Globally
ignore-scripts=true

# Guard Against Dependency Confusion (Example scope lock)
@mycompany:registry=https://mycompany.internal
"@
    Set-Content -Path $npmrcPath -Value $npmrcContent
    Write-Host "Created .npmrc"
}

Write-Host "Remediation and security hardening completed successfully."
