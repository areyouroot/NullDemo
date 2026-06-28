$ErrorActionPreference = "Stop"

$projectDir = "test project"
$reportPath = "VulnerabilityReport.xlsx"

if (!(Test-Path $projectDir)) {
    Write-Error "The 'test project' folder does not exist."
}

# Ensure ImportExcel module is installed
if (!(Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Host "Installing ImportExcel module..."
    Install-Module -Name ImportExcel -Force -Scope CurrentUser
}

# Find package.json directory for npm audit
$packageJsonDir = $projectDir
$packageJsonFile = Get-ChildItem -Path $projectDir -Filter "package.json" -Recurse | Select-Object -First 1
if ($packageJsonFile) {
    $packageJsonDir = $packageJsonFile.Directory.FullName
}

Write-Host "Running npm audit in $packageJsonDir..."
Set-Location $packageJsonDir
$npmAuditJson = npm audit --json | ConvertFrom-Json
Set-Location -Path $PSScriptRoot

Write-Host "Running Snyk scan on the project..."

# Proper capture using Start-Process to avoid throwing errors on non-zero exit codes when vulnerabilities are found.
$snykProcess = Start-Process -FilePath "snyk" -ArgumentList "test `"$projectDir`" --json" -RedirectStandardOutput "$env:TEMP\snyk_out.json" -Wait -NoNewWindow -PassThru
$snykJson = Get-Content "$env:TEMP\snyk_out.json" -Raw | ConvertFrom-Json

$reportData = @()

# Process npm audit results
if ($npmAuditJson.vulnerabilities) {
    foreach ($vulnName in $npmAuditJson.vulnerabilities.PSObject.Properties.Name) {
        $vuln = $npmAuditJson.vulnerabilities.$vulnName
        $reportData += [PSCustomObject]@{
            Tool = "npm audit"
            Package = $vuln.name
            Severity = $vuln.severity
            Vulnerability = $vuln.via -join ", "
            FixAvailable = $vuln.fixAvailable
        }
    }
}

# Process Snyk results
if ($snykJson -is [array]) {
    foreach ($projectScan in $snykJson) {
        if ($projectScan.vulnerabilities) {
            foreach ($vuln in $projectScan.vulnerabilities) {
                $reportData += [PSCustomObject]@{
                    Tool = "Snyk"
                    Package = $vuln.packageName
                    Severity = $vuln.severity
                    Vulnerability = $vuln.title
                    FixAvailable = $vuln.isUpgradable
                }
            }
        }
    }
} elseif ($snykJson.vulnerabilities) {
    foreach ($vuln in $snykJson.vulnerabilities) {
        $reportData += [PSCustomObject]@{
            Tool = "Snyk"
            Package = $vuln.packageName
            Severity = $vuln.severity
            Vulnerability = $vuln.title
            FixAvailable = $vuln.isUpgradable
        }
    }
}

if ($reportData.Count -gt 0) {
    Write-Host "Found $($reportData.Count) vulnerabilities. Generating report..."

    if (Test-Path $reportPath) {
        Write-Host "Overwriting existing report: $reportPath"
        Remove-Item $reportPath -Force
    }

    $reportData | Export-Excel -Path $reportPath -AutoSize -AutoFilter -BoldTopRow
    Write-Host "Report saved to $reportPath"
} else {
    Write-Host "No vulnerabilities found. No report generated."
}
