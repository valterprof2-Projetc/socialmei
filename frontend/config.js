/* PUBLIC CONFIGURATION */
// Apenas configuração pública. Segredos devem permanecer no servidor/n8n.
const SOCIALMEI_CONFIG = Object.freeze({
  // Autenticação real habilitada somente nesta branch de Preview.
  // O cadastro permanece protegido por convite no backend.
  auth: { mode: "remote", apiBaseUrl: "/api/v1" },
  // Experimental branch: no automatic connection to a live message endpoint.
  n8nMessagesUrl: null,
  n8nAuthHeader: null,
  // Desabilitado por padrão. Handoff externo somente para piloto isolado da equipe.
  instagramPublisher: { mode: "disabled", formPath: "/form/instagram-post" },
  // Ativar somente no staging com auth remota e backend em modo simulation.
  instagramSimulation: { mode: "disabled" },
  // Piloto externo opcional: somente após confirmar a instância, a conta e o responsável.
  // Ex.: { mode: "external-pilot", formUrl: "https://SUA-INSTANCIA/form/instagram-post",
  //        approvedOrigin: "https://SUA-INSTANCIA" }. Nunca incluir tokens ou credenciais.
  // Ativar somente em desenvolvimento/staging com API e workspace conferidos.
  clientes: { mode: "local", apiBaseUrl: "", workspaceKey: "" },
  // Optional identifiers for the PUBLIC informational page (/sobre.html).
  // Do not enable until the owner has configured GA4/Clarity, privacy settings
  // and the explicit opt-in banner. Never add CRM/customer identifiers here.
  siteMetrics: {
    enabled: false,
    ga4MeasurementId: "",
    clarityProjectId: "",
  },
});

// Campo de convite da primeira conta administrativa.
// É inserido no DOM antes da interação; o código nunca é armazenado.
document.addEventListener("DOMContentLoaded", () => {
  if (SOCIALMEI_CONFIG.auth?.mode !== "remote") return;
  const form = document.getElementById("fC");
  const email = document.getElementById("cMail")?.closest(".fld");
  if (!form || !email || document.getElementById("cInvite")) return;

  const field = document.createElement("div");
  field.className = "fld";
  const label = document.createElement("label");
  label.htmlFor = "cInvite";
  label.textContent = "Código do convite";
  const input = document.createElement("input");
  input.className = "in";
  input.id = "cInvite";
  input.name = "convite";
  input.type = "text";
  input.inputMode = "text";
  input.autocomplete = "off";
  input.spellcheck = false;
  input.maxLength = 64;
  input.placeholder = "Cole aqui o código recebido do administrador";
  input.setAttribute("aria-describedby", "eInvite");
  const hint = document.createElement("div");
  hint.className = "hint";
  hint.textContent = "Este cadastro é restrito e o convite só pode ser utilizado uma vez.";
  const error = document.createElement("div");
  error.className = "err";
  error.id = "eInvite";
  error.setAttribute("role", "alert");
  field.append(label, input, hint, error);
  email.insertAdjacentElement("afterend", field);

  input.addEventListener("input", () => {
    error.textContent = "";
    input.setAttribute("aria-invalid", "false");
  });
  form.addEventListener("submit", (event) => {
    if (!/^[a-f0-9]{64}$/i.test(input.value.trim())) {
      event.preventDefault();
      event.stopImmediatePropagation();
      error.textContent = "Informe o código completo do convite (64 caracteres).";
      input.setAttribute("aria-invalid", "true");
      input.focus();
    }
  }, true);
});
