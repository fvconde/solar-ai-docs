(() => {
  const d = window.__s22RespostaMetricas;
  if (!d) throw new Error('Resposta HTTP de métricas ausente');
  const bloco = document.querySelector('.metricas');
  const principais = [...bloco.querySelectorAll('.principais > .cartao')];
  const extras = [...bloco.querySelectorAll('.grade-extras > .cartao')];
  const verificacoes = [];
  const igual = (campo, atual, esperado) => {
    if (JSON.stringify(atual) !== JSON.stringify(esperado)) throw new Error(campo + ': ' + JSON.stringify(atual) + ' != ' + JSON.stringify(esperado));
    verificacoes.push(campo);
  };
  const numeros = e => [...e.querySelectorAll('li strong.mono')].map(n => Number(n.textContent.trim()));
  const porcentagem = (valor, total) => total ? Math.round(valor / total * 100) + '%' : '—';
  igual('iniciadas', Number(principais[0].querySelector('.numero').textContent), d.conversasIniciadas);
  igual('confirmadas', Number(principais[1].querySelector('.numero').textContent), d.horariosConfirmados);
  igual('reservas7', principais[1].querySelectorAll('p')[1].textContent.trim().split(' ')[0], String(d.reservasProximos7Dias));
  igual('intencoes', numeros(principais[2]), Object.values(d.leadsPorIntencao));
  igual('equipePresente', !!bloco.querySelector('.equipe'), !!d.equipe);
  if (d.equipe) {
    const equipe = principais[3];
    igual('atribuicoes', numeros(equipe), d.equipe.atribuidasPorCorretor.map(a => a.conversas));
    igual('siglas', [...equipe.querySelectorAll('.carga li > span:last-child')].map(n => n.textContent.trim()), d.equipe.atribuidasPorCorretor.map(a => a.corretor.iniciais));
    igual('aguardando', equipe.querySelector('.aguardando').textContent.trim().split(' ')[0], String(d.equipe.aguardandoCorretor));
    igual('pendentes', equipe.querySelector('.pendentes').textContent.trim().split(' ')[0], String(d.equipe.pendentesAprovacao));
  }
  const s = d.extras.score, total = s.frio + s.morno + s.quente;
  igual('scoreFaixas', numeros(extras[0]), [s.frio,s.morno,s.quente]);
  igual('scoreTotal', Number(extras[0].querySelector('.donut strong').textContent), total);
  igual('scorePercentuais', [...extras[0].querySelectorAll('.legenda li > span.mono')].map(n => n.textContent.trim()), [s.frio,s.morno,s.quente].map(n => porcentagem(n,total)));
  igual('semAvaliacao', extras[0].querySelector('p').textContent.split('·')[1].trim().split(' ')[0], String(s.semAvaliacao));
  igual('imoveis', [...extras[1].querySelectorAll('li')].map(n => ({id:n.querySelector('.codigo').textContent.trim(),bairro:n.querySelector('.bairro').textContent.trim(),conversas:Number(n.querySelector('strong').textContent)})), d.extras.imoveis);
  igual('regioes', [...extras[2].querySelectorAll('li')].map(n => ({regiao:n.firstElementChild.textContent.trim(),leads:Number(n.querySelector('strong').textContent)})), d.extras.regioes.top);
  igual('coberturaRegioes', extras[2].querySelector('p:last-child').textContent.match(/\d+/g).map(Number), [d.extras.regioes.informaram,d.extras.regioes.leads,d.extras.regioes.outras]);
  igual('proximosHorarios', [...extras[3].querySelectorAll('li')].map(n => ({inicio:n.querySelector('time').getAttribute('datetime'),iniciais:n.lastElementChild.textContent.trim()})), d.extras.proximosHorarios);
  const v=d.extras.privacidade;
  igual('consentimentoPercentual', extras[4].querySelector('.numero').textContent.trim(), porcentagem(v.comConsentimento,v.leads));
  igual('consentimentoContagem', extras[4].querySelector('p').textContent.match(/\d+/g).map(Number), [v.comConsentimento,v.leads]);
  igual('vencimentoContagem', Number(extras[4].querySelector('p strong.mono').textContent), v.vencem30Dias);
  igual('retencaoConfigurada', Number(extras[4].querySelector('p strong.mono').parentElement.textContent.match(/\d+/)[0]), v.prazoRetencaoMeses);
  const texto=bloco.innerText;
  igual('PIILeadAusente', /Titular Canario Privado S22|11976543210|titular-canario-s22@tests.solar.local|Transcricao confidencial canario S22/.test(texto), false);
  igual('NomesCorretoresSoAria', /Helena Braga|Rafael Nunes/.test(texto), false);
  igual('NumerosValidos', /NaN|Infinity/.test(bloco.innerHTML), false);
  const r=bloco.getBoundingClientRect(), f=document.querySelector('.corpo-painel').getBoundingClientRect();
  const rolaveis=[bloco,bloco.querySelector('.miolo'),bloco.querySelector('.extras')].filter(e => ['auto','scroll'].includes(getComputedStyle(e).overflowY) && e.scrollHeight > e.clientHeight+1).map(e => e.className);
  return JSON.stringify({perfil:d.equipe?'supervisor':'corretor',atualizadoEm:d.periodo.atualizadoEm,viewport:[innerWidth,innerHeight],tema:document.documentElement.dataset.tema ?? (matchMedia('(prefers-color-scheme: dark)').matches?'escuro':'claro'),faixa:{altura:r.height,percentual:r.height/innerHeight*100,top:r.top},fila:{altura:f.height,top:f.top,visivel:f.height>0 && f.top<innerHeight},rolaveis,botaoAltura:bloco.querySelector('.alternar').getBoundingClientRect().height,cards:principais.map(e=>e.getBoundingClientRect().width),verificacoes:verificacoes.length,campos:verificacoes});
})()
