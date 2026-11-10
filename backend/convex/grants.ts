import { mutation } from "./_generated/server";
import { ConvexError, v } from "convex/values";

export const grant = mutation({
  args: { agentSubject: v.string(), canWrite: v.boolean(), expiresAt: v.number() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Sign in required");
    const now = Date.now();
    if (!args.agentSubject.trim() || args.expiresAt <= now || args.expiresAt > now + 30 * 86400000) throw new ConvexError("Choose an agent and expiry within 30 days");
    const owner = identity.tokenIdentifier;
    const previous = await ctx.db.query("agentGrants").withIndex("by_owner_agent", q => q.eq("owner", owner).eq("agentSubject", args.agentSubject)).unique();
    if (previous) await ctx.db.replace(previous._id, { ...args, owner });
    else await ctx.db.insert("agentGrants", { ...args, owner });
    await ctx.db.insert("audit", { owner, actor: owner, action: "agent.grant", at: now });
  },
});

export const revoke = mutation({
  args: { agentSubject: v.string() },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) throw new ConvexError("Sign in required");
    const owner = identity.tokenIdentifier;
    const grant = await ctx.db.query("agentGrants").withIndex("by_owner_agent", q => q.eq("owner", owner).eq("agentSubject", args.agentSubject)).unique();
    if (grant) await ctx.db.patch(grant._id, { revokedAt: Date.now() });
    await ctx.db.insert("audit", { owner, actor: owner, action: "agent.revoke", at: Date.now() });
  },
});
