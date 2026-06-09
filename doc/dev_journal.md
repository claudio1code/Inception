# Diário de Desenvolvimento - Inception

Este arquivo serve para registrar todo o progresso, decisões técnicas e obstáculos enfrentados durante o desenvolvimento do projeto Inception da 42.

---

## [2026-06-09] - Reforço de Segurança: Isolamento de Rede do Banco de Dados (MariaDB)

### Contexto
Um dos pilares de segurança do projeto Inception é o isolamento dos serviços. O banco de dados MariaDB deve ser acessível exclusivamente pelo container WordPress através da rede interna (`inception_network`), nunca sendo exposto diretamente ao sistema host ou à rede externa. Foi realizado um teste de auditoria para validar se essa restrição estava sendo aplicada.

### Detalhamento das Etapas e Comandos

1. **Auditoria de Segurança (Falha Identificada)**:
   - Comando: `nc -zv 127.0.0.1 3306`
   - **nc (netcat)**: Utilitário para leitura e escrita em conexões de rede.
   - **-z**: Modo scan (não envia dados).
   - **-v**: Modo verboso.
   - **Resultado**: `Connection to 127.0.0.1 3306 port [tcp/mysql] succeeded!`.
   - **Racional**: O sucesso da conexão indicou que o tráfego do host estava alcançando o MariaDB, o que representa um risco de segurança e viola o princípio de menor privilégio.

2. **Análise de Causa Raiz**:
   - Inspeção do `srcs/docker-compose.yml`.
   - Identificou-se a presença do bloco `ports: - "3306:3306"`.
   - **Racional**: A diretiva `ports` no Docker Compose realiza o mapeamento (forwarding) da porta do host para a porta do container, abrindo um túnel que ignora o isolamento pretendido da bridge network.

3. **Correção e Remediação**:
   - Remoção completa do bloco `ports` no serviço `mariadb` do arquivo `docker-compose.yml`.
   - Reinicialização da infraestrutura: `make down && make up`.

4. **Validação Final (Sucesso)**:
   - Comando: `nc -zv 127.0.0.1 3306`
   - **Resultado**: `nc: connect to 127.0.0.1 port 3306 (tcp) failed: Connection refused`.
   - **Racional**: O erro "Connection refused" confirma que a porta 3306 não está mais escutando no host, garantindo que o MariaDB está agora devidamente isolado.

### Racional das Escolhas e Decisões Críticas
A comunicação entre WordPress e MariaDB não é afetada por essa mudança, pois ambos compartilham a `inception_network`. O Docker gerencia a resolução de nomes interna (DNS), permitindo que o WordPress utilize o host `mariadb` na porta `3306` sem que essa porta precise estar aberta para o mundo exterior. Esta configuração é mandatória para garantir que o banco de dados não sofra tentativas de ataques de força bruta ou varreduras vindas de fora da infraestrutura orquestrada.

### Problemas Resolvidos (Troubleshooting)
- **Vulnerabilidade de Exposição de Porta**: Eliminado o acesso externo não autorizado ao serviço de banco de dados.

### Próximos Passos
- Realizar auditoria semelhante em outros serviços (WordPress/PHP-FPM) para garantir isolamento total.

---

## [2026-06-09] - Verificação de Persistência de Dados via Bind Mounts

### Contexto
O objetivo desta sessão foi validar se a infraestrutura do projeto Inception cumpre o requisito de persistência de dados. Foi realizado um teste funcional onde uma alteração de estado na aplicação (criação de um novo post no WordPress) deve sobreviver à destruição completa dos containers da infraestrutura.

### Detalhamento das Etapas e Comandos

1. **Alteração de Estado (Aplicação)**:
   - Acesso ao painel administrativo do WordPress via `https://clados-s.42.fr/wp-admin`.
   - Criação e publicação de um novo post intitulado "Teste de Persistência".
   - **Racional**: Esta ação gera registros na tabela `wp_posts` dentro do banco de dados MariaDB.

2. **Destruição da Infraestrutura**:
   - Comando: `make down`
   - **O que acontece**: O comando executa `docker compose down`, que interrompe e remove os containers, redes e imagens (se especificado), mas não toca nos volumes montados ou caminhos do host. Neste ponto, os processos do MariaDB e WordPress deixam de existir.

3. **Reinstanciação da Infraestrutura**:
   - Comando: `make up`
   - **O que acontece**: O comando recria os containers a partir das imagens. Ao subir o MariaDB, o Docker realiza novamente o mapeamento do diretório do host para dentro do container.

4. **Validação**:
   - Novo acesso ao site e confirmação de que o post "Teste de Persistência" ainda está visível.

### Racional das Escolhas e Decisões Críticas

A persistência observada ocorre devido ao uso de **Bind Mounts** em vez de volumes gerenciados pelo Docker. No arquivo `srcs/docker-compose.yml`, a persistência é definida nos blocos:

- **MariaDB**: `- ${DB_DATA_PATH}:/var/lib/mysql`
- **WordPress**: `- ${WP_DATA_PATH}:/var/www/html`

Diferente de um container padrão, onde os dados são gravados na camada de escrita temporária (que é destruída com o container), o Bind Mount vincula um diretório específico do sistema de arquivos do host (`/home/claudio/data/...`) a um diretório dentro do container. 

No `Makefile`, os caminhos são definidos e criados durante o alvo `up`:
- `WP_DATA_PATH = /home/claudio/data/wordpress`
- `DB_DATA_PATH = /home/claudio/data/mariadb`

Isso garante que, mesmo quando o container é removido pelo `make down`, os arquivos binários do banco de dados e os arquivos estáticos do WordPress permanecem salvos no disco da VM. Para apagar esses dados permanentemente, deve-se utilizar o comando `make fclean`, que executa `rm -rf` nestes diretórios.

### Resultados Obtidos (Marcos Técnicos)
- **Integridade de Dados**: Confirmado que o ciclo de vida dos containers está desvinculado da persistência dos dados.
- **Conformidade com o Subject**: A infraestrutura utiliza caminhos absolutos no host para armazenamento, conforme exigido.

### Próximos Passos
- Verificação final de segurança e permissões dos volumes antes da entrega.

---

## [2026-06-07] - Validação de Tráfego e Conectividade em Tempo Real

### Contexto
Após a implementação das correções no MariaDB e o estabelecimento do túnel SSH SOCKS5, foi realizada uma inspeção nos logs de acesso do Nginx para confirmar se as requisições externas estavam sendo corretamente roteadas e processadas pelo servidor web dentro da infraestrutura Docker.

### Detalhamento das Etapas e Comandos

1. **Monitoramento de Logs de Acesso**:
   - Comando: `docker exec -it nginx tail -f /var/log/nginx/access.log`
   - **Racional**: Este comando permite observar em tempo real o fluxo de entrada de dados, identificando o IP de origem, o método HTTP, o recurso solicitado e o código de status retornado.

2. **Análise dos Resultados (Logs)**:
   - **Origem (172.18.0.1)**: As requisições aparecem vindo do gateway da rede Docker, o que valida que o tráfego está sendo encaminhado corretamente através do proxy/túnel SSH.
   - **Status 200 (OK)**: Confirma que recursos críticos (ex: `index.js`, `view.min.js`, `Manrope-VariableFont_wght.woff2`) foram entregues com sucesso.
   - **Status 301 (Redirect)**: Observado em requisições de `/favicon.ico`, indicando que as regras de reescrita ou diretivas de diretório do Nginx estão operacionais.
   - **User-Agent**: Confirmação de que as requisições vieram tanto do `Chrome/147.0.0.0` quanto de testes via `curl/7.81.0`.

### Racional das Escolhas
- **Monitoramento Live**: A escolha pelo `tail -f` em vez de apenas ler o arquivo é vital para validar a interação imediata do usuário com a interface web, permitindo correlacionar cliques no navegador com eventos no servidor.

### Resultados Obtidos (Marcos Técnicos)
- **Conectividade End-to-End**: Validado que o fluxo Host -> SSH Tunnel -> Nginx -> WordPress está 100% funcional.
- **Resolução de Ativos Estáticos**: O Nginx está servindo corretamente arquivos de temas e fontes, garantindo a integridade visual do site.

### Próximos Passos
- Conclusão da documentação técnica e preparação para a submissão final do projeto.

---


## [2026-06-07] - Estratégia de Infraestrutura Headless e Acesso via Túnel SSH SOCKS5

### Contexto
Como o projeto Inception foca em administração de sistemas e infraestrutura, a VM foi configurada sem interface gráfica (Headless). Em ambientes de produção reais, a ausência de uma GUI é uma prática recomendada para maximizar a performance (redução do consumo de RAM e CPU) e minimizar a superfície de ataque do servidor. Para acessar a aplicação web (`https://clados-s.42.fr`) hospedada na VM a partir do host, foi implementada uma técnica de tunelamento dinâmico.

### Detalhamento das Etapas e Comandos

1. **Criação do Túnel SSH Dinâmico**:
   - Comando: `ssh -D 9000 clados-s@127.0.0.1 -p 2222`
   - **-D 9000**: Estabelece um encaminhamento de porta dinâmico a nível de aplicação, transformando o cliente SSH em um servidor proxy SOCKS5 na porta 9000 do host.
   - **-p 2222**: Porta mapeada para o serviço SSH da VM.

2. **Acesso via Navegador (Chrome/Brave) com Proxy e Resolução de Host**:
   - Antes de iniciar, encerram-se processos residuais: `killall chrome` ou `killall brave-browser`.
   - Execução do Navegador (Exemplo Chrome):
     `google-chrome --proxy-server="socks5://127.0.0.1:9000" --host-resolver-rules="MAP clados-s.42.fr 127.0.0.1"`
   - **--proxy-server**: Direciona todo o tráfego do navegador através do túnel SOCKS5 criado.
   - **--host-resolver-rules**: Força o navegador a resolver o domínio `clados-s.42.fr` para o IP `127.0.0.1` (onde o túnel está escutando), contornando a necessidade de editar o arquivo `/etc/hosts` do sistema host e garantindo que as requisições cheguem à VM.

### Resumo para o README (Instruções de Acesso)
> **Nota de Infraestrutura**: Este projeto foi desenvolvido em uma VM *headless* (sem interface gráfica) para simular um ambiente de produção real, focando em segurança e eficiência de recursos.
>
> #### Como Acessar o WordPress via Túnel SSH
> 1. No terminal do seu host, crie um túnel SOCKS5:
>    ```bash
>    ssh -D 9000 clados-s@127.0.0.1 -p 2222
>    ```
> 2. Inicie o navegador com proxy e resolução de host forçada:
>
> **Para Chrome:**
> ```bash
> killall google-chrome
> google-chrome --proxy-server="socks5://127.0.0.1:9000" --host-resolver-rules="MAP clados-s.42.fr 127.0.0.1"
> ```
>
> **Para Brave:**
> ```bash
> killall brave-browser
> brave-browser --proxy-server="socks5://127.0.0.1:9000" --host-resolver-rules="MAP clados-s.42.fr 127.0.0.1"
> ```

### Racional das Escolhas
- **Segurança de Servidor**: A remoção da GUI elimina vetores de ataque comuns e vulnerabilidades em bibliotecas gráficas.
- **Portabilidade do Acesso**: O uso de flags de linha de comando no navegador permite acessar o site de forma isolada e segura, sem alterar configurações globais de rede do host.

### Problemas Resolvidos (Troubleshooting)
- **Resolução de DNS**: A flag `--host-resolver-rules` resolve o problema de o navegador não encontrar o domínio customizado `.42.fr` fora do ambiente da rede interna da VM.

### Próximos Passos
- Validação do certificado SSL autoassinado através do túnel SOCKS5.
- Monitoramento dos logs de acesso do Nginx para confirmar o recebimento de tráfego via proxy.

---

## [2026-06-07] - Resolução de Erro de Conexão (Host 1130) e Falha de Bootstrap no MariaDB

### Contexto
Durante a inicialização da infraestrutura, os logs revelaram uma falha de comunicação crítica entre o WordPress e o MariaDB. Embora ambos os containers estivessem ativos, o script de bootstrap do banco de dados falhou ao tentar definir privilégios, impedindo que o WordPress gerasse o arquivo `wp-config.php`.

### Detalhamento das Etapas e Comandos

1. **Análise de Logs do WordPress**:
   - `Error: Database connection error (1130) Host 'wordpress.inception_network' is not allowed to connect to this MariaDB server`.
   - **Racional**: Indica que o MariaDB está alcançável na rede, mas recusa a conexão porque o usuário `wp_user` não foi criado corretamente ou não possui permissão para o hostname/IP originário do container WordPress.

2. **Análise de Logs do MariaDB**:
   - `ERROR: 1290 The MariaDB server is running with the --skip-grant-tables option so it cannot execute this statement`.
   - `2026-06-07 17:28:52 0 [ERROR] Aborting`.
   - **Racional**: O motor do MariaDB, ao ser executado em modo de inicialização/bootstrap, encontrou um conflito onde comandos de gestão de usuários (`ALTER USER`, `GRANT`) foram bloqueados pela política de segurança de tabelas de permissão não carregadas.

3. **Refatoração do Script de Bootstrap (`mariadb_start.sh`)**:
   - Implementação de um novo bloco SQL para o arquivo temporário de inicialização:
     ```sql
     FLUSH PRIVILEGES;
     ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
     CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
     CREATE USER IF NOT EXISTS 'wp_user'@'%' IDENTIFIED BY '${DB_PASSWORD}';
     GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO 'wp_user'@'%';
     FLUSH PRIVILEGES;
     ```

### Problemas Resolvidos (Troubleshooting)

- **Erro 1290 (Skip Grant Tables)**:
  - **Sintoma**: O container MariaDB aborta durante o setup inicial.
  - **Causa**: Tentativa de modificar usuários enquanto o sistema está em um estado que ignora as tabelas de privilégios.
  - **Solução**: Inclusão do comando `FLUSH PRIVILEGES;` no topo do script SQL. Isso força o MariaDB a recarregar as tabelas de subvenção mesmo no modo de bootstrap, permitindo a execução de comandos `ALTER` e `GRANT`.

- **Erro 1130 (Host Not Allowed)**:
  - **Sintoma**: WordPress reporta que o host não tem permissão para conectar.
  - **Causa**: O usuário do banco de dados provavelmente estava restrito ao `localhost` ou o script que o criaria falhou devido ao Erro 1290.
  - **Solução**: Definição explícita do host como `'%'` (wildcard) para o `wp_user`. Na arquitetura de containers, o WordPress conecta-se via rede interna (`inception_network`), e seu IP/hostname não será o `localhost` do ponto de vista do MariaDB.

### Racional das Escolhas
- **Idempotência e Segurança**: O uso de `IF NOT EXISTS` garante que o script possa ser re-executado sem erros. A segunda chamada de `FLUSH PRIVILEGES` ao final garante que as alterações entrem em vigor imediatamente antes do daemon principal assumir o controle.

### Próximos Passos
- Aplicar a alteração no arquivo `srcs/requirements/mariadb/tools/mariadb_start.sh`.
- Realizar o reset do volume do MariaDB com `make fclean` para testar a nova lógica de bootstrap do zero.

---

## [2026-06-05] - Estabilização Final: Infraestrutura Operacional e Saudável

### Contexto
Após sucessivas rodadas de depuração técnica e ajustes finos nos scripts de bootstrap e arquivos de configuração, a infraestrutura completa do projeto Inception atingiu o estado operacional esperado. Todos os requisitos de conectividade, segurança e persistência foram validados via runtime.

### Detalhamento das Etapas e Comandos

1. **Validação de Runtime (`docker ps`)**:
   - Os containers foram verificados e apresentam o status `Up`, indicando que os processos principais (daemons) estão mantidos em primeiro plano com sucesso.
   - **Nginx**: Mapeamento de porta `443:443` ativo (IPv4 e IPv6).
   - **WordPress**: Rodando internamente na porta `9000`.
   - **MariaDB**: Escutando internamente na porta `3306`.

### Resultados Obtidos (Marcos Técnicos)

- **Saúde dos Serviços**: 
  - O Nginx está servindo tráfego via TLSv1.2/1.3.
  - O PHP-FPM está processando o WordPress e comunicando-se com o MariaDB sem erros de permissão ou conexão.
  - O MariaDB inicializou corretamente os usuários e o banco de dados após o reset físico dos volumes (`fclean`).

- **Isolamento de Rede**:
  - A `inception_network` permite a resolução de nomes entre serviços (ex: `fastcgi_pass wordpress:9000`), mantendo o banco de dados inacessível de fora da rede Docker, conforme o princípio de segurança exigido.

### Racional das Escolhas
- **Resiliência via Scripts**: A robustez atual da infraestrutura é fruto de scripts de entrypoint que lidam com a geração automática de certificados e a inicialização condicional de bancos de dados, garantindo portabilidade absoluta do projeto.

### Próximos Passos
- Verificação visual do site através do navegador acessando `https://clados-s.42.fr`.
- Preparação para a defesa técnica (viva voce), revisando os conceitos de Docker, Volumes e Redes documentados neste diário.

---

## [2026-06-05] - Resolução de Conflitos de Configuração e Persistência de Dados

### Contexto
Com a infraestrutura orquestrada, surgiram falhas de runtime específicas nos serviços WordPress e MariaDB. A análise dos logs revelou erros de sintaxe em arquivos de configuração do PHP e inconsistências lógicas no banco de dados causadas por estados residuais de builds anteriores.

### Detalhamento das Etapas e Comandos

1. **Correção de Sintaxe no PHP-FPM (`www.conf`)**:
   - Substituição do caractere de comentário `#` por `;` em todo o arquivo.
   - **Racional**: Arquivos de configuração do PHP-FPM seguem o padrão `.ini`, onde o caractere `#` é interpretado como uma entrada de configuração inválida, resultando no erro `value is NULL for a ZEND_INI_PARSER_ENTRY`.

2. **Saneamento de Dados Persistentes (`make fclean`)**:
   - Execução de uma limpeza profunda para remover os volumes físicos no host (`~/data/mariadb`).
   - Re-inicialização completa da infraestrutura.

### Problemas Resolvidos (Troubleshooting)

- **Erro: PHP-FPM falha com ZEND_INI_PARSER_ENTRY**:
  - **Sintoma**: Container WordPress encerra imediatamente com erro de parser.
  - **Causa**: Uso de comentários estilo Bash (`#`) em um arquivo de configuração que exige ponto e vírgula (`;`).
  - **Solução**: Refatoração do `www.conf` para seguir o padrão estrito de comentários do PHP.

- **Erro: MariaDB Connection Error (1130) - Host not allowed**:
  - **Sintoma**: WordPress incapaz de conectar ao banco, apesar das credenciais estarem corretas no `.env`.
  - **Causa (Estado Fantasma)**: Tentativas de build anteriores (sem arquivos de segredos) criaram a estrutura de diretórios do MySQL no host, mas falharam na criação do usuário `wp_user`. Como o script `mariadb_start.sh` verifica a existência da pasta para garantir a idempotência, ele pulava a criação dos usuários em execuções subsequentes, deixando o banco em um estado "meio-inicializado".
  - **Solução**: Uso do `make fclean` para deletar os dados físicos no host, forçando o script de bootstrap a re-executar a lógica de criação de usuários e privilégios (`GRANT ALL PRIVILEGES...`) do zero, agora com os segredos disponíveis.

### Racional das Escolhas
- **Idempotência vs. Limpeza**: A lógica de proteção do script de inicialização do banco é essencial para produção, mas durante o desenvolvimento, o conhecimento sobre quando forçar um reset total (`fclean`) é vital para evitar depurações de estados inconsistentes.

### Próximos Passos
- Validação final do acesso ao painel do WordPress via `https://clados-s.42.fr`.
- Registro do status final de "Healthy" para todos os containers.

---

## [2026-06-05] - Estabilização de Ambiente: Migração para Debian 12 e Refatoração do Nginx

### Contexto
Visando a estabilidade dos binários e a conformidade com as versões de pacotes esperadas (especialmente PHP 8.2), decidiu-se pela alteração da imagem base do projeto. Adicionalmente, logs de erro do Nginx revelaram uma falha estrutural no arquivo de configuração que impedia o boot do serviço.

### Detalhamento das Etapas e Comandos

1. **Downgrade Estratégico de SO (`Debian 12`)**:
   - Substituição de `debian:13` por `debian:12` nos Dockerfiles.
   - **Racional**: O Debian 12 (Bookworm) é a versão estável atual, oferecendo suporte nativo e previsível para o PHP 8.2, resolvendo o problema de "comando não encontrado" encontrado na versão Testing (Debian 13).

2. **Correção Estrutural da Configuração do Nginx (`nginx.conf`)**:
   - Inclusão do bloco obrigatório `events { worker_connections 1024; }`.
   - Adição de `include /etc/nginx/mime.types;` e `default_type application/octet-stream;` para correta interpretação de ativos estáticos.
   - Refinamento do bloco `location ~ \.php$` com a inclusão de `snippets/fastcgi-php.conf`.

### Problemas Resolvidos (Troubleshooting)

- **Erro: Nginx falha ao iniciar (Falta do bloco 'events')**:
  - **Sintoma**: Container Nginx entra em loop de reinicialização mesmo com scripts de ferramentas corretos.
  - **Causa**: O Nginx exige a presença do bloco `events` no arquivo de configuração principal, mesmo que vazio, para definir o modelo de processamento de conexões. Sem ele, o arquivo é considerado sintaticamente inválido para o daemon.
  - **Solução**: Adição do bloco `events` no topo do `nginx.conf`.

- **Sincronização de PHP no Debian 12**:
  - A migração para Debian 12 confirmou a presença do binário `php-fpm8.2`, eliminando o erro de execução anterior e estabilizando o serviço WordPress.

### Racional das Escolhas
- **Estabilidade vs. Novidade**: A escolha pelo Debian 12 prioriza a robustez do ecossistema de pacotes estáveis, essencial para um ambiente de infraestrutura que exige alta disponibilidade e previsibilidade.
- **MIME Types**: A inclusão do `mime.types` garante que o navegador identifique corretamente arquivos CSS e JS, evitando problemas de renderização do site.

### Próximos Passos
- Análise dos logs do container WordPress para validar a conexão com o banco de dados.
- Verificação final da infraestrutura após o re-build completo.

---

## [2026-06-05] - Depuração Técnica e Estabilização dos Microserviços

### Contexto
Após a subida inicial da infraestrutura, os containers apresentaram comportamentos instáveis (ciclos de reinicialização). Esta sessão foi dedicada à análise profunda dos logs e arquivos de configuração para identificar e corrigir falhas de execução nos serviços Nginx, MariaDB e WordPress.

### Detalhamento das Etapas e Comandos

1. **Correção do Fluxo de Execução do Nginx**:
   - Identificou-se que o script `nginx_start.sh` estava truncado. A ausência do comando `exec "$@"` impedia que o processo do Nginx assumisse o PID 1, fazendo com que o container encerrasse imediatamente após o `mkdir`.
   - Implementação da geração silenciosa de certificados SSL via `openssl` para garantir o protocolo HTTPS mandatório.

2. **Ajuste de Sintaxe no MariaDB**:
   - Correção do arquivo `my.cnf` onde a diretiva `bind-address` estava escrita incorretamente como `bind-adress`. O motor do MariaDB não reconhece a chave mal grafada, resultando em falha crítica no boot.

3. **Sincronização de Versões no WordPress (PHP-FPM)**:
   - Resolução do erro `Exit Code 127` (Command not found). O Dockerfile tentava executar o `php-fpm8.3`, mas a imagem base (Debian 13) provê a versão estável `8.2`. O comando foi atualizado para refletir a versão correta instalada no sistema.

### Problemas Resolvidos (Troubleshooting)

- **Bug 1: NGINX Incompleto e Encerramento Prematuro**:
  - **Sintoma**: Container com status `Exited (0)` ou `Restarting`.
  - **Causa**: O script de ferramentas parava após a criação do diretório. Sem o `exec "$@"`, o processo principal do container terminava.
  - **Solução**: Restauração do script completo com lógica de geração de certificados e substituição do processo (`exec`) para manter o daemon em primeiro plano.

- **Bug 2: Erro de Digitação no MariaDB (Typo)**:
  - **Sintoma**: MariaDB falhando ao iniciar com erro de configuração inválida.
  - **Causa**: Falta de um 'd' na palavra `address` (`bind-adress`).
  - **Solução**: Correção ortográfica para `bind-address = 0.0.0.0`.

- **Bug 3: Incompatibilidade de Versão do PHP no WordPress**:
  - **Sintoma**: `Exit Code 127`.
  - **Causa**: O binário `php-fpm8.3` não existe no repositório padrão do Debian 13, que utiliza a versão `8.2`.
  - **Solução**: Ajuste do `CMD` no Dockerfile para `php-fpm8.2 -F`.

### Racional das Escolhas
- **PID 1 Handling**: O uso do `exec` é uma decisão crítica de design para que o container receba corretamente sinais do sistema (como `SIGTERM`), garantindo um desligamento limpo.
- **Versionamento Estrito**: Optou-se por travar a versão do PHP na `8.2` para garantir que o ambiente de desenvolvimento seja idêntico ao de produção/avaliação, evitando falhas silenciosas por atualizações de pacotes.

### Próximos Passos
- Execução de `make fclean` e `make` para aplicar as correções em um ambiente limpo.
- Verificação final da conectividade HTTPS via navegador.

---

## [2026-06-05] - Lançamento da Infraestrutura e Validação de Orquestração

### Contexto
Após a criação manual dos arquivos de segredos no diretório `secrets/`, procedeu-se a uma nova tentativa de inicialização via `make`. O objetivo era validar a persistência dos volumes e a conectividade entre os microserviços.

### Detalhamento das Etapas e Comandos

1. **Execução do Build e Up (`make`)**:
   - Os diretórios de persistência no host foram validados e as imagens foram reconstruídas em 42.7s.
   - A rede `inception_network` foi criada com sucesso.
   - Os containers foram instanciados na ordem de dependência correta.

2. **Estado Operacional Observado**:
   - **Comando**: `docker ps`
   - **Resultado**: Os três containers (`nginx`, `wordpress`, `mariadb`) foram iniciados. No entanto, o sistema reportou um estado de reinicialização intermitente logo após o boot.

### Problemas Resolvidos (Troubleshooting)

- **Sucesso no Bind Mount**: A criação dos arquivos de texto na pasta `secrets/` resolveu o erro crítico de "bind source path does not exist", permitindo que o Docker Compose concluísse a montagem dos volumes de segredos.

- **Análise Técnica de Runtime (Ciclo de Reinicialização)**:
  - Observou-se que os containers entraram em ciclo de restart com os seguintes códigos de saída:
    - `nginx`: Status `Restarting (0)`. Indica que o processo principal terminou sem erros, sugerindo que o script de entrypoint pode ter finalizado o setup SSL mas não manteve o daemon do Nginx em foreground (ex: falta do `daemon off;` ou erro no `exec`).
    - `wordpress`: Status `Restarting (127)`. Código típico de "Command not found", indicando possível erro de sintaxe no script `wp_start.sh` ou ausência de uma dependência esperada no PATH.
    - `mariadb`: Status `Restarting (7)`. Indica um erro de execução interno, possivelmente relacionado a permissões no diretório de dados montado ou falha crítica no script de bootstrap.

### Racional das Escolhas
- **Manutenção do Estado**: A decisão de manter a política de restart como `always` ou `on-failure` no `docker-compose.yml` permitiu identificar rapidamente que, embora a orquestração (Docker Compose) tenha funcionado, a lógica interna dos containers (scripts de tools) ainda requer ajustes finos de execução.

### Próximos Passos
- Inspeção profunda dos logs (`docker logs`) de cada serviço para identificar as causas exatas das saídas prematuras.
- Ajuste dos scripts de entrypoint para garantir que os processos permaneçam ativos em primeiro plano.

---

## [2026-06-05] - Falha Crítica na Inicialização: Ausência de Arquivos de Segredos (Secrets)

### Contexto
Com a automação do `Makefile` pronta, procedeu-se à tentativa de inicialização da infraestrutura completa. O objetivo desta sessão era validar o build das imagens e a subida dos containers em modo orquestrado.

### Detalhamento das Etapas e Comandos

1. **Execução do Orquestrador (`make`)**:
   - O comando iniciou corretamente a criação dos diretórios persistentes no host (`~/data/mariadb` e `~/data/wordpress`).
   - O processo de build das imagens (`nginx`, `mariadb`, `wordpress`) foi concluído com sucesso em 39.4s, confirmando que os Dockerfiles e contextos de build estão corretos.

### Problemas Resolvidos (Troubleshooting)

- **Erro: invalid mount config for type "bind": bind source path does not exist**:
  - **Sintoma**: Falha imediata ao tentar criar o container do MariaDB após o build.
  - **Causa Raiz**: O `docker-compose.yml` utiliza a funcionalidade de `secrets` baseada em arquivos (`file: ...`). O Docker tenta realizar um bind mount do host para dentro do container no caminho `/home/clados-s/Inception/secrets/db_root_password.txt`. Como os arquivos físicos de texto que devem conter as senhas reais ainda não foram criados no diretório `secrets/`, o Docker Engine aborta a criação do container por falta da fonte do mount.
  - **Avisos Prévios**: O console também exibiu alertas de que os segredos externos não existiam (`WARN[0040] secret file srcs_db_root_password does not exist`).
  - **Solução Planejada**: Criação manual dos arquivos `.txt` dentro da pasta `secrets/` com as credenciais definidas no subject, garantindo que o Docker encontre os alvos para o bind mount.

### Racional das Escolhas
- **Gestão de Segredos via Arquivo**: Optou-se por não automatizar a criação desses arquivos no `Makefile` por questões de segurança; o operador deve ser responsável por gerir as credenciais sensíveis fora do controle de versão.

### Próximos Passos
- Criação dos arquivos `db_root_password.txt`, `db_password.txt` e demais segredos necessários.
- Nova execução do comando `make` para validar a orquestração completa.

---

## [2026-06-04] - Orquestração de Microserviços e Automação de Ciclo de Vida

### Contexto
Com os Dockerfiles e configurações individuais prontos, a etapa final consiste em orquestrar a comunicação entre os containers e automatizar a gestão da infraestrutura. O **Docker Compose** é utilizado para definir a topologia da rede, volumes e dependências, enquanto o **Makefile** fornece uma interface simplificada para o operador do sistema.

### Detalhamento das Etapas e Comandos

1. **Definição da Orquestração (`docker-compose.yml`)**:
   - **Topologia de Rede**: Criação da `inception_network` (driver bridge). Esta rede isolada garante que os containers se comuniquem via nomes de serviço (ex: `wordpress` resolve para o IP interno do container WordPress), aumentando a segurança ao não expor o banco de dados diretamente ao host.
   - **Gestão de Segredos (Docker Secrets)**: Implementação de segredos externos (`secrets/*.txt`). Estes arquivos são montados em `/run/secrets/` dentro dos containers em modo somente leitura, protegendo dados sensíveis.
   - **Persistência via Bind Mounts**: Utilização de caminhos físicos do host (`/home/clados-s/data/...`) para persistência de dados. Isso garante que, mesmo que os volumes do Docker sejam removidos, os dados do banco e do site permaneçam salvos no disco da VM.
   - **Hierarquia de Dependências**: Uso de `depends_on` para garantir a ordem lógica de boot: MariaDB -> WordPress -> Nginx.

2. **Automação via Interface de Comando (`Makefile`)**:
   - `make up`: Automatiza a criação prévia dos diretórios de dados no host com `sudo mkdir -p` e aplica permissões amplas (`chmod 777`) para evitar conflitos de UID/GID entre o host e os usuários internos dos containers (`mysql`, `www-data`).
   - `make down`: Finaliza e remove os containers de forma limpa.
   - `make fclean`: Alvo crítico que executa a limpeza profunda, removendo não apenas os containers, mas também os volumes e os dados persistidos no sistema de arquivos do host (`rm -rf ~/data`).

### Racional das Escolhas
- **Bind Mounts vs Volumes Nomeados**: Optou-se por bind mounts explícitos no host para facilitar a auditoria dos dados e cumprir a exigência do subject de armazenamento em caminhos específicos.
- **Portas Expostas**: Apenas o serviço `nginx` expõe a porta `443`. O tráfego interno (porta 9000 para PHP e 3306 para SQL) circula exclusivamente dentro da rede `inception_network`.

### Problemas Resolvidos (Troubleshooting)

- **Erro: lstat .../srcs/srcs: no such file or directory**:
  - **Sintoma**: O comando `make up` falhou durante a fase de build com erro de diretório inexistente.
  - **Causa Raiz**: No arquivo `docker-compose.yml`, o `context` de build estava definido como `.` (diretório atual, que é `srcs/`). No entanto, os caminhos para os `dockerfile` incluíam o prefixo `srcs/` (ex: `srcs/requirements/nginx/Dockerfile`), resultando em uma busca por `srcs/srcs/requirements/...`.
  - **Solução Aplicada**: Os caminhos dos Dockerfiles foram simplificados para `requirements/{serviço}/Dockerfile`, removendo o prefixo redundante, uma vez que o contexto já aponta para a raiz da pasta de fontes.
  - **Limpeza de Configuração**: Remoção da tag `version: '3.8'` do topo do arquivo YAML para silenciar o aviso de obsolescência do Docker Compose V2, seguindo as recomendações modernas da ferramenta.

- **Erro: Variable is not set / Invalid spec (Empty section between colons)**:
...
  - **Sintoma**: Ao executar `make up`, o console exibiu múltiplos avisos de variáveis não definidas e falhou com o erro `invalid spec: :/var/lib/mysql`.
  - **Causa Raiz**: O Docker Compose tentou montar volumes e configurar o ambiente usando variáveis como `${DB_DATA_PATH}`, mas como o arquivo `.env` dentro da pasta `srcs/` ainda não havia sido preenchido ou não foi detectado, as strings foram interpoladas como vazias. No caso dos volumes, o mapeamento resultou em `:/var/lib/mysql`, o que é sintaticamente inválido para o Docker.
  - **Solução Aplicada**: Criação e configuração do arquivo `srcs/.env` contendo as definições mandatórias:
    ```env
    DOMAIN_NAME=clados-s.42.fr
    MYSQL_DATABASE=wordpress
    WP_DATA_PATH=/home/clados-s/data/wordpress
    DB_DATA_PATH=/home/clados-s/data/mariadb
    ```
  - **Racional**: O Docker Compose busca o arquivo `.env` no diretório onde o comando é executado ou no diretório do arquivo `.yml`. Garantir que este arquivo exista e contenha caminhos absolutos válidos é pré-requisito para o funcionamento do Makefile.

### Próximos Passos
- Execução do comando `make` após a configuração do `.env`.
- Validação do status dos containers com `docker ps`.

---

## [2026-06-04] - Processamento Dinâmico e Automação: Implementação do WordPress com PHP-FPM e WP-CLI

### Contexto
O WordPress é o Sistema de Gerenciamento de Conteúdo (CMS) alvo deste projeto. Diferente de uma instalação manual, aqui utilizamos o **WP-CLI** (Command Line Interface para WordPress) para automatizar completamente o ciclo de vida da aplicação. O serviço é executado via PHP-FPM (FastCGI Process Manager), que processa o código PHP e se comunica com o Nginx via protocolo FastCGI.

### Detalhamento das Etapas e Comandos

1. **Configuração do Pool PHP-FPM (`www.conf`)**:
   - `listen = 0.0.0.0:9000`: Altera a escuta padrão (socket Unix) para um socket TCP na porta 9000, permitindo que o Nginx (em outro container) encaminhe requisições PHP.
   - `user = www-data` / `group = www-data`: Define que os processos PHP rodem com o usuário padrão de servidores web no Debian, garantindo segurança e compatibilidade de permissões.
   - `pm = dynamic`: Gerenciamento dinâmico de processos filhos para otimizar o uso de memória RAM.

2. **Script de Bootstrap com WP-CLI (`wp_start.sh`)**:
   - **Download Automatizado**: `wp core download` baixa a última versão estável do WordPress.
   - **Configuração via Segredos**: `wp config create` utiliza variáveis extraídas de `/run/secrets/` para configurar a conexão com o MariaDB (`dbhost="mariadb:3306"`).
   - **Instalação e Segurança**:
     - `wp core install`: Realiza a instalação do banco de dados, define o título do site e as credenciais do administrador.
     - `wp user create`: Cria um segundo usuário (requisito mandatório do subject) com papel de 'author'.
   - **Sincronização de Permissões**: `chown -R www-data:www-data /var/www/html` garante que o servidor web tenha permissão de escrita para uploads e plugins no volume compartilhado.

3. **Arquitetura da Imagem (`Dockerfile`)**:
   - Instalação do `php-fpm` e `php-mysql` (driver de conexão).
   - Instalação manual do binário `wp-cli.phar` via `wget`.
   - `CMD ["php-fpm8.3", "-F"]`: A flag `-F` (*force non-daemonize*) mantém o serviço em primeiro plano para que o container permaneça ativo.

### Racional das Escolhas
- **WP-CLI vs Download Manual**: O CLI permite um deployment reproduzível e sem interação humana (headless), essencial para ambientes de containers.
- **Porta 9000**: Escolhida por ser o padrão de mercado para FastCGI, facilitando a integração com o bloco `proxy_pass` do Nginx definido anteriormente.

### Próximos Passos
- Criação do arquivo `docker-compose.yml` final.
- Configuração do `Makefile` para orquestrar o ciclo de vida (build, up, down).

---

## [2026-06-04] - Persistência de Dados e Segurança: Implementação do Serviço MariaDB

### Contexto
O serviço MariaDB é o motor de persistência do projeto, responsável por armazenar todo o conteúdo dinâmico do WordPress. Sua implementação exige um cuidado redobrado com a segurança das credenciais e a automação da criação do banco de dados, garantindo que o sistema seja resiliente e pronto para uso imediato após o deployment.

### Detalhamento das Etapas e Comandos

1. **Script de Inicialização Inteligente (`mariadb_start.sh`)**:
   - **Gestão de Permissões**: Execução de `chown -R mysql:mysql` nos diretórios de runtime e dados. Isso é essencial porque os volumes montados pelo Docker podem herdar permissões do host que o usuário `mysql` dentro do container não conseguiria acessar.
   - **Integração com Docker Secrets**: Uso de `cat /run/secrets/...` para extrair senhas. Esta é uma prática recomendada de DevOps para evitar que senhas fiquem expostas em variáveis de ambiente (visíveis via `docker inspect`).
   - **Instalação Base**: `mysql_install_db --user=mysql --datadir=/var/lib/mysql`. Este comando cria as tabelas de sistema do MariaDB (como a tabela `mysql.user`) do zero se o diretório de dados estiver vazio.
   - **Modo Bootstrap**: `mysqld --bootstrap < $TMP_FILE`. O modo bootstrap permite que o MariaDB processe comandos SQL em um ambiente mínimo, sem subir a rede ou permitir conexões externas, ideal para configurar o usuário root e o banco do WordPress com segurança total.

2. **Configuração do Motor de Banco de Dados (`my.cnf`)**:
   - `bind-address = 0.0.0.0`: Por padrão, o MariaDB escuta apenas no localhost. Para permitir que o container do WordPress se comunique com ele através da rede interna do Docker, é mandatório abrir a escuta para todas as interfaces.
   - `port = 3306`: Definição da porta padrão de comunicação.
   - `datadir = /var/lib/mysql`: Aponta para o local onde o volume persistente será montado, garantindo que os dados não sejam perdidos ao reiniciar o container.

3. **Arquitetura da Imagem (`Dockerfile`)**:
   - Baseada em **Debian 13**, mantendo a consistência com o serviço Nginx.
   - **Exposição de Porta**: `EXPOSE 3306` documenta a necessidade de rede para este serviço.
   - **Ponto de Entrada**: O `ENTRYPOINT` aponta para o script de setup, enquanto o `CMD` executa o daemon definitivo com a flag `--bind-address=0.0.0.0` para reforçar a acessibilidade na rede Docker.

### Racional das Escolhas
- **Idempotência**: O script verifica a existência do banco de dados antes de inicializá-lo, permitindo que o container seja reiniciado sem corromper ou tentar recriar dados existentes.
- **Privilégio Mínimo**: Foi criado um usuário específico (`wp_user`) com acesso restrito apenas ao banco de dados do WordPress, seguindo o princípio de segurança de menor privilégio.

### Próximos Passos
- Implementação do serviço WordPress com PHP-FPM.
- Configuração final das redes e volumes no `docker-compose.yml`.

---

## [2026-06-04] - Virtualização e Automação: Criação do Dockerfile para o Serviço Nginx

### Contexto
Um **Dockerfile** é um documento de texto que contém todos os comandos que um usuário chamaria na linha de comando para montar uma imagem de container. Ele funciona como uma "receita" ou *blueprint* que garante que o ambiente de execução seja idêntico, independentemente da máquina onde o container for iniciado, resolvendo o clássico problema do "funciona na minha máquina".

### Detalhamento das Instruções e Comandos

1. **Imagem Base (`FROM debian:13`)**:
   - Define o sistema operacional de partida. A escolha do Debian (versão Trixie/Testing) provê um ambiente leve e estável para a instalação do servidor web.

2. **Gestão de Camadas e Otimização (`RUN`)**:
   - `apt-get update && apt-get install -y nginx openssl`: Atualiza os índices e instala as dependências necessárias em uma única camada.
   - `&& rm -rf /var/lib/apt/lists/*`: Comando crítico de limpeza. Remove os arquivos temporários do gerenciador de pacotes após a instalação, reduzindo significativamente o tamanho final da imagem (camada *read-only*).

3. **Injeção de Ativos (`COPY`)**:
   - Transfere os arquivos de configuração (`nginx.conf`) e scripts de automação (`nginx_start.sh`) do sistema de arquivos do host para dentro da imagem. Isso permite que a imagem já nasça configurada com as regras de SSL e proxy definidas anteriormente.

4. **Definição de Fluxo de Execução (`ENTRYPOINT` vs `CMD`)**:
   - `ENTRYPOINT ["/usr/local/bin/nginx_start.sh"]`: Define o executável principal que sempre será rodado ao iniciar o container. Neste caso, o script que gera os certificados SSL.
   - `CMD ["nginx", "-g", "daemon off;"]`: Define os argumentos padrão que serão passados para o `ENTRYPOINT`. O parâmetro `daemon off;` é vital para containers, pois força o Nginx a rodar em primeiro plano (*foreground*). Se o Nginx rodasse como daemon (fundo), o processo principal do container terminaria imediatamente, causando o encerramento do container.

### Racional das Escolhas
- **Debian 13**: Optou-se por uma versão recente para garantir acesso a bibliotecas de segurança atualizadas.
- **Limpeza de Cache**: A prática de remover os `/var/lib/apt/lists/` é um padrão da indústria para criar imagens mais eficientes e rápidas de serem baixadas (menor superfície de ataque e menor latência de rede).

### Próximos Passos
- Implementação do serviço MariaDB seguindo o mesmo padrão de virtualização.
- Configuração do `docker-compose.yml` para orquestrar o build desta imagem.

---

## [2026-06-04] - Configuração do Servidor Web: Nginx com TLS e Gateway FastCGI

### Contexto
A configuração do servidor web é o ponto central da infraestrutura Inception, atuando como o único ponto de entrada (entrypoint) para o tráfego externo. O arquivo `nginx.conf` foi estruturado para garantir segurança via criptografia moderna e integração eficiente com o processador PHP dinâmico.

### Detalhamento das Etapas e Comandos

1. **Endurecimento de Protocolos (Hardening)**:
   - `listen 443 ssl`: Configura o servidor para aceitar conexões apenas na porta padrão HTTPS.
   - `ssl_protocols TLSv1.2 TLSv1.3`: Restringe a negociação de protocolos às versões mais seguras, conforme exigido pelo subject, desabilitando versões legadas e vulneráveis (como SSLv3 ou TLSv1.1).
   - Referenciamento dos certificados gerados pelo script de setup: `/etc/nginx/ssl/inception.crt` e seu par de chave privada.

2. **Gestão de Conteúdo e Roteamento**:
   - `root /var/www/html`: Define o diretório de arquivos estáticos, que será um ponto de montagem de volume compartilhado com o container WordPress.
   - `index index.php ...`: Define o PHP como o tipo de arquivo de índice prioritário.
   - `try_files $uri $uri/ /index.php?$args`: Implementa "Pretty Permalinks" do WordPress, garantindo que o roteamento interno do CMS funcione corretamente ao redirecionar requisições para arquivos inexistentes para o `index.php`.

3. **Integração de Microserviços (FastCGI Proxying)**:
   - `location ~ \.php$`: Bloco de captura para processamento de scripts dinâmicos.
   - `fastcgi_pass wordpress:9000`: Encaminha as requisições PHP para o container nomeado `wordpress` na porta `9000`. O uso do hostname `wordpress` demonstra a dependência da rede interna do Docker (Docker Network), onde o DNS interno resolve nomes de serviços para seus respectivos IPs.

### Racional das Escolhas
- **Isolamento de Responsabilidades**: O Nginx não processa PHP localmente; ele atua estritamente como um servidor web e proxy reverso. Isso aumenta a segurança e a escalabilidade da infraestrutura.
- **Conformidade com o Subject**: A configuração de TLSv1.2/1.3 é uma exigência técnica eliminatória, aqui estritamente aplicada.

### Próximos Passos
- Criação do `Dockerfile` do Nginx integrando a instalação dos pacotes e a cópia das configurações.
- Definição da rede no `docker-compose.yml` para permitir a resolução do hostname `wordpress`.

---

## [2026-06-04] - Automação de Infraestrutura de Segurança: Script de Setup SSL para Nginx

### Contexto
Para cumprir os requisitos do projeto Inception, o servidor Nginx deve utilizar exclusivamente o protocolo TLS. A criação manual de certificados em cada ambiente viola os princípios de infraestrutura como código (IaC). Portanto, foi implementado um script de inicialização que garante a existência de certificados válidos antes de subir o serviço web.

### Detalhamento das Etapas e Comandos

1. **Gestão de Certificados Digitais**:
   - Criação do diretório `/etc/nginx/ssl` para centralizar os ativos criptográficos.
   - Execução do binário `openssl` com os seguintes parâmetros críticos:
     - `req -x509`: Especifica a criação de um certificado autoassinado seguindo o padrão X.509.
     - `-nodes`: Abreviação para 'no DES', garantindo que a chave privada não seja criptografada com senha, o que impediria o boot automático do Nginx.
     - `-days 365`: Define o período de validade do certificado para um ano.
     - `-newkey rsa:4096`: Gera uma chave RSA de alta segurança (4096 bits) simultaneamente ao certificado.
     - `-subj`: Parâmetro que automatiza o preenchimento dos campos de Identidade do certificado (País, Estado, Localidade, Organização, Unidade Organizacional e Common Name).

2. **Orquestração de Processos via Shell**:
   - Uso da condicional `if [ ! -f ... ]` para garantir a idempotência do script, evitando a regeneração desnecessária de certificados em reinicializações do container.
   - Emprego do comando `exec "$@"`:
     - Este é um padrão de design crucial em Dockerfiles. O `exec` substitui o shell script pelo binário do Nginx.
     - Isso faz com que o Nginx herde o PID 1, permitindo que o container responda corretamente a sinais de encerramento (`SIGTERM`) enviados pelo Docker Daemon.

### Racional das Escolhas
- **Common Name (CN)**: Configurado como `clados-s.42.fr` para alinhar com o domínio exigido pelo subject do projeto.
- **Portabilidade**: Ao embutir a geração do certificado no script de entrypoint, garantimos que qualquer pessoa que clone o repositório e execute o build terá um ambiente funcional e seguro sem configurações manuais externas.

### Próximos Passos
- Configuração do arquivo `nginx.conf` para escuta exclusiva na porta 443.
- Integração do script no `Dockerfile` do Nginx.

---

## [2026-06-03] - Criação da Estrutura de Diretórios e Arquivos de Orquestração

### Contexto
O projeto Inception exige uma organização rigorosa de arquivos para garantir a portabilidade e a manutenção da infraestrutura de microserviços. A estrutura segue o padrão de separação de responsabilidades, isolando arquivos de configuração, scripts de ferramentas e segredos.

### Detalhamento das Etapas e Comandos

1. **Criação Recursiva de Diretórios**:
   - `mkdir -p secrets srcs/requirements/{mariadb,nginx,wordpress}/{conf,tools}`:
     - `mkdir -p`: Cria diretórios pai conforme necessário, evitando erros caso o diretório já exista.
     - `requirements/`: Pasta central que conterá os Dockerfiles e recursos de cada serviço.
     - `conf/`: Reservado para arquivos de configuração estáticos (ex: `nginx.conf`, `my.cnf`).
     - `tools/`: Destinado a scripts de inicialização (entrypoints ou setup scripts) que preparam o ambiente interno do container.

2. **Inicialização de Arquivos Base**:
   - `touch Makefile srcs/docker-compose.yml srcs/.env`:
     - `Makefile`: Será o orquestrador principal para comandos de build, up, down e limpeza (requisito do subject).
     - `docker-compose.yml`: Arquivo de definição dos serviços, redes e volumes.
     - `.env`: Arquivo de variáveis de ambiente que conterá dados sensíveis e configurações parametrizáveis.

3. **Diretório de Segredos**:
   - `secrets/`: Criado para armazenar credenciais que não devem ser versionadas diretamente no código principal, seguindo boas práticas de segurança em DevOps.

### Racional das Escolhas
- **Estrutura de Subdiretórios**: A divisão entre `conf` e `tools` facilita o debug. Se um container falha ao iniciar, sabemos se o erro está na configuração do software ou no script que prepara o container.
- **Localização do .env**: Posicionado dentro de `srcs/` para facilitar a referência automática pelo Docker Compose, que por padrão busca o arquivo `.env` no mesmo diretório do arquivo de composição.

### Notas Técnicas
- **Encapsulamento**: Cada serviço (Nginx, MariaDB, WordPress) possui seu próprio contexto de build, garantindo que um container não tenha acesso a arquivos desnecessários de outro.

### Próximos Passos
- Configuração do `Makefile` para automatizar a criação de volumes no host.
- Preenchimento do `.env` com os dados de domínio e credenciais de banco de dados.
- Escrita do Dockerfile para o MariaDB.

---

## [2026-06-03] - Validação Final da Instalação e Teste de Runtime

### Contexto
Após a instalação dos binários e configuração das permissões de grupo, é imperativo validar se o daemon do Docker está operacional e se o usuário comum consegue orquestrar containers sem privilégios explícitos de root.

### Detalhamento das Etapas e Comandos

1. **Aplicação de Permissões em Tempo Real**:
   - `newgrp docker`: Executado para re-carregar as permissões do grupo `docker` na sessão atual do shell, permitindo a execução dos testes sem necessidade de logout/login.

2. **Execução do Container de Teste**:
   - `docker run hello-world`:
     - **Busca Local**: O Docker primeiro verificou se a imagem `hello-world:latest` existia no armazenamento local.
     - **Pull (Download)**: Como não foi encontrada, o daemon realizou o download das camadas da imagem diretamente do Docker Hub (Digest: `sha256:0e760...`).
     - **Criação e Execução**: O daemon criou um novo container a partir da imagem e executou o binário interno que gera a mensagem de sucesso.
     - **Stream de Saída**: O output do container foi redirecionado para o terminal do usuário `clados-s`.

### Racional Técnico
- **Arquitetura Cliente-Servidor**: O sucesso deste teste prova que o `docker-cli` (cliente) está conseguindo se comunicar corretamente com o `docker-daemon` (servidor) através do Unix socket `/var/run/docker.sock`.
- **Persistência de Imagens**: A imagem agora reside localmente, o que significa que execuções futuras do mesmo comando serão instantâneas, não exigindo novo download.

### Resultados Obtidos
- Mensagem "Hello from Docker!" recebida com sucesso.
- Instalação do Docker Engine e Containerd validada.

### Próximos Passos
- Criação da estrutura de diretórios do projeto seguindo as normas do subject.
- Início da configuração do `docker-compose.yml`.

---

## [2026-06-03] - Instalação dos Binários Docker e Resolução de Permissões de Sistema

### Contexto
Após a configuração do repositório, procedemos com a instalação efetiva dos motores de execução de containers e ferramentas de composição. Nesta etapa, também foi necessário intervir nas permissões de usuário do sistema para permitir o uso do comando sudo.

### Detalhamento das Etapas e Comandos

1. **Gestão de Privilégios (Sudoers)**:
   - Problema: O usuário `clados-s` tentou executar comandos administrativos mas não estava presente no arquivo `/etc/sudoers`.
   - Solução: Acesso ao terminal root via `su -` (login shell) e execução de `usermod -aG sudo clados-s`.
   - Racional: O grupo `sudo` no Debian concede privilégios de administração. A flag `-aG` garante que o usuário seja **adicionado** (append) ao grupo sem ser removido dos grupos atuais.

2. **Instalação dos Pacotes Docker**:
   - `apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`:
     - `docker-ce`: Docker Community Edition Engine. É o núcleo que gerencia os containers.
     - `docker-ce-cli`: Interface de linha de comando para interagir com o daemon do Docker.
     - `containerd.io`: Runtime de container de baixo nível que gerencia o ciclo de vida dos containers (transferência de imagens, execução, armazenamento, rede).
     - `docker-buildx-plugin`: Plugin para capacidades estendidas de build (necessário para builds multi-plataforma e cache avançado).
     - `docker-compose-plugin`: Implementação moderna do Docker Compose (V2) como um subcomando do docker (`docker compose` em vez de `docker-compose`).

3. **Tentativa de Configuração de Grupo Pré-instalação**:
   - Comando: `usermod -aG docker clados-s`.
   - Resultado: Falha com a mensagem `group 'docker' does not exist`.
   - Racional Técnico: O grupo `docker` é criado automaticamente pelos scripts de pós-instalação do pacote `docker-ce`. Como o comando foi executado antes da instalação dos pacotes, o grupo ainda não existia no sistema.

### Problemas Resolvidos (Troubleshooting)
- **clados-s is not in the sudoers file**: Resolvido via conta root. Essencial para que o usuário possa gerenciar o sistema sem trocar de contexto permanentemente.
- **Grupo Docker Inexistente**: Identificado que a ordem de execução deve ser: 1. Instalar pacotes -> 2. Configurar grupos de usuário.

### Próximos Passos
- Executar novamente `usermod -aG docker clados-s` agora que o pacote foi instalado.
- Validar a instalação com `docker --version` e `docker compose version`.

---

## [2026-06-03] - Instalação do Docker Engine e Configuração do Ambiente de Execução

### Contexto
Para o projeto Inception, precisamos de uma instalação nativa do Docker no Debian. Não basta apenas instalar o binário; é necessário configurar o repositório oficial para garantir atualizações de segurança e configurar as permissões de usuário para um fluxo de trabalho sem interrupções por permissões de root.

### Detalhamento das Etapas e Comandos

1. **Gestão de Chaves e Segurança (GPG)**:
   - `install -m 0755 -d /etc/apt/keyrings`: Criamos um diretório específico para chaves de terceiros. A flag `-m 0755` define permissões de leitura e execução para todos, mas escrita apenas para o proprietário (root), garantindo que a chave não seja alterada maliciosamente.
   - `curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg`:
     - `-fsSL`: Silencioso, mostra erros, segue redirecionamentos e baixa de forma segura.
     - `gpg --dearmor`: Converte a chave pública do formato de texto (ASCII) para o formato binário que o `apt` exige.
   - `chmod a+r /etc/apt/keyrings/docker.gpg`: Garante que todos os usuários (incluindo o processo do apt) consigam ler a chave para validar os pacotes.

2. **Configuração do Repositório Oficial**:
   - `echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable"`:
     - `arch=$(dpkg --print-architecture)`: Identifica automaticamente se sua VM é x86_64 ou ARM.
     - `signed-by=...`: Vincula este repositório especificamente à chave que baixamos, impedindo que o sistema aceite pacotes de outros espelhos (mirrors) não oficiais.
     - `$VERSION_CODENAME`: Garante que o repositório seja o correto para a sua versão do Debian (ex: Bullseye ou Bookworm).

3. **Pós-instalação e Permissões de Usuário**:
   - `usermod -aG docker clados-s`: Adiciona o usuário ao grupo `docker`. O daemon do Docker se comunica via um Unix socket que, por padrão, pertence ao grupo `docker`. Sem isso, precisaríamos de `sudo` para cada comando, o que dificulta o uso de scripts e automações.
   - `newgrp docker`: Comando essencial para atualizar as permissões do shell atual. Sem ele, a mudança de grupo só teria efeito após um novo login completo.

### Racional das Escolhas
- **Instalação via Repositório Oficial vs Apt padrão**: O repositório oficial do Docker oferece versões mais recentes e patches de segurança mais rápidos do que os repositórios genéricos do Debian.
- **Uso do diretório /etc/apt/keyrings**: Esta é a recomendação atual (substituindo o antigo `apt-key`), pois isola as chaves de cada repositório, aumentando a segurança do sistema.

### Problemas Resolvidos
- **Erro de Permissão Negada**: Inicialmente, o comando `docker ps` exigia root. Resolvido com a gestão de grupos.

### Próximos Passos
- Instalar o plugin Docker Compose (`docker-compose-plugin`).
- Criar a estrutura de pastas do projeto (srcs/...).

---

## [2026-06-03] - Preparação da VM e Ferramentas Base

### Contexto
Configuração inicial do sistema operacional para garantir que ele tenha as dependências necessárias para comunicação em rede segura e compilação de pacotes.

### Detalhamento das Ferramentas
- **apt-get update/upgrade**: Sincroniza os índices de pacotes e aplica patches de segurança. Crucial em uma instalação limpa para evitar bugs conhecidos.
- **ca-certificates**: Base da confiança em conexões SSL/TLS. Essencial para o Docker se comunicar com o Docker Hub.
- **curl/gnupg**: Ferramentas de transporte e criptografia necessárias para o processo de adição de repositórios externos.
- **sudo/git**: `sudo` para gestão administrativa controlada e `git` para versionamento do código conforme as normas da 42.

---

## [2026-06-03] - Inicialização da Estrutura de Documentação

### Contexto
Definição de normas para o registro técnico. O objetivo é criar um rastro de auditoria que suporte a defesa oral do projeto.

### Decisões
- Ordem cronológica inversa para acesso rápido ao status atual.
- Proibição de emojis para manter um tom estritamente profissional e técnico.
