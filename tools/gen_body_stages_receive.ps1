# Receives the files tools/gen_body_stages.luau sends from Studio (localhost only, port 34996):
#   POST /obj?f=<name>.obj&mode=w|a  -> Downloads\other_player_stages\<name>.obj (w = new file, a = append)
#   POST /config                     -> src\ReplicatedStorage\Shared\Config\BodyStages.luau
#   GET  /done                       -> stop
$out = Join-Path $env:USERPROFILE "Downloads\other_player_stages"
$config = (Resolve-Path (Join-Path $PSScriptRoot "..\src\ReplicatedStorage\Shared\Config")).Path
New-Item -ItemType Directory -Force $out | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:34996/")
$listener.Start()
Write-Output "receiving into $out"
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $resp = $ctx.Response
    try {
        $path = $req.Url.AbsolutePath
        if ($path -eq "/done") { $resp.Close(); break }
        $reader = New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
        $text = $reader.ReadToEnd()
        if ($path -eq "/obj") {
            $name = $req.QueryString["f"] -replace "[^A-Za-z0-9_.-]", ""
            if (-not $name.EndsWith(".obj")) { throw "not an .obj name" }
            $file = Join-Path $out $name
            if ($req.QueryString["mode"] -eq "w") { [IO.File]::WriteAllText($file, $text, $utf8) } else { [IO.File]::AppendAllText($file, $text, $utf8) }
        } elseif ($path -eq "/config") {
            [IO.File]::WriteAllText((Join-Path $config "BodyStages.luau"), $text.Replace("`r`n", "`n").Replace("`n", "`r`n"), $utf8)
            Write-Output "wrote Config/BodyStages.luau"
        } else {
            $resp.StatusCode = 400
        }
    } catch { $resp.StatusCode = 500 }
    $resp.Close()
}
