import { getAuthUserId } from "@convex-dev/auth/server";
import { mutation, query } from "./_generated/server";
import { ConvexError, v } from "convex/values";

export const submit = mutation({
  args: { listingId: v.id("publicListings"), rating: v.number(), message: v.string() },
  handler: async (ctx, args) => {
    const userId = await getAuthUserId(ctx);
    if (!userId) throw new ConvexError("Sign in to send feedback");
    if (!Number.isInteger(args.rating) || args.rating < 1 || args.rating > 5) throw new ConvexError("Choose a rating from 1 to 5");
    const message = args.message.trim();
    if (message.length > 3000) throw new ConvexError("Feedback must be 3000 characters or fewer");
    const listing = await ctx.db.get(args.listingId);
    if (!listing || !listing.published) throw new ConvexError("This public event is not available");
    const existing = await ctx.db.query("eventFeedback").withIndex("by_listing_author", q => q.eq("listingId", args.listingId).eq("userId", userId)).unique();
    const now = Date.now();
    let id;
    if (existing) {
      await ctx.db.patch(existing._id, { rating: args.rating, message, updatedAt: now });
      id = existing._id;
    } else {
      id = await ctx.db.insert("eventFeedback", { listingId: args.listingId, userId, rating: args.rating, message, createdAt: now, updatedAt: now });
    }
    return { id, confirmation: "Feedback submitted", rating: args.rating };
  },
});

export const forHost = query({
  args: { listingId: v.id("publicListings") },
  handler: async (ctx, args) => {
    const owner = await getAuthUserId(ctx);
    if (!owner) throw new ConvexError("Sign in required");
    const listing = await ctx.db.get(args.listingId);
    if (!listing || listing.owner !== owner) throw new ConvexError("Only the event host can read feedback");
    const rows = await ctx.db.query("eventFeedback").withIndex("by_listing", q => q.eq("listingId", args.listingId)).collect();
    const feedback = await Promise.all(rows.sort((a, b) => b.updatedAt - a.updatedAt).map(async row => {
      const user = await ctx.db.get(row.userId);
      return { id: row._id, rating: row.rating, message: row.message, createdAt: row.createdAt, updatedAt: row.updatedAt, authorName: user?.name ?? "Calendar user" };
    }));
    return { title: listing.title, feedback, averageRating: rows.length ? rows.reduce((total, row) => total + row.rating, 0) / rows.length : null, count: rows.length };
  },
});

export const summary = query({
  args: { listingId: v.id("publicListings") },
  handler: async (ctx, args) => {
    const listing = await ctx.db.get(args.listingId);
    if (!listing || !listing.published) throw new ConvexError("This public event is not available");
    const rows = await ctx.db.query("eventFeedback").withIndex("by_listing", q => q.eq("listingId", args.listingId)).collect();
    return { averageRating: rows.length ? rows.reduce((total, row) => total + row.rating, 0) / rows.length : null, count: rows.length };
  },
});
