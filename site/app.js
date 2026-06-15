// nt-deploy landing — i18n (en/it/de/es) + copy-to-clipboard + toast
const I18N = {
  en: {
    "nav.features": "Features", "nav.tm": "Time Machine", "nav.install": "Install",
    "hero.badge": "v2.0 · open source · zero dependencies",
    "hero.h1a": "Ship your site in", "hero.h1b": "one command",
    "hero.lede": "Deploy to Cloudflare Pages, <b>instant rollback</b>, PageSpeed audits, a light GUI and a complete dev toolkit. All from your terminal — featherweight.",
    "hero.gh": "View on GitHub",
    "stats.cmds": "commands", "stats.dep": "dependency (wrangler)", "stats.ram": "idle RAM", "stats.rb": "local rollbacks",
    "feat.h2": "A Swiss army knife for the web",
    "feat.deploy.t": "Deploy in one command", "feat.deploy.d": "Static folder or automatic build (npm/pnpm/yarn/bun). One branch per client, a URL ready to share.",
    "feat.tm.t": "Time Machine", "feat.tm.d": "Every deploy is archived locally. <b>Real rollback</b> to a previous version — something wrangler alone cannot do.",
    "feat.audit.t": "PageSpeed audit", "feat.audit.d": "Pre-test with a real score (Google Lighthouse engine): Performance, SEO, Accessibility and Core Web Vitals.",
    "feat.gui.t": "Featherweight GUI", "feat.gui.d": "A browser panel at <code>nt.local</code> to manage clients, projects, snapshots and settings. No Electron — pure stdlib.",
    "feat.traffic.t": "Traffic &amp; visits", "feat.traffic.d": "Enable Web Analytics with one command and read your site's visit stats.",
    "feat.toolkit.t": "Offline toolkit", "feat.toolkit.d": "Local server, scaffold, size report, zip, QR codes, health-check, client notes. Useful even without Cloudflare.",
    "who.h2": "What it's for &amp; who it's for",
    "who.lead": "nt-deploy turns \"I need to put this website online\" into a single command — then gives you everything around it: per-client preview URLs, performance audits before launch, traffic stats, and a safety net that lets you undo a bad deploy in seconds.",
    "who.free.t": "Freelancers &amp; agencies", "who.free.d": "Deliver each client a clean preview URL (<code>client.you.pages.dev</code>), send the link, and roll back instantly if they want the previous version. Keep per-client notes too.",
    "who.dev.t": "Web developers", "who.dev.d": "Skip the dashboard. Build and deploy from the terminal, audit Core Web Vitals before going live, tail logs and check health — without leaving your shell.",
    "who.indie.t": "Indie hackers &amp; makers", "who.indie.d": "Ship landing pages, prototypes and side projects in seconds. Scaffold a starter, serve it locally, deploy, get a QR to test on your phone, and watch the traffic.",
    "who.team.t": "Small teams", "who.team.d": "One consistent deploy workflow for everyone, with local snapshots as a safety net and confirmations before anything destructive (production overwrite, delete).",
    "kill.badge": "★ kill feature", "kill.h2": "Rollback wrangler doesn't have",
    "kill.p": "Cloudflare offers no CLI rollback for Pages. nt-deploy archives every push locally and lets you <b>restore any version</b> in seconds.",
    "kill.l1": "the deploy history", "kill.l2": "back to the previous one", "kill.l3": "to an exact version",
    "install.h2": "Install in 10 seconds", "install.lede": "Only needs Node (for wrangler). The script auto-updates.",
    "install.s1": "login + project", "install.s2": "build, deploy, done", "install.s3": "every command",
    "foot.dim": "deploy · rollback · audit · gui — open source",
  },
  it: {
    "nav.features": "Funzioni", "nav.tm": "Time Machine", "nav.install": "Installa",
    "hero.badge": "v2.0 · open source · zero dipendenze",
    "hero.h1a": "Pubblica il tuo sito in", "hero.h1b": "un comando",
    "hero.lede": "Deploy su Cloudflare Pages, <b>rollback istantaneo</b>, audit PageSpeed, una GUI leggera e un toolkit dev completo. Tutto dal terminale — leggerissimo.",
    "hero.gh": "Vedi su GitHub",
    "stats.cmds": "comandi", "stats.dep": "dipendenza (wrangler)", "stats.ram": "RAM a riposo", "stats.rb": "rollback locali",
    "feat.h2": "Un coltellino svizzero per il web",
    "feat.deploy.t": "Deploy in un comando", "feat.deploy.d": "Cartella statica o build automatica (npm/pnpm/yarn/bun). Un branch per cliente, un URL pronto da condividere.",
    "feat.tm.t": "Time Machine", "feat.tm.d": "Ogni deploy viene archiviato in locale. <b>Rollback vero</b> a una versione precedente — cosa che wrangler da solo non sa fare.",
    "feat.audit.t": "Audit PageSpeed", "feat.audit.d": "Pre-test con punteggio reale (motore Google Lighthouse): Performance, SEO, Accessibilità e Core Web Vitals.",
    "feat.gui.t": "GUI leggerissima", "feat.gui.d": "Un pannello nel browser su <code>nt.local</code> per gestire clienti, progetti, snapshot e impostazioni. Niente Electron — solo stdlib.",
    "feat.traffic.t": "Traffico e visite", "feat.traffic.d": "Attiva Web Analytics con un comando e guarda le statistiche di visite del sito.",
    "feat.toolkit.t": "Toolkit offline", "feat.toolkit.d": "Server locale, scaffold, report dimensioni, zip, QR code, health-check, appunti cliente. Utile anche senza Cloudflare.",
    "who.h2": "Per cosa serve e per chi è utile",
    "who.lead": "nt-deploy trasforma \"devo mettere online questo sito\" in un solo comando — e ti dà tutto intorno: URL di anteprima per ogni cliente, audit delle performance prima del lancio, statistiche di traffico e una rete di sicurezza per annullare un deploy sbagliato in pochi secondi.",
    "who.free.t": "Freelance e agenzie", "who.free.d": "Consegna a ogni cliente un URL di anteprima pulito (<code>cliente.tu.pages.dev</code>), invia il link e torna indietro all'istante se vuole la versione precedente. Tieni anche gli appunti per cliente.",
    "who.dev.t": "Sviluppatori web", "who.dev.d": "Salta il dashboard. Build e deploy dal terminale, audit dei Core Web Vitals prima del lancio, log in tempo reale e health-check — senza uscire dalla shell.",
    "who.indie.t": "Indie hacker e maker", "who.indie.d": "Pubblica landing page, prototipi e side project in pochi secondi. Crea uno starter, servilo in locale, fai deploy, ottieni un QR per provarlo sul telefono e guarda il traffico.",
    "who.team.t": "Piccoli team", "who.team.d": "Un unico flusso di deploy coerente per tutti, con snapshot locali come rete di sicurezza e conferme prima di qualunque azione distruttiva (sovrascrittura produzione, eliminazione).",
    "kill.badge": "★ kill feature", "kill.h2": "Il rollback che wrangler non ha",
    "kill.p": "Cloudflare non offre rollback da CLI per Pages. nt-deploy archivia ogni push in locale e ti permette di <b>ripristinare qualunque versione</b> in pochi secondi.",
    "kill.l1": "lo storico dei deploy", "kill.l2": "torni al precedente", "kill.l3": "a una versione precisa",
    "install.h2": "Installa in 10 secondi", "install.lede": "Serve solo Node (per wrangler). Lo script si auto-aggiorna.",
    "install.s1": "login + progetto", "install.s2": "build, deploy e via", "install.s3": "tutti i comandi",
    "foot.dim": "deploy · rollback · audit · gui — open source",
  },
  de: {
    "nav.features": "Funktionen", "nav.tm": "Time Machine", "nav.install": "Installieren",
    "hero.badge": "v2.0 · Open Source · keine Abhängigkeiten",
    "hero.h1a": "Bring deine Seite online mit", "hero.h1b": "einem Befehl",
    "hero.lede": "Deploy auf Cloudflare Pages, <b>sofortiges Rollback</b>, PageSpeed-Audits, eine leichte GUI und ein komplettes Dev-Toolkit. Alles im Terminal — federleicht.",
    "hero.gh": "Auf GitHub ansehen",
    "stats.cmds": "Befehle", "stats.dep": "Abhängigkeit (wrangler)", "stats.ram": "RAM im Leerlauf", "stats.rb": "lokale Rollbacks",
    "feat.h2": "Ein Schweizer Taschenmesser fürs Web",
    "feat.deploy.t": "Deploy in einem Befehl", "feat.deploy.d": "Statischer Ordner oder automatischer Build (npm/pnpm/yarn/bun). Ein Branch pro Kunde, eine teilbare URL.",
    "feat.tm.t": "Time Machine", "feat.tm.d": "Jeder Deploy wird lokal archiviert. <b>Echtes Rollback</b> zu einer früheren Version — was wrangler allein nicht kann.",
    "feat.audit.t": "PageSpeed-Audit", "feat.audit.d": "Vorab-Test mit echtem Score (Google-Lighthouse-Engine): Performance, SEO, Barrierefreiheit und Core Web Vitals.",
    "feat.gui.t": "Federleichte GUI", "feat.gui.d": "Ein Browser-Panel unter <code>nt.local</code>, um Kunden, Projekte, Snapshots und Einstellungen zu verwalten. Kein Electron — reines stdlib.",
    "feat.traffic.t": "Traffic &amp; Besuche", "feat.traffic.d": "Aktiviere Web Analytics mit einem Befehl und lies die Besuchsstatistik deiner Seite.",
    "feat.toolkit.t": "Offline-Toolkit", "feat.toolkit.d": "Lokaler Server, Scaffold, Größenbericht, Zip, QR-Codes, Health-Check, Kundennotizen. Nützlich auch ohne Cloudflare.",
    "who.h2": "Wofür &amp; für wen",
    "who.lead": "nt-deploy macht aus \"ich muss diese Website online stellen\" einen einzigen Befehl — und gibt dir alles drumherum: Vorschau-URLs pro Kunde, Performance-Audits vor dem Launch, Traffic-Statistiken und ein Sicherheitsnetz, das einen fehlerhaften Deploy in Sekunden rückgängig macht.",
    "who.free.t": "Freelancer &amp; Agenturen", "who.free.d": "Liefere jedem Kunden eine saubere Vorschau-URL (<code>kunde.du.pages.dev</code>), schick den Link und mach sofort ein Rollback, wenn er die vorherige Version will. Mit Notizen pro Kunde.",
    "who.dev.t": "Webentwickler", "who.dev.d": "Vergiss das Dashboard. Build und Deploy im Terminal, Core-Web-Vitals-Audit vor dem Launch, Live-Logs und Health-Check — ohne die Shell zu verlassen.",
    "who.indie.t": "Indie-Hacker &amp; Maker", "who.indie.d": "Veröffentliche Landingpages, Prototypen und Side-Projects in Sekunden. Starter erzeugen, lokal servieren, deployen, QR fürs Handy holen und Traffic beobachten.",
    "who.team.t": "Kleine Teams", "who.team.d": "Ein einheitlicher Deploy-Workflow für alle, mit lokalen Snapshots als Sicherheitsnetz und Bestätigungen vor jeder destruktiven Aktion (Produktion überschreiben, löschen).",
    "kill.badge": "★ Killer-Feature", "kill.h2": "Das Rollback, das wrangler nicht hat",
    "kill.p": "Cloudflare bietet kein CLI-Rollback für Pages. nt-deploy archiviert jeden Push lokal und lässt dich <b>jede Version</b> in Sekunden wiederherstellen.",
    "kill.l1": "der Deploy-Verlauf", "kill.l2": "zurück zum vorherigen", "kill.l3": "zu einer genauen Version",
    "install.h2": "In 10 Sekunden installiert", "install.lede": "Braucht nur Node (für wrangler). Das Skript aktualisiert sich selbst.",
    "install.s1": "Login + Projekt", "install.s2": "Build, Deploy, fertig", "install.s3": "alle Befehle",
    "foot.dim": "deploy · rollback · audit · gui — Open Source",
  },
  es: {
    "nav.features": "Funciones", "nav.tm": "Time Machine", "nav.install": "Instalar",
    "hero.badge": "v2.0 · código abierto · sin dependencias",
    "hero.h1a": "Publica tu sitio en", "hero.h1b": "un comando",
    "hero.lede": "Despliega en Cloudflare Pages, <b>rollback instantáneo</b>, auditorías PageSpeed, una GUI ligera y un toolkit completo. Todo desde la terminal — ligerísimo.",
    "hero.gh": "Ver en GitHub",
    "stats.cmds": "comandos", "stats.dep": "dependencia (wrangler)", "stats.ram": "RAM en reposo", "stats.rb": "rollbacks locales",
    "feat.h2": "Una navaja suiza para la web",
    "feat.deploy.t": "Despliegue en un comando", "feat.deploy.d": "Carpeta estática o build automático (npm/pnpm/yarn/bun). Una rama por cliente, una URL lista para compartir.",
    "feat.tm.t": "Time Machine", "feat.tm.d": "Cada despliegue se archiva en local. <b>Rollback real</b> a una versión anterior — algo que wrangler por sí solo no puede.",
    "feat.audit.t": "Auditoría PageSpeed", "feat.audit.d": "Pre-test con puntuación real (motor Google Lighthouse): Rendimiento, SEO, Accesibilidad y Core Web Vitals.",
    "feat.gui.t": "GUI ligerísima", "feat.gui.d": "Un panel en el navegador en <code>nt.local</code> para gestionar clientes, proyectos, snapshots y ajustes. Sin Electron — solo stdlib.",
    "feat.traffic.t": "Tráfico y visitas", "feat.traffic.d": "Activa Web Analytics con un comando y consulta las estadísticas de visitas de tu sitio.",
    "feat.toolkit.t": "Toolkit offline", "feat.toolkit.d": "Servidor local, scaffold, informe de tamaño, zip, códigos QR, health-check, notas de cliente. Útil incluso sin Cloudflare.",
    "who.h2": "Para qué sirve y para quién",
    "who.lead": "nt-deploy convierte \"necesito poner este sitio online\" en un solo comando — y te da todo alrededor: URLs de vista previa por cliente, auditorías de rendimiento antes del lanzamiento, estadísticas de tráfico y una red de seguridad para deshacer un despliegue fallido en segundos.",
    "who.free.t": "Freelancers y agencias", "who.free.d": "Entrega a cada cliente una URL de vista previa limpia (<code>cliente.tu.pages.dev</code>), envía el enlace y haz rollback al instante si quiere la versión anterior. Con notas por cliente.",
    "who.dev.t": "Desarrolladores web", "who.dev.d": "Olvida el panel. Build y despliegue desde la terminal, auditoría de Core Web Vitals antes del lanzamiento, logs en vivo y health-check — sin salir de tu shell.",
    "who.indie.t": "Indie hackers y makers", "who.indie.d": "Publica landings, prototipos y proyectos personales en segundos. Crea un starter, sírvelo en local, despliega, obtén un QR para probarlo en el móvil y observa el tráfico.",
    "who.team.t": "Equipos pequeños", "who.team.d": "Un flujo de despliegue coherente para todos, con snapshots locales como red de seguridad y confirmaciones antes de cualquier acción destructiva (sobrescribir producción, eliminar).",
    "kill.badge": "★ función estrella", "kill.h2": "El rollback que wrangler no tiene",
    "kill.p": "Cloudflare no ofrece rollback por CLI para Pages. nt-deploy archiva cada push en local y te permite <b>restaurar cualquier versión</b> en segundos.",
    "kill.l1": "el historial de despliegues", "kill.l2": "vuelve al anterior", "kill.l3": "a una versión exacta",
    "install.h2": "Instala en 10 segundos", "install.lede": "Solo necesita Node (para wrangler). El script se auto-actualiza.",
    "install.s1": "login + proyecto", "install.s2": "build, despliega, listo", "install.s3": "todos los comandos",
    "foot.dim": "deploy · rollback · audit · gui — código abierto",
  },
};

function applyLang(lang) {
  const dict = I18N[lang] || I18N.en;
  document.documentElement.lang = lang;
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const v = dict[el.dataset.i18n];
    if (v != null) el.innerHTML = v;
  });
  document.querySelectorAll("#lang button").forEach((b) =>
    b.classList.toggle("on", b.dataset.lang === lang));
  try { localStorage.setItem("nt-lang", lang); } catch {}
}

(function initLang() {
  let saved;
  try { saved = localStorage.getItem("nt-lang"); } catch {}
  const guess = (navigator.language || "en").slice(0, 2).toLowerCase();
  const lang = saved || (I18N[guess] ? guess : "en");
  applyLang(lang);
  document.querySelectorAll("#lang button").forEach((b) =>
    b.addEventListener("click", () => applyLang(b.dataset.lang)));
})();

// copy-to-clipboard + toast
const toast = document.getElementById("toast");
let toastTimer;
function showToast(msg) {
  toast.textContent = msg;
  toast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove("show"), 1800);
}
document.querySelectorAll(".copy").forEach((btn) => {
  btn.addEventListener("click", async () => {
    const cmd = btn.dataset.cmd || "";
    try { await navigator.clipboard.writeText(cmd); showToast("✓"); }
    catch {
      const ta = document.createElement("textarea");
      ta.value = cmd; document.body.appendChild(ta); ta.select();
      try { document.execCommand("copy"); showToast("✓"); } catch { showToast("select & copy"); }
      ta.remove();
    }
  });
});
