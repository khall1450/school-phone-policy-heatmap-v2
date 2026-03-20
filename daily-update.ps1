## Daily Phone Policy Heatmap Update
## Runs Claude Code to check for legislative updates and push changes
## Schedule via Windows Task Scheduler

$repo = "C:\Users\khall\school-phone-policy-heatmap-v2"
Set-Location $repo

$prompt = @'
You are updating a public state school phone policy heatmap dashboard (index.html) in the current directory.

Search the web for any state school cell phone/smartphone ban legislation news from the past 48 hours.

Key states to monitor closely for imminent changes:
- Utah: SB 69 awaiting Gov. Cox signature (bell-to-bell ban)
- Delaware: SB 106 signed Mar 12, 2026 (instructional time) — DONE
- Kansas: HB 2299 awaiting Gov. Kelly signature (bell-to-bell)
- Connecticut: HB 5035 in Senate (bell-to-bell)
- Georgia: HB 1009 in Senate (9-12 extension)
- Wisconsin: AB 948 awaiting Senate floor vote (bell-to-bell expansion)
- Pennsylvania: SB 1014 in House Education Committee
- Maryland: HB 525 heading to Senate
- Massachusetts: S.2561 stalled in House
- Illinois: SB 2427 in House committee
- Minnesota: SF 508 in committee for omnibus bill
- Maine: LD 1234 monitor final passage

Also search broadly for any NEW state phone legislation or policy changes.

If you find updates:
1. Read index.html and find the relevant state entry in STATE_DATA
2. Update the affected fields: notes, additionalNotes, timeline, currentPolicy, legislation, toReview
3. If a bill was SIGNED INTO LAW, update the category field (e.g., "legislation_progress" to appropriate enacted category)
4. Update the header subtitle date to today's date
5. If a flag/accuracyNote is now resolved by the update, remove the flag (set highlighted:false, remove accuracyNote/accuracyVerdict)
6. If changes were made, commit with message "Daily policy update - [today's date]" using git config user.name "khall1450" and user.email "katherinehall1450@gmail.com", then push to origin main.

If no meaningful updates are found, do NOT edit any files or commit.

IMPORTANT: Only make changes backed by verified sources. Do not speculate or assume bills were signed without confirmation.
'@

claude --print --dangerously-skip-permissions $prompt
