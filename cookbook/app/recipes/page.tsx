import Link from "next/link";
import { prisma } from "@/lib/db";
import { RecipeCard } from "../components/RecipeCard";

export const dynamic = "force-dynamic";

type Search = {
  q?: string;
  cuisine?: string;
  meal?: string;
  featured?: string;
  verified?: string;
};

export default async function RecipesPage({
  searchParams,
}: {
  searchParams: Promise<Search>;
}) {
  const sp = await searchParams;
  const where: Record<string, unknown> = {};
  if (sp.q) where.title = { contains: sp.q };
  if (sp.cuisine) where.cuisine = sp.cuisine;
  if (sp.meal) where.mealType = sp.meal;
  if (sp.featured) where.featured = true;
  if (sp.verified) where.verified = true;

  const [recipes, cuisines, meals] = await Promise.all([
    prisma.recipe.findMany({ where, orderBy: { createdAt: "desc" } }),
    prisma.recipe.findMany({
      where: { cuisine: { not: null } },
      distinct: ["cuisine"],
      select: { cuisine: true },
    }),
    prisma.recipe.findMany({
      where: { mealType: { not: null } },
      distinct: ["mealType"],
      select: { mealType: true },
    }),
  ]);

  return (
    <div className="space-y-8">
      <div className="flex items-end justify-between">
        <div>
          <h1 className="text-4xl font-semibold">Recipes</h1>
          <p className="text-ink/60">{recipes.length} matching</p>
        </div>
        <Link href="/recipes/new" className="btn-primary">
          + New recipe
        </Link>
      </div>

      <form className="card flex flex-wrap items-end gap-3">
        <div className="grow">
          <label className="label">Search</label>
          <input
            name="q"
            defaultValue={sp.q ?? ""}
            placeholder="Carbonara, sourdough, tacos…"
            className="input"
          />
        </div>
        <Select
          name="cuisine"
          defaultValue={sp.cuisine}
          options={cuisines.map((c) => c.cuisine!).filter(Boolean)}
          label="Cuisine"
        />
        <Select
          name="meal"
          defaultValue={sp.meal}
          options={meals.map((m) => m.mealType!).filter(Boolean)}
          label="Meal"
        />
        <button className="btn-primary" type="submit">
          Filter
        </button>
        <Link href="/recipes" className="btn-ghost">
          Clear
        </Link>
      </form>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {recipes.map((r) => (
          <RecipeCard key={r.id} recipe={r} />
        ))}
        {recipes.length === 0 && (
          <p className="text-ink/60">No recipes yet. Try clearing your filters.</p>
        )}
      </div>
    </div>
  );
}

function Select({
  name,
  defaultValue,
  options,
  label,
}: {
  name: string;
  defaultValue?: string;
  options: string[];
  label: string;
}) {
  return (
    <div>
      <label className="label">{label}</label>
      <select
        name={name}
        defaultValue={defaultValue ?? ""}
        className="input min-w-[140px]"
      >
        <option value="">All</option>
        {options.map((o) => (
          <option key={o} value={o}>
            {o}
          </option>
        ))}
      </select>
    </div>
  );
}
