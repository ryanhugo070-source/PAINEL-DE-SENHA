javascript:(function(){
    if (window.psbLerInterval) clearInterval(window.psbLerInterval);
    if (window.psbTickInterval) clearInterval(window.psbTickInterval);
    if (window.psbIntervals && Array.isArray(window.psbIntervals)) {
        window.psbIntervals.forEach(clearInterval);
    }
    window.psbIntervals = [];

    const antigo = document.getElementById('painel-senhas-sabin-v2');
    if (antigo) antigo.remove();

    const hojeStr = new Date().toLocaleDateString('pt-BR');
    if (localStorage.getItem('psb_data_hist') !== hojeStr) {
        localStorage.setItem('psb_data_hist', hojeStr);
        localStorage.setItem('psb_historico_hoje', JSON.stringify([]));
    }

    const PRIORIDADE = {
        'A': { label: '80+ ALTA', cor: '#ef4444', icone: '🔴', bg: 'rgba(239, 68, 68, 0.15)', border: '#f87171' },
        'P': { label: 'PREFER.', cor: '#f97316', icone: '🟠', bg: 'rgba(249, 115, 22, 0.15)', border: '#fb923c' },
        'G': { label: 'GERAL', cor: '#38bdf8', icone: '🔵', bg: 'rgba(56, 189, 248, 0.15)', border: '#38bdf8' }
    };

    const NOMES_TIPOS = { 'P': 'Pendência', 'V': 'Vacina', 'R': 'Resultado', 'E': 'Exames', 'A': 'Agendamento', 'D': 'Digital' };
    const NOMES_PRIORIDADE = { 'G': 'Geral', 'P': 'Preferencial', 'A': '80+' };

    let SLAS = JSON.parse(localStorage.getItem('psb_slas_config')) || {
        'P_G': 12, 'P_P': 12, 'P_A': 12, 'V_G': 12, 'V_P': 12, 'V_A': 12,
        'R_G': 12, 'R_P': 12, 'R_A': 12, 'E_G': 20, 'E_P': 20, 'E_A': 20,
        'A_G': 15, 'A_P': 15, 'A_A': 15, 'D_G': 12, 'D_P': 12, 'D_A': 12
    };

    let baseDados = [];
    let ultimaAssinatura = '';
    let senhasNotificadasSLA = new Set();
    let somAtivo = true;

    function tocarSomAlerta() {
        if (!somAtivo) return;
        try {
            const AudioContext = window.AudioContext || window.webkitAudioContext;
            if (!AudioContext) return;
            const ctx = new AudioContext();
            const osc = ctx.createOscillator();
            const gain = ctx.createGain();
            osc.type = 'triangle';
            osc.frequency.setValueAtTime(880, ctx.currentTime);
            osc.frequency.exponentialRampToValueAtTime(440, ctx.currentTime + 0.3);
            gain.gain.setValueAtTime(0.2, ctx.currentTime);
            gain.gain.exponentialRampToValueAtTime(0.01, ctx.currentTime + 0.3);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start();
            osc.stop(ctx.currentTime + 0.3);
        } catch (e) {}
    }

    const painel = document.createElement('div');
    painel.id = 'painel-senhas-sabin-v2';
    painel.style.cssText = "position:fixed;top:14px;right:14px;width:360px;min-width:280px;max-width:90vw;background:rgba(18, 18, 22, 0.95);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px);color:#f4f4f5;border-radius:16px;box-shadow:0 20px 50px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.08);z-index:2147483647;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;overflow:hidden;resize:both;";

    painel.innerHTML = `
        <style>
            #painel-senhas-sabin-v2 ::-webkit-scrollbar { width: 5px; }
            #painel-senhas-sabin-v2 ::-webkit-scrollbar-track { background: transparent; }
            #painel-senhas-sabin-v2 ::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.15); border-radius: 10px; }
            .psb-btn-top { background: rgba(255,255,255,0.05); border: 1px solid rgba(255,255,255,0.08); color: #d4d4d8; border-radius: 8px; width: 28px; height: 28px; cursor: pointer; font-size: 12px; display: flex; align-items: center; justify-content: center; transition: all 0.2s ease; }
            .psb-btn-top:hover { background: rgba(255,255,255,0.15); color: #fff; }
            .psb-card-item { transition: all 0.2s ease; }
            .psb-card-item:hover { background: rgba(39, 39, 42, 0.8) !important; transform: translateX(2px); }
            @keyframes psb-alerta-piscar {
                0% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.6); border-color: rgba(239, 68, 68, 0.9); }
                50% { box-shadow: 0 0 12px 3px rgba(239, 68, 68, 0.4); border-color: rgba(239, 68, 68, 0.4); }
                100% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.6); border-color: rgba(239, 68, 68, 0.9); }
            }
            .psb-card-critico { animation: psb-alerta-piscar 1.2s infinite !important; background: rgba(127, 29, 29, 0.25) !important; }
        </style>

        <div style="background:rgba(255,255,255,0.03);padding:12px 16px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid rgba(255,255,255,0.06);user-select:none;">
            <div style="display:flex;align-items:center;gap:8px;">
                <span style="font-size:16px;">📊</span>
                <span style="font-weight:700;font-size:13px;letter-spacing:0.5px;color:#f4f4f5;text-transform:uppercase;">Painel Sabin</span>
            </div>
            <div style="display:flex;gap:5px;">
                <button id="psb-relatorio" class="psb-btn-top" title="Relatório do Dia">📈</button>
                <button id="psb-som" class="psb-btn-top" title="Som">🔊</button>
                <button id="psb-config" class="psb-btn-top" title="Configurações">⚙️</button>
                <button id="psb-atualizar" class="psb-btn-top" title="Atualizar">↻</button>
                <button id="psb-minimizar" class="psb-btn-top" title="Minimizar">➖</button>
                <button id="psb-fechar" class="psb-btn-top" style="background:rgba(239,68,68,0.15);color:#ef4444;" title="Fechar">✕</button>
            </div>
        </div>

        <div id="psb-corpo-painel">
            <div id="psb-banner-critico" style="display:none;background:#ef4444;color:#fff;font-weight:800;font-size:11px;text-align:center;padding:6px;letter-spacing:0.5px;text-transform:uppercase;">
                ⚠️ SENHA EM ESTADO CRÍTICO EXCEDIDA!
            </div>

            <div id="psb-menu-relatorio" style="display:none;padding:14px;background:rgba(24, 24, 27, 0.98);border-bottom:1px solid rgba(255,255,255,0.08);font-size:11px;">
                <div style="font-weight:800;font-size:12px;color:#a7f3d0;margin-bottom:10px;display:flex;align-items:center;justify-content:space-between;">
                    <span>📈 Relatório de Atendimento Hoje</span>
                    <button id="psb-fechar-relatorio" style="background:none;border:none;color:#a1a1aa;cursor:pointer;">✕</button>
                </div>
                <div id="psb-corpo-relatorio"></div>
            </div>

            <div id="psb-menu-config" style="display:none;padding:14px;background:rgba(24, 24, 27, 0.95);border-bottom:1px solid rgba(255,255,255,0.08);font-size:11px;">
                <div style="font-weight:700;margin-bottom:10px;color:#60a5fa;">⚙️ Limites SLA por Prioridade (min):</div>
                <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;max-height:180px;overflow-y:auto;" id="psb-inputs-config"></div>
                <button id="psb-salvar-config" style="margin-top:12px;width:100%;background:#22c55e;border:none;color:#fff;padding:8px;border-radius:8px;font-weight:700;cursor:pointer;">Salvar Alterações</button>
            </div>

            <div style="padding:12px 14px;background:rgba(0,0,0,0.2);border-bottom:1px solid rgba(255,255,255,0.05);display:flex;gap:8px;">
                <div style="flex:1;text-align:center;background:rgba(239, 68, 68, 0.08);border:1px solid rgba(239, 68, 68, 0.25);border-radius:10px;padding:8px 0;">
                    <div style="font-size:20px;font-weight:800;color:#f87171;line-height:1;" id="psb-num-A">0</div>
                    <div style="font-size:9px;font-weight:700;color:#fca5a5;margin-top:4px;">🔴 80+ ALTA</div>
                </div>
                <div style="flex:1;text-align:center;background:rgba(249, 115, 22, 0.08);border:1px solid rgba(249, 115, 22, 0.25);border-radius:10px;padding:8px 0;">
                    <div style="font-size:20px;font-weight:800;color:#fb923c;line-height:1;" id="psb-num-P">0</div>
                    <div style="font-size:9px;font-weight:700;color:#fdba74;margin-top:4px;">🟠 PREFER.</div>
                </div>
                <div style="flex:1;text-align:center;background:rgba(56, 189, 248, 0.08);border:1px solid rgba(56, 189, 248, 0.25);border-radius:10px;padding:8px 0;">
                    <div style="font-size:20px;font-weight:800;color:#38bdf8;line-height:1;" id="psb-num-G">0</div>
                    <div style="font-size:9px;font-weight:700;color:#7dd3fc;margin-top:4px;">🔵 GERAL</div>
                </div>
            </div>

            <div id="psb-recomendada" style="display:none;padding:12px 14px;background:linear-gradient(135deg, rgba(34, 197, 94, 0.12), rgba(20, 83, 45, 0.25));border-bottom:1px solid rgba(34, 197, 94, 0.2);">
                <div style="font-size:10px;color:#4ade80;font-weight:800;letter-spacing:0.8px;margin-bottom:8px;display:flex;align-items:center;gap:5px;">
                    <span style="display:inline-block;width:6px;height:6px;background:#4ade80;border-radius:50%;box-shadow:0 0 8px #4ade80;"></span>
                    PRÓXIMA SENHA RECOMENDADA
                </div>
                <div id="psb-recom-corpo"></div>
            </div>

            <div id="psb-lista" style="max-height:300px;overflow-y:auto;padding:12px 14px;display:flex;flex-direction:column;gap:8px;"></div>
            
            <div style="padding:8px 14px;text-align:center;font-size:10px;color:#a1a1aa;background:rgba(0,0,0,0.3);border-top:1px solid rgba(255,255,255,0.05);display:flex;justify-content:space-between;align-items:center;">
                <span>Sabin Auto-Sync</span>
                <span>Última busca: <strong id="psb-hora" style="color:#d4d4d8;">--</strong></span>
            </div>
        </div>
    `;

    document.body.appendChild(painel);

    function fmt(seg) {
        seg = Math.max(0, Math.floor(seg));
        const h = Math.floor(seg / 3600);
        const m = Math.floor((seg % 3600) / 60);
        const s = seg % 60;
        return [h, m, s].map(n => String(n).padStart(2, '0')).join(':');
    }

    function registrarChamadas(novas) {
        if (!window.psbUltimaBase || window.psbUltimaBase.length === 0) {
            window.psbUltimaBase = novas;
            return;
        }

        const atuaSet = new Set(novas.map(s => s.senha));
        const recomAnterior = window.psbUltimaBase[0]?.senha;
        let hist = JSON.parse(localStorage.getItem('psb_historico_hoje')) || [];

        window.psbUltimaBase.forEach(ant => {
            if (!atuaSet.has(ant.senha)) {
                const tempoEspera = (Date.now() - ant.timestampBase) / 1000;
                const foiCorreta = (ant.senha === recomAnterior);
                
                hist.push({
                    senha: ant.senha,
                    prio: ant.prioridade,
                    tipo: ant.tipoLabel,
                    esperaSeg: tempoEspera,
                    chamadaCorreta: foiCorreta,
                    hora: new Date().toLocaleTimeString('pt-BR')
                });
            }
        });

        localStorage.setItem('psb_historico_hoje', JSON.stringify(hist));
        window.psbUltimaBase = novas;
    }

    document.getElementById('psb-relatorio').onclick = () => {
        const password = prompt('Digite a senha para acessar o Relatório:');
        if (password === '160405') {
            exibirRelatorio();
        } else if (password !== null) {
            alert('Senha incorreta!');
        }
    };

    function exibirRelatorio() {
        const menuRel = document.getElementById('psb-menu-relatorio');
        const corpoRel = document.getElementById('psb-corpo-relatorio');
        const hist = JSON.parse(localStorage.getItem('psb_historico_hoje')) || [];

        menuRel.style.display = 'block';

        if (hist.length === 0) {
            corpoRel.innerHTML = '<div style="color:#a1a1aa;text-align:center;padding:12px 0;">Nenhum atendimento finalizado registrado hoje ainda.</div>';
            return;
        }

        let maisDemorada = hist.reduce((max, item) => item.esperaSeg > max.esperaSeg ? item : max, hist[0]);
        let corretas = hist.filter(h => h.chamadaCorreta).length;
        let pctCorretas = Math.round((corretas / hist.length) * 100);

        corpoRel.innerHTML = `
            <div style="display:flex;flex-direction:column;gap:8px;">
                <div style="background:rgba(239,68,68,0.12);border:1px solid rgba(239,68,68,0.3);padding:8px 10px;border-radius:8px;">
                    <div style="color:#fca5a5;font-size:9px;font-weight:700;text-transform:uppercase;">⏱️ Maior Tempo de Espera do Dia</div>
                    <div style="display:flex;justify-content:space-between;align-items:center;margin-top:2px;">
                        <span style="font-weight:800;font-size:14px;color:#fff;">${maisDemorada.senha} (${maisDemorada.tipo})</span>
                        <span style="font-weight:800;font-size:13px;color:#f87171;">${fmt(maisDemorada.esperaSeg)}</span>
                    </div>
                </div>

                <div style="background:rgba(34,197,94,0.12);border:1px solid rgba(34,197,94,0.3);padding:8px 10px;border-radius:8px;">
                    <div style="color:#86efac;font-size:9px;font-weight:700;text-transform:uppercase;">🎯 Conformidade das Chamadas (Recomendadas)</div>
                    <div style="display:flex;justify-content:space-between;align-items:center;margin-top:2px;">
                        <span style="font-weight:800;font-size:14px;color:#fff;">${corretas} de ${hist.length} corretas</span>
                        <span style="font-weight:800;font-size:15px;color:${pctCorretas >= 80 ? '#4ade80' : '#f97316'};">${pctCorretas}%</span>
                    </div>
                </div>

                <div style="max-height:120px;overflow-y:auto;background:rgba(0,0,0,0.3);padding:6px;border-radius:6px;border:1px solid rgba(255,255,255,0.05);margin-top:4px;">
                    <div style="font-size:9px;color:#71717a;margin-bottom:4px;font-weight:700;">ÚLTIMAS CHAMADAS DO DIA:</div>
                    ${hist.slice(-10).reverse().map(h => `
                        <div style="display:flex;justify-content:space-between;align-items:center;font-size:10px;padding:3px 0;border-bottom:1px solid rgba(255,255,255,0.04);">
                            <span>${h.hora} - <strong>${h.senha}</strong></span>
                            <span>⏱️ ${fmt(h.esperaSeg)}${h.chamadaCorreta ? '✅' : '❌ Outra'}</span>
                        </div>
                    `).join('')}
                </div>
            </div>
        `;
    }

    document.getElementById('psb-fechar-relatorio').onclick = () => {
        document.getElementById('psb-menu-relatorio').style.display = 'none';
    };

    document.getElementById('psb-som').onclick = () => {
        somAtivo = !somAtivo;
        const btn = document.getElementById('psb-som');
        btn.innerText = somAtivo ? '🔊' : '🔇';
        btn.style.opacity = somAtivo ? '1' : '0.5';
        if (somAtivo) tocarSomAlerta();
    };

    let estaminimizado = false;
    document.getElementById('psb-minimizar').onclick = () => {
        const corpo = document.getElementById('psb-corpo-painel');
        const btn = document.getElementById('psb-minimizar');
        if (estaminimizado) {
            corpo.style.display = 'block';
            btn.innerText = '➖';
            estaminimizado = false;
        } else {
            corpo.style.display = 'none';
            btn.innerText = '🗖';
            estaminimizado = true;
        }
    };

    function renderInputsConfig() {
        const container = document.getElementById('psb-inputs-config');
        let html = '';
        Object.keys(NOMES_TIPOS).forEach(t => {
            Object.keys(NOMES_PRIORIDADE).forEach(p => {
                const key = `${t}_${p}`;
                const label = `${NOMES_TIPOS[t]} ${NOMES_PRIORIDADE[p]}`;
                const val = SLAS[key] || 12;
                html += `
                    <div style="display:flex;justify-content:space-between;align-items:center;background:rgba(255,255,255,0.04);padding:4px 6px;border-radius:6px;">
                        <span style="color:#a1a1aa;font-size:9px;" title="${label}">${label}:</span>
                        <input type="number" id="psb-cfg-${key}" value="${val}" style="width:34px;background:#09090b;border:1px solid rgba(255,255,255,0.15);color:#fff;border-radius:4px;text-align:center;font-size:9px;">
                    </div>
                `;
            });
        });
        container.innerHTML = html;
    }

    document.getElementById('psb-config').onclick = () => {
        const menu = document.getElementById('psb-menu-config');
        if (menu.style.display === 'block') {
            menu.style.display = 'none';
            return;
        }
        const senha = prompt('Digite a senha para acessar as configurações:');
        if (senha === '160405') {
            menu.style.display = 'block';
            renderInputsConfig();
        } else if (senha !== null) {
            alert('Senha incorreta!');
        }
    };

    document.getElementById('psb-salvar-config').onclick = () => {
        Object.keys(NOMES_TIPOS).forEach(t => {
            Object.keys(NOMES_PRIORIDADE).forEach(p => {
                const key = `${t}_${p}`;
                const input = document.getElementById(`psb-cfg-${key}`);
                if (input) SLAS[key] = parseInt(input.value) || 12;
            });
        });
        localStorage.setItem('psb_slas_config', JSON.stringify(SLAS));
        document.getElementById('psb-menu-config').style.display = 'none';
        lerSenhas(true);
    };

    function lerSenhas(forcarRedesenho = false) {
        const emAtend = new Set();
        Array.from(document.querySelectorAll('div')).forEach(el => {
            if (el.closest('#painel-senhas-sabin-v2')) return;
            const txt = el.innerText || '';
            if (txt.length > 500) return;
            if (!/TEMPO DE ATENDIMENTO/i.test(txt)) return;
            (txt.match(/[A-Z]{1,2}\d{3}/g) || []).forEach(s => emAtend.add(s));
        });

        const IGN = /TEMPO DE ATENDIMENTO|Finalizado pelo|Concluída|Histórico/i;
        const vistos = new Set();
        const novas = [];

        Array.from(document.querySelectorAll('div,li')).forEach(el => {
            if (el.closest('#painel-senhas-sabin-v2')) return;
            const txt = (el.innerText || '').trim();
            if (txt.length < 10 || txt.length > 150 || !/[A-Z]{1,2}\d{3}/.test(txt) || !/\d{2}:\d{2}:\d{2}/.test(txt) || IGN.test(txt)) return;

            const senhas = new Set(txt.match(/[A-Z]{1,2}\d{3}/g) || []);
            if (senhas.size !== 1) return;

            const cod = [...senhas][0];
            if (vistos.has(cod) || emAtend.has(cod)) return;

            const tm = txt.match(/(\d{2}:\d{2}:\d{2})/);
            if (!tm) return;

            vistos.add(cod);

            const p = tm[1].split(':').map(Number);
            const seg = p[0] * 3600 + p[1] * 60 + p[2];

            const pref = cod.replace(/\d/g, '');
            const prio = pref.slice(-1);
            if (!['A', 'P', 'G'].includes(prio)) return;

            const tLetra = pref.length > 1 ? pref[0] : pref;
            const tipoNome = NOMES_TIPOS[tLetra] || tLetra;
            const chaveSLA = `${tLetra}_${prio}`;
            const tempoSLA = SLAS[chaveSLA] || 12;

            const ant = baseDados.find(b => b.senha === cod);

            novas.push({
                senha: cod,
                prioridade: prio,
                tipoLabel: tipoNome,
                tempoLimiteMin: tempoSLA,
                timestampBase: ant ? ant.timestampBase : Date.now() - seg * 1000
            });
        });

        novas.sort((a, b) => (((Date.now() - b.timestampBase) / 1000) / (b.tempoLimiteMin * 60)) * 100 - (((Date.now() - a.timestampBase) / 1000) / (a.tempoLimiteMin * 60)) * 100);

        registrarChamadas(novas);
        baseDados = novas;

        ['A', 'P', 'G'].forEach(p => {
            const el = document.getElementById('psb-num-' + p);
            if (el) el.innerText = novas.filter(s => s.prioridade === p).length;
        });

        renderLista(forcarRedesenho);
        
        const hEl = document.getElementById('psb-hora');
        if (hEl) hEl.innerText = new Date().toLocaleTimeString('pt-BR');
    }

    function renderLista(forcar = false) {
        const listaEl = document.getElementById('psb-lista');
        const recomEl = document.getElementById('psb-recomendada');

        const assinaturaAtual = baseDados.map(s => s.senha).join('|');

        if (!forcar && assinaturaAtual === ultimaAssinatura && baseDados.length > 0) {
            tick();
            return;
        }

        ultimaAssinatura = assinaturaAtual;

        if (baseDados.length > 0) {
            recomEl.style.display = 'block';
            const top = baseDados[0];
            const cfg = PRIORIDADE[top.prioridade];
            const seg = (Date.now() - top.timestampBase) / 1000;
            const pct = Math.min((seg / (top.tempoLimiteMin * 60)) * 100, 999);
            const rb = document.getElementById('psb-recom-corpo');

            if (rb) {
                rb.innerHTML = `
                    <div style="display:flex;align-items:center;gap:12px;">
                        <div style="font-size:26px;">${cfg.icone}</div>
                        <div style="flex:1;">
                            <div style="font-weight:800;font-size:20px;color:#fff;line-height:1;">${top.senha}</div>
                            <div style="font-size:10px;color:#a1a1aa;margin-top:4px;">${top.tipoLabel} • ${cfg.label} • <span id="psb-recom-tempo" style="font-weight:700;color:#e4e4e7;">⏱ ${fmt(seg)}</span></div>
                        </div>
                        <div style="text-align:right;">
                            <div id="psb-recom-pct" style="font-size:18px;font-weight:800;color:${pct >= 100 ? '#ef4444' : '#4ade80'};">${Math.round(pct)}%</div>
                            <div style="font-size:9px;color:#a1a1aa;text-transform:uppercase;">do limite</div>
                        </div>
                    </div>
                `;
            }
        } else {
            recomEl.style.display = 'none';
        }

        if (baseDados.length === 0) {
            listaEl.innerHTML = '<div style="text-align:center;color:#71717a;padding:24px 0;font-size:12px;">Nenhuma senha aguardando na fila.</div>';
            return;
        }

        listaEl.innerHTML = baseDados.map((s, i) => {
            const cfg = PRIORIDADE[s.prioridade];
            const seg = (Date.now() - s.timestampBase) / 1000;
            const pct = Math.min((seg / (s.tempoLimiteMin * 60)) * 100, 999);
            const urg = pct >= 100;

            return `
                <div data-senha="${s.senha}" class="psb-card-item ${urg ? 'psb-card-critico' : ''}" style="display:flex;align-items:center;gap:10px;background:rgba(30, 30, 35, 0.6);border:1px solid ${urg ? 'rgba(239, 68, 68, 0.8)' : 'rgba(255, 255, 255, 0.06)'};border-left:4px solid ${cfg.cor};border-radius:10px;padding:8px 12px;">
                    <div style="font-size:11px;font-weight:700;color:#71717a;width:14px;">${i + 1}º</div>
                    <div style="flex:1;">
                        <div style="font-weight:800;font-size:14px;color:#fff;line-height:1;display:flex;align-items:center;gap:6px;">
                            ${s.senha}
                            <span style="font-size:9px;padding:2px 6px;border-radius:4px;background:${cfg.bg};color:${cfg.border};border:1px solid ${cfg.border}40;font-weight:700;">${cfg.label}</span>
                        </div>
                        <div style="font-size:10px;color:#a1a1aa;margin-top:4px;">${s.tipoLabel}</div>
                    </div>
                    <div style="text-align:right;">
                        <div class="psb-tempo-val" style="font-size:12px;color:${urg ? '#f87171' : '#d4d4d8'};font-weight:700;">⏱ ${fmt(seg)}</div>
                        <div class="psb-pct-val" style="font-size:11px;color:${pct >= 100 ? '#ef4444' : pct >= 80 ? '#fb923c' : '#a1a1aa'};font-weight:800;margin-top:2px;">${Math.round(pct)}%</div>
                    </div>
                </div>
            `;
        }).join('');
    }

    function tick() {
        if (!document.getElementById('painel-senhas-sabin-v2')) return;

        let existeCritica = false;

        document.querySelectorAll('#psb-lista [data-senha]').forEach(card => {
            const cod = card.getAttribute('data-senha');
            const s = baseDados.find(item => item.senha === cod);
            if (!s) return;

            const seg = (Date.now() - s.timestampBase) / 1000;
            const pct = Math.min((seg / (s.tempoLimiteMin * 60)) * 100, 999);
            const urg = pct >= 100;

            if (urg) {
                existeCritica = true;
                if (!senhasNotificadasSLA.has(cod)) {
                    senhasNotificadasSLA.add(cod);
                    tocarSomAlerta();
                }
            }

            const eT = card.querySelector('.psb-tempo-val');
            const eP = card.querySelector('.psb-pct-val');

            if (eT) {
                eT.innerText = '⏱ ' + fmt(seg);
                eT.style.color = urg ? '#f87171' : '#d4d4d8';
            }
            if (eP) {
                eP.innerText = Math.round(pct) + '%';
                eP.style.color = pct >= 100 ? '#ef4444' : pct >= 80 ? '#fb923c' : '#a1a1aa';
            }

            if (urg) card.classList.add('psb-card-critico');
            else card.classList.remove('psb-card-critico');
        });

        const banner = document.getElementById('psb-banner-critico');
        if (banner) banner.style.display = existeCritica ? 'block' : 'none';

        if (baseDados.length > 0) {
            const top = baseDados[0];
            const seg = (Date.now() - top.timestampBase) / 1000;
            const pct = Math.min((seg / (top.tempoLimiteMin * 60)) * 100, 999);

            const eRT = document.getElementById('psb-recom-tempo');
            const eRP = document.getElementById('psb-recom-pct');

            if (eRT) eRT.innerText = '⏱ ' + fmt(seg);
            if (eRP) {
                eRP.innerText = Math.round(pct) + '%';
                eRP.style.color = pct >= 100 ? '#ef4444' : '#4ade80';
            }
        }
    }

    document.getElementById('psb-atualizar').onclick = () => { lerSenhas(true); tick(); };
    
    document.getElementById('psb-fechar').onclick = () => {
        clearInterval(window.psbLerInterval);
        clearInterval(window.psbTickInterval);
        document.getElementById('painel-senhas-sabin-v2').remove();
    };

    lerSenhas(true);
    tick();

    window.psbLerInterval = setInterval(() => {
        if (document.getElementById('painel-senhas-sabin-v2')) lerSenhas();
    }, 5000);

    window.psbTickInterval = setInterval(() => {
        if (document.getElementById('painel-senhas-sabin-v2')) tick();
    }, 1000);

})();
