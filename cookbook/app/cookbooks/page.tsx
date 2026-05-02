import Link from "next/link";
import { prisma } from "@/lib/db";

export const dynamic = "force-dynamic";

export default async function CookbooksPage() {
  const cookbooks = await prisma.cookbook.findMany({
    orderBy: { createdAt: "desc" },
    include: { _count: { select: { recipes: true } } },
  });

  return (
    <div className="space-y-6">
      <div className="flex items-end justify-between">
        <h1 className="text-4xl font-semibold">Cookbooks</h1>
        <Link href="/cookbooks/new" className="btn-primary">
          + New cookbook
        </Link>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        {cookbooks.map((cb) => (
          <Link key={cb.id} href={`/cookbooks/${cb.id}`} className="card block">
            <h3 className="text-xl font-semibold">{cb.name}</h3>
            {cb.description && (
              <p className="mt-1 text-sm text-ink/70">{cb.description}</p>
            )}
            <div className="mt-3 text-xs text-ink/50">
              {cb._count.recipes} recipe{cb._count.recipes === 1 ? "" : "s"}
              {cb.author ? ` · by ${cb.author}` : ""}
            </div>
          </Link>
        ))}
        {cookbooks.length === 0 && (
          <p className="text-ink/60">No cookbooks yet. Create your first.</p>
        )}
      </div>
    </div>
  );
}
