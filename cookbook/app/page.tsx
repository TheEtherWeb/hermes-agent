import Link from "next/link";
import { prisma } from "@/lib/db";
import { RecipeCard } from "./components/RecipeCard";

export const dynamic = "force-dynamic";

export default async function Home() {
  const [featured, latest, cookbooks, totalRecipes] = await Promise.all([
    prisma.recipe.findMany({
      where: { featured: true },
      orderBy: { createdAt: "desc" },
      take: 6,
    }),
    prisma.recipe.findMany({
      orderBy: { createdAt: "desc" },
      take: 6,
    }),
    prisma.cookbook.findMany({
      orderBy: { createdAt: "desc" },
      take: 4,
      include: { _count: { select: { recipes: true } } },
    }),
    prisma.recipe.count(),
  ]);

  return (
    <div className="space-y-14">
      <section className="space-y-4">
        <h1 className="text-5xl font-semibold leading-tight tracking-tight">
          Every recipe in the world,<br />
          one cookbook at a time.
        </h1>
        <p className="max-w-2xl text-lg text-ink/70">
          Learn to cook anything. Add recipes, build cookbooks, get recipes
          verified, and figure out dinner from whatever&apos;s in the fridge.
        </p>
        <div className="flex flex-wrap gap-2">
          <Link href="/cook-with" className="btn-primary">
            Cook with what I have
          </Link>
          <Link href="/recipes" className="btn-ghost">
            Browse {totalRecipes} recipes
          </Link>
        </div>
      </section>

      <section>
        <SectionHeader
          title="Featured"
          subtitle="Verified recipes worth cooking tonight"
          href="/recipes?featured=1"
        />
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {featured.map((r) => (
            <RecipeCard key={r.id} recipe={r} />
          ))}
        </div>
      </section>

      <section>
        <SectionHeader title="Latest" href="/recipes" />
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {latest.map((r) => (
            <RecipeCard key={r.id} recipe={r} />
          ))}
        </div>
      </section>

      <section>
        <SectionHeader title="Cookbooks" href="/cookbooks" />
        <div className="grid gap-4 sm:grid-cols-2">
          {cookbooks.map((c) => (
            <Link key={c.id} href={`/cookbooks/${c.id}`} className="card block">
              <h3 className="text-xl font-semibold">{c.name}</h3>
              {c.description && (
                <p className="mt-1 text-sm text-ink/70">{c.description}</p>
              )}
              <div className="mt-3 text-xs text-ink/50">
                {c._count.recipes} recipe{c._count.recipes === 1 ? "" : "s"}
                {c.author ? ` · by ${c.author}` : ""}
              </div>
            </Link>
          ))}
        </div>
      </section>
    </div>
  );
}

function SectionHeader({
  title,
  subtitle,
  href,
}: {
  title: string;
  subtitle?: string;
  href: string;
}) {
  return (
    <div className="mb-4 flex items-end justify-between">
      <div>
        <h2 className="text-2xl font-semibold">{title}</h2>
        {subtitle && <p className="text-sm text-ink/60">{subtitle}</p>}
      </div>
      <Link href={href} className="text-sm text-ember hover:underline">
        See all →
      </Link>
    </div>
  );
}
