#!/usr/bin/env node

import { writeFileSync, existsSync, mkdirSync, unlinkSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const LINKS_DIR = join(import.meta.dirname, "..", "src", "content", "links");
const PERL_RESOURCES_FILE = join(import.meta.dirname, "..", "perl", "resources.json");

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
    let note = null;
    let section = "links";
    let action = "add";
    for (let i = 0; i < args.length; i++) {
        if (args[i] === "--tags") {
            tags = args[++i]?.split(",") ?? null;
        } else if (args[i] === "--note") {
            note = args[++i] ?? null;
        } else if (args[i] === "--perl") {
            section = "perl";
        } else if (args[i] === "remove" || args[i] === "list") {
            action = args[i];
        } else if (!args[i].startsWith("--")) {
            positional.push(args[i]);
        }
    }
    return { action, positional, tags, note, section };
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

async function fetchTitle(url) {
    const { title } = await fetchMeta(url);
    return title;
}

// ---------------------------------------------------------------------------
// Links section
// ---------------------------------------------------------------------------

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

function listLinks() {
    if (!existsSync(LINKS_DIR)) {
        console.log("No links yet.");
        process.exit(0);
    }

    const files = readdirSync(LINKS_DIR).filter((f) => f.endsWith(".mdx"));
    if (files.length === 0) {
        console.log("No links yet.");
        process.exit(0);
    }

    for (const f of files) {
        const content = readFileSync(join(LINKS_DIR, f), "utf8");
        const url = content.match(/url: "(.+)"/)?.[1] ?? "";
        const title = content.match(/title: "(.+)"/)?.[1] ?? f;
        console.log(`${title}\n  ${url}\n`);
    }

    console.log(`${files.length} links`);
}

async function addLinks(urls, tags) {
    mkdirSync(LINKS_DIR, { recursive: true });

    const date = new Date().toISOString().slice(0, 10);
    let ok = 0;
    let fail = 0;

    for (const url of urls) {
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

    if (urls.length > 1) {
        console.log(`\nDone: ${ok} created, ${fail} failed`);
    }
}

// ---------------------------------------------------------------------------
// Perl resources section
// ---------------------------------------------------------------------------

function loadPerlResources() {
    if (!existsSync(PERL_RESOURCES_FILE)) return [];
    return JSON.parse(readFileSync(PERL_RESOURCES_FILE, "utf8"));
}

function savePerlResources(resources) {
    writeFileSync(PERL_RESOURCES_FILE, JSON.stringify(resources, null, 4) + "\n");
}

function listPerlResources() {
    const resources = loadPerlResources();
    if (resources.length === 0) {
        console.log("No perl resources yet.");
        process.exit(0);
    }
    for (const r of resources) {
        console.log(`${r.title}\n  ${r.url}\n  ${r.note}\n`);
    }
    console.log(`${resources.length} resources`);
}

function removePerlResources(targets) {
    const resources = loadPerlResources();
    const remaining = resources.filter(
        (r) => !targets.some((t) => r.url === t || r.title.toLowerCase().includes(t.toLowerCase())),
    );
    const removed = resources.length - remaining.length;
    if (removed === 0) {
        console.error("No matching resources found.");
        return;
    }
    savePerlResources(remaining);
    console.log(`Removed ${removed} resource(s).`);
}

async function addPerlResources(urls, note) {
    const resources = loadPerlResources();
    let ok = 0;

    for (const url of urls) {
        try {
            if (resources.some((r) => r.url === url)) {
                console.error(`[skip] ${url} — already exists`);
                continue;
            }
            const title = await fetchTitle(url);
            resources.push({ title, url, note: note ?? "" });
            console.log(`[ok]   ${url}`);
            console.log(`       title: ${title}`);
            ok++;
        } catch (e) {
            console.error(`[err]  ${url} — ${e.message}`);
        }
    }

    if (ok > 0) {
        savePerlResources(resources);
        console.log(`\nDone: ${ok} added (${resources.length} total)`);
    }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

const { action, positional, tags, note, section } = parseArgs(process.argv.slice(2));

if (action === "list") {
    section === "perl" ? listPerlResources() : listLinks();
    process.exit(0);
}

if (positional.length === 0) {
    console.error("Usage:");
    console.error("  pnpm bm <url>... [--tags tag1,tag2]");
    console.error("  pnpm bm list");
    console.error("  pnpm bm remove <url-or-slug>...");
    console.error("");
    console.error("  pnpm bm --perl <url>... [--note \"description\"]");
    console.error("  pnpm bm --perl list");
    console.error("  pnpm bm --perl remove <url-or-title>...");
    process.exit(1);
}

if (action === "remove") {
    section === "perl" ? removePerlResources(positional) : removeLinks(positional);
    process.exit(0);
}

if (section === "perl") {
    await addPerlResources(positional, note);
} else {
    await addLinks(positional, tags);
}
