<#
  Publishes one of Alan's Android phone apps to the public phone-apps repo, where the My Apps installer
  (and Obtainium) pick it up.

    powershell -NoProfile -ExecutionPolicy Bypass -File C:\Claudework\PhoneApps\phone-apps\publish-app.ps1 -Project C:\Claudework\MinimalLauncher -Notes "What changed"

  The project needs a phoneapp.json (id, name, short, description) and versionCode/versionName in app\build.gradle.kts.
  Bump versionCode before every publish; the script refuses to publish a versionCode that isn't higher than the last one.
#>
param(
    [Parameter(Mandatory)] [string] $Project,
    [string] $Notes = ""
)
$ErrorActionPreference = 'Stop'

$Repo        = 'isharpecomputer/phone-apps'
$RepoDir     = 'C:\Claudework\PhoneApps\phone-apps'
$JavaHome    = 'C:\Android\jdk\jdk-17.0.21+9'
$ApkSigner   = 'C:\Android\sdk\build-tools\35.0.0\apksigner.bat'
# SHA-256 of the shared phone-apps signing certificate (C:\Users\Alan\keys\phone-apps). Every app must carry it.
$ExpectedCert = '303de2c3897a92baa29c6bed3248291b4c42218185d00c0ab17307c18d2deb47'

function Fail($msg) { Write-Host "PUBLISH FAILED: $msg" -ForegroundColor Red; exit 1 }

# --- What are we publishing?
$Project = (Resolve-Path $Project).Path
$metaFile = Join-Path $Project 'phoneapp.json'
if (-not (Test-Path $metaFile)) { Fail "No phoneapp.json in $Project" }
$meta = Get-Content $metaFile -Raw -Encoding UTF8 | ConvertFrom-Json
$gradle = Get-Content (Join-Path $Project 'app\build.gradle.kts') -Raw
if ($gradle -notmatch 'versionCode\s*=\s*(\d+)') { Fail 'versionCode not found in app\build.gradle.kts' }
$versionCode = [long]$Matches[1]
if ($gradle -notmatch 'versionName\s*=\s*"([^"]+)"') { Fail 'versionName not found in app\build.gradle.kts' }
$versionName = $Matches[1]
Write-Host "Publishing $($meta.name) $versionName (versionCode $versionCode)"

# --- Up-to-date copy of the release repo and its app list
if (-not (Test-Path $RepoDir)) { git clone "https://github.com/$Repo.git" $RepoDir; if ($LASTEXITCODE) { Fail 'git clone failed' } }
git -C $RepoDir pull --quiet --ff-only; if ($LASTEXITCODE) { Fail 'git pull of phone-apps failed' }
$catalogFile = Join-Path $RepoDir 'apps.json'
$catalog = Get-Content $catalogFile -Raw -Encoding UTF8 | ConvertFrom-Json
$apps = @($catalog.apps | Where-Object { $_ })
$existing = $apps | Where-Object { $_.id -eq $meta.id }
if ($existing -and [long]$existing.versionCode -ge $versionCode) {
    Fail "$($meta.name) versionCode $versionCode is not higher than the published $($existing.versionCode). Bump versionCode (and versionName) first."
}

# --- Build the signed release APK
$env:JAVA_HOME = $JavaHome
Push-Location $Project
try {
    & .\gradlew.bat assembleRelease --console=plain -q
    if ($LASTEXITCODE) { Fail 'Gradle build failed' }
} finally { Pop-Location }
$apk = Join-Path $Project 'app\build\outputs\apk\release\app-release.apk'
if (-not (Test-Path $apk)) { Fail "Build produced no APK at $apk" }

# --- Must be signed with the shared phone-apps key, or updates would fail on the phone
$certs = & $ApkSigner verify --print-certs $apk 2>&1 | Out-String
if ($LASTEXITCODE) { Fail "apksigner verify failed:`n$certs" }
if ($certs -notmatch "SHA-256 digest:\s*$ExpectedCert") { Fail "APK is not signed with the phone-apps key:`n$certs" }

$assetName = ($meta.name -replace '[^A-Za-z0-9]+', '') + "-$versionName.apk"
$dist = Join-Path $Project 'dist'; New-Item -ItemType Directory -Force $dist | Out-Null
$out = Join-Path $dist $assetName
Copy-Item $apk $out -Force
$sha = (Get-FileHash $out -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $out).Length

# --- GitHub release with the APK attached
$tag = "$($meta.short)-v$versionName"
$body = if ($Notes) { $Notes } else { "$($meta.name) $versionName" }
$body += "`n`nSHA-256: ``$sha``"
gh release create $tag $out --repo $Repo --title "$($meta.name) $versionName" --notes $body --target main
if ($LASTEXITCODE) { Fail "gh release create $tag failed" }

# --- Update apps.json and push it
$entry = [ordered]@{
    id           = $meta.id
    name         = $meta.name
    description  = $meta.description
    versionCode  = $versionCode
    versionName  = $versionName
    apkUrl       = "https://github.com/$Repo/releases/download/$tag/$assetName"
    sha256       = $sha
    size         = $size
    releaseNotes = $Notes
    released     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}
$newApps = [object[]](@($apps | Where-Object { $_.id -ne $meta.id }) + [pscustomobject]$entry | Sort-Object name)
$newCatalog = [ordered]@{ updated = $entry.released; apps = $newApps }
$json = $newCatalog | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText($catalogFile, $json + "`n", (New-Object Text.UTF8Encoding $false))

git -C $RepoDir add apps.json
git -C $RepoDir commit --quiet -m "$($meta.name) $versionName"
git -C $RepoDir push --quiet
if ($LASTEXITCODE) { Fail 'Pushing apps.json failed (the release exists; push it by hand)' }

# --- Tag the code too, if the project is a clean git repo
if (Test-Path (Join-Path $Project '.git')) {
    if (-not (git -C $Project status --porcelain)) {
        git -C $Project tag -f "v$versionName" | Out-Null
        git -C $Project push --quiet -f origin "v$versionName" 2>$null
    } else {
        Write-Host "Note: $Project has uncommitted changes, so the code wasn't tagged." -ForegroundColor Yellow
    }
}

Write-Host "Published $($meta.name) $versionName -> https://github.com/$Repo/releases/tag/$tag" -ForegroundColor Green
