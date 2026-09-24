(() => {
    if (document.getElementById('painel-senhas-sabin')) return;

    // ── CONFIGURAÇÕES ─────────────────────────────────────────────
    const SENHA_ADMIN = '1234';
    const APPS_SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbxYIo9jV3fZuQ2Pb9NhK_X7LmB9aRZ3C1U31Rli0EKYPFCUh6IyS-TAOpjXq0qFTwadBw/exec';

    const TIPOS_LABEL = { R:'Resultado', E:'Exames', P:'Pendência', A:'Agendamento', D:'Digital', V:'Vacina' };
    const PRIOR_LABEL = { A:'80+ Alta', P:'Preferencial', G:'Geral' };
    const TIPOS = ['R','E','P','A','D','V'];
    const PRIORS = ['A','P','G'];
    const COR   = { A:'#e74c3c', P:'#e67e22', G:'#95a5a6' };
    const FUNDO = { A:'#2c0a0a', P:'#2c1a0a', G:'#1a1a1a' };
    const ICONE = { A:'🔴', P:'🟠', G:'⚪' };

    // ── TEMPOS ────────────────────────────────────────────────────
    const TEMPOS_PADRAO = {};
    TIPOS.forEach(t => { TEMPOS_PADRAO[t+'A']=5; TEMPOS_PADRAO[t+'P']=10; TEMPOS_PADRAO[t+'G']=15; });
    function carregarTempos() {
        try { const s=localStorage.getItem('psb_tempos'); return s?{...TEMPOS_PADRAO,...JSON.parse(s)}:{...TEMPOS_PADRAO}; } catch { return {...TEMPOS_PADRAO}; }
    }
    function salvarTempos(t) { try { localStorage.setItem('psb_tempos',JSON.stringify(t)); } catch {} }
    let TEMPOS = carregarTempos();

    // ── DATA ATUAL ────────────────────────────────────────────────
    function dataHoje() {
        const d = new Date();
        return [String(d.getDate()).padStart(2,'0'), String(d.getMonth()+1).padStart(2,'0'), d.getFullYear()].join('/');
    }

    // ── DETECTAR GUICHÊ E UNIDADE ─────────────────────────────────
    function detectarGuiche() {
        const txt = document.body.innerText || '';
        const m = txt.match(/Guiche\s*(\d+)/i) || txt.match(/Guich[êe]\s*#?\s*(\d+)/i);
        return m ? 'Guiche ' + m[1] : 'Guiche ?';
    }
    function detectarUnidade() {
        const el = document.querySelector('[class*="unidade"],[id*="unidade"]');
        if (el) return el.innerText?.trim() || '';
        return sessionStorage.getItem('unidade_central') || '';
    }

    // ── FORMATAR ──────────────────────────────────────────────────
    function fmt(seg) {
        seg = Math.max(0, Math.floor(seg));
        const h=Math.floor(seg/3600), m=Math.floor((seg%3600)/60), s=seg%60;
        return [h,m,s].map(n=>String(n).padStart(2,'0')).join(':');
    }

    // ── ENVIAR CHAMADA PARA APPS SCRIPT ──────────────────────────
    function enviarChamada(payload) {
        fetch(APPS_SCRIPT_URL, {
            method: 'POST',
            mode: 'no-cors',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ tipo: 'chamada', ...payload })
        }).catch(() => {});
    }

    // ── BUSCAR RELATÓRIO DO APPS SCRIPT ──────────────────────────
    async function buscarRelatorio(data, guiche) {
        try {
            const params = new URLSearchParams({ acao: 'relatorio', data: data || '', guiche: guiche || 'Todos' });
            const r = await fetch(`${APPS_SCRIPT_URL}?${params}`);
            const json = await r.json();
            return json.dados || [];
        } catch { return []; }
    }

    // ── VERIFICAR SENHA ───────────────────────────────────────────
    function verificarSenha(callback) {
        const modal = document.createElement('div');
        modal.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.85);z-index:2147483648;display:flex;align-items:center;justify-content:center;font-family:Segoe UI,Arial,sans-serif;';
        modal.innerHTML = `<div style="background:#1e1e1e;border:2px solid #2d7dff;border-radius:12px;padding:24px;width:280px;text-align:center;">
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
        const inp = modal.querySelector('#psb-si'); inp.focus();
        modal.querySelector('#psb-sc').onclick = () => modal.remove();
        const tentar = () => {
            if (inp.value === SENHA_ADMIN) { modal.remove(); callback(); }
            else { modal.querySelector('#psb-se').style.display='block'; inp.value=''; inp.focus(); }
        };
        modal.querySelector('#psb-so').onclick = tentar;
        inp.addEventListener('keydown', e => { if(e.key==='Enter') tentar(); });
    }

    // ── PAINEL HTML ───────────────────────────────────────────────
    const painel = document.createElement('div');
    painel.id = 'painel-senhas-sabin';
    painel.style.cssText = 'position:fixed;top:10px;right:10px;width:340px;background:#111;color:#fff;border-radius:12px;box-shadow:0 8px 32px rgba(0,0,0,.8);z-index:2147483647;font-family:Segoe UI,Arial,sans-serif;border:1px solid #333;overflow:hidden;';
    painel.innerHTML = `
        <div id="psb-header" style="background:#1a1a1a;padding:10px 14px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid #333;">
            <span style="font-weight:700;font-size:13px;">📋 Painel · <span id="psb-guiche" style="color:#2d7dff;font-size:12px;">--</span></span>
            <div style="display:flex;gap:5px;" onclick="event.stopPropagation()">
                <button id="psb-btn-config" title="Configurações" style="background:#333;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;font-size:13px;">⚙️</button>
                <button id="psb-btn-relatorio" title="Relatório" style="background:#333;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;font-size:13px;">📊</button>
                <button id="psb-atualizar" title="Atualizar" style="background:#2d7dff;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;font-size:13px;">↻</button>
                <button id="psb-minimizar" title="Minimizar" style="background:#555;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;font-size:13px;">−</button>
                <button onclick="document.getElementById('painel-senhas-sabin').remove()" style="background:#444;border:none;color:#fff;border-radius:6px;padding:3px 7px;cursor:pointer;font-size:13px;">✕</button>
            </div>
        </div>
        <div id="psb-corpo">
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
            <div id="psb-recomendada" style="display:none;padding:8px 10px;background:#0a1f0a;border-bottom:1px solid #1a3a1a;">
                <div style="font-size:9px;color:#2ecc71;font-weight:700;margin-bottom:3px;">✅ PRÓXIMA RECOMENDADA</div>
                <div id="psb-recom-corpo"></div>
            </div>
            <div id="psb-lista" style="max-height:360px;overflow-y:auto;padding:6px;"></div>
            <div style="padding:5px;text-align:center;font-size:9px;color:#444;border-top:1px solid #1a1a1a;">
                Leitura: <span id="psb-hora">--</span>
            </div>
        </div>`;
    document.body.appendChild(painel);

    const style = document.createElement('style');
    style.innerHTML = `@keyframes psb-pisca{0%,100%{opacity:1}50%{opacity:.4}} #psb-lista::-webkit-scrollbar{width:4px} #psb-lista::-webkit-scrollbar-thumb{background:#333;border-radius:2px}`;
    document.head.appendChild(style);

    // ── MINIMIZAR ─────────────────────────────────────────────────
    let minimizado = false;
    document.getElementById('psb-minimizar').onclick = () => {
        minimizado = !minimizado;
        document.getElementById('psb-corpo').style.display = minimizado ? 'none' : 'block';
        document.getElementById('psb-minimizar').innerText = minimizado ? '+' : '−';
    };
    document.getElementById('psb-header').onclick = () => document.getElementById('psb-minimizar').click();

    // ── ESTADO ────────────────────────────────────────────────────
    let baseDados = [];
    let ultimaRecomendada = null;
    let recomendadaSnapshot = null;
    let ultimaSenhaAtendimento = null;
    let guicheAtual = detectarGuiche();
    document.getElementById('psb-guiche').innerText = guicheAtual;

    // ── LER SENHAS ────────────────────────────────────────────────
    function lerSenhas() {
        guicheAtual = detectarGuiche();
        document.getElementById('psb-guiche').innerText = guicheAtual;

        const emAtendimento = new Set();
        Array.from(document.querySelectorAll('div')).forEach(el => {
            if (el.closest('#painel-senhas-sabin')) return;
            const txt = el.innerText || '';
            if (txt.length > 500) return;
            if (!/TEMPO DE ATENDIMENTO/i.test(txt)) return;
            (txt.match(/[A-Z]{1,2}\d{3}/g)||[]).forEach(s => emAtendimento.add(s));
        });

        const IGNORAR = /TEMPO DE ATENDIMENTO|Finalizado pelo|Concluída|Histórico/i;
        const vistos = new Set();
        const novas = [];

        Array.from(document.querySelectorAll('div,li')).forEach(el => {
            if (el.closest('#painel-senhas-sabin')) return;
            const txt = (el.innerText||'').trim();
            if (txt.length < 10 || txt.length > 150) return;
            if (!/[A-Z]{1,2}\d{3}/.test(txt) || !/\d{2}:\d{2}:\d{2}/.test(txt)) return;
            if (IGNORAR.test(txt)) return;
            const senhasNoCard = new Set((txt.match(/[A-Z]{1,2}\d{3}/g)||[]));
            if (senhasNoCard.size !== 1) return;
            const codSenha = [...senhasNoCard][0];
            if (vistos.has(codSenha) || emAtendimento.has(codSenha)) return;
            const tempoMatch = txt.match(/(\d{2}:\d{2}:\d{2})/);
            if (!tempoMatch) return;
            vistos.add(codSenha);
            const partes = tempoMatch[1].split(':').map(Number);
            const segundos = partes[0]*3600 + partes[1]*60 + partes[2];
            const prefixo = codSenha.replace(/\d/g,'');
            const priorLetra = prefixo.slice(-1);
            if (!['A','P','G'].includes(priorLetra)) return;
            const tipoLetra = prefixo.length > 1 ? prefixo[0] : prefixo;
            const chave = tipoLetra + priorLetra;
            const limiteMin = TEMPOS[chave] || 15;
            const anterior = baseDados.find(b => b.senha === codSenha);
            novas.push({
                senha: codSenha, prioridade: priorLetra, tipo: tipoLetra, chave,
                label: (TIPOS_LABEL[tipoLetra]||tipoLetra) + ' · ' + (PRIOR_LABEL[priorLetra]||priorLetra),
                limiteMin,
                timestampBase: anterior ? anterior.timestampBase : Date.now() - segundos*1000
            });
        });

        novas.sort((a,b) => {
            const pA=((Date.now()-a.timestampBase)/1000)/(a.limiteMin*60)*100;
            const pB=((Date.now()-b.timestampBase)/1000)/(b.limiteMin*60)*100;
            return pB-pA;
        });

        baseDados = novas;
        ultimaRecomendada = novas.length > 0 ? novas[0].senha : null;
        if (novas.length > 0) recomendadaSnapshot = novas[0].senha;

        ['A','P','G'].forEach(p => {
            document.getElementById(`psb-num-${p}`).innerText = novas.filter(s=>s.prioridade===p).length;
        });

        const lista = document.getElementById('psb-lista');
        if (novas.length === 0) {
            lista.innerHTML = '<div style="text-align:center;color:#444;padding:16px;font-size:12px;">Nenhuma senha na fila</div>';
            document.getElementById('psb-recomendada').style.display = 'none';
        } else {
            document.getElementById('psb-recomendada').style.display = 'block';
            lista.innerHTML = novas.map((s, idx) => {
                const cor=COR[s.prioridade], fundo=FUNDO[s.prioridade], icone=ICONE[s.prioridade];
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
            document.getElementById('psb-recom-corpo').innerHTML = `
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
        document.getElementById('psb-hora').innerText = new Date().toLocaleTimeString('pt-BR');
    }

    // ── TICK ─────────────────────────────────────────────────────
    function tick() {
        if (!document.getElementById('painel-senhas-sabin') || minimizado) return;
        baseDados.forEach((s,idx) => {
            const seg=(Date.now()-s.timestampBase)/1000;
            const pct=Math.min((seg/(s.limiteMin*60))*100,999);
            const elT=document.getElementById(`psb-tempo-${idx}`);
            const elP=document.getElementById(`psb-pct-${idx}`);
            if(elT) elT.innerText='⏱ '+fmt(seg);
            if(elP){ elP.innerText=Math.round(pct)+'% / '+s.limiteMin+'min'; elP.style.color=pct>=100?'#e74c3c':pct>=80?'#e67e22':'#666'; }
        });
        if(baseDados.length>0){
            const top=baseDados[0];
            const seg=(Date.now()-top.timestampBase)/1000;
            const pct=Math.min((seg/(top.limiteMin*60))*100,999);
            const elRT=document.getElementById('psb-recom-tempo');
            const elRP=document.getElementById('psb-recom-pct');
            if(elRT) elRT.innerText='⏱ '+fmt(seg);
            if(elRP){ elRP.innerText=Math.round(pct)+'%'; elRP.style.color=pct>=100?'#e74c3c':'#2ecc71'; }
        }
    }

    // ── MONITORAR BOTÃO CHAMAR ────────────────────────────────────
    function monitorarBotaoChamar() {
        const botoes = Array.from(document.querySelectorAll('button,a,div[role="button"]')).filter(el =>
            /Chamar\s*Próxima|Chamar\s*Proxima/i.test(el.innerText||'')
        );
        botoes.forEach(btn => {
            if (btn.dataset.psbMonitorado) return;
            btn.dataset.psbMonitorado = '1';
            btn.addEventListener('click', () => {
                if (baseDados.length > 0) recomendadaSnapshot = baseDados[0].senha;
            }, true);
        });
    }

    // ── VERIFICAR CHAMADA ─────────────────────────────────────────
    function verificarChamada() {
        monitorarBotaoChamar();
        let senhaAtual = null;
        Array.from(document.querySelectorAll('div')).forEach(el => {
            if (el.closest('#painel-senhas-sabin')) return;
            const txt = el.innerText || '';
            if (txt.length > 500) return;
            if (!/TEMPO DE ATENDIMENTO/i.test(txt)) return;
            const m = txt.match(/([A-Z]{1,2}\d{3})/);
            if (m) senhaAtual = m[1];
        });
        if (senhaAtual && senhaAtual !== ultimaSenhaAtendimento) {
            ultimaSenhaAtendimento = senhaAtual;
            const recomendadaAgora = recomendadaSnapshot || ultimaRecomendada || senhaAtual;
            const foiRecomendada = senhaAtual === recomendadaAgora;
            enviarChamada({
                guiche: guicheAtual,
                senha: senhaAtual,
                recomendada: recomendadaAgora,
                foiRecomendada,
                unidade: detectarUnidade(),
                data: dataHoje()
            });
            if (baseDados.length > 0) recomendadaSnapshot = baseDados[0].senha;
        }
    }

    // ── CONFIGURAÇÕES ─────────────────────────────────────────────
    function abrirConfig() {
        TEMPOS = carregarTempos();
        const modal = document.createElement('div');
        modal.id = 'psb-modal-config';
        modal.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.9);z-index:2147483648;display:flex;align-items:center;justify-content:center;font-family:Segoe UI,Arial,sans-serif;';
        let linhas = '';
        TIPOS.forEach(t => PRIORS.forEach(p => {
            const chave=t+p, val=TEMPOS[chave]||15, corP=p==='A'?'#e74c3c':p==='P'?'#e67e22':'#aaa';
            linhas+=`<tr><td style="padding:5px 8px;color:#ccc;font-size:12px;">${TIPOS_LABEL[t]||t}</td><td style="padding:5px 8px;color:${corP};font-size:11px;font-weight:700;">${PRIOR_LABEL[p]}</td><td style="padding:5px 8px;"><input type="number" id="psb-cfg-${chave}" value="${val}" min="1" max="120" style="width:55px;padding:4px;border-radius:6px;border:1px solid #444;background:#2a2a2a;color:#fff;font-size:12px;text-align:center;"> <span style="color:#666;font-size:10px;">min</span></td></tr>`;
        }));
        modal.innerHTML = `<div style="background:#1a1a1a;border:2px solid #2d7dff;border-radius:12px;padding:20px;width:350px;max-height:85vh;overflow-y:auto;">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
                <span style="font-size:15px;font-weight:700;color:#fff;">⚙️ Configurar Tempos</span>
                <button onclick="document.getElementById('psb-modal-config').remove()" style="background:#444;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;">✕</button>
            </div>
            <div style="font-size:10px;color:#666;margin-bottom:10px;">Tempo limite (minutos) por tipo de serviço + prioridade:</div>
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
        document.getElementById('psb-cfg-salvar').onclick = () => {
            const novos={};
            TIPOS.forEach(t=>PRIORS.forEach(p=>{ const c=t+p; novos[c]=parseInt(document.getElementById(`psb-cfg-${c}`)?.value)||15; }));
            TEMPOS=novos; salvarTempos(novos);
            document.getElementById('psb-cfg-ok').style.display='block';
            setTimeout(()=>{ try{document.getElementById('psb-cfg-ok').style.display='none';}catch{} },2000);
            lerSenhas();
        };
        document.getElementById('psb-cfg-restaurar').onclick = () => {
            TIPOS.forEach(t=>PRIORS.forEach(p=>{ const el=document.getElementById(`psb-cfg-${t+p}`); if(el) el.value=TEMPOS_PADRAO[t+p]; }));
        };
    }

    // ── RELATÓRIO ─────────────────────────────────────────────────
    function abrirRelatorio() {
        const modal = document.createElement('div');
        modal.id = 'psb-modal-relatorio';
        modal.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.9);z-index:2147483648;display:flex;align-items:center;justify-content:center;font-family:Segoe UI,Arial,sans-serif;';
        modal.innerHTML = `<div style="background:#1a1a1a;border:2px solid #2d7dff;border-radius:12px;padding:18px;width:500px;max-height:88vh;overflow-y:auto;">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
                <span style="font-size:15px;font-weight:700;color:#fff;">📊 Relatório de Chamadas</span>
                <button onclick="document.getElementById('psb-modal-relatorio').remove()" style="background:#444;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;">✕</button>
            </div>
            <div style="display:flex;gap:8px;margin-bottom:12px;flex-wrap:wrap;">
                <div style="flex:1;min-width:120px;">
                    <div style="font-size:10px;color:#666;margin-bottom:4px;">📅 Data</div>
                    <input type="text" id="psb-filtro-data" value="${dataHoje()}" placeholder="dd/mm/aaaa"
                        style="width:100%;padding:6px;background:#2a2a2a;color:#fff;border:1px solid #444;border-radius:6px;font-size:12px;box-sizing:border-box;">
                </div>
                <div style="flex:1;min-width:120px;">
                    <div style="font-size:10px;color:#666;margin-bottom:4px;">🖥️ Guichê</div>
                    <input type="text" id="psb-filtro-guiche" value="Todos" placeholder="Todos ou Guiche 2"
                        style="width:100%;padding:6px;background:#2a2a2a;color:#fff;border:1px solid #444;border-radius:6px;font-size:12px;box-sizing:border-box;">
                </div>
                <div style="display:flex;align-items:flex-end;">
                    <button id="psb-rel-buscar" style="padding:6px 14px;background:#2d7dff;color:#fff;border:none;border-radius:6px;cursor:pointer;font-weight:700;font-size:12px;">🔍 Buscar</button>
                </div>
            </div>
            <div id="psb-rel-corpo" style="text-align:center;color:#555;padding:20px;font-size:13px;">Clique em Buscar para carregar o relatório...</div>
        </div>`;
        document.body.appendChild(modal);

        async function buscarEMostrar() {
            const corpo = document.getElementById('psb-rel-corpo');
            corpo.innerHTML = '<div style="color:#666;padding:20px;text-align:center;">⏳ Carregando...</div>';
            const data = document.getElementById('psb-filtro-data').value.trim();
            const guiche = document.getElementById('psb-filtro-guiche').value.trim();
            const dados = await buscarRelatorio(data, guiche);

            if (dados.length === 0) {
                corpo.innerHTML = '<div style="color:#444;padding:20px;text-align:center;font-size:12px;">Nenhum registro encontrado para esse filtro.</div>';
                return;
            }

            const total=dados.length, corretas=dados.filter(d=>d.foiRecomendada).length, erradas=total-corretas;
            const pct=total>0?Math.round((corretas/total)*100):0;

            // Resumo por guichê
            const guiches=[...new Set(dados.map(d=>d.guiche||'?'))].sort();
            let resumo='';
            guiches.forEach(g=>{
                const d=dados.filter(x=>x.guiche===g);
                const c=d.filter(x=>x.foiRecomendada).length, e=d.length-c;
                const p=d.length>0?Math.round((c/d.length)*100):0;
                const cor=p>=80?'#2ecc71':p>=50?'#e67e22':'#e74c3c';
                resumo+=`<div style="display:flex;align-items:center;gap:8px;padding:5px 8px;background:#1a1a1a;border:1px solid #2a2a2a;border-radius:6px;margin-bottom:4px;">
                    <div style="font-size:11px;color:#aaa;flex:1;">${g}</div>
                    <div style="font-size:11px;color:#2ecc71;">✅ ${c}</div>
                    <div style="font-size:11px;color:#e74c3c;">❌ ${e}</div>
                    <div style="font-size:12px;font-weight:700;color:${cor};">${p}%</div>
                </div>`;
            });

            const linhas=[...dados].reverse().slice(0,50).map(d=>`
                <tr style="border-bottom:1px solid #1a1a1a;">
                    <td style="padding:4px 6px;font-size:10px;color:#666;">${d.hora||'--'}</td>
                    <td style="padding:4px 6px;font-size:10px;color:#888;">${d.guiche||'?'}</td>
                    <td style="padding:4px 6px;font-size:12px;font-weight:700;color:#fff;">${d.senha}</td>
                    <td style="padding:4px 6px;font-size:11px;color:#888;">${d.recomendada||'--'}</td>
                    <td style="padding:4px 6px;">${d.foiRecomendada?'<span style="color:#2ecc71;font-size:14px;">✅</span>':'<span style="color:#e74c3c;font-size:14px;">❌</span>'}</td>
                </tr>`).join('');

            corpo.innerHTML = `
                <div style="display:flex;gap:8px;margin-bottom:12px;">
                    <div style="flex:1;background:#0a2a0a;border:1px solid #2ecc71;border-radius:8px;padding:8px;text-align:center;">
                        <div style="font-size:20px;font-weight:700;color:#2ecc71;">${corretas}</div>
                        <div style="font-size:9px;color:#2ecc71;">✅ Na ordem</div>
                    </div>
                    <div style="flex:1;background:#2c0a0a;border:1px solid #e74c3c;border-radius:8px;padding:8px;text-align:center;">
                        <div style="font-size:20px;font-weight:700;color:#e74c3c;">${erradas}</div>
                        <div style="font-size:9px;color:#e74c3c;">❌ Fora da ordem</div>
                    </div>
                    <div style="flex:1;background:#1a1a2a;border:1px solid #2d7dff;border-radius:8px;padding:8px;text-align:center;">
                        <div style="font-size:20px;font-weight:700;color:#2d7dff;">${pct}%</div>
                        <div style="font-size:9px;color:#2d7dff;">🎯 Acerto</div>
                    </div>
                </div>
                <div style="font-size:10px;color:#555;font-weight:700;margin-bottom:6px;">POR GUICHÊ:</div>
                ${resumo}
                <div style="font-size:10px;color:#555;font-weight:700;margin:10px 0 6px;">ÚLTIMAS 50 CHAMADAS:</div>
                <table style="width:100%;border-collapse:collapse;">
                    <thead><tr style="border-bottom:1px solid #333;">
                        <th style="text-align:left;padding:4px 6px;font-size:9px;color:#555;">Hora</th>
                        <th style="text-align:left;padding:4px 6px;font-size:9px;color:#555;">Guichê</th>
                        <th style="text-align:left;padding:4px 6px;font-size:9px;color:#555;">Chamou</th>
                        <th style="text-align:left;padding:4px 6px;font-size:9px;color:#555;">Recomend.</th>
                        <th style="text-align:left;padding:4px 6px;font-size:9px;color:#555;">OK?</th>
                    </tr></thead>
                    <tbody>${linhas}</tbody>
                </table>`;
        }

        document.getElementById('psb-rel-buscar').onclick = buscarEMostrar;
        buscarEMostrar();
    }

    // ── EVENTOS ───────────────────────────────────────────────────
    document.getElementById('psb-atualizar').onclick = lerSenhas;
    document.getElementById('psb-btn-config').onclick = () => verificarSenha(abrirConfig);
    document.getElementById('psb-btn-relatorio').onclick = () => verificarSenha(abrirRelatorio);

    // ── INICIAR ───────────────────────────────────────────────────
    lerSenhas();
    monitorarBotaoChamar();

    const intLer = setInterval(() => {
        if (!document.getElementById('painel-senhas-sabin')) { clearInterval(intLer); clearInterval(intTick); clearInterval(intChamada); return; }
        lerSenhas(); verificarChamada();
    }, 5000);
    const intTick = setInterval(() => {
        if (!document.getElementById('painel-senhas-sabin')) { clearInterval(intTick); return; }
        tick();
    }, 1000);
    const intChamada = setInterval(() => {
        if (!document.getElementById('painel-senhas-sabin')) { clearInterval(intChamada); return; }
        verificarChamada();
    }, 2000);

})();
