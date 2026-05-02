import Link from "next/link";
import { notFound } from "next/navigation";
import { prisma } from "@/lib/db";
import { RecipeCard } from "@/app/components/RecipeCard";
import { importCookbook, removeRecipeFromCookbook } from "@/app/actions";

export const dynamic = "force-dynamic";

export default async function CookbookPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const [cookbook, otherCookbooks] = await Promise.all([
    prisma.cookbook.findUnique({
      where: { id },
      include: {
        recipes: {
          orderBy: { addedAt: "desc" },
          include: { recipe: true },
        },
      },
    }),
    prisma.cookbook.findMany({ where: { id: { not: id } } }),
  ]);

  if (!cookbook) notFound();

  return (
    <div className="space-y-8">
      <header className="space-y-2">
        <Link href="/cookbooks" className="text-sm text-ember hover:underline">
          ← All cookbooks
        </Link>
        <h1 className="text-5xl font-semibold tracking-tight">{cookbook.name}</h1>
        {cookbook.description && (
          <p className="max-w-2xl text-lg text-ink/70">{cookbook.description}</p>
        )}
        <div className="text-sm text-ink/60">
          {cookbook.recipes.length} recipe{cookbook.recipes.length === 1 ? "" : "s"}
          {cookbook.author ? ` · by ${cookbook.author}` : ""}
        </div>
      </header>

      {otherCookbooks.length > 0 && (
        <div className="card flex flex-wrap items-end gap-2">
          <div className="grow">
            <h3 className="font-semibold">Import another cookbook</h3>
            <p className="text-xs text-ink/60">
              Pulls every recipe from another cookbook into this one.
            </p>
          </div>
          <form action={importCookbook} className="flex items-end gap-2">
            <input type="hidden" name="targetId" value={cookbook.id} />
            <select name="sourceId" className="input min-w-[220px]" required>
              {otherCookbooks.map((cb) => (
                <option key={cb.id} value={cb.id}>
                  {cb.name}
                </option>
              ))}
            </select>
            <button className="btn-primary" type="submit">
              Import all
            </button>
          </form>
        </div>
      )}

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {cookbook.recipes.map(({ recipe }) => (
          <div key={recipe.id} className="space-y-2">
            <RecipeCard recipe={recipe} />
            <form
              action={removeRecipeFromCookbook}
              className="flex justify-end"
            >
              <input type="hidden" name="cookbookId" value={cookbook.id} />
              <input type="hidden" name="recipeId" value={recipe.id} />
              <button
                className="text-xs text-ink/50 hover:text-ember"
                type="submit"
              >
                Remove from cookbook
              </button>
            </form>
          </div>
        ))}
        {cookbook.recipes.length === 0 && (
          <p className="text-ink/60">
            No recipes yet.{" "}
            <Link href="/recipes" className="text-ember underline">
              Browse recipes
            </Link>{" "}
            and add some.
          </p>
        )}
      </div>
    </div>
  );
}
