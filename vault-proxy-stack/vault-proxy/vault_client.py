import os
import time
import hvac
from requests.exceptions import ConnectionError

def get_secret_with_retry(max_retries=5, delay=2):
    # Read token from file
    token_path = os.getenv('VAULT_TOKEN_PATH', '/tmp/vault_token')
    try:
        with open(token_path, 'r') as f:
            token = f.read().strip()
    except IOError:
        token = None

    client = hvac.Client(
        url=os.getenv('VAULT_PROXY_ADDR', 'http://vault-proxy:8100'),
        token=token
    )

    for attempt in range(max_retries):
        try:
            if not client.sys.is_initialized():
                raise ConnectionError("Vault proxy not reachable")

            if not client.is_authenticated():
                time.sleep(10)
                raise PermissionError("Not authenticated with Vault proxy")

            secret = client.read(os.getenv('SECRET_PATH', 'secret/data/appset'))
            if secret and 'data' in secret:
                return secret['data']['data']
            raise ValueError("Secret not found")

        except (ConnectionError, PermissionError, ValueError) as e:
            print(f"Attempt {attempt + 1} failed: {str(e)}")
            if attempt == max_retries - 1:
                raise
            time.sleep(delay)


if __name__ == "__main__":
    try:
        secrets = get_secret_with_retry()
        print("Successfully retrieved secrets:")
        for k, v in secrets.items():
            print(f"{k}: {v}")
    except Exception as e:
        print(f"Critical error: {str(e)}")
        exit(1)
