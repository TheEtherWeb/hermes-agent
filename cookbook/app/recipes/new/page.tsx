import { createRecipe } from "@/app/actions";

export default function NewRecipePage() {
  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <header>
        <h1 className="text-4xl font-semibold">New recipe</h1>
        <p className="text-ink/60">Anyone can add. Verified recipes get the badge.</p>
      </header>
      <form action={createRecipe} className="card space-y-4">
        <Field label="Title" name="title" required placeholder="Grandma's Lasagna" />
        <Field
          label="Description"
          name="description"
          placeholder="One sentence — what makes it good."
        />
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Cuisine" name="cuisine" placeholder="Italian" />
          <div>
            <label className="label">Meal</label>
            <select name="mealType" className="input">
              <option value="">—</option>
              <option value="breakfast">Breakfast</option>
              <option value="lunch">Lunch</option>
              <option value="dinner">Dinner</option>
              <option value="dessert">Dessert</option>
              <option value="snack">Snack</option>
              <option value="basics">Basics / from scratch</option>
            </select>
          </div>
        </div>
        <div className="grid gap-4 sm:grid-cols-3">
          <Field label="Prep (min)" name="prepMinutes" type="number" />
          <Field label="Cook (min)" name="cookMinutes" type="number" />
          <Field label="Servings" name="servings" type="number" />
        </div>
        <Field label="Author" name="author" placeholder="You" />
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" name="fromScratch" />
          Made from scratch (bread, pasta, sauces, broth)
        </label>

        <div>
          <label className="label">Ingredients <span className="text-ink/50">(one per line)</span></label>
          <textarea
            name="ingredients"
            rows={8}
            className="input font-mono text-sm"
            placeholder={"2 cups flour\n1 tsp salt\n3 large eggs"}
            required
          />
        </div>

        <div>
          <label className="label">Steps <span className="text-ink/50">(one per line)</span></label>
          <textarea
            name="steps"
            rows={8}
            className="input"
            placeholder={"Mix the dry ingredients.\nWhisk the eggs and combine.\nKnead 10 minutes."}
            required
          />
        </div>

        <div className="flex justify-end gap-2 pt-2">
          <button className="btn-primary" type="submit">
            Create recipe
          </button>
        </div>
      </form>
    </div>
  );
}

function Field({
  label,
  name,
  type = "text",
  required,
  placeholder,
}: {
  label: string;
  name: string;
  type?: string;
  required?: boolean;
  placeholder?: string;
}) {
  return (
    <div>
      <label className="label">{label}</label>
      <input
        name={name}
        type={type}
        required={required}
        placeholder={placeholder}
        className="input"
      />
    </div>
  );
}
