# Sonda privada front -> API. Nao comprova a invocacao API -> agente.
# Processo exclusivo da sonda; nao altera o transporte nativo geral.
function Initialize-S26ProcessoToken {
    if ('Solar.S26.ProcessoToken' -as [type]) { return }
    Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using Microsoft.Win32.SafeHandles;

namespace Solar.S26 {
    public static class ProcessoToken {
        [StructLayout(LayoutKind.Sequential)]
        struct Security { public int Length; public IntPtr Descriptor; public int Inherit; }
        [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
        struct Startup {
            public int Size; public string Reserved, Desktop, Title;
            public uint X,Y,XSize,YSize,XCount,YCount,Fill,Flags;
            public ushort Show, ReservedSize; public IntPtr ReservedBytes, Input, Output, Error;
        }
        [StructLayout(LayoutKind.Sequential)]
        struct StartupEx { public Startup Startup; public IntPtr Attributes; }
        [StructLayout(LayoutKind.Sequential)]
        struct ProcessInfo { public IntPtr Process, Thread; public uint Id, ThreadId; }
        [StructLayout(LayoutKind.Sequential)]
        struct BasicLimit {
            public long ProcessTime, JobTime; public uint Flags;
            public UIntPtr MinWorking, MaxWorking; public uint ActiveLimit;
            public UIntPtr Affinity; public uint Priority, Scheduling;
        }
        [StructLayout(LayoutKind.Sequential)]
        struct IoCounters { public ulong ReadOps,WriteOps,OtherOps,ReadBytes,WriteBytes,OtherBytes; }
        [StructLayout(LayoutKind.Sequential)]
        struct ExtendedLimit {
            public BasicLimit Basic; public IoCounters Io;
            public UIntPtr ProcessMemory,JobMemory,PeakProcessMemory,PeakJobMemory;
        }
        [StructLayout(LayoutKind.Sequential)]
        struct Accounting {
            public long User,Kernel,PeriodUser,PeriodKernel;
            public uint PageFaults,Total,Active,Terminated;
        }
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern IntPtr CreateJobObject(IntPtr attributes, string name);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool SetInformationJobObject(IntPtr job,int info,ref ExtendedLimit value,int size);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool QueryInformationJobObject(IntPtr job,int info,IntPtr value,int size,IntPtr length);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool TerminateJobObject(IntPtr job,uint exit);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool CreatePipe(out IntPtr read,out IntPtr write,ref Security attributes,int size);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool SetHandleInformation(IntPtr handle,uint mask,uint flags);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern IntPtr CreateFile(string name,uint access,uint share,ref Security attributes,uint creation,uint flags,IntPtr template);
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        static extern bool CreateProcess(string app,StringBuilder command,IntPtr processAttributes,IntPtr threadAttributes,
            bool inherit,uint flags,IntPtr environment,string directory,ref StartupEx startup,out ProcessInfo process);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool InitializeProcThreadAttributeList(IntPtr list,int count,uint flags,ref IntPtr size);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool UpdateProcThreadAttribute(IntPtr list,uint flags,UIntPtr attribute,IntPtr value,
            IntPtr size,IntPtr previous,IntPtr returned);
        [DllImport("kernel32.dll")]
        static extern void DeleteProcThreadAttributeList(IntPtr list);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern uint ResumeThread(IntPtr thread);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern uint WaitForSingleObject(IntPtr handle,uint milliseconds);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool GetExitCodeProcess(IntPtr process,out uint code);
        [DllImport("kernel32.dll", SetLastError=true)]
        static extern bool TerminateProcess(IntPtr process,uint exit);
        [DllImport("kernel32.dll")]
        static extern bool CloseHandle(IntPtr handle);

        static void Check(bool ok) { if (!ok) throw new InvalidOperationException("Processo de sonda recusado."); }
        static void Close(ref IntPtr handle) {
            if (handle != IntPtr.Zero && handle != new IntPtr(-1)) CloseHandle(handle);
            handle=IntPtr.Zero;
        }
        static string Quote(string value) {
            if (value == null || value.IndexOf('\0') >= 0) throw new InvalidOperationException("Argumento invalido.");
            var result = new StringBuilder("\"");
            int slashes=0;
            foreach (char c in value) {
                if (c=='\\') { slashes++; continue; }
                result.Append('\\', c=='"' ? slashes*2+1 : slashes);
                result.Append(c); slashes=0;
            }
            result.Append('\\',slashes*2); result.Append('"');
            return result.ToString();
        }
        static bool UnsafeCmd(string value) {
            return value == null || value.IndexOfAny(new char[]{'%','!','&','|','<','>','^','"','\r','\n','\0'}) >= 0;
        }
        static int Remaining(Stopwatch clock,int limit) {
            return Math.Max(0, limit-(int)Math.Min(int.MaxValue,clock.ElapsedMilliseconds));
        }
        static uint Active(IntPtr job) {
            int size=Marshal.SizeOf(typeof(Accounting));
            IntPtr data=Marshal.AllocHGlobal(size);
            try {
                Check(QueryInformationJobObject(job,1,data,size,IntPtr.Zero));
                return ((Accounting)Marshal.PtrToStructure(data,typeof(Accounting))).Active;
            } finally { Marshal.FreeHGlobal(data); }
        }
        static int[] Ids(IntPtr job) {
            // Buffer limitado; job sem nome e sem permissoes de breakaway.
            int size=65536;
            IntPtr data=Marshal.AllocHGlobal(size);
            try {
                Check(QueryInformationJobObject(job,3,data,size,IntPtr.Zero));
                int count=Marshal.ReadInt32(data,4);
                Check(count>=0 && count <= (size-8)/IntPtr.Size);
                int[] ids=new int[count];
                for(int i=0;i<count;i++) {
                    long id = IntPtr.Size==8 ? Marshal.ReadInt64(data,8+i*8) : (long)(uint)Marshal.ReadInt32(data,8+i*4);
                    ids[i]=checked((int)id);
                }
                return ids;
            } finally { Marshal.FreeHGlobal(data); }
        }
        static void Notify(Action<int[]> observer,int[] ids) {
            if(observer!=null) { try { observer(ids); } catch { } }
        }
        public static string Run(string program,string[] args,int milliseconds,Action<int[]> observer) {
            if(milliseconds<4 || !Path.IsPathRooted(program) || program.StartsWith("\\\\") ||
                program.StartsWith("//") || !File.Exists(program))
                throw new InvalidOperationException("Processo de sonda recusado.");
            string application=Path.GetFullPath(program);
            bool cmd=String.Equals(Path.GetExtension(application),".cmd",StringComparison.OrdinalIgnoreCase) ||
                String.Equals(Path.GetExtension(application),".bat",StringComparison.OrdinalIgnoreCase);
            var command=new StringBuilder();
            if(cmd) {
                if(UnsafeCmd(application)) throw new InvalidOperationException("Launcher recusado.");
                foreach(string arg in args) if(UnsafeCmd(arg)) throw new InvalidOperationException("Argumento de launcher recusado.");
                string launcher=Quote(application);
                foreach(string arg in args) launcher+=" "+Quote(arg);
                application=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),"cmd.exe");
                command.Append(Quote(application)).Append(" /d /s /v:off /c \"").Append(launcher).Append('"');
            } else {
                command.Append(Quote(application));
                foreach(string arg in args) command.Append(' ').Append(Quote(arg));
            }
            var clock=Stopwatch.StartNew();
            // Reserva incluida no orcamento para encerrar e conferir toda a arvore.
            int reserve=Math.Min(1000,Math.Max(1,milliseconds/4));
            int work=milliseconds-reserve;
            IntPtr job=IntPtr.Zero,read=IntPtr.Zero,write=IntPtr.Zero,nul=IntPtr.Zero;
            IntPtr attributes=IntPtr.Zero,allowedHandles=IntPtr.Zero;
            bool attributesReady=false;
            ProcessInfo process=new ProcessInfo();
            FileStream stream=null;
            Task<byte[]> reader=null;
            bool assigned=false,good=false,clean=false;
            string stdout=null;
            try {
                job=CreateJobObject(IntPtr.Zero,null);
                Check(job!=IntPtr.Zero);
                var limits=new ExtendedLimit();
                limits.Basic.Flags=0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
                Check(SetInformationJobObject(job,9,ref limits,Marshal.SizeOf(typeof(ExtendedLimit))));
                var sa=new Security(); sa.Length=Marshal.SizeOf(typeof(Security)); sa.Inherit=1;
                Check(CreatePipe(out read,out write,ref sa,0));
                Check(SetHandleInformation(read,1,0));
                nul=CreateFile("NUL",0xC0000000,3,ref sa,3,0,IntPtr.Zero);
                Check(nul!=new IntPtr(-1));
                // Heranca fechada: somente stdout e NUL, nunca handles de outros processos.
                IntPtr attributeBytes=IntPtr.Zero;
                InitializeProcThreadAttributeList(IntPtr.Zero,1,0,ref attributeBytes);
                Check(attributeBytes.ToInt64()>0 && attributeBytes.ToInt64()<=65536);
                attributes=Marshal.AllocHGlobal(attributeBytes);
                Check(InitializeProcThreadAttributeList(attributes,1,0,ref attributeBytes));
                attributesReady=true;
                allowedHandles=Marshal.AllocHGlobal(IntPtr.Size*2);
                Marshal.WriteIntPtr(allowedHandles,0,write);
                Marshal.WriteIntPtr(allowedHandles,IntPtr.Size,nul);
                Check(UpdateProcThreadAttribute(attributes,0,new UIntPtr(0x20002),allowedHandles,
                    new IntPtr(IntPtr.Size*2),IntPtr.Zero,IntPtr.Zero));
                var start=new StartupEx();
                start.Startup.Size=Marshal.SizeOf(typeof(StartupEx)); start.Startup.Flags=0x100;
                start.Startup.Input=nul; start.Startup.Output=write; start.Startup.Error=nul;
                start.Attributes=attributes;
                Check(Remaining(clock,work)>0);
                Check(CreateProcess(application,command,IntPtr.Zero,IntPtr.Zero,true,
                    0x08080004,IntPtr.Zero,null,ref start,out process)); // extended + suspended + no window
                Check(AssignProcessToJobObject(job,process.Process)); assigned=true;
                Notify(observer,new int[]{checked((int)process.Id)});
                Close(ref write); Close(ref nul);
                stream=new FileStream(new SafeFileHandle(read,true),FileAccess.Read,4096,false);
                read=IntPtr.Zero;
                FileStream captured=stream;
                reader=Task.Run(delegate {
                    using(var bytes=new MemoryStream()) {
                        byte[] chunk=new byte[4096];
                        int n;
                        while((n=captured.Read(chunk,0,chunk.Length))>0) {
                            if(bytes.Length+n>32768) throw new InvalidOperationException("Stdout excede limite.");
                            bytes.Write(chunk,0,n);
                        }
                        return bytes.ToArray();
                    }
                });
                Check(ResumeThread(process.Thread)!=0xFFFFFFFF);
                int left=Remaining(clock,work);
                Check(left>0 && WaitForSingleObject(process.Process,(uint)left)==0);
                uint exit; Check(GetExitCodeProcess(process.Process,out exit) && exit==0);
                left=Remaining(clock,work);
                Check(left>0 && reader.Wait(left));
                stdout=new UTF8Encoding(false,true).GetString(reader.Result).Trim();
                good=true;
            } catch {
                good=false;
            } finally {
                if(assigned) {
                    try { Notify(observer,Ids(job)); } catch { }
                    bool terminated=TerminateJobObject(job,1);
                    try {
                        while(Active(job)>0 && Remaining(clock,milliseconds)>0)
                            System.Threading.Thread.Sleep(Math.Min(5,Remaining(clock,milliseconds)));
                        clean=terminated && Active(job)==0;
                        Notify(observer,Ids(job));
                    } catch { clean=false; }
                } else if(process.Process!=IntPtr.Zero) {
                    TerminateProcess(process.Process,1); // suspenso: ainda nao pode ter filhos
                    clean=WaitForSingleObject(process.Process,(uint)Remaining(clock,milliseconds))==0;
                } else { clean=true; }
                Close(ref job); // tambem mata descendentes se a verificacao falhar
                if(attributesReady) DeleteProcThreadAttributeList(attributes);
                if(attributes!=IntPtr.Zero) Marshal.FreeHGlobal(attributes);
                if(allowedHandles!=IntPtr.Zero) Marshal.FreeHGlobal(allowedHandles);
                Close(ref process.Thread); Close(ref process.Process);
                Close(ref write); Close(ref nul); Close(ref read);
                if(stream!=null) stream.Dispose();
                if(reader!=null && reader.IsFaulted) { var ignored=reader.Exception; }
            }
            if(!good || !clean || Remaining(clock,milliseconds)==0)
                throw new InvalidOperationException("Obtencao de token SondaIam falhou; detalhes externos suprimidos.");
            return stdout;
        }
    }
}
'@
}

function Invoke-S26TokenSonda {
    param([string]$Programa, [string[]]$Argumentos, [double]$TimeoutSegundos,
        [datetime]$LimiteUtc, [Action[int[]]]$Observador)
    try {
        $inicio = [datetime]::UtcNow
        if ($LimiteUtc.Kind -ne [DateTimeKind]::Utc -or $TimeoutSegundos -le 0 -or
            [double]::IsNaN($TimeoutSegundos) -or [double]::IsInfinity($TimeoutSegundos)) { throw 'Prazo invalido.' }
        $prazo = $inicio.AddSeconds([Math]::Min($TimeoutSegundos, ($LimiteUtc - $inicio).TotalSeconds))
        Initialize-S26ProcessoToken
        $ms = [Math]::Floor(($prazo - [datetime]::UtcNow).TotalMilliseconds)
        if ($ms -lt 4 -or $ms -gt [int]::MaxValue) { throw 'Prazo esgotado.' }
        $stdout = [Solar.S26.ProcessoToken]::Run($Programa,$Argumentos,[int]$ms,$Observador)
        if ([string]::IsNullOrWhiteSpace($stdout)) { throw 'Token ausente.' }
        return $stdout
    } catch {
        throw 'Obtencao de token SondaIam falhou; detalhes externos suprimidos.'
    }
}

function Invoke-S26SondaIamNativa($Acao) {
    $token = $null; $cliente = $null; $requisicao = $null
    $resposta = $null; $stream = $null; $cancelamento = $null
    try {
        $origem = ConvertTo-S26OrigemHttps $Acao.OrigemFront
        if ($origem -cne $Acao.OrigemFront -or $Acao.Uri -cne ($origem + '/api/sessao')) {
            throw 'Destino invalido.'
        }
        $ctx = New-S26Contexto
        if ([datetime]::UtcNow -ge $Acao.LimiteUtc) { throw 'Prazo esgotado.' }
        # Token do operador autenticado; sem impersonacao, audience ou token no argv.
        $prazoSondaUtc = [datetime]::UtcNow.AddSeconds($Acao.TimeoutSegundos)
        if ($prazoSondaUtc -gt $Acao.LimiteUtc) { $prazoSondaUtc = $Acao.LimiteUtc }
        $token = Invoke-S26TokenSonda -Programa $ctx.Gcloud -Argumentos @(
            'auth','print-identity-token',('--project=' + $ctx.Projeto),'--quiet') `
            -TimeoutSegundos $Acao.TimeoutSegundos -LimiteUtc $prazoSondaUtc
        if ([string]::IsNullOrWhiteSpace($token)) { throw 'Token ausente.' }
        $timeout = [Math]::Min($Acao.TimeoutSegundos, ($prazoSondaUtc - [datetime]::UtcNow).TotalSeconds)
        if ($timeout -le 0) { throw 'Prazo esgotado.' }
        Add-Type -AssemblyName System.Net.Http
        $handler = New-Object Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect = $false
        $handler.UseCookies = $false
        $cliente = New-Object Net.Http.HttpClient($handler)
        $cancelamento = New-Object Threading.CancellationTokenSource
        $cancelamento.CancelAfter([TimeSpan]::FromSeconds($timeout))
        $cliente.Timeout = [TimeSpan]::FromSeconds($timeout)
        $requisicao = New-Object Net.Http.HttpRequestMessage
        $requisicao.Method = [Net.Http.HttpMethod]::Get
        $requisicao.RequestUri = [Uri]$Acao.Uri
        $requisicao.Headers.Authorization = New-Object Net.Http.Headers.AuthenticationHeaderValue('Bearer', $token)
        $resposta = $cliente.SendAsync($requisicao, [Net.Http.HttpCompletionOption]::ResponseHeadersRead,
            $cancelamento.Token).GetAwaiter().GetResult()
        $codigo = [int]$resposta.StatusCode
        $corpo = ''
        # Apenas o 401 esperado precisa de corpo; nenhum corpo externo e registrado.
        if ($codigo -eq 401) {
            $stream = $resposta.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            $bytes = New-Object byte[] 8193
            $total = 0
            do {
                $lidos = $stream.ReadAsync($bytes, $total, ($bytes.Length - $total),
                    $cancelamento.Token).GetAwaiter().GetResult()
                $total += $lidos
                if ($total -gt 8192) { throw 'Corpo excede limite.' }
            } while ($lidos -gt 0)
            $utf8 = New-Object Text.UTF8Encoding($false, $true)
            $corpo = $utf8.GetString($bytes, 0, $total)
        }
        return [pscustomobject]@{ StatusCode=$codigo; Corpo=$corpo }
    } finally {
        if ($stream) { $stream.Dispose() }
        if ($resposta) { $resposta.Dispose() }
        if ($requisicao) { $requisicao.Dispose() }
        if ($cliente) { $cliente.Dispose() }
        if ($cancelamento) { $cancelamento.Dispose() }
        $token = $null
    }
}

function Wait-S26IamFrontApi {
    param([string]$OrigemFront, [datetime]$BindingAgenteUtc, [scriptblock]$Executor,
        [scriptblock]$Relogio = { [datetime]::UtcNow },
        [scriptblock]$Dormir = { param([double]$Segundos) Start-Sleep -Milliseconds ([int][Math]::Ceiling($Segundos * 1000)) })
    try {
        $origem = ConvertTo-S26OrigemHttps $OrigemFront
        if ($origem -cne $OrigemFront) { throw 'Origem nao canonica.' }
        $inicio = & $Relogio
        if ($inicio -isnot [datetime] -or $inicio.Kind -ne [DateTimeKind]::Utc -or
            $BindingAgenteUtc.Kind -ne [DateTimeKind]::Utc -or $BindingAgenteUtc -gt $inicio) {
            throw 'Relogio ou binding invalido.'
        }
        $limite = $inicio.AddMinutes(10)
        $anterior = $inicio
        $confirmado = $false
        for ($tentativa = 1; $tentativa -le 10; $tentativa++) {
            $agora = & $Relogio
            if ($agora -lt $anterior -or $agora.AddSeconds(60) -gt $limite) { throw 'Prazo excedido.' }
            & $Dormir 60 | Out-Null
            $agora = & $Relogio
            if ($agora -lt $anterior.AddSeconds(60) -or $agora -gt $limite) { throw 'Espera ou prazo invalido.' }
            $anterior = $agora
            $acao = [ordered]@{ Id='sonda-iam-front-api'; Tipo='SondaIam'; Metodo='GET'
                OrigemFront=$origem; Uri=($origem + '/api/sessao')
                LimiteUtc=$limite
                TimeoutSegundos=[Math]::Max(0.001, [Math]::Min(20, ($limite - $agora).TotalSeconds)) }
            $resposta = Invoke-S26Transporte $acao $Executor
            $agora = & $Relogio
            if ($agora -lt $anterior -or $agora -gt $limite) { throw 'Prazo excedido.' }
            $anterior = $agora
            if ($resposta.StatusCode -eq 401) {
                if ($resposta.Corpo -isnot [string] -or [Text.Encoding]::UTF8.GetByteCount($resposta.Corpo) -gt 8192 -or
                    $resposta.Corpo -notmatch '\A\s*\{') { throw 'Corpo invalido.' }
                # ConvertFrom-Json aceita extensoes diferentes entre PS7 e 5.1.
                # Recusar comentarios/virgula final e codigo ambiguo nos dois shells.
                $stringJson = '"(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"'
                $semStrings = [regex]::Replace($resposta.Corpo, $stringJson, '""')
                if ($semStrings -match '/|,\s*[}\]]' -or
                    [regex]::Matches($resposta.Corpo, '"codigo"\s*:').Count -ne 1) { throw 'JSON ambiguo/invalido.' }
                $json = $resposta.Corpo | ConvertFrom-Json -ErrorAction Stop
                if ($null -eq $json -or $json.codigo -isnot [string] -or $json.codigo -cne 'sessao_invalida') {
                    throw 'Resposta nao comprova front/API.'
                }
                $confirmado = $true
                break
            }
            if ($resposta.StatusCode -notin @(403,502)) { throw 'Status inesperado.' }
        }
        if (-not $confirmado) { throw 'Sonda esgotada.' }
        # Somente estabilizacao temporal do binding. Prova do agente segue pendente.
        $restante = ($BindingAgenteUtc.AddMinutes(5) - $agora).TotalSeconds
        if ($restante -gt 0) {
            & $Dormir $restante | Out-Null
            $fim = & $Relogio
            if ($fim -lt $BindingAgenteUtc.AddMinutes(5) -or $fim -lt $agora) { throw 'Espera incompleta.' }
        }
    } catch {
        throw 'Espera IAM S-26 interrompida; detalhes externos suprimidos. Agente permanece sem prova.'
    }
}
