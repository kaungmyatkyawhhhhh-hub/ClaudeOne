# Receives scripts exported from Studio (tools/export/Export.luau) and writes them under src/.
# localhost only. Each POST: header X-Path = path relative to src/, body = script source.
# POST /done stops the receiver.
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\src")).Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:34998/")
$listener.Start()
Write-Output "receiving into $root"
$utf8 = New-Object System.Text.UTF8Encoding($false)
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $resp = $ctx.Response
    if ($req.Url.AbsolutePath -eq "/done") {
        $resp.Close()
        break
    }
    $rel = $req.Headers["X-Path"]
    $path = [IO.Path]::GetFullPath((Join-Path $root $rel))
    if ($req.HttpMethod -eq "POST" -and $rel -and $path.StartsWith($root + "\") -and $path.EndsWith(".luau")) {
        $reader = New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
        $text = $reader.ReadToEnd().Replace("`r`n", "`n").Replace("`n", "`r`n")
        New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
        [IO.File]::WriteAllText($path, $text, $utf8)
        Write-Output "wrote $rel"
    } else {
        $resp.StatusCode = 400
    }
    $resp.Close()
}
$listener.Stop()
