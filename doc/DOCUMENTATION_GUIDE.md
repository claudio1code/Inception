# Guia de Documentação - Projeto Inception

Este guia define as normas estritas para a manutenção da documentação técnica deste projeto. Estas instruções devem ser seguidas por qualquer IA ou colaborador para garantir a consistência e a qualidade necessária para a defesa técnica na 42.

## 1. Filosofia e Rigor Técnico
A documentação não deve apenas listar o que foi feito, mas explicar o **como** e o **porquê**. Cada comando deve ser decomposto para demonstrar entendimento total da infraestrutura.

## 2. Estrutura da Pasta /doc
- DOCUMENTATION_GUIDE.md: Este arquivo de diretrizes.
- dev_journal.md: O diário de bordo técnico principal.
- /diagrams: Armazenamento de diagramas de infraestrutura.
- /configs: Notas detalhadas sobre arquivos de configuração.

## 3. Padrões de Escrita (Mandatórios)
- **Idioma**: Português.
- **Tom**: Estritamente profissional, técnico e direto.
- **Emojis**: É proibido o uso de emojis ou qualquer elemento gráfico informal.
- **Cronologia**: As entradas mais recentes no dev_journal.md devem sempre ficar no topo (ordem cronológica inversa).

## 4. Estrutura de uma Entrada no Diário (dev_journal.md)
Cada nova entrada deve seguir obrigatoriamente este nível de detalhamento:

### [DATA] - [Título Técnico Detalhado]

#### Contexto
Explicação teórica do objetivo da sessão e por que ele é importante para o projeto Inception.

#### Detalhamento das Etapas e Comandos
- **Comandos**: Listar comandos completos e explicar cada flag utilizada (ex: o que significa `-fsSL` no curl).
- **Processos**: Explicar o que acontece no sistema operacional ao executar tais ações.

#### Racional das Escolhas e Decisões Críticas
- Justificar a escolha de ferramentas, versões de SO (ex: Debian Bullseye) ou métodos de instalação.
- Explicar por que uma abordagem é mais segura ou eficiente que outra.

#### Problemas Resolvidos (Troubleshooting)
- Registrar erros encontrados, logs analisados e a solução aplicada.

#### Próximos Passos
- Lista técnica do que será abordado na sequência.

## 5. Objetivo Final
Esta documentação deve servir como base de dados rica para a geração automática de um README.md completo e para a preparação da defesa oral (viva voce) do projeto.
