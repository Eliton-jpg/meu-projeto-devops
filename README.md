# Meu Projeto DevOps - Teste Técnico

Este repositório contém a solução para o teste técnico.
# Meu Projeto DevOps - Teste Técnico

Este repositório contém a solução para o teste técnico de DevOps, configurando um ambiente de CI/CD para uma aplicação Python.

## Estrutura do Projeto

*   `app/`: Código fonte da aplicação Django (fork) e Dockerfile.
*   `infra/`: Configurações de Infraestrutura como Código (Terraform).
    *   `localstack/`: Terraform para S3 e DynamoDB no LocalStack.
    *   `kind/`: Terraform para criar cluster Kubernetes com Kind.
    *   `k8s/`: Manifestos Kubernetes (Deployment, Service).
*   `jenkins/`: Arquivo `Jenkinsfile` para o pipeline de CI/CD.
*   `docker-compose-localstack.yml`: Docker Compose para iniciar o LocalStack.
*   `docker-compose-jenkins.yml`: Docker Compose para iniciar o Jenkins.
*   `.gitignore`: Especifica arquivos a serem ignorados pelo Git.
*   `README.md`: Este arquivo.

## Pré-requisitos

*   Git
*   Docker & Docker Compose
*   Terraform
*   kubectl
*   Kind
*   AWS CLI (configurada com perfil `localstack` dummy)

## Setup Inicial

1.  Clone este repositório.
2.  Instale todas as ferramentas listadas em Pré-requisitos.
3.  Clone o fork do `django_crm` para dentro da pasta `app/`:
    ```bash
    git clone https://github.com/SEU_USUARIO/django_crm.git app
    ```
4.  Crie o arquivo `app/Dockerfile` (conteúdo abaixo).

## Como Executar (Até Passo 5)

1.  **Iniciar LocalStack:**
    ```bash
    docker compose -f docker-compose-localstack.yml up -d
    ```
2.  **Provisionar Infra LocalStack:**
    ```bash
    cd infra/localstack
    terraform init
    terraform apply --auto-approve
    cd ../..
    ```
3.  **Criar Cluster Kind:**
    ```bash
    cd infra/kind
    terraform init
    terraform apply --auto-approve
    cd ../..
    kubectl config use-context kind-staging-cluster
    ```
4.  **Iniciar Jenkins:**
    ```bash
    docker compose -f docker-compose-jenkins.yml up -d
    ```
    *   Acesse `http://localhost:8090`.
    *   Obtenha a senha inicial: `docker exec jenkins-server cat /var/jenkins_home/secrets/initialAdminPassword`
    *   Siga o assistente: Instale plugins sugeridos, crie usuário admin.
    *   Configure as credenciais `kubeconfig-kind` (Secret file, usando `~/.kube/config` ou `kind get kubeconfig --name staging-cluster`).
    *   Crie o Pipeline Job ("Nova tarefa"), tipo "Pipeline", aponte para este repositório Git (branch `develop`), script path `jenkins/Jenkinsfile`.

5.  **Executar Pipeline:** Dispare o build manualmente no Jenkins ("Construir agora").

## Fluxo Git

*   Branch principal: `main` (para produção)
*   Branch de desenvolvimento: `develop`
*   Branches de feature: `feature/nome-da-feature` (criadas a partir de `develop`, mescladas de volta em `develop`).
