"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { prisma } from "@/lib/db";
import { normalizeIngredient } from "@/lib/ingredients";

function parseSteps(raw: string): string[] {
  return raw
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean);
}

function parseIngredientLines(raw: string): { display: string; name: string }[] {
  return raw
    .split("\n")
    .map((s) => s.trim())
    .filter(Boolean)
    .map((display) => ({ display, name: normalizeIngredient(display) }));
}

export async function createRecipe(formData: FormData) {
  const title = String(formData.get("title") ?? "").trim();
  if (!title) throw new Error("Title is required");

  const ingredientsRaw = String(formData.get("ingredients") ?? "");
  const stepsRaw = String(formData.get("steps") ?? "");
  const ingredients = parseIngredientLines(ingredientsRaw);
  const steps = parseSteps(stepsRaw);

  const recipe = await prisma.recipe.create({
    data: {
      title,
      description: String(formData.get("description") ?? "") || null,
      cuisine: String(formData.get("cuisine") ?? "") || null,
      mealType: String(formData.get("mealType") ?? "") || null,
      prepMinutes: numField(formData, "prepMinutes"),
      cookMinutes: numField(formData, "cookMinutes"),
      servings: numField(formData, "servings"),
      author: String(formData.get("author") ?? "") || "Anonymous",
      fromScratch: formData.get("fromScratch") === "on",
      steps: JSON.stringify(steps),
      ingredients: { create: ingredients },
    },
  });

  revalidatePath("/recipes");
  redirect(`/recipes/${recipe.id}`);
}

export async function verifyRecipe(formData: FormData) {
  const id = String(formData.get("id"));
  const recipe = await prisma.recipe.findUnique({ where: { id } });
  if (!recipe) return;
  await prisma.recipe.update({
    where: { id },
    data: { verified: !recipe.verified, featured: !recipe.verified ? true : recipe.featured },
  });
  revalidatePath(`/recipes/${id}`);
  revalidatePath("/recipes");
  revalidatePath("/");
}

export async function toggleFeatured(formData: FormData) {
  const id = String(formData.get("id"));
  const recipe = await prisma.recipe.findUnique({ where: { id } });
  if (!recipe) return;
  await prisma.recipe.update({
    where: { id },
    data: { featured: !recipe.featured },
  });
  revalidatePath(`/recipes/${id}`);
  revalidatePath("/");
}

export async function createCookbook(formData: FormData) {
  const name = String(formData.get("name") ?? "").trim();
  if (!name) throw new Error("Name is required");
  const cb = await prisma.cookbook.create({
    data: {
      name,
      description: String(formData.get("description") ?? "") || null,
      author: String(formData.get("author") ?? "") || "Anonymous",
    },
  });
  revalidatePath("/cookbooks");
  redirect(`/cookbooks/${cb.id}`);
}

export async function addRecipeToCookbook(formData: FormData) {
  const cookbookId = String(formData.get("cookbookId"));
  const recipeId = String(formData.get("recipeId"));
  if (!cookbookId || !recipeId) return;
  await prisma.cookbookRecipe.upsert({
    where: { cookbookId_recipeId: { cookbookId, recipeId } },
    create: { cookbookId, recipeId },
    update: {},
  });
  revalidatePath(`/cookbooks/${cookbookId}`);
}

export async function removeRecipeFromCookbook(formData: FormData) {
  const cookbookId = String(formData.get("cookbookId"));
  const recipeId = String(formData.get("recipeId"));
  await prisma.cookbookRecipe.delete({
    where: { cookbookId_recipeId: { cookbookId, recipeId } },
  });
  revalidatePath(`/cookbooks/${cookbookId}`);
}

export async function importCookbook(formData: FormData) {
  // Copy every recipe from `sourceId` into `targetId`. Lets you slurp a
  // featured chef's cookbook into your own.
  const sourceId = String(formData.get("sourceId"));
  const targetId = String(formData.get("targetId"));
  if (!sourceId || !targetId || sourceId === targetId) return;
  const entries = await prisma.cookbookRecipe.findMany({
    where: { cookbookId: sourceId },
  });
  for (const e of entries) {
    await prisma.cookbookRecipe.upsert({
      where: { cookbookId_recipeId: { cookbookId: targetId, recipeId: e.recipeId } },
      create: { cookbookId: targetId, recipeId: e.recipeId },
      update: {},
    });
  }
  revalidatePath(`/cookbooks/${targetId}`);
}

function numField(fd: FormData, key: string): number | null {
  const v = String(fd.get(key) ?? "").trim();
  if (!v) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}
