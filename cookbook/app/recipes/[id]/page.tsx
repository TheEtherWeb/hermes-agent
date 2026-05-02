import Link from "next/link";
import { notFound } from "next/navigation";
import { prisma } from "@/lib/db";
import {
  addRecipeToCookbook,
  toggleFeatured,
  verifyRecipe,
} from "@/app/actions";

export const dynamic = "force-dynamic";

export default async function RecipePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const [recipe, cookbooks] = await Promise.all([
    prisma.recipe.findUnique({
      where: { id },
      include: { ingredients: true },
    }),
    prisma.cookbook.findMany({ orderBy: { createdAt: "desc" } }),
  ]);

  if (!recipe) notFound();

  const steps: string[] = JSON.parse(recipe.steps);
  const totalTime =
    (recipe.prepMinutes ?? 0) + (recipe.cookMinutes ?? 0) || null;

  return (
    <article className="space-y-8">
      <header className="space-y-3">
        <div className="flex flex-wrap items-center gap-2">
          {recipe.featured && <span className="badge-featured">Featured</span>}
          {recipe.verified && <span className="badge-verified">✓ Verified</span>}
          {recipe.cuisine && <span className="chip">{recipe.cuisine}</span>}
          {recipe.mealType && <span className="chip capitalize">{recipe.mealType}</span>}
          {recipe.fromScratch && <span className="chip">From scratch</span>}
        </div>
        <h1 className="text-5xl font-semibold tracking-tight">{recipe.title}</h1>
        {recipe.description && (
          <p className="max-w-2xl text-lg text-ink/70">{recipe.description}</p>
        )}
        <div className="flex flex-wrap gap-4 text-sm text-ink/60">
          {recipe.author && <span>By {recipe.author}</span>}
          {recipe.prepMinutes !== null && <span>Prep {recipe.prepMinutes}m</span>}
          {recipe.cookMinutes !== null && <span>Cook {recipe.cookMinutes}m</span>}
          {totalTime && <span>Total {totalTime}m</span>}
          {recipe.servings !== null && <span>Serves {recipe.servings}</span>}
        </div>
      </header>

      <div className="grid gap-10 lg:grid-cols-[1fr_2fr]">
        <section>
          <h2 className="mb-3 text-xl font-semibold">Ingredients</h2>
          <ul className="space-y-1.5 text-sm">
            {recipe.ingredients.map((ing) => (
              <li key={ing.id} className="flex gap-2">
                <span className="text-ember">•</span>
                <span>{ing.display}</span>
              </li>
            ))}
          </ul>
        </section>

        <section>
          <h2 className="mb-3 text-xl font-semibold">Method</h2>
          <ol className="space-y-3">
            {steps.map((s, i) => (
              <li key={i} className="flex gap-3">
                <span className="mt-0.5 inline-flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-ink text-xs font-medium text-cream">
                  {i + 1}
                </span>
                <p className="text-ink/80">{s}</p>
              </li>
            ))}
          </ol>
        </section>
      </div>

      <section className="border-t border-ink/10 pt-6">
        <h2 className="mb-3 text-xl font-semibold">Save this recipe</h2>
        {cookbooks.length === 0 ? (
          <p className="text-sm text-ink/60">
            No cookbooks yet. <Link href="/cookbooks/new" className="text-ember underline">Create one →</Link>
          </p>
        ) : (
          <form action={addRecipeToCookbook} className="flex flex-wrap items-end gap-2">
            <input type="hidden" name="recipeId" value={recipe.id} />
            <div>
              <label className="label">Add to cookbook</label>
              <select name="cookbookId" className="input min-w-[220px]" required>
                {cookbooks.map((cb) => (
                  <option key={cb.id} value={cb.id}>
                    {cb.name}
                  </option>
                ))}
              </select>
            </div>
            <button className="btn-primary" type="submit">
              Add
            </button>
            <Link href="/cookbooks/new" className="btn-ghost">
              + New cookbook
            </Link>
          </form>
        )}
      </section>

      <section className="rounded-xl border border-dashed border-ink/15 bg-white/40 p-5">
        <h3 className="mb-2 font-semibold">Editor controls</h3>
        <p className="mb-3 text-xs text-ink/60">
          MVP: anyone can verify or feature recipes. Wire to roles later.
        </p>
        <div className="flex flex-wrap gap-2">
          <form action={verifyRecipe}>
            <input type="hidden" name="id" value={recipe.id} />
            <button className="btn-ghost" type="submit">
              {recipe.verified ? "Unverify" : "Mark verified"}
            </button>
          </form>
          <form action={toggleFeatured}>
            <input type="hidden" name="id" value={recipe.id} />
            <button className="btn-ghost" type="submit">
              {recipe.featured ? "Unfeature" : "Feature"}
            </button>
          </form>
        </div>
      </section>
    </article>
  );
}
