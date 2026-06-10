*This project has been created as part of the 42 curriculum by clados-s.*

# Inception - Microservices Infrastructure

## Description and Design Justification
The **Inception** project focuses on creating a robust and secure network infrastructure using **Docker Compose**. The goal is to orchestrate three fundamental services — Nginx, WordPress (with PHP-FPM), and MariaDB — ensuring that each operates in a dedicated container with network isolation and data persistence.

The architecture was designed following the **Separation of Concerns** principle:
- **Nginx**: Acts as the only public Gateway (port 443 via TLSv1.2/1.3), routing dynamic traffic to WordPress.
- **WordPress + PHP-FPM**: Processes application logic and communicates internally with the database.
- **MariaDB**: Manages data persistence in isolation, inaccessible via the external network.

---

## Mandatory Technical Comparisons

### 1. Virtual Machines vs Docker
**Virtual Machines (VMs)** emulate complete hardware and run an entire guest operating system, which consumes significant resources (RAM/CPU) and has a slow boot time. **Docker**, on the other hand, uses container technology that shares the host's OS kernel. This makes containers extremely lightweight, fast, and efficient, as they isolate only the application process and its dependencies.

### 2. Secrets vs Environment Variables
**Environment Variables** are easy to use but can be exposed via commands like `docker inspect` or system logs, representing a risk for sensitive data. **Docker Secrets** allow for secure storage of confidential information (passwords, certificates). In Inception, secrets are mounted as files in `/run/secrets/`, ensuring that passwords are never exposed in plain text within the environment.

### 3. Docker Network vs Host Network
Using the **Host Network** would cause containers to share the host machine's ports directly, eliminating network isolation. The **Docker Network (bridge)** used in this project creates a private virtual network where containers communicate via service names (internal DNS). This allows MariaDB to remain hidden from the outside world, accessible only by WordPress within the `inception_network`.

### 4. Docker Volumes vs Bind Mounts
**Docker Volumes** are managed by Docker and stored in specific areas of the Docker filesystem. **Bind Mounts**, used in Inception, link a specific directory on the host (`/home/clados-s/data/...`) to a directory in the container. This ensures that WordPress and database data persist even if containers are destroyed and facilitates data auditing directly on the virtual machine.

---

## Usage Instructions

### Prerequisites
- Docker and Docker Compose installed.
- Environment variables configured in the `srcs/.env` file.
- Secret files configured in the `secrets/` folder.

### Main Commands
```bash
# Initialize the entire infrastructure (Build + Up)
make

# Stop and remove containers
make down

# Deep clean (Removes containers, networks, images, and PHYSICAL DATA)
make fclean
```

### Access
After running `make`, the site will be available at `https://clados-s.42.fr`.

---

## Resources and Credits
- Official Docker and Docker Compose Documentation.
- WordPress CLI (WP-CLI) Handbook.
- Mozilla SSL Configuration Generator (for TLS directives).

### AI Assistance Disclosure
This project utilized Artificial Intelligence assistance (Gemini CLI) for:
- Drafting technical documentation and development journals.
- Grammar review and Markdown file structuring.
- Assisting in debugging syntax errors in bootstrap scripts.
All infrastructure logic, Dockerfiles, and network configurations were manually reviewed and validated to ensure compliance with 42 requirements.
