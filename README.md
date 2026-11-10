(() => {
    if (document.getElementById('painel-senhas-sabin')) return;
    async function iniciarPainel(unidadeSelecionada) {
    const STORAGE_KEY = 'psb_historico_global';

    const TIPOS_LABEL = { R:'Resultado', E:'Exames', P:'Pendência', A:'Agendamento', D:'Digital', V:'Vacina' };
    const PRIOR_LABEL = { A:'80+ Alta', P:'Preferencial', G:'Geral' };
    const TIPOS = ['R','E','P','A','D','V'];
    const PRIORS = ['A','P','G'];
    const COR   = { A:'#e74c3c', P:'#e67e22', G:'#95a5a6' };
    const FUNDO = { A:'#2c0a0a', P:'#2c1a0a', G:'#1a1a1a' };
    const ICONE = { A:'🔴', P:'🟠', G:'⚪' };

    const TEMPOS_PADRAO = {};
    TIPOS.forEach(t => { TEMPOS_PADRAO[t+'A']=5; TEMPOS_PADRAO[t+'P']=10; TEMPOS_PADRAO[t+'G']=15; });

    
const SUPABASE_URL = 'https://wujxwgargixuadyhgnck.supabase.co';
const SUPABASE_KEY = 'sb_publishable_rkZ5MaE5lhotdn1pzVECmQ_9VCY2PpF';

async function consultarSupabase(caminho, opcoes = {}) {
    const resposta = await fetch(SUPABASE_URL + '/rest/v1/' + caminho, {
        ...opcoes,
        headers: {
            apikey: SUPABASE_KEY,
            'Content-Type': 'application/json',
            ...(opcoes.headers || {})
        }
    });

    if (!resposta.ok) {
        throw new Error('Erro ao conectar ao Supabase: ' + resposta.status);
    }

    return resposta.json();
}


    function carregarTempos() {
        try { const s=localStorage.getItem('psb_tempos_' + unidadeSelecionada); return s?{...TEMPOS_PADRAO,...JSON.parse(s)}:{...TEMPOS_PADRAO}; } catch { return {...TEMPOS_PADRAO}; } 
    }
function salvarTempos(t) {
    try {
        localStorage.setItem('psb_tempos_' + unidadeSelecionada, JSON.stringify(t));
    } catch {}
}

let TEMPOS = carregarTempos();
let ID_UNIDADE = null;
let carregandoTempos = false;

async function buscarUnidade() {
    const unidades = await consultarSupabase(
        'units?select=id,name&active=eq.true'
    );

    const unidade = unidades.find(
        u => u.name === unidadeSelecionada
    );

    if (!unidade) {
        throw new Error('Unidade não encontrada no Supabase.');
    }

    ID_UNIDADE = unidade.id;
}
async function carregarTemposSupabase() {
    await buscarUnidade();

    const dados = await consultarSupabase(
        'unit_settings?select=tempos&unit_id=eq.' + ID_UNIDADE
    );

    if (!dados.length) {
        throw new Error('Tempos não encontrados para esta unidade.');
    }

    TEMPOS = { ...TEMPOS_PADRAO, ...dados[0].tempos };
    salvarTempos(TEMPOS);
}
 
  try {
      await carregarTemposSupabase();
  } catch (erro) {
      alert('Não foi possível carregar os tempos da unidade: ' + erro.message);
      throw erro;
  }

  function dataHoje() {
        const d=new Date();
        return [String(d.getDate()).padStart(2,'0'),String(d.getMonth()+1).padStart(2,'0'),d.getFullYear()].join('/');
    }

    function carregarHistorico() {
        try { return JSON.parse(localStorage.getItem(STORAGE_KEY)||'[]'); } catch { return []; }
    }
    function salvarHistorico(h) {
        try { localStorage.setItem(STORAGE_KEY,JSON.stringify(h.slice(-1000))); } catch {}
    }

    function detectarGuiche() {
        const txt = document.body.innerText||'';
        const m = txt.match(/Guiche\s*(\d+)/i)||txt.match(/Guich[êe]\s*#?\s*(\d+)/i);
        return m ? 'Guiche '+m[1] : 'Guiche ?';
    }

    function fmt(seg) {
        seg=Math.max(0,Math.floor(seg));
        const h=Math.floor(seg/3600),m=Math.floor((seg%3600)/60),s=seg%60;
        return [h,m,s].map(n=>String(n).padStart(2,'0')).join(':');
    }

    function verificarSenha(callback) {
        const modal=document.createElement('div');
        modal.style.cssText='position:fixed;inset:0;background:rgba(0,0,0,.85);z-index:2147483648;display:flex;align-items:center;justify-content:center;font-family:Segoe UI,Arial,sans-serif;';
        modal.innerHTML=`<div style="background:#1e1e1e;border:2px solid #2d7dff;border-radius:12px;padding:24px;width:280px;text-align:center;">
            <div style="font-size:24px;margin-bottom:8px;">🔐</div>
            <div style="font-weight:700;color:#fff;margin-bottom:16px;">Senha de acesso</div>
            <input id="psb-si" type="password" placeholder="Digite a senha..." style="width:100%;padding:10px;border-radius:8px;border:1px solid #444;background:#2a2a2a;color:#fff;font-size:16px;text-align:center;box-sizing:border-box;margin-bottom:12px;">
            <div style="display:flex;gap:8px;">
                <button id="psb-sc" style="flex:1;padding:10px;background:#444;color:#fff;border:none;border-radius:8px;cursor:pointer;">Cancelar</button>
                <button id="psb-so" style="flex:1;padding:10px;background:#2d7dff;color:#fff;border:none;border-radius:8px;cursor:pointer;font-weight:700;">Entrar</button>
            </div>
            <div id="psb-se" style="color:#e74c3c;font-size:12px;margin-top:8px;display:none;">Senha incorreta!</div>
        </div>`;
        document.body.appendChild(modal);
        const inp=modal.querySelector('#psb-si'); inp.focus();
        modal.querySelector('#psb-sc').onclick=()=>modal.remove();
        const tentar=()=>{
            if(inp.value){modal.remove();callback();}
            else{modal.querySelector('#psb-se').style.display='block';inp.value='';inp.focus();}
        };
        modal.querySelector('#psb-so').onclick=tentar;
        inp.addEventListener('keydown',e=>{if(e.key==='Enter')tentar();});
    }

    const painel=document.createElement('div');
    painel.id='painel-senhas-sabin';
    painel.style.cssText='position:fixed;top:10px;right:10px;width:370px;background:#0f172a;color:#f8fafc;border-radius:16px;box-shadow:0 16px 48px rgba(2,6,23,.65);z-index:2147483647;font-family:Segoe UI,Arial,sans-serif;border:1px solid #334155;overflow:hidden;';
    painel.innerHTML=`
        <div id="psb-header" style="background:linear-gradient(115deg,#0f172a,#1e40af);padding:14px 15px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid #333;">
            <span style="font-weight:700;font-size:13px;">⠿ SABIN · <span id="psb-guiche" style="color:#2d7dff;font-size:12px;">--</span></span>
            <div style="display:flex;gap:5px;" onclick="event.stopPropagation()">
                <button id="psb-btn-config" title="Configurações" style="background:#333;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;font-size:13px;">⚙️</button>
                <button id="psb-btn-relatorio" title="Relatório" style="background:#333;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;font-size:13px;">📊</button>
                <button id="psb-atualizar" title="Atualizar" style="background:#2d7dff;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;font-size:13px;">↻</button>
                <button id="psb-minimizar" title="Minimizar" style="background:#555;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;font-size:13px;">−</button>
                <button onclick="document.getElementById('painel-senhas-sabin').remove()" style="background:#444;border:none;color:#fff;border-radius:6px;padding:3px 7px;cursor:pointer;font-size:13px;">✕</button>
            </div>
        </div>
        <div id="psb-corpo" style="background:#0f172a">
            <div style="padding:8px 10px;background:#161616;border-bottom:1px solid #2a2a2a;display:flex;gap:6px;">
                <div style="flex:1;text-align:center;background:#2c0a0a;border:1px solid #e74c3c;border-radius:8px;padding:5px;">
                    <div style="font-size:18px;font-weight:700;color:#e74c3c;" id="psb-num-A">0</div>
                    <div style="font-size:9px;color:#e74c3c;">🔴 80+</div>
                </div>
                <div style="flex:1;text-align:center;background:#2c1a0a;border:1px solid #e67e22;border-radius:8px;padding:5px;">
                    <div style="font-size:18px;font-weight:700;color:#e67e22;" id="psb-num-P">0</div>
                    <div style="font-size:9px;color:#e67e22;">🟠 PREFER.</div>
                </div>
                <div style="flex:1;text-align:center;background:#1a1a1a;border:1px solid #555;border-radius:8px;padding:5px;">
                    <div style="font-size:18px;font-weight:700;color:#aaa;" id="psb-num-G">0</div>
                    <div style="font-size:9px;color:#aaa;">⚪ GERAL</div>
                </div>
            </div>
            <div id="psb-recomendada" style="display:none;padding:12px;background:#052e25;border-bottom:1px solid #166534;">
                <div style="font-size:9px;color:#2ecc71;font-weight:700;margin-bottom:3px;">✅ PRÓXIMA RECOMENDADA</div>
                <div id="psb-recom-corpo"></div>
            </div>
            <div id="psb-lista" style="max-height:380px;overflow-y:auto;padding:9px;"></div>
            <div style="padding:5px;text-align:center;font-size:9px;color:#444;border-top:1px solid #1a1a1a;">
                Leitura: <span id="psb-hora">--</span>
            </div>
        </div>`;
    document.body.appendChild(painel);

    const style=document.createElement('style');
    style.innerHTML=`@keyframes psb-pisca{0%,100%{opacity:1}50%{opacity:.4}} #psb-lista::-webkit-scrollbar{width:5px} #psb-lista::-webkit-scrollbar-thumb{background:#475569;border-radius:6px} #painel-senhas-sabin button{transition:background .15s,transform .15s;border-radius:8px!important} #painel-senhas-sabin button:hover{filter:brightness(1.2)} #psb-lista>div{border-radius:10px!important;margin-bottom:5px} #psb-recomendada{box-shadow:inset 3px 0 #22c55e}`;
    document.head.appendChild(style);

    let minimizado=false;
    document.getElementById('psb-minimizar').onclick=()=>{
        minimizado=!minimizado;
        document.getElementById('psb-corpo').style.display=minimizado?'none':'block';
        document.getElementById('psb-minimizar').innerText=minimizado?'+':'−';
    };
    // Arraste pelo cabecalho para mover o painel; posicao salva neste navegador.
    const cabecalhoPainel=document.getElementById('psb-header');
    const chavePosicao='psb_posicao_painel';
    const limitarPosicao=(x,y)=>({
        x:Math.max(0,Math.min(x,Math.max(0,window.innerWidth-painel.offsetWidth))),
        y:Math.max(0,Math.min(y,Math.max(0,window.innerHeight-45)))
    });
    const posicionarPainel=(x,y)=>{
        const p=limitarPosicao(x,y);
        painel.style.left=p.x+'px';
        painel.style.top=p.y+'px';
        painel.style.right='auto';
    };
    try {
        const pos=JSON.parse(localStorage.getItem(chavePosicao)||'null');
        if(pos&&Number.isFinite(pos.x)&&Number.isFinite(pos.y))posicionarPainel(pos.x,pos.y);
    } catch {}
    cabecalhoPainel.style.cursor='grab';
    cabecalhoPainel.style.userSelect='none';
    cabecalhoPainel.style.touchAction='none';
    let arrastoPainel=null;
    // Eventos globais de mouse funcionam mesmo quando o cursor sai do cabecalho.
    cabecalhoPainel.addEventListener('mousedown',e=>{
        if(e.button!==0||e.target.closest('button,a,input,select'))return;
        const rect=painel.getBoundingClientRect();
        arrastoPainel={dx:e.clientX-rect.left,dy:e.clientY-rect.top};
        cabecalhoPainel.style.cursor='grabbing';
        e.preventDefault();
        e.stopPropagation();
    });
    document.addEventListener('mousemove',e=>{
        if(!arrastoPainel||!painel.isConnected)return;
        posicionarPainel(e.clientX-arrastoPainel.dx,e.clientY-arrastoPainel.dy);
    },true);
    const finalizarArrasto=()=>{
        if(!arrastoPainel)return;
        arrastoPainel=null;
        cabecalhoPainel.style.cursor='grab';
        const rect=painel.getBoundingClientRect();
        try{localStorage.setItem(chavePosicao,JSON.stringify({x:rect.left,y:rect.top}));}catch{}
    };
    document.addEventListener('mouseup',finalizarArrasto,true);
    window.addEventListener('blur',finalizarArrasto);
    // Suporte a toque sem interferir nos botoes.
    cabecalhoPainel.addEventListener('touchstart',e=>{
        if(e.target.closest('button,a,input,select'))return;
        const toque=e.touches[0],rect=painel.getBoundingClientRect();
        arrastoPainel={dx:toque.clientX-rect.left,dy:toque.clientY-rect.top};
    },{passive:true});
    document.addEventListener('touchmove',e=>{
        if(!arrastoPainel||!painel.isConnected)return;
        const toque=e.touches[0];
        posicionarPainel(toque.clientX-arrastoPainel.dx,toque.clientY-arrastoPainel.dy);
        e.preventDefault();
    },{passive:false});
    document.addEventListener('touchend',finalizarArrasto);
    window.addEventListener('resize',()=>{
        if(!painel.isConnected)return;
        const rect=painel.getBoundingClientRect();
        posicionarPainel(rect.left,rect.top);
    });

    let baseDados=[], ultimaRecomendada=null, recomendadaSnapshot=null, ultimaSenhaAtendimento=null;
    let snapshotTravado=false;
    let chamadaPendente=null;
    const chamadasRecentes=new Map();
    let guicheAtual=detectarGuiche();
    document.getElementById('psb-guiche').innerText=guicheAtual;

    // Auditoria observacional V2: somente piloto em Guiche 2 / Shopping Felicittá.
    // Nenhum resultado daqui deve ser usado para avaliacao funcional sem validacao.
    let ultimaLeituraEm=0;
    const pilotoAtivo=()=>!!ID_UNIDADE && /^Guiche [1-9][0-9]{0,2}$/.test(guicheAtual);
    let erroPilotoAvisado=false;
    function senhasAtivasNaTela(){
        const codigos=new Set();
        Array.from(document.querySelectorAll('div')).forEach(el=>{
            if(el.closest('#painel-senhas-sabin'))return;
            const texto=(el.innerText||'').trim();
            if(texto.length>250||!/TEMPO DE ATENDIMENTO/i.test(texto))return;
            const encontradas=[...new Set(texto.match(/\b[A-Z]{1,2}\d{3}\b/g)||[])];
            if(encontradas.length===1)codigos.add(encontradas[0]);
        });
        return codigos;
    }
    async function enviarObservacaoPiloto(captura, motivo, senhaChamada=null){
        if(!captura?.eventoId||!captura.piloto)return false;
        try {
            const ok=await consultarSupabase('rpc/registrar_observacao_v2',{
                method:'POST',body:JSON.stringify({
                    p_evento_id:captura.eventoId,p_unit_id:ID_UNIDADE,
                    p_guiche:captura.guiche,p_senha_recomendada:captura.senha,
                    p_senha_chamada:senhaChamada,p_tipo_acao:captura.tipo,p_motivo:motivo
                })
            });
            if(ok!==true)console.warn('[Painel Sabin] Observacao piloto nao aceita:',motivo,senhaChamada);
            return ok===true;
        } catch(e) {
            if(!erroPilotoAvisado){
                console.warn('[Painel Sabin] Auditoria piloto ainda nao habilitada ou indisponivel no Supabase:',e);
                erroPilotoAvisado=true;
            }
            return false;
        }
    }
    function finalizarObservacao(captura,senhaChamada,motivo){
        if(!captura||captura.finalizado)return;
        captura.finalizado=true;
        if(captura.piloto){
            Promise.resolve(captura.envioInicial).then(()=>enviarObservacaoPiloto(captura,motivo,senhaChamada));
        }
        snapshotTravado=false;
        recomendadaSnapshot=null;
    }

    function lerSenhas() {
        guicheAtual=detectarGuiche();
        document.getElementById('psb-guiche').innerText=guicheAtual;

        const emAtendimento=new Set();
        Array.from(document.querySelectorAll('div')).forEach(el=>{
            if(el.closest('#painel-senhas-sabin'))return;
            const txt=el.innerText||'';
            if(txt.length>500)return;
            if(!/TEMPO DE ATENDIMENTO/i.test(txt))return;
            (txt.match(/[A-Z]{1,2}\d{3}/g)||[]).forEach(s=>emAtendimento.add(s));
        });

        const IGNORAR=/TEMPO DE ATENDIMENTO|Finalizado pelo|Concluída|Histórico/i;
        const vistos=new Set(), novas=[];
        const instanteLeitura=Date.now();

        Array.from(document.querySelectorAll('div,li')).forEach(el=>{
            if(el.closest('#painel-senhas-sabin'))return;
            const txt=(el.innerText||'').trim();
            if(txt.length<10||txt.length>150)return;
            if(!/[A-Z]{1,2}\d{3}/.test(txt)||!/\d{2}:\d{2}:\d{2}/.test(txt))return;
            if(IGNORAR.test(txt))return;
            const senhasNoCard=new Set((txt.match(/[A-Z]{1,2}\d{3}/g)||[]));
            if(senhasNoCard.size!==1)return;
            const codSenha=[...senhasNoCard][0];
            if(vistos.has(codSenha)||emAtendimento.has(codSenha))return;
            const tempoMatch=txt.match(/(\d{2}:\d{2}:\d{2})/);
            if(!tempoMatch)return;
            vistos.add(codSenha);
            const partes=tempoMatch[1].split(':').map(Number);
            const segundos=partes[0]*3600+partes[1]*60+partes[2];
            const prefixo=codSenha.replace(/\d/g,'');
            const priorLetra=prefixo.slice(-1);
            if(!['A','P','G'].includes(priorLetra))return;
            const tipoLetra=prefixo.length>1?prefixo[0]:prefixo;
            const chave=tipoLetra+priorLetra;
            const limiteMin=TEMPOS[chave]||15;
            // Recalcular a partir do contador atual do Sabin a cada leitura.
            // Reaproveitar timestamp antigo fazia uma senha mais nova ultrapassar
            // outra da mesma categoria apos atrasos, pausas ou recarregamentos.
            novas.push({
                senha:codSenha, prioridade:priorLetra, tipo:tipoLetra, chave,
                label:(TIPOS_LABEL[tipoLetra]||tipoLetra)+' · '+(PRIOR_LABEL[priorLetra]||priorLetra),
                limiteMin,
                timestampBase:instanteLeitura-segundos*1000
            });
        });

        novas.sort((a,b)=>{
            const pA=((Date.now()-a.timestampBase)/1000)/(a.limiteMin*60)*100;
            const pB=((Date.now()-b.timestampBase)/1000)/(b.limiteMin*60)*100;
            return pB-pA || a.timestampBase-b.timestampBase || a.senha.localeCompare(b.senha);
        });

        baseDados=novas;
        ultimaRecomendada=novas.length>0?novas[0].senha:null;
        // Só atualiza o snapshot se não estiver travado (aguardando registro de chamada)
        if(!snapshotTravado) recomendadaSnapshot=novas[0]?.senha||null;

        ['A','P','G'].forEach(p=>{
            document.getElementById(`psb-num-${p}`).innerText=novas.filter(s=>s.prioridade===p).length;
        });

        const lista=document.getElementById('psb-lista');
        if(novas.length===0){
            lista.innerHTML='<div style="text-align:center;color:#444;padding:16px;font-size:12px;">Nenhuma senha na fila</div>';
            document.getElementById('psb-recomendada').style.display='none';
        } else {
            document.getElementById('psb-recomendada').style.display='block';
            lista.innerHTML=novas.map((s,idx)=>{
                const cor=COR[s.prioridade],fundo=FUNDO[s.prioridade],icone=ICONE[s.prioridade];
                const seg=(Date.now()-s.timestampBase)/1000;
                const pct=Math.min((seg/(s.limiteMin*60))*100,999);
                const urg=pct>=80;
                return `<div id="psb-card-${idx}" style="display:flex;align-items:center;gap:8px;background:${fundo};border:1px solid ${cor}44;border-left:3px solid ${cor};border-radius:8px;padding:7px 9px;margin-bottom:5px;${urg?`animation:psb-pisca 1s infinite;box-shadow:0 0 8px ${cor};`:''}">
                    <div style="font-size:10px;color:#444;width:14px;">${idx+1}º</div>
                    <div style="font-size:15px;">${icone}</div>
                    <div style="flex:1;">
                        <div style="font-weight:700;font-size:14px;color:${cor};">${s.senha}</div>
                        <div style="font-size:10px;color:#666;">${s.label}</div>
                    </div>
                    <div style="text-align:right;">
                        <div id="psb-tempo-${idx}" style="font-size:12px;color:${urg?cor:'#aaa'};font-weight:${urg?'700':'400'};">⏱ ${fmt(seg)}</div>
                        <div id="psb-pct-${idx}" style="font-size:10px;color:${pct>=100?'#e74c3c':pct>=80?'#e67e22':'#666'};font-weight:700;">${Math.round(pct)}% / ${s.limiteMin}min</div>
                    </div>
                </div>`;
            }).join('');

            const top=novas[0];
            const segTop=(Date.now()-top.timestampBase)/1000;
            const pctTop=Math.min((segTop/(top.limiteMin*60))*100,999);
            document.getElementById('psb-recom-corpo').innerHTML=`
                <div style="display:flex;align-items:center;gap:8px;">
                    <div style="font-size:20px;">${ICONE[top.prioridade]}</div>
                    <div style="flex:1;">
                        <div style="font-weight:700;font-size:16px;color:#fff;">${top.senha}</div>
                        <div style="font-size:10px;color:#888;">${top.label} · <span id="psb-recom-tempo">⏱ ${fmt(segTop)}</span></div>
                    </div>
                    <div style="text-align:right;">
                        <div id="psb-recom-pct" style="font-size:15px;font-weight:700;color:${pctTop>=100?'#e74c3c':'#2ecc71'};">${Math.round(pctTop)}%</div>
                        <div style="font-size:9px;color:#555;">de ${top.limiteMin}min</div>
                    </div>
                </div>`;
        }
        ultimaLeituraEm=Date.now();
        document.getElementById('psb-hora').innerText=new Date().toLocaleTimeString('pt-BR');
    }

    function tick() {
        if(!document.getElementById('painel-senhas-sabin')||minimizado)return;
        baseDados.forEach((s,idx)=>{
            const seg=(Date.now()-s.timestampBase)/1000;
            const pct=Math.min((seg/(s.limiteMin*60))*100,999);
            const elT=document.getElementById(`psb-tempo-${idx}`);
            const elP=document.getElementById(`psb-pct-${idx}`);
            if(elT)elT.innerText='⏱ '+fmt(seg);
            if(elP){elP.innerText=Math.round(pct)+'% / '+s.limiteMin+'min';elP.style.color=pct>=100?'#e74c3c':pct>=80?'#e67e22':'#666';}
        });
        if(baseDados.length>0){
            const top=baseDados[0];
            const seg=(Date.now()-top.timestampBase)/1000;
            const pct=Math.min((seg/(top.limiteMin*60))*100,999);
            const elRT=document.getElementById('psb-recom-tempo');
            const elRP=document.getElementById('psb-recom-pct');
            if(elRT)elRT.innerText='⏱ '+fmt(seg);
            if(elRP){elRP.innerText=Math.round(pct)+'%';elRP.style.color=pct>=100?'#e74c3c':'#2ecc71';}
            // Atualiza snapshot a cada segundo se não estiver travado
            // A recomendacao so muda na leitura completa da fila, nao no cronometro.
        }
    }


    function monitorarBotaoChamar(){
        const capturar=btn=>{
            const agora=Date.now();
            if(chamadaPendente&&agora-chamadaPendente.ts<1200)return; // pointerdown + click
            if(chamadaPendente){
                finalizarObservacao(chamadaPendente,null,'tempo_esgotado');
                chamadaPendente=null;
            }
            guicheAtual=detectarGuiche();
            const textoBotao=(btn.innerText||'').trim().replace(/\s+/g,' ');
            const tipo=/Pr[oó]xima/i.test(textoBotao)?'proxima':'manual';
            const topo=baseDados[0]?.senha||null;
            const senhaVisivel=(document.getElementById('psb-recom-corpo')?.innerText||'').match(/\b[A-Z]{1,2}\d{3}\b/)?.[0]||null;
            // Sem confirmacao da leitura recente e do elemento visivel, nao assumir recomendacao.
            const senha=(Date.now()-ultimaLeituraEm<5000&&senhaVisivel===topo
                &&document.getElementById('psb-recomendada')?.style.display!=='none')?senhaVisivel:null;
            const piloto=pilotoAtivo();
            const eventoId=piloto&&window.crypto?.randomUUID?window.crypto.randomUUID():null;
            const captura={
                senha,ts:agora,tipo,guiche:guicheAtual,piloto:piloto&&!!eventoId,eventoId,
                antes:senhasAtivasNaTela(),candidato:null,candidatoDesde:0,
                finalizado:false,envioInicial:null
            };
            chamadaPendente=captura;
            recomendadaSnapshot=senha;
            snapshotTravado=true;
            if(captura.piloto)captura.envioInicial=enviarObservacaoPiloto(captura,'aguardando');
        };
        Array.from(document.querySelectorAll('button,a,div[role="button"]'))
            .filter(el=>{
                if(el.closest('#painel-senhas-sabin'))return false;
                const txt=(el.innerText||'').trim().replace(/\s+/g,' ');
                return /Chamar Pr[oó]xima|Chamar Senha|^Chamar$|^Pr[oó]xima Senha$/i.test(txt)
                    && !/Repetir/i.test(txt) && el.getBoundingClientRect().width>0;
            }).forEach(btn=>{
                if(btn.dataset.psbMonitoradoV2)return;
                btn.dataset.psbMonitoradoV2='1';
                btn.addEventListener('pointerdown',()=>capturar(btn),true);
                btn.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' ')capturar(btn);},true);
                btn.addEventListener('click',()=>capturar(btn),true);
            });
    }


    // Monitoramento adicional: acompanha a senha que entrou em atendimento
    // mesmo quando o Sabin não expõe um clique de "Chamar" ao painel.
    let guicheBaseMonitorado=guicheAtual;
    const ativaInicial=senhasAtivasNaTela();
    let ultimaSenhaAtivaConfirmada=ativaInicial.size===1?[...ativaInicial][0]:null;
    let candidataSemClique=null, candidataSemCliqueDesde=0, semAtivaDesde=0;

    function registrarChamadaSemClique(codigo,agora){
        const piloto=pilotoAtivo();
        const eventoId=piloto&&window.crypto?.randomUUID?window.crypto.randomUUID():null;
        // A recomendação anterior não é verificável sem o evento do clique.
        // Contar a senha, mas não atribuir um acerto ou erro especulativo.
        const captura={
            senha:null,ts:agora,tipo:'manual',guiche:guicheAtual,
            piloto:piloto&&!!eventoId,eventoId,finalizado:false,envioInicial:null
        };
        if(captura.piloto)captura.envioInicial=enviarObservacaoPiloto(captura,'aguardando');
        finalizarObservacao(captura,codigo,'sem_recomendacao');
    }

    function verificarChamada(){
        monitorarBotaoChamar();
        const agora=Date.now();
        const codigos=senhasAtivasNaTela();
        const ativa=codigos.size===1?[...codigos][0]:null;

        // Troca de guichê: a senha que já estava aberta não é nova chamada.
        if(guicheBaseMonitorado!==guicheAtual){
            guicheBaseMonitorado=guicheAtual;
            ultimaSenhaAtivaConfirmada=ativa;
            candidataSemClique=null;
            semAtivaDesde=0;
            if(chamadaPendente){
                finalizarObservacao(chamadaPendente,null,'tempo_esgotado');
                chamadaPendente=null;
            }
            return;
        }

        const captura=chamadaPendente;
        if(captura&&!captura.finalizado){
            if(agora-captura.ts>30000||guicheAtual!==captura.guiche){
                finalizarObservacao(captura,null,'tempo_esgotado');
                if(chamadaPendente===captura)chamadaPendente=null;
            } else {
                if(!ativa||captura.antes.has(ativa))return;
                if(captura.candidato!==ativa){
                    captura.candidato=ativa;
                    captura.candidatoDesde=agora;
                    return;
                }
                if(agora-captura.candidatoDesde<1500)return;
                const chave=captura.guiche+'|'+ativa;
                const repetida=chamadasRecentes.has(chave)
                    &&agora-chamadasRecentes.get(chave)<90000;
                const motivo=repetida||captura.antes.size>1?'captura_ambigua':
                    !captura.senha?'sem_recomendacao':
                    captura.tipo!=='proxima'?'chamada_manual':'chamada_confirmada';
                chamadasRecentes.set(chave,agora);
                for(const [chaveAntiga,instante] of chamadasRecentes){
                    if(agora-instante>180000)chamadasRecentes.delete(chaveAntiga);
                }
                finalizarObservacao(captura,ativa,motivo);
                if(chamadaPendente===captura)chamadaPendente=null;
                ultimaSenhaAtivaConfirmada=ativa;
                candidataSemClique=null;
                semAtivaDesde=0;
                return;
            }
        }

        // Detecta a troca real de senha sem clique capturado.
        // Aguarda estabilidade para evitar chamadas fictícias durante transições.
        if(!ativa){
            if(!semAtivaDesde)semAtivaDesde=agora;
            if(agora-semAtivaDesde>10000)ultimaSenhaAtivaConfirmada=null;
            candidataSemClique=null;
            return;
        }
        semAtivaDesde=0;
        if(ativa===ultimaSenhaAtivaConfirmada){
            candidataSemClique=null;
            return;
        }
        if(candidataSemClique!==ativa){
            candidataSemClique=ativa;
            candidataSemCliqueDesde=agora;
            return;
        }
        if(agora-candidataSemCliqueDesde<1500)return;
        ultimaSenhaAtivaConfirmada=ativa;
        candidataSemClique=null;
        const chave=guicheAtual+'|'+ativa;
        if(agora-(chamadasRecentes.get(chave)||0)<8000)return;
        chamadasRecentes.set(chave,agora);
        registrarChamadaSemClique(ativa,agora);
    }

    function abrirConfig() {
        const modal=document.createElement('div');
        modal.id='psb-modal-config';
        modal.style.cssText='position:fixed;inset:0;background:rgba(0,0,0,.9);z-index:2147483648;display:flex;align-items:center;justify-content:center;font-family:Segoe UI,Arial,sans-serif;';
        let linhas='';
        TIPOS.forEach(t=>PRIORS.forEach(p=>{
            const chave=t+p,val=TEMPOS[chave]||15,corP=p==='A'?'#e74c3c':p==='P'?'#e67e22':'#aaa';
            linhas+=`<tr><td style="padding:5px 8px;color:#ccc;font-size:12px;">${TIPOS_LABEL[t]||t}</td><td style="padding:5px 8px;color:${corP};font-size:11px;font-weight:700;">${PRIOR_LABEL[p]}</td><td style="padding:5px 8px;"><input type="number" id="psb-cfg-${chave}" value="${val}" min="1" max="120" style="width:55px;padding:4px;border-radius:6px;border:1px solid #444;background:#2a2a2a;color:#fff;font-size:12px;text-align:center;"> <span style="color:#666;font-size:10px;">min</span></td></tr>`;
        }));
        modal.innerHTML=`<div style="background:#1a1a1a;border:2px solid #2d7dff;border-radius:12px;padding:20px;width:350px;max-height:85vh;overflow-y:auto;">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
                <span style="font-size:15px;font-weight:700;color:#fff;">⚙️ Configurar Tempos</span>
                <button onclick="document.getElementById('psb-modal-config').remove()" style="background:#444;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;">✕</button>
            </div>
            <table style="width:100%;border-collapse:collapse;"><thead><tr>
                <th style="text-align:left;padding:5px 8px;font-size:10px;color:#555;border-bottom:1px solid #333;">Serviço</th>
                <th style="text-align:left;padding:5px 8px;font-size:10px;color:#555;border-bottom:1px solid #333;">Prioridade</th>
                <th style="text-align:left;padding:5px 8px;font-size:10px;color:#555;border-bottom:1px solid #333;">Tempo</th>
            </tr></thead><tbody>${linhas}</tbody></table>
            <div style="display:flex;gap:8px;margin-top:14px;">
                <button id="psb-cfg-restaurar" style="flex:1;padding:9px;background:#333;color:#aaa;border:none;border-radius:8px;cursor:pointer;font-size:12px;">Restaurar padrão</button>
                <button id="psb-cfg-salvar" style="flex:1;padding:9px;background:#2d7dff;color:#fff;border:none;border-radius:8px;cursor:pointer;font-weight:700;">💾 Salvar</button>
            </div>
            <div id="psb-cfg-ok" style="display:none;text-align:center;color:#2ecc71;font-size:12px;margin-top:8px;">✅ Salvo!</div>
        </div>`;
        document.body.appendChild(modal);
        document.getElementById('psb-cfg-salvar').onclick=async ()=>{
        const senha = prompt('Digite a senha da unidade para salvar os tempos:');
if (senha === null) return;
            const novos={};
            TIPOS.forEach(t=>PRIORS.forEach(p=>{ const c=t+p; novos[c]=parseInt(document.getElementById(`psb-cfg-${c}`)?.value)||15; }));
            if (Object.values(novos).some(v => !Number.isInteger(v) || v < 1 || v > 999)) { alert('Informe tempos entre 1 e 999 minutos.'); return; }
            try {
            const resultado = await consultarSupabase('rpc/atualizar_tempos_unidade', {
  method: 'POST',
  body: JSON.stringify({
    p_unit_id: ID_UNIDADE,
    p_senha: senha,
    p_tempos: novos
  })
});

if (resultado !== true) {
  alert('Senha incorreta ou não foi possível salvar os tempos.');
  return;
}
            } catch (erro) { alert('Erro ao salvar no Supabase: ' + erro.message); return; }

TEMPOS = novos;
salvarTempos(novos);
            document.getElementById('psb-cfg-ok').style.display='block';
            setTimeout(()=>{ try{document.getElementById('psb-cfg-ok').style.display='none';}catch{} },2000);
            lerSenhas();
        };
        document.getElementById('psb-cfg-restaurar').onclick=()=>{
            TIPOS.forEach(t=>PRIORS.forEach(p=>{ const el=document.getElementById(`psb-cfg-${t+p}`); if(el)el.value=TEMPOS_PADRAO[t+p]; }));
        };
    }

    async function abrirRelatorio() {
        if(document.getElementById('psb-modal-relatorio'))return;
        const senha=prompt('Senha para consultar o Relatório de Supervisão:');
        if(!senha)return;
        const modal=document.createElement('div');
        modal.id='psb-modal-relatorio';
        modal.style.cssText='position:fixed;inset:0;background:rgba(0,0,0,.92);z-index:2147483648;display:flex;align-items:center;justify-content:center;font-family:Segoe UI,Arial,sans-serif;';
        const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
        const hoje=()=>{const d=new Date();return [d.getFullYear(),String(d.getMonth()+1).padStart(2,'0'),String(d.getDate()).padStart(2,'0')].join('-');};
        let unidades=[], unidadeId=ID_UNIDADE, data=hoje(), guiche='Todos', registros=[], observacoes=[], erroObservacoes='';
        const css='padding:7px;background:#292929;color:white;border:1px solid #555;border-radius:6px;max-width:100%;';
        modal.innerHTML='<div style="background:#191919;color:white;border:2px solid #2d7dff;border-radius:12px;padding:18px;width:760px;max-width:95vw;max-height:88vh;overflow:auto"><div style="display:flex;justify-content:space-between;gap:10px"><b>📊 Relatório de Supervisão</b><button id="psb-rel-fechar">✕</button></div><div id="psb-rel-corpo" style="margin-top:15px">Carregando...</div></div>';
        document.body.appendChild(modal);
        modal.querySelector('#psb-rel-fechar').onclick=()=>modal.remove();
        const corpo=modal.querySelector('#psb-rel-corpo');
        function mostrar() {
            const guiches=[...new Set([...registros,...observacoes].map(r=>r.guiche).filter(Boolean))]
                .sort((x,y)=>x.localeCompare(y,'pt-BR',{numeric:true}));
            if(guiche!=='Todos'&&!guiches.includes(guiche))guiche='Todos';
            const piloto=observacoes.filter(r=>guiche==='Todos'||r.guiche===guiche)
                .sort((a,b)=>new Date(b.criado_em)-new Date(a.criado_em));
            const historicos=registros.filter(r=>guiche==='Todos'||r.guiche===guiche)
                .sort((a,b)=>new Date(b.chamada_em)-new Date(a.chamada_em));
            // Comparacao visual simples, independente da classificacao tecnica.
            // Nao constitui validacao da recomendacao no instante da chamada.
            const comPar=piloto.filter(r=>r.senha_recomendada&&r.senha_chamada);
            const corretas=comPar.filter(r=>r.senha_recomendada===r.senha_chamada).length;
            const erradas=comPar.length-corretas;
            const semDados=piloto.length-comPar.length;
            const linhaCss='padding:8px 5px;border-bottom:1px solid #303846;font-size:12px;';
            const linhas=piloto.slice(0,300).map(r=>{
                const hora=new Date(r.criado_em).toLocaleTimeString('pt-BR',{timeZone:'America/Sao_Paulo'});
                const possuiPar=!!(r.senha_recomendada&&r.senha_chamada);
                const igual=possuiPar&&r.senha_recomendada===r.senha_chamada;
                const rotulo=possuiPar?(igual?'Correta*':'Errada*'):'—';
                const cor=possuiPar?(igual?'#86efac':'#fca5a5'):'#94a3b8';
                return '<tr><td style="'+linhaCss+'">'+esc(hora)+'</td>'+
                    '<td style="'+linhaCss+'">'+esc(r.guiche)+'</td>'+
                    '<td style="'+linhaCss+'">'+esc(r.senha_recomendada||'—')+'</td>'+
                    '<td style="'+linhaCss+'"><b>'+esc(r.senha_chamada||'—')+'</b></td>'+
                    '<td style="'+linhaCss+';color:'+cor+'"><b>'+rotulo+'</b></td></tr>';
            }).join('');
            const historicoLinhas=historicos.slice(0,300).map(r=>{
                const hora=new Date(r.chamada_em).toLocaleTimeString('pt-BR',{timeZone:'America/Sao_Paulo'});
                return '<tr><td style="'+linhaCss+'">'+esc(hora)+'</td>'+
                    '<td style="'+linhaCss+'">'+esc(r.guiche)+'</td>'+
                    '<td style="'+linhaCss+'">'+esc(r.senha_chamada)+'</td>'+
                    '<td style="'+linhaCss+'">'+esc(r.senha_recomendada||'—')+'</td></tr>';
            }).join('');
            const botoes='<div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:14px;align-items:end">'+
                '<label style="font-size:12px">Unidade<br><select id="psb-rel-unidade" style="'+css+'">'+
                unidades.map(u=>'<option value="'+esc(u.id)+'" '+(u.id===unidadeId?'selected':'')+'>'+esc(u.name)+'</option>').join('')+
                '</select></label>'+
                '<label style="font-size:12px">Data<br><input id="psb-rel-data" type="date" value="'+esc(data)+'" style="'+css+'"></label>'+
                '<label style="font-size:12px">Guichê<br><select id="psb-rel-guiche" style="'+css+'">'+
                ['Todos',...guiches].map(g=>'<option '+(g===guiche?'selected':'')+'>'+esc(g)+'</option>').join('')+
                '</select></label>'+
                '<button id="psb-rel-atualizar" style="'+css+';cursor:pointer">Atualizar</button></div>';
            const status='<div style="font-size:12px;color:#fcd34d;margin-bottom:12px">'+
                '🧪 Monitoramento V2 em teste — todos os guichês. Não utilizar para avaliar atendentes.</div>'+
                (erroObservacoes?'<div style="font-size:12px;color:#fca5a5;margin-bottom:10px">⚠️ Não foi possível consultar o monitoramento: '+esc(erroObservacoes)+'</div>':'')+
                (observacoes.length>=1000?'<div style="font-size:12px;color:#fcd34d;margin-bottom:10px">Mostrando apenas os 1000 registros mais recentes desta unidade/data.</div>':'');
            const resumo='<div style="background:#1e293b;border-radius:8px;padding:10px 12px;margin-bottom:13px;font-size:13px;line-height:1.8">'+
                '<b>'+piloto.length+'</b> chamada(s) registrada(s) &nbsp;·&nbsp; '+
                '<b>'+corretas+'</b> corretas* &nbsp;·&nbsp; '+
                '<b>'+erradas+'</b> erradas*'+
                (semDados?' &nbsp;·&nbsp; <b>'+semDados+'</b> sem dados completos':'')+'</div>';
            const tabela='<div style="font-weight:700;font-size:13px;margin-bottom:8px">Chamadas do teste</div>'+
                '<div style="overflow-x:auto"><table style="width:100%;text-align:left;border-collapse:collapse">'+
                '<thead><tr><th>Hora</th><th>Guichê</th><th>Recomendada</th><th>Chamada</th><th>Situação</th></tr></thead>'+
                '<tbody>'+(linhas||'<tr><td colspan="5" style="padding:12px 0;color:#aaa">Nenhuma chamada registrada neste período.</td></tr>')+
                '</tbody></table></div>'+
                '<div style="font-size:11px;color:#94a3b8;margin-top:9px;margin-bottom:13px">'+
                '*Correta/Errada indica apenas se os dois códigos registrados são iguais ou diferentes. A captura ainda não foi validada e não deve ser usada para avaliar atendentes. Traço (—) indica dados insuficientes.</div>';
            const historico='<details style="border-top:1px solid #384152;margin-top:7px;padding-top:10px">'+
                '<summary style="cursor:pointer;font-size:12px;color:#cbd5e1">Ver histórico anterior ('+historicos.length+' registros)</summary>'+
                '<div style="font-size:11px;color:#fcd34d;margin:10px 0">Registros antigos sem validação de precisão; podem conter duplicatas ou recomendações incorretas.</div>'+
                '<div style="overflow-x:auto"><table style="width:100%;text-align:left;border-collapse:collapse">'+
                '<thead><tr><th>Hora</th><th>Guichê</th><th>Chamada</th><th>Recomendação antiga</th></tr></thead>'+
                '<tbody>'+(historicoLinhas||'<tr><td colspan="4" style="padding:9px 0">Nenhum registro antigo nesta data.</td></tr>')+
                '</tbody></table></div></details>';
            corpo.innerHTML=botoes+status+resumo+tabela+historico;
            corpo.querySelector('#psb-rel-unidade').onchange=e=>{unidadeId=e.target.value;guiche='Todos';buscar();};
            corpo.querySelector('#psb-rel-data').onchange=e=>{data=e.target.value;guiche='Todos';buscar();};
            corpo.querySelector('#psb-rel-guiche').onchange=e=>{guiche=e.target.value;mostrar();};
            corpo.querySelector('#psb-rel-atualizar').onclick=buscar;
        }
        async function buscar(){
            corpo.textContent='Consultando registros...';
            try {
                const resposta=await consultarSupabase('rpc/consultar_relatorio_chamadas',{
                    method:'POST',body:JSON.stringify({p_senha:senha,p_unit_id:unidadeId,p_data:data})
                });
                registros=Array.isArray(resposta)?resposta:[];
                try {
                    const respPiloto=await consultarSupabase('rpc/consultar_observacoes_v2',{
                        method:'POST',body:JSON.stringify({p_senha:senha,p_unit_id:unidadeId,p_data:data})
                    });
                    observacoes=Array.isArray(respPiloto)?respPiloto:[];
                    erroObservacoes='';
                } catch(e) {
                    observacoes=[];
                    erroObservacoes=e.message||'serviço indisponível';
                }
                if(modal.isConnected)mostrar();
            } catch(e) {
                if(modal.isConnected)corpo.textContent='Não foi possível consultar. Confira a senha e a configuração do Supabase. '+e.message;
            }
        }
        try {
            unidades=await consultarSupabase('units?select=id,name&active=eq.true&order=name.asc');
            await buscar();
        } catch(e){corpo.textContent='Erro ao carregar unidades: '+e.message;}
    }

    document.getElementById('psb-atualizar').onclick=lerSenhas;
    document.getElementById('psb-btn-config').onclick=abrirConfig;
    document.getElementById('psb-btn-relatorio').onclick=abrirRelatorio;

    lerSenhas();
    monitorarBotaoChamar();

    const intSync=setInterval(async ()=>{
        if (!document.getElementById('painel-senhas-sabin')) { clearInterval(intSync); return; }
        if (carregandoTempos) return;
        carregandoTempos = true;
        try {
            const dados = await consultarSupabase('unit_settings?select=tempos&unit_id=eq.' + ID_UNIDADE);
            if (dados.length && dados[0].tempos) {
                const novos = { ...TEMPOS_PADRAO, ...dados[0].tempos };
                if (JSON.stringify(novos) !== JSON.stringify(TEMPOS)) {
                    TEMPOS = novos;
                    salvarTempos(novos);
                    if (!document.getElementById('psb-modal-config')) lerSenhas();
                }
            }
        } catch (erro) { console.warn('Sincronização dos tempos:', erro); }
        finally { carregandoTempos = false; }
    }, 3000);

    const intLer=setInterval(()=>{
        if(!document.getElementById('painel-senhas-sabin')){clearInterval(intLer);clearInterval(intTick);clearInterval(intChamada);clearInterval(intSync);return;}
        lerSenhas();verificarChamada();
    },2000);
    const intTick=setInterval(()=>{
        if(!document.getElementById('painel-senhas-sabin')){clearInterval(intTick);return;}
        tick();
    },1000);
    const intChamada=setInterval(()=>{
        if(!document.getElementById('painel-senhas-sabin')){clearInterval(intChamada);return;}
        verificarChamada();
    },1000);

    }
        const UNIDADES = [
      'Arniqueira',
      'Jacarandá',
      'Metrópole',
      'Núcleo Bandeirante',
      'Terraço Shopping',
      'Vicente Pires I',
      'Cruzeiro Center',
      'Guará I',
      'Guará II',
      'Guará II - Real Mix',
      'Vicente Pires II',
      'Park Sul',
      'Sudoeste 105',
      'Águas Claras',
      'Shopping Felicittá',
      'SIA Center',
      'Sudoeste 104',
      'Sudoeste Centro Clínico',
      'Sudoeste JK'
    ];

    const tela = document.createElement('div');
    tela.id = 'psb-selecao-unidade';
    tela.style.cssText = 'position:fixed;inset:0;z-index:2147483647;background:#0f172a;color:white;display:flex;align-items:center;justify-content:center;font-family:Arial,sans-serif;';

    const caixa = document.createElement('div');
    caixa.style.cssText = 'background:#1e293b;padding:25px;border-radius:15px;width:90%;max-width:650px;max-height:90vh;overflow:auto;box-sizing:border-box;';

    const titulo = document.createElement('h2');
    titulo.textContent = 'PAINEL DE SENHAS SABIN';
    titulo.style.textAlign = 'center';

    const subtitulo = document.createElement('p');
    subtitulo.textContent = 'Selecione sua unidade';
    subtitulo.style.textAlign = 'center';

    const grade = document.createElement('div');
    grade.style.cssText = 'display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:10px;';

    UNIDADES.forEach(nome => {
      const botao = document.createElement('button');
      botao.textContent = nome;
      botao.style.cssText = 'padding:14px;border:0;border-radius:8px;background:#2563eb;color:white;font-size:14px;cursor:pointer;';

      botao.onclick = async () => {
    botao.disabled = true;

    try {
        await iniciarPainel(nome);
        tela.remove();
    } catch (erro) {
        alert('Erro ao abrir a unidade: ' + erro.message);
        botao.disabled = false;
    }
};
      grade.appendChild(botao);
    });

    const fechar = document.createElement('button');
    fechar.textContent = 'Cancelar';
    fechar.style.cssText = 'display:block;margin:20px auto 0;padding:10px 25px;border:0;border-radius:8px;cursor:pointer;';
    fechar.onclick = () => tela.remove();

    caixa.appendChild(titulo);
    caixa.appendChild(subtitulo);
    caixa.appendChild(grade);
    caixa.appendChild(fechar);
    tela.appendChild(caixa);
    document.body.appendChild(tela);
    })();
