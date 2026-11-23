# Regras obrigatórias para qualquer IA que editar este ZIP

1. **Base única:** trabalhe em `frontend/`. Não misture versões antigas ou reconstitua o site a partir de screenshots.
2. **Preservação:** não modifique componentes fora do escopo do pedido. Em especial, não altere a FAQ, a animação final SocialMEI, o efeito azul de hover dos cards nem o mural sem instrução expressa.
3. **Experiência existente:** mural continua subindo e **não pausa ao passar o mouse**; clicar nele **não abre lightbox/imagem**. Preserve esses comportamentos.
4. **Arquivo de entrada:** `ABRIR-SITE.cmd` abre a landing, `ABRIR-APLICATIVO-COMPLETO.cmd` abre o app. **Ambos devem continuar funcionando**. Mantenha `index.html` e os scripts `tools/`.
5. **NÃO GERAR PRINTS:** não criar capturas de tela, screenshots, pastas `capturas`, imagens de antes/depois nem relatórios visuais com imagens. O usuário não as utiliza e não quer gastar tokens, tempo ou espaço com isso. Use inspeção de código, verificações estruturais, testes de funcionamento e console. Somente gerar print se o usuário solicitar explicitamente.
6. **Entrega:** produzir somente um ZIP limpo com o `frontend/` atualizado, atalhos, ferramentas e documentação. Não incluir backups completos duplicados, dumps, `node_modules` ou diffs extensos na raiz.
7. **Testar:** executar `node tools/verificar-arquivos.cjs`. Testar navegação do site e app quando um navegador disponível permitir. Declarar claramente o que não foi testado.
8. **Segurança:** não inserir tokens, segredos, senhas ou configurações de produção. Não realizar deploy, commit, push ou alterações remotas sem autorização expressa.
9. **Reporte em texto curto:** arquivos alterados, mudanças, testes executados e limitações. Não acrescentar prints nem longas auditorias não solicitadas.
10. **Design:** quando houver pedido de melhoria visual, pesquisar referências externas se o acesso à internet estiver disponível, mas não copiar layouts ou criar funcionalidades fictícias. A criatividade pode se aplicar à hero, respeitando o escopo solicitado.
11. **Escala:** o tamanho "de 90%" é feito com medidas reais (bloco 1 de `frontend/styles/premium-v5.css`, só a partir de 1025 px). Nunca usar `zoom` global nem `transform` global. No celular, alvos de toque ≥ 44 px.
12. **Ramo escolhido na hero:** grava só `smei-ramo` (e `smei-brand` no passo 2). O onboarding (`scripts/entrada.js`, `ramoGuardado()`) já vem marcado e nunca sobrescreve o que a pessoa preencheu. Não gravar nada além disso nem fingir envio ao servidor.
13. **Mapa de arquivos da landing:** hero `entrada.html` (`.hero.hx`) + `styles/hero-v3.css` + `scripts/hero-wall.js` (expõe `window.SMEI_RAMO`); seções `styles/sections-v3.css`, `scripts/sections-v3.js`, textos `scripts/landing-content.js`; v5 (funcionalidades, passos, FAQ, seletor de ramo) `styles/premium-v5.css` + `scripts/premium-v5.js`.
