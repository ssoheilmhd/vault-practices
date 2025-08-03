FROM python:3.9-slim

ENV PYTHONUNBUFFERED=1 \
    VAULT_PROXY_ADDR="http:/<Vault-Addr>:<Vault-Port>"

RUN pip install --no-cache-dir hvac python-dotenv

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

HEALTHCHECK --interval=30s --timeout=3s \
  CMD python -c "import hvac; hvac.Client(url='${VAULT_PROXY_ADDR}').is_authenticated()" || exit 1

CMD ["python", "vault_client.py"]
