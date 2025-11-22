# Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Copie des requirements et installation
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# On copie le script
COPY producers.py .

# On lance la boucle infinie
CMD ["python", "producers.py"]