import Link from "next/link";

type Props = {
  recipe: {
    id: string;
    title: string;
    description: string | null;
    cuisine: string | null;
    mealType: string | null;
    prepMinutes: number | null;
    cookMinutes: number | null;
    verified: boolean;
    featured: boolean;
  };
};

export function RecipeCard({ recipe }: Props) {
  const totalTime =
    (recipe.prepMinutes ?? 0) + (recipe.cookMinutes ?? 0) || null;
  return (
    <Link href={`/recipes/${recipe.id}`} className="card block">
      <div className="flex items-start justify-between gap-3">
        <h3 className="text-xl font-semibold leading-snug">{recipe.title}</h3>
        <div className="flex shrink-0 flex-col items-end gap-1">
          {recipe.featured && <span className="badge-featured">Featured</span>}
          {recipe.verified && <span className="badge-verified">Verified</span>}
        </div>
      </div>
      {recipe.description && (
        <p className="mt-2 line-clamp-2 text-sm text-ink/70">{recipe.description}</p>
      )}
      <div className="mt-3 flex flex-wrap gap-2">
        {recipe.cuisine && <span className="chip">{recipe.cuisine}</span>}
        {recipe.mealType && <span className="chip capitalize">{recipe.mealType}</span>}
        {totalTime && <span className="chip">{totalTime} min</span>}
      </div>
    </Link>
  );
}
