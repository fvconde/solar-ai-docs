(() => {
  if (window.__s22Observador) return "observador existente";
  window.__s22Observador = true;
  const abrir = XMLHttpRequest.prototype.open;
  const enviar = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (metodo, url, ...resto) {
    this.__s22Metrica = String(url).includes("/api/painel/metricas");
    if (this.__s22Metrica) this.addEventListener("load", () => {
      if (this.status === 200) {
        try { window.__s22RespostaMetricas = JSON.parse(this.responseText); } catch {}
      }
    });
    return abrir.call(this, metodo, url, ...resto);
  };
  XMLHttpRequest.prototype.send = function (...args) {
    if (this.__s22Metrica && window.__s22Modo === "erro") {
      setTimeout(() => this.dispatchEvent(new ProgressEvent("error")), 50);
      return;
    }
    if (this.__s22Metrica && window.__s22Modo === "carregando") {
      setTimeout(() => enviar.apply(this, args), 4000);
      return;
    }
    return enviar.apply(this, args);
  };
  const buscar = window.fetch.bind(window);
  window.fetch = async function (...args) {
    const url = String(args[0]?.url ?? args[0]);
    const metrica = url.includes("/api/painel/metricas");
    if (metrica && window.__s22Modo === "erro") throw new TypeError("falha de rede sintetica S22");
    if (metrica && window.__s22Modo === "carregando") await new Promise(resolve => setTimeout(resolve, 4000));
    const resposta = await buscar(...args);
    if (metrica && resposta.ok) {
      try { window.__s22RespostaMetricas = await resposta.clone().json(); } catch {}
    }
    return resposta;
  };
  return "observador instalado somente em metricas; modo normal";
})()
