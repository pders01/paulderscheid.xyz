#!/usr/bin/env node

import { writeFileSync, existsSync, mkdirSync, unlinkSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const LINKS_DIR = join(import.meta.dirname, "..", "src", "content", "links");

function decodeEntities(text) {
    return text
        .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
        .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCharCode(parseInt(code, 16)))
        .replace(/&amp;/g, "&")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, '"')
        .replace(/&apos;/g, "'")
        .replace(/&nbsp;/g, " ");
}

function slugify(text) {
    return text
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "")
        .slice(0, 80);
}

function parseArgs(args) {
    const positional = [];
    let tags = null;
    let action = "add";
    for (let i = 0; i < args.length; i++) {
        if (args[i] === "--tags") {
            tags = args[++i]?.split(",") ?? null;
        } else if (args[i] === "remove" && i === 0) {
            action = "remove";
        } else if (!args[i].startsWith("--")) {
            positional.push(args[i]);
        }
    }
    return { action, positional, tags };
}

async function fetchMeta(url) {
    const res = await fetch(url);
    const html = await res.text();

    const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
    const descMatch = html.match(/<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i);

    return {
        title: decodeEntities(titleMatch?.[1]?.trim() || new URL(url).hostname),
        description: decodeEntities(descMatch?.[1]?.trim() || ""),
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

function removeLinks(targets) {
    if (!existsSync(LINKS_DIR)) {
        console.error("No links directory");
        process.exit(1);
    }

    const files = readdirSync(LINKS_DIR).filter((f) => f.endsWith(".mdx"));
    let removed = 0;

    for (const target of targets) {
        // Match by URL or slug/filename
        const matched = files.filter((f) => {
            if (target.endsWith(".mdx") && f === target) return true;
            if (f === target + ".mdx") return true;
            const content = readFileSync(join(LINKS_DIR, f), "utf8");
            return content.includes(`url: "${target}"`);
        });

        if (matched.length === 0) {
            console.error(`[skip] ${target} — not found`);
            continue;
        }

        for (const f of matched) {
            unlinkSync(join(LINKS_DIR, f));
            console.log(`[ok]   removed ${f}`);
            removed++;
        }
    }

    if (targets.length > 1) console.log(`\nDone: ${removed} removed`);
}

const { action, positional, tags } = parseArgs(process.argv.slice(2));

if (positional.length === 0) {
    console.error("Usage:");
    console.error("  node scripts/add-link.mjs <url>... [--tags tag1,tag2]");
    console.error("  node scripts/add-link.mjs remove <url-or-slug>...");
    process.exit(1);
}

if (action === "remove") {
    removeLinks(positional);
    process.exit(0);
}

mkdirSync(LINKS_DIR, { recursive: true });

const date = new Date().toISOString().slice(0, 10);
let ok = 0;
let fail = 0;

for (const url of positional) {
    try {
        const { title, description } = await fetchMeta(url);
        const slug = slugify(title);
        const filename = `${slug}.mdx`;
        const filepath = join(LINKS_DIR, filename);

        if (existsSync(filepath)) {
            console.error(`[skip] ${url} — ${filename} already exists`);
            fail++;
            continue;
        }

        writeFileSync(filepath, toFrontmatter({ url, title, description, date, tags }));
        console.log(`[ok]   ${url} → src/content/links/${filename}`);
        console.log(`       title: ${title}`);
        ok++;
    } catch (e) {
        console.error(`[err]  ${url} — ${e.message}`);
        fail++;
    }
}

if (positional.length > 1) {
    console.log(`\nDone: ${ok} created, ${fail} failed`);
}
