import mongoose from "mongoose";
import { config } from "../config";

export async function connectMongo(): Promise<void> {
  try {
    await mongoose.connect(config.mongodbUrl);
    console.log("MongoDB connected");
  } catch (err) {
    console.error("MongoDB connection error:", err);
  }
}

// Mongoose schemas
const newsArticleSchema = new mongoose.Schema({
  article_id: String,
  title: String,
  body: String,
  url: String,
  source: String,
  published_at: Date,
  symbols: [String],
  symbol: String,
  sentiment: {
    positive: Number,
    negative: Number,
    neutral: Number,
    weighted_score: Number,
    label: String,
    confidence: Number,
  },
});

export const NewsArticle = mongoose.model("NewsArticle", newsArticleSchema, "news_articles");
