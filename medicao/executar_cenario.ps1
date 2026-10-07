<#
.SYNOPSIS
    Equivalente em PowerShell de executar_cenario.sh (R repetições de um cenário do dataset real).
.DESCRIPTION
    Por repetição: apply, configuração (Ansible via WSL), testes de fumaça, idempotência (plan
    -detailed-exitcode e segundo apply), consistência (hash do estado normalizado) e limpeza.
    Grava três CSV (tempos, idempotência, consistência) com as mesmas colunas da versão bash.
    Requer Python (utils_cenario.py), Docker, Terraform/OpenTofu (-TfBin tofu) e WSL com Ansible.
    No perfil leve o Ansible roda apenas o papel do proxy (tag "proxy").
    NÃO foi executado nesta máquina (sem Docker/Terraform); apenas o analisador de sintaxe foi usado.
.EXAMPLE
    .\executar_cenario.ps1 -Cenario ..\cenarios\leve_n05.tfvars.json -Repeticoes 10
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Cenario,
    [int]$Repeticoes = 10,
    [string]$SaidaDir = (Join-Path $PSScriptRoot 'resultados'),
    [string]$TfBin = 'terraform',
    [string]$Python = 'python',
    [string]$AnsibleCmd = 'wsl',
    [int]$SmokeTimeout = 900
)
$ErrorActionPreference = 'Continue'
$raiz = Split-Path $PSScriptRoot -Parent
$tfDir = Join-Path $raiz 'terraform'
$ansibleDir = Join-Path $raiz 'ansible'
$logDir = Join-Path $PSScriptRoot 'logs'
$tmpDir = Join-Path $PSScriptRoot '.tmp'
$util = Join-Path $PSScriptRoot 'utils_cenario.py'
New-Item -ItemType Directory -Force -Path $logDir, $tmpDir, $SaidaDir | Out-Null
$tfvars = (Resolve-Path $Cenario).Path
$inv = [System.Globalization.CultureInfo]::InvariantCulture

$resumo = (& $Python $util resumo $tfvars).Trim() -split ' '
$nome = $resumo[0]; $porte = $resumo[1]; $n = $resumo[2]
$escolas = @(& $Python $util escolas $tfvars | ForEach-Object {
        $p = $_.Trim() -split ' '
        [pscustomobject]@{ Prefixo = $p[0]; Indice = [int]$p[1]; Perfil = $p[2]; Moodle = ($p[3] -eq '1') }
    })
$perfil = $escolas[0].Perfil
$tags = if ($perfil -eq 'leve') { @('--tags', 'proxy') } else { @() }

$tempos = Join-Path $SaidaDir "${nome}_tempos.csv"
$idem = Join-Path $SaidaDir "${nome}_idempotencia.csv"
$cons = Join-Path $SaidaDir "${nome}_consistencia.csv"
function Initialize-Csv($caminho, $cabecalho) {
    if (-not (Test-Path $caminho) -or (Get-Item $caminho).Length -eq 0) { Set-Content -Path $caminho -Value $cabecalho -Encoding ascii }
}
Initialize-Csv $tempos 'run_id,cenario,porte,n,fase,segundos,exit_code,falhas_teste,timestamp'
Initialize-Csv $idem 'run_id,cenario,porte,n,plan_exit_code,recursos_a_alterar,apply2_adicionados,apply2_alterados,apply2_destruidos'
Initialize-Csv $cons 'run_id,cenario,porte,n,hash_estado_tf,hash_docker'

function Invoke-Fase {
    param([string]$RunId, [string]$Fase, [scriptblock]$Comando)
    $log = Join-Path $logDir "${nome}_${RunId}_${Fase}.log"
    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $global:LASTEXITCODE = 0
    & $Comando *> $log
    $rc = $LASTEXITCODE
    $sw.Stop()
    $seg = $sw.Elapsed.TotalSeconds.ToString('0.000', $inv)
    $falhas = ''
    if ($Fase -eq 'smoke_tests') { $falhas = @(Select-String -Path $log -Pattern '^FALHA').Count }
    Add-Content -Path $tempos -Value "$RunId,$nome,$porte,$n,$Fase,$seg,$rc,$falhas,$ts" -Encoding ascii
    Write-Host "  [$RunId] ${Fase}: ${seg}s (exit $rc)"
    return $rc
}

function Invoke-AnsibleEscola {
    param([string]$Playbook, $Escola)
    $moodle = if ($Escola.Moodle) { 'true' } else { 'false' }
    $extra = @('-e', "escola_prefixo=$($Escola.Prefixo)", '-e', "escola_indice=$($Escola.Indice)", '-e', "escola_habilitar_moodle=$moodle")
    & $AnsibleCmd --cd $ansibleDir ansible-playbook $Playbook @extra @tags
    if ($LASTEXITCODE -ne 0) { $script:falhaLote = $true }
}
function Invoke-EmTodas([string]$Playbook) {
    $script:falhaLote = $false
    foreach ($e in $escolas) { Invoke-AnsibleEscola $Playbook $e }
    $global:LASTEXITCODE = [int]$script:falhaLote
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
function Invoke-SmokeTodas {
    $falhas = 0
    foreach ($e in $escolas) {
        $p = $e.Prefixo; $https = 8443 + $e.Indice; $graf = 3000 + $e.Indice; $prom = 9090 + $e.Indice
        Write-Output "Smoke tests da escola $p (perfil $($e.Perfil))"
        $http = { param($u) $c = & curl.exe -ks -o NUL -w '%{http_code}' --max-time 10 $u; $c -match '^(2|3)\d\d$' }
        $t = @(
            @('proxy /healthz', { & $http "https://localhost:$https/healthz" }.GetNewClosure()),
            @('cabecalho HSTS', { (& curl.exe -ksI --max-time 10 "https://localhost:$https/healthz") -match '(?i)^strict-transport-security' }.GetNewClosure())
        )
        if ($e.Perfil -eq 'leve') {
            $t += , @('MariaDB saudavel', { (& docker inspect -f '{{.State.Health.Status}}' "$p-mariadb") -eq 'healthy' }.GetNewClosure())
        } else {
            if ($e.Moodle) { $t += , @('Moodle via proxy', { & $http "https://localhost:$https/" }.GetNewClosure()) }
            $t += , @('Grafana', { & $http "http://localhost:$graf/api/health" }.GetNewClosure())
            $t += , @('Prometheus', { & $http "http://localhost:$prom/-/healthy" }.GetNewClosure())
            $t += , @('LDAP ldapsearch', { (& docker exec "$p-ldap" sh -c '/opt/bitnami/openldap/bin/ldapsearch -x -H ldap://localhost:1389 -D "cn=admin,$LDAP_ROOT" -w "$LDAP_ADMIN_PASSWORD" -b "ou=professores,$LDAP_ROOT" -s base dn') -match '^dn: ou=professores' }.GetNewClosure())
        }
        foreach ($x in $t) { if (-not (Test-Esperar $x[0] $x[1])) { $falhas++ } }
    }
    if ($falhas -gt 0) { Write-Output "Resultado: $falhas teste(s) falharam."; $global:LASTEXITCODE = 1 } else { $global:LASTEXITCODE = 0 }
}

$planoBin = Join-Path $tmpDir "$nome.plan"
$planoJson = Join-Path $tmpDir "${nome}_plano.json"
$script:planRc = ''
function Invoke-PlanIdem {
    & $TfBin "-chdir=$tfDir" plan -detailed-exitcode -input=false "-var-file=$tfvars" "-out=$planoBin"
    $script:planRc = $LASTEXITCODE
    if ($script:planRc -eq 0 -or $script:planRc -eq 2) {
        & $TfBin "-chdir=$tfDir" show -json $planoBin | Set-Content -Path $planoJson -Encoding utf8
        $global:LASTEXITCODE = 0
    } else { $global:LASTEXITCODE = $script:planRc }
}

function Get-JsonDocker([string]$tipo, [string]$arquivo) {
    $lista = switch ($tipo) {
        'container' { & docker ps -a --format '{{.Names}}' }
        'network' { & docker network ls --format '{{.Name}}' }
        'volume' { & docker volume ls --format '{{.Name}}' }
    }
    $nomes = @($lista | Where-Object { $_ -match '^escola\d+-' })
    if ($nomes.Count -eq 0) { Set-Content -Path $arquivo -Value '[]' -Encoding ascii; return }
    & docker $tipo inspect @nomes 2> $null | Set-Content -Path $arquivo -Encoding utf8
}
function Save-Hashes([string]$RunId) {
    $est = Join-Path $tmpDir "${nome}_estado.json"
    & $TfBin "-chdir=$tfDir" show -json 2> $null | Set-Content -Path $est -Encoding utf8
    $c = Join-Path $tmpDir "${nome}_cont.json"; $r = Join-Path $tmpDir "${nome}_redes.json"; $v = Join-Path $tmpDir "${nome}_vols.json"
    Get-JsonDocker 'container' $c; Get-JsonDocker 'network' $r; Get-JsonDocker 'volume' $v
    $hTf = (& $Python $util hash-tf $est).Trim()
    $hDk = (& $Python $util hash-docker $c $r $v).Trim()
    Add-Content -Path $cons -Value "$RunId,$nome,$porte,$n,$hTf,$hDk" -Encoding ascii
    Write-Host "  [$RunId] hash estado TF: $($hTf.Substring(0,12))  hash docker: $($hDk.Substring(0,12))"
}
function Save-Idempotencia([string]$RunId) {
    $alterar = ''; $add = ''; $alt = ''; $des = ''
    if ((Test-Path $planoJson) -and ($script:planRc -eq 0 -or $script:planRc -eq 2)) { $alterar = (& $Python $util contar-mudancas $planoJson).Trim() }
    $logApply2 = Join-Path $logDir "${nome}_${RunId}_terraform_apply_idempotencia.log"
    if (Test-Path $logApply2) {
        $m = Select-String -Path $logApply2 -Pattern 'Resources: (\d+) added, (\d+) changed, (\d+) destroyed' | Select-Object -Last 1
        if ($m) { $add = $m.Matches[0].Groups[1].Value; $alt = $m.Matches[0].Groups[2].Value; $des = $m.Matches[0].Groups[3].Value }
    }
    Add-Content -Path $idem -Value "$RunId,$nome,$porte,$n,$($script:planRc),$alterar,$add,$alt,$des" -Encoding ascii
    Write-Host "  [$RunId] plan -detailed-exitcode: $($script:planRc); recursos a alterar: $alterar; segundo apply: +$add ~$alt -$des"
}

Write-Host "Cenario $nome (porte $porte, N=$n, perfil $perfil), $Repeticoes repeticoes"
& $TfBin "-chdir=$tfDir" init -input=false *> (Join-Path $logDir 'setup_init.log')
if ($LASTEXITCODE -ne 0) { throw "Falha no init. Veja $logDir\setup_init.log" }

for ($i = 1; $i -le $Repeticoes; $i++) {
    $run = 'run_{0:D2}' -f $i
    Write-Host "== Repeticao $i de $Repeticoes ($run)"
    Remove-Item -Force -ErrorAction SilentlyContinue $planoJson, $planoBin
    $script:planRc = ''
    $rcApply = Invoke-Fase $run 'terraform_apply' { & $TfBin "-chdir=$tfDir" apply -auto-approve -input=false "-var-file=$tfvars" }
    if ($rcApply -eq 0) {
        Invoke-Fase $run 'ansible_playbook' { Invoke-EmTodas 'site.yml' } | Out-Null
        Invoke-Fase $run 'smoke_tests' { Invoke-SmokeTodas } | Out-Null
        Invoke-Fase $run 'terraform_plan_idempotencia' { Invoke-PlanIdem } | Out-Null
        Invoke-Fase $run 'terraform_apply_idempotencia' { & $TfBin "-chdir=$tfDir" apply -auto-approve -input=false "-var-file=$tfvars" } | Out-Null
        Save-Idempotencia $run
        Save-Hashes $run
    } else {
        Write-Host '  apply falhou: configuracao, testes, idempotencia e consistencia nao executados nesta repeticao.'
    }
    Invoke-Fase $run 'teardown_ansible' { Invoke-EmTodas 'teardown.yml' } | Out-Null
    Invoke-Fase $run 'terraform_destroy' { & $TfBin "-chdir=$tfDir" destroy -auto-approve -input=false "-var-file=$tfvars" } | Out-Null
}
Write-Host "Concluido. CSV: $tempos, $idem, $cons"
