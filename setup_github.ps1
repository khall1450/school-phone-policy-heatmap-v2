# ─────────────────────────────────────────────────────────────────────────────
# GitHub Setup — Creates repo and pushes dashboard
# Run ONCE: powershell -ExecutionPolicy Bypass -File setup_github.ps1
# ─────────────────────────────────────────────────────────────────────────────

$githubUsername = "khall1450"
$repoName       = "school-phone-policy-heatmap"
$repoDesc       = "Interactive heatmap dashboard of US state cell phone policies in schools"

Write-Host ""
Write-Host "GitHub Repository Setup" -ForegroundColor Cyan
Write-Host "──────────────────────────────────────────" -ForegroundColor Cyan

# ── Get GitHub Personal Access Token ──────────────────────────────────────────
Write-Host ""
Write-Host "You need a GitHub Personal Access Token (classic) with 'repo' scope." -ForegroundColor Yellow
Write-Host "Create one at: https://github.com/settings/tokens/new" -ForegroundColor Yellow
Write-Host "  ✓ Check: repo (Full control of private repositories)" -ForegroundColor Gray
Write-Host ""
$token = Read-Host "Paste your GitHub token here (input is hidden)" -AsSecureString
$tokenPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($token)
)

$headers = @{
  Authorization = "token $tokenPlain"
  Accept        = "application/vnd.github.v3+json"
  "User-Agent"  = "PowerShell-Setup"
}

# ── Create GitHub Repo ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Creating GitHub repository '$repoName'..." -ForegroundColor Cyan

$body = @{
  name        = $repoName
  description = $repoDesc
  private     = $false
  auto_init   = $false
} | ConvertTo-Json

try {
  $result = Invoke-RestMethod -Uri "https://api.github.com/user/repos" `
    -Method Post -Headers $headers -Body $body -ContentType "application/json"
  Write-Host "  ✓ Repository created: $($result.html_url)" -ForegroundColor Green
  $repoUrl = $result.clone_url
} catch {
  $status = $_.Exception.Response.StatusCode.Value__
  if ($status -eq 422) {
    Write-Host "  ! Repository already exists — using existing repo." -ForegroundColor Yellow
    $repoUrl = "https://github.com/$githubUsername/$repoName.git"
  } else {
    Write-Host "  ✗ Failed to create repo: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }
}

# ── Initialize Git and Push ───────────────────────────────────────────────────
$projectDir = $PSScriptRoot
Set-Location $projectDir

Write-Host ""
Write-Host "Initializing git repository..." -ForegroundColor Cyan

git init
git config user.email "khall1450@users.noreply.github.com"
git config user.name "$githubUsername"

# Write .gitignore
@"
*.ps1.bak
Thumbs.db
.DS_Store
"@ | Set-Content ".gitignore"

git add index.html .gitignore
git commit -m "Initial commit: State phone policy heatmap dashboard

Interactive D3.js heatmap of all 50 US states' cell phone policies in schools.
Data as of March 2026. Includes accuracy review for flagged states and data quality analysis."

# Set remote (use token in URL for auth)
$remoteUrl = "https://${githubUsername}:${tokenPlain}@github.com/$githubUsername/$repoName.git"
git remote remove origin 2>$null
git remote add origin $remoteUrl

git branch -M main
git push -u origin main

Write-Host ""
Write-Host "  ✓ Dashboard pushed to GitHub!" -ForegroundColor Green
Write-Host "  → Repository: https://github.com/$githubUsername/$repoName" -ForegroundColor Cyan
Write-Host ""
Write-Host "  To enable GitHub Pages (free hosting):" -ForegroundColor Yellow
Write-Host "  1. Go to https://github.com/$githubUsername/$repoName/settings/pages" -ForegroundColor Gray
Write-Host "  2. Under 'Source', select 'main' branch, '/ (root)', Save" -ForegroundColor Gray
Write-Host "  3. Your dashboard will be live at:" -ForegroundColor Gray
Write-Host "     https://$githubUsername.github.io/$repoName/" -ForegroundColor Green
Write-Host ""
