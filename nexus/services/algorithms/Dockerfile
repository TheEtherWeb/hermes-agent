FROM python:3.12-slim

WORKDIR /app

# System deps: TA-Lib requires C library
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ libpq-dev wget curl \
    && wget -q https://sourceforge.net/projects/ta-lib/files/ta-lib/0.4.0/ta-lib-0.4.0-src.tar.gz \
    && tar -xzf ta-lib-0.4.0-src.tar.gz \
    && cd ta-lib && ./configure --prefix=/usr && make && make install \
    && cd .. && rm -rf ta-lib ta-lib-0.4.0-src.tar.gz \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download FinBERT model into the image layer (avoids runtime download)
RUN python -c "\
from transformers import AutoTokenizer, AutoModelForSequenceClassification; \
AutoTokenizer.from_pretrained('ProsusAI/finbert'); \
AutoModelForSequenceClassification.from_pretrained('ProsusAI/finbert'); \
print('FinBERT cached successfully')"

COPY . .

CMD ["celery", "-A", "celery_app", "worker", "--loglevel=info", \
     "--queues=sentinel,oracle,phantom,accuracy,default", \
     "--concurrency=4"]
