(() => {
    if (document.getElementById('painel-senhas-sabin')) return;

    // ── CONFIGURAÇÃO DE PRIORIDADES ──────────────────────────────
    const PRIORIDADE = {
        'A': { label: '80+ ALTA', cor: '#e74c3c', corFundo: '#2c0a0a', tempo: 5,  icone: '🔴' },
        'P': { label: 'PREFERENCIAL', cor: '#e67e22', corFundo: '#2c1a0a', tempo: 10, icone: '🟠' },
        'G': { label: 'GERAL', cor: '#95a5a6', corFundo: '#1a1a1a', tempo: 15, icone: '⚪' }
    };

    // Guarda as senhas lidas + o momento exato da leitura, para contar segundo a segundo localmente
    let senhasAtuais = [];
    let momentoLeitura = Date.now();

    // ── PAINEL PRINCIPAL ─────────────────────────────────────────
    const painel = document.createElement('div');
    painel.id = 'painel-senhas-sabin';
    painel.style.cssText = `
        position: fixed; top: 10px; right: 10px; width: 340px;
        background: #111; color: #fff; border-radius: 12px;
        box-shadow: 0 8px 32px rgba(0,0,0,0.8); z-index: 2147483647;
        font-family: 'Segoe UI', Arial, sans-serif;
        border: 1px solid #333; overflow: hidden;
    `;

    painel.innerHTML = `
        <div style="background:#1a1a1a; padding:12px 16px; display:flex; align-items:center; justify-content:space-between; border-bottom:1px solid #333;">
            <div style="font-weight:700; font-size:15px; color:#fff;">📋 Painel de Senhas</div>
            <div style="display:flex; gap:8px; align-items:center;">
                <button id="btn-atualizar-painel" style="background:#2d7dff; border:none; color:#fff; border-radius:6px; padding:4px 10px; cursor:pointer; font-size:12px;">↻ Atualizar</button>
                <button onclick="document.getElementById('painel-senhas-sabin').remove()" style="background:#444; border:none; color:#fff; border-radius:6px; padding:4px 8px; cursor:pointer; font-size:12px;">✕</button>
            </div>
        </div>
        <div id="proxima-recomendada" style="padding:10px 12px; background:#0a1f0a; border-bottom:1px solid #2a2a2a; display:none;">
            <div style="font-size:10px; color:#2ecc71; font-weight:700; margin-bottom:4px;">✅ PRÓXIMA RECOMENDADA (fila justa)</div>
            <div id="conteudo-recomendada"></div>
        </div>
        <div style="padding:10px 12px; background:#161616; border-bottom:1px solid #2a2a2a; display:flex; gap:8px; flex-wrap:wrap;">
            <div id="contador-A" style="flex:1; text-align:center; background:#2c0a0a; border:1px solid #e74c3c; border-radius:8px; padding:6px;">
                <div style="font-size:20px; font-weight:700; color:#e74c3c;" id="num-A">0</div>
                <div style="font-size:10px; color:#e74c3c;">🔴 80+ ALTA</div>
            </div>
            <div id="contador-P" style="flex:1; text-align:center; background:#2c1a0a; border:1px solid #e67e22; border-radius:8px; padding:6px;">
                <div style="font-size:20px; font-weight:700; color:#e67e22;" id="num-P">0</div>
                <div style="font-size:10px; color:#e67e22;">🟠 PREFERENCIAL</div>
            </div>
            <div id="contador-G" style="flex:1; text-align:center; background:#1a1a1a; border:1px solid #555; border-radius:8px; padding:6px;">
                <div style="font-size:20px; font-weight:700; color:#aaa;" id="num-G">0</div>
                <div style="font-size:10px; color:#aaa;">⚪ GERAL</div>
            </div>
        </div>
        <div id="lista-senhas-painel" style="max-height:420px; overflow-y:auto; padding:8px;"></div>
        <div style="padding:8px 12px; text-align:center; font-size:10px; color:#555; border-top:1px solid #222;">
            Atualizado em: <span id="hora-atualizacao">--</span>
        </div>
    `;
    document.body.appendChild(painel);

    // ── FUNÇÃO PRINCIPAL ─────────────────────────────────────────
    function lerSenhas() {
        const lista = document.getElementById('lista-senhas-painel');
        lista.innerHTML = '<div style="text-align:center;color:#555;padding:20px;">Lendo senhas...</div>';

        // ── Estratégia robusta: acha o "card" que contém a senha inteira (senha + tempo) ──
        // Um card válido é o menor elemento cujo texto bate com o padrão completo:
        // CÓDIGO + (PRIORIDADE/NORMAL/etc) + HH:MM:SS — tudo junto, sem outra senha dentro.
        const REGEX_SENHA = /([A-Z]{1,2})(\d{3})/;       // ex: PP177, RA265, EG091
        const REGEX_TEMPO = /(\d{2}:\d{2}:\d{2})/;

        const candidatos = Array.from(document.querySelectorAll('div, li')).filter(el => {
            if (el.closest('#painel-senhas-sabin')) return false;
            // Ignora área de atendimento ativo (card central roxo/colorido com "Atendendo", "Chamando", "Finalizar" etc)
            const textoEl = el.innerText || '';
            if (!REGEX_SENHA.test(textoEl) || !REGEX_TEMPO.test(textoEl)) return false;
            // Ignora se o card contém palavras típicas de atendimento ativo ou histórico
            if (/Atendendo|Chamando|Finalizar|Transferir|Não Compareceu|Concluída|TEMPO DE ATENDIMENTO|Chamada às/i.test(textoEl)) return false;
            // Conta quantas senhas distintas aparecem no texto desse elemento
            const todasSenhas = new Set((textoEl.match(/[A-Z]{1,2}\d{3}/g) || []));
            return todasSenhas.size === 1;
        });

        // Entre os candidatos (que podem ser pai/filho um do outro), pega só o MENOR de cada grupo
        const senhasVistas = new Set();
        const senhas = [];

        // Ordena do menor texto pro maior, assim pegamos o card mais "específico" primeiro
        candidatos.sort((a, b) => (a.innerText?.length || 0) - (b.innerText?.length || 0));

        candidatos.forEach(el => {
            const txt = el.innerText || '';
            const matchSenha = txt.match(/([A-Z]{1,2})(\d{3})/);
            const matchTempo = txt.match(REGEX_TEMPO);
            if (!matchSenha || !matchTempo) return;

            const codigoCompleto = matchSenha[0]; // ex: PP177
            if (senhasVistas.has(codigoCompleto)) return;
            senhasVistas.add(codigoCompleto);

            const prefixo = matchSenha[1]; // 1 ou 2 letras antes do número
            // Identifica a letra de prioridade (a última letra do prefixo)
            const priorLetra = prefixo.slice(-1);
            const tipoLetra = prefixo.length > 1 ? prefixo.slice(0, -1) : prefixo;
            const tempoEspera = matchTempo[1];

            if (!['A', 'P', 'G'].includes(priorLetra)) return; // ignora se não reconhecer

            // Calcula % do tempo limite atingido (regra de urgência combinada)
            const partes = tempoEspera.split(':').map(Number);
            const segundosTotais = partes[0] * 3600 + partes[1] * 60 + partes[2];
            const minutos = segundosTotais / 60;
            const limite = PRIORIDADE[priorLetra]?.tempo || 15;
            const percentual = Math.min((minutos / limite) * 100, 999);
            const urgente = percentual >= 80;

            const TIPOS = { R: 'Resultado', E: 'Exames', P: 'Pendência', A: 'Agendamento', D: 'Digital', V: 'Vacina' };

            senhas.push({
                senha: codigoCompleto,
                tipo: TIPOS[tipoLetra] || tipoLetra,
                prioridade: priorLetra,
                tempo: tempoEspera,
                segundosTotais,
                minutos,
                percentual,
                urgente
            });
        });

        // Ordena por % do tempo limite atingido (regra de urgência combinada — fila justa)
        senhas.sort((a, b) => b.percentual - a.percentual);

        // Salva para o relógio local (segundo a segundo) usar como base
        senhasAtuais = senhas;
        momentoLeitura = Date.now();

        // Atualiza contadores
        ['A', 'P', 'G'].forEach(p => {
            document.getElementById(`num-${p}`).innerText = senhas.filter(s => s.prioridade === p).length;
        });

        // Mostra a recomendação no topo (maior % do tempo limite)
        const boxRecomendada = document.getElementById('proxima-recomendada');
        const conteudoRecomendada = document.getElementById('conteudo-recomendada');
        if (senhas.length > 0) {
            const top = senhas[0];
            const cfgTop = PRIORIDADE[top.prioridade];
            boxRecomendada.style.display = 'block';
            conteudoRecomendada.innerHTML = `
                <div style="display:flex; align-items:center; gap:10px;">
                    <div style="font-size:22px;">${cfgTop.icone}</div>
                    <div style="flex:1;">
                        <div style="font-weight:700; font-size:18px; color:#fff;">${top.senha}</div>
                        <div style="font-size:11px; color:#888;">${top.tipo} · ${cfgTop.label} · <span class="tempo-vivo-recom">⏱ ${top.tempo}</span></div>
                    </div>
                    <div style="text-align:right;">
                        <div class="pct-vivo-recom" style="font-size:16px; font-weight:700; color:${top.percentual >= 100 ? '#e74c3c' : '#2ecc71'};">${Math.round(top.percentual)}%</div>
                        <div style="font-size:9px; color:#666;">do limite</div>
                    </div>
                </div>
            `;
            boxRecomendada.dataset.senhaTop = top.senha;
        } else {
            boxRecomendada.style.display = 'none';
        }

        // Renderiza lista
        if (senhas.length === 0) {
            lista.innerHTML = '<div style="text-align:center;color:#555;padding:20px;font-size:13px;">Nenhuma senha encontrada na tela</div>';
        } else {
            lista.innerHTML = senhas.map((s, idx) => {
                const cfg = PRIORIDADE[s.prioridade];
                const bordaUrgente = s.urgente ? `box-shadow: 0 0 8px ${cfg.cor}; animation: pisca 1s infinite;` : '';
                const corPercentual = s.percentual >= 100 ? '#e74c3c' : (s.percentual >= 80 ? '#e67e22' : '#888');
                return `
                    <div data-card-senha="${s.senha}" style="
                        display:flex; align-items:center; gap:10px;
                        background:${cfg.corFundo}; border:1px solid ${cfg.cor}44;
                        border-left: 3px solid ${cfg.cor};
                        border-radius:8px; padding:8px 10px; margin-bottom:6px;
                        ${bordaUrgente}
                    ">
                        <div style="font-size:11px; color:#555; width:16px;">${idx + 1}º</div>
                        <div style="font-size:18px;">${cfg.icone}</div>
                        <div style="flex:1;">
                            <div style="font-weight:700; font-size:15px; color:${cfg.cor};">${s.senha}</div>
                            <div style="font-size:11px; color:#888;">${s.tipo} · ${cfg.label}</div>
                        </div>
                        <div style="text-align:right;">
                            <div class="tempo-vivo" data-senha="${s.senha}" style="font-size:13px; color:${s.urgente ? cfg.cor : '#aaa'}; font-weight:${s.urgente ? '700' : '400'};">⏱ ${s.tempo}</div>
                            <div class="pct-vivo" data-senha="${s.senha}" style="font-size:11px; color:${corPercentual}; font-weight:700;">${Math.round(s.percentual)}%</div>
                        </div>
                    </div>
                `;
            }).join('');
        }

        document.getElementById('hora-atualizacao').innerText = new Date().toLocaleTimeString('pt-BR');
    }

    // Animação de pisca
    const style = document.createElement('style');
    style.innerHTML = `@keyframes pisca { 0%,100%{opacity:1} 50%{opacity:0.5} }`;
    document.head.appendChild(style);

    // Formata segundos totais em HH:MM:SS
    function formatarTempo(segundosTotais) {
        const h = Math.floor(segundosTotais / 3600);
        const m = Math.floor((segundosTotais % 3600) / 60);
        const s = Math.floor(segundosTotais % 60);
        return [h, m, s].map(n => String(n).padStart(2, '0')).join(':');
    }

    // Roda a cada 1 segundo: soma o tempo decorrido desde a última leitura real da tela
    // e atualiza só os textos (sem reler o DOM do sistema, sem piscar a lista)
    function tick() {
        if (!document.getElementById('painel-senhas-sabin')) return;
        const decorridoSeg = (Date.now() - momentoLeitura) / 1000;

        const elsTempo = document.querySelectorAll('#painel-senhas-sabin .tempo-vivo');
        const elsPct = document.querySelectorAll('#painel-senhas-sabin .pct-vivo');

        senhasAtuais.forEach((s, idx) => {
            const segundosAgora = s.segundosTotais + decorridoSeg;
            const minutosAgora = segundosAgora / 60;
            const limite = PRIORIDADE[s.prioridade]?.tempo || 15;
            const percentualAgora = Math.min((minutosAgora / limite) * 100, 999);
            const tempoFormatado = formatarTempo(segundosAgora);

            const elTempo = elsTempo[idx];
            const elPct = elsPct[idx];
            if (elTempo) elTempo.innerText = '⏱ ' + tempoFormatado;
            if (elPct) {
                elPct.innerText = Math.round(percentualAgora) + '%';
                elPct.style.color = percentualAgora >= 100 ? '#e74c3c' : (percentualAgora >= 80 ? '#e67e22' : '#888');
            }
        });

        // Atualiza também o card "Próxima Recomendada" (sempre é a primeira da lista ordenada)
        const boxRecomendada = document.getElementById('proxima-recomendada');
        if (boxRecomendada && senhasAtuais.length > 0 && boxRecomendada.style.display !== 'none') {
            const top = senhasAtuais[0];
            const segundosAgora = top.segundosTotais + decorridoSeg;
            const minutosAgora = segundosAgora / 60;
            const limite = PRIORIDADE[top.prioridade]?.tempo || 15;
            const percentualAgora = Math.min((minutosAgora / limite) * 100, 999);
            const tempoFormatado = formatarTempo(segundosAgora);

            const elTempoRecom = boxRecomendada.querySelector('.tempo-vivo-recom');
            const elPctRecom = boxRecomendada.querySelector('.pct-vivo-recom');
            if (elTempoRecom) elTempoRecom.innerText = '⏱ ' + tempoFormatado;
            if (elPctRecom) {
                elPctRecom.innerText = Math.round(percentualAgora) + '%';
                elPctRecom.style.color = percentualAgora >= 100 ? '#e74c3c' : '#2ecc71';
            }
        }
    }

    // Atualiza ao clicar
    document.getElementById('btn-atualizar-painel').onclick = lerSenhas;

    // Lê a tela de verdade a cada 5 segundos (pega senhas novas, remove as que sumiram)
    lerSenhas();
    const intervaloLeitura = setInterval(() => {
        if (!document.getElementById('painel-senhas-sabin')) { clearInterval(intervaloLeitura); return; }
        lerSenhas();
    }, 5000);

    // Conta segundo a segundo por cima, sem reler a tela (cronômetro vivo)
    const intervaloTick = setInterval(() => {
        if (!document.getElementById('painel-senhas-sabin')) { clearInterval(intervaloTick); return; }
        tick();
    }, 1000);

})();
