# ─────────────────────────────────────────────────────────────────────────────
# Local HTTP Server — School Phone Policy Heatmap
# Run: powershell -ExecutionPolicy Bypass -File server.ps1
# ─────────────────────────────────────────────────────────────────────────────
$port = 8080
$root = $PSScriptRoot

$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

Write-Host ""
Write-Host "  ┌──────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "  │  School Phone Policy Heatmap — Local Server Running  │" -ForegroundColor Cyan
Write-Host "  │                                                        │" -ForegroundColor Cyan
Write-Host "  │  Open in browser: http://localhost:$port/              │" -ForegroundColor Green
Write-Host "  │  Press Ctrl+C to stop                                 │" -ForegroundColor Yellow
Write-Host "  └──────────────────────────────────────────────────────┘" -ForegroundColor Cyan
Write-Host ""

# Auto-open browser
Start-Process "http://localhost:$port/"

$mimeTypes = @{
  '.html' = 'text/html; charset=utf-8'
  '.css'  = 'text/css'
  '.js'   = 'application/javascript'
  '.json' = 'application/json'
  '.png'  = 'image/png'
  '.ico'  = 'image/x-icon'
}

while ($listener.IsListening) {
  try {
    $context  = $listener.GetContext()
    $request  = $context.Request
    $response = $context.Response

    $urlPath = $request.Url.LocalPath
    if ($urlPath -eq '/' -or $urlPath -eq '') { $urlPath = '/index.html' }

    $filePath = Join-Path $root $urlPath.TrimStart('/')
    $filePath = [System.IO.Path]::GetFullPath($filePath)

    # Security: ensure file is inside root
    if (-not $filePath.StartsWith($root)) {
      $response.StatusCode = 403
      $response.Close()
      continue
    }

    if (Test-Path $filePath -PathType Leaf) {
      $ext  = [System.IO.Path]::GetExtension($filePath).ToLower()
      $mime = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { 'application/octet-stream' }
      $content = [System.IO.File]::ReadAllBytes($filePath)
      $response.ContentType = $mime
      $response.ContentLength64 = $content.Length
      $response.StatusCode = 200
      $response.OutputStream.Write($content, 0, $content.Length)
      Write-Host "  200  $urlPath" -ForegroundColor Gray
    } else {
      $response.StatusCode = 404
      $bytes = [System.Text.Encoding]::UTF8.GetBytes("<h1>404 Not Found</h1>")
      $response.ContentType = 'text/html'
      $response.ContentLength64 = $bytes.Length
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
      Write-Host "  404  $urlPath" -ForegroundColor Red
    }

    $response.Close()
  } catch [System.Net.HttpListenerException] {
    break
  } catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    try { $context.Response.StatusCode = 500; $context.Response.Close() } catch {}
  }
}

$listener.Stop()
Write-Host "`n  Server stopped." -ForegroundColor Yellow
