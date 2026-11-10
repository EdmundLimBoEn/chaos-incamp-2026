import { getAuthUserId } from "@convex-dev/auth/server";
import { mutation, query } from "./_generated/server";
import { ConvexError, v } from "convex/values";
import { paginationOptsValidator } from "convex/server";

export const saveHost = mutation({
  args: { displayName: v.string(), bio: v.string() },
  handler: async (ctx, args) => {
    const owner = await getAuthUserId(ctx);
    if (!owner) throw new ConvexError("Sign in required");
    const displayName = args.displayName.trim();
    if (!displayName || displayName.length > 100 || args.bio.length > 2000) throw new ConvexError("Invalid host profile");
    const existing = await ctx.db.query("hosts").withIndex("by_owner", q => q.eq("owner", owner)).unique();
    const data = { owner, displayName, bio: args.bio.trim(), updatedAt: Date.now() };
    if (existing) { await ctx.db.patch(existing._id, data); return existing._id; }
    return ctx.db.insert("hosts", data);
  },
});

export const publish = mutation({
  args: {
    id: v.optional(v.id("publicListings")), title: v.string(), description: v.string(),
    tags: v.array(v.string()), start: v.number(), end: v.number(), location: v.string(),
    published: v.boolean(),
  },
  handler: async (ctx, args) => {
    const owner = await getAuthUserId(ctx);
    if (!owner) throw new ConvexError("Sign in required");
    const host = await ctx.db.query("hosts").withIndex("by_owner", q => q.eq("owner", owner)).unique();
    if (!host) throw new ConvexError("Create a host profile first");
    if (!args.title.trim() || args.title.length > 200 || args.description.length > 10000 || args.tags.length > 12 || args.tags.some(tag => tag.length > 50) || !Number.isFinite(args.start) || !Number.isFinite(args.end) || args.end <= args.start) throw new ConvexError("Invalid listing");
    const existing = args.id ? await ctx.db.get(args.id) : null;
    if (args.id && (!existing || existing.owner !== owner)) throw new ConvexError("Listing not found");
    const tags = [...new Set(args.tags.map(tag => tag.trim().toLowerCase().replace(/^#/, "")).filter(Boolean))];
    const { id, ...fields } = args;
    const data = { ...fields, title: args.title.trim(), tags, owner, hostId: host._id, searchText: [args.title, args.description, args.location, host.displayName, ...tags].join(" "), updatedAt: Date.now() };
    const listingId = id ?? await ctx.db.insert("publicListings", data);
    if (id) await ctx.db.replace(id, data);
    await ctx.db.insert("audit", { owner, actor: owner, action: args.published ? "listing.publish" : "listing.unpublish", at: Date.now() });
    return listingId;
  },
});

export const search = query({
  args: { text: v.optional(v.string()), tag: v.optional(v.string()), hostId: v.optional(v.id("hosts")), from: v.optional(v.number()), until: v.optional(v.number()), paginationOpts: paginationOptsValidator },
  handler: async (ctx, args) => {
    const text = args.text?.trim();
    const source = text
      ? ctx.db.query("publicListings").withSearchIndex("search_public", q => {
          const search = q.search("searchText", text).eq("published", true);
          return args.hostId ? search.eq("hostId", args.hostId) : search;
        })
      : ctx.db.query("publicListings").withIndex("by_public_start", q => q.eq("published", true));
    let filtered = source.filter(q => q.and(
      args.from === undefined ? true : q.gt(q.field("end"), args.from),
      args.until === undefined ? true : q.lt(q.field("start"), args.until),
      args.hostId === undefined ? true : q.eq(q.field("hostId"), args.hostId),
    ));
    const result = await filtered.paginate({ ...args.paginationOpts, numItems: Math.min(50, Math.max(1, args.paginationOpts.numItems)) });
    const tag = args.tag?.trim().toLowerCase().replace(/^#/, "");
    const page = await Promise.all(result.page.filter(item => !tag || item.tags.includes(tag)).map(async item => {
      const host = await ctx.db.get(item.hostId);
      return { id: item._id, title: item.title, description: item.description, tags: item.tags, start: item.start, end: item.end, location: item.location, host: host ? { id: host._id, displayName: host.displayName, bio: host.bio } : null };
    }));
    return { ...result, page };
  },
});

export const myListings = query({
  args: {},
  handler: async (ctx) => {
    const owner = await getAuthUserId(ctx);
    if (!owner) throw new ConvexError("Sign in required");
    const listings = await ctx.db.query("publicListings").withIndex("by_owner", q => q.eq("owner", owner)).collect();
    const events = await Promise.all(listings.sort((a, b) => b.start - a.start).map(async item => {
      const host = await ctx.db.get(item.hostId);
      return { id: item._id, title: item.title, description: item.description, tags: item.tags, start: item.start, end: item.end, location: item.location, published: item.published, host: host ? { id: host._id, displayName: host.displayName, bio: host.bio } : null };
    }));
    return { events };
  },
});
