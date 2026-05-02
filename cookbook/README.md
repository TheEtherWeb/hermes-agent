# Cookbook

Every recipe in the world, one cookbook at a time.

A standalone Next.js app living inside `hermes-agent/cookbook/`. Not part of the
hermes runtime — just sharing the repo.

## What it does today (MVP)

- **Recipes** — browse, filter by cuisine / meal, view full recipe with
  ingredients + numbered method.
- **Add a recipe** — anyone can submit. Fields for cuisine, meal type, prep /
  cook time, servings, and a "from scratch" flag for things like sourdough,
  fresh pasta, pizza dough.
- **Cookbooks** — create your own collections of recipes. Add any recipe to
  any cookbook. Import an entire cookbook into another one with one click.
- **Verified + Featured** — recipes carry `verified` and `featured` flags.
  Verified recipes show a green badge; featured ones surface on the home
  page shelf.
- **Cook with what I have** — paste a comma-separated list of ingredients,
  get every recipe ranked by how much of it you already have. Two shelves:
  "you can cook these right now" (100% match) and "a short shopping list
  away" (≥50%). Pantry staples (salt, pepper, oil, water, flour, sugar) are
  assumed and don't count against you. Ingredient matching is case-insensitive
  with substring fallback ("tomato" matches "cherry tomato" and vice versa).

The seed ships 18 recipes across American, Italian, Indian, Mexican,
Vietnamese, Thai, French, Filipino, and Middle Eastern cuisines, plus
breakfast, lunch, dinner, dessert, and from-scratch basics (sourdough,
fresh pasta dough, pizza dough).

## Stack

- Next.js 14 (App Router, Server Actions)
- Prisma + SQLite
- Tailwind CSS
- TypeScript

## Run it

```bash
cd hermes-agent/cookbook
npm install
cp .env.example .env
npm run db:reset   # creates schema + seeds 18 recipes + 2 starter cookbooks
npm run dev
```

Then open http://localhost:3000.

## Scripts

- `npm run dev` — start the dev server
- `npm run build` — production build
- `npm run db:push` — sync schema to SQLite
- `npm run db:seed` — load sample data
- `npm run db:reset` — wipe + reseed

## Data model

```
Recipe ─┬─< RecipeIngredient (name, display)
        └─< CookbookRecipe >─ Cookbook
```

`Recipe.steps` is stored as a JSON-encoded `string[]` (SQLite has no native
JSON type). `RecipeIngredient.name` is a normalized lowercase noun used by the
matcher; `display` is the human-readable line shown on the recipe page.

## Roadmap (deferred from MVP)

- Auth + per-user cookbooks (currently single-shared-world)
- Featured chef profiles
- Michelin-style 1–3 star rating system on verified recipes
- Connect-the-dots mode (visual UI: drag pantry items onto a board, draw lines
  between matching recipes — current `/cook-with` page is the list-view
  precursor)
- Recipe import from URL
- Photo uploads
- Comments / forking
