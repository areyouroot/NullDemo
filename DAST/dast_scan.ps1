$ErrorActionPreference = "Stop"

$zapDir = "C:\Program Files\OWASP\Zed Attack Proxy"
$projectDir = "C:\dast\vuln_angular_app"

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

# 1. Install OWASP ZAP
if (Prompt-Reinstall "OWASP ZAP" $zapDir) {
    Write-Host "Downloading and installing OWASP ZAP..."
    $installer = "$env:TEMP\ZAP_2_14_0_windows.exe"
    Invoke-WebRequest -Uri "https://github.com/zaproxy/zaproxy/releases/download/v2.14.0/ZAP_2_14_0_windows.exe" -OutFile $installer
    Start-Process $installer -Wait -ArgumentList "-q"
    Write-Host "OWASP ZAP installed."
}

# 2. Scaffold Application
if (Test-Path $projectDir) {
    Remove-Item -Path $projectDir -Recurse -Force
}
Write-Host "Creating vulnerable C#/Angular app at $projectDir..."
New-Item -Path (Split-Path $projectDir) -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
Set-Location (Split-Path $projectDir)
dotnet new angular -o "vuln_angular_app"
Set-Location $projectDir


# 3. Inject Vulnerabilities (Stored XSS and OWASP Top 10)
Write-Host "Injecting Stored XSS and vulnerable configurations..."

# Backend Controller with Stored XSS injection point
$controllerPath = "$projectDir\Controllers\CommentsController.cs"
$controllerContent = @'
using Microsoft.AspNetCore.Mvc;
using System.Collections.Generic;

namespace vuln_angular_app.Controllers;

[ApiController]
[Route("[controller]")]
public class CommentsController : ControllerBase
{
    // In-memory store to simulate database for Stored XSS
    private static List<string> _comments = new List<string> { "First comment!" };

    [HttpGet]
    public IActionResult Get()
    {
        // Vulnerable: returning unescaped raw data directly to frontend
        return Ok(_comments);
    }

    [HttpPost]
    public IActionResult Post([FromBody] string comment)
    {
        // Vulnerable: storing raw unvalidated input (Stored XSS payload)
        _comments.Add(comment);
        return Ok();
    }
}
'@
Set-Content -Path $controllerPath -Value $controllerContent

# Frontend Angular Component with XSS Execution
$appComponentHtmlPath = "$projectDir\ClientApp\src\app\app.component.html"
$appComponentHtmlContent = @'
<div style="padding: 20px;">
  <h1>Vulnerable Comment Board</h1>

  <input type="text" [(ngModel)]="newComment" placeholder="Write a comment...">
  <button (click)="submitComment()">Submit</button>

  <hr>
  <h2>Comments:</h2>
  <!-- VULNERABLE: Using innerHTML allows execution of stored XSS payload scripts -->
  <div *ngFor="let c of comments" [innerHTML]="c" style="border:1px solid #ccc; margin:5px; padding:5px;"></div>
</div>
'@
if (!(Test-Path (Split-Path $appComponentHtmlPath))) {
    New-Item -ItemType Directory -Force -Path (Split-Path $appComponentHtmlPath) | Out-Null
}
Set-Content -Path $appComponentHtmlPath -Value $appComponentHtmlContent

$appComponentTsPath = "$projectDir\ClientApp\src\app\app.component.ts"
$appComponentTsContent = @'
import { Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html'
})
export class AppComponent implements OnInit {
  newComment: string = '';
  comments: string[] = [];

  constructor(private http: HttpClient) {}

  ngOnInit() {
    this.loadComments();
  }

  loadComments() {
    this.http.get<string[]>('/comments').subscribe(res => {
      this.comments = res;
    });
  }

  submitComment() {
    // VULNERABLE: Sending raw input without sanitization
    this.http.post('/comments', `"${this.newComment}"`, {headers: {'Content-Type': 'application/json'}}).subscribe(() => {
      this.loadComments();
      this.newComment = '';
    });
  }
}
'@
Set-Content -Path $appComponentTsPath -Value $appComponentTsContent

# 4. Start Application in Background
Write-Host "Building and starting vulnerable application on http://localhost:5000..."
Set-Location $projectDir
# Run in background via Start-Process
$appProcess = Start-Process dotnet -ArgumentList "run", "--urls", "http://localhost:5000" -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 15 # Wait for app to boot up


# 5. Run OWASP ZAP API Scan
Write-Host "Starting OWASP ZAP Daemon..."
$zapBat = "$zapDir\zap.bat"
$zapPort = 8080
$zapApiKey = "testapikey123"
$zapProcess = Start-Process $zapBat -ArgumentList "-daemon -port $zapPort -config api.key=$zapApiKey" -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 20 # Wait for ZAP to boot up

$targetUrl = "http://localhost:5000"

Write-Host "Running ZAP Spider against $targetUrl..."
Invoke-RestMethod -Uri "http://localhost:$zapPort/JSON/spider/action/scan/?apikey=$zapApiKey&url=$targetUrl" | Out-Null
Start-Sleep -Seconds 10 # Give spider time

Write-Host "Running ZAP Active Scan against $targetUrl..."
Invoke-RestMethod -Uri "http://localhost:$zapPort/JSON/ascan/action/scan/?apikey=$zapApiKey&url=$targetUrl" | Out-Null

Write-Host "Waiting for scan to complete... (Mocking wait for simplicity)"
Start-Sleep -Seconds 30

Write-Host "Generating HTML Report..."
$reportPath = "$PSScriptRoot\ZAP_Vulnerability_Report.html"
$reportHtml = Invoke-RestMethod -Uri "http://localhost:$zapPort/OTHER/core/other/htmlreport/?apikey=$zapApiKey"
Set-Content -Path $reportPath -Value $reportHtml

Write-Host "Report saved to $reportPath"

# 6. Cleanup Background Processes
Write-Host "Stopping application and ZAP..."
Stop-Process -Id $appProcess.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $zapProcess.Id -Force -ErrorAction SilentlyContinue
# Also try shutting ZAP down via API gracefully
try {
    Invoke-RestMethod -Uri "http://localhost:$zapPort/JSON/core/action/shutdown/?apikey=$zapApiKey" -ErrorAction SilentlyContinue | Out-Null
} catch {}

Write-Host "DAST script execution complete. Check $reportPath for the results."
