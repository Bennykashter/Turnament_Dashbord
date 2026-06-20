# Upload dashboard files to Supabase and attempt CSV import
# Paths and project
$PROJECT = "yfnzuwxjuolofhitjpzx"
$bucket = "public-site"
$html = "G:\\My Drive\\Hema\\Turnament Dashbored\\Ministry_of_the_Fence_Dashboard_v2.html"
$csv  = "G:\\My Drive\\Hema\\Turnament Dashbored\\HEMA_Europe_Planner.csv"

# Prompt for Service Role key (secure)
$srkSecure = Read-Host -Prompt "Paste Service Role key (it will not be stored in chat)" -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($srkSecure)
$SERVICE_ROLE_KEY = [Runtime.InteropServices.Marshal]::PtrToStringAuto($ptr).Trim()

# Use the system curl executable to avoid PowerShell aliasing of 'curl'
$curlExe = "C:\\Windows\\System32\\curl.exe"

# Create public bucket
$body = '{"name":"' + $bucket + '","public":true}'
Write-Host "Creating bucket '$bucket'..."
try {
  $createResp = & $curlExe -s -X POST "https://$PROJECT.supabase.co/storage/v1/bucket" `
    -H "Authorization: Bearer $SERVICE_ROLE_KEY" `
    -H "apikey: $SERVICE_ROLE_KEY" `
    -H "Content-Type: application/json" `
    -d $body
  Write-Host $createResp
} catch {
  Write-Host "Bucket creation request failed: $($_.Exception.Message)"
}

# Upload HTML
if (Test-Path $html) {
  Write-Host "Uploading HTML..."
  try {
    $uploadHtml = & $curlExe -s -X POST "https://$PROJECT.supabase.co/storage/v1/object/$bucket/Ministry_of_the_Fence_Dashboard_v2.html" `
      -H "Authorization: Bearer $SERVICE_ROLE_KEY" `
      -H "apikey: $SERVICE_ROLE_KEY" `
      -F "file=@\"$html\""
    Write-Host $uploadHtml
    $htmlUrl = "https://$PROJECT.supabase.co/storage/v1/object/public/$bucket/Ministry_of_the_Fence_Dashboard_v2.html"
    Write-Host "HTML public URL: $htmlUrl"
  } catch {
    Write-Host "HTML upload failed: $($_.Exception.Message)"
  }
} else { Write-Host "HTML file not found at $html" }

# Upload CSV
if (Test-Path $csv) {
  Write-Host "Uploading CSV..."
  try {
    $uploadCsv = & $curlExe -s -X POST "https://$PROJECT.supabase.co/storage/v1/object/$bucket/HEMA_Europe_Planner.csv" `
      -H "Authorization: Bearer $SERVICE_ROLE_KEY" `
      -H "apikey: $SERVICE_ROLE_KEY" `
      -F "file=@\"$csv\""
    Write-Host $uploadCsv
    $csvUrl = "https://$PROJECT.supabase.co/storage/v1/object/public/$bucket/HEMA_Europe_Planner.csv"
    Write-Host "CSV public URL: $csvUrl"
  } catch {
    Write-Host "CSV upload failed: $($_.Exception.Message)"
  }
} else { Write-Host "CSV file not found at $csv" }

# Attempt to import CSV rows into REST table hema_planner (table must exist)
try {
  Write-Host "Reading CSV and attempting REST insert into table 'hema_planner'..."
  $rows = Import-Csv -Path $csv
  if ($rows.Count -gt 0) {
    Write-Host "Sanitizing CSV rows (removing control characters, trimming values, normalizing headers)..."
    $cleanRows = @()
    foreach ($r in $rows) {
      $obj = @{}
      foreach ($header in $r.PSObject.Properties.Name) {
        $val = $r.$header
        if ($null -ne $val) {
          $clean = ($val -replace '[\x00-\x1F]','').Trim()
        } else {
          $clean = $null
        }
        $safeHeader = $header -replace '[^a-zA-Z0-9_]','_' -replace '__+','_' -replace '^_|_$',''
        $obj[$safeHeader] = $clean
      }
      $cleanRows += [PSCustomObject]$obj
    }

    # Check if table exists by attempting a small select
    $tableExists = $false
    try {
      $check = Invoke-RestMethod -Method Get -Uri "https://$PROJECT.supabase.co/rest/v1/hema_planner?select=1&limit=1" `
        -Headers @{ Authorization = "Bearer $SERVICE_ROLE_KEY"; apikey = $SERVICE_ROLE_KEY } -ErrorAction Stop
      $tableExists = $true
    } catch {
      $tableExists = $false
    }

    if (-not $tableExists) {
      Write-Host "Table 'hema_planner' not found or no read access via REST."
      Write-Host "Automated table creation via REST is not supported from this script."
      Write-Host "Options: 1) Create table via Supabase SQL editor or psql, 2) Import CSV via Supabase Dashboard -> Table Editor -> Import CSV."
    } else {
      Write-Host "Table exists — attempting REST insert of sanitized rows..."
      $json = $cleanRows | ConvertTo-Json -Depth 10
      $resp = Invoke-RestMethod -Method Post -Uri "https://$PROJECT.supabase.co/rest/v1/hema_planner" `
        -Headers @{ Authorization = "Bearer $SERVICE_ROLE_KEY"; apikey = $SERVICE_ROLE_KEY; "Content-Type" = "application/json"; Prefer = "return=representation" } `
        -Body $json -ErrorAction Stop
      if ($resp -is [System.Array]) { Write-Host "REST insert succeeded. Inserted rows: $($resp.Count)" } else { Write-Host "REST insert succeeded." }
    }
  } else { Write-Host "CSV seems empty." }
} catch {
  Write-Host "REST insert failed: $($_.Exception.Message)"
  Write-Host "If the table does not exist or RLS prevents inserts, import via Supabase Dashboard -> Table Editor -> Import CSV."
}

Write-Host "Done. Rotate the Service Role key in Supabase immediately if it was exposed."
