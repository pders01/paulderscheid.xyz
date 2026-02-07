import rss from "@astrojs/rss";
import { getCollection } from "astro:content";

export async function GET(context: { site: string }) {
    const links = await getCollection("links");
    links.sort((a, b) => new Date(b.data.date).getTime() - new Date(a.data.date).getTime());

    return rss({
        title: "paul derscheid — links",
        description: "Just stuff I found interesting. No endorsement or affiliation.",
        site: context.site,
        items: links.map((link) => ({
            title: link.data.title,
            description: link.data.description,
            pubDate: link.data.date,
            link: link.data.url,
        })),
    });
}
