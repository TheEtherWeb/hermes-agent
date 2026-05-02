import Link from "next/link";
import { prisma } from "@/lib/db";
import {
  matchRecipes,
  parseIngredientList,
  type RecipeWithIngredients,
} from "@/lib/ingredients";

export const dynamic = "force-dynamic";

export default async function CookWithPage({
  searchParams,
}: {
  searchParams: Promise<{ have?: string }>;
}) {
  const sp = await searchParams;
  const have = sp.have ? parseIngredientList(sp.have) : [];

  const recipes = await prisma.recipe.findMany({
    include: { ingredients: { select: { name: true, display: true } } },
  });

  const candidates: RecipeWithIngredients[] = recipes.map((r) => ({
    id: r.id,
    title: r.title,
    cuisine: r.cuisine,
    mealType: r.mealType,
    verified: r.verified,
    featured: r.featured,
    ingredients: r.ingredients,
  }));

  const matches = have.length > 0 ? matchRecipes(candidates, have) : [];
  const canMakeNow = matches.filter((m) => m.score === 1);
  const closeCalls = matches.filter((m) => m.score < 1 && m.score >= 0.5);

  return (
    <div className="space-y-8">
      <header className="space-y-2">
        <h1 className="text-4xl font-semibold">Cook with what I have</h1>
        <p className="max-w-2xl text-ink/60">
          Tell us what&apos;s in your kitchen. We&apos;ll rank every recipe by how much
          of it you already have. Pantry staples (salt, pepper, oil, water,
          flour) are assumed.
        </p>
      </header>

      <form className="card space-y-3">
        <div>
          <label className="label">Your ingredients</label>
          <textarea
            name="have"
            rows={4}
            defaultValue={sp.have ?? ""}
            placeholder="eggs, tomato, garlic, onion, parmesan, spaghetti, bacon"
            className="input"
          />
          <p className="mt-1 text-xs text-ink/50">
            Comma- or newline-separated. Order doesn&apos;t matter.
          </p>
        </div>
        <div className="flex justify-end">
          <button className="btn-primary" type="submit">
            Find recipes
          </button>
        </div>
      </form>

      {have.length > 0 && (
        <div className="space-y-10">
          <ResultSection
            title="Connect the dots"
            subtitle={`${have.length} ingredient${have.length === 1 ? "" : "s"} → ${matches.length} recipes ranked by match`}
            chips={have}
          />

          {canMakeNow.length > 0 && (
            <Shelf title="You can cook these right now" matches={canMakeNow} />
          )}

          {closeCalls.length > 0 && (
            <Shelf
              title="A short shopping list away"
              matches={closeCalls}
              showMissing
            />
          )}

          {canMakeNow.length === 0 && closeCalls.length === 0 && (
            <p className="text-ink/60">
              Nothing close. Try adding a few more ingredients.
            </p>
          )}
        </div>
      )}
    </div>
  );
}

function ResultSection({
  title,
  subtitle,
  chips,
}: {
  title: string;
  subtitle: string;
  chips: string[];
}) {
  return (
    <section>
      <h2 className="text-2xl font-semibold">{title}</h2>
      <p className="text-sm text-ink/60">{subtitle}</p>
      <div className="mt-3 flex flex-wrap gap-2">
        {chips.map((c, i) => (
          <span key={`${c}-${i}`} className="chip">
            {c}
          </span>
        ))}
      </div>
    </section>
  );
}

function Shelf({
  title,
  matches,
  showMissing,
}: {
  title: string;
  matches: ReturnType<typeof matchRecipes>;
  showMissing?: boolean;
}) {
  return (
    <section>
      <h3 className="mb-3 text-xl font-semibold">{title}</h3>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {matches.map((m) => (
          <Link
            key={m.recipe.id}
            href={`/recipes/${m.recipe.id}`}
            className="card block"
          >
            <div className="flex items-start justify-between gap-3">
              <h4 className="text-lg font-semibold leading-snug">
                {m.recipe.title}
              </h4>
              <ScoreRing score={m.score} />
            </div>
            <div className="mt-2 flex flex-wrap gap-1.5">
              {m.recipe.cuisine && <span className="chip">{m.recipe.cuisine}</span>}
              {m.recipe.mealType && (
                <span className="chip capitalize">{m.recipe.mealType}</span>
              )}
              {m.recipe.verified && <span className="badge-verified">✓</span>}
            </div>
            <p className="mt-3 text-xs text-ink/60">
              {m.haveCount} of {m.totalCount} ingredients
            </p>
            {showMissing && m.missing.length > 0 && (
              <p className="mt-1 line-clamp-2 text-xs text-ember/80">
                Missing: {m.missing.slice(0, 3).join(", ")}
                {m.missing.length > 3 && ` +${m.missing.length - 3} more`}
              </p>
            )}
          </Link>
        ))}
      </div>
    </section>
  );
}

function ScoreRing({ score }: { score: number }) {
  const pct = Math.round(score * 100);
  const color = score === 1 ? "bg-sage" : score >= 0.75 ? "bg-ember" : "bg-ink/40";
  return (
    <div
      className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-xs font-semibold text-white ${color}`}
      title={`${pct}% match`}
    >
      {pct}
    </div>
  );
}
