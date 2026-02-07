import { z, defineCollection } from "astro:content";

const blogCollection = defineCollection({
    schema: z.object({
        title: z.string(),
        snippet: z.string(),
        author: z.string(),
        date: z.coerce.date(),
        tags: z.array(z.string()).optional(),
        image: z.string().optional(),
    }),
});

const linksCollection = defineCollection({
    schema: z.object({
        url: z.string().url(),
        title: z.string(),
        description: z.string(),
        date: z.coerce.date(),
        tags: z.array(z.string()).optional(),
    }),
});

export const collections = {
    blog: blogCollection,
    links: linksCollection,
};
