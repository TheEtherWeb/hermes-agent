import { createCookbook } from "@/app/actions";

export default function NewCookbookPage() {
  return (
    <div className="mx-auto max-w-xl space-y-6">
      <header>
        <h1 className="text-4xl font-semibold">New cookbook</h1>
        <p className="text-ink/60">A collection of recipes you want to come back to.</p>
      </header>
      <form action={createCookbook} className="card space-y-4">
        <div>
          <label className="label">Name</label>
          <input name="name" required className="input" placeholder="Sunday Dinners" />
        </div>
        <div>
          <label className="label">Description</label>
          <input
            name="description"
            className="input"
            placeholder="The slow-cooked, low-and-slow rotation."
          />
        </div>
        <div>
          <label className="label">Author</label>
          <input name="author" className="input" placeholder="You" />
        </div>
        <div className="flex justify-end">
          <button className="btn-primary" type="submit">
            Create cookbook
          </button>
        </div>
      </form>
    </div>
  );
}
