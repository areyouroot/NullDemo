$ErrorActionPreference = "Stop"

$projectDir = "test project"

if (Test-Path $projectDir) {
    Write-Host "Deleting existing '$projectDir' folder..."
    Remove-Item -Path $projectDir -Recurse -Force
}

Write-Host "Creating new Angular/C# application in '$projectDir'..."
dotnet new angular -o "$projectDir"

Write-Host "Modifying template to add simple calculator UI and logic..."

# Update C# Controller
$controllerPath = "$projectDir\Controllers\CalculatorController.cs"
$controllerContent = @"
using Microsoft.AspNetCore.Mvc;

namespace test_project.Controllers;

[ApiController]
[Route("[controller]")]
public class CalculatorController : ControllerBase
{
    [HttpGet("add")]
    public IActionResult Add(int a, int b)
    {
        return Ok(new { result = a + b });
    }

    [HttpGet("subtract")]
    public IActionResult Subtract(int a, int b)
    {
        return Ok(new { result = a - b });
    }
}
"@
Set-Content -Path $controllerPath -Value $controllerContent

# Update Angular component
$appComponentHtmlPath = "$projectDir\ClientApp\src\app\app.component.html"
$appComponentHtmlContent = @"
<div style=""padding: 20px;"">
  <h1>Simple Calculator</h1>

  <input type=""number"" [(ngModel)]=""num1"" placeholder=""Number 1"">
  <input type=""number"" [(ngModel)]=""num2"" placeholder=""Number 2"">

  <button (click)=""calculate('add')"">Add</button>
  <button (click)=""calculate('subtract')"">Subtract</button>

  <h2 *ngIf=""result !== null"">Result: {{ result }}</h2>
</div>
"@
# Note: In newer templates ClientApp is just 'ClientApp/src' or 'src' depending on the template version.
# Assuming standard .NET 6/7/8 angular template where it's in ClientApp/src/app/
# We'll create the file, but in a real environment it might be in different path.
if (!(Test-Path (Split-Path $appComponentHtmlPath))) {
    New-Item -ItemType Directory -Force -Path (Split-Path $appComponentHtmlPath) | Out-Null
}
Set-Content -Path $appComponentHtmlPath -Value $appComponentHtmlContent


$appComponentTsPath = "$projectDir\ClientApp\src\app\app.component.ts"
$appComponentTsContent = @'
import { Component } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html'
})
export class AppComponent {
  num1: number = 0;
  num2: number = 0;
  result: number | null = null;

  constructor(private http: HttpClient) {}

  calculate(operation: string) {
    this.http.get<any>(`/calculator/${operation}?a=${this.num1}&b=${this.num2}`).subscribe(res => {
      this.result = res.result;
    });
  }
}
'@
if (!(Test-Path (Split-Path $appComponentTsPath))) {
    New-Item -ItemType Directory -Force -Path (Split-Path $appComponentTsPath) | Out-Null
}
Set-Content -Path $appComponentTsPath -Value $appComponentTsContent

Write-Host "Pilot project created successfully."
