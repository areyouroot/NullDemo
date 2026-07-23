$ErrorActionPreference = "Stop"

$javaDir = "C:\sast\java"
$sonarDir = "C:\sast\sonarqube"
$sonarScannerDir = "C:\sast\net"
$projectDir = "C:\sast\vuln_ecommerce"

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

# 1. Install Java 17
if (Prompt-Reinstall "Java 17" $javaDir) {
    Write-Host "Downloading and installing Java 17..."
    New-Item -Path $javaDir -ItemType Directory -Force | Out-Null
    $zipPath = "$env:TEMP\java17.zip"
    # Using Adoptium JDK 17
    Invoke-WebRequest -Uri "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.10%2B7/OpenJDK17U-jdk_x64_windows_hotspot_17.0.10_7.zip" -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $javaDir -Force
    Move-Item -Path "$javaDir\jdk-17.0.10+7\*" -Destination $javaDir -Force
    Remove-Item -Path "$javaDir\jdk-17.0.10+7" -Recurse -Force
}

$env:JAVA_HOME = $javaDir
$env:Path = "$javaDir\bin;" + $env:Path

# 2. Install SonarQube Community
if (Prompt-Reinstall "SonarQube Community" $sonarDir) {
    Write-Host "Downloading and installing SonarQube Community..."
    New-Item -Path $sonarDir -ItemType Directory -Force | Out-Null
    $zipPath = "$env:TEMP\sonarqube.zip"
    Invoke-WebRequest -Uri "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.4.0.87286.zip" -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $sonarDir -Force
    Move-Item -Path "$sonarDir\sonarqube-10.4.0.87286\*" -Destination $sonarDir -Force
    Remove-Item -Path "$sonarDir\sonarqube-10.4.0.87286" -Recurse -Force
}

# 3. Install SonarScanner for .NET
if (Prompt-Reinstall "SonarScanner .NET" $sonarScannerDir) {
    Write-Host "Downloading and installing SonarScanner .NET..."
    New-Item -Path $sonarScannerDir -ItemType Directory -Force | Out-Null
    $zipPath = "$env:TEMP\sonar-net.zip"
    # We download the global tool package or the zip. Using the global tool via dotnet is preferred,
    # but we'll use the zip for standalone as requested.
    Invoke-WebRequest -Uri "https://github.com/SonarSource/sonar-scanner-msbuild/releases/download/6.0.0.81631/sonar-scanner-msbuild-6.0.0.81631-net46.zip" -OutFile $zipPath
    Expand-Archive -Path $zipPath -DestinationPath $sonarScannerDir -Force
}
$env:Path = "$sonarScannerDir;" + $env:Path


# 4. Start SonarQube
Write-Host "Starting SonarQube as a background process..."
$sonarBat = "$sonarDir\bin\windows-x86-64\StartSonar.bat"
Start-Process -FilePath $sonarBat -WindowStyle Hidden
Write-Host "SonarQube is starting up. It may take a few minutes."


# 5. Scaffold Application and Inject Vulnerabilities
if (Test-Path $projectDir) {
    Remove-Item -Path $projectDir -Recurse -Force
}
Write-Host "Creating vulnerable C#/Angular e-commerce app at $projectDir..."
New-Item -Path (Split-Path $projectDir) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
Set-Location (Split-Path $projectDir)
dotnet new angular -o "vuln_ecommerce"
Set-Location $projectDir

Write-Host "Injecting vulnerable code..."
$controllerPath = "$projectDir\Controllers\ProductController.cs"
$controllerContent = @'
using Microsoft.AspNetCore.Mvc;
using System.Data.SqlClient;

namespace vuln_ecommerce.Controllers;

[ApiController]
[Route("[controller]")]
public class ProductController : ControllerBase
{
    // BAD CODE: Hardcoded connection string
    private string connectionString = "Server=myServerAddress;Database=myDataBase;User Id=myUsername;Password=myPassword;";

    [HttpGet("search")]
    public IActionResult Search(string productName)
    {
        // SQL INJECTION VULNERABILITY: Directly concatenating user input
        string query = "SELECT * FROM Products WHERE Name = '" + productName + "'";

        // REPEATED/BAD CODE block 1
        try {
            using (SqlConnection connection = new SqlConnection(connectionString)) {
                SqlCommand command = new SqlCommand(query, connection);
                connection.Open();
                SqlDataReader reader = command.ExecuteReader();
            }
        } catch { }

        // REPEATED/BAD CODE block 2 (Duplicate code)
        try {
            using (SqlConnection connection = new SqlConnection(connectionString)) {
                SqlCommand command = new SqlCommand(query, connection);
                connection.Open();
                SqlDataReader reader = command.ExecuteReader();
            }
        } catch { }

        return Ok(new { message = "Query executed (mocked)", query = query });
    }
}
'@
Set-Content -Path $controllerPath -Value $controllerContent

# Return to script root
Set-Location $PSScriptRoot

# 6. Launch interactive scan console
$interactiveScriptPath = "$PSScriptRoot\interactive_scan.ps1"
Write-Host "Launching interactive scanning console..."
Start-Process powershell -ArgumentList "-NoExit", "-File", "`"$interactiveScriptPath`""

Write-Host "Setup complete."
