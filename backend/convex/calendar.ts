import { mutation, query } from "./_generated/server";
import { ConvexError, v } from "convex/values";

export const list = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Sign in required");
    return ctx.db.query("events").withIndex("by_owner", q => q.eq("owner", identity.tokenIdentifier)).collect();
  },
});

export const upsert = mutation({
  args: {
    clientId: v.string(), title: v.string(), start: v.number(), end: v.number(),
    isAllDay: v.boolean(), location: v.string(), notes: v.string(), color: v.string(),
    reminderMinutes: v.optional(v.number()),
    people: v.optional(v.array(v.string())), tags: v.optional(v.array(v.string())),
    hostName: v.optional(v.string()),
    expectedUpdatedAt: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Sign in required");
    const owner = identity.tokenIdentifier;
    if (!args.title.trim() || !Number.isFinite(args.start) || !Number.isFinite(args.end) || args.end <= args.start) {
      throw new ConvexError("Invalid event");
    }
    const existing = await ctx.db.query("events").withIndex("by_owner_client", q => q.eq("owner", owner).eq("clientId", args.clientId)).unique();
    if (existing && args.expectedUpdatedAt !== existing.updatedAt) throw new ConvexError("Event changed; refresh before saving");
    const { expectedUpdatedAt, ...event } = args;
    const data = { ...event, owner, updatedAt: Date.now(), deletedAt: undefined };
    const id = existing ? (await ctx.db.replace(existing._id, data), existing._id) : await ctx.db.insert("events", data);
    await ctx.db.insert("audit", { owner, actor: owner, action: "event.upsert", clientId: args.clientId, at: Date.now() });
    return id;
  },
});

export const remove = mutation({
  args: { clientId: v.string(), expectedUpdatedAt: v.number() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Sign in required");
    const owner = identity.tokenIdentifier;
    const event = await ctx.db.query("events").withIndex("by_owner_client", q => q.eq("owner", owner).eq("clientId", args.clientId)).unique();
    if (!event || event.updatedAt !== args.expectedUpdatedAt) throw new ConvexError("Event changed or missing");
    const now = Date.now();
    await ctx.db.patch(event._id, { deletedAt: now, updatedAt: now });
    await ctx.db.insert("audit", { owner, actor: owner, action: "event.delete", clientId: args.clientId, at: now });
  },
});
