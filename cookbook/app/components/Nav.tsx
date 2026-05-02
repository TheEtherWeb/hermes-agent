import Link from "next/link";

export function Nav() {
  return (
    <header className="border-b border-ink/10 bg-white/70 backdrop-blur">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-4">
        <Link href="/" className="font-display text-2xl font-semibold tracking-tight">
          Cookbook
        </Link>
        <nav className="flex items-center gap-1 text-sm">
          <NavLink href="/recipes">Recipes</NavLink>
          <NavLink href="/cookbooks">Cookbooks</NavLink>
          <NavLink href="/cook-with">Cook with what I have</NavLink>
          <Link href="/recipes/new" className="btn-primary ml-2">
            New recipe
          </Link>
        </nav>
      </div>
    </header>
  );
}

function NavLink({ href, children }: { href: string; children: React.ReactNode }) {
  return (
    <Link
      href={href}
      className="rounded-md px-3 py-2 text-ink/70 hover:bg-ink/5 hover:text-ink"
    >
      {children}
    </Link>
  );
}
