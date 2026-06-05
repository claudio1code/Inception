# Diário de Desenvolvimento - Inception

Este arquivo serve para registrar todo o progresso, decisões técnicas e obstáculos enfrentados durante o desenvolvimento do projeto Inception da 42.

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
