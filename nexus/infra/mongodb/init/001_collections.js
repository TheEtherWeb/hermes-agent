// MongoDB initialization script — runs once when container is first created
// Executed as 'nexus' database

db = db.getSiblingDB('nexus');

// ── news_articles ────────────────────────────────────────────────────────────
db.createCollection('news_articles');
db.news_articles.createIndex({ symbol: 1, published_at: -1 });
db.news_articles.createIndex({ source: 1, published_at: -1 });
db.news_articles.createIndex({ article_id: 1 }, { unique: true });
// TTL index: auto-delete articles older than 30 days
db.news_articles.createIndex(
    { published_at: 1 },
    { expireAfterSeconds: 2592000 }
);

// ── sentiment_scores ──────────────────────────────────────────────────────────
db.createCollection('sentiment_scores');
db.sentiment_scores.createIndex({ symbol: 1, computed_at: -1 });
db.sentiment_scores.createIndex(
    { article_id: 1, model_version: 1 },
    { unique: true }
);
// TTL: delete sentiment records after 7 days
db.sentiment_scores.createIndex(
    { computed_at: 1 },
    { expireAfterSeconds: 604800 }
);

// ── sec_filings ───────────────────────────────────────────────────────────────
db.createCollection('sec_filings');
db.sec_filings.createIndex({ symbol: 1, filed_at: -1 });
db.sec_filings.createIndex({ form_type: 1, filed_at: -1 });
db.sec_filings.createIndex({ accession_number: 1 }, { unique: true });

print('NEXUS MongoDB collections and indexes created successfully.');
