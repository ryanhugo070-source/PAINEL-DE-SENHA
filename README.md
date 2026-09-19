(() => {
    if (document.getElementById('painel-senhas-sabin')) return;

    // ── SENHA DE ACESSO ──────────────────────────────────────────
    const SENHA_ADMIN = '1234'; // Altere aqui

    // ── TIPOS E PRIORIDADES ──────────────────────────────────────
    const TIPOS_LABEL = { R:'Resultado', E:'Exames', P:'Pendência', A:'Agendamento', D:'Digital', V:'Vacina' };
    const PRIOR_LABEL = { A:'80+ Alta', P:'Preferencial', G:'Geral' };
    const TIPOS = ['R','E','P','A','D','V'];
    const PRIORS = ['A','P','G'];

    // ── TEMPOS PADRÃO (minutos) por combinação tipo+prioridade ───
    const TEMPOS_PADRAO = {};
    TIPOS.forEach(t => {
        TEMPOS_PADRAO[t+'A'] = 5;
        TEMPOS_PADRAO[t+'P'] = 10;
        TEMPOS_PADRAO[t+'G'] = 15;
    });

    function carregarTempos() {
        try {
            const s = localStorage.getItem('psb_tempos');
            return s ? {...TEMPOS_PADRAO, ...JSON.parse(s)} : {...TEMPOS_PADRAO};
        } catch { return {...TEMPOS_PADRAO}; }
    }
    function salvarTempos(t) {
        try { localStorage.setItem('psb_tempos', JSON.stringify(t)); } catch {}
    }

    let TEMPOS = carregarTempos();

    // ── HISTÓRICO DE CHAMADAS ────────────────────────────────────
    function carregarHistorico() {
        try { return JSON.parse(localStorage.getItem('psb_historico') || '[]'); } catch { return []; }
    }
    function salvarHistorico(h) {
        try { localStorage.setItem('psb_historico', JSON.stringify(h.slice(-500))); } catch {} // max 500
    }
    let historico = carregarHistorico();
    let ultimaRecomendada = null;
    let baseDados = [];

    // ── FORMATAR TEMPO ───────────────────────────────────────────
    function fmt(seg) {
        seg = Math.max(0, Math.floor(seg));
        const h = Math.floor(seg/3600), m = Math.floor((seg%3600)/60), s = seg%60;
        return [h,m,s].map(n=>String(n).padStart(2,'0')).join(':');
    }

    // ── VERIFICAR SENHA ──────────────────────────────────────────
    function verificarSenha(callback) {
        const modal = document.createElement('div');
        modal.style.cssText = `position:fixed;inset:0;background:rgba(0,0,0,.85);z-index:2147483648;display:flex;align-items:center;justify-content:center;font-family:'Segoe UI',Arial,sans-serif;`;
        modal.innerHTML = `
            <div style="background:#1e1e1e;border:2px solid #2d7dff;border-radius:12px;padding:24px;width:280px;text-align:center;">
                <div style="font-size:24px;margin-bottom:8px;">🔐</div>
                <div style="font-weight:700;color:#fff;margin-bottom:16px;">Digite a senha de acesso</div>
                <input id="psb-senha-input" type="password" placeholder="Senha..." style="width:100%;padding:10px;border-radius:8px;border:1px solid #444;background:#2a2a2a;color:#fff;font-size:16px;text-align:center;box-sizing:border-box;margin-bottom:12px;">
                <div style="display:flex;gap:8px;">
                    <button id="psb-senha-cancel" style="flex:1;padding:10px;background:#444;color:#fff;border:none;border-radius:8px;cursor:pointer;">Cancelar</button>
                    <button id="psb-senha-ok" style="flex:1;padding:10px;background:#2d7dff;color:#fff;border:none;border-radius:8px;cursor:pointer;font-weight:700;">Entrar</button>
                </div>
                <div id="psb-senha-erro" style="color:#e74c3c;font-size:12px;margin-top:8px;display:none;">Senha incorreta!</div>
            </div>`;
        document.body.appendChild(modal);
        const inp = modal.querySelector('#psb-senha-input');
        inp.focus();
        modal.querySelector('#psb-senha-cancel').onclick = () => modal.remove();
        const tentar = () => {
            if (inp.value === SENHA_ADMIN) { modal.remove(); callback(); }
            else { modal.querySelector('#psb-senha-erro').style.display='block'; inp.value=''; inp.focus(); }
        };
        modal.querySelector('#psb-senha-ok').onclick = tentar;
        inp.addEventListener('keydown', e => { if(e.key==='Enter') tentar(); });
    }

    // ── PAINEL PRINCIPAL ─────────────────────────────────────────
    const painel = document.createElement('div');
    painel.id = 'painel-senhas-sabin';
    painel.style.cssText = `position:fixed;top:10px;right:10px;width:340px;background:#111;color:#fff;border-radius:12px;box-shadow:0 8px 32px rgba(0,0,0,.8);z-index:2147483647;font-family:'Segoe UI',Arial,sans-serif;border:1px solid #333;overflow:hidden;`;

    painel.innerHTML = `
        <div style="background:#1a1a1a;padding:10px 14px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid #333;">
            <span style="font-weight:700;font-size:14px;">📋 Painel de Senhas</span>
            <div style="display:flex;gap:5px;">
                <button id="psb-btn-config" title="Configurações" style="background:#333;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;font-size:13px;">⚙️</button>
                <button id="psb-btn-relatorio" title="Relatório" style="background:#333;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;font-size:13px;">📊</button>
                <button id="psb-atualizar" title="Atualizar" style="background:#2d7dff;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;font-size:13px;">↻</button>
                <button onclick="document.getElementById('painel-senhas-sabin').remove()" style="background:#444;border:none;color:#fff;border-radius:6px;padding:3px 7px;cursor:pointer;font-size:13px;">✕</button>
            </div>
        </div>
        <div style="padding:8px 10px;background:#161616;border-bottom:1px solid #2a2a2a;display:flex;gap:6px;">
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
        <div id="psb-recomendada" style="display:none;padding:8px 10px;background:#0a1f0a;border-bottom:1px solid #1a3a1a;">
            <div style="font-size:9px;color:#2ecc71;font-weight:700;margin-bottom:3px;">✅ PRÓXIMA RECOMENDADA (fila justa)</div>
            <div id="psb-recom-corpo"></div>
        </div>
        <div id="psb-lista" style="max-height:380px;overflow-y:auto;padding:6px;"></div>
        <div style="padding:5px;text-align:center;font-size:9px;color:#444;border-top:1px solid #1a1a1a;">
            Leitura: <span id="psb-hora">--</span>
        </div>`;
    document.body.appendChild(painel);

    const style = document.createElement('style');
    style.innerHTML = `@keyframes psb-pisca{0%,100%{opacity:1}50%{opacity:.4}} #psb-lista::-webkit-scrollbar{width:4px} #psb-lista::-webkit-scrollbar-thumb{background:#333;border-radius:2px}`;
    document.head.appendChild(style);

    // ── LER SENHAS DA TELA ───────────────────────────────────────
    function lerSenhas() {
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
            const txt = (el.innerText || '').trim();
            if (txt.length < 10 || txt.length > 150) return;
            if (!/[A-Z]{1,2}\d{3}/.test(txt)) return;
            if (!/\d{2}:\d{2}:\d{2}/.test(txt)) return;
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
                senha: codSenha,
                prioridade: priorLetra,
                tipo: tipoLetra,
                chave,
                label: (TIPOS_LABEL[tipoLetra]||tipoLetra) + ' · ' + (PRIOR_LABEL[priorLetra]||priorLetra),
                limiteMin,
                segundosBase: anterior ? anterior.segundosBase : segundos,
                timestampBase: anterior ? anterior.timestampBase : Date.now() - segundos*1000
            });
        });

        // Cor por prioridade
        const COR = { A:'#e74c3c', P:'#e67e22', G:'#95a5a6' };
        const FUNDO = { A:'#2c0a0a', P:'#2c1a0a', G:'#1a1a1a' };
        const ICONE = { A:'🔴', P:'🟠', G:'⚪' };

        // Ordena por % do limite
        novas.sort((a,b) => {
            const pctA = ((Date.now()-a.timestampBase)/1000) / (a.limiteMin*60) * 100;
            const pctB = ((Date.now()-b.timestampBase)/1000) / (b.limiteMin*60) * 100;
            return pctB - pctA;
        });

        baseDados = novas;
        ultimaRecomendada = novas.length > 0 ? novas[0].senha : null;

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
                const cor = COR[s.prioridade], fundo = FUNDO[s.prioridade], icone = ICONE[s.prioridade];
                const segAtual = (Date.now()-s.timestampBase)/1000;
                const pct = Math.min((segAtual/(s.limiteMin*60))*100, 999);
                const urgente = pct >= 80;
                return `<div id="psb-card-${idx}" style="display:flex;align-items:center;gap:8px;background:${fundo};border:1px solid ${cor}44;border-left:3px solid ${cor};border-radius:8px;padding:7px 9px;margin-bottom:5px;${urgente?`animation:psb-pisca 1s infinite;box-shadow:0 0 8px ${cor};`:''}">
                    <div style="font-size:10px;color:#444;width:14px;">${idx+1}º</div>
                    <div style="font-size:15px;">${icone}</div>
                    <div style="flex:1;">
                        <div style="font-weight:700;font-size:14px;color:${cor};">${s.senha}</div>
                        <div style="font-size:10px;color:#666;">${s.label}</div>
                    </div>
                    <div style="text-align:right;">
                        <div id="psb-tempo-${idx}" style="font-size:12px;color:${urgente?cor:'#aaa'};font-weight:${urgente?'700':'400'};">⏱ ${fmt(segAtual)}</div>
                        <div id="psb-pct-${idx}" style="font-size:10px;color:${pct>=100?'#e74c3c':pct>=80?'#e67e22':'#666'};font-weight:700;">${Math.round(pct)}% / ${s.limiteMin}min</div>
                    </div>
                </div>`;
            }).join('');

            // Recomendada
            const top = novas[0];
            const cor = COR[top.prioridade];
            const segTop = (Date.now()-top.timestampBase)/1000;
            const pctTop = Math.min((segTop/(top.limiteMin*60))*100,999);
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

    // ── TICK SEGUNDO A SEGUNDO ───────────────────────────────────
    function tick() {
        if (!document.getElementById('painel-senhas-sabin')) return;
        const COR = { A:'#e74c3c', P:'#e67e22', G:'#95a5a6' };
        baseDados.forEach((s, idx) => {
            const segAtual = (Date.now()-s.timestampBase)/1000;
            const pct = Math.min((segAtual/(s.limiteMin*60))*100,999);
            const elT = document.getElementById(`psb-tempo-${idx}`);
            const elP = document.getElementById(`psb-pct-${idx}`);
            if (elT) elT.innerText = '⏱ ' + fmt(segAtual);
            if (elP) { elP.innerText = Math.round(pct)+'% / '+s.limiteMin+'min'; elP.style.color = pct>=100?'#e74c3c':pct>=80?'#e67e22':'#666'; }
        });
        if (baseDados.length > 0) {
            const top = baseDados[0];
            const segTop = (Date.now()-top.timestampBase)/1000;
            const pctTop = Math.min((segTop/(top.limiteMin*60))*100,999);
            const elRT = document.getElementById('psb-recom-tempo');
            const elRP = document.getElementById('psb-recom-pct');
            if (elRT) elRT.innerText = '⏱ ' + fmt(segTop);
            if (elRP) { elRP.innerText = Math.round(pctTop)+'%'; elRP.style.color = pctTop>=100?'#e74c3c':'#2ecc71'; }
        }
    }

    // ── REGISTRAR CHAMADA ────────────────────────────────────────
    // Detecta quando uma nova senha é chamada e registra se foi a recomendada ou não
    let ultimaSenhaAtendimento = null;
    function verificarChamada() {
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
            const foiRecomendada = senhaAtual === ultimaRecomendada;
            historico.push({
                senha: senhaAtual,
                recomendada: ultimaRecomendada,
                foiRecomendada,
                hora: new Date().toLocaleString('pt-BR')
            });
            salvarHistorico(historico);
        }
    }

    // ── ABA CONFIGURAÇÕES ────────────────────────────────────────
    function abrirConfig() {
        TEMPOS = carregarTempos();
        const modal = document.createElement('div');
        modal.id = 'psb-modal-config';
        modal.style.cssText = `position:fixed;inset:0;background:rgba(0,0,0,.9);z-index:2147483648;display:flex;align-items:center;justify-content:center;font-family:'Segoe UI',Arial,sans-serif;`;

        let linhas = '';
        TIPOS.forEach(t => {
            PRIORS.forEach(p => {
                const chave = t+p;
                const val = TEMPOS[chave] || 15;
                const corP = p==='A'?'#e74c3c':p==='P'?'#e67e22':'#aaa';
                linhas += `<tr>
                    <td style="padding:6px 8px;color:#ccc;font-size:12px;">${TIPOS_LABEL[t]||t}</td>
                    <td style="padding:6px 8px;color:${corP};font-size:12px;font-weight:700;">${PRIOR_LABEL[p]}</td>
                    <td style="padding:6px 8px;">
                        <input type="number" id="psb-cfg-${chave}" value="${val}" min="1" max="120"
                            style="width:60px;padding:4px 6px;border-radius:6px;border:1px solid #444;background:#2a2a2a;color:#fff;font-size:13px;text-align:center;">
                        <span style="color:#666;font-size:11px;"> min</span>
                    </td>
                </tr>`;
            });
        });

        modal.innerHTML = `
            <div style="background:#1a1a1a;border:2px solid #2d7dff;border-radius:12px;padding:20px;width:360px;max-height:85vh;overflow-y:auto;">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;">
                    <span style="font-size:16px;font-weight:700;color:#fff;">⚙️ Configurar Tempos</span>
                    <button onclick="document.getElementById('psb-modal-config').remove()" style="background:#444;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;">✕</button>
                </div>
                <div style="font-size:11px;color:#666;margin-bottom:12px;">Defina o tempo limite (minutos) para cada combinação de serviço + prioridade:</div>
                <table style="width:100%;border-collapse:collapse;">
                    <thead><tr>
                        <th style="text-align:left;padding:6px 8px;font-size:11px;color:#555;border-bottom:1px solid #333;">Serviço</th>
                        <th style="text-align:left;padding:6px 8px;font-size:11px;color:#555;border-bottom:1px solid #333;">Prioridade</th>
                        <th style="text-align:left;padding:6px 8px;font-size:11px;color:#555;border-bottom:1px solid #333;">Tempo</th>
                    </tr></thead>
                    <tbody>${linhas}</tbody>
                </table>
                <div style="display:flex;gap:8px;margin-top:16px;">
                    <button id="psb-cfg-restaurar" style="flex:1;padding:10px;background:#333;color:#aaa;border:none;border-radius:8px;cursor:pointer;font-size:12px;">Restaurar padrão</button>
                    <button id="psb-cfg-salvar" style="flex:1;padding:10px;background:#2d7dff;color:#fff;border:none;border-radius:8px;cursor:pointer;font-weight:700;">💾 Salvar</button>
                </div>
                <div id="psb-cfg-ok" style="display:none;text-align:center;color:#2ecc71;font-size:12px;margin-top:8px;">✅ Salvo com sucesso!</div>
            </div>`;
        document.body.appendChild(modal);

        document.getElementById('psb-cfg-salvar').onclick = () => {
            const novos = {};
            TIPOS.forEach(t => PRIORS.forEach(p => {
                const chave = t+p;
                const v = parseInt(document.getElementById(`psb-cfg-${chave}`)?.value) || 15;
                novos[chave] = v;
            }));
            TEMPOS = novos;
            salvarTempos(novos);
            document.getElementById('psb-cfg-ok').style.display = 'block';
            setTimeout(() => { document.getElementById('psb-cfg-ok').style.display='none'; }, 2000);
            lerSenhas();
        };

        document.getElementById('psb-cfg-restaurar').onclick = () => {
            TIPOS.forEach(t => PRIORS.forEach(p => {
                const chave = t+p;
                const el = document.getElementById(`psb-cfg-${chave}`);
                if (el) el.value = TEMPOS_PADRAO[chave];
            }));
        };
    }

    // ── ABA RELATÓRIO ────────────────────────────────────────────
    function abrirRelatorio() {
        historico = carregarHistorico();
        const modal = document.createElement('div');
        modal.id = 'psb-modal-relatorio';
        modal.style.cssText = `position:fixed;inset:0;background:rgba(0,0,0,.9);z-index:2147483648;display:flex;align-items:center;justify-content:center;font-family:'Segoe UI',Arial,sans-serif;`;

        const total = historico.length;
        const corretas = historico.filter(h=>h.foiRecomendada).length;
        const erradas = total - corretas;
        const pctAcerto = total > 0 ? Math.round((corretas/total)*100) : 0;

        // Últimas 20 chamadas
        const ultimas = [...historico].reverse().slice(0,20);
        const linhas = ultimas.map(h => `
            <tr style="border-bottom:1px solid #222;">
                <td style="padding:5px 8px;font-size:11px;color:#ccc;">${h.hora}</td>
                <td style="padding:5px 8px;font-size:12px;font-weight:700;color:#fff;">${h.senha}</td>
                <td style="padding:5px 8px;font-size:11px;color:#888;">${h.recomendada||'--'}</td>
                <td style="padding:5px 8px;font-size:12px;">${h.foiRecomendada ? '<span style="color:#2ecc71;font-weight:700;">✅ Sim</span>' : '<span style="color:#e74c3c;font-weight:700;">❌ Não</span>'}</td>
            </tr>`).join('');

        modal.innerHTML = `
            <div style="background:#1a1a1a;border:2px solid #2d7dff;border-radius:12px;padding:20px;width:420px;max-height:85vh;overflow-y:auto;">
                <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;">
                    <span style="font-size:16px;font-weight:700;color:#fff;">📊 Relatório de Chamadas</span>
                    <div style="display:flex;gap:6px;">
                        <button id="psb-rel-limpar" style="background:#8B0000;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;font-size:11px;">🗑 Limpar</button>
                        <button onclick="document.getElementById('psb-modal-relatorio').remove()" style="background:#444;border:none;color:#fff;border-radius:6px;padding:3px 8px;cursor:pointer;">✕</button>
                    </div>
                </div>
                <div style="display:flex;gap:8px;margin-bottom:14px;">
                    <div style="flex:1;background:#0a2a0a;border:1px solid #2ecc71;border-radius:8px;padding:10px;text-align:center;">
                        <div style="font-size:22px;font-weight:700;color:#2ecc71;">${corretas}</div>
                        <div style="font-size:10px;color:#2ecc71;">✅ Na ordem</div>
                    </div>
                    <div style="flex:1;background:#2c0a0a;border:1px solid #e74c3c;border-radius:8px;padding:10px;text-align:center;">
                        <div style="font-size:22px;font-weight:700;color:#e74c3c;">${erradas}</div>
                        <div style="font-size:10px;color:#e74c3c;">❌ Fora da ordem</div>
                    </div>
                    <div style="flex:1;background:#1a1a2a;border:1px solid #2d7dff;border-radius:8px;padding:10px;text-align:center;">
                        <div style="font-size:22px;font-weight:700;color:#2d7dff;">${pctAcerto}%</div>
                        <div style="font-size:10px;color:#2d7dff;">🎯 Acerto</div>
                    </div>
                </div>
                <div style="font-size:11px;color:#555;margin-bottom:8px;">Últimas 20 chamadas:</div>
                <table style="width:100%;border-collapse:collapse;">
                    <thead><tr style="border-bottom:1px solid #333;">
                        <th style="text-align:left;padding:5px 8px;font-size:10px;color:#555;">Hora</th>
                        <th style="text-align:left;padding:5px 8px;font-size:10px;color:#555;">Chamou</th>
                        <th style="text-align:left;padding:5px 8px;font-size:10px;color:#555;">Recomendada</th>
                        <th style="text-align:left;padding:5px 8px;font-size:10px;color:#555;">Correto?</th>
                    </tr></thead>
                    <tbody>${linhas || '<tr><td colspan="4" style="text-align:center;color:#444;padding:16px;">Nenhum registro ainda</td></tr>'}</tbody>
                </table>
            </div>`;
        document.body.appendChild(modal);

        document.getElementById('psb-rel-limpar').onclick = () => {
            if (confirm('Limpar todo o histórico?')) {
                historico = [];
                salvarHistorico([]);
                modal.remove();
            }
        };
    }

    // ── EVENTOS ───────────────────────────────────────────────────
    document.getElementById('psb-atualizar').onclick = lerSenhas;
    document.getElementById('psb-btn-config').onclick = () => verificarSenha(abrirConfig);
    document.getElementById('psb-btn-relatorio').onclick = () => verificarSenha(abrirRelatorio);

    // ── INICIAR ───────────────────────────────────────────────────
    lerSenhas();

    const intLer = setInterval(() => {
        if (!document.getElementById('painel-senhas-sabin')) { clearInterval(intLer); clearInterval(intTick); clearInterval(intChamada); return; }
        lerSenhas();
        verificarChamada();
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
