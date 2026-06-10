# Inception - Régua de Avaliação (Correction Sheet)

## 1. Preliminares e Instruções Gerais
- [ ] **Estrutura do Repositório:** O `Makefile` está na raiz do repositório. Todos os ficheiros de configuração estão dentro da diretoria `srcs/`.
- [ ] **Sem Imagens Prontas:** Os ficheiros `Dockerfile` começam com imagens de SO base (ex: `FROM debian:bullseye` ou `FROM alpine:3.18`). Não são usadas imagens pré-configuradas como `nginx:alpine` ou `mariadb:latest`.
- [ ] **Proibição da tag "Latest":** Nenhuma imagem base utiliza a tag `latest`.
- [ ] **Segurança de Credenciais:** Nenhuma password ou credencial sensível está em *plain text* nos Dockerfiles, scripts ou ficheiros de configuração enviados para o repositório Git.

## 2. O Teste Base (Build e Execução)
- [ ] **Comando Up:** O comando `make` (ou `make up`) constrói toda a infraestrutura sem erros.
- [ ] **Contentores Ativos:** O comando `docker ps` mostra exatamente três contentores em execução (Nginx, WordPress, MariaDB).
- [ ] **Acesso Web:** Aceder a `https://<login>.42.fr` no navegador carrega o site WordPress com sucesso (ignorando o aviso de certificado autoassinado).

## 3. Rede e Isolamento (Docker Network)
- [ ] **Rede Interna:** O comando `docker network ls` mostra uma rede dedicada criada para o projeto. O parâmetro `--network host` ou a flag `links:` não foram utilizados.
- [ ] **Isolamento do MariaDB:** A tentativa de ligação à porta 3306 a partir do terminal físico do avaliador (ex: usando `nc -zv 127.0.0.1 3306` ou `mysql`) é **recusada**. A base de dados não está exposta ao exterior.

## 4. Nginx (Servidor Web e TLS)
- [ ] **Bloqueio HTTP:** Aceder a `http://<login>.42.fr` (porta 80) falha, recusa a conexão ou redireciona automaticamente para HTTPS. A porta 80 não está exposta no `docker-compose.yml`.
- [ ] **Exclusividade TLS:** O servidor suporta apenas TLSv1.2 e/ou TLSv1.3. Conexões forçadas com TLSv1.1 ou inferiores são rejeitadas pelo servidor.

## 5. WordPress e MariaDB (Configuração Interna)
- [ ] **Mapeamento de Volumes:** As diretorias físicas `/home/<login>/data/wordpress` e `/home/<login>/data/mariadb` (ou caminhos equivalentes exigidos) existem no host e contêm os dados da aplicação.
- [ ] **Automação de Utilizadores:** O painel de administração do WordPress exibe a criação de pelo menos **dois utilizadores**. 
- [ ] **Regra do Administrador:** O nome de utilizador com privilégios de Administrador **não contém** as palavras `admin` ou `administrator` (em qualquer variação de maiúsculas/minúsculas).
- [ ] **Processos PID 1:** Executar `docker exec -it <nome_contentor> ps aux` comprova que os processos principais (nginx, php-fpm, mysqld/mariadb) estão a correr como **PID 1**, e não como processos secundários de um shell `/bin/sh` ou `bash`.
- [ ] **Segurança do Root DB:** A tentativa de ligação ao MariaDB dentro do contentor usando o utilizador *root* sem fornecer uma password é **negada**.

## 6. Persistência de Dados (O Teste de Destruição)
- [ ] **Passo 1 (Criação):** O avaliador cria um novo artigo, página ou altera um título no WordPress.
- [ ] **Passo 2 (Destruição):** O comando `make down` é executado, destruindo contentores e a rede.
- [ ] **Passo 3 (Reinicialização):** O comando `make up` reconstrói a infraestrutura.
- [ ] **Passo 4 (Validação):** O site volta a ficar online e a alteração/artigo criado no Passo 1 continua presente e intacto.

## 7. Makefile Avançado (Limpeza)
- [ ] O comando `make fclean` (ou `make clean`, conforme definido para destruição total) para todos os contentores, apaga a rede, elimina as imagens construídas localmente (`docker rmi`) e destrói os volumes do Docker (`docker volume rm`). O ambiente volta ao estado limpo.

---

## 8. Parte Bónus 
*(Avaliador só prossegue se a secção mandatório estiver 100% correta e funcional)*

- [ ] **Cache Redis:** O contentor Redis está ativo e o WordPress está configurado (via plugin automático ou manual) para utilizá-lo como cache de objetos.
- [ ] **Servidor FTP:** É possível conectar ao contentor FTP e transferir ficheiros diretamente para a diretoria do WordPress.
- [ ] **Adminer:** O painel web do Adminer está acessível e permite gerir a base de dados do MariaDB através do navegador.
- [ ] **Site Estático:** Um site HTML/CSS simples está acessível, roteado pelo Nginx (ex: numa sub-rota ou porta específica) sem utilizar PHP.
- [ ] **Serviço Extra Livre:** O serviço extra escolhido pelo aluno (Portainer, Uptime Kuma, etc.) está ativo, funcional e integrado na rede da infraestrutura.