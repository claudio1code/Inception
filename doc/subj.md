# Inception (v5.0)

## 1. Introdução
[cite_start]Este projeto tem como objetivo expandir os seus conhecimentos em administração de sistemas utilizando o Docker[cite: 14]. [cite_start]Irá virtualizar várias imagens Docker, criando-as numa nova máquina virtual pessoal[cite: 15].

## 2. Diretrizes Gerais
* [cite_start]O projeto tem de ser feito numa Máquina Virtual (VM)[cite: 19].
* [cite_start]Todos os ficheiros necessários para a configuração devem estar localizados numa pasta chamada `srcs`[cite: 20].
* [cite_start]É obrigatório um `Makefile` na raiz do diretório, que deve configurar toda a aplicação (construindo as imagens usando `docker-compose.yml`)[cite: 21, 22].
* [cite_start]O uso de Inteligência Artificial é permitido, mas o aluno deve compreender totalmente o código gerado e ser capaz de o justificar na avaliação[cite: 38].

## 3. Parte Obrigatória

[cite_start]A infraestrutura é composta por diferentes serviços sob regras específicas, utilizando `docker compose`[cite: 75, 76].

### 3.1 Regras de Imagens e Contentores
* [cite_start]Cada imagem Docker tem de ter o mesmo nome do seu serviço correspondente[cite: 77].
* [cite_start]Cada serviço tem de correr num contentor dedicado[cite: 78].
* [cite_start]Os contentores têm de ser construídos a partir da penúltima versão estável do Alpine ou Debian[cite: 79].
* **Proibido:** Utilizar imagens pré-feitas ou de serviços do DockerHub (exceto os sistemas base Alpine/Debian). [cite_start]O aluno tem de escrever os seus próprios `Dockerfiles`[cite: 81, 84].
* [cite_start]**Proibido:** A *tag* `latest` é estritamente proibida[cite: 115].
* [cite_start]Os contentores devem reiniciar em caso de falha de sistema (*crash*)[cite: 92].
* [cite_start]**PID 1:** Os processos principais não devem correr com `tail -f`, `bash`, `sleep infinity` ou loops infinitos[cite: 94, 101, 103].

### 3.2 Rede e Volumes
* [cite_start]**Rede:** Os contentores devem estar ligados através de uma rede Docker interna (`docker-network`)[cite: 91].
* [cite_start]**Proibido:** O uso de `network: host`, `--link` ou `links:` é proibido[cite: 99].
* [cite_start]**Volumes:** A infraestrutura exige dois volumes físicos[cite: 89, 90]:
  1. Base de dados do WordPress.
  2. Ficheiros do site WordPress.
* [cite_start]O caminho dos volumes tem de ser, obrigatoriamente: `/home/<login>/data`[cite: 109, 110].
* [cite_start]O domínio local tem de apontar para o IP local e seguir o formato: `<login>.42.fr` (ex: `clados-s.42.fr`)[cite: 111, 112].

### 3.3 A Arquitetura (Os 3 Serviços)
1. **NGINX:** O único ponto de entrada da infraestrutura. [cite_start]Apenas a porta `443` deve estar aberta, utilizando os protocolos TLSv1.2 ou TLSv1.3[cite: 86, 121].
2. **WordPress + PHP-FPM:** Apenas o WP e o PHP-FPM (sem Nginx). [cite_start]Deve ligar-se à base de dados de forma automática[cite: 87]. A base de dados tem de possuir pelo menos dois utilizadores, incluindo um administrador. [cite_start]O nome de administrador **não pode** conter "admin" ou "administrator"[cite: 106, 107].
3. [cite_start]**MariaDB:** Apenas o serviço MariaDB (sem Nginx)[cite: 88]. [cite_start]O Nginx não tem acesso direto a este contentor e este não pode estar exposto ao exterior[cite: 130, 134].

### 3.4 Segurança de Credenciais
* [cite_start]É obrigatório o uso de ficheiros `.env` para armazenar variáveis de ambiente[cite: 117, 118].
* [cite_start]É altamente recomendado o uso de *Docker Secrets* para gerir informação confidencial[cite: 119].
* [cite_start]**Eliminação Imediata:** Nenhuma password ou API key pode estar visível no repositório Git em texto limpo (*plain text*)[cite: 116, 120].

---

## 4. Requisitos de Documentação Obrigatória

[cite_start]Além da infraestrutura, o repositório **tem** de conter três ficheiros Markdown na sua raiz[cite: 203, 221, 222].

### [cite_start]4.1 README.md [cite: 203]
* [cite_start]A primeira linha deve ser em itálico com a sintaxe exata: *This project has been created as part of the 42 curriculum by <login>.* [cite: 206]
* [cite_start]**Description:** Visão geral do projeto, justificação de *design* e comparações obrigatórias entre[cite: 207, 212, 213]:
  - [cite_start]Virtual Machines vs Docker [cite: 214]
  - [cite_start]Secrets vs Environment Variables [cite: 215]
  - [cite_start]Docker Network vs Host Network [cite: 216]
  - [cite_start]Docker Volumes vs Bind Mounts [cite: 217]
* [cite_start]**Instructions:** Informações sobre a compilação, instalação e execução[cite: 208].
* [cite_start]**Resources:** Documentação utilizada e uma declaração explícita detalhando quais tarefas e partes do projeto utilizaram a assistência de IA[cite: 209].

### [cite_start]4.2 USER_DOC.md (Documentação do Utilizador) [cite: 223]
Explicação simples sobre como:
* [cite_start]Compreender os serviços fornecidos[cite: 224].
* [cite_start]Iniciar e parar a aplicação[cite: 225].
* [cite_start]Aceder ao site web e ao painel administrativo[cite: 226].
* [cite_start]Localizar e gerir credenciais[cite: 227].
* [cite_start]Verificar o correto funcionamento dos serviços[cite: 228].

### [cite_start]4.3 DEV_DOC.md (Documentação do Desenvolvedor) [cite: 229, 230]
Explicação técnica sobre como:
* [cite_start]Configurar o ambiente do zero (pré-requisitos, segredos e ficheiros de configuração)[cite: 232].
* [cite_start]Construir e lançar o projeto utilizando o Makefile e Docker Compose[cite: 233].
* [cite_start]Gerir contentores e volumes com comandos relevantes[cite: 234].
* [cite_start]Identificar onde os dados residem e como é feita a persistência[cite: 235].

---

## 5. Parte Bónus (Opcional)
[cite_start]*Os bónus apenas serão avaliados se toda a parte obrigatória for entregue perfeitamente e estiver a funcionar a 100%[cite: 253, 254].*

[cite_start]Cada serviço extra precisa do seu próprio contentor, `Dockerfile` e volume dedicado (se necessário)[cite: 240]. Os bónus consistem em:
1. [cite_start]**Redis Cache:** Implementar cache para o site WordPress[cite: 242].
2. [cite_start]**Servidor FTP:** Acesso direto ao volume do WordPress[cite: 243].
3. [cite_start]**Site Estático:** Um site (como um currículo) numa linguagem à sua escolha, exceto PHP[cite: 244, 245].
4. [cite_start]**Adminer:** Interface visual de gestão do MariaDB[cite: 246].
5. [cite_start]**Serviço Livre:** Outro serviço considerado útil (requer justificação)[cite: 247, 248].