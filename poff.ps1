$env:HTTP_PROXY = ""
$env:HTTPS_PROXY = ""
$env:NO_PROXY = "localhost,127.0.0.1"
Write-Host "代理已关闭, NO_PROXY=localhost,127.0.0.1"
