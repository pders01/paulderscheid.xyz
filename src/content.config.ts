import { z, defineCollection } from "astro:content";
import { glob } from "astro/loaders";

const blogCollection = defineCollection({
    loader: glob({ pattern: "**/*.mdx", base: "./src/content/blog" }),
    schema: z.object({
        title: z.string(),
        snippet: z.string(),
        author: z.string(),
        date: z.coerce.date(),
        draft: z.boolean().optional(),
        tags: z.array(z.string()).optional(),
        image: z.string().optional(),
    }),
});

const linksCollection = defineCollection({
    loader: glob({ pattern: "**/*.mdx", base: "./src/content/links" }),
    schema: z.object({
        url: z.string().url(),
        title: z.string(),
        description: z.string(),
        date: z.coerce.date(),
        tags: z.array(z.string()).optional(),
    }),
});

const perlCollection = defineCollection({
    loader: glob({ pattern: "**/*.mdx", base: "./src/content/perl" }),
    schema: z.object({
        title: z.string(),
        snippet: z.string(),
        author: z.string(),
        date: z.coerce.date(),
        draft: z.boolean().optional(),
        tags: z.array(z.string()).optional(),
        image: z.string().optional(),
    }),
});

export const collections = {
    blog: blogCollection,
    links: linksCollection,
    perl: perlCollection,
};
