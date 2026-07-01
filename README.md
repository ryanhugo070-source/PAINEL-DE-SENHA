(() => {
    if (document.getElementById('painel-senhas-sabin')) return;

    const PRIORIDADE = {
        'A': { label: '80+ ALTA',     cor: '#e74c3c', corFundo: '#2c0a0a', tempo: 5,  icone: '🔴' },
        'P': { label: 'PREFERENCIAL', cor: '#e67e22', corFundo: '#2c1a0a', tempo: 10, icone: '🟠' },
        'G': { label: 'GERAL',        cor: '#95a5a6', corFundo: '#1a1a1a', tempo: 15, icone: '⚪' }
    };
    const TIPOS = { R:'Resultado', E:'Exames', P:'Pendência', A:'Agendamento', D:'Digital', V:'Vacina' };

    // Dados das senhas com base de tempo para o tick
    let baseDados = []; // [{senha, prioridade, tipo, segundosBase, timestampBase}]

    // ── PAINEL ───────────────────────────────────────────────────
    const painel = document.createElement('div');
    painel.id = 'painel-senhas-sabin';
    painel.style.cssText = `
        position:fixed; top:10px; right:10px; width:330px;
        background:#111; color:#fff; border-radius:12px;
        box-shadow:0 8px 32px rgba(0,0,0,.8); z-index:2147483647;
        font-family:'Segoe UI',Arial,sans-serif; border:1px solid #333; overflow:hidden;
    `;
    painel.innerHTML = `
        <div style="background:#1a1a1a;padding:10px 14px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid #333;">
            <span style="font-weight:700;font-size:14px;">📋 Painel de Senhas</span>
            <div style="display:flex;gap:6px;">
                <button id="psb-atualizar" style="background:#2d7dff;border:none;color:#fff;border-radius:6px;padding:3px 9px;cursor:pointer;font-size:12px;">↻</button>
                <button onclick="document.getElementById('painel-senhas-sabin').remove()" style="background:#444;border:none;color:#fff;border-radius:6px;padding:3px 7px;cursor:pointer;font-size:12px;">✕</button>
            </div>
        </div>
        <div style="padding:8px 10px;background:#161616;border-bottom:1px solid #2a2a2a;display:flex;gap:6px;" id="psb-contadores">
            <div style="flex:1;text-align:center;background:#2c0a0a;border:1px solid #e74c3c;border-radius:8px;padding:5px;">
                <div style="font-size:18px;font-weight:700;color:#e74c3c;" id="psb-num-A">0</div>
                <div style="font-size:9px;color:#e74c3c;">🔴 80+ALTA</div>
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
        <div id="psb-recomendada" style="display:none;padding:8px 10px;background:#0a1f0a;border-bottom:1px solid #2a2a2a;">
            <div style="font-size:9px;color:#2ecc71;font-weight:700;margin-bottom:3px;">✅ PRÓXIMA RECOMENDADA</div>
            <div id="psb-recom-corpo"></div>
        </div>
        <div id="psb-lista" style="max-height:400px;overflow-y:auto;padding:6px;"></div>
        <div style="padding:5px;text-align:center;font-size:9px;color:#444;border-top:1px solid #1a1a1a;">
            Leitura: <span id="psb-hora">--</span>
        </div>
    `;
    document.body.appendChild(painel);

    const style = document.createElement('style');
    style.innerHTML = `@keyframes psb-pisca{0%,100%{opacity:1}50%{opacity:.4}}`;
    document.head.appendChild(style);

    // ── FORMATAR TEMPO ───────────────────────────────────────────
    function fmt(seg) {
        seg = Math.max(0, Math.floor(seg));
        const h = Math.floor(seg/3600), m = Math.floor((seg%3600)/60), s = seg%60;
        return [h,m,s].map(n=>String(n).padStart(2,'0')).join(':');
    }

    // ── LER SENHAS DA TELA ───────────────────────────────────────
    function lerSenhas() {
        // 1. Identifica senhas em atendimento ATIVO
        // O card ativo tem "TEMPO DE ATENDIMENTO" — isso é único do card central roxo
        const emAtendimento = new Set();
        Array.from(document.querySelectorAll('div')).forEach(el => {
            if (el.closest('#painel-senhas-sabin')) return;
            const txt = el.innerText || '';
            if (!/TEMPO DE ATENDIMENTO/i.test(txt)) return;
            (txt.match(/[A-Z]{1,2}\d{3}/g) || []).forEach(s => emAtendimento.add(s));
        });

        const IGNORAR = /TEMPO DE ATENDIMENTO|Finalizado pelo|Concluída/i;

        // 2. Lê os cards da fila — pega o MENOR elemento que tem exatamente 1 senha + 1 tempo
        const vistos = new Set();
        const novas = [];

        // Ordena por tamanho do texto (menor primeiro = mais específico)
        const todos = Array.from(document.querySelectorAll('div,li'))
            .filter(el => {
                if (el.closest('#painel-senhas-sabin')) return false;
                const txt = el.innerText || '';
                return /[A-Z]{1,2}\d{3}/.test(txt) && /\d{2}:\d{2}:\d{2}/.test(txt);
            })
            .sort((a,b) => (a.innerText?.length||0) - (b.innerText?.length||0));

        todos.forEach(el => {
            const txt = el.innerText || '';
            if (IGNORAR.test(txt)) return;

            const senhasNoCard = new Set((txt.match(/[A-Z]{1,2}\d{3}/g)||[]));
            if (senhasNoCard.size !== 1) return;

            const codSenha = [...senhasNoCard][0];
            if (vistos.has(codSenha)) return;
            if (emAtendimento.has(codSenha)) return;

            const tempoMatch = txt.match(/(\d{2}:\d{2}:\d{2})/);
            if (!tempoMatch) return;

            vistos.add(codSenha);

            const partes = tempoMatch[1].split(':').map(Number);
            const segundos = partes[0]*3600 + partes[1]*60 + partes[2];

            // Identifica tipo e prioridade
            const prefixo = codSenha.replace(/\d/g,'');
            const priorLetra = prefixo.slice(-1);
            if (!['A','P','G'].includes(priorLetra)) return;
            const tipoLetra = prefixo.length > 1 ? prefixo[0] : prefixo;

            // Verifica se já tinha essa senha no baseDados para preservar o timestamp
            const anterior = baseDados.find(b => b.senha === codSenha);

            novas.push({
                senha:        codSenha,
                prioridade:   priorLetra,
                tipo:         TIPOS[tipoLetra] || tipoLetra,
                segundosBase: anterior ? anterior.segundosBase : segundos,
                timestampBase: anterior ? anterior.timestampBase : Date.now() - segundos * 1000
            });
        });

        // Ordena por % do limite
        novas.sort((a,b) => {
            const pctA = (((Date.now()-a.timestampBase)/1000) / (PRIORIDADE[a.prioridade].tempo*60)) * 100;
            const pctB = (((Date.now()-b.timestampBase)/1000) / (PRIORIDADE[b.prioridade].tempo*60)) * 100;
            return pctB - pctA;
        });

        baseDados = novas;

        // Contadores
        ['A','P','G'].forEach(p => {
            document.getElementById(`psb-num-${p}`).innerText = novas.filter(s=>s.prioridade===p).length;
        });

        // Monta lista
        const lista = document.getElementById('psb-lista');
        if (novas.length === 0) {
            lista.innerHTML = '<div style="text-align:center;color:#444;padding:16px;font-size:12px;">Nenhuma senha na fila</div>';
            document.getElementById('psb-recomendada').style.display = 'none';
        } else {
            document.getElementById('psb-recomendada').style.display = 'block';
            lista.innerHTML = novas.map((s, idx) => {
                const cfg = PRIORIDADE[s.prioridade];
                const segAtual = (Date.now() - s.timestampBase) / 1000;
                const pct = Math.min((segAtual / (cfg.tempo*60)) * 100, 999);
                const urgente = pct >= 80;
                return `
                <div id="psb-card-${idx}" style="display:flex;align-items:center;gap:8px;
                    background:${cfg.corFundo};border:1px solid ${cfg.cor}44;border-left:3px solid ${cfg.cor};
                    border-radius:8px;padding:7px 9px;margin-bottom:5px;
                    ${urgente ? `animation:psb-pisca 1s infinite;box-shadow:0 0 8px ${cfg.cor};` : ''}">
                    <div style="font-size:10px;color:#444;width:14px;">${idx+1}º</div>
                    <div style="font-size:16px;">${cfg.icone}</div>
                    <div style="flex:1;">
                        <div style="font-weight:700;font-size:14px;color:${cfg.cor};">${s.senha}</div>
                        <div style="font-size:10px;color:#666;">${s.tipo} · ${cfg.label}</div>
                    </div>
                    <div style="text-align:right;">
                        <div id="psb-tempo-${idx}" style="font-size:12px;color:${urgente?cfg.cor:'#aaa'};font-weight:${urgente?'700':'400'};">⏱ ${fmt(segAtual)}</div>
                        <div id="psb-pct-${idx}" style="font-size:10px;color:${pct>=100?'#e74c3c':pct>=80?'#e67e22':'#666'};font-weight:700;">${Math.round(pct)}%</div>
                    </div>
                </div>`;
            }).join('');

            // Recomendada
            const top = novas[0];
            const cfgTop = PRIORIDADE[top.prioridade];
            const segTop = (Date.now() - top.timestampBase) / 1000;
            const pctTop = Math.min((segTop / (cfgTop.tempo*60)) * 100, 999);
            document.getElementById('psb-recom-corpo').innerHTML = `
                <div style="display:flex;align-items:center;gap:8px;">
                    <div style="font-size:20px;">${cfgTop.icone}</div>
                    <div style="flex:1;">
                        <div style="font-weight:700;font-size:16px;color:#fff;">${top.senha}</div>
                        <div style="font-size:10px;color:#888;">${top.tipo} · ${cfgTop.label} · <span id="psb-recom-tempo">⏱ ${fmt(segTop)}</span></div>
                    </div>
                    <div style="text-align:right;">
                        <div id="psb-recom-pct" style="font-size:15px;font-weight:700;color:${pctTop>=100?'#e74c3c':'#2ecc71'};">${Math.round(pctTop)}%</div>
                        <div style="font-size:9px;color:#555;">do limite</div>
                    </div>
                </div>`;
        }

        document.getElementById('psb-hora').innerText = new Date().toLocaleTimeString('pt-BR');
    }

    // ── TICK: atualiza só os números, segundo a segundo ──────────
    function tick() {
        if (!document.getElementById('painel-senhas-sabin')) return;
        baseDados.forEach((s, idx) => {
            const cfg = PRIORIDADE[s.prioridade];
            const segAtual = (Date.now() - s.timestampBase) / 1000;
            const pct = Math.min((segAtual / (cfg.tempo*60)) * 100, 999);
            const elTempo = document.getElementById(`psb-tempo-${idx}`);
            const elPct   = document.getElementById(`psb-pct-${idx}`);
            if (elTempo) elTempo.innerText = '⏱ ' + fmt(segAtual);
            if (elPct) {
                elPct.innerText = Math.round(pct) + '%';
                elPct.style.color = pct>=100?'#e74c3c':pct>=80?'#e67e22':'#666';
            }
        });
        // Recomendada
        if (baseDados.length > 0) {
            const top = baseDados[0];
            const segTop = (Date.now() - top.timestampBase) / 1000;
            const pctTop = Math.min((segTop / (PRIORIDADE[top.prioridade].tempo*60)) * 100, 999);
            const elRT = document.getElementById('psb-recom-tempo');
            const elRP = document.getElementById('psb-recom-pct');
            if (elRT) elRT.innerText = '⏱ ' + fmt(segTop);
            if (elRP) {
                elRP.innerText = Math.round(pctTop) + '%';
                elRP.style.color = pctTop>=100?'#e74c3c':'#2ecc71';
            }
        }
    }

    document.getElementById('psb-atualizar').onclick = lerSenhas;

    lerSenhas();

    // Relê a tela a cada 5s (pega senhas novas / remove concluídas)
    const intLer = setInterval(() => {
        if (!document.getElementById('painel-senhas-sabin')) { clearInterval(intLer); clearInterval(intTick); return; }
        lerSenhas();
    }, 5000);

    // Atualiza os números na tela a cada 1s (cronômetro vivo)
    const intTick = setInterval(() => {
        if (!document.getElementById('painel-senhas-sabin')) { clearInterval(intTick); return; }
        tick();
    }, 1000);

})();
