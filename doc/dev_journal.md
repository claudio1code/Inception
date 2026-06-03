# Diário de Desenvolvimento - Inception

Este arquivo serve para registrar todo o progresso, decisões técnicas e obstáculos enfrentados durante o desenvolvimento do projeto Inception da 42.

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
