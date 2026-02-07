#!/usr/bin/env node

import { writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

const LINKS_DIR = join(import.meta.dirname, "..", "src", "content", "links");

function slugify(text) {
    return text
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "")
        .slice(0, 80);
}

function parseArgs(args) {
    const url = args.find((a) => !a.startsWith("--"));
    const tagsIdx = args.indexOf("--tags");
    const tags = tagsIdx !== -1 ? args[tagsIdx + 1]?.split(",") : null;
    return { url, tags };
}

async function fetchMeta(url) {
    const res = await fetch(url);
    const html = await res.text();

    const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
    const descMatch = html.match(
        /<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i,
    );

    return {
        title: titleMatch?.[1]?.trim() || new URL(url).hostname,
        description: descMatch?.[1]?.trim() || "",
    };
}

function toFrontmatter({ url, title, description, date, tags }) {
    const lines = [
        "---",
        `url: "${url}"`,
        `title: "${title.replace(/"/g, '\\"')}"`,
        `description: "${description.replace(/"/g, '\\"')}"`,
        `date: ${date}`,
    ];
    if (tags) {
        lines.push(`tags: [${tags.map((t) => `"${t.trim()}"`).join(", ")}]`);
    }
    lines.push("---", "");
    return lines.join("\n");
}

const { url, tags } = parseArgs(process.argv.slice(2));

if (!url) {
    console.error("Usage: node scripts/add-link.mjs <url> [--tags tag1,tag2]");
    process.exit(1);
}

const { title, description } = await fetchMeta(url);
const date = new Date().toISOString().slice(0, 10);
const slug = slugify(title);
const filename = `${slug}.mdx`;
const filepath = join(LINKS_DIR, filename);

if (existsSync(filepath)) {
    console.error(`Already exists: ${filepath}`);
    process.exit(1);
}

writeFileSync(filepath, toFrontmatter({ url, title, description, date, tags }));
console.log(`Created: src/content/links/${filename}`);
console.log(`  title: ${title}`);
console.log(`  description: ${description || "(none)"}`);
