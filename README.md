
```
# Teste Técnico DevOps Jr: Implantação de Aplicação Web com CI/CD

## Introdução

Este repositório documenta a solução desenvolvida para o teste técnico de Engenheiro DevOps Jr. O objetivo era configurar um ambiente automatizado e escalável para implantar uma aplicação web Django (com PostgreSQL e MongoDB) em contêineres Docker, orquestrados com Kubernetes (Kind localmente), e implementar um pipeline de CI/CD com Jenkins. O ambiente de staging simulou serviços AWS usando LocalStack e Terraform, enquanto stacks auxiliares (Monitoramento, Logging, Qualidade) foram gerenciadas com Docker Compose.

## Cenário Proposto

Implantar uma aplicação web Python/Django em staging (local) e produção (AWS - *não abordado neste teste*).
*   **Banco de Dados:** PostgreSQL (aplicação)
*   **Logs:** MongoDB (aplicação)
*   **Infraestrutura:** Docker, Kubernetes (Kind localmente)
*   **Automação:** Terraform (IaC), Jenkins (CI/CD)
*   **Staging Local:** LocalStack para simular AWS (S3, DynamoDB)
*   **Monitoramento:** Prometheus, Grafana, Loki
*   **Qualidade:** SonarQube
*   **Logging Centralizado:** ELK Stack (Elasticsearch, Logstash, Kibana)
*   **Ingress:** Nginx Ingress Controller (Helm)

## Arquitetura Adotada (Ambiente Staging Local)

*   **Host:** Ubuntu Linux
*   **Orquestração:** Kubernetes (cluster local via Kind)
*   **Infraestrutura como Código (IaC):** Terraform para provisionar:
    *   Recursos AWS simulados no LocalStack (S3 Bucket, Tabela DynamoDB).
    *   Cluster Kubernetes Kind.
*   **Conteinerização:** Docker para a aplicação Django e serviços auxiliares.
*   **CI/CD:** Jenkins rodando em Docker, com pipeline definido em `Jenkinsfile`.
*   **Ingress:** Nginx Ingress Controller instalado via Helm no cluster Kind.
*   **Stacks Auxiliares (Docker Compose):**
    *   **LocalStack:** Simulação AWS.
    *   **Monitoramento:** Prometheus, Grafana, Loki, Promtail.
    *   **Qualidade:** SonarQube, PostgreSQL (para SonarQube).
    *   **Logging:** Elasticsearch, Logstash, Kibana.
*   **Aplicação:** Fork do Django CRM conteinerizado.

*(Um diagrama visual poderia ser adicionado aqui em `/docs/diagrama-arquitetura.png`)*

## Estrutura do Repositório

```

.
├── app/ # Código fonte da aplicação Django CRM (fork) + Dockerfile + sonar-project.properties
├── Dockerfile.jenkins # Dockerfile para customizar a imagem Jenkins (instalar Docker CLI)
├── docker-compose-jenkins.yml # Docker Compose para iniciar o Jenkins
├── docker-compose-localstack.yml # Docker Compose para iniciar o LocalStack
├── infra/
│ ├── k8s/ # Manifestos Kubernetes (Deployment, Service, Ingress)
│ ├── kind/ # Configuração Terraform para criar o cluster Kind
│ └── localstack/ # Configuração Terraform para provisionar recursos no LocalStack
├── jenkins/
│ └── Jenkinsfile # Definição do pipeline CI/CD declarativo
├── logging/ # Configuração da stack ELK (docker-compose.elk.yaml, logstash.conf)
├── monitoring/ # Configuração da stack de Monitoramento (docker-compose.yaml, prometheus.yml, etc.)
├── sonarqube/ # Configuração da stack SonarQube (docker-compose.yaml)
├── .gitignore
├── kind-kubeconfig-*.yaml # Arquivos kubeconfig gerados/editados (não essenciais para commit)
└── README.md # Este arquivo

**text**

```
## Pré-requisitos

As seguintes ferramentas precisam estar instaladas no ambiente Ubuntu:

*   Git
*   Docker & Docker Compose plugin (v2)
*   Terraform (~> 1.x)
*   Kind (~> v0.20)
*   kubectl (~> 1.2x)
*   Helm (~> v3.x)
*   Python 3 & Pip (para LocalStack CLI, se usado)
*   AWS CLI v2 (opcional, para interagir com LocalStack manualmente)
*   Java JDK (ex: 17 - necessário se o Jenkins não tiver embutido ou para o scanner SonarQube)
*   `nc` (netcat - usado para teste de log ELK)
*   `curl` (para testes de API/saúde)

## Configuração do Ambiente (Passo a Passo)

**Observação Importante:** Durante o desenvolvimento, foi necessário mover o diretório raiz de dados do Docker para uma partição com mais espaço (`/mnt/docker_data` neste caso) devido a limitações de disco na partição raiz. Os comandos para isso estão documentados na seção de Desafios.

**1. Clonar o Repositório:**

```bash
git clone https://github.com/Eliton-jpg/meu-projeto-devops.git
cd meu-projeto-devops
```

**2. Criar Rede Docker Compartilhada:**

Uma rede dedicada foi criada para permitir a comunicação entre Jenkins e SonarQube usando nomes de serviço.

**bash**

```
docker network create devops-net
```

**3. Infraestrutura Local (LocalStack + Terraform):**

* **Objetivo:** Simular serviços AWS (S3, DynamoDB) localmente.
* **Iniciar LocalStack:**
  **bash**

  ```
  docker compose -f docker-compose-localstack.yml up -d
  sleep 15 # Aguardar inicialização
  ```
* **Provisionar Recursos com Terraform:**
  **bash**

  ```
  cd infra/localstack
  terraform init -upgrade
  terraform apply --auto-approve
  cd ../..
  ```
* **Arquivos:** `infra/localstack/*.tf`, `docker-compose-localstack.yml`.

**4. Cluster Kubernetes (Kind + Terraform):**

* **Objetivo:** Criar um cluster Kubernetes local para staging.
* **Criar Cluster:**
  **bash**

  ```
  cd infra/kind
  # Limpar estado antigo se recriando após delete manual
  terraform state rm kind_cluster.staging_cluster || true
  terraform init -upgrade
  terraform apply --auto-approve
  cd ../..
  ```
* **Configuração:** O `infra/kind/main.tf` define um nó control-plane e um worker, e mapeia as portas 80 e 443 do nó control-plane para as portas 8080 e 8443 do host, respectivamente, para permitir o acesso via Ingress.
* **Configurar `kubectl`:**
  **bash**

  ```
  kubectl config use-context kind-staging-cluster
  kubectl cluster-info # Verificar
  ```
* **Arquivos:** `infra/kind/*.tf`.

**5. Aplicação Django (Fork + Dockerfile):**

* **Objetivo:** Obter o código da aplicação e criar um Dockerfile para conteinerizá-la.
* **Ações:**
  * O código da aplicação (fork de `python019/django_crm`) foi colocado no diretório `app/`.
  * Um `Dockerfile` foi criado em `app/Dockerfile` usando uma imagem base Python 3.9, instalando dependências e definindo o comando de execução (ex: gunicorn).
  * Um arquivo `.dockerignore` foi adicionado em `app/` para otimizar o build.
* **Arquivos:** `app/Dockerfile`, `app/.dockerignore`, código fonte em `app/`.

**6. Ingress Controller (Nginx + Helm):**

* **Objetivo:** Instalar um Ingress Controller para gerenciar o acesso externo aos serviços no cluster Kind.
* **Instalação:**
  **bash**

  ```
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx || true
  helm repo update
  helm uninstall nginx-ingress --namespace ingress-nginx || true # Limpeza opcional
  kubectl delete ns ingress-nginx || true # Limpeza opcional
  helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    --set controller.service.type=NodePort \
    --set controller.service.nodePorts.http=30080 \
    --set controller.service.nodePorts.https=30443 \
    --wait
  ```
* **Verificação:**
  **bash**

  ```
  kubectl get pods -n ingress-nginx
  kubectl get svc -n ingress-nginx
  ```

**7. Stack de Monitoramento (Prometheus, Grafana, Loki):**

* **Objetivo:** Coletar métricas e logs do ambiente.
* **Iniciar Stack:**
  **bash**

  ```
  cd monitoring
  docker compose up -d
  cd ..
  ```
* **Acesso:**

  * Grafana: `http://localhost:3000` (admin/admin)
  * Prometheus: `http://localhost:9090`
* **Configuração Manual:** É necessário configurar as Data Sources no Grafana:

  * Prometheus: URL `http://prometheus:9090`
  * Loki: URL `http://loki:3100`
* **Arquivos:** `monitoring/docker-compose.yaml`, `monitoring/prometheus.yml`, `monitoring/loki-config.yaml`, `monitoring/promtail-config.yaml`.

**8. Stack de Logging (ELK):**

* **Objetivo:** Centralizar logs da aplicação e serviços.
* **Ajustes de Sistema (Necessário para Elasticsearch):**
  **bash**

  ```
  sudo sysctl -w vm.max_map_count=262144
  # Adicionar 'vm.max_map_count=262144' em /etc/sysctl.conf para persistência
  ```
* **Iniciar Stack:**
  **bash**

  ```
  cd logging
  docker compose -f docker-compose.elk.yaml up -d
  cd ..
  ```
* **Acesso:**

  * Kibana: `http://localhost:5601`
* **Configuração Manual (Kibana):**

  1. Acessar Kibana.
  2. Ir para "Stack Management" > "Data Views".
  3. Clicar em "Create data view".
  4. Usar `logstash-*` como Index pattern.
  5. Selecionar `@timestamp` como Time field.
  6. Salvar a Data View.
* **Envio de Logs:** A stack está pronta para receber logs. Para enviar logs da aplicação Django (rodando no Kind) para o Logstash (rodando no host), o próximo passo seria configurar um coletor como o Filebeat como DaemonSet no Kubernetes, apontando para `udp://<IP_DO_HOST>:5000` (GELF) ou `tcp://<IP_DO_HOST>:5044` (Beats). Esta etapa de configuração do Filebeat não foi implementada neste teste. Um log de teste foi enviado manualmente para confirmar o funcionamento da stack ELK:
  **bash**

  ```
  echo '{"version": "1.1","host":"test-host","short_message":"Olá Logstash!","level":6}' | nc -u -w1 localhost 5000
  ```
* **Arquivos:** `logging/docker-compose.elk.yaml`, `logging/logstash/pipeline/logstash.conf`.

**9. Stack de Qualidade de Código (SonarQube):**

* **Objetivo:** Analisar estaticamente o código da aplicação.
* **Ajustes de Sistema (Necessário para Elasticsearch no SonarQube):**
  **bash**

  ```
  sudo sysctl -w vm.max_map_count=262144 # Se ainda não feito para ELK
  ```
* **Iniciar Stack:**
  **bash**

  ```
  cd sonarqube
  docker compose up -d
  cd ..
  ```
* **Acesso:**

  * SonarQube: `http://localhost:9001` (admin/admin -> mudar senha)
* **Configuração Manual (SonarQube):**

  1. Acessar SonarQube.
  2. Criar um novo projeto manualmente:
     * Project Key: `django-crm-app`
     * Display Name: `Django CRM Application`
  3. Gerar um token de autenticação para o Jenkins (Account > Security > Generate Tokens).
* **Configuração Manual (Jenkins):**

  1. Instalar plugin "SonarQube Scanner".
  2. Configurar Credencial "Secret text" com ID `sonarqube-token` contendo o token gerado.
  3. Configurar SonarQube Server em "Configure System":
     * Name: `SonarQube Local`
     * Server URL: `http://sonarqube:9000` (Assumindo comunicação via rede Docker compartilhada `devops-net`)
     * Authentication token: Selecionar a credencial `sonarqube-token`.
  4. Configurar SonarQube Scanner em "Global Tool Configuration":
     * Name: `SonarScanner`
     * Install automatically.
* **Arquivo de Configuração do Scanner:** Criado em `app/sonar-project.properties` para definir a chave do projeto e o diretório fonte.
* **Integração com Pipeline:**

  * **Desafio Encontrado:** Durante a execução do teste, ocorreram dificuldades na configuração correta das ferramentas JDK e SonarScanner dentro do Jenkins (erro `Tool type "jdk" does not have an install of "jdk17" configured` e problemas subsequentes na configuração automática/manual do JDK). Para não bloquear o progresso geral e focar nas outras entregas, **decidiu-se por comentar/remover temporariamente os estágios `SonarQube Analysis` e `Quality Gate` do `Jenkinsfile` final entregue.**
  * **Status:** A stack SonarQube está funcional e acessível, o projeto foi criado, e a configuração básica no Jenkins foi realizada. A integração final no pipeline (`Jenkinsfile`) foi revertida devido aos desafios de configuração da ferramenta JDK no ambiente de teste. Continuarei a desenvolver minhas habilidades para superar esses desafios de configuração em futuras oportunidades.
* **Arquivos:** `sonarqube/docker-compose.yaml`, `app/sonar-project.properties`.

**10. Pipeline CI/CD (Jenkins):**

* **Objetivo:** Automatizar o build, teste (básico) e deploy da aplicação no cluster Kind.
* **Setup Jenkins:**
  * Uma imagem customizada (`Dockerfile.jenkins`) foi usada para incluir o Docker CLI.
  * O Jenkins foi iniciado via `docker-compose-jenkins.yml`.
  * Os containers Jenkins e SonarQube foram conectados à rede Docker `devops-net` para comunicação interna. O Jenkins também foi conectado à rede `kind`.
  * Plugins essenciais foram instalados (Pipeline, Git, GitHub, Credentials, Kubernetes CLI, etc.).
  * Credenciais foram configuradas:
    * `kubeconfig-kind`: Secret file contendo o `kubeconfig` do Kind (editado para usar `server: https://staging-cluster-control-plane:6443`).
    * `sonarqube-token`: Secret text (configurada, mas não usada no pipeline final).
* **Pipeline (`Jenkinsfile`):**
  * Definido em `jenkins/Jenkinsfile` usando sintaxe Declarativa.
  * **Estágios:**
    1. `Checkout`: Clona o repositório Git.
    2. `Build Docker Image`: Constrói a imagem da aplicação usando `docker build`.
    3. `Load Image into Kind`: Carrega a imagem buildada para dentro dos nós do cluster Kind.
    4. `Test Application (Check)`: Executa um `manage.py check` básico dentro de um container temporário.
    5. `Deploy to Kubernetes (Kind)`:
       * Usa `withKubeConfig` para autenticar com o cluster.
       * Usa `sed` para atualizar a tag da imagem no `deployment.yaml`.
       * Usa `kubectl apply` para aplicar os manifestos `deployment.yaml`, `service.yaml`, e `ingress.yaml` (localizados em `infra/k8s/`).
       * Verifica o status do rollout do deployment.
  * **Gatilho:** Configurado no Job Jenkins para usar "GitHub hook trigger for GITScm polling", permitindo o início automático via webhook do GitHub (requer ngrok ou exposição pública do Jenkins).
* **Arquivos:** `jenkins/Jenkinsfile`, `docker-compose-jenkins.yml`, `Dockerfile.jenkins`, `infra/k8s/*.yaml`.

## Executando o Pipeline

1. Certifique-se de que LocalStack, Kind, Nginx Ingress, SonarQube (opcionalmente) e Jenkins estejam rodando.
2. Faça um `git push` para a branch configurada no Job Jenkins (neste caso, `main`).
3. Se o webhook estiver configurado corretamente (via ngrok ou similar), o pipeline iniciará automaticamente.
4. Alternativamente, acesse o Jenkins (`http://localhost:8090`), navegue até o job `django-crm-pipeline` e clique em "Construir agora".
5. Monitore a execução no Console Output ou na interface Blue Ocean.

## Acessando a Aplicação

Devido a dificuldades encontradas para acessar a aplicação diretamente via `localhost:8080` (mapeamento do Kind) ou `localhost:30080` (NodePort do Ingress) no ambiente de teste, o método mais confiável para verificar a aplicação implantada é usando `kubectl port-forward`:

1. Execute em um terminal (e deixe rodando):
   **bash**

   ```
   kubectl port-forward -n ingress-nginx deploy/nginx-ingress-ingress-nginx-controller 8888:80
   ```
2. Acesse a aplicação no navegador: `http://localhost:8888`

## Acessando Ferramentas Auxiliares

* **Jenkins:** `http://localhost:8090`
* **Grafana:** `http://localhost:3000` (Login: admin/admin)
* **Prometheus:** `http://localhost:9090`
* **SonarQube:** `http://localhost:9001` (Login: admin/sua_nova_senha)
* **Kibana:** `http://localhost:5601`

## Fluxo de Desenvolvimento (Branches)

* **Intenção Inicial:** Criar uma branch `develop` para integração contínua e manter a `main` para produção. Features seriam desenvolvidas em branches separadas (ex: `feature/nome-da-feature`), mergeadas em `develop` via Pull Request, e eventualmente `develop` seria mergeada em `main` para releases.
  * Exemplo de fluxo de feature:
    **bash**

    ```
    git checkout develop
    git pull origin develop
    git checkout -b feature/nova-funcionalidade
    # ... fazer alterações e commits ...
    git push origin feature/nova-funcionalidade
    # Abrir PR no GitHub: feature/nova-funcionalidade -> develop
    # Após merge do PR:
    git checkout develop
    git pull origin develop
    ```
* **Execução Real:** Uma branch `develop` foi criada inicialmente. No entanto, durante o processo iterativo de configuração e resolução de problemas, por falta de costume e afinidade com o fluxo estrito em um ambiente de teste individual, acabei utilizando predominantemente a branch `main` para os commits e a configuração do pipeline Jenkins. A estrutura para o fluxo correto está presente, mas a prática durante este teste concentrou-se na `main`.

## Decisões de Design e Desafios

* **Kind:** Escolhido para um cluster Kubernetes local leve e rápido, ideal para desenvolvimento e teste.
* **Terraform:** Utilizado para IaC, permitindo a criação reprodutível da infraestrutura local (LocalStack, Kind).
* **Jenkins:** Selecionado pela flexibilidade e amplo suporte da comunidade, rodando em Docker para isolamento e facilidade de configuração inicial. O pipeline foi escrito em modo Declarativo.
* **Docker Compose:** Usado para gerenciar as stacks auxiliares (LocalStack, Monitoramento, Logging, SonarQube) de forma simples e isolada.
* **Nginx Ingress Controller (Helm):** Padrão de mercado para Ingress no Kubernetes, instalado facilmente via Helm.
* **ELK vs Loki:** Ambas as stacks foram configuradas. ELK foi solicitado especificamente, enquanto Loki (com Promtail) foi configurado como parte da stack de monitoramento padrão com Grafana.
* **Desafio - Espaço em Disco:** A partição raiz ficou sem espaço, exigindo a reconfiguração do Docker para usar um `data-root` em outra partição (`/mnt/docker_data`). Isso foi feito parando o Docker, editando `/etc/docker/daemon.json` e reiniciando o serviço.
* **Desafio - Kubeconfig:** O `kubeconfig` gerado pelo Kind precisou ser editado (`server:` apontando para `staging-cluster-control-plane:6443`) e atualizado na credencial do Jenkins para permitir a comunicação `kubectl` de dentro do container Jenkins. Erros de formatação YAML e dados Base64 corrompidos na credencial causaram falhas no pipeline e exigiram depuração cuidadosa.
* **Desafio - Acesso via Ingress:** O acesso à aplicação via `localhost:8080` (mapeamento Kind) ou `localhost:30080` (NodePort) não funcionou no ambiente de teste, apesar da configuração interna do Kubernetes parecer correta. O `kubectl port-forward` foi usado como workaround funcional.
* **Desafio - Integração SonarQube:** Dificuldades na configuração da ferramenta JDK (`jdk17`) em "Global Tool Configuration" impediram a execução bem-sucedida dos estágios SonarQube no pipeline, levando à decisão de revertê-los temporariamente.

## Próximos Passos / Melhorias

* Implementar testes automatizados robustos (unitários, integração) para a aplicação Django e adicioná-los como um estágio no pipeline Jenkins.
* Configurar o envio de logs da aplicação Django (rodando no Kind) para a stack ELK usando Filebeat como DaemonSet.
* Resolver o problema de acesso direto à aplicação via Ingress/NodePort no Kind.
* Resolver os problemas de configuração do JDK/SonarScanner no Jenkins para habilitar a análise de qualidade no pipeline.
* Implementar o push da imagem Docker para um registry (como Docker Hub) no pipeline.
* Adaptar a configuração Terraform e o pipeline para um ambiente de produção real na AWS (usando EKS, RDS, S3 real, etc.).
* Gerenciar segredos (senhas de banco de dados, tokens) de forma mais segura (ex: Jenkins Credentials, Vault, Secrets Manager).
* Adicionar health checks (liveness/readiness probes) aos manifestos Kubernetes.

## Conclusão / Percentual Entregue

A maioria das tarefas solicitadas foi implementada e configurada com sucesso, demonstrando conhecimento em IaC (Terraform), conteinerização (Docker), orquestração (Kubernetes/Kind), CI/CD (Jenkins), Ingress (Nginx/Helm) e configuração de stacks de monitoramento (Prometheus/Grafana/Loki) e logging (ELK).

* **Entregue com Sucesso:**
  * Repositório GitHub com estrutura e README inicial.
  * Infra LocalStack (S3, DynamoDB) via Terraform.
  * Cluster Kind via Terraform com mapeamento de porta.
  * Dockerfile para a aplicação Django.
  * Pipeline Jenkins funcional (Checkout, Build, Load to Kind, Test Check, Deploy to K8s).
  * Gatilho de webhook funcional (requer ngrok/exposição).
  * Stack de Monitoramento (Prometheus, Grafana, Loki) via Docker Compose.
  * Nginx Ingress Controller via Helm.
  * Stack ELK via Docker Compose com Data View configurada no Kibana.
  * Stack SonarQube via Docker Compose.
* **Entregue Parcialmente / Com Desafios:**
  * **Integração SonarQube no Pipeline:** A stack SonarQube está funcional, mas os estágios no pipeline foram desativados devido a problemas de configuração de ferramentas no Jenkins.
  * **Acesso à Aplicação:** Funcional apenas via `kubectl port-forward` no ambiente de teste.
  * **Fluxo de Branches:** Branch `develop` criada, mas `main` foi usada predominantemente.
  * **Envio de Logs para ELK:** A stack ELK está pronta, mas o envio de logs da aplicação não foi configurado (requer Filebeat).
* **Não Entregue:**
  * Testes automatizados robustos no pipeline.
  * Configuração para ambiente de produção AWS.

Considerando os itens entregues e parcialmente entregues, estima-se que aproximadamente **80-85%** do escopo principal do teste foi abordado e implementado funcionalmente (com workarounds documentados onde necessário). Os desafios encontrados, especialmente com configurações de ferramentas e rede no ambiente local, impediram a conclusão de 100%, mas a arquitetura central e os fluxos principais foram estabelecidos.


mermaid

```
graph TD
    subgraph "Desenvolvedor & Git"
        Dev[Desenvolvedor] -- 1. Git Push --> GitHub[GitHub Repo<br>(Eliton-jpg/meu-projeto-devops)]
    end

    subgraph "CI/CD (Jenkins)"
        Jenkins[Jenkins (Docker)]
        GitHub -- 2. Webhook (via Ngrok) --> Jenkins
        Jenkins -- 3. Checkout Code --> GitHub
        Jenkins -- 4. Docker Build --> DockerDaemon[Docker Daemon<br>(Host)]
        Jenkins -- 5. Kind Load Image --> KindCluster
        Jenkins -- 6. Test (docker run) --> DockerDaemon
        Jenkins -- 8. kubectl apply --> KindCluster
    end

    subgraph "Cluster Kubernetes (Kind)"
        KindCluster[Kind Cluster]
        subgraph "Dentro do Cluster"
            IngressController[Nginx Ingress Controller Pod(s)]
            IngressResource[Ingress Resource]
            AppService[Service (django-crm-service)<br>ClusterIP]
            AppPod1[Pod (django-crm-app)]
            AppPod2[Pod (django-crm-app)]
        end
        KindCluster -- Contém --> IngressController
        KindCluster -- Contém --> IngressResource
        KindCluster -- Contém --> AppService
        KindCluster -- Contém --> AppPod1
        KindCluster -- Contém --> AppPod2

        IngressResource -- Roteia para --> AppService
        AppService -- Seleciona/Encaminha para --> AppPod1
        AppService -- Seleciona/Encaminha para --> AppPod2
    end

    subgraph "Acesso do Usuário (Workaround)"
        User[Usuário (Browser)] -- a. Acessa localhost:8888 --> PortForward[kubectl port-forward<br>(Host)]
        PortForward -- b. Encaminha para --> IngressController
    end

    subgraph "Stacks Auxiliares (Docker Compose no Host)"
        LocalStack[LocalStack]
        Monitoring[Monitoramento<br>(Prometheus, Grafana, Loki)]
        Logging[Logging<br>(Elasticsearch, Logstash, Kibana)]
        Sonar[SonarQube<br>(SonarQube, PostgreSQL)]
    end

    subgraph "Ferramentas de Setup (Manual)"
        Terraform[Terraform] -- Cria/Gerencia --> LocalStackResources[Recursos LocalStack<br>(S3, DynamoDB)]
        Terraform -- Cria/Gerencia --> KindCluster
        Helm[Helm] -- Instala --> IngressController
    end

    %% Conexões Adicionais (Conceituais)
    AppPod1 -- Usa (se configurado) --> LocalStackResources
    AppPod2 -- Usa (se configurado) --> LocalStackResources
    %% Filebeat (Não implementado) -.-> Logstash
    %% Promtail (Docker) --> Loki
    %% Prometheus (Docker) --> Grafana
    %% Loki (Docker) --> Grafana
    %% Elasticsearch (Docker) --> Kibana
    %% Jenkins -- (Análise desativada) --> Sonar

    style Dev fill:#f9f,stroke:#333,stroke-width:2px
    style User fill:#f9f,stroke:#333,stroke-width:2px
    style GitHub fill:#lightgrey,stroke:#333
    style Jenkins fill:#lightblue,stroke:#333,stroke-width:2px
    style KindCluster fill:#lightgreen,stroke:#333,stroke-width:2px
    style DockerDaemon fill:#grey,stroke:#333
    style PortForward fill:#orange,stroke:#333
```

**Explicação Detalhada do Funcionamento:**

1. **Fluxo de CI/CD:**
   * **(1) Git Push:** O desenvolvedor envia alterações de código (commits) para a branch `main` do repositório `Eliton-jpg/meu-projeto-devops` no GitHub.
   * **(2) Webhook:** O GitHub detecta o push e envia uma notificação (payload JSON) via webhook para um URL público (neste caso, fornecido pelo `ngrok`, que tunela para o Jenkins local).
   * **(Jenkins Trigger):** O Jenkins, rodando em um container Docker no host local, recebe a notificação do webhook (ou é iniciado manualmente). O Job `django-crm-pipeline` é disparado.
   * **(3) Checkout:** O Jenkins clona ou atualiza o código fonte do repositório GitHub para seu workspace.
   * **(4) Docker Build:** O Jenkins usa o Docker Daemon do host (através do socket montado) para construir uma nova imagem Docker da aplicação Django (`meu-app-django:<build_number>`) usando o `app/Dockerfile`.
   * **(5) Kind Load Image:** A imagem recém-construída, que existe no Docker Daemon do host, é carregada para dentro dos nós do cluster Kind usando o comando `kind load docker-image`. Isso torna a imagem disponível para o Kubernetes dentro do cluster.
   * **(6) Teste Básico:** O Jenkins executa um teste simples (`python manage.py check`) dentro de um container temporário usando a imagem recém-buildada para uma verificação rápida.
   * **(SonarQube - Desativado):** Os estágios para enviar o código para análise no SonarQube e verificar o Quality Gate foram desativados devido a desafios de configuração no ambiente de teste.
   * **(8) Deploy Kubernetes:**
     * O Jenkins usa a credencial `kubeconfig-kind` (que foi editada para apontar para o control-plane do Kind) para se autenticar no cluster.
     * Ele modifica o arquivo `infra/k8s/deployment.yaml` (usando `sed`) para usar a tag da nova imagem Docker.
     * Ele usa `kubectl apply` para aplicar os manifestos `deployment.yaml`, `service.yaml`, e `ingress.yaml` ao cluster Kind no namespace `default`. Isso cria ou atualiza os respectivos recursos. O Kubernetes então puxa a imagem (que já foi carregada via `kind load`) e cria/atualiza os Pods da aplicação.
     * Ele verifica se o deployment foi concluído com sucesso (`kubectl rollout status`).
