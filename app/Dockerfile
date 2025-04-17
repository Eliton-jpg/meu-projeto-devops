# app/Dockerfile

# Use a imagem base Python completa
FROM python:3.9

# Defina variáveis de ambiente
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

# Defina o diretório de trabalho
WORKDIR /app

# Copie o arquivo de dependências primeiro
COPY requirements.txt .

# Instale as dependências Python
RUN pip install --no-cache-dir -r requirements.txt

# Copie o restante do código da aplicação
COPY . .

# Exponha a porta que a aplicação usa
EXPOSE 8000

# CMD continua comentado/removido
# CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
