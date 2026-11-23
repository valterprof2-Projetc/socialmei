# SocialMEI-IA — Experiência Premium v5 (resumo em NOTAS-v5.md)

Este pacote é a v5, construída sobre o pacote organizado v4. Veja `NOTAS-v5.md`.

## Abrir no Windows

1. Extraia TODO o ZIP em uma pasta (não execute o arquivo dentro da visualização do ZIP).
2. Dê dois cliques em **`ABRIR-SITE.cmd`** para abrir a landing/hero completa.
3. Dê dois cliques em **`ABRIR-APLICATIVO-COMPLETO.cmd`** para abrir o aplicativo diretamente.
4. Mantenha a janela de terminal aberta enquanto navega. Para finalizar, pressione `Ctrl+C`.

Os dois atalhos usam **Node.js**, sem instalações de dependências e sem `npm install`. Se o Node não estiver disponível, abrem o HTML diretamente, com possíveis limitações do modo `file://`.

Endereços locais previstos, com o servidor iniciado:

- Site/landing: `http://127.0.0.1:4173/frontend/entrada.html`
- Aplicativo: `http://127.0.0.1:4173/frontend/socialmei-app.html#/inicio`

Se a porta 4173 estiver ocupada, o iniciador escolherá outra e mostrará os endereços corretos no terminal.

**Alternativa sem terminal:** abrir `index.html` ou `frontend/entrada.html` diretamente; algumas funcionalidades do aplicativo podem exigir HTTP ou configuração apropriada.

## Estrutura do ZIP

```text
SocialMEI-IA-Experiencia-Premium-v5/
├── ABRIR-SITE.cmd                   ← abrir landing e hero
├── ABRIR-APLICATIVO-COMPLETO.cmd    ← abrir o app completo
├── VERIFICAR-ARQUIVOS.cmd           ← integridade estrutural + sintaxe JavaScript
├── index.html                       ← atalho para landing
├── LEIA-ME-PRIMEIRO.md
├── INSTRUCOES-PARA-OUTRA-IA.md
├── NOTAS-v5.md
├── tools/
│   ├── servidor-local.cjs           ← servidor HTTP apenas em 127.0.0.1
│   └── verificar-arquivos.cjs
└── frontend/                       ← site (v5)
    ├── entrada.html                 ← landing, hero e acesso
    ├── socialmei-app.html           ← aplicação completa
    ├── telas/                       ← páginas auxiliares do aplicativo
    ├── scripts/
    ├── styles/
    └── assets/
```

## Onde alterar a hero

- Conteúdo HTML da hero: `frontend/entrada.html` — `<section class="hero hx">`.
- Visual da hero: `frontend/styles/hero-v3.css`, com estilos compartilhados em `frontend/styles/entrada.css`.
- Mural de cartões animados: `frontend/scripts/hero-wall.js`.
- Textos e exemplos da landing: `frontend/scripts/landing-content.js`.
- Outras seções da landing: `frontend/styles/sections-v3.css` e `frontend/scripts/sections-v3.js`.
- v5 (funcionalidades, passos, FAQ, seletor de ramo): `frontend/styles/premium-v5.css` e `frontend/scripts/premium-v5.js`.

## O que foi retirado do pacote principal

- `capturas-v4/`: 183 capturas de teste, desnecessárias para executar o site.
- `estado-anterior-v3/`: cópia duplicada de todo o frontend anterior.
- `DIFF-*.diff`: arquivos auxiliares de comparação.

A cópia original completa continua no ZIP que você enviou. Os arquivos removidos são apenas material de histórico e auditoria, **não componentes da versão atual do aplicativo**.

## Importante

- Este pacote é para edição e testes locais. Ele **não publica** nem atualiza a AWS ou o GitHub.
- A interface pode incluir recursos demonstrativos ou integrações externas não configuradas; abrir a página não comprova que as integrações estejam ativas.
- Não foram geradas capturas de tela. Nas próximas alterações, **não gerar prints**, salvo solicitação expressa.
