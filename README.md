(() => {
    if (document.getElementById('painel-senhas-sabin')) return;

    // ── CONFIGURAÇÃO DE PRIORIDADES ──────────────────────────────
    const PRIORIDADE = {
        'A': { label: '80+ ALTA', cor: '#e74c3c', corFundo: '#2c0a0a', tempo: 5,  icone: '🔴' },
        'P': { label: 'PREFERENCIAL', cor: '#e67e22', corFundo: '#2c1a0a', tempo: 10, icone: '🟠' },
        'G': { label: 'GERAL', cor: '#95a5a6', corFundo: '#1a1a1a', tempo: 15, icone: '⚪' }
    };

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

        // Pega todos os elementos de senha na tela
        const elementos = Array.from(document.querySelectorAll('*')).filter(el => {
            if (el.children.length > 3) return false;
            const txt = el.innerText?.trim();
            return txt && /^[REPADV][APG]\d{3}/.test(txt);
        });

        // Monta lista de senhas únicas
        const senhasVistas = new Set();
        const senhas = [];

        elementos.forEach(el => {
            const txt = el.innerText?.trim();
            const match = txt?.match(/^([REPADV])([APG])(\d{3})/);
            if (!match || senhasVistas.has(txt)) return;
            senhasVistas.add(txt);

            const tipoLetra = match[1];
            const priorLetra = match[2];
            const numero = match[3];

            // Tenta pegar o tempo de espera
            const container = el.closest('[class]') || el.parentElement;
            const textoContainer = container?.innerText || '';
            const tempoMatch = textoContainer.match(/(\d{2}:\d{2}:\d{2})/);
            const tempoEspera = tempoMatch ? tempoMatch[1] : null;

            // Calcula se está próximo do limite
            let urgente = false;
            if (tempoEspera) {
                const partes = tempoEspera.split(':').map(Number);
                const minutos = partes[0] * 60 + partes[1];
                const limite = PRIORIDADE[priorLetra]?.tempo || 15;
                urgente = minutos >= (limite - 2);
            }

            const TIPOS = { R: 'Resultado', E: 'Exames', P: 'Pendência', A: 'Agendamento', D: 'Digital', V: 'Vacina' };

            senhas.push({
                senha: `${tipoLetra}${priorLetra}${numero}`,
                tipo: TIPOS[tipoLetra] || tipoLetra,
                prioridade: priorLetra,
                tempo: tempoEspera,
                urgente
            });
        });

        // Ordena: A primeiro, P segundo, G por último; dentro de cada grupo por tempo
        senhas.sort((a, b) => {
            const ordem = { A: 0, P: 1, G: 2 };
            if (ordem[a.prioridade] !== ordem[b.prioridade]) return ordem[a.prioridade] - ordem[b.prioridade];
            if (a.tempo && b.tempo) return b.tempo.localeCompare(a.tempo);
            return 0;
        });

        // Atualiza contadores
        ['A', 'P', 'G'].forEach(p => {
            document.getElementById(`num-${p}`).innerText = senhas.filter(s => s.prioridade === p).length;
        });

        // Renderiza lista
        if (senhas.length === 0) {
            lista.innerHTML = '<div style="text-align:center;color:#555;padding:20px;font-size:13px;">Nenhuma senha encontrada na tela</div>';
        } else {
            lista.innerHTML = senhas.map(s => {
                const cfg = PRIORIDADE[s.prioridade];
                const bordaUrgente = s.urgente ? `box-shadow: 0 0 8px ${cfg.cor}; animation: pisca 1s infinite;` : '';
                return `
                    <div style="
                        display:flex; align-items:center; gap:10px;
                        background:${cfg.corFundo}; border:1px solid ${cfg.cor}44;
                        border-left: 3px solid ${cfg.cor};
                        border-radius:8px; padding:8px 10px; margin-bottom:6px;
                        ${bordaUrgente}
                    ">
                        <div style="font-size:18px;">${cfg.icone}</div>
                        <div style="flex:1;">
                            <div style="font-weight:700; font-size:15px; color:${cfg.cor};">${s.senha}</div>
                            <div style="font-size:11px; color:#888;">${s.tipo} · ${cfg.label}</div>
                        </div>
                        <div style="text-align:right;">
                            ${s.tempo ? `<div style="font-size:13px; color:${s.urgente ? cfg.cor : '#aaa'}; font-weight:${s.urgente ? '700' : '400'};">⏱ ${s.tempo}</div>` : ''}
                            ${s.urgente ? `<div style="font-size:10px; color:${cfg.cor}; font-weight:700;">⚠️ URGENTE</div>` : ''}
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

    // Atualiza ao clicar
    document.getElementById('btn-atualizar-painel').onclick = lerSenhas;

    // Atualiza automaticamente a cada 30 segundos
    lerSenhas();
    const intervalo = setInterval(() => {
        if (!document.getElementById('painel-senhas-sabin')) { clearInterval(intervalo); return; }
        lerSenhas();
    }, 30000);

})();
