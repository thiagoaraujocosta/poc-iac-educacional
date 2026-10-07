<#
.SYNOPSIS
    Equivalente em PowerShell de executar_medicao.sh (N repetições, CSV cronometrado).
.DESCRIPTION
    Fases: terraform_apply, ansible_playbook, smoke_tests, teardown_ansible, terraform_destroy.
    O Ansible não roda nativamente no Windows: por padrão os comandos são executados
    no WSL ("wsl --cd <pasta> ansible-playbook ..."). Ajuste -AnsibleCmd se preferir.
    Os scripts de deriva e replicação existem apenas em bash (rode-os no WSL).
.EXAMPLE
    .\executar_medicao.ps1 -Repeticoes 10
#>
[CmdletBinding()]
param(
    [int]$Repeticoes = 10,
    [string]$Saida = (Join-Path $PSScriptRoot 'resultados\medicao_iac.csv'),
    [switch]$SemMoodle,
    [string]$TfBin = 'terraform',
    [string]$AnsibleCmd = 'wsl',
    [int]$SmokeTimeout = 900
)
$ErrorActionPreference = 'Continue'
$raiz = Split-Path $PSScriptRoot -Parent
$tfDir = Join-Path $raiz 'terraform'
$ansibleDir = Join-Path $raiz 'ansible'
$logDir = Join-Path $PSScriptRoot 'logs'
$tmpDir = Join-Path $PSScriptRoot '.tmp'
New-Item -ItemType Directory -Force -Path $logDir, $tmpDir, (Split-Path $Saida) | Out-Null

$moodle = if ($SemMoodle) { 'false' } else { 'true' }
$tfvars = Join-Path $tmpDir 'medicao.tfvars.json'
$json = @{ escolas = @{ escola01 = @{ nome = 'Escola Modelo 01'; indice = 0; habilitar_moodle = [bool]($moodle -eq 'true') } } } | ConvertTo-Json -Depth 5
Set-Content -Path $tfvars -Value $json -Encoding ascii

if (-not (Test-Path $Saida) -or (Get-Item $Saida).Length -eq 0) {
    Set-Content -Path $Saida -Value 'run_id,fase,segundos,exit_code,timestamp' -Encoding ascii
}

function Invoke-Fase {
    param([string]$RunId, [string]$Fase, [scriptblock]$Comando)
    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $global:LASTEXITCODE = 0
    & $Comando *> (Join-Path $logDir "${RunId}_${Fase}.log")
    $rc = $LASTEXITCODE
    $sw.Stop()
    $seg = $sw.Elapsed.TotalSeconds.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture)
    Add-Content -Path $Saida -Value "$RunId,$Fase,$seg,$rc,$ts" -Encoding ascii
    Write-Host "  [$RunId] ${Fase}: ${seg}s (exit $rc)"
}

function Invoke-Ansible {
    param([string]$Playbook)
    $extra = @('-e', 'escola_prefixo=escola01', '-e', 'escola_indice=0', '-e', "escola_habilitar_moodle=$moodle")
    & $AnsibleCmd --cd $ansibleDir ansible-playbook $Playbook @extra
}

function Test-Esperar {
    param([string]$Nome, [scriptblock]$Teste)
    $limite = (Get-Date).AddSeconds($SmokeTimeout)
    while ($true) {
        $ok = $false
        try { $ok = [bool](& $Teste) } catch { $ok = $false }
        if ($ok) { Write-Output "OK     $Nome"; return $true }
        if ((Get-Date) -gt $limite) { Write-Output "FALHA  $Nome"; return $false }
        Start-Sleep -Seconds 5
    }
}

function Invoke-Smoke {
    $p = 'escola01'
    $curlOk = { param($u) $c = & curl.exe -ks -o NUL -w '%{http_code}' --max-time 10 $u; $c -match '^(2|3)\d\d$' }
    $falhas = 0
    $testes = @(
        @('proxy /healthz', { & $curlOk 'https://localhost:8443/healthz' }),
        @('cabecalho HSTS', { (& curl.exe -ksI --max-time 10 'https://localhost:8443/healthz') -match '(?i)^strict-transport-security' }),
        @('Grafana', { & $curlOk 'http://localhost:3000/api/health' }),
        @('Prometheus', { & $curlOk 'http://localhost:9090/-/healthy' }),
        @('LDAP ldapsearch', { (& docker exec "$p-ldap" sh -c '/opt/bitnami/openldap/bin/ldapsearch -x -H ldap://localhost:1389 -D "cn=admin,$LDAP_ROOT" -w "$LDAP_ADMIN_PASSWORD" -b "ou=professores,$LDAP_ROOT" -s base dn') -match '^dn: ou=professores' })
    )
    if ($moodle -eq 'true') { $testes += , @('Moodle via proxy', { & $curlOk 'https://localhost:8443/' }) }
    foreach ($t in $testes) { if (-not (Test-Esperar $t[0] $t[1])) { $falhas++ } }
    if ($falhas -gt 0) { Write-Output "Resultado: $falhas teste(s) falharam."; $global:LASTEXITCODE = 1 } else { $global:LASTEXITCODE = 0 }
}

& $TfBin "-chdir=$tfDir" init -input=false *> (Join-Path $logDir 'setup_init.log')
if ($LASTEXITCODE -ne 0) { throw "Falha no init. Veja $logDir\setup_init.log" }

for ($i = 1; $i -le $Repeticoes; $i++) {
    $run = 'run_{0:D2}' -f $i
    Write-Host "== Repeticao $i de $Repeticoes ($run)"
    Invoke-Fase $run 'terraform_apply' { & $TfBin "-chdir=$tfDir" apply -auto-approve -input=false "-var-file=$tfvars" }
    Invoke-Fase $run 'ansible_playbook' { Invoke-Ansible 'site.yml' }
    Invoke-Fase $run 'smoke_tests' { Invoke-Smoke }
    Invoke-Fase $run 'teardown_ansible' { Invoke-Ansible 'teardown.yml' }
    Invoke-Fase $run 'terraform_destroy' { & $TfBin "-chdir=$tfDir" destroy -auto-approve -input=false "-var-file=$tfvars" }
}
Write-Host "Concluido. CSV: $Saida"
