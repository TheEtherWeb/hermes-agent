// Normalize an ingredient name: lowercase, strip punctuation, drop common
// modifiers ("fresh", "chopped", "to taste") and trailing plurals.
const STOPWORDS = new Set([
  "fresh", "freshly", "ground", "chopped", "diced", "sliced", "minced",
  "grated", "shredded", "to", "taste", "for", "serving", "garnish",
  "optional", "large", "small", "medium", "ripe", "raw", "cooked",
  "boneless", "skinless", "of", "a", "an", "the", "and", "or",
]);

export function normalizeIngredient(input: string): string {
  const cleaned = input
    .toLowerCase()
    .replace(/\([^)]*\)/g, " ")
    .replace(/[^a-z\s-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  const tokens = cleaned
    .split(" ")
    .filter((t) => t && !STOPWORDS.has(t) && !/^\d+$/.test(t));

  if (tokens.length === 0) return cleaned;

  // Singularize common plurals on the last token (the noun head).
  const last = tokens[tokens.length - 1];
  tokens[tokens.length - 1] = depluralize(last);
  return tokens.join(" ");
}

function depluralize(word: string): string {
  if (word.endsWith("ies") && word.length > 4) return word.slice(0, -3) + "y";
  if (word.endsWith("es") && word.length > 3) return word.slice(0, -2);
  if (word.endsWith("s") && word.length > 2 && !word.endsWith("ss"))
    return word.slice(0, -1);
  return word;
}

export function parseIngredientList(raw: string): string[] {
  return raw
    .split(/[,\n]/g)
    .map((s) => s.trim())
    .filter(Boolean);
}

export type RecipeWithIngredients = {
  id: string;
  title: string;
  cuisine: string | null;
  mealType: string | null;
  verified: boolean;
  featured: boolean;
  ingredients: { name: string; display: string }[];
};

export type MatchResult = {
  recipe: RecipeWithIngredients;
  haveCount: number;
  totalCount: number;
  missing: string[];
  score: number; // 0..1
};

// Score each recipe by what fraction of its ingredients the user has.
// Pantry staples (salt, pepper, water, oil) are not penalized when missing.
const PANTRY = new Set([
  "salt", "pepper", "black pepper", "water", "oil", "olive oil",
  "vegetable oil", "sugar", "flour",
]);

export function matchRecipes(
  recipes: RecipeWithIngredients[],
  haveRaw: string[],
): MatchResult[] {
  const have = new Set(haveRaw.map(normalizeIngredient).filter(Boolean));
  const results: MatchResult[] = [];

  for (const recipe of recipes) {
    const required = recipe.ingredients.filter(
      (ing) => !PANTRY.has(ing.name),
    );
    if (required.length === 0) continue;

    const missing: string[] = [];
    let haveCount = 0;
    for (const ing of required) {
      if (haveAny(have, ing.name)) haveCount += 1;
      else missing.push(ing.display);
    }

    const score = haveCount / required.length;
    results.push({
      recipe,
      haveCount,
      totalCount: required.length,
      missing,
      score,
    });
  }

  results.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return b.haveCount - a.haveCount;
  });
  return results;
}

function haveAny(have: Set<string>, ingredientName: string): boolean {
  if (have.has(ingredientName)) return true;
  // Allow substring match: if the user said "tomato" and the recipe wants
  // "cherry tomato", that counts. And vice versa.
  for (const h of have) {
    if (ingredientName.includes(h) || h.includes(ingredientName)) return true;
  }
  return false;
}
