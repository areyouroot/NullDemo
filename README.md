# DevSecOps Playground (NullDemo)

Welcome to the DevSecOps Playground! This repository is designed to help you provision a local environment, scaffold vulnerable C#/Angular applications, execute security scans, and learn how to implement automated remediations for modern software supply chain attacks.

## Prerequisites

This repository contains scripts intended to be executed on a **Windows** environment with:
- **PowerShell 5.1+** or **PowerShell Core (pwsh)**.
- **.NET SDK** (6, 7, or 8) installed globally to use the `dotnet` CLI commands.
- Administrator privileges may be required for some MSI installers (e.g., Node.js).

## Repository Structure

The repository is split into four primary pillars of application security testing:

- `SCA/` (Software Composition Analysis) - Supply chain and dependency scanning.
- `SAST/` (Static Application Security Testing) - Source code analysis (SonarQube).
- `DAST/` (Dynamic Application Security Testing) - Runtime analysis (OWASP ZAP).
- `AIST/` (Artificial Intelligence Security Testing) - (Placeholder for future AI testing scripts).

## Getting Started

### 1. Global Setup
First, prepare your machine by installing the necessary baseline tools (Node.js, SonarQube, Sonar CLI, OWASP ZAP, etc.).
```powershell
.\setup.ps1
```

### 2. SCA (Software Composition Analysis)
The SCA directory simulates a supply chain attack and its remediation. Run the scripts in the following order:

1. **Scaffold the App:**
   ```powershell
   .\SCA\Create pilot.ps1
   ```
   *Creates a simple C#/Angular calculator app in a "test project" folder.*

2. **Inject Vulnerabilities:**
   ```powershell
   .\SCA\mr robot.ps1
   ```
   *Injects vulnerable versions of `Newtonsoft.Json`, `lodash`, and `request` into the project.*

3. **Scan and Report:**
   ```powershell
   .\SCA\scan.ps1
   ```
   *Runs `npm audit` and `snyk test`, then generates a `VulnerabilityReport.xlsx` Excel report.*

4. **Remediate:**
   ```powershell
   .\SCA\remediate.ps1
   ```
   *Updates the packages to safe versions and automatically injects enterprise security controls (`nuget.config`, `Directory.Build.props`, `.npmrc`, and dependabot config).*

### 3. SAST (Static Application Security Testing)
The SAST directory focuses on finding vulnerabilities in your source code using SonarQube.

1. **Setup and Scaffold:**
   ```powershell
   .\SAST\setup_and_app.ps1
   ```
   *Interactively installs Java 17 and SonarQube, creates a vulnerable e-commerce application (containing SQL injections and bad practices), starts the SonarQube server in the background, and launches the interactive scanning console.*

2. **Interactive Scan (Launched Automatically):**
   *The previous script automatically opens `interactive_scan.ps1` in a new window. It will open `http://localhost:9000` in your browser.*
   * Log into SonarQube (default: admin/admin).
   * Create a local project and generate a token.
   * Provide the Project Key, Project Name, and Token back to the PowerShell console to trigger the local scan.

### 4. DAST (Dynamic Application Security Testing)
The DAST directory demonstrates running active payload scans against a running application using OWASP ZAP.

1. **Run the Automated DAST Pipeline:**
   ```powershell
   .\DAST\dast_scan.ps1
   ```
   *This script handles everything automatically:*
   * *Installs OWASP ZAP.*
   * *Scaffolds a vulnerable Angular/C# application with a Stored XSS vulnerability.*
   * *Starts the application in the background (port 5000).*
   * *Starts the ZAP Daemon in the background (port 8080).*
   * *Uses the ZAP REST API to run a Spider and Active Scan against the running app.*
   * *Generates a `ZAP_Vulnerability_Report.html` report.*
   * *Cleans up and shuts down the background processes.*

---
**Disclaimer:** This is a playground environment intended strictly for educational and local testing purposes. The scripts download external binaries and manipulate local files. Review the code before executing it.
