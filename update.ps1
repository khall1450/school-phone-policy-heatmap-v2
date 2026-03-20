## School Phone Policy Heatmap — Weekly Update Script
## Combines LegiScan API bill tracking + Claude news search
## Run manually anytime, or schedule weekly via Task Scheduler
##
## Usage:
##   powershell -ExecutionPolicy Bypass -File update.ps1
##   powershell -ExecutionPolicy Bypass -File update.ps1 -NewsOnly
##   powershell -ExecutionPolicy Bypass -File update.ps1 -LegiscanOnly
##
## Requires:
##   - LEGISCAN_API_KEY environment variable (get free key at legiscan.com/legiscan)
##   - Claude Code CLI installed and authenticated

param(
    [switch]$NewsOnly,
    [switch]$LegiscanOnly
)

$repo = "C:\Users\khall\school-phone-policy-heatmap-v2"
Set-Location $repo

$LEGISCAN_KEY = $env:LEGISCAN_API_KEY
if (-not $LEGISCAN_KEY -and -not $NewsOnly) {
    Write-Host "ERROR: LEGISCAN_API_KEY environment variable not set." -ForegroundColor Red
    Write-Host "Get a free API key at https://legiscan.com/legiscan"
    Write-Host "Then run: `$env:LEGISCAN_API_KEY = 'your-key-here'"
    Write-Host ""
    Write-Host "Or run with -NewsOnly to skip LegiScan and only do news search."
    exit 1
}

# ── BILL WATCHLIST ──────────────────────────────────────────────────────────
# Pending legislation being tracked on the heatmap
# Format: state abbreviation, bill number (as LegiScan expects), description
$watchlist = @(
    @{ state="CT"; bill="HB5035";  desc="CT bell-to-bell ban" },
    @{ state="CT"; bill="HB5149";  desc="CT companion bell-to-bell ban" },
    @{ state="GA"; bill="HB1009";  desc="GA extend ban to HS" },
    @{ state="IL"; bill="SB2427";  desc="IL instructional-time ban" },
    @{ state="MD"; bill="HB525";   desc="MD Phone-Free Schools Act" },
    @{ state="MD"; bill="SB928";   desc="MD Senate crossfile" },
    @{ state="MA"; bill="S2561";   desc="MA bell-to-bell ban" },
    @{ state="MN"; bill="SF508";   desc="MN K-8 bell-to-bell / HS instructional" },
    @{ state="MN"; bill="HF2516";  desc="MN companion" },
    @{ state="OK"; bill="SB1719";  desc="OK make ban permanent" },
    @{ state="OK"; bill="HB3715";  desc="OK companion permanent ban" },
    @{ state="PA"; bill="SB1014";  desc="PA bell-to-bell ban" },
    @{ state="WA"; bill="SB5346";  desc="WA study directive / 2030 goal" },
    @{ state="WI"; bill="AB948";   desc="WI bell-to-bell expansion" }
)

# ── LEGISCAN CHECK ──────────────────────────────────────────────────────────
$legiscanReport = ""

if (-not $NewsOnly) {
    Write-Host "Checking LegiScan for bill status updates..." -ForegroundColor Cyan

    foreach ($bill in $watchlist) {
        $state = $bill.state
        $billNum = $bill.bill
        $desc = $bill.desc

        try {
            $url = "https://api.legiscan.com/?key=$LEGISCAN_KEY&op=getSearch&state=$state&query=$billNum"
            $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 30

            if ($response.status -eq "OK" -and $response.searchresult) {
                # Find the matching bill in search results
                $found = $false
                foreach ($key in $response.searchresult.PSObject.Properties) {
                    if ($key.Name -eq "summary") { continue }
                    $result = $key.Value
                    if ($result.bill_number -and $result.bill_number -replace "\s","" -eq $billNum) {
                        $found = $true
                        # Get full bill details
                        $billUrl = "https://api.legiscan.com/?key=$LEGISCAN_KEY&op=getBill&id=$($result.bill_id)"
                        $billData = Invoke-RestMethod -Uri $billUrl -Method Get -TimeoutSec 30

                        if ($billData.status -eq "OK") {
                            $b = $billData.bill
                            $statusMap = @{
                                1 = "Introduced"
                                2 = "Engrossed"
                                3 = "Enrolled"
                                4 = "Passed"
                                5 = "Vetoed"
                                6 = "Failed/Dead"
                            }
                            $statusText = if ($statusMap.ContainsKey([int]$b.status)) { $statusMap[[int]$b.status] } else { "Unknown ($($b.status))" }

                            # Get last 3 history entries
                            $recentHistory = ""
                            if ($b.history) {
                                $histArr = @($b.history)
                                $recent = $histArr | Select-Object -Last 3
                                foreach ($h in $recent) {
                                    $recentHistory += "`n    - $($h.date): $($h.action) [$($h.chamber)]"
                                }
                            }

                            # Get vote info if available
                            $voteInfo = ""
                            if ($b.votes) {
                                foreach ($v in @($b.votes)) {
                                    $voteInfo += "`n    - Vote: $($v.desc) (Yea:$($v.yea) Nay:$($v.nay) Passed:$(if($v.passed){'Yes'}else{'No'}))"
                                }
                            }

                            $legiscanReport += @"

--- $state $billNum ($desc) ---
  Status: $statusText (as of $($b.status_date))
  Title: $($b.title)
  Last action: $($b.history[-1].date) - $($b.history[-1].action)
  Recent history:$recentHistory$voteInfo
  LegiScan URL: $($b.url)
  State URL: $($b.state_link)

"@
                            Write-Host "  $state $billNum - $statusText ($($b.status_date))" -ForegroundColor Green
                        }
                        break
                    }
                }
                if (-not $found) {
                    $legiscanReport += "`n--- $state $billNum ($desc) ---`n  NOT FOUND in LegiScan search results`n"
                    Write-Host "  $state $billNum - NOT FOUND" -ForegroundColor Yellow
                }
            } else {
                $legiscanReport += "`n--- $state $billNum ($desc) ---`n  API ERROR: $($response.alert.message)`n"
                Write-Host "  $state $billNum - API ERROR" -ForegroundColor Red
            }
        } catch {
            $legiscanReport += "`n--- $state $billNum ($desc) ---`n  REQUEST FAILED: $($_.Exception.Message)`n"
            Write-Host "  $state $billNum - REQUEST FAILED: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Rate limit: small delay between requests
        Start-Sleep -Milliseconds 500
    }

    Write-Host ""
}

# ── BUILD CLAUDE PROMPT ─────────────────────────────────────────────────────

$today = Get-Date -Format "MMMM d, yyyy"

$prompt = @"
You are updating a public state school phone policy heatmap dashboard (index.html) in the current directory. Today is $today.

"@

if (-not $NewsOnly -and $legiscanReport) {
    $prompt += @"

## PART 1: LEGISCAN BILL STATUS DATA

The following is current bill status data from the LegiScan API for all pending legislation tracked on the heatmap. Compare each bill's status below against what is currently in the pendingLegislation entries in STATE_DATA. Update any entries where the status has changed (e.g., bill passed a chamber, signed into law, failed, etc.).

$legiscanReport

For any bill whose status has changed significantly:
1. Read index.html and find the relevant state entry in STATE_DATA
2. Update the pendingLegislation status field to reflect the new status
3. If a bill was SIGNED INTO LAW: move it from pendingLegislation to the main fields — update category, rawCategory, currentPolicy, storageReq, legislation, and notes. Remove the pendingLegislation object. To verify details, fetch the enrolled bill text from the state legislature URL provided above.
4. If a bill FAILED/DIED: move it to priorFailedBills with accurate details
5. Update the header subtitle date to today's date

"@
}

if (-not $LegiscanOnly) {
    $prompt += @"

## $(if ($NewsOnly) { "TASK" } else { "PART 2" }): NEWS SEARCH FOR NEW DEVELOPMENTS

Search the web for any state school cell phone/smartphone ban legislation or policy news from the past 7 days. Focus on:

1. NEW bills filed in any state that the heatmap doesn't currently track
2. Executive orders, Board of Education policies, or DOE guidance (these don't appear on LegiScan)
3. Governor signing/veto announcements
4. Implementation updates for enacted laws
5. Any corrections to existing heatmap data

If you find new developments:
1. Read index.html and find or create the relevant state entry in STATE_DATA
2. Update the affected fields with verified information
3. For brand new bills not on the heatmap, add them as pendingLegislation entries
4. Update the header subtitle date to today's date

"@
}

$prompt += @"

## RULES

- Only make changes backed by verified sources. Do not speculate or assume bills were signed without confirmation.
- When verifying a bill signing or major status change, fetch the enrolled bill text from the state legislature website to confirm details like storage requirements, scope, and effective dates.
- If no meaningful updates are found, do NOT edit any files.
- Do NOT commit or push — the script handles that separately.
- Be precise with dates, vote counts, and bill numbers.
"@

Write-Host "Running Claude update..." -ForegroundColor Cyan
claude --print --dangerously-skip-permissions $prompt

# ── COMMIT AND PUSH IF CHANGED ──────────────────────────────────────────────
$hasChanges = git diff --quiet index.html 2>&1; $changed = $LASTEXITCODE -ne 0

if ($changed) {
    Write-Host ""
    Write-Host "Changes detected. Committing and pushing..." -ForegroundColor Cyan
    git config user.name "khall1450"
    git config user.email "katherinehall1450@gmail.com"
    git add index.html
    $commitDate = Get-Date -Format "MMMM d, yyyy"
    git commit -m "Policy update - $commitDate"
    git push origin main
    Write-Host "Update pushed successfully." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "No changes found. Nothing to commit." -ForegroundColor Yellow
}
