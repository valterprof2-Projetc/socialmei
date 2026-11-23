# SocialMEI-IA · Experiência Premium v5 (resumo)

**Base:** `SocialMEI-Site-Completo-v4-ORGANIZADO.zip`. Nada foi publicado, enviado ao GitHub ou alterado em produção.

## O que mudou
- **Escala ~90% natural** (desktop ≥ 1025 px): contêineres, tipografia, botões e espaçamentos menores com medidas reais; sem `zoom`.
- **"Cada parte do negócio, no seu lugar"**: o grid de cards virou índice numerado (direita) + palco (esquerda) com abas acessíveis, setas do teclado, botão "Seguir para…" e as mesmas telas de exemplo e textos de antes. Brilho azul no hover preservado. No celular o índice vira faixa de abas rolável.
- **Hero**: nome SocialMEI-IA maior e **seletor "O que você faz?"** (Vendo doces, Loja de roupas, Beleza, Serviços e reparos, Presentes e artesanato, Outro ramo). Tocar de novo desfaz. O mural continua subindo, sem pausa no hover e sem clique.
- **Continuidade com o cadastro**: a escolha vai para `smei-ramo`; o onboarding já abre com a área marcada (com aviso "Pode trocar") e acompanha a hero enquanto a pessoa não marcou nada lá. Dados já preenchidos nunca são sobrescritos.
- **Três passos**: passo 2 com ramo e cor reais (ligados à hero e ao cadastro); passo 3 com roteiro e checkboxes que mudam com o ramo.
- **FAQ**: abertura/fechamento suaves (300 ms), seta animada, cliques seguidos, ↑/↓/Home/End, `prefers-reduced-motion` e modo calmo. Perguntas e respostas intactas.

## Arquivos
Novos: `frontend/styles/premium-v5.css`, `frontend/scripts/premium-v5.js`.
Alterados: `frontend/entrada.html`, `frontend/scripts/hero-wall.js` (API `SMEI_RAMO`), `frontend/scripts/entrada.js` (ramo no onboarding), `INSTRUCOES-PARA-OUTRA-IA.md`, `LEIA-ME-PRIMEIRO.md`.

## Limitações
- Escolhas ficam só neste navegador (localStorage); sem backend.
- "Outro ramo" mantém os exemplos padrão (o mural só tem textos para 5 ramos).
- A cor do passo 2 só é aplicada no app quando o cadastro a lê (`smei-brand`).
- Pendência fora do escopo: seções história/demonstração/planos e app interno não foram redesenhados.
