# Prompt reutilizável para próximas alterações no SocialMEI-IA

Trabalhe exclusivamente sobre o ZIP organizado do SocialMEI-IA fornecido. Mantenha os arquivos de entrada `ABRIR-SITE.cmd`, `ABRIR-APLICATIVO-COMPLETO.cmd`, `index.html` e o servidor de testes. Qualquer nova entrega deve continuar permitindo abrir o site e o aplicativo completo com dois cliques no Windows.

Implemente **somente** as alterações que eu solicitar na mensagem da vez. Não altere outras telas, componentes, textos, animações ou integrações por iniciativa própria. Preserve especialmente o mural subindo sem pausar no hover ou abrir imagens ao clicar, os efeitos azuis dos cards, a FAQ e a grande animação do nome SocialMEI no final.

**PROIBIDO GERAR PRINTS AUTOMATICAMENTE.** Não capture telas, não crie imagens de antes/depois, não gere pastas `capturas-*`, não faça relatórios com dezenas de screenshots. Eu não utilizo essas imagens e não quero gastar tempo, tokens ou espaço de ZIP com elas. Só faça capturas se eu pedir expressamente numa solicitação futura. Teste com código, verificações estáticas, navegador/console se houver acesso e descreva o resultado em texto curto.

Ao terminar, execute `node tools/verificar-arquivos.cjs`, teste a abertura dos dois endereços locais se possível, compare os arquivos modificados e entregue **um único ZIP limpo**, com somente o site atual, os atalhos, ferramentas necessárias e documentação sucinta. Não inclua duplicatas de versões antigas, pastas de capturas, `node_modules` ou relatórios de auditoria excessivamente longos.

Não publique na AWS, não faça push, não mude configurações remotas e não invente recursos reais para a demonstração. Informe de forma breve: o que mudou, o que foi preservado, os testes realmente executados e qualquer limitação.
