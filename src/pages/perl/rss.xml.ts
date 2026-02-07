import rss from "@astrojs/rss";
import { getCollection } from "astro:content";

export async function GET(context: { site: string }) {
    const posts = (await getCollection("perl")).filter((p) => !p.data.draft);
    posts.sort((a, b) => new Date(b.data.date).getTime() - new Date(a.data.date).getTime());

    return rss({
        title: "paul derscheid — perl",
        description: "Perl tips, articles, and things worth knowing.",
        site: context.site,
        items: posts.map((post) => ({
            title: post.data.title,
            description: post.data.snippet,
            pubDate: post.data.date,
            link: `/perl/${post.slug}/`,
        })),
    });
}
